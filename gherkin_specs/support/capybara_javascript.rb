# frozen_string_literal: true

# Real-browser driver for @javascript scenarios.
#
# PRD-0001 DEV-0005 ("the page is responsive on mobile") measures actual
# layout (window resize + scrollWidth), which the default rack_test driver
# cannot do — rack_test renders no layout at all. Selenium Manager
# (selenium-webdriver 4.6+) resolves the chromedriver matching the installed
# Chrome automatically; headless Chrome must be present on the host and on the
# CI runner (ubuntu-latest ships it). Capybara adds --no-sandbox /
# --disable-dev-shm-usage when CI is set.
Capybara.javascript_driver = :selenium_chrome_headless
