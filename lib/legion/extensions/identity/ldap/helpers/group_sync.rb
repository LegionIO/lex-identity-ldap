# frozen_string_literal: true

require 'net-ldap'

module Legion
  module Extensions
    module Identity
      module Ldap
        module Helpers
          module GroupSync
            PROFILE_ATTRIBUTES = {
              first_name:   :givenname,
              last_name:    :sn,
              email:        :mail,
              display_name: :displayname,
              department:   :department,
              title:        :title
            }.freeze

            USER_ATTRIBUTES = %w[memberOf givenName sn mail displayName department title].freeze

            def resolve_profile(canonical_name:)
              cfg = ldap_settings
              return nil if cfg.nil? || cfg[:host].nil?

              ldap = build_ldap_client(cfg)
              return { success: false, error: 'LDAP bind failed' } unless ldap.bind

              search_user(
                ldap:            ldap,
                username:        canonical_name,
                base_dn:         cfg[:base_dn],
                user_filter:     cfg.fetch(:user_filter, '(sAMAccountName=%<username>s)'),
                group_attribute: cfg.fetch(:group_attribute, 'memberOf')
              )
            rescue Net::LDAP::Error => e
              { success: false, error: "LDAP error: #{e.message}" }
            end

            private

            def ldap_settings
              return unless defined?(Legion::Settings) && Legion::Settings.respond_to?(:dig)

              cfg = Legion::Settings.dig(:identity, :ldap)
              cfg = Legion::Settings.dig(:kerberos, :ldap) if cfg.nil?
              cfg
            end

            def build_ldap_client(cfg)
              opts = {
                host: cfg[:host],
                port: cfg.fetch(:port, 636),
                auth: { method: :simple, username: cfg[:bind_dn], password: cfg[:bind_password] }
              }
              encryption = cfg.fetch(:encryption, 'simple_tls')
              opts[:encryption] = { method: encryption.to_sym } if encryption
              Net::LDAP.new(opts)
            end

            def search_user(ldap:, username:, base_dn:, user_filter:, group_attribute:)
              filter = Net::LDAP::Filter.construct(format(user_filter, username: username))
              groups = []
              profile = {}
              ldap.search(base: base_dn, filter: filter, attributes: USER_ATTRIBUTES) do |entry|
                groups.concat(Array(entry[group_attribute]).map(&:to_s))
                profile = extract_profile(entry)
              end
              { success: true, groups: groups, profile: profile }
            end

            def extract_profile(entry)
              PROFILE_ATTRIBUTES.transform_values { |attr| entry[attr]&.first&.to_s }.compact
            end
          end
        end
      end
    end
  end
end
