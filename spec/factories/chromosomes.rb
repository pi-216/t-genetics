# frozen_string_literal: true

FactoryBot.define do
  factory :chromosome do
    sequence(:name) { |n| "Chromosome #{n}" }
    # Org-scoped domain (PRD-0002): every new chromosome belongs to an
    # organization. Pass `organization: nil` explicitly to build legacy rows.
    association :organization, factory: :organization

    factory :chromosome_with_alleles do
      transient do
        alleles_count { 2 }
      end

      after(:create) do |chromosome, evaluator|
        # Create a couple of default alleles if none are specified
        # Ensure Allele model and its methods are available
        # Example: creating one float and one integer allele
        if chromosome.alleles.empty? && evaluator.alleles_count.positive?
          Allele.new_with_float(name: "float_allele_#{chromosome.id}", minimum: 0.0, maximum: 1.0).tap do |a|
            a.chromosome = chromosome
            a.save!
          end
          if evaluator.alleles_count > 1
            Allele.new_with_integer(name: "integer_allele_#{chromosome.id}", minimum: 1, maximum: 100).tap do |a|
              a.chromosome = chromosome
              a.save!
            end
          end
          # Add more allele types if needed for broader testing
        end
        chromosome.reload # ensure alleles association is up to date
      end
    end
  end
end
