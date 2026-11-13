# frozen_string_literal: true

require "test_helper"

# What each system means for the game (Platform), as the shell makes it
# from the name Lota::System.os gives the system (Shell::Platforms), and
# that nothing but the shell compares a system's name.
class PlatformTest < Minitest::Test
  def on(name) = DotPopperTest.platform(name)

  def test_a_phone_or_tablet_is_played_by_touch_in_the_phone_host
    %w[iOS Android].each do |name|
      assert_predicate on(name), :touch?, name
      assert_predicate on(name), :phone_host?, name
      assert_nil on(name).own_store, name
    end
    ["OS X", "Windows", "Linux"].each do |name|
      refute_predicate on(name), :touch?, name
      refute_predicate on(name), :phone_host?, name
    end
  end

  def test_only_ios_never_quits_itself
    refute_predicate on("iOS"), :quits_itself?
    ["Android", "OS X", "Windows", "Linux"].each { assert_predicate on(it), :quits_itself?, it }
  end

  def test_only_android_buzzes
    assert_predicate on("Android"), :buzzes?
    ["iOS", "OS X", "Windows", "Linux"].each { refute_predicate on(it), :buzzes?, it }
  end

  def test_only_a_mac_holds_command_for_its_shortcuts
    assert_predicate on("OS X"), :command_key?
    %w[iOS Android Windows Linux].each { refute_predicate on(it), :command_key?, it }
  end

  def test_a_mac_and_a_windows_pc_each_have_their_own_store
    assert_equal DotPopper::Build::MAC_APP_STORE, on("OS X").own_store
    assert_equal DotPopper::Build::MICROSOFT_STORE, on("Windows").own_store
    assert_nil on("Linux").own_store
  end

  def test_an_ios_copy_never_sells_through_the_website
    refute_predicate on("iOS"), :website_sales?
    ["Android", "OS X", "Windows", "Linux"].each { assert_predicate on(it), :website_sales?, it }
  end

  def test_a_unit_is_named_as_each_system_names_it
    assert_equal({ "iOS" => "points", "Android" => "dp", "OS X" => "logical pixels", "Windows" => "logical pixels",
                   "Linux" => "logical pixels" },
                 %w[iOS Android OS\ X Windows Linux].to_h { [it, on(it).unit] })
  end

  def test_a_system_the_shell_does_not_know_plays_as_a_computer
    assert_equal DotPopper::Platform::COMPUTER, on("Haiku")
  end

  # A system's name in code: Lota's ("iOS", and the engine's question that
  # answers it), or Ruby's (RUBY_PLATFORM, or one of its words in a string
  # or a regex, as "linux" or /darwin|ios/).
  SYSTEM_NAMES = Regexp.union(/"(?:iOS|Android|OS X|Windows|Linux)"|System\.os\b/,
                              %r{RUBY_PLATFORM|["/](?:[\w-]*\|)*(?:mingw|mswin|darwin|linux|android|ios)(?:\|[\w-]*)*["/]})
  INSIDE = %w[lib/dot_popper.rb lib/dot_popper/**/*.rb].freeze
  ROOT = File.expand_path("..", __dir__)

  def naming_a_system(files) = files.select { |file| File.readlines(file).any? { !it.lstrip.start_with?("#") && it.match?(SYSTEM_NAMES) } }
  def relative(files) = files.map { it.delete_prefix("#{ROOT}/") }.sort

  def test_nothing_but_the_shell_names_a_system
    files = INSIDE.flat_map { Dir[File.join(ROOT, it)] }.reject { it.include?("/lib/dot_popper/shell/") }

    assert_empty relative(naming_a_system(files))
  end

  # The scan sees the names where they are meant to be, so it is not blind.
  def test_the_scan_finds_the_shells_own_system_names
    named = relative(naming_a_system(Dir[File.join(ROOT, "lib/dot_popper/shell/*.rb")]))

    assert_equal %w[app platforms relaunch renderer_choice vulkan_rescue].map { "lib/dot_popper/shell/#{it}.rb" }, named
  end
end
