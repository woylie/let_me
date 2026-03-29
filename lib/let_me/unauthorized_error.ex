defmodule LetMe.UnauthorizedError do
  @moduledoc """
  Raised by `c:LetMe.Policy.authorize!/4` if a request is unauthorized.
  """

  alias LetMe.AllOf
  alias LetMe.AnyOf
  alias LetMe.CheckResult
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
          allow_checks: CheckResult.t() | Literal.t() | AnyOf.t() | AllOf.t(),
          deny_checks: CheckResult.t() | Literal.t() | AnyOf.t() | AllOf.t()
        }

  defexception [:message, :allow_checks, :deny_checks]

  def message(exception) do
    exception.message || @default_message
  end

  @doc false
  def new(allow_checks \\ [], deny_checks \\ []) do
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
      clauses:
        checks
        |> Enum.reverse()
        |> Enum.map(&wrap_all_of/1)
    }
  end

  defp wrap_all_of([check]), do: to_check(check)

  defp wrap_all_of(checks) do
    %AllOf{clauses: checks |> Enum.reverse() |> Enum.map(&to_check/1)}
  end

  defp to_check({{name, arg}, result}) do
    %CheckResult{name: name, arg: arg, result: result}
  end

  defp to_check(bool) when is_boolean(bool) do
    %Literal{result: bool}
  end

  defp to_check({bool, bool}) when is_boolean(bool) do
    %Literal{result: bool}
  end

  defp to_check({name, result}) do
    %CheckResult{name: name, result: result}
  end
end
