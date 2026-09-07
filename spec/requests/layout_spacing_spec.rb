# frozen_string_literal: true

require 'rails_helper'

# Issue #141 — mobile spacing pass. The shared application layout owns the
# content column's top margin: 7rem (mt-28) on every breakpoint pushed
# internal forms more than a third of the way down a phone screen. The
# margin is now compact at the base breakpoint and switches to the brand
# cadence from md up. This request spec pins that responsive contract so a
# regression can't silently restore the always-7rem layout.
RSpec.describe 'Shared layout responsive top margin (issue #141)' do
  it 'uses the compact phone margin and the brand margin from md up' do
    get '/'

    main = Nokogiri::HTML(response.body).at_css('main')
    expect(main['class']).to include('mt-10')
    expect(main['class']).to include('md:mt-28')
  end
end
