# Component Kit — Issue #133 (internal design sweep)

> Built 2026-09-06 — uniform ViewComponent kit for the internal (workspace +
> identity) surfaces of the Lab Instrument brand. Token source of truth:
> `docs/design-sprint/ph1/DESIGN.md` (locked) → `app/assets/stylesheets/theme.css`
> (generated). This note is the kit catalog + the design read per refactored
> surface; it is a working note, not a PRD.

## Kit catalog (`app/components/`)

| Component | Variants / slots | Renders | Purpose |
|---|---|---|---|
| `PageHeaderComponent` | `kicker`, `title`, `subtitle`, `back_path`/`back_label`; `actions` slot | — | Shared page-headline treatment: signal kicker, ink title, quiet flush-left back link, actions rail. Renamed from `PageheaderComponent` (file moved to `page_header_component.rb`). |
| `CardComponent` | `title`, `description`, `pad:`, `class_name:`, `spacing:`; `footer` slot | `section.card` | Dark surface panel, 1px hairline border, optional header + hairline-separated footer. `class_name:` keeps BDD selectors (`.suggested-organism`) stable. Owns the stacked-box rhythm itself (`spacing: true`, `mb-6` = the DESIGN.md lg step, 24px) so stacked boxes never sit flush; a container that owns the gap (a grid/flex row) passes `spacing: false`. |
| `FormFieldComponent` | `label`, `input_id`, `hint`, `errors[]`, `required`, `spacing:`; content slot | wrapper + label + field + hint + `.field-error` | Label-above-input with hint + inline danger errors and a signal `*` required marker. Exposes `INPUT_CLASSES` (the shared hairline input treatment) and owns the inter-field rhythm itself (`spacing: true`, the DESIGN.md md step) so stacked fields group into pairs whatever wraps them; a row that places a field beside its submit button passes `spacing: false`. |
| `ButtonComponent` | `primary` / `secondary` / `danger` / `ghost` / `back`; `href:` (link), `form_action:`+`method:` (button_to POST), `type:`/`name:`/`value:` (submit) | `a` / `form>button` / `button` | Single action control. Primary = locked button-primary tokens (signal fill, onSignal text, mono caption); secondary = hairline ring; danger = red fill with dark text (contrast-safe); ghost = quiet text action; back = ghost with no left padding, for the flush-left heading link. 44px reach targets. |
| `TableComponent` | `columns[]`, `empty:` flag, `spacing:`; `header`/`body`/`empty` slots | `div.table-wrap > table` | Dense-data surface: hairline rows, uppercase muted headers, `numeric_cell_class` for mono tabular numerals, explicit colspan empty state. Carries the same stacked-box rhythm as the card (`mb-6`, `spacing: false` when a container owns the gap). |
| `BadgeComponent` | `default` / `signal` / `good` / `danger` / `muted`; content or `text:` | `span.badge` | Short-radius status chips (experiment status, ripeness). Never pill. |
| `EmptyStateComponent` | `title`, `body`, `class_name:`, `aria_label:`, `spacing:`; `action` slot | `div.empty-state` | Explicit no-data surface (PRD-0004 convention): dashed hairline panel + title + muted body + optional centered action. `class_name:`/`aria_label:` keep `.no-suggestion-available` + its aria-label stable. Carries the stacked-box rhythm (`mb-6`) like the card and table. |

Existing components reused/extended, not duplicated: `ChromosomeComponent`
(chromosome list card row), `FitnessTrendComponent` (self-hosted SVG trend,
now surfaced inside a `CardComponent` panel). No new JS, no model/controller
changes — the sweep is presentational only.

### Stacked-box rhythm (issue #205)

