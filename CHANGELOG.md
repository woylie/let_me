# Changelog

## Unreleased

### Added

- Added `c:LetMe.Policy.filter_allowed_actions/3` and
  `LetMe.filter_allowed_actions/4`.

## [0.2.0] - 2022-07-12

### Changed

- Added support for nested field redactions, either by explicitly listing the
  fields or by referencing a module that also implements `LetMe.Schema`.

### Fixed

- `reject_redacted_fields/3` called `redact/2` callback with the wrong argument
  order.

## [0.1.0] - 2022-07-11

initial release
