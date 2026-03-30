defmodule LetMe.UnauthorizedError do
  @moduledoc """
  Raised by `c:LetMe.Policy.authorize!/4` if a request is unauthorized.
  """

  alias LetMe.AllOf
  alias LetMe.AnyOf
  alias LetMe.Check
  alias LetMe.Literal

  @default_message "unauthorized"

  @typedoc """
  Struct returned or raised if an authorization check fails.

  `allow_checks` and `deny_checks` contain the checks that were performed and
  their results. Checks are evaluated lazily, and `deny` checks are always
  evaluated first.

  The struct reflects the checks until a decision is made, but it does not
  reflect the complete authorization policy.
  """
  @type t :: %__MODULE__{
          message: String.t(),
          allow_checks: checks,
          deny_checks: checks
        }

  @type checks :: Check.t() | Literal.t() | AnyOf.t() | AllOf.t() | nil

  defexception [:message, :allow_checks, :deny_checks]

  def message(exception) do
    exception.message || @default_message
  end

  @spec new(String.t()) :: __MODULE__.t()
  def new(message \\ @default_message) do
    %__MODULE__{message: message}
  end

  @doc false
  def new(allow_checks, deny_checks) do
    %__MODULE__{
      message: @default_message,
      allow_checks: convert_checks(allow_checks),
      deny_checks: convert_checks(deny_checks)
    }
  end

  defp convert_checks([]), do: nil
  defp convert_checks([checks]), do: wrap_all_of(checks)

  defp convert_checks(checks) do
    %AnyOf{
      children:
        checks
        |> Enum.reverse()
        |> Enum.map(&wrap_all_of/1)
    }
  end

  defp wrap_all_of([check]), do: to_check(check)

  defp wrap_all_of(checks) do
    %AllOf{children: checks |> Enum.reverse() |> Enum.map(&to_check/1)}
  end

  defp to_check({{name, arg}, result}) do
    %Check{name: name, arg: arg, result: result}
  end

  defp to_check(bool) when is_boolean(bool) do
    %Literal{passed?: bool}
  end

  defp to_check({name, result}) do
    %Check{name: name, result: result}
  end
end
