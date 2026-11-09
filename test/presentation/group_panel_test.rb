# frozen_string_literal: true

require_relative "presentation_helper"

class GroupPanelTest < Minitest::Test
  include PresentationTest

  Groups = DotPopper::Groups
  Reply = Groups::Reply
  Screen = DotPopper::Presentation::GroupScreen
  Words = DotPopper::Presentation::GroupWords

  class HandWorker
    attr_reader :started

    def initialize = (@started = []) && (@answers = [])
    def start(job, token) = @started << [job, token]
    def finished = @answers.shift(@answers.size)
    def answer(reply) = @answers << [@started.shift.first, reply]
  end

  def group(id: 1, numbers: [1, 2], you: 2, champion: 1, top: 18)
    { "id" => id, "join_code" => "2345678", "you" => you, "champion_number" => champion, "top_score" => top,
      "reign_started_at" => "2026-11-01", "members" => numbers.map { { "number" => it, "top_score" => it } } }
  end

  def setup
    @sounds = FakeSounds.new
    @worker = HandWorker.new
    @session = Groups::Session.new(store: DotPopper::ScoreRecord::Memory.new, worker: @worker)
    @pro = DotPopper::Entitlement.new(DotPopper::ScoreRecord::Memory.new, forced: true)
    @cabinet = DotPopper::Cabinet.new(field)
    build
  end

  def build(width: 800, height: 600, entitlement: @pro)
    @show = Show.new(cabinet: @cabinet, layout: layout(width, height), sounds: @sounds, radius: R,
                     entitlement:, groups: @session)
  end

  def panel = @show.group_panel
  def tick(seconds = 0.016) = @show.update(seconds)
  def names = @show.controls.map(&:name)
  def lines = @show.group_plan.lines.map(&:text)

  def tap_control(name)
    reach = @show.controls.find { it.name == name }.reach
    @show.tap(reach.center_x, reach.center_y)
  end

  def reply(status, body = {})
    @worker.answer(Reply.new(status:, body:))
    tick
  end

  def tap_code(digits) = digits.each_char { tap_control([:code_digit, it]) }

  def open_join
    @show.group_panel.open
    tap_control(:group_join_open)
  end

  def join!(body = group)
    open_join
    tap_code("2345678")
    tap_control(:code_submit)
    tick
    reply(201, { "token" => "t" })
    tick
    reply(201, body)
    tick
    answer_all(body)
  end

  # Answers every job waiting, as the server would for this group.
  def answer_all(body, changes: [])
    tick
    until @worker.started.empty?
      path = @worker.started.first.first.path
      reply(200, path.end_with?("title_changes") ? changes : body)
      tick
    end
  end

  def test_the_list_offers_join_and_create
    panel.open

    assert_includes names, :group_join_open
    assert_includes names, :group_create
    assert_includes lines, Words.blurb
  end

  def test_no_screen_has_a_field_for_text_or_a_picker_of_dots
    panel.open

    assert_empty(names.select { it.is_a?(Array) && it.first == :group_mark })
    refute_includes names, :group_report
  end

  def test_join_and_create_look_the_same_to_a_free_player_and_a_pro_one
    build(entitlement: DotPopper::Entitlement.free)
    panel.open
    free = @show.group_plan.actions.map { [it.name, it.text] }
    build(entitlement: @pro)
    panel.open

    assert_equal free, @show.group_plan.actions.map { [it.name, it.text] }
    assert_equal %w[Join Create], @show.group_plan.actions.filter_map { it.text if %i[group_join_open group_create].include?(it.name) }
  end

  def test_joining_leads_a_free_player_to_the_offer_and_back_to_where_they_were
    build(entitlement: DotPopper::Entitlement.free)
    panel.open
    tap_control(:group_join_open)

    assert_predicate @show, :offer?
    assert_equal :groups, @show.offer_focus
    assert_equal "Friend groups", @show.words.offer_items(@show.offer_focus).first
    assert_equal :list, panel.page
    assert_empty @worker.started
    tap_control(:back)

    refute_predicate @show, :offer?
    assert_predicate panel, :open?
    assert_equal :list, panel.page
  end

  def test_creating_leads_a_free_player_to_the_offer_and_starts_nothing
    build(entitlement: DotPopper::Entitlement.free)
    panel.open
    tap_control(:group_create)

    assert_predicate @show, :offer?
    assert_equal :groups, @show.offer_focus
    assert_empty @worker.started
  end

  def test_leaving_and_deleting_never_need_it
    join!
    tap_control(:group_leave)

    assert_predicate panel.hold, :held?
    @pro = DotPopper::Entitlement.free
    build(entitlement: @pro)
    panel.open
    tick

    assert_includes names, :group_delete
  end

  def test_a_short_code_is_not_sent
    open_join
    tap_code("23")
    tap_control(:code_submit)

    assert_equal Words.need_code, panel.note
    assert_empty @worker.started
  end

  def test_the_code_stops_at_seven_and_erases
    open_join
    tap_code("23456789")

    assert_equal 7, panel.code.size
    tap_control(:code_erase)

    assert_equal 6, panel.code.size
  end

  def test_joining_opens_the_group
    join!

    assert_equal :group, panel.page
    assert_equal 1, panel.group_id
  end

  def test_the_standings_are_best_first_with_the_champion_and_you_clear
    join!(group(numbers: [1, 2, 3], you: 3, champion: 2, top: 90))
    rows = @show.group_plan.rows

    assert_equal [2, 3, 1], rows.map(&:number)
    assert_equal [true, false, false], rows.map(&:champion)
    assert_equal [false, true, false], rows.map(&:me)
    assert_includes lines, Words.title_line(panel.group)
    assert_includes lines, Words.code_line("2345678")
  end

  def test_back_climbs_the_screens
    join!
    tap_control(:group_history)

    assert_equal :history, panel.page
    tap_control(:back)

    assert_equal :group, panel.page
    tap_control(:back)

    assert_equal :list, panel.page
    tap_control(:back)

    refute_predicate panel, :open?
  end

  def test_the_list_opens_a_group
    join!
    tap_control(:back)

    assert_includes names, [:group_show, 1]
    tap_control([:group_show, 1])

    assert_equal 1, panel.group_id
  end

  def test_leaving_takes_a_long_press_and_returns_to_the_list
    join!
    tap_control(:group_leave)
    @show.update(0.5)

    assert_predicate panel.group, :itself
    @show.update(3.0)

    assert_equal :list, panel.page
    tick
    reply(204)

    assert_nil @session.group(1)
  end

  def test_a_list_too_long_for_a_page_goes_in_pages
    @session = Groups::Session.new(store: DotPopper::ScoreRecord::Memory.new, worker: @worker)
    build(width: 400, height: 500)
    join!
    groups = (1..20).map { group(id: it) }
    @session.refresh
    tick
    reply(200, groups)
    answer_all(groups, changes: [])
    tap_control(:back)
    first = @show.group_plan.rows.map { it.group.id }

    assert_operator first.size, :<, 20
    assert_includes names, :group_older
    tap_control(:group_older)
    refute_equal first, @show.group_plan.rows.map { it.group.id }
    assert_includes names, :group_newer
  end

  def test_the_history_is_read_for_the_group
    join!
    tap_control(:group_history)
    tick
    changes = [{ "id" => 2, "champion_number" => 2, "previous_champion_number" => 1, "score" => 18, "won_at" => "2026-11-05T01:00:00Z" }]
    until @worker.started.empty?
      path = @worker.started.first.first.path
      reply(200, path.end_with?("title_changes") ? changes : group)
      tick
    end

    assert_equal [2], @show.group_plan.rows.map { it.change.id }
  end

  def test_an_announcement_waits_for_game_over_or_the_title_and_stays_quiet_during_a_game
    join!
    tap_control(:back)
    tap_control(:back)
    panel.update(1.0, quiet: false, showing: false)

    assert_nil panel.banner
    tick
    groups_moved = group(top: 40, champion: 1)
    @session.refresh
    tick
    reply(200, [groups_moved])
    tick
    reply(200, [{ "id" => 9, "champion_number" => 1, "previous_champion_number" => 2, "score" => 40 }])
    tick

    assert_match(/took your title/, panel.banner.text)
    assert_equal 1, panel.banner.number
  end

  def test_game_over_holds_a_blank_for_the_line_and_then_says_it
    join!
    tap_control(:back)
    tap_control(:back)
    @session.game_finished(score: 30, sized_to_screen: true)

    assert_equal " ", panel.game_line
    tick
    reply(200, { "groups" => [{ "group" => group(top: 30, champion: 2), "won_title" => true }] })

    assert_equal "You took the title!", panel.game_line
  end

  def test_no_line_is_held_for_a_game_that_does_not_count
    join!
    @session.game_finished(score: 30, sized_to_screen: false)

    assert_nil panel.game_line
  end

  def test_words_for_each_game_result
    result = Groups::GameResult

    assert_equal "You took 3 titles!", Words.game_line(result.new(won: 3, raised: 0, short: nil, reigning: false))
    assert_equal "You raised the bar!", Words.game_line(result.new(won: 0, raised: 1, short: nil, reigning: false))
    assert_equal "The title stays yours.", Words.game_line(result.new(won: 0, raised: 0, short: nil, reigning: true))
    assert_equal "4 short of the title.", Words.game_line(result.new(won: 0, raised: 0, short: 4, reigning: false))
  end

  def test_the_group_button_opens_the_list_only_where_there_is_a_server
    refute_predicate Groups::Session.off, :available?
    assert_predicate @session, :available?
  end

  [[1200, 800], [400, 850], [850, 400]].each do |width, height|
    define_method(:"test_every_screen_fits_and_is_apart_at_#{width}x#{height}") do
      build(width:, height:)
      body = group(numbers: (1..8).to_a, you: 3, champion: 2, top: 90)
      join!(body)
      safe = @show.layout.safe
      standings = @show.group_plan
      standings.rows.each { assert_operator it.rect.bottom, :<=, safe.bottom + 1, "standings" }

      assert_equal 8, standings.rows.size
      [@show.controls.map(&:reach)].flatten.each { assert_operator it.bottom, :<=, safe.bottom + 1 }
      tap_control(:group_history)
      tick
      @show.controls.map(&:reach).each { assert_operator it.right, :<=, safe.right + 1 }
      tap_control(:back)
      tap_control(:back)
      tap_control(:group_join_open)
      @show.controls.map(&:reach).each { assert_operator it.bottom, :<=, safe.bottom + 1 }
    end
  end
end
