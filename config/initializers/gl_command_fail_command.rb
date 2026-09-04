# frozen_string_literal: true

# Restore GLCommand::Callable#fail_command! — the engine commands
# (Experiments::Setup / RequestSuggestion / RecordOutcome / EvaluateAndEvolve,
# Organisms::Clone / SetValue) rely on it to record command-level error keys
# and halt. The helper was dropped from the gem (gl_command 1.4.0), so every
# fail path silently degraded into a generic NoMethodError ("Command Error:
# undefined method 'fail_command!'") carrying none of the intended error keys.
# Defining it once here fixes the whole call-site class — each call site keeps
# its existing `fail_command!(errors: ...)` contract (issue #68: Setup's
# population-size guard must surface as a real `population_size` error).
#
# Matching the gem's own idiom (GLCommand::Validatable#validate_validatable!):
# record errors on the callable, then stop_and_fail! with a RecordInvalid —
# Context#handle_failure imports the record's errors into the result so
# `result.errors[:key]` carries the intended message and rollback runs.
module GLCommand
  class Callable
    def fail_command!(errors:, no_notify: true)
      case errors
      when ActiveModel::Errors
        # ActiveModel::Errors#each yields Error objects (not attribute/message
        # pairs) on Rails 8; to_hash is the version-stable pair view.
        errors.to_hash.each do |attribute, messages|
          Array(messages).each { |message| self.errors.add(attribute, message) }
        end
      when Hash
        errors.each do |attribute, messages|
          Array(messages).each { |message| self.errors.add(attribute, message) }
        end
      end
      stop_and_fail!(ActiveRecord::RecordInvalid.new(self), no_notify: no_notify)
    end
  end
end