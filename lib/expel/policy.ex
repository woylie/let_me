defmodule Expel.Policy do
  @moduledoc """
  Defines a DSL for writing authorization rules.

  ## Example

      defmodule MyApp.Policy do
        use Expel.Policy

        alias MyApp.Policy.Checks

        rules Checks do
          action :article_create do
            allow role: :admin
            allow role: :writer
          end

          action :article_update do
            allow :own_resource
          end

          action :article_view do
            allow true
          end
        end
      end
  """
  alias Expel.Rule

  @doc """
  Returns all authorization rules as a list.

  ## Example

      iex> MyApp.Policy.list_rules()
      [
        %Expel.Rule{
          action: :article_create,
          allow: [[role: :writer], [role: :editor]],
          disallow: [],
          pre_hooks: []
        },
        %Expel.Rule{
          action: :article_update,
          allow: [:own_resource],
          disallow: [],
          pre_hooks: [:preload_groups]
        }
      ]
  """
  @callback list_rules :: [Expel.Rule.t()]

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      Module.register_attribute(__MODULE__, :allow_checks, accumulate: true)
      Module.register_attribute(__MODULE__, :disallow_checks, accumulate: true)
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
      |> Enum.into(%{}, &{&1.action, &1})

    quote do
      @doc false
      def __rules__, do: unquote(Macro.escape(rules))

      @impl Expel.Policy
      def list_rules, do: Map.values(__rules__())
    end
  end

  defmacro rules(_checks_module, do: block) do
    quote do
      unquote(block)
    end
  end

  @doc """
  Defines an action that needs to be authorized.

  Within the do-block, you can use the `allow/1`, `disallow/1` and `pre_hooks/1`
  macros to define the checks to be run.

  ## Example

      action :article_create do
        allow role: :admin
        allow role: :writer
      end

      action :article_update do
        allow role: :admin
        allow [:own_resource, role: :writer]
      end
  """
  defmacro action(name, do: block) do
    quote do
      # reset attributes from previous `action/2` calls
      Module.delete_attribute(__MODULE__, :allow_checks)
      Module.delete_attribute(__MODULE__, :disallow_checks)
      Module.delete_attribute(__MODULE__, :pre_hooks)

      # compile inner block
      unquote(block)

      Module.put_attribute(__MODULE__, :rules, %Rule{
        action: unquote(name),
        allow: get_acc_attribute(__MODULE__, :allow_checks),
        disallow: get_acc_attribute(__MODULE__, :disallow_checks),
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
    `disallow/1` macro.

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

      action :article_update do
        allow role: :admin
      end

  This is equivalent to:

      action :article_update do
        allow {:role, :admin}
      end

  This would allow the `:article_update` action if the user has the role
  `:writer` _and_ the article belongs to the user:

      action :article_update do
        allow [:own_resource, role: :writer]
      end

  This is equivalent to:

      action :article_update do
        allow [:own_resource, {:role, :writer}]
      end

  This would allow the `:article_update` action if
  (the user has the role `:admin` _or_ (the user has the role `:writer` _and_
  the article belongs to the user)):

      action :article_update do
        allow role: :admin
        allow [:own_resource, role: :writer]
      end
  """
  defmacro allow(checks) do
    quote do
      Module.put_attribute(__MODULE__, :allow_checks, unquote(checks))
    end
  end

  @doc """
  Defines the checks to be run to determine if an action is disallowed.

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

      action :message do
        allow true
        disallow :same_user
      end

  This would allow the `:article_update` action only if the current user has
  the role `:admin`, _unless_ the object is the current user:

      action :user_delete do
        allow role: :admin
        disallow :same_user
      end

  This would allow the `:user_delete` by default, _unless_ the object is the
  current user _and_ the current user is an admin:

      action :message do
        allow true
        disallow [:same_user, role: :admin]
      end

  This would allow the `:user_delete` by default, _unless_ the object is the
  current user _or_ the current user is a peasant:

      action :user_delete do
        allow true
        disallow :same_user
        disallow role: :peasant
      end
  """
  defmacro disallow(checks) do
    quote do
      Module.put_attribute(__MODULE__, :disallow_checks, unquote(checks))
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
