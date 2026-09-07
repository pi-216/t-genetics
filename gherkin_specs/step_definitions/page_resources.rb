# frozen_string_literal: true

# Step definitions for PRD-0001 DEV-0007 — the page makes no external network
# calls. The landing page (and the shared application layout it renders) must
# not load scripts, stylesheets, or IMAGES from third-party hosts: no CDNs, no
# font servers, no external screenshot hosts — nothing. Everything the page
# needs ships with the app.
#
# "External" is defined precisely: a <script src>, <link rel=stylesheet href>,
# <img src>, or <picture><source srcset> whose absolute URL points at a host
# that is not the app's own host. Relative URLs (/assets/...) are local by
# construction, so they can never be external. Protocol-relative URLs
# (//cdn.example.com/...) are external too — the scheme is stripped but the
# host comparison still catches them.
#
# Images joined the surface in issue #132 (the genome walkthrough serves real
# screenshots as local assets); the guard walks img[src] AND picture
# source[srcset] alongside links and scripts so no future external image host
# can slip in unnoticed — an <img> points at /assets/ while its desktop-width
# <source srcset> rides the same picture element.
#
# Sabotage discipline (proven in the DEV-0007 PR):
#   - adding any <link rel=stylesheet href="https://..."> to the shared layout
#     (e.g. a CDN font like rsms.me/inter/inter.css) kills this scenario;
#   - adding any <script src="https://..."> to a page kills it too;
#   - adding any <img src="https://..."> (e.g. an external screenshot host)
#     kills it as well;
#   - adding any <source srcset="https://..."> to a <picture> kills it too.
# The assertion walks the real rendered head/body, so it cannot be fooled by a
# resource that is only declared in a config file or comment.

When(/^I inspect the page resources$/) do
  @external_assets = page.all('link[rel="stylesheet"][href], script[src], img[src], source[srcset]', visible: false).filter_map do |tag|
    source = tag[:href] || tag[:src] || tag[:srcset]
    next unless source.start_with?('http://', 'https://', '//')

    source_uri = URI.parse(source.start_with?('//') ? "https:#{source}" : source)
    next if source_uri.host == URI.parse(page.current_url).host

    source
  rescue URI::InvalidURIError
    source
  end
end

Then(/^I see no external scripts, stylesheets, or images$/) do
  expect(@external_assets).to be_empty,
                              "expected no external scripts/stylesheets/images, found: #{@external_assets.join(', ')}"
end
