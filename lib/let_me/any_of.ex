defmodule LetMe.AnyOf do
  @moduledoc """
  Struct that represents a combination of checks one of which must be true.
  """

  alias LetMe.AllOf
  alias LetMe.CheckResult
  alias LetMe.Literal

  @type t :: %__MODULE__{clauses: [CheckResult.t() | Literal.t() | AllOf.t()]}

  defstruct clauses: []
end
