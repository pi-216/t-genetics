# frozen_string_literal: true

# Step definitions for DEV-0011 (finding #56, founder ruling 2026-09-04) —
# anonymous visitors are sent to sign-in before the org-scoped workspace.
# Factory truth: :chromosome (organization optional — pass nil explicitly to
# build legacy org-less rows, mirroring the pre-org-scoping demo data the
# tgenetics:migrate_legacy_org_rows rake task cleans up).

Given(/^a legacy chromosome exists without an organization$/) do
  FactoryBot.create(:chromosome, name: 'legacy-demo', organization: nil)
end

When(/^I visit the chromosomes page$/) do
  visit chromosomes_path
end

Then(/^I am redirected to the sign-in page$/) do
  expect(page).to have_current_path(login_path)
end

And(/^the chromosomes are not disclosed$/) do
  expect(page.body).not_to include('legacy-demo')
  expect(page.body).not_to include('Chromosomes')
end
