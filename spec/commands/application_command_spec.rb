# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCommand do
  # Not transactional: fixture transactions only ever roll back, so an
  # after_commit deferral registered inside an example could never resolve —
  # the suite could not prove the deferral actually fires on commit.
  self.use_transactional_tests = false

  def command_with_after_commit_hook(hook)
    Class.new(ApplicationCommand).tap do |klass|
      klass.define_method(:call) { run_after_commit(&hook) }
    end
  end

  describe '#run_after_commit' do
    it 'runs the block immediately when no transaction is open' do
      # spec_helper's DatabaseCleaner starts a suite-wide transaction, so the
      # no-transaction state can only be expressed by stubbing the guard; the
      # deferral/rollback cases below exercise the real connection.
      fired = false
      command_class = command_with_after_commit_hook(proc { fired = true })
      allow(ActiveRecord::Base.connection).to receive(:transaction_open?).and_return(false)

      command_class.call

      expect(fired).to be(true)
    end

    it 'defers the block until the surrounding transaction commits' do
      fired = false
      command_class = command_with_after_commit_hook(proc { fired = true })

      ActiveRecord::Base.transaction do
        command_class.call
        expect(fired).to be(false)
      end

      expect(fired).to be(true)
    end

    it 'never runs the block when the surrounding transaction rolls back' do
      fired = false
      command_class = command_with_after_commit_hook(proc { fired = true })

      ActiveRecord::Base.transaction do
        command_class.call
        raise ActiveRecord::Rollback
      end

      expect(fired).to be(false)
    end
  end
end
