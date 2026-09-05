# frozen_string_literal: true

# PRD-0004 DEV-0006 (issue #82) — per-generation average fitness trend.
#
# Renders one point per generation of the experiment's chromosome that has
# recorded fitness, joined by a self-hosted inline SVG polyline. The fitness
# values are the recorded averages the engine writes on organisms at
# evaluation time (customer-reported numbers averaged per organism — the same
# values the generation history page shows), then averaged per generation.
#
# Red lines honored: no charting gem, no external CDN (dependency + network
# policy, drift flag A2) — the chart is pure inline SVG; and the trend never
# evaluates anyone's fitness — it only reads recorded numbers back.
class FitnessTrendComponent < ViewComponent::Base
  VIEWBOX_WIDTH = 320
  VIEWBOX_HEIGHT = 72
  PAD_X = 24
  PAD_TOP = 8
  PAD_BOTTOM = 12
  LABEL_LINE_1_Y = 64
  LABEL_LINE_2_Y = 74

  def initialize(experiment:)
    @experiment = experiment
    super()
  end

  # One entry per generation with recorded fitness:
  #   { iteration:, fitness:, x:, y: } — x/y are the SVG coordinates of the
  # trend point (right-leaning by iteration, fitness-scaled vertically).
  def points
    @points ||= compute_points
  end

  delegate :empty?, to: :points

  def line_points
    points.map { |point| [point[:x], point[:y]].join(',') }.join(' ')
  end

  # 0.750 → "0.75", 1.0 → "1" — keeps short labels for the trend points.
  def formatted_fitness(fitness)
    format('%.3f', fitness).sub(/0+\z/, '').delete_suffix('.')
  end

  private

  def compute_points
    values = Generation.where(chromosome: @experiment.chromosome)
                       .order(:iteration)
                       .filter_map { |generation| generation_point(generation) }

    return [] if values.empty?

    min = values.pluck(:fitness).min
    max = values.pluck(:fitness).max
    range = max - min
    count = values.size

    values.each_with_index.map do |value, index|
      x = if count == 1
            VIEWBOX_WIDTH / 2.0
          else
            PAD_X + (index * (VIEWBOX_WIDTH - (2 * PAD_X)) / (count - 1).to_f)
          end
      y = if range.zero?
            VIEWBOX_HEIGHT / 2.0
          else
            PAD_TOP + (((max - value[:fitness]) / range) * (VIEWBOX_HEIGHT - PAD_TOP - PAD_BOTTOM))
          end
      value.merge(x: x.round(1), y: y.round(1))
    end
  end

  # The generation's recorded fitness = average of its organisms' recorded
  # fitness averages, or nil when nothing is recorded yet.
  def generation_point(generation)
    recorded = generation.organisms.filter_map(&:fitness)
    return nil if recorded.empty?

    { iteration: generation.iteration, fitness: (recorded.sum / recorded.size).round(3) }
  end
end
