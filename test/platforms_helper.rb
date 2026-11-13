# frozen_string_literal: true

require "test_helper"
require "dot_popper/shell/platforms"

# For the tests that play a real system's Platform as the shell makes it
# (Shell::Platforms), so that the core's tests, which load test_helper
# alone, depend on no file of the shell.
module DotPopperTest
  # The Platform the shell makes on the system Lota::System.os calls
  # +name+, such as "iOS" or "OS X".
  def self.platform(name) = DotPopper::Shell::Platforms.for(name)
end
