# frozen_string_literal: true

module Identity
  # Creates an organization with the signing-up user as its owner, signs the
  # user in at the controller layer. Creates all three records atomically —
  # a failure (duplicate email, invalid org name...) leaves no partial state.

  class SignUpCommand < GLCommand::Callable
    requires email: String, password: String, organization: String
    returns user: User, organization: Organization, membership: OrgMembership

    def call
      org = Organization.new(name: organization.to_s.strip)
      user = User.new(email: email.to_s.strip.downcase, password: password.to_s)
      membership = OrgMembership.new(user:, organization: org, role: OrgMembership::OWNER_ROLE)

      if [org, user, membership].all?(&:valid?)
        ActiveRecord::Base.transaction do
          org.save!
          user.save!
          membership.save!
        end
        context.user = user
        context.organization = org
        context.membership = membership
      else
        context.error = [org, user, membership].flat_map { |record| record.errors.full_messages }.uniq.join(', ')
      end
    end
  end
end
