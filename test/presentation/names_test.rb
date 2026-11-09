# frozen_string_literal: true

require_relative "presentation_helper"

class NamesTest < Minitest::Test
  Names = DotPopper::Presentation::Names

  # LDNOOBW's bad-word list (CC BY 4.0), used here only and never shipped.
  BAD = File.readlines(File.expand_path("../fixtures/ldnoobw_en.txt", __dir__), chomp: true).map(&:downcase).reject(&:empty?)

  def test_the_names_are_the_same_every_time
    assert_equal Names.group("abc"), Names.group("abc")
    assert_equal Names.member("abc", 3), Names.member("abc", 3)
  end

  def test_a_group_reads_plural_and_a_member_singular
    Names::BIRDS.each { assert it.end_with?("s"), "#{it} is plural" }
    Names::FRUIT.each { refute it.end_with?("s"), "#{it} is singular" }
    assert_match(/\A\p{Upper}\p{Lower}+ \p{Upper}\p{Lower}+\z/, Names.group("a-group"))
    assert_match(/\A\p{Upper}\p{Lower}+ \p{Upper}\p{Lower}+\z/, Names.member("a-group", 2))
  end

  def test_members_of_a_group_never_share_a_name
    names = (1..200).map { Names.member("a-group", it) }
    assert_equal names.size, names.uniq.size
  end

  def test_no_group_name_or_member_name_is_rude
    Names::ADJECTIVES.product(Names::BIRDS).each { |word, bird| refute_rude("#{word} #{bird}") }
    Names::COLORS.product(Names::FRUIT).each { |color, fruit| refute_rude("#{color} #{fruit}") }
  end

  private

  def refute_rude(name)
    joined = name.delete(" ")
    words = name.split
    hits = BAD.select { |bad| name == bad || words.include?(bad) || joined == bad.delete(" ") }
    assert_empty hits, "#{name} matches #{hits.inspect}"
  end
end
