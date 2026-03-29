# Used by "mix format"

locals_without_parens = [
  allow: 1,
  deny: 1,
  desc: 1,
  metadata: 2,
  pre_hooks: 1
]

internal_locals_without_parens = [
  assert_authorized: 3,
  assert_authorized: 4,
  assert_unauthorized: 4,
  assert_unauthorized: 5
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 80,
  locals_without_parens:
    locals_without_parens ++ internal_locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
