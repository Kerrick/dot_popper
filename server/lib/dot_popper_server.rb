# frozen_string_literal: true

# The server behind Dot Popper's friend groups: who is in which group,
# and who holds its trophy. It is plain Rack and SQLite, with the trophy's
# rules from the game's own lib/dot_popper/trophy.rb.
require_relative "../../lib/dot_popper/trophy"
require_relative "../../lib/dot_popper/groups/mark"
require_relative "dot_popper_server/store"
require_relative "dot_popper_server/app"
