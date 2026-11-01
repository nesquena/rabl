#!/usr/bin/env bash
# Generates a fresh app that uses rabl from this checkout, copies in the shared models, views and
# tests (test/apps/shared) and the app's own files (test/apps/rails or test/apps/sinatra), and runs
# its tests. CI runs it for each app (the apps job in .github/workflows/ci.yml). It needs network
# access to rubygems.org.
#
#   test/apps/build_and_test.sh rails-8.1 /tmp/rabl-rails-app   # needs `gem install rails -v '~> 8.1.0'`
#   test/apps/build_and_test.sh sinatra /tmp/rabl-sinatra-app
#
# The directory must not exist yet.
set -euo pipefail

target=${1:?usage: $0 rails-X.Y|sinatra DIR}
dir=${2:?usage: $0 rails-X.Y|sinatra DIR}
apps=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$apps/../.." && pwd)
[ ! -e "$dir" ] || { echo "$dir already exists" >&2; exit 1; }
unset BUNDLE_GEMFILE

case "$target" in
  rails-*)
    series=${target#rails-}
    version=$(ruby -e 'print Gem::Specification.find_by_name("railties", "~> #{ARGV[0]}.0").version' "$series")
    rails "_${version}_" new "$dir" --minimal --skip-git --skip-bundle --skip-bootsnap
    files=rails
    ;;
  sinatra)
    mkdir -p "$dir"
    files=sinatra
    ;;
  *)
    echo "unknown app '$target' (rails-X.Y or sinatra)" >&2; exit 1 ;;
esac

cp -R "$apps/shared/." "$apps/$files/." "$dir/"
cd "$dir"
echo "gem 'rabl', path: '$root'" >> Gemfile
bundle install

if [ "$files" = rails ]; then
  bin/rails db:migrate
  bin/rails test test/rabl
else
  bundle exec ruby -Itest -e 'Dir["test/rabl/*_test.rb"].sort.each { |f| require File.expand_path(f) }'
fi
