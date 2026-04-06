# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Identity::Ldap::Actor::GroupRefresh do
  subject(:actor) { described_class.allocate }

  describe 'configuration' do
    it 'runs every 6 hours' do
      expect(actor.time).to eq(21_600)
    end

    it 'does not run immediately at boot' do
      expect(actor.run_now?).to be false
    end

    it 'does not use framework runner dispatch' do
      expect(actor.use_runner?).to be false
    end

    it 'does not check subtasks' do
      expect(actor.check_subtask?).to be false
    end

    it 'does not generate tasks' do
      expect(actor.generate_task?).to be false
    end
  end

  describe '#enabled?' do
    it 'returns truthy when GroupSync helper is defined' do
      expect(actor.enabled?).to be_truthy
    end
  end

  describe '#manual' do
    context 'when no known principals are cached' do
      before do
        allow(actor).to receive(:known_principals).and_return([])
      end

      it 'does not raise' do
        expect { actor.manual }.not_to raise_error
      end
    end

    context 'when principals are cached' do
      before do
        allow(actor).to receive(:known_principals).and_return(%w[jdoe])
        allow(actor).to receive(:sync_principal)
      end

      it 'calls sync_principal for each known principal and does not raise' do
        expect { actor.manual }.not_to raise_error
        expect(actor).to have_received(:sync_principal).with('jdoe')
      end
    end

    context 'when sync raises a StandardError' do
      before do
        allow(actor).to receive(:sync_known_principals).and_raise(StandardError, 'boom')
      end

      it 'logs the error and does not re-raise' do
        expect { actor.manual }.not_to raise_error
      end
    end
  end

  describe 'group status transitions' do
    subject(:actor_instance) { described_class.allocate }

    let(:now) { Time.now.to_i }

    describe '#reconcile_statuses (via private interface)' do
      it 'marks groups present in current sync as active' do
        cached = { 'CN=Admins' => { status: :stale, last_seen: now - 100, first_seen: now - 200 } }
        current = Set.new(['CN=Admins'])
        result = actor_instance.send(:reconcile_statuses, cached, current, now)
        expect(result['CN=Admins'][:status]).to eq(:active)
      end

      it 'marks groups absent from sync as stale' do
        cached = { 'CN=Admins' => { status: :active, last_seen: now - 100, first_seen: now - 200 } }
        current = Set.new([])
        result = actor_instance.send(:reconcile_statuses, cached, current, now)
        expect(result['CN=Admins'][:status]).to eq(:stale)
      end

      it 'marks stale groups older than 24h as expired' do
        old_time = now - 90_000
        cached = { 'CN=Admins' => { status: :stale, last_seen: old_time, first_seen: old_time } }
        current = Set.new([])
        result = actor_instance.send(:reconcile_statuses, cached, current, now)
        expect(result['CN=Admins'][:status]).to eq(:expired)
      end

      it 'adds new groups from current sync' do
        cached = {}
        current = Set.new(['CN=NewGroup'])
        result = actor_instance.send(:reconcile_statuses, cached, current, now)
        expect(result['CN=NewGroup'][:status]).to eq(:active)
        expect(result['CN=NewGroup'][:first_seen]).to eq(now)
      end
    end
  end
end
