# frozen_string_literal: true

require_relative "presentation_helper"

class GroupPanelTest < Minitest::Test
  include PresentationTest

  Groups = DotPopper::Groups
  Reply = Groups::Reply

  class HandWorker
    attr_reader :started

    def initialize = (@started = []) && (@answers = [])
    def start(job, token) = @started << [job, token]
    def finished = @answers.shift(@answers.size)
    def answer(reply) = @answers << [@started.shift.first, reply]
  end

  def group(news: [], members: nil)
    members ||= [{ "look" => 0, "you" => true }, { "look" => 1, "you" => false }]
    { "join_code" => "2345678", "members" => members, "news" => news, "holder_look" => 0, "score_to_beat" => 18 }
  end

  def setup
    @sounds = FakeSounds.new
    @worker = HandWorker.new
    @session = Groups::Session.new(store: DotPopper::BestScore::Memory.new, worker: @worker)
    @paid = DotPopper::Entitlement.new(DotPopper::BestScore::Memory.new, forced: true)
    @game = DotPopper::Game.new(field)
    build
  end

  def build(width: 800, height: 600)
    @show = Show.new(game: @game, layout: layout(width, height), sounds: @sounds, radius: R,
                     entitlement: @paid, groups: @session)
  end

  def panel = @show.group_panel

  def tap_control(name)
    reach = @show.controls.find { it.name == name }.reach
    @show.tap(reach.center_x, reach.center_y)
  end

  def tap_code(digits) = digits.each_char { tap_control([:group_digit, it]) }

  def tick(seconds = 0.016) = @show.update(seconds)

  def reply(status, body)
    @worker.answer(Reply.new(status:, body:))
    tick
  end

  def join!(news: [])
    panel.open
    tick
    tap_control([:group_mark, 3])
    tap_code("2345678")
    tap_control(:group_join)
    tick
    reply(201, { "token" => "t" })
    tick
    reply(201, group(news:))
  end

  def test_no_server_offers_no_group
    show = Show.new(game: @game, layout: layout, sounds: @sounds, radius: R)

    refute_predicate show, :group_offered?
    assert_nil(show.controls.find { it.name == :group_open })
  end

  def test_with_a_server_the_title_offers_it_once_a_round_is_played
    refute_predicate @show, :group_offered?
    play_round(5)

    assert_predicate @show, :group_offered?
  end

  def test_opening_the_screen_is_over_the_title_and_blocks_play
    panel.open

    assert_predicate @show, :group_open?
    assert_nil @show.play_reach
    @show.play

    assert_kind_of DotPopper::Game::Title, @game.state
  end

  def test_a_code_is_tapped_in_digits_and_limited
    panel.open
    tick
    tap_code("234567890")

    assert_equal "2345678", panel.code
    tap_control(:group_erase)

    assert_equal "234567", panel.code
  end

  def test_join_needs_paid_and_says_so
    @paid = DotPopper::Entitlement.free
    build
    panel.open
    tick
    tap_control(:group_join)

    assert_equal GroupWords.needs_paid, panel.note
    assert_empty @worker.started
  end

  def test_create_needs_paid_and_says_so
    @paid = DotPopper::Entitlement.free
    build
    panel.open
    tick
    tap_control(:group_create)

    assert_equal GroupWords.needs_paid, panel.note
    assert_empty @worker.started
  end

  def test_create_with_paid_makes_a_group
    build
    panel.open
    tick
    tap_control(:group_create)
    tick

    assert_equal 1, @worker.started.size
  end

  def test_join_needs_a_whole_code
    panel.open
    tick
    tap_code("234")
    tap_control(:group_join)

    assert_equal GroupWords.need_code, panel.note
    assert_empty @worker.started
  end

  def test_a_member_sees_the_trophy_the_code_and_buttons_for_others
    join!
    plan = @show.group_plan

    assert(plan.lines.any? { it.text.include?("Beat 18") })
    assert_equal [0, 1], plan.rows.map(&:mark)
    assert_equal [true, false], plan.rows.map(&:holder)
    assert_equal [true, false], plan.rows.map(&:me)
  end

  def test_joining_sends_the_picked_dot_and_the_code_and_nothing_typed
    panel.open
    tick
    tap_control([:group_mark, 5])
    tap_code("2345678")
    tap_control(:group_join)
    tick
    tick

    assert_nil @worker.started.first.first.body
    reply(201, { "token" => "t" })
    tick

    assert_equal({ join_code: "2345678", look: 5 }, @worker.started.first.first.body)
  end

  def test_the_door_has_no_field_for_text_and_the_screen_offers_no_report_or_block
    panel.open
    tick
    names = @show.group_plan.controls.map(&:first)

    assert_nil @show.group_plan.lines.find { it.text.match?(/name/i) }
    refute_respond_to panel, :type
    refute_respond_to panel, :editing?
    assert_equal Array.new(8) { [:group_mark, it] }, names.select { it.is_a?(Array) && it.first == :group_mark }
    assert_equal 10, names.count { it.is_a?(Array) && it.first == :group_digit }
    join!
    refute(@show.group_plan.controls.map(&:first).any? { it.to_s.match?(/report|block/) })
  end

  def test_a_theft_message_names_no_one_and_shows_the_thiefs_dot
    join!(news: [{ "id" => 9, "thief_look" => 4, "score" => 21 }])
    panel.close
    tick

    assert_equal 4, panel.banner.mark
    assert_equal "A friend took your trophy with 21.", panel.banner.text
  end

  def test_leave_takes_a_long_press
    join!
    tap_control(:group_leave)
    @show.let_go(:tap)
    tick

    assert_empty @worker.started

    tap_control(:group_leave)
    tick(2.1)
    tick

    assert_equal :left, @worker.started.first.first.kind
  end

  def test_delete_is_offered_and_takes_a_long_press
    join!
    tap_control(:group_delete)
    tick(2.1)
    tick

    assert_equal :deleted, @worker.started.first.first.kind
  end

  def test_group_rows_fit_a_small_phones_screen_in_columns_and_above_the_floor
    members = Array.new(8) { { "look" => it, "you" => it == 3 } }
    build(width: 844, height: 390)
    panel.open
    tick
    @session.instance_variable_set(:@group, group(members:))
    plan = @show.group_plan

    assert(plan.rows.all? { it.rect.bottom <= @show.layout.records_floor })
    assert_equal 8, plan.rows.size
    assert_operator plan.rows.map { it.rect.x }.uniq.size, :>, 1
  end

  def test_the_door_fits_every_size_with_nothing_overlapping
    [[1200, 800], [800, 600], [800, 500], [400, 850], [850, 400], [844, 390]].each do |width, height|
      build(width:, height:)
      panel.open
      tick
      plan = @show.group_plan
      rects = plan.actions.map(&:rect) + [plan.code_box]
      body = rects - [@show.layout.back_button, @show.layout.clear_records_button]

      assert(body.all? { it.bottom <= @show.layout.records_floor && it.x >= 0 && it.right <= width }, "inside at #{width}x#{height}")
      assert(rects.combination(2).none? { |a, b| a.x < b.right - 0.5 && b.x < a.right - 0.5 && a.y < b.bottom - 0.5 && b.y < a.bottom - 0.5 }, "no overlap at #{width}x#{height}")
      assert(plan.actions.select { it.name.is_a?(Array) }.all? { it.rect.width >= 30 && it.rect.height >= 30 }, "pressable at #{width}x#{height}")
    end
  end

  def test_a_message_waits_for_launch_or_game_over_and_shows_once
    join!(news: [{ "id" => 9, "thief_look" => 1, "score" => 21 }])
    tick

    assert_nil panel.banner, "not while the group screen covers it"

    panel.close
    tick

    assert_includes panel.banner.text, "took your trophy"
    tick(8.0)

    assert_nil panel.banner
  end

  def test_a_round_with_standard_dots_is_not_reported
    join!
    play_round(10)

    assert_empty @worker.started
  end

  def test_a_round_with_dots_sized_to_the_screen_is_reported
    @game = DotPopper::Game.new(field, sizing: DotPopper::DotSizing::SIZED_TO_SCREEN)
    build
    join!
    play_round(10)

    assert_equal :round, @worker.started.first.first.kind
  end

  private

  # A round played out to its end with +points+ on the board.
  def play_round(points)
    @game.press(0, 0)
    score!(@game.round, points)
    @game.update(1000)
    tick
  end
end
