# frozen_string_literal: true

# Step definitions for PRD-0001 DEV-0007 — the page makes no external network
# calls. The landing page (and the shared application layout it renders) must
# not load scripts or stylesheets from third-party hosts: no CDNs, no font
# servers, nothing external. Everything the page needs ships with the app.
#
# "External" is defined precisely: a <script src> or <link rel=stylesheet href>
# whose absolute URL points at a host that is not the app's own host. Relative
# URLs (/assets/...) are local by construction, so they can never be external.
# Protocol-relative URLs (//cdn.example.com/...) are external too — the scheme
# is stripped but the host comparison still catches them.
#
# Sabotage discipline (proven in the DEV-0007 PR):
#   - adding any <link rel=stylesheet href="https://..."> to the shared layout
#     (e.g. a CDN font like rsms.me/inter/inter.css) kills this scenario;
#   - adding any <script src="https://..."> to a page kills it too.
# The assertion walks the real rendered head, so it cannot be fooled by a
# stylesheet that is only declared in a config file or comment.

When(/^I inspect the page resources$/) do
  @external_assets = page.all('link[rel="stylesheet"][href], script[src]', visible: false).filter_map do |tag|
    source = tag[:href] || tag[:src]
    next unless source.start_with?('http://', 'https://', '//')

    source_uri = URI.parse(source.start_with?('//') ? "https:#{source}" : source)
    next if source_uri.host == URI.parse(page.current_url).host

    source
  rescue URI::InvalidURIError
    source
  end
end

Then(/^I see no external scripts or stylesheets$/) do
  expect(@external_assets).to be_empty,
                              "expected no external scripts/stylesheets, found: #{@external_assets.join(', ')}"
end
