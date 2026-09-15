# frozen_string_literal: true

# QA-2026-09-14 MEDIUM-4 (issue #169): development boots with
# consider_all_requests_local = true, leaking detailed exception pages to the
# public tunnel host. Gate the flag by Host (tunnel arrives from 127.0.0.1,
# so IP-based detection cannot discriminate). Config initializers load before
# the autoloader is wired, so the middleware file is required explicitly.
require Rails.root.join('app/middleware/local_only_detailed_exceptions')

Rails.application.config.middleware.insert_before(
  ActionDispatch::DebugExceptions,
  LocalOnlyDetailedExceptions
)
