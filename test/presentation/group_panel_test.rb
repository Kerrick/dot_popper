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
    members ||= [{ "id" => 1, "name" => "Kai", "holder" => true, "blocked" => false, "me" => true },
                 { "id" => 2, "name" => "Sam", "holder" => false, "blocked" => false, "me" => false }]
    { "code" => "ABC234", "members" => members, "news" => news,
      "trophy" => { "holder_id" => 1, "holder_name" => "Kai", "score" => 20, "standing" => 18, "days_held" => 2 } }
  end

  def setup
    @sounds = FakeSounds.new
    @worker = HandWorker.new
    @session = Groups::Session.new(store: DotPopper::BestScore::Memory.new, worker: @worker)
    @paid = DotPopper::Entitlement.free
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

  def tick(seconds = 0.016) = @show.update(seconds)

  def reply(status, body)
    @worker.answer(Reply.new(status:, body:))
    tick
  end

  def join!(news: [])
    panel.open
    tick
    tap_control(:group_name)
    panel.type("Kai")
    tap_control(:group_code)
    panel.type("abc234")
    tap_control(:group_join)
    tick
    reply(201, { "token" => "t", "id" => 1 })
    tick
    reply(200, { "group" => group(news:) })
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

  def test_typing_is_uppercased_for_codes_and_limited
    panel.open
    tick
    tap_control(:group_code)
    panel.type("abc234xx")

    assert_equal "ABC234", panel.code
  end

  def test_create_needs_paid_and_says_so
    panel.open
    tick
    tap_control(:group_name)
    panel.type("Kai")
    tap_control(:group_create)

    assert_equal GroupWords.needs_paid, panel.note
    assert_empty @worker.started
  end

  def test_create_with_paid_makes_a_group
    @paid = DotPopper::Entitlement.new(DotPopper::BestScore::Memory.new, forced: true)
    build
    panel.open
    tick
    tap_control(:group_name)
    panel.type("Kai")
    tap_control(:group_create)
    tick

    assert_equal 1, @worker.started.size
  end

  def test_join_needs_a_name_and_a_code
    panel.open
    tick
    tap_control(:group_join)

    assert_equal GroupWords.need_name, panel.note
  end

  def test_a_member_sees_the_trophy_the_code_and_buttons_for_others
    join!
    plan = @show.group_plan

    assert(plan.lines.any? { it.text.include?("Beat 18") })
    assert(plan.lines.any? { it.text.include?("ABC234") })
    assert_empty plan.rows.first.actions
    assert_equal [[:group_report, 2], [:group_block, 2]], plan.rows.last.actions.map(&:name)
  end

  def test_blocking_sends_it_and_report_says_so
    join!
    tap_control([:group_report, 2])
    tick

    assert_equal "/v1/members/2/report", @worker.started.first.first.path
    assert_equal GroupWords.reported, panel.note
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
    members = Array.new(8) { { "id" => it + 2, "name" => "Friend#{it}", "holder" => false, "blocked" => false, "me" => false } }
    build(width: 844, height: 390)
    panel.open
    tick
    @session.instance_variable_set(:@group, group(members:))
    plan = @show.group_plan

    assert(plan.rows.all? { it.rect.bottom <= @show.layout.records_floor })
    assert_equal 8, plan.rows.size
    assert_operator plan.rows.map { it.rect.x }.uniq.size, :>, 1
  end

  def test_a_message_waits_for_launch_or_game_over_and_shows_once
    join!(news: [{ "id" => 9, "thief" => "Sam", "score" => 21 }])
    tick

    assert_nil panel.banner, "not while the group screen covers it"

    panel.close
    tick

    assert_includes panel.banner.text, "Sam took your trophy"
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
