# frozen_string_literal: true

# Shared helpers for request specs that exercise org-scoped endpoints.
# Sign-in goes through the real login flow (sets the session cookie, exactly
# like the web flow); the request scope derives from the session.
module AuthHelpers
  # Creates (or accepts) an organization, a member user, signs them in via the
  # real login route, and returns the signed-in user.
  def sign_in_as(organization: nil)
    org = organization || FactoryBot.create(:organization)
    user = FactoryBot.create(:user)
    FactoryBot.create(:org_membership, user:, organization: org)
    post login_path, params: { identity_user: { email: user.email, password: user.password } }
    user
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
