# frozen_string_literal: true

# What only a test build carries (Build::PARTS): every playtest kit and
# every check runs one. A build for sale leaves this folder out
# (script/channel_contents.rb), so it holds none of it.
#
# Its own development settings, besides main.rb's:
#
#   DOT_POPPER_PRO=1            plays as if Pro were bought
#   DOT_POPPER_TODAY=2026-11-07 plays as if it were that date, for its
#                               daily goal and the goal's streak, and for
#                               which holiday look is in season.
require_relative "test_keys"
require_relative "receipt_test_key"
require_relative "fake_setdef"
require_relative "switches"
require_relative "fake_store"
require_relative "fake_checkout"
