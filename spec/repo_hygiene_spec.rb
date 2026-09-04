# frozen_string_literal: true

require 'rails_helper'

# Issue #58 (founder ruling 2026-09-04): credentials tooling is intentionally
# unused in this repo — secrets come from the environment (SECRET_KEY_BASE,
# pinned in the tgenetics-puma systemd unit). The scaffold-era
# config/credentials.yml.enc held only generated defaults and has been
# removed; these guards keep encrypted credential files from being tracked
# again.
RSpec.describe 'Repo hygiene: no encrypted credential files tracked' do # rubocop:disable RSpec/DescribeClass
  let(:gitignore) { Rails.root.join('.gitignore').read }

  it 'ignores config/credentials.yml.enc' do
    expect(gitignore).to include('/config/credentials.yml.enc')
  end

  it 'continues ignoring config/master.key' do
    expect(gitignore).to include('/config/master.key')
  end

  it 'does not track config/credentials.yml.enc in git' do
    tracked = `git ls-files config/credentials.yml.enc`.strip

    expect(tracked).to be_empty
  end

  it 'does not track config/master.key in git' do
    tracked = `git ls-files config/master.key`.strip

    expect(tracked).to be_empty
  end
end
