# frozen_string_literal: true

class Generation < ApplicationRecord
  # Issue #209 — the chromosome show page renders the generation count, so a
  # new generation must invalidate the chromosome's cache key (same shape as
  # the allele touch on Allele).
  belongs_to :chromosome, touch: true
  has_many :organisms, dependent: :destroy
  scope :latest, -> { order(iteration: :desc).first }

  def to_hsh
    {
      id: id,
      chromosome_id: chromosome_id
    }
  end
end
