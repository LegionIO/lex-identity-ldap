# lex-identity-ldap

LegionIO identity **profile provider** that enriches identity with group memberships and profile data from LDAP / Active Directory.

This is a `:profile` type provider — it enriches identities that have already been authenticated by an auth provider. It cannot set `canonical_name`.

## Features

- Looks up users by `sAMAccountName` against Active Directory
- Returns `memberOf` group DNs for authorization decisions
- Extracts profile attributes: `first_name`, `last_name`, `email`, `display_name`, `department`, `title`
- TLS support (`simple_tls`)
- Falls back to `kerberos.ldap` settings for backward compatibility with `lex-kerberos`
- Periodic group refresh actor (every 6 hours) with `active`/`stale`/`expired` status tracking

## Provider Contract

| Property | Value |
|----------|-------|
| `provider_name` | `:ldap` |
| `provider_type` | `:profile` |
| `trust_weight` | `10` |
| `capabilities` | `[:profile, :groups]` |

## Configuration

```json
{
  "identity": {
    "ldap": {
      "host": "dc.example.com",
      "port": 636,
      "encryption": "simple_tls",
      "base_dn": "DC=example,DC=com",
      "bind_dn": "CN=svc-legion,OU=Service Accounts,DC=example,DC=com",
      "bind_password": "vault://secret/ldap#bind_password",
      "user_filter": "(sAMAccountName=%<username>s)",
      "group_attribute": "memberOf",
      "profile_attributes": {
        "givenName": "first_name",
        "sn": "last_name",
        "mail": "email",
        "displayName": "display_name",
        "department": "department",
        "title": "title"
      }
    }
  }
}
```

If `identity.ldap` is not set, the provider falls back to `kerberos.ldap` settings.

## Usage

```ruby
result = Legion::Extensions::Identity::Ldap::Identity.resolve(canonical_name: 'jdoe')
# => {
#      groups: ["CN=Admins,DC=example,DC=com", ...],
#      profile: { first_name: "Jane", last_name: "Doe", email: "jdoe@example.com", ... }
#    }
```

Returns `nil` if LDAP is not configured or the user is not found.

## License

MIT