`PageHeaderComponent` already carried `mb-6` (the DESIGN.md `lg` step, 24px);
the box panels carried nothing, so views that stacked them rendered flush
(the token page's "Create a token" card touching the token table). The rhythm
now belongs to the box: `CardComponent`, `TableComponent` and
`EmptyStateComponent` each carry `mb-6` by default and reach through whatever
wraps them, and a container that owns the gap itself — a grid/flex row, e.g.
the experiment page's two-column layout — passes `spacing: false` and owns the
rhythm *below* itself too (`mb-6` on the grid), or the box after it sits flush
against the container. Wrappers
that re-declared the rhythm (`space-y-4` around stacked cards) were removed:
two owners of one rhythm is a latent doubling the moment that container stops
collapsing margins. Guarded by `spec/requests/stacked_box_spacing_spec.rb`
(every stacked surface, no container a second owner, the grid's own rhythm
below itself) and the real-browser scenarios `@DEV-0205` (measured gaps: the
token page's card against its table, and the experiment page's trend panel
below the grid).

## Design reads per refactored surface

- **chromosomes/index** — reading as: chromosome list for a GA designer,
  utility-first with name-forward card rows + mono allele counts, leaning
  toward `ChromosomeComponent` rows + explicit `EmptyStateComponent`.
- **chromosomes/show** — reading as: chromosome detail for the designer,
  utility-first with a title + allele-preview card, leaning toward
  `PageHeader` + `CardComponent` (Edit secondary action added).
- **chromosomes/new (designer), edit, _form** — reading as: designer form for
  a GA designer, utility-first with hairline inputs + one amber action,
  leaning toward `PageHeader` + `FormField` + `CardComponent` allele cards +
  `ButtonComponent` (`Add allele` / `Create chromosome` commit round trips
  preserved). `.allele-card` / `.allele-error` / `.allele-preview-*`
  selectors stable.
- **experiments/index** — reading as: experiment monitor table for a GA
  operator, utility-first with status badges + mono ids, leaning toward
  `TableComponent` + `BadgeComponent` + explicit `EmptyStateComponent`.
- **experiments/show** — reading as: loop instrument panel for a GA operator,
  utility-first with one amber action per surface, leaning toward
  `PageHeader` + config/suggestion `CardComponent`s + `EmptyStateComponent`
  (`.no-suggestion-available`) + inline fitness report form. `.suggested-organism`,
  `.recorded-fitness`, `.command-errors` selectors stable.
- **experiments/new** — reading as: experiment setup form, utility-first,
  leaning toward `PageHeader` + `FormField` fields + primary create button.
- **experiments/history** — reading as: generation history for a GA operator,
  utility-first with mono generation/organism ids, leaning toward one
  `CardComponent` per generation with hairline-divided organism rows.
- **organisms/show** — reading as: organism specimen detail, utility-first
  with typed value rows + mono fitness readout, leaning toward `PageHeader` +
  `CardComponent`; `value-row value-<type>` + data attributes + typed spans
  preserved untouched.
- **alleles/index, show** — reading as: legacy scaffold surface (alleles are
  managed under chromosomes today; routes answer JSON/404), utility-first,
  leaning toward `TableComponent` + `EmptyStateComponent` / `CardComponent`.
- **application/_notice** — flash notice re-styled to the good-signal alert
  (hairline + tinted wash), id `notice` kept.
- **devise/passwords (new/edit)** — reading as: password recovery forms,
  utility-first with hairline inputs + one amber action, leaning toward
  `PageHeader` + `FormField` + `ButtonComponent`; `#error_explanation`
  preserved.
- **packs/identity** — sessions/new, registrations/new, invitations/new:
  the same auth form treatment (`PageHeader` + `FormField` +
  `ButtonComponent` primary). settings/show: org console with
  `CardComponent` panels, mono one-time token display
  (`#token_plaintext`/`#token_plaintext_value` kept), inline token form.
  invite_codes/show: `PageHeader` + `CardComponent` with the mono
  `.invite-code` readout + explicit no-code empty state.
- **layouts/application** — reading as: shared dark instrument frame, already
  branded; body stays on the locked mono base/ink treatment (kept app-wide —
  see deviations), footer hairline kept. No change shipped.

## Selector / contract stability

BDD + request selectors kept identical where dependents assert them:
`.no-suggestion-available` + `aria-label`, `.suggested-organism`,
`.recorded-fitness`, `.command-errors`, `.allele-card`, `.allele-preview`,
`.allele-preview-item`, `.allele-error` (+ stripped-message regex updated for
the added kit classes), `.invite-code`, `#error_explanation`, `#notice`,
`#token_plaintext(_value)`, `value-row value-<type>` rows with
`data-allele`/`data-type`, input class string
`border border-line bg-surface px-3 py-2 text-ink` (auth surfaces), and the
`bg-signal`/`text-onSignal` primary-button tokens. `div>p` scaffold assertion
in the dead alleles/index view spec replaced with the table contract.

## Verify (per-gate exit codes)

Recorded against the final commit — see PR description.