defmodule LetMe.Not do
  @moduledoc """
  Struct that represents a boolean negation.
  """

  @type t :: %__MODULE__{
          expression: LetMe.expression(),
          passed?: boolean | nil
        }

  defstruct [:expression, :passed?]
end
