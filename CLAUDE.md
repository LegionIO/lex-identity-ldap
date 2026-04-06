# lex-identity-ldap: LDAP Identity Profile Provider for LegionIO

**Repository Level 3 Documentation**
- **Parent (Level 2)**: `/Users/miverso2/rubymine/legion/extensions/CLAUDE.md`
- **Parent (Level 1)**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

LegionIO identity **profile provider** that enriches identity with group memberships and profile data from LDAP / Active Directory. This is a `:profile` type provider — it cannot set `canonical_name` (only auth providers can). It looks up users by `sAMAccountName` and returns `memberOf` groups plus profile attributes.

**GitHub**: https://github.com/LegionIO/lex-identity-ldap
**License**: MIT
**Version**: 0.1.0

## Architecture

```
Legion::Extensions::Identity::Ldap
├── Identity              # Provider contract module (profile, :ldap, trust_weight 10)
├── Helpers/
│   └── GroupSync         # LDAP user lookup + profile extraction via net-ldap
└── Actor/
    └── GroupRefresh      # Every 6h: re-sync group memberships for known principals
```

## File Map

| File | Purpose |
|------|---------|
| `lib/legion/extensions/identity/ldap.rb` | Entry point; requires all modules; extends Core; declares `identity_provider?` and `remote_invocable?` |
| `lib/legion/extensions/identity/ldap/identity.rb` | Profile provider contract: `provider_name`, `provider_type`, `facing`, `priority`, `trust_weight`, `capabilities`, `resolve`, `normalize` |
| `lib/legion/extensions/identity/ldap/helpers/group_sync.rb` | LDAP search via `net-ldap`; settings resolution; TLS; `resolve_profile` returns `{ success:, groups:, profile: }` |
| `lib/legion/extensions/identity/ldap/actors/group_refresh.rb` | Interval actor (6h); syncs known principals from cache; status transitions: active/stale/expired |
| `lib/legion/extensions/identity/ldap/version.rb` | `VERSION = '0.1.0'` |

## Key Patterns

### Provider Contract

`Identity` is `extend self` — all methods are module-level. `resolve(canonical_name:)` normalizes the name, calls `resolve_profile`, and returns `{ groups: [...], profile: {...} }` or `nil`.

### Settings Resolution

`Helpers::GroupSync#ldap_settings` checks `Legion::Settings.dig(:identity, :ldap)` first. If nil, falls back to `Legion::Settings.dig(:kerberos, :ldap)` for backward compatibility with `lex-kerberos` deployments. Returns nil if `Legion::Settings` is not defined.

### Group Status Tracking

`Actor::GroupRefresh` maintains a cache key `identity:ldap:groups:{canonical_name}` with a hash of `{ dn => { status:, last_seen:, first_seen: } }`. Status transitions:
- Present in sync → `:active`
- Absent from sync → `:stale`
- Stale for > 24h (86400s) → `:expired`

Known principals are stored at `identity:ldap:principals` in Legion::Cache.

## Settings Reference

```json
{
  "identity": {
    "ldap": {
      "host": null,
      "port": 636,
      "encryption": "simple_tls",
      "base_dn": null,
      "bind_dn": null,
      "bind_password": null,
      "user_filter": "(sAMAccountName=%<username>s)",
      "group_attribute": "memberOf"
    }
  }
}
```

If `identity.ldap.host` is nil, `resolve` returns nil without connecting.

## Dependencies

| Gem | Purpose |
|-----|---------|
| `net-ldap` (~> 0.19) | LDAP queries against Active Directory |
| `legion-settings` (>= 1.3.14) | Settings resolution |
| `legion-json` (>= 1.2.1) | JSON serialization |

## Testing

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

---

**Maintained By**: Matthew Iverson (@Esity)
