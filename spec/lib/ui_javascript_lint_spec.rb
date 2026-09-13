# frozen_string_literal: true

require 'tempfile'

require_relative '../../lib/ui_javascript_lint'

RSpec.describe UiJavascriptLint do
  def write_feature(content)
    file = Tempfile.new(['ui_lint', '.feature'])
    file.write(content)
    file.close
    file
  end

  def lint(content)
    file = write_feature(content)
    described_class.check([file.path])
  ensure
    file&.unlink
  end

  it 'flags a scenario that clicks without @javascript' do
    violations = lint(<<~GHERKIN)
      @PRD-0001
      Feature: Landing
        Scenario: The CTA leads to sign-up
          When I click the "Start free" call to action
          Then I land on the sign-up page
    GHERKIN

    expect(violations).to include(a_string_matching(/click/))
    expect(violations).to include(a_string_matching(/@javascript/))
  end

  it 'flags an inline-validation scenario without @javascript' do
    violations = lint(<<~GHERKIN)
      @PRD-0004
      Feature: Designer
        Scenario: Bounds validated inline
          When I set a minimum greater than the maximum
          Then I see an inline validation error
    GHERKIN

    expect(violations).to include(a_string_matching(/inline validation/))
  end

  it 'passes a UI-verb scenario that carries @javascript' do
    violations = lint(<<~GHERKIN)
      @PRD-0004
      Feature: Designer
        @DEV-0001
        @javascript
        Scenario: Mixed alleles with a live preview
          When I create a chromosome with mixed alleles
          Then I see a live preview of all three alleles
    GHERKIN

    expect(violations).to be_empty
  end

  it 'passes a feature-level @javascript that covers its scenarios' do
    violations = lint(<<~GHERKIN)
      @PRD-0006
      @javascript
      Feature: Brand Tokens
        Scenario: The shared layout renders the brand dark theme
          When I view any page
          Then the page background is the brand base color
    GHERKIN

    expect(violations).to be_empty
  end

  it 'passes API scenarios that stay request-layer' do
    violations = lint(<<~GHERKIN)
      @PRD-0005
      Feature: Token API
        Scenario: A valid token authenticates chromosome reads
          Given organization "Loop Labs" owns chromosome "Alpha-chrom"
          When I GET /api/v1/chromosomes with that token
          Then I receive a 200 response
    GHERKIN

    expect(violations).to be_empty
  end

  it 'passes non-interactive read scenarios' do
    violations = lint(<<~GHERKIN)
      @PRD-0001
      Feature: Landing
        Scenario: The page renders with the core message
          When I read the page content
          Then I see the product name
    GHERKIN

    expect(violations).to be_empty
  end

  it 'passes theme-parity scenarios that compare tokens, not rendered styles' do
    violations = lint(<<~GHERKIN)
      @PRD-0006
      Feature: Brand Tokens
        Scenario: The theme layer matches the locked token set
          When I compare the application theme with the locked DESIGN.md tokens
          Then every color token matches
          And every typeface token matches
          And every radius token matches
    GHERKIN

    expect(violations).to be_empty
  end

  it 'reports the file for each violation' do
    file = write_feature(<<~GHERKIN)
      @PRD-0001
      Feature: Landing
        Scenario: The CTA leads to sign-up
          When I click the "Start free" call to action
    GHERKIN

    violations = described_class.check([file.path])

    expect(violations.first).to include(file.path)
  ensure
    file&.unlink
  end

  it 'reports the scenario declaration line' do
    violations = lint(<<~GHERKIN)
      @PRD-0001
      Feature: Landing
        Scenario: The CTA leads to sign-up
          When I click the "Start free" call to action
    GHERKIN

    expect(violations.first).to include(':3:')
  end

  it 'requires @javascript for viewport and scrolling measurements' do
    violations = lint(<<~GHERKIN)
      @PRD-0001
      Feature: Landing
        Scenario: Responsive on mobile
          When I view the page at a 480 pixel viewport
          Then there is no horizontal scrolling
    GHERKIN

    expect(violations).to include(a_string_matching(/viewport/))
  end
end
