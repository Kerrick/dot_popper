# frozen_string_literal: true

require_relative "presentation_helper"

class ShowTest < Minitest::Test
  include PresentationTest

  def setup
    @sounds = FakeSounds.new
    @game = DotPopper::Game.new(field, random: Random.new(2))
    @clipboard = MemoryClipboard.new
    @sizing_store = DotPopper::BestScore::Memory.new
    @show = Show.new(game: @game, layout: layout, sounds: @sounds, radius: R, random: Random.new(3),
                     clipboard: @clipboard, sizing_store: @sizing_store)
  end

  def test_a_tap_on_a_title_dot_pops_it_for_fun_and_starts_nothing
    dots = @show.attract.dots
    fresh = dots.find { it.fresh? && dots.top_at(it.x, it.y) == it && @show.control_at(it.x, it.y).nil? }
    @show.tap(fresh.x, fresh.y)

    assert @show.title?
    assert_equal %i[pop], @sounds.names
    assert_equal 1, @show.effects.rings.size
  end

  # Play starts a round; empty space beside it does nothing.
  def test_only_play_starts_a_round
    @show.tap(5, 5)
    assert @show.title?

    @show.tap(*middle(@show.play_reach))
    assert @show.playing?
    assert_equal 0, @game.round.score
  end

  # Play is at least a dot fitted to the screen across, whichever size is
  # chosen, and a press reaches it a margin past its edges.
  def test_play_is_big_and_easy_to_reach
    button = @show.title_plan.play_button
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
    assert @show.playing?, "in a round it does nothing"
    @game.update(20)
    @show.tap(5, 5, by: :gamepad)
    assert @show.finished?, "the grace still holds"
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.tap(5, 5, by: :mouse)
    assert @show.finished?, "a click on empty space is the pile's"
    @show.tap(5, 5, by: :gamepad)
    assert @show.title?
  end

  # The words name the press the player last made: a click to start,
  # until a gamepad or a finger is used.
  def test_the_words_follow_the_input_last_used
    assert_equal [InputKind::MOUSE, "Play"], [@show.input, @show.words.play]
    @show.input = InputKind::GAMEPAD
    assert_equal "Play (A)", @show.words.play
    @show.input = InputKind::TOUCH
    assert_equal "Play", @show.words.play
    assert_equal "Continue",
                 Show.new(game: @game, layout:, sounds: @sounds, radius: R, input: InputKind::TOUCH).words.continue
  end

  RESULT = "Dot Popper: 1 point\n🟡 1 pop · ⚫ 0 mistakes · ⏱ 11 seconds\n" \
           "Played on a screen about 8 dots wide and 6 dots tall."

  # "Share my score" only shows the result: the clipboard changes only
  # when the player presses Copy, and then to exactly what was shown.
  def test_share_my_score_shows_the_result_and_only_copy_copies_it
    start_and_pop
    @game.update(20)
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.update(0.1)
    @show.tap(*middle(@show.share_reach))

    assert @show.finished?
    assert @show.sharing?
    assert_equal RESULT, @show.share_preview.text
    assert_nil @clipboard.text, "opening the preview copies nothing"
    refute @show.share_preview.copied?

    @show.tap(*middle(@show.copy_reach))

    assert_equal RESULT, @clipboard.text
    assert @show.share_preview.copied?
    assert @show.sharing?, "the preview stays open to say it was copied"
    assert @show.finished?
  end

  def test_the_share_preview_closes_by_close_by_back_and_by_a_tap_beside_it
    finish_round(back_to_title: false)
    @show.share
    @show.tap(*middle(@show.close_reach))
    refute @show.sharing?, "Close closes it"

    @show.share
    assert @show.back, "Escape and B close it"
    refute @show.sharing?
    assert @show.finished?, "and go no further than Game Over"

    @show.share
    card = @show.share_plan.card
    @show.tap(card.x + 2, card.y + 2)
    assert @show.sharing?, "a tap on the card, away from its buttons, does nothing"
    @show.tap(card.x - 5, card.y - 5)
    refute @show.sharing?, "a tap beside the card closes it"
    assert_nil @clipboard.text
  end

  # In the preview, the main button is Copy: Enter, Space, Start, a
  # gamepad's A aimed at nothing, and Y again all copy.
  def test_in_the_share_preview_the_main_button_and_y_copy
    finish_round(back_to_title: false)
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
  # press, and once it closes, Continue goes on as before.
  def test_the_share_preview_leaves_game_over_and_continue_as_they_were
    finish_round(back_to_title: false)
    continue = middle(@show.continue_reach)
    @show.share
    assert_equal %i[close copy], @show.controls.map(&:name).sort, "only the preview's buttons take a press"
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    assert @game.state.ready?, "the grace runs on under the preview"
    @show.primary
    assert @show.finished?, "the main button copies there, and goes nowhere"
    refute @show.waits_for_release?(*continue), "no press under the preview drags the pile"

    @show.close_share
    @show.tap(*continue)
    assert @show.title?
    refute @show.sharing?
  end

  # A phone's own share sheet can take the preview's place (Show's
  # +sharing+): offered the result, it opens no preview.
  def test_a_system_share_sheet_can_stand_in_for_the_preview
    sheet = Class.new do
      attr_reader :offered

      def offer(text, _now) = (@offered = text) && nil
    end.new
    show = Show.new(game: @game, layout:, sounds: @sounds, radius: R, clipboard: @clipboard, sharing: sheet)
    press_main(show)
    @game.update(20)
    show.share

    assert_match(/\ADot Popper: 0 points\n/, sheet.offered)
    refute show.sharing?
    assert_nil @clipboard.text
  end

  def test_each_finished_round_is_added_to_the_lifetime_stats
    start_and_pop
    @game.update(20)

    assert_equal 1, @show.lifetime.stats.rounds
    assert_equal 1, @show.lifetime.stats.pops
    assert_equal [1], @show.lifetime.stats.recent
  end

  def test_game_over_names_the_best_record_the_round_set
    start_and_pop
    @game.update(20)
    assert_nil @show.finale.record, "a first round has nothing to beat"

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @game.press(10, 10)
    @game.press(10, 10)
    2.times { start_and_pop(started: true) }
    @game.update(30)

    assert_equal :longest_run, @show.finale.record.kind
    assert_equal 2, @show.finale.record.value
  end

  # 2026-11-01's goal is to pop 10 bright dots in the first 10 seconds.
  def test_the_round_that_meets_todays_goal_celebrates_it_once_the_score_has_counted
    lifetime = DotPopper::Lifetime.new(DotPopper::BestScore::Memory.new, today: -> { Date.new(2026, 11, 1) })
    show = Show.new(game: @game, layout:, sounds: @sounds, radius: R, random: Random.new(3), lifetime:)
    press_main(show)
    10.times do
      fresh = @game.round.dots.find(&:fresh?)
      clear_around!(@game.round, fresh)
      show.tap(fresh.x, fresh.y)
    end
    @game.update(30)

    assert show.finale.goal_met
    refute show.finale.goal_due?(show.now), "not before the score has counted"
    show.update(Look::FINALE.tally.duration)
    assert show.finale.goal_celebrated
    assert lifetime.goal_done?
  end

  def test_continue_goes_on_once_the_grace_is_over_and_empty_space_never_does
    press_main
    @game.update(20)
    @show.update(0.1)
    press_main
    assert @show.finished?, "the grace still holds"

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.tap(5, 5)
    assert @show.finished?, "empty space is only for the pile"
    press_main
    assert @show.title?
    assert_nil @clipboard.text
  end

  def test_back_goes_on_from_game_over_and_leaves_nothing_else
    refute @show.back
    press_main
    refute @show.back, "in a round it does nothing"
    @game.update(20)
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    assert @show.back
    assert @show.title?
  end

  # Game Over's presses wait for their release, since each may become a
  # drag of the pile; a round's and the buttons' never do.
  def test_only_game_over_waits_for_a_press_to_be_let_go
    refute @show.waits_for_release?(10, 10)
    press_main
    refute @show.waits_for_release?(10, 10)
    @game.update(20)

    assert @show.waits_for_release?(10, 10)
    refute @show.waits_for_release?(*middle(@show.share_reach))
    refute @show.waits_for_release?(*middle(@show.continue_reach))
  end

  def test_share_my_score_takes_taps_where_its_plan_draws_it
    finish_round(back_to_title: false)
    button = @show.finale_plan.share_button

    reach = @show.share_reach
    assert reach.contains?(button.center_x, button.center_y)
    assert_operator reach.height, :>=, button.height
    refute reach.overlaps?(@show.continue_reach), "a press reaches one button"
    assert_operator @show.finale_plan.backing.bottom, :<=, @show.finale_plan.continue_button.y,
                    "the backing ends above Continue"
    assert_operator @show.finale_plan.backing.bottom, :>=, button.bottom, "and holds Share my score, with the score"
  end

  def test_the_share_buttons_place_on_the_title_shares_nothing
    finish_round(back_to_title: false)
    place = middle(@show.share_reach)
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    assert @show.title?
    assert_nil @show.share_reach

    @show.tap(*place)

    refute @show.sharing?
    assert_nil @clipboard.text
  end

  def test_the_mute_button_takes_its_own_tap_on_the_title
    button = @show.layout.mute_button
    @show.tap(button.center_x, button.center_y)

    assert @sounds.muted?
    assert @show.title?
  end

  def test_your_records_is_offered_only_once_a_round_has_finished
    refute @show.records_offered?
    assert_nil @show.records_reach
    @show.tap(*middle(@show.layout.records_button))
    assert @show.title?, "before then, its corner is empty space, which does nothing"

    finish_round
    assert @show.records_offered?
  end

  # 800 by 600 fits a radius of about 35 when dots are sized to it.
  def test_the_dot_size_choice_switches_on_the_title_and_is_remembered
    finish_round
    assert_operator @show.marquee.best, :>, 0

    @show.tap(*middle(reach(DotPopper::DotSizing::SIZED_TO_SCREEN)))
    assert @show.title?, "the tap never starts a round"
    assert @game.sizing.sized_to_screen?
    assert_equal DotPopper::DotSizing::SIZED_TO_SCREEN.to_text, @sizing_store.read
    assert_in_delta 35.4, @show.attract.dots.first.radius, 0.1
    assert_equal 0, @show.marquee.best, "the title shows this choice's best"

    press_main
    assert_in_delta 35.4, @game.round.field.radius, 0.1

    @game.update(20)
    assert_equal "Played with dots sized to the screen.", @show.finale.screen
  end

  # A tap on a segment chooses it, so tapping the chosen one again keeps
  # it; a shoulder button switches to the other.
  def test_each_segment_of_the_dot_size_choice_chooses_it
    finish_round
    same = DotPopper::DotSizing::STANDARD
    @show.tap(*middle(reach(same)))
    refute @game.sizing.sized_to_screen?
    assert_nil @sizing_store.read, "nothing changed, so nothing is saved"

    @show.toggle_sizing
    assert @game.sizing.sized_to_screen?
    @show.tap(*middle(reach(same)))
    refute @game.sizing.sized_to_screen?
    assert @show.title?
  end

  # The maintainer didn't see why Play changed size with the Dot size
  # choice: it was sized from the chosen dots. It never moves now.
  def test_choosing_a_dot_size_leaves_play_where_it_is
    finish_round
    play = @show.send(:title_plan).play_button
    @show.toggle_sizing

    assert_equal play, @show.send(:title_plan).play_button
  end

  # Laying the title out took a millisecond a frame on a phone, twice a
  # frame; it is laid out again only when something on it changes.
  def test_the_title_is_laid_out_again_only_when_it_changes
    plan = @show.title_plan

    assert_same plan, @show.title_plan
    finish_round

    refute_same plan, @show.title_plan, "a played round brings the records and the goal"
    assert_same @show.title_plan, @show.title_plan
    wider = @show.title_plan
    @show.resize(layout(400, 850), field(400, 850))

    refute_equal wider.play_button, @show.title_plan.play_button
  end

  def test_game_over_is_laid_out_again_only_when_it_changes
    finish_round(back_to_title: false)
    plan = @show.finale_plan

    assert_same plan, @show.finale_plan
  end

  # The maintainer, on a controller alone, couldn't find how to quit. B
  # on the title asks, and a second B within two seconds quits.
  def test_b_twice_on_the_title_quits_and_once_only_asks
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

  def test_b_never_quits_from_a_round_or_the_records
    finish_round(back_to_title: false)

    assert_nil @show.ask_to_quit
  end

  def test_the_dot_size_choice_is_offered_only_once_a_round_has_finished
    assert_nil reach(DotPopper::DotSizing::SIZED_TO_SCREEN)
    @show.tap(*middle(@show.layout.sizing_control.options.first))

    assert @show.title?
    refute @game.sizing.sized_to_screen?
  end

  # On the 24 × 16 R window, dots sized to it are the standard size, so
  # the title leaves the choice out, and neither its segments nor a
  # shoulder button change the saved one.
  def test_where_the_sizes_look_alike_the_choice_is_not_offered
    game = DotPopper::Game.new(field(1200, 800), random: Random.new(2), sizing: DotPopper::DotSizing::SIZED_TO_SCREEN)
    show = Show.new(game:, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, sizing_store: @sizing_store)
    game.press(10, 10)
    game.update(20)
    game.update(DotPopper::Rules::GAME_OVER_GRACE)
    game.press(10, 10)
    assert show.records_offered?
    refute show.sizing_offered?

    show.toggle_sizing
    assert game.sizing.sized_to_screen?, "the saved choice stays"
    assert_nil show.sizing_reaches.to_h.fetch(DotPopper::DotSizing::STANDARD)
    show.tap(*middle(show.layout.sizing_control.options.last))
    assert game.state.is_a?(DotPopper::Game::Title), "where the control would be is empty space"
    assert_nil @sizing_store.read
  end

  # Resizing the window brings the choice back, or takes it away.
  def test_the_choice_comes_and_goes_as_the_window_is_resized
    finish_round
    assert @show.sizing_offered?

    @game.screen = field(1200, 800)
    @show.resize(layout(1200, 800), @game.field)
    refute @show.sizing_offered?

    @game.screen = field(400, 850)
    @show.resize(layout(400, 850), @game.field)
    assert @show.sizing_offered?
    assert_equal :smaller, @show.sizing_preview.effect
  end

  def test_your_records_opens_over_the_title_and_back_goes_back
    finish_round
    @show.tap(*middle(@show.records_reach))
    assert @show.records?
    assert @show.title?
    assert_equal 1, @show.records.totals.rows.first.value.to_i

    @show.tap(10, 300)
    assert @show.records?, "empty space does nothing"
    @show.tap(*middle(@show.back_reach))
    refute @show.records?
    assert @show.title?, "Back never starts a round"
  end

  def test_start_and_back_leave_the_records_screen_and_only_it
    finish_round
    @show.open_records
    @show.start
    refute @show.records?
    assert @show.title?

    @show.open_records
    assert @show.back
    refute @show.back, "with no Records screen, back has nothing to do"
    assert @show.title?
  end

  def test_the_records_screen_opens_only_from_the_title
    finish_round(back_to_title: false)
    @show.open_records

    refute @show.records?
  end

  def test_a_gamepads_start_begins_the_usual_round_without_popping_a_title_dot
    @show.start

    assert @show.playing?
    assert_equal [:start], @sounds.names
  end

  def test_start_does_nothing_in_a_round
    @show.start
    score = @game.round.score
    clock = @game.round.countdown
    @show.start

    assert @show.playing?
    assert_equal [score, clock], [@game.round.score, @game.round.countdown]
  end

  def test_start_continues_from_game_over_after_the_grace
    @show.start
    @game.update(20)
    @show.start
    assert @show.finished?, "the grace still holds"

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.start
    assert @show.title?
  end

  def test_a_gamepads_y_shares_the_result_on_game_over_and_nothing_else
    @show.share
    assert @show.title?, "Y does nothing on the title"
    refute @show.sharing?

    @show.start
    @show.share
    assert @show.playing?, "Y does nothing in a round"
    refute @show.sharing?

    @game.update(20)
    @show.update(0.1)
    @show.share
    assert @show.finished?
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
    assert_equal [Look::POP_BURST], @show.effects.take_sprays.map(&:look)
    assert_equal 2, @show.effects.rings.size
  end

  def test_a_pop_buzzes_briefly_and_a_wrong_tap_longer
    haptics = FakeHaptics.new
    @show = Show.new(game: @game, layout: layout, sounds: @sounds, radius: R, random: Random.new(3), haptics:)
    start_and_pop
    popped = @game.round.dots.find(&:popped?)
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y)

    assert_equal [Look::HAPTICS.pop, Look::HAPTICS.penalty], haptics.buzzes
    assert_operator Look::HAPTICS.penalty, :>, Look::HAPTICS.pop
  end

  def test_a_pop_is_heard_where_it_is
    start_and_pop
    x = @game.round.dots.find(&:popped?).x

    assert_in_delta Look::SOUND.stereo.pan(x, 800), @sounds.pans.last
  end

  def test_the_pop_climbs_with_the_score_up_to_a_cap
    press_main
    score!(@game.round, 1000)
    start_and_pop(started: true)

    assert_in_delta Look::SOUND.pop_highest, @sounds.played.last.last
  end

  def test_a_wrong_tap_shows_only_what_was_lost
    start_and_pop
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y) # the score falls from 1 to 0: only 1 lost

    assert_equal ["−1", "−2s"], @show.effects.floaters.last(2).map(&:text)
    assert_equal :bonk, @sounds.names.last
    assert_operator @show.effects.flash_alpha, :>, 0
  end

  def test_a_wrong_tap_at_zero_shows_only_the_seconds
    start_and_pop
    score!(@game.round, 0)
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y)

    assert_equal "−2s", @show.effects.floaters.last.text
  end

  def test_a_wrong_tap_over_the_fresh_dot_outlines_it
    start_and_pop
    popped = @game.round.dots.first
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, popped)
    put!(fresh.id, popped.x + 30, popped.y)
    @show.tap(popped.x - 20, popped.y)

    assert_equal [fresh.id], @show.effects.reveals.map(&:follow)
    @show.update(Look::REVEAL.duration)
    assert_empty @show.effects.reveals
  end

  # The stacking rule is taught on Game Over, never in play, and only
  # after a round whose wrong tap had the bright dot hidden beneath.
  def test_game_over_teaches_the_stack_after_a_wrong_tap_over_the_fresh_dot
    store = DotPopper::BestScore::Memory.new
    @show = Show.new(game: @game, layout:, sounds: @sounds, radius: R, random: Random.new(3),
                     tutor: Tutor.new(store, times: 1))
    start_and_pop
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y)
    @game.update(20)
    assert_nil @show.finale.lesson, "a wrong tap with nothing under it teaches nothing"

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    hide_fresh_under_a_popped_dot_and_tap_it
    popped = @game.round.dots.first
    fresh = @game.round.dots.find(&:fresh?)
    @game.update(20)
    assert_equal Slip.new(popped: popped.id, bright: fresh.id), @show.finale.lesson, "the wrong tap is the lesson"
    assert_equal "1", store.read
    refute @show.finale_plan.placed.key?(:lesson), "with no word"

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    press_main
    hide_fresh_under_a_popped_dot_and_tap_it(started: true)
    @game.update(20)
    assert_nil @show.finale.lesson, "it has been taught as often as it is"
  end

  # On the pile, the wrong tap's penalty replays as it played, after the
  # score has counted, a few times: the popped dot's shudder and alarm
  # ring, and the dashed outline of the bright dot under it, which
  # pulses. The screen never shakes, and Continue works as ever.
  def test_game_overs_lesson_replays_the_wrong_tap_on_the_pile
    hide_fresh_under_a_popped_dot_and_tap_it
    popped = @game.round.dots.first
    fresh = @game.round.dots.find(&:fresh?)
    @game.update(20)
    @show.update(Look::LESSON.every)
    @show.effects.update(Look::REVEAL.duration)
    @sounds.played.clear

    @show.update(Look::FINALE.tally.duration)
    assert_equal [fresh.id], @show.effects.reveals.map(&:follow), "the bright dot is outlined"
    assert_includes @show.effects.rings.map { [it.look, it.follow] }, [Look::ALARM_RING, popped.id]
    assert_includes @show.effects.rings.map { [it.look, it.follow] }, [Look::SPAWN_RIPPLE, fresh.id], "and pulses"
    assert_operator @show.animations.pose(popped, @show.now + 0.05).alarm, :>, 0.0, "the popped dot shudders"
    assert_in_delta 0.0, @show.effects.shake_x
    assert_empty @sounds.played, "quietly"

    (Look::LESSON.replays * 2).times { @show.update(Look::LESSON.every) }
    assert_equal Look::LESSON.replays, @show.finale.replayed, "a few times, and no more"
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
    assert @show.title?, "Continue works as ever"
  end

  # Once the bright dot it hid has been popped, the pile can't show which
  # it was, so Game Over shows nothing, and that Game Over doesn't count.
  def test_a_wrong_tap_whose_bright_dot_was_popped_later_teaches_nothing
    store = DotPopper::BestScore::Memory.new
    @show = Show.new(game: @game, layout:, sounds: @sounds, radius: R, random: Random.new(3),
                     tutor: Tutor.new(store, times: 2))
    hide_fresh_under_a_popped_dot_and_tap_it
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, fresh)
    @show.tap(fresh.x, fresh.y)
    @game.update(20)

    assert_nil @show.finale.lesson
    assert_nil store.read
  end

  def test_a_wrong_tap_with_the_fresh_dot_elsewhere_reveals_nothing
    start_and_pop
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y)

    assert_empty @show.effects.reveals
  end

  def test_game_over_counts_up_then_asks_to_continue_once_ready
    start_and_pop
    @game.update(20)
    @show.update(0.1)

    assert @show.finished?
    assert_equal :game_over, @sounds.names.last, "a first round has no best to beat"
    assert @show.finale.first
    assert_equal 1, @show.finale.stats.pops
    assert_in_delta 0.0, @show.finale.prompt(@show.now)
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.update(0.01)
    @show.update(1.0)
    assert_equal 1, @show.finale.shown_score(@show.now)
    assert_operator @show.finale.prompt(@show.now), :>, 0.9
    refute @show.finale.celebrated, "only a beaten best is celebrated"
  end

  def test_the_last_seconds_tick
    press_main
    105.times do
      @game.update(0.1)
      @show.update(0.1)
    end

    assert_equal 3, @sounds.names.count(:tick)
    assert_equal :game_over, @sounds.names.last
  end

  def test_back_on_the_title_the_effects_are_cleared
    start_and_pop
    @game.update(20)
    @game.update(1)
    press_main

    assert @show.title?
    assert_empty @show.effects.floaters
  end

  private

  def middle(rect) = [rect.center_x, rect.center_y]

  def put!(id, x, y)
    round = @game.round
    round.instance_variable_set(:@dots, round.dots.map_dots { it.id == id ? it.with(x:, y:) : it })
  end

  def reach(sizing) = @show.sizing_reaches.to_h.fetch(sizing)

  def hide_fresh_under_a_popped_dot_and_tap_it(started: false)
    start_and_pop(started:)
    popped = @game.round.dots.first
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, popped)
    put!(fresh.id, popped.x + 30, popped.y)
    @show.tap(popped.x - 20, popped.y)
    assert_equal 1, @show.effects.reveals.size
  end

  def finish_round(back_to_title: true)
    start_and_pop
    @game.update(20)
    return unless back_to_title

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
  end

  def start_and_pop(started: false)
    press_main unless started
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, fresh)
    @show.tap(fresh.x, fresh.y)
  end
end
