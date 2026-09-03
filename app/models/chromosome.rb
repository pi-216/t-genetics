# frozen_string_literal: true

class Chromosome < ApplicationRecord
  # Optional for legacy pre-org rows (issue #19); new rows are always assigned
  # an organization by the controller/command layer.
  belongs_to :organization, class_name: 'Identity::Organization', optional: true

  validates :name, presence: true
  has_many :alleles, dependent: :destroy
  has_many :generations, dependent: :destroy
  has_many :organisms, through: :generations

  after_initialize do
    alleles.each do |allele|
      self.class.send(:define_method, allele.name) { allele }
    end
  end

  def to_s
    "#<Chromosome id:#{id} name:#{name} alleles:[#{alleles.map(&:to_s).sort.join(', ')}]>"
  end

  def to_hsh
    {
      id: id,
      name: name,
      alleles: alleles.map(&:to_hsh).sort_by { _1[:name] }
    }
  end
end
