# frozen_string_literal: true

require 'legion/extensions/identity/ldap/helpers/group_sync'

module Legion
  module Extensions
    module Identity
      module Ldap
        module Identity
          extend self
          include Helpers::GroupSync

          def provider_name  = :ldap
          def provider_type  = :profile
          def facing         = nil
          def priority       = 0
          def trust_weight   = 10
          def capabilities   = %i[profile groups]

          def resolve(canonical_name:)
            name = normalize(canonical_name)
            return nil if name.empty?

            result = resolve_profile(canonical_name: name)
            return nil if result.nil?
            return nil unless result[:success]

            { groups: result[:groups], profile: result[:profile] }
          end

          def normalize(val)
            val.to_s.downcase.strip
          end
        end
      end
    end
  end
end
