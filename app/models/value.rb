# frozen_string_literal: true

class Value < ApplicationRecord
  belongs_to :organism
  belongs_to :allele

  delegated_type :valuable, types: ['Value::Float', 'Value::Boolean', 'Value::Integer']
  delegate :data, :data=, to: :valuable
  delegate :mutate, :mutate!, to: :valuable
  delegate :name, to: :allele

  scope :with_allele, -> { joins(:allele) }
  scope :by_name, ->(name) { with_allele.where(allele: { name: }) }

  def self.new_from(allele, options = {})
    valuable_type = "Values::#{allele.type}".constantize
    valuable = valuable_type.new
    value = new(options.merge(allele:, valuable:))
    # Pin the has_one inverse before generating a value: Valuable delegates
    # `allele` through `value`, so an unborn Value cannot resolve its allele
    # otherwise — and `random` needs it. Without this, every organism was born
    # with NULL allele data (issue #166) because nothing ever called `random`.
    valuable.value = value if valuable.respond_to?(:value=) && valuable.value.nil?
    valuable.data = valuable.random
    value
  end

  def self.create_from(allele, options = {})
    v = new_from(allele, options)
    v.save
    v
  end

  def to_s
    "#{allele.name}: #{valuable.data}"
  end
end
