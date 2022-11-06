# Changelog

## Unreleased

### Added

- Added `c:LetMe.Policy.filter_allowed_actions/3` and
  `LetMe.filter_allowed_actions/4`.
- Added `c:LetMe.Policy.get_object_name/1`.

### Changed

- Renamed `c:LetMe.Policy.authorized?/3` to `c:LetMe.Policy.authorize?/3`,
  because consistency is more important than grammar, maybe.

## [0.2.0] - 2022-07-12

### Changed

- Added support for nested field redactions, either by explicitly listing the
  fields or by referencing a module that also implements `LetMe.Schema`.

### Fixed

- `reject_redacted_fields/3` called `redact/2` callback with the wrong argument
  order.

## [0.1.0] - 2022-07-11

initial release
