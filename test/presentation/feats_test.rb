# frozen_string_literal: true

require_relative "presentation_helper"

# The feats on the Records screen and at Game Over: shown with the paid
# version, earned and kept without it, and cleared with the records.
class FeatsTest < Minitest::Test
  include PresentationTest

  Memory = DotPopper::BestScore::Memory
  MEDIUM = DotPopper::SizeClass::MEDIUM

  def setup
    @folder = DotPopper::RecordKeeper::Folder.new
    @achievements = DotPopper::Achievements.new(@folder.call("achievements"))
  end

  def show(paid:)
    @game = DotPopper::Game.new(field, random: Random.new(2), best: DotPopper::BestScore.new(@folder.call("best")))
    lifetime = DotPopper::Lifetime.new(@folder.call("lifetime"), today: -> { Date.new(2026, 11, 8) })
    keeper = DotPopper::RecordKeeper.new(best: @game.best, lifetime:, achievements: @achievements, folder: @folder)
    entitlement = DotPopper::Entitlement.new(Memory.new(paid ? "paid" : nil))
    @show = Show.new(game: @game, layout: layout, sounds: FakeSounds.new, radius: R, lifetime:, keeper:,
                     achievements: @achievements, entitlement:)
  end

  # Plays a round in which the player pops a dot with almost none of it
  # showing, and lets the clock run out.
  def play_a_sharp_round
    press_main
    round = @game.round
    covered = dot(400, 300, popped: true)
    round.instance_variable_set(:@dots, DotPopper::Stack.new(dots: [covered, dot(395, 300, id: 900)]))
    @show.tap(346, 300)
    @game.update(30)
  end

  def test_a_sharp_pop_is_named_at_game_over_for_a_paid_player
    show(paid: true)
    play_a_sharp_round

    assert_equal [:sharpshooter], @show.finale.feats
    assert_equal "New feat: Sharpshooter", FeatWords.earned(@show.finale.feats)
  end

  def test_a_free_player_earns_it_too_but_hears_nothing_of_it
    show(paid: false)
    play_a_sharp_round

    assert_empty @show.finale.feats
    assert_equal [:sharpshooter], @achievements.earned
    assert_equal "sharpshooter=2026-11-08\n", @folder.call("achievements").read
  end

  def test_a_feat_is_announced_only_the_round_it_is_first_earned
    show(paid: true)
    play_a_sharp_round
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    play_a_sharp_round

    assert_empty @show.finale.feats
  end

  def test_the_records_list_every_feat_open_before_any_is_earned
    show(paid: true)
    sheet = build_sheet(paid: true)
    marks = sheet.feats.rows.map(&:mark)

    assert_equal DotPopper::Feat::IDS.size, marks.size
    assert_equal [:open], marks.uniq
    assert_equal "Feats: 0 of 11", sheet.feats.title
  end

  def test_earned_feats_are_marked_and_counted_for_a_paid_player
    @achievements.award(%i[sharpshooter blink], day: "2026-11-08")
    sheet = build_sheet(paid: true)

    assert_equal "Feats: 2 of 11", sheet.feats.title
    assert_equal %i[earned open open earned], sheet.feats.rows.first(4).map(&:mark).values_at(0, 1, 2, 3)
    assert_equal ["Sharpshooter", "<10%"], sheet.feats.rows.first.then { [it.label, it.value] }
  end

  def test_a_free_player_sees_the_feats_exist_but_not_which_are_earned
    @achievements.award(%i[sharpshooter], day: "2026-11-08")
    sheet = build_sheet(paid: false)

    assert_equal [:locked], sheet.feats.rows.map(&:mark).uniq
    assert_equal "Feats come with the full game", sheet.feats.title
  end

  def test_buying_shows_what_was_earned_while_free
    @achievements.award(%i[sharpshooter], day: "2026-11-08")

    assert_equal [:earned], build_sheet(paid: true).feats.rows.map(&:mark).first(1)
  end

  def test_a_sheet_with_no_achievements_lists_no_feats
    assert_nil RecordsSheet.build(stats, best: 1, words: Look::WORDS).feats
  end

  def test_the_records_screen_puts_the_feats_in_a_column_of_their_own_where_there_is_room
    sheet = build_sheet(paid: true)
    plan = RecordsLayout.new(layout: layout(1400, 700), sheet:, look: Look::RECORDS, widest: 360)
    feats = plan.placements.select { it.item.is_a?(RecordRow) && it.item.mark }
    others = plan.placements.reject { it.item.is_a?(RecordRow) && it.item.mark }.select { it.item.is_a?(RecordRow) }

    assert_equal DotPopper::Feat::IDS.size, feats.size
    assert_equal 1, feats.map(&:x).uniq.size
    assert_empty feats.map(&:x) & others.map(&:x)
  end

  def test_on_a_narrow_screen_the_feats_stack_under_the_rest_and_all_fit
    sheet = build_sheet(paid: true)
    plan = RecordsLayout.new(layout: layout(395, 850), sheet:, look: Look::RECORDS, widest: 300)
    placed = plan.placements

    assert_equal DotPopper::Feat::IDS.size, placed.count { it.item.is_a?(RecordRow) && it.item.mark }
    assert_equal 1, placed.map(&:x).uniq.size, "one column"
    assert_operator placed.map(&:y).max, :<, plan.prompt_y
  end

  def test_clearing_the_records_clears_the_feats_and_undo_brings_them_back
    show(paid: true)
    play_a_sharp_round
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    @show.open_records
    assert_equal :earned, @show.records.feats.rows.first.mark

    @show.send(:clear_records)
    assert_empty @achievements.earned
    assert_equal :open, @show.records.feats.rows.first.mark
    assert_equal 1, @folder.call("cleared.txt").read.scan("achievements-").size

    @show.undo_offer && @show.send(:undo)
    assert_equal [:sharpshooter], @achievements.earned
    assert_equal :earned, @show.records.feats.rows.first.mark
  end

  private

  def stats
    DotPopper::LifetimeStats.new(rounds: 4, pops: 40, slips: 2, seconds: 100.0, days: 2, recent: [3, 9],
                                 recent_classes: [MEDIUM] * 2)
  end

  def build_sheet(paid:)
    RecordsSheet.build(stats, best: 9, words: Look::WORDS, size_class: MEDIUM, field: DotPopper::Field.new(1200, 800, R),
                              achievements: @achievements, paid:)
  end
end
