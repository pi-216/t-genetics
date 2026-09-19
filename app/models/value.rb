# frozen_string_literal: true

class Value < ApplicationRecord
  # Issue #215 — a value write must invalidate the organism's cache key: the
  # organisms index derives its ETag from MAX(organisms.updated_at) and the
  # viewer's from the organism row, while both render `values`. The valuable's
  # `has_one :value, touch: true` (Valuable) reaches this row; without the touch
  # the write stops here and a revalidating client keeps the pre-write values
  # behind a 304.
  belongs_to :organism, touch: true
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
