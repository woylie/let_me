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

  defmacro allow(checks) do
    quote do
      Module.put_attribute(__MODULE__, :allow_checks, unquote(checks))
    end
  end

  defmacro disallow(checks) do
    quote do
      Module.put_attribute(__MODULE__, :disallow_checks, unquote(checks))
    end
  end

  defmacro pre_hooks(checks) do
    quote do
      Module.put_attribute(__MODULE__, :pre_hooks, unquote(checks))
    end
  end
end
