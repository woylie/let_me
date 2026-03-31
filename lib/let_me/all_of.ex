defmodule LetMe.AllOf do
  @moduledoc """
  Struct that represents a combination of expressions that all must be true.

  An `AllOf` without children evaluates to `true`.
  """

  @type t :: %__MODULE__{
          children: [LetMe.expression()],
          passed?: boolean | nil
        }

  defstruct [:passed?, children: []]
end
