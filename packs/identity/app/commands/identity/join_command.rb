# frozen_string_literal: true

module Identity
  # Joins an organization with an owner-generated invite code
  # (PRD-0002 DEV-0007 / issue #17). The joining user becomes a MEMBER —
  # never owner — of the organization the (globally unique) code belongs to.
  # Creates user + membership atomically; a failure leaves no partial state.

  class JoinCommand < GLCommand::Callable
    requires invite_code: String, email: String, password: String
    returns user: User, organization: Organization, membership: OrgMembership

    def call
      invite = InviteCode.find_by(code: normalize_code(invite_code))
      if invite.nil?
        context.error = 'Invalid invite code'
        return
      end

      user = User.new(email: email.to_s.strip.downcase, password: password.to_s)
      membership = OrgMembership.new(
        user: user,
        organization: invite.organization,
        role: OrgMembership::MEMBER_ROLE
      )

      if [user, membership].all?(&:valid?)
        begin
          ActiveRecord::Base.transaction do
            user.save!
            membership.save!
          end
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
          # Validation raced a concurrent insert (e.g. duplicate email hitting
          # the unique index). Surface as a clean failure, never a 500.
          context.error = [user, membership].flat_map { |record| record.errors.full_messages }
                                            .uniq.compact_blank.join(', ').presence || 'Unable to join the organization'
          return
        end
        context.user = user
        context.organization = invite.organization
        context.membership = membership
      else
        context.error = [user, membership].flat_map { |record| record.errors.full_messages }.uniq.join(', ')
      end
    end

    private

    def normalize_code(value)
      value.to_s.strip.upcase
    end
  end
end
