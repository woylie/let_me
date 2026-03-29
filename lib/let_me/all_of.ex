defmodule LetMe.AllOf do
  @moduledoc """
  Struct that represents a combination of checks that all must be true.
  """

  alias LetMe.CheckResult
  alias LetMe.Literal

  @type t :: %__MODULE__{clauses: [CheckResult.t() | Literal.t()]}

  defstruct clauses: []
end
