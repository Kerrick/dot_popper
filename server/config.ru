# frozen_string_literal: true

# The friend-group server. Run it with `bundle exec rackup` from this
# folder. DOT_POPPER_DB says where the SQLite file lives. It logs no
# request lines, so no address is ever written down.
$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "dot_popper_server"

run DotPopperServer::App.new(DotPopperServer::Store.new(ENV.fetch("DOT_POPPER_DB", "groups.sqlite3")))
