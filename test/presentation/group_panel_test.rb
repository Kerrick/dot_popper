# frozen_string_literal: true

require_relative "presentation_helper"

class GroupPanelTest < Minitest::Test
  include PresentationTest

  Groups = DotPopper::Groups
  Reply = DotPopper::Network::Reply
  Screen = DotPopper::Presentation::GroupScreen
  Words = DotPopper::Presentation::GroupWords

  class ManualWorker
    attr_reader :started

    def initialize = (@started = []) && (@answers = [])
    def start(job, token) = @started << [job, token]
    def finished = @answers.shift(@answers.size)
    def answer(reply) = @answers << [@started.shift.first, reply]
  end

  # The old name, until no commit uses it.
  HandWorker = ManualWorker

  def group(id: 1, numbers: [1, 2], you: 2, champion: 1, top: 18)
    { "id" => id, "join_code" => "2345678", "you" => you, "champion_number" => champion, "top_score" => top,
      "reign_started_at" => "2026-11-01", "members" => numbers.map { { "number" => it, "top_score" => it } } }
  end

  def setup
    @sounds = FakeSounds.new
    @worker = ManualWorker.new
    @session = Groups::Session.new(store: DotPopper::ScoreRecord::Memory.new, worker: @worker)
    @pro = DotPopper::Entitlement.new(forced: true)
    @cabinet = DotPopper::Cabinet.new(field)
    build
  end

  def build(width: 800, height: 600, entitlement: @pro, group_notice: DotPopper::Presentation::GroupNotice.read, links: DotPopper::Presentation::NoLinks.new)
    @show = new_show(cabinet: @cabinet, layout: layout(width, height), sounds: @sounds, radius: R,
                     entitlement:, groups: @session, group_notice:, links:)
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
      reply(200, path.end_with?("history") ? changes : body)
      tick
    end
  end

  def test_the_list_offers_join_and_create
    panel.open

    assert_includes names, :group_join_open
    assert_includes names, :group_create
    assert_includes lines, Words.blurb
  end

  # Every game counts in a group whatever its dot size, so a group's page
  # says nothing about the size.
  def test_a_group_says_the_same_whatever_the_dot_size
    @cabinet.sizing = DotPopper::DotSizing::DEFAULT
    join!
    with_default = lines

    @cabinet.sizing = DotPopper::DotSizing::DEFAULT.toggled

    assert_equal with_default, lines
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

  # A license key that holds Pro until it is gone, as when it moves to
  # another device (Continuity::License).
  License = Struct.new(:pro?)

  # Pro gone while the code pad is open: Join sends nothing, and the
  # offer of Pro opens instead.
  def test_joining_after_pro_is_gone_leads_to_the_offer_and_sends_nothing
    license = License.new(true)
    build(entitlement: DotPopper::Entitlement.new(license:))
    open_join
    tap_code("2345678")
    license[:pro?] = false
    tap_control(:code_submit)

    assert_predicate @show, :offer?
    assert_equal :groups, @show.offer_focus
    assert_empty @worker.started
  end

  # Pro gone while the friend groups' notice is open: Create sends
  # nothing, and the offer of Pro opens instead.
  def test_creating_after_pro_is_gone_leads_to_the_offer_and_sends_nothing
    license = License.new(true)
    with_notice
    build(entitlement: DotPopper::Entitlement.new(license:), group_notice: DotPopper::Presentation::GroupNotice.new(@notice_store))
    panel.open
    tap_control(:group_create)
    assert_equal :create, panel.asking
    license[:pro?] = false
    @show.primary

    assert_predicate @show, :offer?
    assert_empty @worker.started
  end

  class Links
    attr_reader :opened

    def initialize = @opened = []
    def open(url) = @opened << url
  end

  def with_notice(saved = nil)
    @notice_store = DotPopper::ScoreRecord::Memory.new(saved)
    @links = Links.new
    build(group_notice: DotPopper::Presentation::GroupNotice.new(@notice_store), links: @links)
  end

  # A first Join or Create says who keeps the scores, once, before any
  # score is sent; Not now asks again next time.
  def test_a_first_join_asks_first_and_not_now_asks_again
    with_notice
    panel.open
    tap_control(:group_join_open)

    assert_equal :join, panel.asking
    assert_equal %i[policy notice_later notice_go], names
    assert_equal :list, panel.page
    tap_control(:notice_later)

    assert_nil panel.asking
    assert_equal :list, panel.page
    tap_control(:group_join_open)

    assert_equal :join, panel.asking
  end

  def test_going_on_does_what_was_pressed_and_never_asks_again
    with_notice
    panel.open
    tap_control(:group_create)
    assert_empty @worker.started, "nothing is sent before the notice is answered"
    tap_control(:notice_go)
    tick

    refute_empty @worker.started
    assert_equal "read", @notice_store.read
    panel.close
    panel.open
    tap_control(:group_join_open)

    assert_nil panel.asking
    assert_equal :join, panel.page
  end

  def test_the_notice_links_to_the_privacy_policy_and_names_its_buttons
    with_notice
    panel.open
    tap_control(:group_join_open)
    tap_control(:policy)

    assert_equal ["https://dot-popper.setdef.com/privacy"], @links.opened
    assert_equal "Join", Words.notice_go(:join).for(DotPopper::Presentation::InputKind::TOUCH)
    @show.input = DotPopper::Presentation::InputKind::GAMEPAD
    @show.pad(:x)

    assert_equal 2, @links.opened.size
    @show.back

    assert_nil panel.asking, "B is Not now"
    assert_predicate panel, :open?
  end

  def test_a_free_player_sees_the_offer_not_the_notice
    with_notice
    build(entitlement: DotPopper::Entitlement.free, group_notice: DotPopper::Presentation::GroupNotice.new(@notice_store))
    panel.open
    tap_control(:group_join_open)

    assert_predicate @show, :offer?
    assert_nil panel.asking
  end

  # The gesture doc/privacy.json describes: Delete my friend group data,
  # on the Privacy screen, held, asks the server to delete this player.
  def test_holding_delete_my_data_deletes_the_player_from_the_server
    join!
    open_privacy
    tap_control(:privacy_delete)
    tick(DotPopper::Presentation::GroupPanel::HOLD + 0.1)
    tick

    assert_equal :deleted, @worker.started.last.first.kind
  end

  def open_privacy
    panel.close
    @show.open_settings
    @show.open_privacy
  end

  def test_leaving_and_deleting_never_need_it
    join!
    tap_control(:group_leave)

    assert_predicate panel.hold, :held?
    @pro = DotPopper::Entitlement.free
    build(entitlement: @pro)
    tick
    open_privacy

    assert_includes names, :privacy_delete
  end

  def test_a_short_code_is_not_sent
    open_join
    tap_code("23")
    tap_control(:code_submit)

    assert_nil panel.note, "Join looks disabled until then, and says nothing"
    refute panel.code_complete?
    assert_empty @worker.started
  end

  # On a keyboard the keypad takes typed digits (Shell::LotaInput names
  # the keypad's as the main keys'), Backspace takes the last away, and
  # Enter joins.
  def test_typed_digits_fill_the_code_and_enter_joins
    open_join
    "2345".each_char { assert @show.type_key(it.to_sym) }
    %i[6 7 8].each { @show.type_key(it) }
    assert_equal "2345678", panel.code, "the eighth digit has no place"
    assert panel.code_complete?
    assert @show.type_key(:backspace)
    assert_equal "234567", panel.code
    refute @show.type_key(:m), "a letter is not the keypad's"
    @show.type_key(:"8")
    @show.primary
    tick
    refute_empty @worker.started
  end

  def test_a_code_reads_as_it_is_shared
    assert_equal "482-1073", DotPopper::Presentation::CodeText.hyphenated("4821073")
    assert_equal ["4", "8", nil], DotPopper::Presentation::CodeText.places("48", 3)
    assert_equal "Delete", Words.erase
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

  def test_the_standings_are_highest_first_with_the_champion_and_you_clear
    join!(group(numbers: [1, 2, 3], you: 3, champion: 2, top: 90))
    rows = @show.group_plan.rows

    assert_equal [2, 3, 1], rows.map(&:number)
    assert_equal [true, false, false], rows.map(&:champion)
    assert_equal [false, true, false], rows.map(&:me)
    assert_includes lines, Words.title_line(panel.group)
  end

  # The code is hidden until Show; Show then becomes Copy, which copies it
  # as it is shared, and leaving the group's screen hides it again.
  def test_the_code_shows_then_copies_and_hides_again_on_leaving
    join!
    action = -> { @show.group_plan.actions.find { it.name == :group_code } }
    assert_equal Words.show, action.call.text
    refute panel.code_shown?
    tap_control(:group_code)
    assert panel.code_shown?
    assert_equal Words.copy, action.call.text
    tap_control(:group_code)
    assert_equal "234-5678", @show.instance_variable_get(:@clipboard).text
    tap_control(:group_history)
    tap_control(:back)
    assert panel.code_shown?, "History is the group's own"
    tap_control(:back)
    tap_control([:group_show, 1])
    refute panel.code_shown?
  end

  # History says when, in the player's own time.
  def test_history_says_when_in_local_time_and_names_the_members
    assert_equal "November 5, 1:00 AM", Words.when("2026-11-05T01:00:00Z", offset: "+00:00")
    assert_equal "November 4, 7:00 PM", Words.when("2026-11-05T01:00:00Z", offset: "-06:00")
    change = Groups::TitleChange.new(id: 1, champion_number: 2, previous_champion_number: 1, score: 31, at: "2026-11-05T01:00:00Z")
    names = Words.entry(7, change).map(&:first).join
    assert_equal "#{DotPopper::Presentation::Names.member(7, 2)} took the title from #{DotPopper::Presentation::Names.member(7, 1)} with 31.", names
    passed = Groups::TitleChange.new(id: 3, champion_number: 2, previous_champion_number: 1, score: 31, at: "2026-11-05T01:00:00Z", passed_on: true)
    assert_equal "The title passed to #{DotPopper::Presentation::Names.member(7, 2)} with 31.", Words.entry(7, passed).map(&:first).join
    won = passed.with(passed_on: false)
    assert_equal names, Words.entry(7, won).map(&:first).join
    earned = Groups::MemberAchievement.new(id: 2, member_number: 2, key: :blink, at: "2026-11-05T01:00:00Z")
    assert_equal "#{DotPopper::Presentation::Names.member(7, 2)} earned Blink.", Words.entry(7, earned).map(&:first).join
  end

  def test_a_pass_is_worded_apart_from_a_win
    announce = ->(kind) { Words.announcement(Groups::Announcement.new(group_id: 7, champion_number: 2, score: 31, kind: kind)) }
    assert_equal "The title is yours.", announce.(:passed_to_you)
    assert_equal "The title passed to a friend.", announce.(:passed)
    assert_equal "A friend took the title with 31.", announce.(:changed)
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

  def test_a_list_too_long_for_its_window_scrolls
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
    @show.scroll_key(:end)
    last = @show.group_plan.rows.map { it.group.id }
    refute_equal first, last
    assert_includes last, groups.map { it["id"] }.max_by { DotPopper::Presentation::Names.group(it) }, "the end shows the last"
  end

  def gamepad! = @show.input = DotPopper::Presentation::InputKind::GAMEPAD
  def texts = @show.group_plan.actions.filter_map(&:text)

  # On a controller every friend groups' screen names its buttons, and
  # each button does what its label says, without the cursor.
  def test_a_controller_labels_the_list_and_presses_each_button
    join!
    tap_control(:back)
    gamepad!

    assert_equal ["Join (X)", "Create (Y)", "Open group (RB)", "Back (B)"], texts
    @show.pad(:rb)

    assert_equal [:group, 1], [panel.page, panel.group_id]
    @show.back
    @show.pad(:x)

    assert_equal :join, panel.page
    @show.back
    @show.pad(:y)
    tick

    assert_equal :create, @worker.started.last.first.kind
  end

  def test_a_controller_labels_a_group_and_steps_through_the_groups
    @session = Groups::Session.new(store: DotPopper::ScoreRecord::Memory.new, worker: @worker)
    build
    join!
    groups = [group(id: 1), group(id: 2)]
    @session.refresh
    tick
    reply(200, groups)
    answer_all(groups, changes: [])
    gamepad!

    assert_equal ["Show (X)", "History (Y)", "Hold Start to leave", "LB", "RB", "Back (B)"], texts
    @show.pad(:x)

    assert panel.code_shown?
    assert_includes texts, "Copy (X)"
    order = panel.listed.map(&:id)
    @show.pad(:rb)

    assert_equal order[(order.index(1) + 1) % 2], panel.group_id
    @show.pad(:lb)

    assert_equal 1, panel.group_id
    @show.pad(:y)

    assert_equal :history, panel.page
    assert_equal ["Back (B)"], texts
  end

  def test_holding_start_leaves_a_group_and_letting_go_too_soon_does_not
    join!
    gamepad!
    @show.start
    @show.update(0.5)
    @show.let_go(:start)
    @show.update(3.0)

    assert_equal :group, panel.page, "let go too soon"
    @show.start
    @show.update(3.0)

    assert_equal :list, panel.page
  end

  def test_a_controller_labels_the_keypad_deletes_with_x_and_joins_with_start
    open_join
    gamepad!
    keys = @show.group_plan.actions.to_h { [it.name, it.text] }

    assert_equal "Delete (X)", keys[:code_erase]
    assert_equal "Join (Start)", keys[:code_submit]
    tap_code("23456789")
    @show.pad(:x)

    assert_equal "234567", panel.code
    tap_code("8")
    @show.start
    tick

    refute_empty @worker.started
  end

  SIZES = [[400, 850], [1200, 800], [850, 400], [320, 568], [568, 320], [1024, 768], [2560, 1440]].freeze

  def assert_apart(where)
    rects = @show.group_plan.actions.reject { it.name.is_a?(Array) && it.name.first == :group_show }.map { [it.name, it.rect] }
    safe = @show.layout.safe
    rects.combination(2).each { |(a, r), (b, q)| refute r.overlaps?(q), "#{where}: #{a} overlaps #{b}" }
    rects.each { |name, r| assert r.x >= safe.x && r.right <= safe.right && r.y >= safe.y && r.bottom <= safe.bottom, "#{where}: #{name} leaves the safe area" }
  end

  # With a controller's labels, and with the notice open, nothing on a
  # friend groups' screen overlaps or leaves the safe area, at any size.
  def test_labeled_screens_and_the_notice_fit_every_size
    SIZES.each do |width, height|
      @session = Groups::Session.new(store: DotPopper::ScoreRecord::Memory.new, worker: @worker)
      build(width:, height:)
      join!
      groups = [group(id: 1), group(id: 2)]
      @session.refresh
      tick
      reply(200, groups)
      answer_all(groups, changes: [])
      gamepad!
      assert_apart("#{width}x#{height} group")
      @show.back
      assert_apart("#{width}x#{height} list")
      @show.pad(:x)
      assert_apart("#{width}x#{height} keypad")
      @show.back
      build(width:, height:, group_notice: DotPopper::Presentation::GroupNotice.new(DotPopper::ScoreRecord::Memory.new))
      gamepad!
      panel.open
      @show.pad(:y)
      plan = @show.group_notice_plan
      parts = plan.controls
      parts.combination(2).each { |(a, r), (b, q)| refute r.overlaps?(q), "#{width}x#{height} notice: #{a} overlaps #{b}" }
      parts.each { |name, r| assert plan.card.contains?(r.x, r.y) && plan.card.contains?(r.right, r.bottom), "#{width}x#{height} notice: #{name} leaves its card" }
      assert @show.layout.safe.contains?(plan.card.x, plan.card.y) && @show.layout.safe.contains?(plan.card.right, plan.card.bottom), "#{width}x#{height}: the notice leaves the safe area"
    end
  end

  def test_the_history_is_read_for_the_group
    join!
    tap_control(:group_history)
    tick
    changes = [{ "id" => 2, "champion_number" => 2, "previous_champion_number" => 1, "score" => 18, "at" => "2026-11-05T01:00:00Z" }]
    until @worker.started.empty?
      path = @worker.started.first.first.path
      reply(200, path.end_with?("history") ? changes : group)
      tick
    end

    assert_equal [2], @show.group_plan.rows.map { it.change.id }
  end

  def test_an_announcement_waits_for_game_over_or_home_and_stays_quiet_during_a_game
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

  # An announcement shows only where the renderer draws one, over Home
  # and Game Over: on a screen over Home it waits, rather than passing
  # unseen.
  def test_an_announcement_waits_on_a_screen_over_home
    join!
    tap_control(:back)
    tap_control(:back)
    tick
    @show.open_themes
    @session.refresh
    tick
    reply(200, [group(top: 40, champion: 1)])
    tick
    reply(200, [{ "id" => 9, "champion_number" => 1, "previous_champion_number" => 2, "score" => 40 }])
    tick(5.0)

    assert_nil panel.banner, "not over Themes"
    @show.back
    tick

    assert_match(/took your title/, panel.banner&.text.to_s)
  end

  def test_game_over_holds_a_blank_for_the_line_and_then_says_it
    join!
    tap_control(:back)
    tap_control(:back)
    @session.game_finished(score: 30, counts: true)

    assert_equal " ", panel.game_line
    tick
    reply(200, { "groups" => [{ "group" => group(top: 30, champion: 2), "won_title" => true }] })

    id = panel.groups.groups.first.id
    assert_equal "You took the #{DotPopper::Presentation::Names.group(id)} title!", panel.game_line
    assert_equal id, panel.game_title_taken, "Game Over's line opens that group"
  end

  def test_no_line_is_held_for_a_game_that_does_not_count
    join!
    @session.game_finished(score: 30, counts: false)

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

  # On a phone either way up, a computer's window, and the smallest
  # window, every friend groups' screen keeps its buttons apart and inside
  # the safe area, and a press on each one's middle reaches it.
  [[400, 850], [850, 400], [1200, 800], [400, 320], [640, 400]].each do |width, height|
    define_method(:"test_every_screens_buttons_are_apart_and_inside_at_#{width}x#{height}") do
      build(width:, height:)
      join!(group(numbers: (1..8).to_a, you: 3, champion: 2, top: 90))
      check = lambda do |where|
        safe = @show.layout.safe
        controls = @show.controls
        controls.combination(2) { |one, other| refute one.frame.overlaps?(other.frame), "#{where}: #{one.name} and #{other.name}" }
        controls.each do |control|
          frame = control.frame
          assert_operator frame.y, :>=, safe.y - 1e-6, "#{where}: #{control.name}"
          assert_operator frame.bottom, :<=, safe.bottom + 1e-6, "#{where}: #{control.name}"
          assert_equal control.name, @show.control_at(frame.center_x, frame.center_y)&.name, "#{where}: #{control.name}"
        end
      end
      check.call("the group")
      tap_control(:group_history)
      tick
      check.call("its history")
      tap_control(:back)
      tap_control(:back)
      check.call("the list")
      tap_control(:group_join_open)
      check.call("the keypad")
    end
  end

  [[1200, 800]].each do |width, height|
    define_method(:"test_every_screen_fits_and_is_apart_at_#{width}x#{height}") do
      build(width:, height:)
      body = group(numbers: (1..8).to_a, you: 3, champion: 2, top: 90)
      join!(body)
      safe = @show.layout.safe
      standings = @show.group_plan
      standings.rows.each { assert_operator it.rect.y, :<, standings.window.bottom, "standings" }
      @show.scroll_key(:end)
      assert_includes @show.group_plan.rows.map(&:number), 1, "the last of the eight scrolls into view"
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
