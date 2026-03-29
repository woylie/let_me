defmodule LetMe.CheckResult do
  @moduledoc """
  Struct that represents the evaluation result of a single check function.
  """

  @type t :: %__MODULE__{name: atom, arg: term, result: result()}
  @type result :: boolean | :ok | :error | {:ok, term} | {:error, term}

  defstruct [:name, :arg, :result]
end
