# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "tmpdir"

# The Microsoft Store build's helper (windows/store) builds with MinGW and
# passes what it can check with no Store: its URL parser and the list it
# hands WinRT. It is never asked a real request here, which would reach
# the Microsoft Store. Windows only, where gcc is on the PATH.
class WindowsStoreHelperTest < Minitest::Test
  SOURCE = File.expand_path("../windows/store/dot_popper_store.c", __dir__)

  def setup
    skip "the store helper is Windows'" unless Gem.win_platform?
    skip "no gcc on the PATH" unless system("gcc", "--version", out: File::NULL, err: File::NULL)
  end

  def test_it_builds_runs_and_passes_its_self_test
    Dir.mktmpdir("dot_popper_store_helper") do |dir|
      program = File.join(dir, "dot-popper-store.exe")
      out, status = Open3.capture2e("gcc", "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror", "-Wno-cast-function-type",
                                    "-municode", "-o", program, SOURCE, "-lruntimeobject", "-lole32")

      assert status.success?, out
      assert_equal "dot-popper-store runs", Open3.capture2(program, "--check").first.strip
      out, status = Open3.capture2e(program, "--self-test")

      assert status.success?, out
      _, status = Open3.capture2e(program, "dotpopper-store://open?n=1&product=x&file=C:/answer.txt")

      assert_equal 64, status.exitstatus, "an answer file is never written: only the pipe"
    end
  end
end
