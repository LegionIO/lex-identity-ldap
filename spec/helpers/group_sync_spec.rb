# frozen_string_literal: true

require 'spec_helper'
require 'net-ldap'
require 'legion/extensions/identity/ldap/helpers/group_sync'

RSpec.describe Legion::Extensions::Identity::Ldap::Helpers::GroupSync do
  subject(:helper) { Object.new.extend(described_class) }

  let(:mock_ldap) { instance_double(Net::LDAP) }

  let(:ldap_settings) do
    {
      host: 'dc.example.com',
      port: 636,
      encryption: 'simple_tls',
      base_dn: 'DC=example,DC=com',
      bind_dn: 'CN=svc-legion,DC=example,DC=com',
      bind_password: 'secret',
      user_filter: '(sAMAccountName=%<username>s)',
      group_attribute: 'memberOf'
    }
  end

  before do
    allow(Net::LDAP).to receive(:new).and_return(mock_ldap)
    allow(mock_ldap).to receive(:bind).and_return(true)
  end

  def stub_ldap_settings(settings)
    legion_settings = Module.new do
      define_method(:dig) do |*keys|
        keys.reduce(settings) { |h, k| h.is_a?(Hash) ? h[k] : nil }
      end
      def self.respond_to?(name, _include_private = false)
        name == :dig || super
      end
    end
    stub_const('Legion::Settings', legion_settings)
  end

  describe '#resolve_profile' do
    context 'when LDAP is not configured (no host)' do
      it 'returns nil when settings are nil' do
        allow(helper).to receive(:ldap_settings).and_return(nil)
        expect(helper.resolve_profile(canonical_name: 'jdoe')).to be_nil
      end

      it 'returns nil when host is nil' do
        allow(helper).to receive(:ldap_settings).and_return({ host: nil })
        expect(helper.resolve_profile(canonical_name: 'jdoe')).to be_nil
      end
    end

    context 'when LDAP bind fails' do
      before do
        allow(helper).to receive(:ldap_settings).and_return(ldap_settings)
        allow(mock_ldap).to receive(:bind).and_return(false)
      end

      it 'returns failure hash' do
        result = helper.resolve_profile(canonical_name: 'jdoe')
        expect(result[:success]).to be false
        expect(result[:error]).to include('bind failed')
      end
    end

    context 'when user is found with groups' do
      let(:ldap_entry) do
        entry = Net::LDAP::Entry.new('CN=jdoe,OU=Users,DC=example,DC=com')
        entry['memberOf'] = [
          'CN=Admins,OU=Groups,DC=example,DC=com',
          'CN=Users,OU=Groups,DC=example,DC=com'
        ]
        entry['givenName']    = ['Jane']
        entry['sn']           = ['Doe']
        entry['mail']         = ['jdoe@example.com']
        entry['displayName']  = ['Jane Doe']
        entry['department']   = ['Engineering']
        entry['title']        = ['Staff Engineer']
        entry
      end

      before do
        allow(helper).to receive(:ldap_settings).and_return(ldap_settings)
        allow(mock_ldap).to receive(:search).and_yield(ldap_entry)
      end

      it 'returns success with groups' do
        result = helper.resolve_profile(canonical_name: 'jdoe')
        expect(result[:success]).to be true
        expect(result[:groups]).to include('CN=Admins,OU=Groups,DC=example,DC=com')
        expect(result[:groups].length).to eq(2)
      end

      it 'returns profile attributes' do
        result = helper.resolve_profile(canonical_name: 'jdoe')
        expect(result[:profile][:first_name]).to eq('Jane')
        expect(result[:profile][:last_name]).to eq('Doe')
        expect(result[:profile][:email]).to eq('jdoe@example.com')
        expect(result[:profile][:display_name]).to eq('Jane Doe')
        expect(result[:profile][:department]).to eq('Engineering')
        expect(result[:profile][:title]).to eq('Staff Engineer')
      end
    end

    context 'when user is not found' do
      before do
        allow(helper).to receive(:ldap_settings).and_return(ldap_settings)
        allow(mock_ldap).to receive(:search)
      end

      it 'returns success with empty groups and profile' do
        result = helper.resolve_profile(canonical_name: 'nobody')
        expect(result[:success]).to be true
        expect(result[:groups]).to be_empty
        expect(result[:profile]).to be_empty
      end
    end

    context 'when Net::LDAP raises an error' do
      before do
        allow(helper).to receive(:ldap_settings).and_return(ldap_settings)
        allow(mock_ldap).to receive(:bind).and_raise(Net::LDAP::Error, 'connection refused')
      end

      it 'returns failure with error message' do
        result = helper.resolve_profile(canonical_name: 'jdoe')
        expect(result[:success]).to be false
        expect(result[:error]).to include('connection refused')
      end
    end

    context 'with TLS configuration' do
      before do
        allow(helper).to receive(:ldap_settings).and_return(ldap_settings)
        allow(mock_ldap).to receive(:search)
      end

      it 'passes encryption option to Net::LDAP' do
        expect(Net::LDAP).to receive(:new).with(
          hash_including(encryption: { method: :simple_tls })
        ).and_return(mock_ldap)
        helper.resolve_profile(canonical_name: 'jdoe')
      end
    end

    context 'when TLS encryption is nil or absent' do
      let(:settings_no_tls) { ldap_settings.merge(encryption: nil) }

      before do
        allow(helper).to receive(:ldap_settings).and_return(settings_no_tls)
        allow(mock_ldap).to receive(:search)
      end

      it 'does not pass encryption option to Net::LDAP' do
        expect(Net::LDAP).to receive(:new).with(
          hash_excluding(:encryption)
        ).and_return(mock_ldap)
        helper.resolve_profile(canonical_name: 'jdoe')
      end
    end

    context 'settings fallback to kerberos.ldap' do
      before do
        allow(helper).to receive(:ldap_settings).and_call_original
        allow(mock_ldap).to receive(:search).and_yield(Net::LDAP::Entry.new('CN=jdoe'))
      end

      it 'falls back to kerberos.ldap settings when identity.ldap is nil' do
        kerberos_ldap_settings = {
          identity: { ldap: nil },
          kerberos: { ldap: ldap_settings }
        }

        legion_settings = Module.new do
          define_method(:dig) do |*keys|
            keys.reduce(kerberos_ldap_settings) { |h, k| h.is_a?(Hash) ? h[k] : nil }
          end
          define_method(:respond_to?) { |name, _include_private = false| name == :dig || super }
        end
        stub_const('Legion::Settings', legion_settings)

        result = helper.resolve_profile(canonical_name: 'jdoe')
        expect(result[:success]).to be true
      end
    end
  end
end
