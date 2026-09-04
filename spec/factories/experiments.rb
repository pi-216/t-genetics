# frozen_string_literal: true

FactoryBot.define do
  factory :experiment do
    sequence(:name) { |n| "Experiment #{n}" } # PRD-0003: experiments are named (issue #68)
    association :chromosome, factory: :chromosome_with_alleles # Default to a chromosome with alleles
    association :external_entity, factory: :chromosome # Using chromosome as a dummy polymorphic association
    status { 'pending' } # Default status from AASM
    configuration { { 'population_size' => 10 } } # Default configuration for other settings like population_size

    # Default values for new direct attributes, matching migration defaults
    feedback_percentage_threshold { 0.75 }
    min_organisms_with_feedback { 2 }
    suggestion_count_threshold_multiplier { 3.0 }

    trait :running do
      status { 'running' }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :with_current_generation do
      after(:create) do |experiment|
        # Generation doesn't take :experiment directly in its factory
        generation = create(:generation, chromosome: experiment.chromosome)
        experiment.update!(current_generation: generation)
      end
    end
  end
end
