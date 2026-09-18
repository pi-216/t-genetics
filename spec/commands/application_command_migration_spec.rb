# frozen_string_literal: true

require 'rails_helper'

# Ticket #171 — every mutation command must subclass ApplicationCommand so the
# AGENTS.md after-commit side-effect rail is actually reachable. The read-only
# commands (no writes: pure queries/selection) legitimately stay on
# GLCommand::Callable — they never emit side effects.
RSpec.describe ApplicationCommand do
  describe 'command base class migration' do
    let(:mutation_commands) do
      [
        Chromosomes::Create,
        Chromosomes::Update,
        Comfy,
        Generations::New,
        Organisms::Clone,
        Organisms::Create,
        Organisms::Crossover,
        Organisms::Crossovers::Average,
        Organisms::Crossovers::Random,
        Organisms::Procreate,
        Organisms::SetValue,
        WriteTrainingFiles,
        Experiments::EvaluateAndEvolve,
        Experiments::RecordOutcome,
        Experiments::RequestSuggestion,
        Experiments::Setup,
        Identity::CreateApiTokenCommand,
        Identity::GenerateInviteCodeCommand,
        Identity::JoinCommand,
        Identity::RemoveMembershipCommand,
        Identity::SignUpCommand
      ]
    end

    let(:read_only_commands) do
      [
        Generations::Fitness,
        Generations::Pick,
        Experiments::CurrentSuggestion
      ]
    end

    it 'subclasses ApplicationCommand so run_after_commit is reachable' do
      expect(mutation_commands).to all(be < described_class)
    end

    it 'leaves read-only commands on GLCommand::Callable' do
      read_only_commands.each do |command_class|
        expect(command_class).to be < GLCommand::Callable
        expect(command_class).not_to be < described_class
      end
    end
  end
end
