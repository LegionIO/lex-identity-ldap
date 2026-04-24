# frozen_string_literal: true

require 'legion/extensions/identity/ldap/version'
require 'legion/extensions/identity/ldap/helpers/group_sync'
require 'legion/extensions/identity/ldap/identity'
require 'legion/extensions/identity/ldap/actors/group_refresh'

module Legion
  module Extensions
    module Identity
      module Ldap
        extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core, false)

        def self.identity_provider? = true
        def self.remote_invocable?  = false
      end
    end
  end
end

if defined?(Legion::Identity::Resolver)
  Legion::Identity::Resolver.register(Legion::Extensions::Identity::Ldap::Identity)
elsif defined?(Legion::Identity) && Legion::Identity.respond_to?(:pending_registrations)
  Legion::Identity.pending_registrations << Legion::Extensions::Identity::Ldap::Identity
end
