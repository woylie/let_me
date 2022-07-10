defmodule Expel.Rule do
  @moduledoc """
  A struct for an authorization rule.
  """

  @typedoc """
  Struct for an authorization rule.

  - `action` - The action (verb) to be performed on the object, e.g. `:update`.
  - `allow` - A list of lists of checks to run to determine whether the action
    is allowed. The outer list contains the alternatives (one for each `allow`
    call; combined with `OR`). The inner lists are the checks for each `allow`
    (combined with `AND`).
  - `description` - A human-readable description of the action.
  - `deny` - A list of lists of checks to run to determine whether the action is
    explicitly denied. Same format as in `allow`. If any of these checks returns
    `true`, the end result of the authorization request is immediately `false`,
    even if any of the checks in the `allow` field would return `true`.
  - `name` - The name of the rule. Is always `{object}_{action}`.
  - `object` - The object that the action is performed on, e.g. `:article`.
  - `pre_hooks` - Functions to run in order to hydrate the subject and/or object
    before running the allow and deny checks.

  The list entries in the outer list of the `allow` and `deny` fields are
  combined with a logical `OR`. If one of the entries is a list of checks, those
  checks are combined with a logical `AND`.

  ## Examples

  - `[{role: :editor}, {role: :writer}]` - role is editor OR role is writer
  - `[[{role: :editor}], [{role: :writer}]]` - same as above
  - `[[{role: :editor}], [{role: :writer}, {:own_resource}]]` -
     (role is editor OR (role is writer AND object is the user's own resource))
  """
  @type t :: %__MODULE__{
          action: atom,
          allow: [check | [check]],
          deny: [check | [check]],
          description: String.t() | nil,
          name: atom,
          object: atom,
          pre_hooks: [hook]
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

  Can be either one of:

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
            allow: [],
            deny: [],
            description: nil,
            name: nil,
            object: nil,
            pre_hooks: []
end
