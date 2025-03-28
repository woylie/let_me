# Changelog

## Unreleased

## [1.2.5] - 2025-03-26

### Changed

- Improve documentation.

## [1.2.4] - 2024-04-22

### Fixed

- Nested lists within structs resulted in a `CaseClauseError` during redaction.

## [1.2.3] - 2023-11-11

### Changed

- Updated documentation.

## [1.2.2] - 2023-06-28

### Changed

- You can now override the exception message used by
  `c:LetMe.Policy.authorize!/4` (e.g.
  `use LetMe.Policy, error_message: "Not today, chap."`).

## [1.2.1] - 2023-06-28

### Changed

- Define `action` type when you `use LetMe.Policy`.
- Add type specifications for generated `authorize` functions.

## [1.2.0] - 2023-06-19

### Added

- Added an optional `opts` argument to the authorize functions, so that
  additional options can be passed to pre-hooks.
- Updated `LetMe.filter_rules/2` to allow filtering by meta data.

### Changed

- Pre-hook options are now expected to be passed as a keyword list.

### Fixed

- Fix deprecation warning about `Logger.warn/2` in Elixir 1.15.

## [1.1.0] - 2023-05-08

### Added

- Added a `metadata` macro to add metadata to actions. The metadata can be read
  from the `LetMe.Rule` struct.

## [1.0.3] - 2023-03-21

### Changed

- Update `ex_doc` and other dev dependencies.

## [1.0.2] - 2023-01-05

### Added

- Added a cheat sheet for rules and checks.

### Fixed

- Fixed a code example for rule introspection in the readme.

## [1.0.1] - 2022-11-06

### Changed

- Use `Keyword.pop/3` with default value instead of `Keyword.pop!/2`, so that
  you can pass options to `LetMe.redact/3` without passing the `redact_value`
  option.

## [1.0.0] - 2022-11-06

### Added

- Added `c:LetMe.Policy.filter_allowed_actions/3` and
  `LetMe.filter_allowed_actions/4`.
- Added `c:LetMe.Policy.get_object_name/1`.

### Changed

- Renamed `c:LetMe.Policy.authorized?/3` to `c:LetMe.Policy.authorize?/3`,
  because consistency is more important than grammar, maybe.
- The `c:LetMe.Schema.scope/2` callback was removed in favour of
  `c:LetMe.Schema.scope/3`. The `__using__` macro defined default
  implementations for both functions that returned the given query unchanged, in
  case you only needed the `redact` callback of the behaviour. In practice, this
  made it all too easy to call the 2-arity version when only the 3-arity
  version was defined, and vice versa, which would lead the query to not be
  scoped. So in order to reduce the room for error at the cost of a minor
  inconvenience, you will now always need to implement the 3-arity function,
  even if you don't need the third argument.
- Changed `c:LetMe.Schema.redacted_fields/2` to
  `c:LetMe.Schema.redacted_fields/3` to allow passing additional options, and to
  be consistent with `c:LetMe.Schema.scope/3`.

## [0.2.0] - 2022-07-12

### Changed

- Added support for nested field redactions, either by explicitly listing the
  fields or by referencing a module that also implements `LetMe.Schema`.

### Fixed

- `reject_redacted_fields/3` called `redact/2` callback with the wrong argument
  order.

## [0.1.0] - 2022-07-11

initial release
