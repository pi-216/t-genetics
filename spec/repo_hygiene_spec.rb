# frozen_string_literal: true

require 'rails_helper'

# Issue #58 (founder ruling 2026-09-04): credentials tooling is intentionally
# unused in this repo — secrets come from the environment (SECRET_KEY_BASE,
# pinned in the tgenetics-puma systemd unit). The scaffold-era
# config/credentials.yml.enc held only generated defaults and has been
# removed; these guards keep encrypted credential files from being tracked
# again.
# Issue #173: the rails-venture-template's governance layer — FOUNDERS.md,
# docs/tech_design_docs/README.md, packs/README.md — was never backfilled into
# this repo. The guard below keeps the three stubs from silently vanishing
# again.
RSpec.describe 'Repo hygiene' do # rubocop:disable RSpec/DescribeClass
  describe 'no encrypted credential files tracked' do
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

  describe 'governance stubs present' do
    let(:governance_stubs) do
      [
        Rails.root.join('FOUNDERS.md'),
        Rails.root.join('docs/tech_design_docs/README.md'),
        Rails.root.join('packs/README.md')
      ]
    end

    it 'tracks the founder pillar index' do
      expect(governance_stubs[0]).to exist
    end

    it 'tracks the technical design doc skeleton' do
      expect(governance_stubs[1]).to exist
    end

    it 'tracks the bounded-context creation guide' do
      expect(governance_stubs[2]).to exist
    end
  end
end
