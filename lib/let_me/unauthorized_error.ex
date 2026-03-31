defmodule LetMe.UnauthorizedError do
  @moduledoc """
  Raised by `c:LetMe.Policy.authorize!/4` if a request is unauthorized.
  """

  @default_message "unauthorized"

  @typedoc """
  Struct returned or raised if an authorization check fails.

  `expression` and `deny_checks` contains the parts of the policy expression
  that were performed and their results. Checks are evaluated lazily, and
  `deny` checks are always evaluated first.

  The expression reflects the checks until a decision is made, but it does not
  reflect the complete authorization policy.
  """
  @type t :: %__MODULE__{
          message: String.t(),
          expression: LetMe.expression() | nil
        }

  defexception [:message, :expression]

  def message(exception) do
    exception.message || @default_message
  end

  @spec new(String.t()) :: __MODULE__.t()
  def new(message \\ @default_message) do
    %__MODULE__{message: message}
  end

  @doc false
  def with_expression(expression) do
    %__MODULE__{
      message: @default_message,
      expression: expression
    }
  end
end
