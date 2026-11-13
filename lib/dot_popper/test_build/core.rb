# frozen_string_literal: true

# What only a test build carries (Build::PARTS): every playtest kit and
# every check runs one. A build for sale leaves this folder out
# (script/channel_contents.rb), so it holds none of it.
require_relative "test_keys"
require_relative "fake_setdef"
require_relative "switches"
