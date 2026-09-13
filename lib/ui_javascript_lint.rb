# frozen_string_literal: true

# bin/verify gate: PRD scenarios that exercise the UI (clicking, live
# previews, inline validation, Turbo-driven mutations, viewport/layout
# measurements, computed styles) must run in a real browser. rack_test
# renders no layout and executes no JavaScript, so a request-layer green
# proves nothing about the transport layer (PRD-0004 findings T1/T2).
module UiJavascriptLint
  UI_VERBS = [
    /\bclick\b/,
    /live preview/,
    /inline validation/,
    /\bturbo\b/i,
    /visible field set/,
    /viewport/,
    /horizontal scrolling/,
    /background is the brand/,
    /renders in the mono/,
    /tabular numeral/,
    /signal (?:background|color)/,
    /no scaffold teal/
  ].freeze

  module_function

  # Returns an array of violation strings, one per UI-verb scenario that
  # lacks the @javascript tag. API/auth/data scenarios pass untouched.
  def check(feature_files)
    feature_files.flat_map { |file| check_file(file) }
  end

  def check_file(path)
    scenarios = parse_scenarios(path)
    scenarios.filter_map do |scenario|
      verbs = UI_VERBS.select { |re| scenario[:steps].any? { |step| re.match?(step) } }
      next if verbs.empty? || scenario[:tags].include?('@javascript')

      "#{path}:#{scenario[:line]}: scenario \"#{scenario[:title]}\" uses UI verbs " \
        "(#{verbs.map(&:source).join(', ')}) but is not tagged @javascript"
    end
  end

  def parse_scenarios(path)
    scenarios = []
    current = nil
    tags = []
    feature_tags = []

    File.foreach(path).with_index(1) do |line, number|
      stripped = line.strip
      case stripped
      when /\A@/
        tags.concat(stripped.scan(/@\S+/))
      when /\AFeature:/
        feature_tags = tags
        tags = []
      when /\AScenario(?: Outline)?:/
        scenarios << current if current
        current = { line: number, title: stripped.sub(/\AScenario(?: Outline)?:\s*/, ''), steps: [], tags: (feature_tags + tags).uniq }
        tags = []
      when /\A(?:Given|When|Then|And|But)\s+/
        current[:steps] << stripped if current
      when /\A(?:Examples:|Background:)/
        scenarios << current if current
        current = nil
        tags = []
      when /\A\s*\z/, /\A#/
        # Blank lines and comments: nothing to do.
      end
    end
    scenarios << current if current
    scenarios
  end
end
