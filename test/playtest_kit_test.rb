# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"
require_relative "../playtest/kit"

# The playtest kits' hand checks (playtest/checks.yml): every check has
# wording and an answer to give, each phrase it quotes is one the game
# shows, and both renderings carry every check.
class PlaytestKitTest < Minitest::Test
  WINDOWS = Playtest::Checklist.load(:windows)
  MAC = Playtest::Checklist.load(:mac)
  LINUX = Playtest::Checklist.load(:linux)
  IPAD = Playtest::Checklist.load(:ipad)
  LISTS = [WINDOWS, MAC, LINUX, IPAD].freeze

  # Every String the presentation's settings hold, the words among them.
  def self.game_strings(value = DotPopper::Presentation::Look.constants.map { DotPopper::Presentation::Look.const_get(it) })
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
    assert_equal (1..13).map(&:to_s), IPAD.checks.map(&:id)
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

  def test_the_results_sheet_holds_the_build_and_every_check_with_a_blank
    sheet = Playtest::ResultsSheet.new(IPAD, "Dot Popper v9.9.9").render

    assert_includes sheet, "  Dot Popper v9.9.9"
    IPAD.each { |check| assert_match(/^#{check.id}\. /, sheet) }
    assert_operator sheet.scan("Note: ->").size, :==, IPAD.checks.size
    assert_includes sheet, "(too small / right / too big): ->"
    assert_includes sheet, "Pasted result:"
  end
end
