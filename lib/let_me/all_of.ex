defmodule LetMe.AllOf do
  @moduledoc """
  Struct that represents a combination of checks that all must be true.
  """

  alias LetMe.Check
  alias LetMe.Literal

  @type t :: %__MODULE__{clauses: [Check.t() | Literal.t()]}

  defstruct clauses: []
end
