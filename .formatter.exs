# Used by "mix format"

locals_without_parens = [
  allow: 1,
  desc: 1,
  deny: 1,
  pre_hooks: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 80,
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
