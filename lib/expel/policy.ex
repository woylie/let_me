defmodule Expel.Policy do
  @moduledoc """
  This module defines a DSL for authorization rules and compiles these rules
  to authorize and introspection functions.

  ## Usage

      defmodule MyApp.Policy do
        use Expel.Policy

        object :article do
          action :create do
            allow role: :admin
            allow role: :writer
          end

          action :update do
            allow :own_resource
          end

          action :view do
            allow true
          end
        end
      end

  ### Options

  These options can be passed when using this module:

  - `check_module` - The module where the check functions are defined. Defaults
    to `__MODULE__.Checks`.
  - `error_reason` - The error reason used by the `c:authorize/3` callback.
    Defaults to `:unauthorized`.

  ## Check module

  The checks passed to `allow/1` and `allow/2` reference the names of functions
  in the checks module.

  By default, Expel tries to find the functions in `__MODULE__.Checks` (in the
  example, this would be `MyApp.Policy.Checks`). However, you can override the
  default check module:

      use Expel.Policy, check_module: MyApp.AuthChecks

  Each check function has to take the subject (user), the object, and optionally
  an additional options argument, and must return a boolean value.

  For example, this check determines whether a user is banned:

      def banned(%User{banned: true}, _), do: true
      def banned(%User{}, _), do: false

  This check determines whether the user has the given role:

      def role(%User{role: role}, _, role), do: true
      def role(_, _, _), do: false

  And this check determines whether the object belongs to the user:

      def own_resource(%User{id: user_id}, %{user_id: user_id}), do: true
      def own_resource(_, _), do: false

  Expel does not make any assumptions about your access control model, as long
  as you can map your rules to subject, object and action. You can use the three
  rules above with the `allow/1` and `deny/1` macros.

      allow role: :admin
      allow :own_resource
      deny :banned

  ## Combining checks

  Rules evaluate to `false` by default. These rules will always be `false`
  because they don't have any `allow` clauses:

      action :create do
      end

      action :update do
        deny false
      end


  Trying to evaluate a rule name that does not exist also evaluates to `false`.

  As soon as one `deny` check evaluates to `true`, the whole rule will evaluate
  to `false`. This rule will always evaluate to `false`:

      action :create do
        allow true
        deny true
      end

  If you pass a list of checks to either `allow/1` or `deny/1`, the checks
  are combined with a logical `AND`.

      # false
      action :create do
        allow [true, false]
      end

      # true
      action :create do
        allow [true, true]
      end

      # true
      action :create do
        allow [true, true]
        deny [true, false]
      end

      # false
      action :create do
        allow [true, true]
        deny [true, true]
      end

  On the other hand, if either the `allow/1` or the `deny/1` macro is used
  multiple times, the checks are combined with a logical `OR`.

      # true
      action :create do
        allow true
        allow false
      end

      # false
      action :create do
        allow [true, false]
        allow false
      end

      # true
      action :create do
        allow [true, false]
        allow true
      end

      # false
      action :create do
        allow [true, true]
        allow true
        deny false
        deny true
      end

  ## Pre-hooks

  You can use pre-hooks to process or gather additional data about the subject
  and/or object before running the checks. This can be useful if you need to
  preload associations or make external requests. Pre-hooks run once per
  authorization request before running the checks. See the documentation for
  `pre_hooks/1`.
  """
  alias Expel.Rule

  @doc """
  Returns all authorization rules as a list.

  ## Example

      iex> MyApp.PolicyShort.list_rules()
      [
        %Expel.Rule{
          action: :create,
          allow: [[role: :admin], [role: :writer]],
          deny: [],
          name: :article_create,
          object: :article,
          pre_hooks: []
        },
        %Expel.Rule{
          action: :update,
          allow: [:own_resource],
          deny: [],
          name: :article_update,
          object: :article,
          pre_hooks: [:preload_groups]
        }
      ]
  """
  @callback list_rules :: [Expel.Rule.t()]

  @doc """
  Same as `c:list_rules/0`, but takes a keyword list with filter options.

  See `Expel.filter_rules/2` for a list of available filter options.
  """
  @callback list_rules(keyword) :: [Expel.Rule.t()]

  @doc """
  Returns the rule for the given name. Returns an `:ok` tuple or `:error`.

  The rule name is an atom with the format `{object}_{action}`.

  ## Example

      iex> MyApp.Policy.fetch_rule(:article_create)
      {:ok,
       %Expel.Rule{
         action: :create,
         allow: [[role: :admin], [role: :writer]],
         deny: [],
         name: :article_create,
         object: :article,
         pre_hooks: []
       }}

       iex> MyApp.Policy.fetch_rule(:cookie_eat)
       :error
  """
  @callback fetch_rule(atom) :: {:ok, Expel.Rule.t()} | :error

  @doc """
  Returns the rule with the given name. Raises if the rule is not found.

  The rule name is an atom with the format `{object}_{action}`.

  ## Example

      iex> MyApp.Policy.fetch_rule!(:article_create)
      %Expel.Rule{
        action: :create,
        allow: [[role: :admin], [role: :writer]],
        deny: [],
        name: :article_create,
        object: :article,
        pre_hooks: []
      }
  """
  @callback fetch_rule!(atom) :: Expel.Rule.t()

  @doc """
  Authorizes a request defined by the action, subject and object.

  ## Example

  Assume we defined this authorization rule:

      object :article do
        action :update do
          allow :own_resource
        end
      end

  And the `:own_resource` check is defined as:

      def own_resource(%{id: user_id}, %{user_id: user_id}), do: true
      def own_resource(_, _), do: false

  The identifier for the action consists of the object and the action name, in
  this case `:article_create`. To authorize the action, we need to pass this
  identifier, the subject (current user) and the object (the article to be
  updated).

      iex> article = %{id: 80, user_id: 1}
      iex> user_1 = %{id: 1}
      iex> user_2 = %{id: 2}
      iex> MyApp.Policy.authorize(:article_update, user_1, article)
      :ok
      iex> MyApp.Policy.authorize(:article_update, user_2, article)
      {:error, :unauthorized}

  If the checks don't require the object, it can be omitted.

      object :user do
        action :list do
          allow {:role, :admin}
          allow {:role, :client}
        end
      end

      iex> user = %{id: 1, role: :admin}
      iex> MyApp.Policy.authorize(:user_list, user)
      :ok
      iex> user = %{id: 2, role: :user}
      iex> MyApp.Policy.authorize(:user_list, user)
      {:error, :unauthorized}

  The error reason can be customized by setting the `:error_reason` option when
  using the module.
  """
  @callback authorize(atom, any, any) :: :ok | {:error, any}

  @doc """
  Same as `c:authorize/3`, but raises an error if unauthorized.

  ## Example

  With the same authorization rules as defined in the `c:authorize/3`
  documentation, we get this:

      iex> article = %{id: 80, user_id: 1}
      iex> user_1 = %{id: 1}
      iex> user_2 = %{id: 2}
      iex> MyApp.Policy.authorize!(:article_update, user_1, article)
      :ok
      iex> MyApp.Policy.authorize!(:article_update, user_2, article)
      ** (Expel.UnauthorizedError) unauthorized
  """
  @callback authorize!(atom, any, any) :: :ok

  @doc """
  Same as `c:authorize/3`, but returns a boolean.

  ## Example

  With the same authorization rules as defined in the `c:authorize/3`
  documentation, we get this:

      iex> article = %{id: 80, user_id: 1}
      iex> user_1 = %{id: 1}
      iex> user_2 = %{id: 2}
      iex> MyApp.Policy.authorized?(:article_update, user_1, article)
      true
      iex> MyApp.Policy.authorized?(:article_update, user_2, article)
      false
  """
  @callback authorized?(atom, any, any) :: boolean

  @doc """
  Returns the rule for the given rule identifier. Returns `nil` if the rule is
  not found.

  The rule identifier is an atom with the format `{object}_{action}`.

  ## Example

      iex> MyApp.Policy.get_rule(:article_create)
      %Expel.Rule{
        action: :create,
        allow: [[role: :admin], [role: :writer]],
        deny: [],
        name: :article_create,
        object: :article,
        pre_hooks: []
      }

      iex> MyApp.Policy.get_rule(:cookie_eat)
      nil
  """
  @callback get_rule(atom) :: Expel.Rule.t() | nil

  defmacro __using__(opts \\ []) do
    opts =
      Keyword.validate!(opts,
        check_module: Module.concat(__CALLER__.module, Checks),
        error_reason: :unauthorized
      )

    quote do
      Module.put_attribute(__MODULE__, :opts, unquote(opts))
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      Module.register_attribute(__MODULE__, :actions, accumulate: true)
      Module.register_attribute(__MODULE__, :allow_checks, accumulate: true)
      Module.register_attribute(__MODULE__, :deny_checks, accumulate: true)
      Module.register_attribute(__MODULE__, :pre_hooks, accumulate: true)

      @behaviour Expel.Policy

      import Expel.Policy
      import Expel.Builder

      require Logger

      @before_compile unquote(__MODULE__)
      @after_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :opts)

    rules =
      env.module
      |> Module.get_attribute(:rules)
      |> Enum.reverse()
      |> Enum.into(%{}, &{:"#{&1.object}_#{&1.action}", &1})

    introspection_functions = Expel.Builder.introspection_functions(rules)
    authorize_functions = Expel.Builder.authorize_functions(rules, opts)

    quote do
      unquote(introspection_functions)
      unquote(authorize_functions)
    end
  end

  defmacro __after_compile__(env, _) do
    rules = Module.get_attribute(env.module, :rules)
    validate_no_duplicate_rules!(rules, env.module)
    validate_no_duplicate_checks!(rules, env.module)
  end

  defp validate_no_duplicate_rules!(rules, module) do
    duplicate_rules =
      rules
      |> Enum.frequencies_by(&{&1.object, &1.action})
      |> Enum.filter(fn {_, count} -> count > 1 end)

    if duplicate_rules != [] do
      rules_as_string =
        Enum.map_join(duplicate_rules, "\n    ", fn {{object, action}, _} ->
          "object: #{inspect(object)}, action: #{inspect(action)}"
        end)

      raise """
      duplicate authorization rules

      The policy module #{module} has duplicate authorization rules.

          #{rules_as_string}

      Look out for actions that are defined twice for the same object.
      """
    end

    :ok
  end

  defp validate_no_duplicate_checks!(rules, module) do
    Enum.each(rules, fn rule ->
      do_validate_no_duplicate_checks!(rule, :allow, module)
      do_validate_no_duplicate_checks!(rule, :deny, module)
    end)
  end

  defp do_validate_no_duplicate_checks!(rule, field, module) do
    rule
    |> Map.fetch!(field)
    |> Enum.each(fn
      checks when is_list(checks) ->
        duplicate_checks =
          checks
          |> Enum.frequencies()
          |> Enum.filter(fn {_, count} -> count > 1 end)
          |> Enum.map(&elem(&1, 0))

        if duplicate_checks != [] do
          raise """
          duplicate authorization checks

          The policy module #{module} has duplicate authorization checks.

              object: #{rule.object}
              action: #{rule.action}
              macro: #{field}/1
              #{inspect(duplicate_checks)}
          """
        end

      _ ->
        :ok
    end)
  end

  @doc """
  Defines an action that needs to be authorized.

  Within the do-block, you can use the `allow/1`, `deny/1` and `pre_hooks/1`
  macros to define the checks to be run.

  This macro must be used within the do-block of `object/2`.

  Each `action` block will be compiled to a rule. The identifier for the rule
  is an atom with the format `{object}_{action}`.

  ## Example

      object :article do
        action :create do
          allow role: :admin
          allow role: :writer
        end

        action :update do
          allow role: :admin
          allow [:own_resource, role: :writer]
        end
      end
  """
  @spec action(atom, Macro.t()) :: Macro.t()
  defmacro action(name, do: block) do
    quote do
      # reset attributes from previous `action/2` calls
      Module.delete_attribute(__MODULE__, :allow_checks)
      Module.delete_attribute(__MODULE__, :description)
      Module.delete_attribute(__MODULE__, :deny_checks)
      Module.delete_attribute(__MODULE__, :pre_hooks)

      # compile inner block
      unquote(block)

      Module.put_attribute(__MODULE__, :actions, %{
        name: unquote(name),
        allow: get_acc_attribute(__MODULE__, :allow_checks),
        description: Module.get_attribute(__MODULE__, :description),
        deny: get_acc_attribute(__MODULE__, :deny_checks),
        pre_hooks: __MODULE__ |> get_acc_attribute(:pre_hooks) |> List.flatten()
      })
    end
  end

  @doc """
  Defines the checks to be run to determine if an action is allowed.

  The argument can be:

  - a function name as an atom
  - a tuple with the function name and an additional argument
  - a list of function names or function/argument tuples
  - `true` - Always allows an action. This is useful in combination with the
    `deny/1` macro.

  The function must be defined in the configured Checks module and take the
  subject (current user), object as arguments, and if given, the additional
  argument.

  If a list is given as an argument, the checks are combined with a logical
  `AND`.

  If the `allow/1` macro is used multiple times within the same `action/2`
  block, the checks of each macro call are combined with a logical `OR`.

  ## Examples

  Let's assume you defined the following checks:

      defmodule MyApp.Policy.Checks do
        def role(%User{role: role}, _, role), do: true
        def role(_, _, _), do: false

        def own_resource(%User{id: id}, %{user_id: id}, _), do: true
        def own_resource(_, _, _), do: false
      end

  This would allow the `:article_update` action only if the current user has
  the role `:admin`:

      object :article do
        action :update do
          allow role: :admin
        end
      end

  This is equivalent to:

      object :article do
        action :update do
          allow {:role, :admin}
        end
      end

  This would allow the `:article_update` action if the user has the role
  `:writer` _and_ the article belongs to the user:

      object :article do
        action :update do
          allow [:own_resource, role: :writer]
        end
      end

  This is equivalent to:

      object :article do
        action :update do
          allow [:own_resource, {:role, :writer}]
        end
      end

  This would allow the `:article_update` action if
  (the user has the role `:admin` _or_ (the user has the role `:writer` _and_
  the article belongs to the user)):

      object :article do
        action :update do
          allow role: :admin
          allow [:own_resource, role: :writer]
        end
      end
  """
  @spec allow(check | [check]) :: Macro.t() when check: atom | {atom, any}
  defmacro allow(checks) do
    quote do
      Module.put_attribute(__MODULE__, :allow_checks, unquote(checks))
    end
  end

  @doc """
  Allows you to add a description to a rule.

  The description can be accessed from the `Expel.Rule` struct. You can use it
  to generate help texts or documentation.

  ## Example

      object :article do
        action :create do
          desc "allows a user to create a new article"
          allow role: :writer
        end
      end
  """
  @spec desc(String.t()) :: Macro.t()
  defmacro desc(text) do
    quote do
      Module.put_attribute(__MODULE__, :description, unquote(text))
    end
  end

  @doc """
  Defines the checks to be run to determine if an action is denied.

  If any of the checks evaluates to `true`, the `allow` checks are overridden
  and the permission request is automatically denied.

  If a list is given as an argument, the checks are combined with a logical
  `AND`.

  If the `allow/1` macro is used multiple times within the same `action/2`
  block, the checks of each macro call are combined with a logical `OR`.


  ## Examples

  Let's assume you defined the following checks:

      defmodule MyApp.Policy.Checks do
        def role(%User{role: role}, _, role), do: true
        def role(_, _, _), do: false

        def own_resource(%User{id: id}, %{user_id: id}, _), do: true
        def own_resource(_, _, _), do: false

        def same_user(%User{id: id}, %User{id: id}, _), do: true
        def same_user(_, _, _), do: false
      end

  This would allow the `:user_delete` by default, _unless_ the object is the
  current user:

      object :user do
        action :delete do
          allow true
          deny :same_user
        end
      end

  This would allow the `:article_update` action only if the current user has
  the role `:admin`, _unless_ the object is the current user:

      object :user do
        action :delete do
          allow role: :admin
          deny :same_user
        end
      end

  This would allow the `:user_delete` by default, _unless_ the object is the
  current user _and_ the current user is an admin:

      object :user do
        action :delete do
          allow true
          deny [:same_user, role: :admin]
        end
      end

  This would allow the `:user_delete` by default, _unless_ the object is the
  current user _or_ the current user is a peasant:

      object :user do
        action :delete do
          allow true
          deny :same_user
          deny role: :peasant
        end
      end
  """
  @spec deny(check | [check]) :: Macro.t() when check: atom | {atom, any}
  defmacro deny(checks) do
    quote do
      Module.put_attribute(__MODULE__, :deny_checks, unquote(checks))
    end
  end

  @doc """
  Defines an object on which actions can be performed.

  Within the do-block, you can use the `action/2` macro to define the actions
  and checks.

  ## Example

      object :article do
        action :create do
          allow role: :writer
        end

        action :delete do
          allow role: :editor
        end
      end
  """
  @spec object(atom, Macro.t()) :: Macro.t()
  defmacro object(name, do: block) do
    quote do
      # reset attributes from previous `object/2` calls
      Module.delete_attribute(__MODULE__, :actions)

      # compile inner block
      unquote(block)

      for action <- Module.get_attribute(__MODULE__, :actions, []) do
        Module.put_attribute(__MODULE__, :rules, %Rule{
          action: action.name,
          allow: action.allow,
          deny: action.deny,
          description: action.description,
          name: :"#{unquote(name)}_#{action.name}",
          object: unquote(name),
          pre_hooks: action.pre_hooks
        })
      end
    end
  end

  @doc """
  Registers one or multiple functions to run in order to hydrate the subject
  and/or object of the request.

  This is useful if you need to enhance the data for multiple checks in the
  same action. The configured hook functions will be called once before running
  the checks for an action.

  The referenced functions must take the subject and object as arguments and
  return a 2-tuple with the updated subject and object.

  ## Examples

  Let's assume we defined these check and hook functions in our check module:

      def MyApp.Policy.Checks do
        # Checks

        def min_age(%{age: age}, _, min_age), do: age >= min_age

        # Hooks

        def double_age(subject, object) do
          new_subject = %{subject | age: subject.age * 2}
          {new_subject, object}
        end

        def set_age(subject, object, age) do
          new_subject = %{subject | age: age}
          {new_subject, object}
        end
      end

  If an atom is passed, Expel will try to find the function in the check module.

      object :article do
        action :view do
          pre_hooks :double_age
          allow min_age: 50
        end
      end

  With this in place, the following authorization request will evaluate to
  `true`:

      MyApp.Policy.authorize!(:article_view, %{age: 25})
      # => true

  If your hooks are defined in a different module, you can also pass a
  module/function tuple. The pre-hook configuration above is equivalent to:

      object :article do
        action :view do
          pre_hooks {MyApp.Policy.Checks, :double_age}
          allow min_age: 50
        end
      end

  You can also pass options to a hook by using an MFA tuple:

      object :article do
        action :view do
          pre_hooks {MyApp.Policy.Checks, :set_age, 50}
          allow min_age: 50
        end
      end

      MyApp.Policy.authorize!(:article_view, %{age: 10})
      # => true

  And finally, you can also pass a list of hooks, which will be run in sequence:

      alias MyApp.Policy.Checks

      object :article do
        action :view do
          pre_hooks [{Checks, :set_age, 25}, :double_age]
          allow min_age: 50
        end
      end

      MyApp.Policy.authorize!(:article_view, %{age: 10})
      # => true
  """
  @spec pre_hooks(hook | [hook]) :: Macro.t()
        when hook: atom | {module, atom} | {module, atom, any}
  defmacro pre_hooks(hooks) do
    quote do
      Module.put_attribute(__MODULE__, :pre_hooks, unquote(hooks))
    end
  end
end
