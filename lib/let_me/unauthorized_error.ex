defmodule LetMe.UnauthorizedError do
  @moduledoc """
  Raised by `c:LetMe.Policy.authorize!/4` if a request is unauthorized.
  """

  @default_message "unauthorized"

  @typedoc """
  Struct returned or raised if an authorization check fails.

  `expression` contains the parts of the policy expression that were evaluated
  and their results. Checks are evaluated lazily. The evaluation order follows
  the expression as `Spek.optimize/1` rewrote it at compile time, which is not
  the order the `allow/1` and `deny/1` calls were written in.

  The expression reflects the checks until a decision is made, but it does not
  reflect the complete authorization policy.
  """
  @type t :: %__MODULE__{
          message: String.t(),
          expression: Spek.expression() | nil
        }

  defexception [:message, :expression]

  @impl Exception
  @spec message(t()) :: String.t()
  def message(exception) do
    exception.message || @default_message
  end

  @doc """
  Returns an error struct with the given message and without an expression.

  ## Examples

      iex> LetMe.UnauthorizedError.new()
      %LetMe.UnauthorizedError{message: "unauthorized", expression: nil}

      iex> LetMe.UnauthorizedError.new("forbidden")
      %LetMe.UnauthorizedError{message: "forbidden", expression: nil}
  """
  @spec new(String.t()) :: t()
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
