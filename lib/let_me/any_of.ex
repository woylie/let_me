defmodule LetMe.AnyOf do
  @moduledoc """
  Struct that represents a combination of checks one of which must be true.

  An `AnyOf` without children evaluates to `false`.
  """

  @type t :: %__MODULE__{
          children: [LetMe.expression()],
          passed?: boolean | nil
        }

  defstruct [:passed?, children: []]
end
