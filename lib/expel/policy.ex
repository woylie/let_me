defmodule Expel.Policy do
  @moduledoc """
  Defines a DSL for writing authorization rules.

  ## Example

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
          object: :article,
          pre_hooks: []
        },
        %Expel.Rule{
          action: :update,
          allow: [:own_resource],
          deny: [],
          object: :article,
          pre_hooks: [:preload_groups]
        }
      ]
  """
  @callback list_rules :: [Expel.Rule.t()]

  @doc """
  Returns the rule for the given rule identifier. Returns an `:ok` tuple or
  `:error`.

  The rule identifier is an atom with the format `{object}_{action}`.

  ## Example

      iex> MyApp.Policy.fetch_rule(:article_create)
      {:ok,
       %Expel.Rule{
         action: :create,
         allow: [[role: :admin], [role: :writer]],
         deny: [],
         object: :article,
         pre_hooks: []
       }}

       iex> MyApp.Policy.fetch_rule(:cookie_eat)
       :error
  """
  @callback fetch_rule(atom) :: {:ok, Expel.Rule.t()} | :error

  @doc """
  Returns the rule for the given rule identifier. Raises if the rule is not
  found.

  The rule identifier is an atom with the format `{object}_{action}`.

  ## Example

      iex> MyApp.Policy.fetch_rule!(:article_create)
      %Expel.Rule{
        action: :create,
        allow: [[role: :admin], [role: :writer]],
        deny: [],
        object: :article,
        pre_hooks: []
      }
  """
  @callback fetch_rule!(atom) :: Expel.Rule.t()

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
        object: :article,
        pre_hooks: []
      }

      iex> MyApp.Policy.get_rule(:cookie_eat)
      nil
  """
  @callback get_rule(atom) :: Expel.Rule.t() | nil

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      Module.register_attribute(__MODULE__, :actions, accumulate: true)
      Module.register_attribute(__MODULE__, :allow_checks, accumulate: true)
      Module.register_attribute(__MODULE__, :deny_checks, accumulate: true)
      Module.register_attribute(__MODULE__, :pre_hooks, accumulate: true)

      @behaviour Expel.Policy

      import Expel.Policy
      import Expel.Builder

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    rules =
      env.module
      |> Module.get_attribute(:rules)
      |> Enum.reverse()
      |> Enum.into(%{}, &{:"#{&1.object}_#{&1.action}", &1})

    quote do
      @doc false
      def __rules__, do: unquote(Macro.escape(rules))

      @impl Expel.Policy
      def list_rules, do: Map.values(__rules__())

      @impl Expel.Policy
      def fetch_rule(action) when is_atom(action),
        do: Map.fetch(__rules__(), action)

      @impl Expel.Policy
      def fetch_rule!(action) when is_atom(action),
        do: Map.fetch!(__rules__(), action)

      @impl Expel.Policy
      def get_rule(action) when is_atom(action),
        do: Map.get(__rules__(), action)
    end
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
  defmacro action(name, do: block) do
    quote do
      # reset attributes from previous `action/2` calls
      Module.delete_attribute(__MODULE__, :allow_checks)
      Module.delete_attribute(__MODULE__, :deny_checks)
      Module.delete_attribute(__MODULE__, :pre_hooks)

      # compile inner block
      unquote(block)

      Module.put_attribute(__MODULE__, :actions, %{
        name: unquote(name),
        allow: get_acc_attribute(__MODULE__, :allow_checks),
        deny: get_acc_attribute(__MODULE__, :deny_checks),
        pre_hooks: get_acc_attribute(__MODULE__, :pre_hooks)
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
  defmacro allow(checks) do
    quote do
      Module.put_attribute(__MODULE__, :allow_checks, unquote(checks))
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
          object: unquote(name),
          pre_hooks: action.pre_hooks
        })
      end
    end
  end

  @doc """
  Registers one or multiple functions to run in order to hydrate the subject
  and/or object of the request.
  """
  defmacro pre_hooks(checks) do
    quote do
      Module.put_attribute(__MODULE__, :pre_hooks, unquote(checks))
    end
  end
end
