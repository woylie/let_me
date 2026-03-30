defmodule LetMe.AnyOf do
  @moduledoc """
  Struct that represents a combination of checks one of which must be true.
  """

  alias LetMe.AllOf
  alias LetMe.Check
  alias LetMe.Literal

  @type t :: %__MODULE__{children: [Check.t() | Literal.t() | AllOf.t()]}

  defstruct children: []
end
