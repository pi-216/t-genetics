# PRD-0004 — Chromosome & allele management (standard CRUD)
# Drift flags vs PRD-0004:
# - A3 (2026-09-15, issue #184, PO ruling): the single-surface "designer"
#   (inline allele cards + Add-allele round trip + live preview) is REPLACED
#   by standard CRUD operations — create the chromosome by name only, land
#   on its show page, then add/edit/destroy alleles through their own nested
#   forms (each mutation redirecting back to the show page). The scenarios
#   below encode that flow.
# - Fitness trend = self-hosted pure-CSS/SVG bars, no charting gem (A2
#   resolved; no external charting CDN — dependency + network red line).
# - DEV-0004 (issue #80) implemented: cross-org chromosome access answers
#   404; DEV-0006 (issue #82, fitness trend line) and DEV-0007 (issue #83,
#   explicit empty state) implemented.
# - DEV-0004 drift: the published scenario references "Alpha-chrom" without
#   creating it — the implicit prerequisite "organization Alpha owns a
#   chromosome named Alpha-chrom" is injected (reuses the PRD-0002 DEV-0009
#   step in org_scoping.rb) so the 404 proves cross-org blocking, not mere
#   absence of the chromosome.
# - No paid-tier visualization depth.

@PRD-0004
Feature: Chromosome Designer
  As an organization member
  I want to create chromosomes and manage their typed alleles with standard CRUD
  So that I can shape my genome and watch my evolution progress

  Background:
    Given I am signed in as an owner of "Loop Labs"

  @DEV-0001
  # Issue #184 — the create flow is name-only; alleles are added afterwards
  # through the nested allele form. @javascript: the new-allele form posts
  # through a real browser (the transport layer that used to swallow the
  # designer's re-renders — finding #147 class).
  @javascript
  Scenario: A user creates a chromosome by name
    When I create a chromosome with the name "Mixed genome"
    Then I see the empty allele state on the chromosome
    And the chromosome is saved under my organization

  @DEV-0001
  # Issue #184 — PO ruling: "Once done you end up on the show page of the
  # chromosome, now showing the one allele."
  @javascript
  Scenario: Adding an allele returns to the chromosome show page
    Given a chromosome named "Mixed genome"
    When I add a float allele "weight" bounded by 0 and 10
    Then I am back on the chromosome show page and see the allele "weight"

  @DEV-0151
  # Issue #151 (T3 gap) — saved-state-integrity guard, on the CRUD flow now:
  # the alleles added one at a time persist EXACTLY — count and names — never
  # fewer or duplicated. Real browser because T3 lived in the transport layer.
  @javascript
  Scenario: A chromosome is saved with exactly the alleles added
    Given a chromosome named "Mixed genome"
    When I add a float allele "weight" 0..10, integer "limbs" 2..4, boolean "wings"
    Then the chromosome is saved with exactly those 3 alleles

  @DEV-0002
  # Finding #147 (T1) — inline validation on the allele form: the 422
  # re-render must display in a real browser (the allele form opts out of
  # Turbo, same transport class as the old designer form).
  @javascript
  Scenario: Allele bounds are validated inline
    Given I am adding a float allele to a chromosome
    When I set a minimum greater than the maximum
    Then I see an inline validation error
    And the allele is not saved

  @DEV-0003
  # Inline validation re-renders on the allele form — the same transport
  # class as findings T1/T2: only the browser proves the 422 displays.
  @javascript
  Scenario: An option allele requires a non-empty choice list
    Given I am adding an option allele to a chromosome
    When I leave the choice list empty
    Then I see an inline validation error
    And the allele is not saved

  @DEV-0210
  # Issue #210 — the web form posts `allele[choices]` as ONE comma-separated
  # string (a single text input), unlike the machine contract's array; the
  # happy path must round-trip through a real browser, not just the JSON API.
  # Issue #211 added the persistence assertion: rendering the choices proves
  # the page, not the record.
  @javascript
  Scenario: An option allele is created from a comma-separated choice list
    Given a chromosome named "Mixed genome"
    When I add an option allele "color" with the choices "red, blue"
    Then I am back on the chromosome show page and see the allele "color"
    And the allele "color" shows the choices "red, blue"
    And the allele "color" is stored with the choices "red", "blue"

  # Issue #211 — the exhaustive CRUD net for the allele web forms. The success
  # paths are where the live-site bugs (#209 stale page, #210 dropped choices)
  # slipped past the gate: every scenario below drives the real form, follows
  # the redirect back to the show page, and then checks the stored record — a
  # page that renders is not a record that saved.

  @DEV-0211
  # Integer/Float constraint round trip: the typed bounds must survive the
  # form post AND render on the show page. The pre-#211 coverage asserted a
  # float allele's name and count, never the constraints the user typed.
  @javascript
  Scenario: Numeric alleles round-trip their bounds
    Given a chromosome named "Mixed genome"
    When I add a float allele "weight" 0..10 and an integer allele "legs" 2..4
    Then the allele "weight" renders the bounds "0.0" and "10.0"
    And the allele "legs" renders the bounds "2" and "4"
    And the allele "weight" is stored with the bounds "0.0" and "10.0"
    And the allele "legs" is stored with the bounds "2" and "4"

  @DEV-0211
  # Boolean success round trip: a Boolean allele constrains nothing, so it
  # renders as a bare typed row and must carry no constraint detail.
  @javascript
  Scenario: A boolean allele round-trips without constraint fields
    Given a chromosome named "Mixed genome"
    When I add a boolean allele "wings"
    Then the allele "wings" renders as a boolean allele with no constraints
    And the allele "wings" is stored as a boolean allele

  @DEV-0211
  # Revisit after mutation (#209): the show page is ETag-cached, so a revisit
  # revalidates the copy the browser already holds — unchanged validators mean
  # a 304 and the pre-mutation allele list stays on screen. Headless Chrome in
  # this harness never revalidates (every show-page navigation in a run answers
  # 200, zero 304s), so the scenario replays the revisit's conditional request
  # from the page itself: same transport, deterministic evidence.
  @javascript
  Scenario: A mutation invalidates the cached chromosome show page
    Given a chromosome named "Mixed genome"
    And I hold the chromosome show page's validators
    When I add an integer allele "legs" bounded by 2 and 4
    Then the chromosome show page revalidates with the allele "legs"

  @DEV-0211
  # Edit round trip, numeric path: the typed inheritable is persisted
  # explicitly on update (delegated-type autosave only fires on a new row), so
  # the new bounds must survive the edit form and re-render.
  @javascript
  Scenario: Editing a numeric allele round-trips its new bounds
    Given a chromosome named "Mixed genome"
    And the chromosome has an integer allele "legs" bounded by 2 and 4
    When I edit the allele "legs" to be bounded by 3 and 5
    Then the allele "legs" renders the bounds "3" and "5"
    And the allele "legs" is stored with the bounds "3" and "5"

  @DEV-0211
  # Edit round trip, Option path: shares #210's root cause — the web form
  # posts the choices as one comma-separated string on update too.
  @javascript
  Scenario: Editing an option allele round-trips its new choices
    Given a chromosome named "Mixed genome"
    And the chromosome has an option allele "color" with the choices "red, blue"
    When I edit the allele "color" to have the choices "green, amber"
    Then the allele "color" shows the choices "green, amber"
    And the allele "color" is stored with the choices "green", "amber"

  @DEV-0211
  # Destroy round trip: the row leaves the show page and the record leaves the
  # database.
  @javascript
  Scenario: Destroying an allele removes it from the chromosome
    Given a chromosome named "Mixed genome"
    And the chromosome has an integer allele "legs" bounded by 2 and 4
    When I delete the allele "legs"
    Then no allele named "legs" is stored
    And the chromosome show page lists no alleles

  @DEV-0148
  # Finding #148 (T2) — type-aware allele fields: the allele form reveals
  # only the fields the selected type needs (Stimulus toggle in a real
  # browser; server-side validation stays the source of truth).
  @javascript
  Scenario: The allele form renders only the fields each allele type needs
    Given I am adding an allele to a chromosome
    When I walk the allele form through every allele type
    Then each allele form shows only its type's fields

  @DEV-0149
  # Finding #149 — duplicate allele names are rejected by the model-level
  # scoped uniqueness; adding a second allele with an existing name must
  # fail inline and persist nothing.
  @javascript
  Scenario: Duplicate allele names are rejected inline
    Given a chromosome with an allele named "weight"
    When I add another allele named "weight"
    Then I see an inline validation error
    And the duplicate allele is not saved

  @DEV-0004
  Scenario: Another organization cannot access my chromosome
    Given organization "Alpha" owns a chromosome named "Alpha-chrom"
    And I am signed in as an owner of organization "Beta"
    When I visit the chromosome "Alpha-chrom"
    Then I receive a not-found or forbidden response

  @DEV-0005
  Scenario: I can open an organism and see its typed values
    Given the generation browser shows an organism
    When I open the organism
    Then I see each value rendered by its allele type

  @DEV-0006
  Scenario: The fitness trend shows a line from recorded fitness
    Given the experiment has generations with recorded fitness
    When I view the fitness trend
    Then I see a per-generation trend line
    And no external charting is loaded

  @DEV-0007
  Scenario: The fitness trend shows an explicit empty state when no fitness is recorded
    Given the experiment has no recorded fitness
    When I view the fitness trend
    Then I see an explicit empty state

  @DEV-0203
  # Issue #203 — the page-header back link must left-align with the kicker and
  # title directly below it; the button kit's px-4 base padding indented the
  # link 16px. Only real layout can prove the alignment, so this measures the
  # actual left edges in headless Chrome (same class as the brand-token
  # computed-style scenarios — rack_test renders no layout).
  @javascript
  Scenario: The page-header back link left-aligns with the heading
    Given a chromosome named "Mixed genome"
    When I open the new allele form for the chromosome
    Then the back link and the heading share the same left edge

  @DEV-0209
  # Issue #209 — a successful mutation must confirm itself on the page it
  # redirects to. The shared layout renders the flash now; before, the notice
  # had no surface at all, so a committed allele looked like a silent failure.
  # Real browser: the step drives the form and the redirect it triggers.
  @javascript
  Scenario: Adding an allele confirms itself on the chromosome show page
    Given a chromosome named "Mixed genome"
    When I add an integer allele "legs" bounded by 2 and 4
    Then I see the success notice "Added allele legs."

  @DEV-0204
  # Issue #204 — stacked fields must group into label/input pairs: the gap
  # BETWEEN two fields has to be at least the label→input gap INSIDE one. The
  # inter-field rhythm used to come from the container's space-y-*, so the
  # type-aware field wrappers left label 2 clinging to input 1. Only real
  # layout can measure the boxes apart (rack_test renders no layout — same
  # class as @DEV-0203/@DEV-0209 in this feature).
  @javascript
  Scenario: Stacked allele form fields keep their inter-field spacing
    Given a chromosome named "Mixed genome"
    When I open the new allele form for the chromosome
    Then each field is separated from the next by at least its label-to-input gap
