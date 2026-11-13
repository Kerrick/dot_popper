# frozen_string_literal: true

require_relative "presentation_helper"

class ShowTest < Minitest::Test
  include PresentationTest

  def setup
    @sounds = FakeSounds.new
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2))
    @clipboard = MemoryClipboard.new
    @sizing_store = DotPopper::ScoreRecord::Memory.new
    @show = new_show(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, random: Random.new(3),
                     clipboard: @clipboard, sizing_store: @sizing_store)
  end

  def test_a_tap_on_a_home_dot_pops_it_for_fun_and_starts_nothing
    dots = @show.attract.dots
    bright = dots.find { it.bright? && dots.top_at(it.x, it.y) == it && @show.control_at(it.x, it.y).nil? }
    @show.tap(bright.x, bright.y)

    assert @show.home?
    assert_equal %i[pop], @sounds.names
    assert_equal 1, @show.effects.rings.size
  end

  # Home's dots are a toy on Home alone: on a screen over it, which veils
  # them, and under the offer of Pro, a tap where one shows through does
  # nothing and makes no sound.
  def test_home_dots_pop_only_on_home
    { themes: -> { @show.open_themes }, privacy: -> { @show.open_settings && @show.open_privacy },
      server: -> { @show.open_settings && @show.open_page(:server) }, offer: -> { @show.open_offer_for(:themes) } }.each do |name, open|
      open.call
      dots = @show.attract.dots
      bright = dots.find { it.bright? && dots.top_at(it.x, it.y) == it && @show.control_at(it.x, it.y).nil? }
      @sounds.played.clear
      @show.tap(bright.x, bright.y, by: :mouse)

      refute_includes @sounds.names, :pop, name
      @show.back while @show.back
    end
  end

  # Play starts a game; empty space beside it does nothing.
  # A game on a field so wide that the dots, which hold still here, never
  # cover one another, so each bright dot can be tapped on the spot.
  def calm_show
    @cabinet = DotPopper::Cabinet.new(field(4000, 3000), random: Random.new(2))
    show = new_show(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, random: Random.new(3))
    show.tap(*middle(show.play_reach))
    show
  end

  def pop_bright(show)
    bright = @cabinet.game.dots.find(&:bright?)
    show.tap(bright.x, bright.y)
  end

  def test_a_streak_earns_a_bonus_dot_that_arrives_with_a_chime_and_pays_with_a_chord
    show = calm_show
    DotPopper::Rules::BONUS.dots_in_a_row.times { pop_bright(show) }

    assert_equal 1, @sounds.names.count(:bonus), "the bonus dot arrives with a chime"
    refute_includes @sounds.names, :bonus_pop
    bonus = @cabinet.game.dots.find(&:bonus?)
    assert bonus.bright?
    assert(show.effects.rings.any? { it.style == Style::BONUS_RIPPLE })

    show.update(Style::BONUS_BEACON_EVERY + 0.1)
    assert(show.effects.rings.any? { it.style == Style::BONUS_BEACON }, "a ring pulses about it while it waits")

    pop_bright(show)
    assert_equal 1, @sounds.names.count(:bonus_pop)
    assert(show.effects.rings.any? { it.style == Style::BONUS_SHOCKWAVE })
    refute(@cabinet.game.dots.any? { it.bright? && it.bonus? })
  end

  def test_an_ordinary_pop_makes_no_bonus_sound
    show = calm_show
    3.times { pop_bright(show) }

    assert_equal [:start, :pop, :pop, :pop], @sounds.names
  end

  def test_only_play_starts_a_game
    @show.tap(5, 5)
    assert @show.home?

    @show.tap(*middle(@show.play_reach))
    assert @show.playing?
    assert_equal 0, @cabinet.game.score
  end

  # Play is at least a dot fitted to the screen across, whichever size is
  # chosen, and a press reaches it a margin past its edges.
  def test_play_is_big_and_easy_to_reach
    button = @show.home_plan.play_button
    layout = @show.layout

    assert_operator button.height, :>=, 2 * DotPopper::DotSize.fitted(layout.width, layout.height).radius
    assert_operator @show.play_reach.width, :>, button.width
    assert @show.play_reach.contains?(button.x - 5, button.y - 5)
  end

  # Enter, Space, and a gamepad's Start press the main button; a
  # gamepad's A aimed at nothing does too.
  def test_the_main_button_answers_keys_and_a_gamepad
    @show.primary
    assert @show.playing?
    @show.primary
    assert @show.playing?, "in a game it does nothing"
    @cabinet.update(20)
    @show.tap(5, 5, by: :gamepad)
    assert @show.game_over?, "the grace still holds"
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.tap(5, 5, by: :mouse)
    assert @show.game_over?, "a click on empty space is the pile's"
    @show.tap(5, 5, by: :gamepad)
    assert @show.playing?, "Play again starts the next game at once"
  end

  # The words name the press the player last made: a click to start,
  # until a gamepad or a finger is used.
  def test_the_words_follow_the_input_last_used
    assert_equal [InputKind::MOUSE, "Play"], [@show.input, @show.words.play]
    @show.input = InputKind::GAMEPAD
    assert_equal "Play (A)", @show.words.play
    @show.input = InputKind::TOUCH
    assert_equal "Play", @show.words.play
    assert_equal "Play again",
                 new_show(cabinet: @cabinet, layout:, sounds: @sounds, radius: R, input: InputKind::TOUCH).words.play_again
  end

  RESULT = "Dot Popper: 1 point\n🟡 1 dot · ⚫ 0 mistakes · ⏱ 11 seconds\n" \
           "Played on a screen about 8 dots wide and 6 dots tall."

  # "Share my score" only shows the result: the clipboard changes only
  # when the player presses Copy, and then to exactly what was shown.
  def test_share_my_score_shows_the_result_and_only_copy_copies_it
    start_and_pop
    @cabinet.update(20)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.update(0.1)
    @show.tap(*middle(@show.share_reach))

    assert @show.game_over?
    assert @show.sharing?
    assert_equal RESULT, @show.share_preview.text
    assert_nil @clipboard.text, "opening the preview copies nothing"
    refute @show.share_preview.copied?

    @show.tap(*middle(@show.copy_reach))

    assert_equal RESULT, @clipboard.text
    assert @show.share_preview.copied?
    assert @show.sharing?, "the preview stays open to say it was copied"
    assert @show.game_over?
  end

  def test_the_share_preview_closes_by_close_by_back_and_by_a_tap_beside_it
    finish_game(back_to_title: false)
    @show.share
    @show.tap(*middle(@show.close_reach))
    refute @show.sharing?, "Close closes it"

    @show.share
    assert @show.back, "Escape and B close it"
    refute @show.sharing?
    assert @show.game_over?, "and go no further than Game Over"

    @show.share
    card = @show.share_plan.card
    @show.tap(card.x + 2, card.y + 2)
    assert @show.sharing?, "a tap on the card, away from its buttons, does nothing"
    @show.tap(card.x - 5, card.y - 5)
    refute @show.sharing?, "a tap beside the card closes it"
    assert_nil @clipboard.text
  end

  # A controller's Y is Share my score at Game Over, and Copy in the
  # preview over it.
  def test_a_controllers_y_shares_at_game_over_and_copies_in_the_preview
    finish_game(back_to_title: false)
    @show.pad(:y)
    assert @show.sharing?
    assert_nil @clipboard.text

    @show.pad(:y)
    assert_match(/\ADot Popper: 1 point\n/, @clipboard.text)
    assert @show.sharing?
  end

  # In the preview, the main button is Copy: Enter, Space, Start, a
  # gamepad's A aimed at nothing, and Y again all copy.
  def test_in_the_share_preview_the_main_button_and_y_copy
    finish_game(back_to_title: false)
    @show.share
    @show.primary
    assert_match(/\ADot Popper: 1 point\n/, @clipboard.text)
    @clipboard.copy(nil)
    @show.share
    assert_match(/\ADot Popper: 1 point\n/, @clipboard.text)
    @clipboard.copy(nil)
    @show.tap(0, 0, by: :gamepad)
    assert_match(/\ADot Popper: 1 point\n/, @clipboard.text)
    assert @show.sharing?
  end

  # The preview is the presentation's alone: the game stays on Game
  # Over, its grace runs as ever, nothing under the preview takes a
  # press, and once it closes, Home goes on as before.
  def test_the_share_preview_leaves_game_over_and_home_as_they_were
    finish_game(back_to_title: false)
    continue = middle(@show.home_reach)
    @show.share
    assert_equal %i[close copy], @show.controls.map(&:name).sort, "only the preview's buttons take a press"
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    assert @cabinet.state.ready?, "the grace runs on under the preview"
    @show.primary
    assert @show.game_over?, "the main button copies there, and goes nowhere"
    refute @show.waits_for_release?(*continue), "no press under the preview drags the pile"

    @show.close_share
    @show.tap(*continue)
    assert @show.home?
    refute @show.sharing?
  end

  # A phone's own share sheet can take the preview's place (Show's
  # +sharing+): offered the result, it opens no preview.
  def test_a_system_share_sheet_can_stand_in_for_the_preview
    sheet = Class.new do
      attr_reader :offered

      def offer(text, _now) = (@offered = text) && nil
    end.new
    show = new_show(cabinet: @cabinet, layout:, sounds: @sounds, radius: R, clipboard: @clipboard, sharing: sheet)
    press_main(show)
    @cabinet.update(20)
    show.share

    assert_match(/\ADot Popper: 0 points\n/, sheet.offered)
    refute show.sharing?
    assert_nil @clipboard.text
  end

  def test_each_finished_game_is_added_to_the_stats
    start_and_pop
    @cabinet.update(20)

    assert_equal 1, @show.stats_book.stats.games
    assert_equal 1, @show.stats_book.stats.dots_popped
    assert_equal [1], @show.stats_book.stats.recent
  end

  def test_game_over_names_the_score_record_record_the_game_set
    start_and_pop
    @cabinet.update(20)
    assert_nil @show.game_over.record, "a first game has nothing to beat"

    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @cabinet.press(10, 10)
    start_and_pop
    start_and_pop(started: true)
    @cabinet.update(30)

    assert_equal :most_dots_in_a_row, @show.game_over.record.kind
    assert_equal 2, @show.game_over.record.value
  end

  # 2026-11-01's goal is to pop 10 bright dots in the first 10 seconds.
  def test_the_game_that_meets_todays_goal_celebrates_it_once_the_score_has_counted
    stats_book = DotPopper::StatsBook.new(DotPopper::ScoreRecord::Memory.new, today: -> { Date.new(2026, 11, 1) })
    show = new_show(cabinet: @cabinet, layout:, sounds: @sounds, radius: R, random: Random.new(3), stats_book:)
    press_main(show)
    10.times do
      bright = @cabinet.game.dots.find(&:bright?)
      clear_around!(@cabinet.game, bright)
      show.tap(bright.x, bright.y)
    end
    @cabinet.update(30)

    assert show.game_over.goal_met
    refute show.game_over.goal_due?(show.now), "not before the score has counted"
    show.update(Style::GAME_OVER.tally.duration)
    assert show.game_over.goal_celebrated
    assert stats_book.goal_done?
  end

  def test_continue_goes_on_once_the_grace_is_over_and_empty_space_never_does
    press_main
    @cabinet.update(20)
    @show.update(0.1)
    press_main
    assert @show.game_over?, "the grace still holds"

    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.tap(5, 5)
    assert @show.game_over?, "empty space is only for the pile"
    press_main
    assert @show.home?
    assert_nil @clipboard.text
  end

  def test_back_goes_on_from_game_over_and_leaves_nothing_else
    refute @show.back
    press_main
    refute @show.back, "in a game it does nothing"
    @cabinet.update(20)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    assert @show.back
    assert @show.home?
  end

  # Game Over's presses wait for their release, since each may become a
  # drag of the pile; a game's and the buttons' never do.
  def test_only_game_over_waits_for_a_press_to_be_let_go
    refute @show.waits_for_release?(10, 10)
    press_main
    refute @show.waits_for_release?(10, 10)
    @cabinet.update(20)

    assert @show.waits_for_release?(10, 10)
    refute @show.waits_for_release?(*middle(@show.share_reach))
    refute @show.waits_for_release?(*middle(@show.home_reach))
    refute @show.waits_for_release?(*middle(@show.play_again_reach))
  end

  def test_share_my_score_takes_taps_where_its_plan_draws_it
    finish_game(back_to_title: false)
    button = @show.game_over_plan.share_button

    reach = @show.share_reach
    assert reach.contains?(button.center_x, button.center_y)
    assert_operator reach.height, :>=, button.height
    refute reach.overlaps?(@show.home_reach), "a press reaches one button"
    assert_operator @show.game_over_plan.backing.bottom, :<=, @show.game_over_plan.play_button.y,
                    "the backing ends above Play again"
  end

  def test_the_share_buttons_place_on_home_shares_nothing
    finish_game(back_to_title: false)
    place = middle(@show.share_reach)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    assert @show.home?
    assert_nil @show.share_reach

    @show.tap(*place)

    refute @show.sharing?
    assert_nil @clipboard.text
  end

  # Laying Home out took a millisecond a frame on a phone, twice a
  # frame; it is laid out again only when something on it changes.
  def test_home_is_laid_out_again_only_when_it_changes
    plan = @show.home_plan

    assert_same plan, @show.home_plan
    finish_game

    refute_same plan, @show.home_plan, "a played game brings the records and the goal"
    assert_same @show.home_plan, @show.home_plan
    wider = @show.home_plan
    @show.resize(layout(400, 850), field(400, 850))

    refute_equal wider.play_button, @show.home_plan.play_button
  end

  def test_game_over_is_laid_out_again_only_when_it_changes
    finish_game(back_to_title: false)
    plan = @show.game_over_plan

    assert_same plan, @show.game_over_plan
  end

  # The maintainer, on a controller alone, couldn't find how to quit. B
  # on Home asks, and a second B within two seconds quits.
  def test_b_twice_on_home_quits_and_once_only_asks
    assert_equal :asked, @show.ask_to_quit
    assert_operator @show.quit_prompt, :>, 0.0
    @show.update(1.0)

    assert_equal :quit, @show.ask_to_quit
  end

  def test_a_second_b_too_late_only_asks_again
    @show.ask_to_quit
    @show.update(Show::QUIT_ASK + 0.1)

    assert_in_delta 0.0, @show.quit_prompt
    assert_equal :asked, @show.ask_to_quit
  end

  def test_b_never_quits_from_a_game_or_the_stats
    finish_game(back_to_title: false)

    assert_nil @show.ask_to_quit
  end

  # Resizing the window brings the choice back, or takes it away.
  def test_the_choice_comes_and_goes_as_the_window_is_resized
    finish_game
    assert @show.sizing_offered?

    @cabinet.screen = field(1200, 800)
    @show.resize(layout(1200, 800), @cabinet.field)
    refute @show.sizing_offered?

    @cabinet.screen = field(400, 850)
    @show.resize(layout(400, 850), @cabinet.field)
    assert @show.sizing_offered?
    assert_equal :smaller, @show.sizing_preview.effect
  end

  def test_your_stats_opens_over_home_and_back_goes_back
    finish_game
    @show.tap(*middle(@show.stats_reach))
    assert @show.stats?
    assert @show.home?
    assert_equal 1, @show.stats.totals.rows.first.value.to_i

    @show.tap(10, 300)
    assert @show.stats?, "empty space does nothing"
    @show.tap(*middle(@show.back_reach))
    refute @show.stats?
    assert @show.home?, "Back never starts a game"
  end

  def test_start_and_back_leave_the_stats_screen_and_only_it
    finish_game
    @show.open_stats
    @show.start
    refute @show.stats?
    assert @show.home?

    @show.open_stats
    assert @show.back
    refute @show.back, "with no Stats screen, back has nothing to do"
    assert @show.home?
  end

  def test_the_stats_screen_opens_only_from_home
    finish_game(back_to_title: false)
    @show.open_stats

    refute @show.stats?
  end

  def test_a_gamepads_start_begins_the_usual_game_without_popping_a_home_dot
    @show.start

    assert @show.playing?
    assert_equal [:start], @sounds.names
  end

  def test_start_does_nothing_in_a_game
    @show.start
    score = @cabinet.game.score
    clock = @cabinet.game.countdown
    @show.start

    assert @show.playing?
    assert_equal [score, clock], [@cabinet.game.score, @cabinet.game.countdown]
  end

  def test_start_plays_again_from_game_over_after_the_grace
    @show.start
    @cabinet.update(20)
    @show.start
    assert @show.game_over?, "the grace still holds"

    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.start
    assert @show.playing?
  end

  # Game Over's Home goes Home, and B does too.
  def test_home_and_b_go_home_from_game_over
    @show.start
    @cabinet.update(20)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.tap(*middle(@show.home_reach))
    assert @show.on_home?

    @show.start
    @cabinet.update(20)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    assert @show.back
    assert @show.on_home?
  end

  def test_a_gamepads_y_shares_the_result_on_game_over_and_nothing_else
    @show.share
    assert @show.home?, "Y does nothing on Home"
    refute @show.sharing?

    @show.start
    @show.share
    assert @show.playing?, "Y does nothing in a game"
    refute @show.sharing?

    @cabinet.update(20)
    @show.update(0.1)
    @show.share
    assert @show.game_over?
    assert @show.sharing?
    assert_nil @clipboard.text
    @show.share
    assert_match(/\ADot Popper: 0 points\n/, @clipboard.text)
  end

  def test_any_other_tap_reaches_the_game_at_once
    press_main

    assert @show.playing?
    assert_equal [:start], @sounds.names
  end

  def test_a_pop_shows_what_it_earned_and_bloops
    start_and_pop

    assert_equal ["+1", "+1s"], @show.effects.floaters.map(&:text)
    assert_equal :pop, @sounds.names.last
    assert_equal [Style::POP_BURST], @show.effects.take_sprays.map(&:style)
    assert_equal 2, @show.effects.rings.size
  end

  def test_a_pop_buzzes_briefly_and_a_wrong_tap_longer
    haptics = FakeHaptics.new
    @show = new_show(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, random: Random.new(3), haptics:)
    start_and_pop
    popped = @cabinet.game.dots.find(&:popped?)
    clear_around!(@cabinet.game, popped)
    @show.tap(popped.x, popped.y)

    assert_equal [Style::HAPTICS.pop, Style::HAPTICS.penalty], haptics.buzzes
    assert_operator Style::HAPTICS.penalty, :>, Style::HAPTICS.pop
  end

  def test_a_pop_is_heard_where_it_is
    start_and_pop
    x = @cabinet.game.dots.find(&:popped?).x

    assert_in_delta Style::SOUND.stereo.pan(x, 800), @sounds.pans.last
  end

  def test_the_pop_climbs_with_the_score_up_to_a_cap
    press_main
    score!(@cabinet.game, 1000)
    start_and_pop(started: true)

    assert_in_delta Style::SOUND.pop_highest, @sounds.played.last.last
  end

  def test_a_wrong_tap_shows_only_what_was_lost
    start_and_pop
    popped = @cabinet.game.dots.first
    clear_around!(@cabinet.game, popped)
    @show.tap(popped.x, popped.y) # the score falls from 1 to 0: only 1 lost

    assert_equal ["−1", "−2s"], @show.effects.floaters.last(2).map(&:text)
    assert_equal :bonk, @sounds.names.last
    assert_operator @show.effects.flash_alpha, :>, 0
  end

  def test_a_wrong_tap_at_zero_shows_only_the_seconds
    start_and_pop
    score!(@cabinet.game, 0)
    popped = @cabinet.game.dots.first
    clear_around!(@cabinet.game, popped)
    @show.tap(popped.x, popped.y)

    assert_equal "−2s", @show.effects.floaters.last.text
  end

  def test_a_wrong_tap_over_the_bright_dot_outlines_it
    start_and_pop
    popped = @cabinet.game.dots.first
    bright = @cabinet.game.dots.find(&:bright?)
    clear_around!(@cabinet.game, popped)
    put!(bright.id, popped.x + 30, popped.y)
    @show.tap(popped.x - 20, popped.y)

    assert_equal [bright.id], @show.effects.reveals.map(&:follow)
    @show.update(Style::REVEAL.duration)
    assert_empty @show.effects.reveals
  end

  # The stacking rule is taught on Game Over, never in play, and only
  # after a game whose mistake had the bright dot hidden beneath.
  def test_game_over_teaches_the_stack_after_a_wrong_tap_over_the_bright_dot
    store = DotPopper::ScoreRecord::Memory.new
    @show = new_show(cabinet: @cabinet, layout:, sounds: @sounds, radius: R, random: Random.new(3),
                     tutor: Tutor.new(store, times: 1))
    start_and_pop
    popped = @cabinet.game.dots.first
    clear_around!(@cabinet.game, popped)
    @show.tap(popped.x, popped.y)
    @cabinet.update(20)
    assert_nil @show.game_over.lesson, "a mistake with nothing under it teaches nothing"

    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    hide_bright_under_a_popped_dot_and_tap_it
    popped = @cabinet.game.dots.first
    bright = @cabinet.game.dots.find(&:bright?)
    @cabinet.update(20)
    assert_equal Mistake.new(popped: popped.id, bright: bright.id), @show.game_over.lesson, "the mistake is the lesson"
    assert_equal "1", store.read
    refute @show.game_over_plan.placed.key?(:lesson), "with no word"

    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    press_main
    hide_bright_under_a_popped_dot_and_tap_it(started: true)
    @cabinet.update(20)
    assert_nil @show.game_over.lesson, "it has been taught as often as it is"
  end

  # On the pile, the mistake's penalty replays as it played, after the
  # score has counted, a few times: the popped dot's shudder and alarm
  # ring, and the dashed outline of the bright dot under it, which
  # pulses. The screen never shakes, and Continue works as ever.
  def test_game_overs_lesson_replays_the_wrong_tap_on_the_pile
    hide_bright_under_a_popped_dot_and_tap_it
    popped = @cabinet.game.dots.first
    bright = @cabinet.game.dots.find(&:bright?)
    @cabinet.update(20)
    @show.update(Style::LESSON.every)
    @show.effects.update(Style::REVEAL.duration)
    @sounds.played.clear

    @show.update(Style::GAME_OVER.tally.duration)
    assert_equal [bright.id], @show.effects.reveals.map(&:follow), "the bright dot is outlined"
    assert_includes @show.effects.rings.map { [it.style, it.follow] }, [Style::ALARM_RING, popped.id]
    assert_includes @show.effects.rings.map { [it.style, it.follow] }, [Style::SPAWN_RIPPLE, bright.id], "and pulses"
    assert_operator @show.animations.pose(popped, @show.now + 0.05).alarm, :>, 0.0, "the popped dot shudders"
    assert_in_delta 0.0, @show.effects.shake_x
    assert_empty @sounds.played, "quietly"

    (Style::LESSON.replays * 2).times { @show.update(Style::LESSON.every) }
    assert_equal Style::LESSON.replays, @show.game_over.replayed, "a few times, and no more"
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    assert @show.home?, "Continue works as ever"
  end

  # Once the bright dot it hid has been popped, the pile can't show which
  # it was, so Game Over shows nothing, and that Game Over doesn't count.
  def test_a_wrong_tap_whose_bright_dot_was_popped_later_teaches_nothing
    store = DotPopper::ScoreRecord::Memory.new
    @show = new_show(cabinet: @cabinet, layout:, sounds: @sounds, radius: R, random: Random.new(3),
                     tutor: Tutor.new(store, times: 2))
    hide_bright_under_a_popped_dot_and_tap_it
    bright = @cabinet.game.dots.find(&:bright?)
    clear_around!(@cabinet.game, bright)
    @show.tap(bright.x, bright.y)
    @cabinet.update(20)

    assert_nil @show.game_over.lesson
    assert_nil store.read
  end

  def test_a_wrong_tap_with_the_bright_dot_elsewhere_reveals_nothing
    start_and_pop
    popped = @cabinet.game.dots.first
    clear_around!(@cabinet.game, popped)
    @show.tap(popped.x, popped.y)

    assert_empty @show.effects.reveals
  end

  def test_game_over_counts_up_then_asks_to_continue_once_ready
    start_and_pop
    @cabinet.update(20)
    @show.update(0.1)

    assert @show.game_over?
    assert_equal :game_over, @sounds.names.last, "a first game has no record to beat"
    assert @show.game_over.first
    assert_equal 1, @show.game_over.stats.dots_popped
    assert_in_delta 0.0, @show.game_over.prompt(@show.now)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.update(0.01)
    @show.update(1.0)
    assert_equal 1, @show.game_over.shown_score(@show.now)
    assert_operator @show.game_over.prompt(@show.now), :>, 0.9
    refute @show.game_over.celebrated, "only a beaten record is celebrated"
  end

  def test_the_last_seconds_tick
    press_main
    105.times do
      @cabinet.update(0.1)
      @show.update(0.1)
    end

    assert_equal 3, @sounds.names.count(:tick)
    assert_equal :game_over, @sounds.names.last
  end

  def test_back_on_home_the_effects_are_cleared
    start_and_pop
    @cabinet.update(20)
    @cabinet.update(1)
    press_main

    assert @show.home?
    assert_empty @show.effects.floaters
  end

  private

  def middle(rect) = [rect.center_x, rect.center_y]

  def put!(id, x, y)
    game = @cabinet.game
    game.instance_variable_set(:@dots, game.dots.map_dots { it.id == id ? it.with(x:, y:) : it })
  end

  def reach(sizing) = @show.sizing_reaches.to_h.fetch(sizing)

  def hide_bright_under_a_popped_dot_and_tap_it(started: false)
    start_and_pop(started:)
    popped = @cabinet.game.dots.first
    bright = @cabinet.game.dots.find(&:bright?)
    clear_around!(@cabinet.game, popped)
    put!(bright.id, popped.x + 30, popped.y)
    @show.tap(popped.x - 20, popped.y)
    assert_equal 1, @show.effects.reveals.size
  end

  def finish_game(back_to_title: true)
    start_and_pop
    @cabinet.update(20)
    return unless back_to_title

    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
  end

  def start_and_pop(started: false)
    press_main unless started
    bright = @cabinet.game.dots.find(&:bright?)
    clear_around!(@cabinet.game, bright)
    @show.tap(bright.x, bright.y)
  end
end
