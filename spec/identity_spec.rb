# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Identity::Ldap::Identity do
  subject(:identity) { described_class }

  describe 'provider contract' do
    it 'returns :ldap as provider_name' do
      expect(identity.provider_name).to eq(:ldap)
    end

    it 'returns :profile as provider_type' do
      expect(identity.provider_type).to eq(:profile)
    end

    it 'returns nil for facing (not applicable for profile providers)' do
      expect(identity.facing).to be_nil
    end

    it 'returns 0 for priority (not used for profile providers)' do
      expect(identity.priority).to eq(0)
    end

    it 'returns 10 for trust_weight (most authoritative for groups)' do
      expect(identity.trust_weight).to eq(10)
    end

    it 'returns :verified for trust_level' do
      expect(identity.trust_level).to eq(:verified)
    end

    it 'includes :profile and :groups in capabilities' do
      expect(identity.capabilities).to include(:profile, :groups)
    end
  end

  describe '#normalize' do
    it 'downcases and strips whitespace' do
      expect(identity.normalize('  USER123  ')).to eq('user123')
    end

    it 'handles nil-like by calling to_s' do
      expect(identity.normalize(nil)).to eq('')
    end

    it 'handles numeric input via to_s' do
      expect(identity.normalize(42)).to eq('42')
    end
  end

  describe '#resolve' do
    context 'when canonical_name normalizes to empty string' do
      it 'returns nil without querying LDAP' do
        expect(identity.resolve(canonical_name: '   ')).to be_nil
      end
    end

    context 'when LDAP is not configured (nil settings)' do
      let(:helper_double) { double('GroupSyncHelper') }

      before do
        allow(identity).to receive(:group_sync_helper).and_return(helper_double)
        allow(helper_double).to receive(:resolve_profile).and_return(nil)
      end

      it 'returns nil' do
        expect(identity.resolve(canonical_name: 'jdoe')).to be_nil
      end
    end

    context 'when LDAP lookup fails' do
      let(:helper_double) { double('GroupSyncHelper') }

      before do
        allow(identity).to receive(:group_sync_helper).and_return(helper_double)
        allow(helper_double).to receive(:resolve_profile)
          .and_return({ success: false, error: 'bind failed' })
      end

      it 'returns nil' do
        expect(identity.resolve(canonical_name: 'jdoe')).to be_nil
      end
    end

    context 'when LDAP lookup succeeds' do
      let(:groups) { ['CN=Admins,DC=example,DC=com', 'CN=Users,DC=example,DC=com'] }
      let(:profile) { { first_name: 'Jane', last_name: 'Doe', email: 'jdoe@example.com' } }
      let(:helper_double) { double('GroupSyncHelper') }

      before do
        allow(identity).to receive(:group_sync_helper).and_return(helper_double)
        allow(helper_double).to receive(:resolve_profile)
          .and_return({ success: true, groups: groups, profile: profile })
      end

      it 'returns enrichment hash with groups and profile' do
        result = identity.resolve(canonical_name: 'jdoe')
        expect(result).to eq({ groups: groups, profile: profile })
      end

      it 'normalizes the canonical_name before lookup' do
        expect(helper_double).to receive(:resolve_profile).with(canonical_name: 'jdoe')
        identity.resolve(canonical_name: 'JDOE')
      end
    end
  end

  describe 'provider type flags' do
    it 'does not respond to provide_token (not an auth provider)' do
      expect(identity).not_to respond_to(:provide_token)
    end

    it 'does not respond to vault_auth (not an auth provider)' do
      expect(identity).not_to respond_to(:vault_auth)
    end
  end
end
