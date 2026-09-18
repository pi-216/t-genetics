# frozen_string_literal: true

class Allele < ApplicationRecord
  # Finding #149: allele names are unique within a chromosome (scoped, never
  # global — the same name on two different chromosomes is legal) and the
  # DB carries a matching unique index. The designer surfaces this inline
  # via the command; this model rule is the safeguard for every other write
  # path (append controller, API, rename).
  validates :name, presence: true, uniqueness: { scope: :chromosome_id }

  delegated_type :inheritable,
                 types: ['Alleles::Float',
                         'Alleles::Boolean',
                         'Alleles::Integer',
                         'Alleles::Option']

  scope :by_name, ->(name) { find_by(name:) }

  # Issue #209 — allele writes must invalidate the chromosome's cache key:
  # `fresh_when(@chromosome)` derives its ETag from this row's
  # `updated_at` (and the index page's from MAX(updated_at)), so without the
  # touch a cached show/index page revalidates unchanged and the browser
  # keeps the pre-mutation allele list.
  belongs_to :chromosome, touch: true
  has_many :values, dependent: :destroy

  def self.new_with_float(name:, minimum:, maximum:)
    new(name:, inheritable: Alleles::Float.create(minimum:, maximum:))
  end

  def self.new_with_integer(name:, minimum:, maximum:)
    new(name:, inheritable: Alleles::Integer.create(minimum:, maximum:))
  end

  def self.new_with_boolean(name:)
    new(name:, inheritable: Alleles::Boolean.create)
  end

  def self.new_with_option(name:, choices:)
    new(name:, inheritable: Alleles::Option.create(choices:))
  end

  def crossover_algorithm
    Organisms::Crossovers::Average
  end

  def type
    inheritable.class.to_s.split('::').last
  end

  def to_s
    "#{name}: [#{inheritable}]"
  end

  def to_hsh
    {
      id:,
      chromosome_id:,
      name:,
      type:
    }.merge(inheritable.to_hsh)
  end
end
