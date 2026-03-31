defmodule LetMe.Rule do
  @moduledoc """
  A struct for an authorization rule.
  """

  @typedoc """
  Struct for an authorization rule.

  - `action` - The action (verb) to be performed on the object, e.g. `:update`.
  - `expression` - A logical expression to determine whether the action is
    allowed.
  - `description` - A human-readable description of the action.
  - `name` - The name of the rule. Is always `{object}_{action}`.
  - `object` - The object that the action is performed on, e.g. `:article`.
  - `pre_hooks` - Functions to run in order to hydrate the subject and/or object
    before running the expression.
  - `metadata` - A list of relevant metadata useful for extending functionality.
  """
  @type t :: %__MODULE__{
          action: atom,
          expression: LetMe.expression(),
          description: String.t() | nil,
          name: atom,
          object: atom,
          pre_hooks: [hook],
          metadata: Keyword.t()
        }

  @typedoc """
  A `check` references a function in the configured check module.

  Can be either one of:

  - A function name as an atom. The function must be a 2-arity function that
    takes the subject (usually the current user) and the object as
    arguments.
  - A tuple with the function name as an atom and a value of any type. The
    function must be a 3-arity function that takes the subject, the object, and
    the given value as arguments.
  """
  @type check :: atom | {atom, any}

  @typedoc """
  A hook can be registered to hydrate the subject and/or object before passing
  them to the check functions.

  "Hydration" in this context means enriching or preparing the data by adding
  or transforming necessary information. For instance, you might fetch related
  data from the database, calculate derived properties, or format the data in a
  certain way.

  A hook can be one of the following:

  - The name of a function defined in the configured check module as an atom.
  - A `{module, function}` tuple.
  - A `{module, function, arguments}` tuple.

  In either case, the function must take the subject as the first argument, the
  object as the second argument, and return a tuple with the updated subject and
  object. If an MFA tuple is passed, the given arguments are appended to the
  default arguments.
  """
  @type hook :: atom | {module, atom} | {module, atom, any}

  @enforce_keys [:action, :name, :object]

  defstruct action: nil,
            expression: nil,
            description: nil,
            name: nil,
            object: nil,
            pre_hooks: [],
            metadata: []
end
