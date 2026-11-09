# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"
require "tmpdir"
require_relative "../playtest/kit"

# The playtest kits' hand checks (playtest/checks.yml): every check has
# wording and an answer to give, each phrase it quotes is one the game
# shows, and both renderings carry every check.
class PlaytestKitTest < Minitest::Test
  WINDOWS = Playtest::Checklist.load(:windows)
  MAC = Playtest::Checklist.load(:mac)
  LINUX = Playtest::Checklist.load(:linux)
  IOS = Playtest::Checklist.load(:ios)
  ANDROID = Playtest::Checklist.load(:android)
  LISTS = [WINDOWS, MAC, LINUX, IOS, ANDROID].freeze

  # Every String the presentation's settings hold, the words among them.
  def self.game_strings(value = DotPopper::Presentation::Style.constants.map { DotPopper::Presentation::Style.const_get(it) })
    case value
    when String then [value]
    when Array then value.flat_map { game_strings(it) }
    when Hash then value.values.flat_map { game_strings(it) }
    when Data then game_strings(value.to_h.values)
    else []
    end
  end

  GAME_STRINGS = game_strings.freeze

  def test_the_lists_hold_the_checks_the_maintainer_asked_for
    [WINDOWS, MAC, LINUX].each { assert_equal (1..18).map(&:to_s), it.checks.map(&:id) }
    assert_equal (1..13).map(&:to_s), IOS.checks.map(&:id)
    assert_equal (1..15).map(&:to_s), ANDROID.checks.map(&:id)
    assert_equal %w[14 15 16 17 18], WINDOWS.checks.select(&:controller?).map(&:id)
  end

  def test_every_check_has_wording_and_an_answer
    LISTS.each do |list|
      list.each do |check|
        refute_empty check.ask.strip, "#{list.device} check #{check.id} has no wording"
        refute_empty check.answers, "#{list.device} check #{check.id} asks for no answer"
        check.answers.each do |part|
          refute_empty part.ask.strip, "#{list.device} check #{check.id} has a part with no wording"
          assert_includes Playtest::ANSWERS.keys, part.answer, "#{list.device} check #{check.id}: #{part.answer.inspect}"
          refute_nil part.scale, "#{list.device} check #{check.id} rates with no scale" if part.answer == "rating"
          refute_empty part.options, "#{list.device} check #{check.id} offers no choices" if part.answer == "choice"
        end
      end
    end
  end

  def test_sound_and_mute_come_first_on_windows
    assert_match(/Sound plays/, WINDOWS.checks[0].ask)
    assert WINDOWS.checks[1].restart, "the mute check starts the game again before it asks"
  end

  def test_each_quoted_phrase_is_in_the_check_and_in_the_game
    LISTS.each do |list|
      list.each do |check|
        check.quotes.each do |quote|
          assert check.wording.any? { it.include?(quote) }, "#{list.device} check #{check.id} quotes #{quote.inspect} but never says it"
          assert GAME_STRINGS.any? { it.include?(quote) }, "#{list.device} check #{check.id}: the game never shows #{quote.inspect}"
        end
      end
    end
  end

  def test_windows_wording_is_ascii
    WINDOWS.each { |check| check.wording.each { assert it.ascii_only?, "Windows check #{check.id}: #{it}" } }
  end

  def test_the_powershell_list_has_a_row_per_check_with_quotes_doubled
    list = Playtest::PowerShellList.new(WINDOWS).render

    assert_equal WINDOWS.checks.size, list.scan(/^  @\{ Id = /).size
    assert_includes list, "Ask = 'The bright dot''s edge is easy to see while it moves.'"
    assert_includes list, "Restart = $true"
  end

  def test_the_powershell_list_replaces_the_template_mark
    template = File.read(File.expand_path("../playtest/playtest.ps1", __dir__))
    filled = Playtest::PowerShellList.new(WINDOWS).fill(template)

    refute_includes filled, Playtest::PowerShellList::MARK
    assert_includes filled, "$Checks = @("
    assert_includes template, "@BUILD@"
    assert template.ascii_only?
    assert_raises(ArgumentError) { Playtest::PowerShellList.new(WINDOWS).fill("no mark") }
  end

  def test_each_system_reads_its_own_words
    assert_match(/Command\+Enter/, MAC.checks[3].ask)
    assert_match(/F11/, LINUX.checks[3].ask)
    assert_match(/Windows pauses/, WINDOWS.checks[4].try)
    refute_match(/Windows/, LINUX.checks[4].try)
    assert_match(/Notepad/, WINDOWS.checks[8].try)
    assert_match(/TextEdit/, MAC.checks[8].try)
    refute_match(/kit starts it/, MAC.checks[1].try)
  end

  def test_the_shell_list_has_a_function_per_check_with_quotes_escaped
    list = Playtest::ShellList.new(LINUX).render

    assert_includes list, "CHECK_IDS=(#{(1..18).to_a.join(" ")})"
    assert_includes list, %(CONTROLLER_IDS=" 14 15 16 17 18 ")
    assert_equal 18, list.scan(/^check_\d+\(\) \{$/).size
    assert_includes list, %q('The bright dot'\''s edge is easy to see while it moves.')
    assert_includes list, "answer 'rating' 'The cursor'\\''s top speed:'"
  end

  def test_the_mac_sheet_asks_about_the_mac
    sheet = Playtest::ResultsSheet.new(MAC, "Dot Popper v9.9.9").render

    assert sheet.start_with?("Dot Popper macOS playtest results\n")
    assert_includes sheet, "macOS version: ->"
    assert_includes sheet, "4. Command+Enter"
  end

  def test_the_android_sheet_asks_what_back_does_on_each_screen_and_how_to_keep_the_log
    sheet = Playtest::ResultsSheet.new(ANDROID, "Dot Popper v9.9.9").render

    assert sheet.start_with?("Dot Popper Android playtest results (experimental)\n")
    assert_includes sheet, "Android version (Settings > About device > Version): ->"
    ["on Stats, it goes back Home", "during a game, it does nothing",
     "at Game Over, it goes back Home, as Home does", "on Home, it leaves the app"].each { assert_includes sheet, it }
    # On a line of its own, so it copies whole into a terminal.
    assert_match(/^ +adb logcat -d > dot-popper-logcat\.txt$/, sheet)
  end

  def test_the_results_sheet_holds_the_build_and_every_check_with_a_blank
    sheet = Playtest::ResultsSheet.new(IOS, "Dot Popper v9.9.9").render

    assert_includes sheet, "  Dot Popper v9.9.9"
    IOS.each { |check| assert_match(/^#{check.id}\. /, sheet) }
    assert_operator sheet.scan("Note: ->").size, :==, IOS.checks.size
    assert_includes sheet, "(too small / right / too big): ->"
    assert_includes sheet, "Pasted result:"
  end

  # The macOS kit of v0.8.2-rc.1 said "version 0.8.1", fledge.yml's.
  def test_a_tag_builds_its_own_version_and_an_rc_its_base
    assert_equal "0.9.0", Playtest::BuildVersion.of("v0.9.0", fallback: "0.8.1").app
    assert_equal "0.8.2", Playtest::BuildVersion.of("v0.8.2-rc.1", fallback: "0.8.1").app
    other = Playtest::BuildVersion.of("trunk", fallback: "0.8.1")
    assert_equal "0.8.1", other.app, "a build of a branch keeps fledge.yml's"
    refute other.tag?
  end

  def test_the_tags_version_replaces_fledge_ymls_and_nothing_else
    yml = "name: Dot Popper\nversion: \"0.8.1\"\nkind: windowed\n"
    assert_equal "name: Dot Popper\nversion: \"0.8.2\"\nkind: windowed\n",
                 Playtest::BuildVersion.of("v0.8.2-rc.1", fallback: "0.8.1").pin(yml)
    assert_raises(ArgumentError) { Playtest::BuildVersion.of("v1.0.0", fallback: "").pin("name: x\n") }
  end

  def test_a_kits_header_must_name_the_tag_and_its_version
    version = Playtest::BuildVersion.of("v0.8.2-rc.1", fallback: "0.8.1")
    assert version.names?("Dot Popper v0.8.2-rc.1, commit 4246fd6, version 0.8.2")
    refute version.names?("Dot Popper v0.8.2-rc.1, commit 4246fd6, version 0.8.1")
    refute version.names?("Dot Popper trunk, commit 4246fd6, version 0.8.2")
  end

  def test_the_kit_script_pins_the_version_and_checks_the_header
    Dir.mktmpdir do |dir|
      fledge = File.join(dir, "fledge.yml")
      File.write(fledge, "name: Dot Popper\nversion: \"0.8.1\"\n")
      script = File.expand_path("../script/playtest_kit.rb", __dir__)
      assert_equal "0.8.2\n", IO.popen(["ruby", script, "tag-version", "v0.8.2-rc.1", fledge], &:read)
      assert_includes File.read(fledge), "version: \"0.8.2\""

      build = File.join(dir, "build.txt")
      File.write(build, "Dot Popper v0.8.2-rc.1, commit abc, version 0.8.1\nFused by lota fuse\n")
      refute system("ruby", script, "check-build", "v0.8.2-rc.1", build, err: File::NULL, out: File::NULL)
      File.write(build, "Dot Popper v0.8.2-rc.1, commit abc, version 0.8.2\nFused by lota fuse\n")
      assert system("ruby", script, "check-build", "v0.8.2-rc.1", build, out: File::NULL)
    end
  end
end
