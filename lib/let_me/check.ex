defmodule LetMe.Check do
  @moduledoc """
  Struct that represents the evaluation result of a single check function.
  """

  @typedoc """
  Representation of a single policy check.

  - `name` - The function name in the configured check module.
  - `arg` - An argument passed to the check function. If set, the function is
    expected to be a 3-arity function that takes the subject, object, and the
    `arg` as arguments. If set to `nil`, the function is expected to be a
    2-arity function that only takes the subject and the object as arguments.
  - `result` - The original return value of the check function.
  - `passed?` - A boolean set depending on the return value of the check
    function.

  `result` and `passed?` are only set when the policy is evaluated, i.e., when
  the the `c:LetMe.Policy.authorize/4` or `c:LetMe.Policy.authorize!/4`
  functions are called.

  The `result` values `true`, `:ok`, and `{:ok, term}` are mapped to
  `passed?: true`. The result values `false`, `:error`, and `{:error, term}`
  are mapped to `passed?: false`.
  """
  @type t :: %__MODULE__{
          name: atom,
          arg: term,
          result: result() | nil,
          passed?: boolean | nil
        }

  @type result :: boolean | :ok | :error | {:ok, term} | {:error, term}

  defstruct [:name, :arg, :result, :passed?]
end
