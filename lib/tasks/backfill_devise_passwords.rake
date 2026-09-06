# frozen_string_literal: true

namespace :tgenetics do
  desc 'Copy legacy has_secure_password digests into Devise encrypted_password (issue #118).
        Run between migration 1 (add devise columns) and migration 2 (drop password_digest).'
  task backfill_devise_passwords: :environment do
    unless ActiveRecord::Base.connection.column_exists?(:users, :password_digest)
      puts 'No legacy password_digest column — Devise migration already complete, nothing to do.'
      next
    end

    # rubocop:disable Rails/SkipsModelValidations -- deliberate raw column copy: moving an existing
    # bcrypt digest into the Devise column must NOT re-hash or re-validate; callbacks/validations
    # do not apply to a 1:1 column move.
    moved = Identity::User.where(encrypted_password: [nil, ''])
                          .where.not(password_digest: [nil, ''])
                          .update_all('encrypted_password = password_digest')
    # rubocop:enable Rails/SkipsModelValidations
    puts "Backfilled #{moved} legacy password digest(s)."
  end
end
