defmodule LetMe.Check do
  @moduledoc """
  Struct that represents the evaluation result of a single check function.
  """

  @type t :: %__MODULE__{
          name: atom,
          arg: term,
          result: result(),
          passed?: boolean | nil
        }
  @type result :: boolean | :ok | :error | {:ok, term} | {:error, term} | nil

  defstruct [:name, :arg, :result, :passed?]
end
