defmodule LetMe.Literal do
  @moduledoc """
  Struct that represents an authorization rule that evaluates to a fixed value.
  """

  @type t :: %__MODULE__{passed?: boolean}

  defstruct [:passed?]
end
