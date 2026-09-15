# frozen_string_literal: true

require 'gl_command'

# Base class for every mutation command. AGENTS.md binds side effects
# (broadcasts, external writes) to after-commit — run_after_commit is the
# enforcing rail: the block runs only once the surrounding DB transaction
# commits (immediately when none is open), so a rolled-back command can never
# leak an orphaned email, webhook, or broadcast.
class ApplicationCommand < GLCommand::Callable
  def run_after_commit(&)
    if ActiveRecord::Base.connection.transaction_open?
      ActiveRecord::Base.connection.current_transaction.after_commit(&)
    else
      yield
    end
  end
end
