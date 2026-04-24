# Changelog

## [Unreleased]

## [0.2.0] - 2026-04-24

### Added
- `trust_level` method returning `:verified` on provider contract
- Self-registration with `Legion::Identity::Resolver` at load time

## [0.1.0] - 2026-04-06

### Added
- Initial release of `lex-identity-ldap`
- `Identity` module implementing the profile provider contract (`provider_name`, `provider_type`, `facing`, `priority`, `trust_weight`, `capabilities`, `resolve`, `normalize`)
- `Helpers::GroupSync` module for LDAP user lookup via `net-ldap`: binds with service account, searches by `sAMAccountName` filter, returns `memberOf` groups and profile attributes (`first_name`, `last_name`, `email`, `display_name`, `department`, `title`)
- TLS support via `simple_tls` encryption option
- Settings resolution from `Legion::Settings.dig(:identity, :ldap)` with fallback to `Legion::Settings.dig(:kerberos, :ldap)` for backward compatibility with lex-kerberos LDAP config
- `Actors::GroupRefresh` interval actor (every 6 hours) that re-syncs group memberships for known principals with `active`/`stale`/`expired` status tracking
- `run_now? false` — initial group population comes from `Identity#resolve`, not from boot-time actor run
