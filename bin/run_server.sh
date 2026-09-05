#!/usr/bin/env bash
# t-genetics Rails server launcher (GAaaS engine host, port 3005).
# systemd user services run with a minimal env; pin the rvm Ruby 3.4.5 like
# turbo-carnival's run_server.sh does.
set -euo pipefail

export PATH="/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/gems/ruby-3.4.5@global/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:$PATH"
export GEM_HOME="/usr/share/rvm/gems/ruby-3.4.5"
export GEM_PATH="/usr/share/rvm/gems/ruby-3.4.5:/usr/share/rvm/gems/ruby-3.4.5@global"

export RAILS_ENV=development
export RAILS_SERVE_STATIC_FILES=1
export PORT=3005

cd /home/tim/source/activity/t-genetics
exec "$(command -v bundle 2>/dev/null || echo /usr/share/rvm/gems/ruby-3.4.5/bin/bundle)" exec rails server -p 3005 -b 0.0.0.0