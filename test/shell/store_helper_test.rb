# frozen_string_literal: true

require_relative "../presentation/presentation_helper"
require_relative "../presentation/store_contract"
require "dot_popper/shell/store_helper"
require "rbconfig"
require "tmpdir"

# The store helper's adapter (Shell::StoreHelper), with real processes: a
# stand-in for the helper (test/fixtures/store_helper_stand_in.rb),
# written from macos/store and windows/store, answering down a real pipe.
# It runs the contract over the game's half of the computers' native path,
# and shows nothing about StoreKit or Windows.Services.Store themselves.
class StoreHelperContractTest < Minitest::Test
  include StoreContract

  StoreHelper = DotPopper::Shell::StoreHelper
  STAND_IN = File.expand_path("../fixtures/store_helper_stand_in.rb", __dir__)
  LIB = File.expand_path("../../lib", __dir__)

  # Reads as the game does, but gives the helper, a separate process, the
  # moment it needs to answer, so the contract's reads land on answers.
  class Polled < Data.define(:helper, :folder, :memo)
    def read
      last = memo[:text]
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        text = helper.read
        return memo[:text] = text if text != last || !helper.busy? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.005
      end
    end

    def open(url) = helper.open(url)
    def remove = helper.remove.tap { memo.clear }
    def path = helper.path
  end

  def setup
    super
    @root = Dir.mktmpdir("dot_popper_helper")
    @count = 0
  end

  def teardown = FileUtils.rm_rf(@root)

  def new_store(fails: nil, folder: nil)
    folder ||= File.join(@root, (@count += 1).to_s).tap { FileUtils.mkdir_p(it) }
    command = fails == "refused" ? nil : [RbConfig.ruby, "-I", LIB, STAND_IN, folder, fails.to_s]
    Polled.new(helper: StoreHelper.new(command), folder:, memo: {})
  end

  def relaunched(store) = new_store(folder: store.folder)

  def test_an_automated_run_starts_no_helper
    helper = StoreHelper.new([RbConfig.ruby, "-e", "exit"], automated: true)

    refute helper.open(Storefront.url(:open, 1, StoreHelper::PIPE))
  end

  def test_a_helper_that_is_not_there_is_refused
    refute StoreHelper.new([File.join(@root, "missing")]).open(Storefront.url(:open, 1, StoreHelper::PIPE))
  end

  def test_an_older_requests_late_answer_never_hides_a_newer_ones
    helper = StoreHelper.new(nil)
    helper.send(:heard, "answer=2\nstate=ready\n")
    helper.send(:heard, "answer=1\nstate=ready\n")

    assert_match(/answer=2/, helper.read)
  end

  def test_the_helper_is_found_in_a_macs_helpers_folder_or_beside_a_windows_program
    mac = File.join(@root, "Dot Popper.app", "Contents")
    FileUtils.mkdir_p([File.join(mac, "Helpers"), File.join(mac, "Resources", "game", "lib")])
    File.write(File.join(mac, "Helpers", "dot-popper-store"), "")
    File.chmod(0o755, File.join(mac, "Helpers", "dot-popper-store"))

    assert_equal File.join(mac, "Helpers", "dot-popper-store"), StoreHelper.find(DotPopperTest.platform("OS X"), starts: [File.join(mac, "Resources", "game", "lib")])
    assert_nil StoreHelper.find(DotPopperTest.platform("Windows"), starts: [File.join(mac, "Resources", "game", "lib")])
    assert_nil StoreHelper.find(DotPopperTest.platform("Linux"), starts: [mac])

    windows = File.join(@root, "Dot Popper")
    FileUtils.mkdir_p(File.join(windows, "game"))
    File.write(File.join(windows, "dot-popper-store.exe"), "")
    File.chmod(0o755, File.join(windows, "dot-popper-store.exe"))

    assert_equal File.join(windows, "dot-popper-store.exe"), StoreHelper.find(DotPopperTest.platform("Windows"), starts: [File.join(windows, "game")])
  end
end
