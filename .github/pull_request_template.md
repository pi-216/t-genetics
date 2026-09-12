Closes #

<!-- Describe what this PR does and why it's necessary -->
<!-- Attach screenshots — for UI changes, show BEFORE (main/current) and AFTER (this branch) -->

## Author checklist

- [ ] Assign yourself to the PR
- [ ] Link the issue: `Closes #N` at the very top
- [ ] Attach relevant screenshots (both sides for UI changes)
- [ ] Changes covered by automated tests
- [ ] New controller actions carry authorization (Devise + org-scoping; cross-org → 403/404)
- [ ] Command-pattern conventions followed (GLCommand: verb-named, validation before call, side effects after commit)
- [ ] Migrations are schema-only (backfills in separate Rake tasks)
- [ ] No hand-edited generated files (schema, lockfiles, swagger — regenerate with rswag)
- [ ] `bin/verify` clean (Tier-0 gate: rubocop · brakeman · bundler-audit · packwerk · erb_lint · rspec · cucumber · rswag:verify · gherkin_lint)

## Reviewer checklist

- [ ] Read the changes; ensure they do what the linked issue says
- [ ] Behavior changes covered by automated tests
- [ ] Org-scoping respected on every new/changed access path
- [ ] No fitness-bearing logic added (we suggest; customers report fitness)
- [ ] Generated files regenerated, not hand-tuned

## Helpful links

- [t-genetics AGENTS.md](AGENTS.md) — red lines, loop, pipeline
- [t-genetics-development skill](skill:t-genetics-development) — shipping flow, deploy, pitfalls