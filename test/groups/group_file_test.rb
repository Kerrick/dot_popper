# frozen_string_literal: true

require "test_helper"

# group.txt's format, which players' builds have written since v0.9.10:
# it must read and write byte for byte as they do.
class GroupFileTest < Minitest::Test
  GroupFile = DotPopper::Groups::GroupFile
  Seen = DotPopper::Groups::Seen

  FULL = "t\n60\n1\n1|4|1~50 a-b|0|~7\nsteady,blink"

  def test_every_line_is_read
    file = GroupFile.parse(FULL)

    assert_equal "t", file.token
    assert_equal 60, file.unsent_score
    assert file.member
    assert_equal({ 1 => Seen.new(last: 4, fingerprint: "1~50"), "a-b" => Seen.new(last: 0, fingerprint: "~7") }, file.seen)
    assert_equal %w[steady blink], file.unsent_achievements
  end

  def test_what_is_read_is_written_back_unchanged
    ["t\n60\n1\n1|4|1~50 a-b|0|~7\nsteady,blink", "t\n\n1\n1|4|1~50\n", "\n\n\n\n", "t\n\n\n\nsteady"].each do |text|
      assert_equal text, GroupFile.parse(text).to_s
    end
  end

  def test_a_new_player_writes_five_empty_lines
    assert_equal "\n\n\n\n", GroupFile.new(token: nil, unsent_score: nil, member: false, seen: {}, unsent_achievements: []).to_s
  end

  def test_a_four_line_file_from_an_earlier_build_is_read
    file = GroupFile.parse("t\n7\n1\n1|4|1~50")

    assert_equal [7, true, []], [file.unsent_score, file.member, file.unsent_achievements]
    assert_equal "t\n7\n1\n1|4|1~50\n", file.to_s
  end

  def test_nothing_or_nonsense_reads_as_a_new_player
    [nil, "", "\n\n\n\n"].each do |text|
      file = GroupFile.parse(text)

      assert_equal [nil, nil, false, {}, []], file.to_h.values
    end
  end

  def test_an_unreadable_line_keeps_its_starting_value
    file = GroupFile.parse("t\nseven\nyes\nnot-an-entry 2|x\n")

    assert_nil file.unsent_score
    refute file.member
    assert_equal "t\n\n\nnot-an-entry|0| 2|0|\n", file.to_s
  end
end
