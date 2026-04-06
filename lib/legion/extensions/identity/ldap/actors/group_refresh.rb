# frozen_string_literal: true

require 'legion/extensions/actors/every'

module Legion
  module Extensions
    module Identity
      module Ldap
        module Actor
          class GroupRefresh < Legion::Extensions::Actors::Every # rubocop:disable Legion/Extension/SelfContainedActorRunnerClass, Legion/Extension/EveryActorRequiresTime
            STALE_THRESHOLD  = 86_400
            ACTIVE_STATUS    = :active
            STALE_STATUS     = :stale
            EXPIRED_STATUS   = :expired

            def initialize(**opts)
              return unless enabled?

              super
            end

            def time      = 21_600
            def run_now?  = false
            def use_runner?    = false
            def check_subtask? = false
            def generate_task? = false

            def enabled? # rubocop:disable Legion/Extension/ActorEnabledSideEffects
              defined?(Legion::Extensions::Identity::Ldap::Helpers::GroupSync)
            rescue StandardError => _e
              false
            end

            def manual
              sync_known_principals
            rescue StandardError => e
              log.error("GroupRefresh: #{e.message}")
            end

            private

            def sync_known_principals
              principals = known_principals
              return log.debug('GroupRefresh: no known principals to sync') if principals.empty?

              principals.each { |name| sync_principal(name) }
            end

            def known_principals
              return [] unless defined?(Legion::Cache) && Legion::Cache.respond_to?(:get)

              raw = cache_get('identity:ldap:principals')
              return [] if raw.nil?

              Array(raw)
            end

            def sync_principal(canonical_name)
              helper = Object.new.extend(Helpers::GroupSync)
              result = helper.resolve_profile(canonical_name: canonical_name)
              update_group_statuses(canonical_name, result)
            end

            def update_group_statuses(canonical_name, result)
              unless result.is_a?(Hash) && result[:success]
                log.warn("GroupRefresh: failed to sync #{canonical_name}")
                return
              end

              current_groups = Set.new(result[:groups])
              update_cached_statuses(canonical_name, current_groups)
            end

            def update_cached_statuses(canonical_name, current_groups)
              return unless defined?(Legion::Cache) && Legion::Cache.respond_to?(:get)

              key = "identity:ldap:groups:#{canonical_name}"
              cached = cache_get(key) || {}
              now = Time.now.to_i
              updated = reconcile_statuses(cached, current_groups, now)
              cache_set(key, updated) if Legion::Cache.respond_to?(:set)
            end

            def reconcile_statuses(cached, current_groups, now)
              updated = {}
              cached.each do |dn, entry|
                updated[dn] = if current_groups.include?(dn)
                                entry.merge(status: ACTIVE_STATUS, last_seen: now)
                              elsif stale_expired?(entry, now)
                                entry.merge(status: EXPIRED_STATUS)
                              else
                                entry.merge(status: STALE_STATUS)
                              end
              end
              current_groups.each do |dn|
                updated[dn] ||= { status: ACTIVE_STATUS, last_seen: now, first_seen: now }
              end
              updated
            end

            def stale_expired?(entry, now)
              last_seen = entry[:last_seen]
              last_seen && (now - last_seen) > STALE_THRESHOLD
            end

            include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                        Legion::Extensions::Helpers.const_defined?(:Lex, false)
          end
        end
      end
    end
  end
end
