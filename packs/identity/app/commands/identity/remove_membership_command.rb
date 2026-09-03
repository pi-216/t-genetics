# frozen_string_literal: true

module Identity
  # Removes a membership from an organization (PRD-0002 DEV-0010 /
  # issue #20). An org must never end up with zero owners, so the last
  # owner cannot be removed. The same guard applies to demotion whenever a
  # role-change command exists; today removal is the only surface.

  class RemoveMembershipCommand < GLCommand::Callable
    requires membership: OrgMembership
    returns membership: OrgMembership

    def call
      if last_owner?(membership)
        context.error = 'The last owner cannot be removed or demoted'
        return
      end

      membership.destroy!
      context.membership = membership
    end

    private

    def last_owner?(membership)
      membership.role == OrgMembership::OWNER_ROLE &&
        membership.organization.org_memberships.where(role: OrgMembership::OWNER_ROLE).one?
    end
  end
end
