# frozen_string_literal: true

require_relative "inputs"

# What each screen does with each thing a player presses, as a table per
# screen: on that screen, this press has this outcome. Each row starts
# from a fresh Fixture, goes to the screen as a finger would, and presses
# once, the way Shell::App hands that press to the Show (Answers#press).
# The outcome is what can be seen to change (Answers#outcome): the
# screen, the list's scroll, the clipboard, a link opened, the sound, the
# dot size, the window, a hold, a theme, an achievement shown, the store.
#
# So taking any answer away from a screen (its Back, a gamepad button, its
# main button, a typed key, whether its list scrolls) changes a row here.
class ScreenAnswersTest < Minitest::Test
  include Inputs

  # A press, by its name in the tables, as Shell::App hands it on.
  PRESSES = {
    "A at nothing" => ->(p) { p.a_at_nothing },
    "B" => ->(p) { p.b },
    "X" => ->(p) { p.pad(:x) },
    "Y" => ->(p) { p.pad(:y) },
    "Y held" => ->(p) { p.pad(:y, held: 3.0) },
    "LB" => ->(p) { p.pad(:lb) },
    "RB" => ->(p) { p.pad(:rb) },
    "LT" => ->(p) { p.pad(:lt) },
    "View" => ->(p) { p.pad(:select) },
    "Start" => ->(p) { p.start },
    "Start held" => ->(p) { p.start(held: 3.0) },
    "Enter" => ->(p) { p.key(:enter) },
    "Space" => ->(p) { p.key(:space) },
    "Escape" => ->(p) { p.key(:escape) },
    "H" => ->(p) { p.key(:h) },
    "C" => ->(p) { p.key(:c) },
    "7" => ->(p) { p.key(:"7") },
    "Backspace" => ->(p) { p.key(:backspace) },
    "End" => ->(p) { p.key(:end) },
    "Ctrl+V" => ->(p) { p.paste },
    "Ctrl+B" => ->(p) { p.buy },
    "wheel" => ->(p) { p.wheel },
    "right stick" => ->(p) { p.right_stick },
    "left stick" => ->(p) { p.left_stick },
    "drag" => ->(p) { p.drag },
    "drag from a row" => ->(p) { p.drag_from_row },
    "tap on nothing" => ->(p) { p.tap_nothing },
    "tap on a bright dot" => ->(p) { p.tap_bright_dot },
    "tap on a dot in play" => ->(p) { p.tap_dot_in_play },
    "tap beside the card" => ->(p) { p.tap_beside_card }
  }.freeze

  # A player at a Fixture, pressing as Shell::App would hand each press on.
  class Answers
    P = DotPopper::Presentation
    attr_reader :fixture

    def initialize(fixture) = @fixture = fixture

    def show = fixture.show

    # A controller's A with its cursor on no button: a press there, let go
    # (App#gamepad_down, #gamepad_up), heard on Game Over's pile as a click.
    def a_at_nothing
      show.input = P::InputKind::GAMEPAD
      x, y = nothing || (return :no_place)
      click(x, y, :gamepad)
    end

    # B: the screen's Back, or on Home, where the system lets the game quit
    # itself, the ask to quit (App#leave_home).
    def b
      show.input = P::InputKind::GAMEPAD
      show.back || (fixture.platform.quits_itself? && show.ask_to_quit)
    end

    # A gamepad button, let go at once, or after +held+ seconds.
    def pad(name, held: 0.05)
      show.input = P::InputKind::GAMEPAD
      show.pad(name)
      fixture.tick(held)
      show.let_go(name)
    end

    def start(held: 0.05)
      show.input = P::InputKind::GAMEPAD
      show.start
      fixture.tick(held)
      show.let_go(:start)
    end

    # A key on a computer's keyboard, with the modifier keys +held+, as
    # Shell::App hands it on (Presentation::InputHandler).
    def key(name, *held)
      show.input = P::InputKind::MOUSE
      fixture.key(name, *held)
    end

    def paste = key(:v, :ctrl)
    def buy = key(:b, :ctrl)

    def wheel = show.wheel_scroll(-3)

    def right_stick = show.stick_scroll(P::Stick.new(x: 0.0, y: 1.0), 0.5)

    # The left stick moves the gamepad's cursor, except where the screen
    # scrolls with it (App#read_with_stick).
    def left_stick = (show.stick_scroll(P::Stick.new(x: 0.0, y: 1.0), 0.5) if show.stick_scrolls?)

    # A finger put down on nothing in the page's window and dragged up.
    def drag
      x, y = nothing(show.layout.page) || (return :no_place)
      drag_from(x, y)
    end

    # A finger put down on a list's row and dragged up before it lets go.
    def drag_from_row
      row = show.controls.find { show.list_row_at?(it.reach.center_x, it.reach.center_y) } or return :no_row
      drag_from(row.reach.center_x, row.reach.center_y)
    end

    # A tap on no button, by a finger.
    def tap_nothing
      show.input = P::InputKind::TOUCH
      x, y = nothing || (return :no_place)
      click(x, y, 7)
    end

    # A finger's tap on one of Home's bright dots, where no button is.
    def tap_bright_dot
      show.input = P::InputKind::TOUCH
      dots = show.attract.dots
      dot = dots.find { it.bright? && dots.top_at(it.x, it.y)&.id == it.id && show.control_at(it.x, it.y).nil? } or return :no_dot
      click(dot.x, dot.y, 7)
    end

    # A finger's tap on the bright dot on top of a game in play.
    def tap_dot_in_play
      show.input = P::InputKind::TOUCH
      dots = show.cabinet.game&.dots or return :no_game
      dot = dots.find { it.bright? && dots.top_at(it.x, it.y)&.id == it.id } or return :no_dot
      click(dot.x, dot.y, 7)
    end

    # A tap away from a dialog's card, by a finger.
    def tap_beside_card
      show.input = P::InputKind::TOUCH
      click(show.layout.safe.x + 2, show.layout.safe.y + 2, 7)
    end

    # What can be seen of the Show and what it was given, as a frame
    # draws it (so a list has fitted its scroll to its window).
    def look
      show.controls
      sounds = fixture.sounds
      { screen: Inputs.say(Inputs.screen(show)), scroll: show.scroll&.offset&.round(1), dialog: show.dialog, theme: show.in_use.key,
        clipboard: fixture.clipboard.paste, opened: fixture.opener.urls.dup, quits: fixture.window.respond_to?(:quits) && fixture.window.quits,
        game_quits: fixture.shell.quits,
        display: fixture.window.display, muted: sounds.muted?, dot_size: show.cabinet.sizing.to_text,
        holding: [show.clearing, show.group_panel.hold].find(&:held?)&.then { :held }, asked_to_quit: show.quit_prompt.positive?,
        store: fixture.storefront.status, status: show.offer_status, server: fixture.server_choice.address,
        undo: show.undo_offer && :offered, games: show.stats_book.stats.games, code: (show.group_panel.code unless show.group_panel.code.empty?),
        code_shown: show.group_panel.code_shown?, group: show.group_panel.group_id, score: show.cabinet.game&.score,
        sounds: sounds.played.size, last_sound: sounds.played.last&.then { |name, pitch| "#{name} #{pitch.round(2)}" } }
    end

    # The outcome of going from +before+ to +after+, in words: the screen
    # it went to, or the scroll on the same screen, what else changed, and
    # with nothing else, the sound it made; or "nothing".
    def self.outcome(before, after)
      same = %i[sounds last_sound]
      same += %i[scroll dialog undo score] if before[:screen] != after[:screen]
      changed = after.select { |facet, value| before[facet] != value && !same.include?(facet) }
      words = changed.map do |facet, value|
        case facet
        when :screen then value
        when :scroll then "scrolled"
        when :clipboard then "copied"
        when :code then "code #{value}"
        when :opened then "opened #{value.last}"
        when :holding then value ? "holding" : "let go"
        when :asked_to_quit then value ? "asks to quit" : nil
        else
          name = facet.to_s.tr("_", " ")
          if value == true then name
          elsif value.nil? || value == false then "no #{name}"
          else "#{name} #{value}"
          end
        end
      end.compact
      words << after[:last_sound] if after[:sounds] > before[:sounds] && words.empty?
      words.empty? ? "nothing" : words.join("; ")
    end

    # A place in +area+ (the safe area unless given) that no button
    # reaches, nearest its middle.
    def nothing(area = show.layout.safe)
      points = (1..19).to_a.product((1..19).to_a).map { |i, j| [area.x + (area.width * i / 20.0), area.y + (area.height * j / 20.0)] }
      points.select { |x, y| show.control_at(x, y).nil? }.min_by { |x, y| Math.hypot(x - area.center_x, y - area.center_y) }
    end

    private

    # A press at +x+, +y+ by +by+, let go: on Game Over's pile, where a
    # press waits for its release, Shell::Dragging hears one that drags
    # nothing as a click, which is the same tap.
    def click(x, y, by)
      show.tap(x, y, by:)
      fixture.tick(0.05)
      show.let_go(by)
    end

    def drag_from(x, y)
      show.input = P::InputKind::TOUCH
      show.tap(x, y, by: 7)
      6.times { |i| show.drag_scroll(7, y - (30.0 * (i + 1))) }
      show.let_go(7)
    end
  end

  # The way to each screen: a Fixture, and the controls a finger presses
  # from Home, in order.
  def self.at(fixture: {}, path: [])
    { fixture: { os: "Linux", width: 1200, height: 800 }.merge(fixture), path: }
  end

  SMALL = { os: "Linux", width: 400, height: 320 }.freeze

  WAYS = {
    home: at,
    new_theme: at(fixture: { arrival: true }),
    tutorial: at(path: [:how_to_play]),
    game: at(path: [:play]),
    game_over: at(path: %i[play play_game]),
    share_preview: at(path: %i[play play_game share]),
    offer: at(fixture: { games_left: 0 }, path: [:play]),
    offer_on_a_phone: at(fixture: { os: "Android", width: 400, height: 850, games_left: 0 }, path: [:play]),
    offer_over_game_over: at(fixture: { games_left: 1 }, path: %i[play play_game play_again]),
    stats: at(path: [:stats]),
    stats_with_undo: at(path: %i[stats clear]),
    achievements: at(fixture: SMALL, path: [:achievements]),
    achievement_dialog: at(fixture: SMALL.merge(pro: true), path: [:achievements, [:achievement, DotPopper::Achievement::IDS.first]]),
    themes: at(fixture: { pro: true }, path: [:themes]),
    themes_for_a_free_player: at(path: [:themes]),
    settings: at(fixture: SMALL, path: [:settings]),
    credits: at(path: %i[settings credits]),
    privacy: at(fixture: { member: true }, path: %i[settings privacy]),
    change_server: at(fixture: { gone: true, copied: "https://groups.example.org" }, path: %i[settings server]),
    friend_groups: at(fixture: SMALL.merge(pro: true, member: true), path: [:groups]),
    a_friend_group: at(fixture: { pro: true, member: true }, path: [:groups, [:group_show, 1]]),
    join_notice: at(fixture: { pro: true, member: true }, path: %i[groups group_join_open]),
    keypad: at(fixture: { pro: true, member: true }, path: [:groups, :group_join_open, :notice_go, [:code_digit, "2"]])
  }.freeze

  # Each table lists the presses that do something on its screen; every
  # other press in PRESSES must do nothing there.
  # Home, on a computer, for a player who has played: Escape asks to quit, as B does.
  HOME = {
    "A at nothing" => "Playing",
    "B" => "asks to quit",
    "X" => "Home, stats",
    "Y" => "Paused, tutorial",
    "Y held" => "Paused, tutorial",
    "LB" => "Home, achievements",
    "RB" => "Home, themes",
    "LT" => "Home, groups list",
    "View" => "Home, settings",
    "Start" => "Playing",
    "Start held" => "Playing",
    "Enter" => "Playing",
    "Space" => "Playing",
    "Escape" => "asks to quit",
    "H" => "Paused, tutorial",
    "tap on a bright dot" => "pop 1.0"
  }.freeze
  def test_on_home = check(WAYS.fetch(:home), HOME)

  # The card telling of a new theme, to a Free player: its switch opens the offer. Nothing of Home's under it takes a press (the card is a mode of its own).
  NEW_THEME = {
    "A at nothing" => "Home, offer",
    "B" => "Home",
    "Start" => "Home, offer",
    "Start held" => "Home, offer",
    "Enter" => "Home, offer",
    "Space" => "Home, offer",
    "Escape" => "Home"
  }.freeze
  def test_on_new_theme = check(WAYS.fetch(:new_theme), NEW_THEME)

  # The Tutorial over its paused game: B and Escape skip it, and the game plays on.
  TUTORIAL = {
    "B" => "Playing",
    "Escape" => "Playing"
  }.freeze
  def test_on_tutorial = check(WAYS.fetch(:tutorial), TUTORIAL)

  # A game in play: only a press at a place reaches it, and no key ends it.
  GAME = {
    "tap on a dot in play" => "score 1"
  }.freeze
  def test_on_game = check(WAYS.fetch(:game), GAME)

  # Game Over, once its grace is over, with no new achievement or friend group's line.
  GAME_OVER = {
    "A at nothing" => "Playing",
    "B" => "Home",
    "Y" => "GameOver, share_preview",
    "Y held" => "GameOver, share_preview",
    "Start" => "Playing",
    "Start held" => "Playing",
    "Enter" => "Playing",
    "Space" => "Playing",
    "Escape" => "Home"
  }.freeze
  def test_on_game_over = check(WAYS.fetch(:game_over), GAME_OVER)

  # The share preview over Game Over, on a computer: its main button and Y copy; a tap beside its card closes it.
  SHARE_PREVIEW = {
    "A at nothing" => "copied",
    "B" => "GameOver",
    "Y" => "copied",
    "Y held" => "copied",
    "Start" => "copied",
    "Start held" => "copied",
    "Enter" => "copied",
    "Space" => "copied",
    "Escape" => "GameOver",
    "tap on a bright dot" => "GameOver",
    "tap on a dot in play" => "GameOver",
    "tap beside the card" => "GameOver"
  }.freeze
  def test_on_share_preview = check(WAYS.fetch(:share_preview), SHARE_PREVIEW)

  # The offer of Pro over Home, from Play with no game left, in a computer's test build, which sells as a website copy does: Buy copies a license key, and X or Ctrl+V pastes it.
  OFFER = {
    "A at nothing" => "Home",
    "B" => "Home",
    "X" => "store empty; status Copy your license key first.",
    "Y" => "copied; store copied; status Your license key is copied. Paste it here.",
    "Y held" => "copied; store copied; status Your license key is copied. Paste it here.",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home",
    "H" => "status Key: H",
    "C" => "status Key: C",
    "7" => "status Key: 7",
    "Ctrl+V" => "store empty; status Copy your license key first.",
    "Ctrl+B" => "copied; store copied; status Your license key is copied. Paste it here."
  }.freeze
  def test_on_offer = check(WAYS.fetch(:offer), OFFER)

  # The same offer in a phone's store copy: X is Restore Purchases, and no key is typed.
  OFFER_ON_A_PHONE = {
    "A at nothing" => "Home",
    "B" => "Home",
    "X" => "store busy; status One moment…",
    "Y" => "store busy; status One moment…",
    "Y held" => "status Thank you. It's yours.",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home",
    "Ctrl+B" => "store busy; status One moment…"
  }.freeze
  def test_on_offer_on_a_phone = check(WAYS.fetch(:offer_on_a_phone), OFFER_ON_A_PHONE)

  # The offer over Game Over, from Play again with no game left: Y is Buy here too, as its "(Y)" says.
  OFFER_OVER_GAME_OVER = {
    "A at nothing" => "GameOver",
    "B" => "GameOver",
    "X" => "store empty; status Copy your license key first.",
    "Y" => "copied; store copied; status Your license key is copied. Paste it here.",
    "Y held" => "copied; store copied; status Your license key is copied. Paste it here.",
    "Start" => "GameOver",
    "Start held" => "GameOver",
    "Enter" => "GameOver",
    "Space" => "GameOver",
    "Escape" => "GameOver",
    "H" => "status Key: H",
    "C" => "status Key: C",
    "7" => "status Key: 7",
    "Ctrl+V" => "store empty; status Copy your license key first.",
    "Ctrl+B" => "copied; store copied; status Your license key is copied. Paste it here."
  }.freeze
  def test_on_offer_over_game_over = check(WAYS.fetch(:offer_over_game_over), OFFER_OVER_GAME_OVER)

  # Stats: Y held clears them.
  STATS = {
    "A at nothing" => "Home",
    "B" => "Home",
    "Y" => "tick 0.7",
    "Y held" => "undo offered; games 0",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home"
  }.freeze
  def test_on_stats = check(WAYS.fetch(:stats), STATS)

  # Stats just cleared, with Undo offered: Y is Undo.
  STATS_WITH_UNDO = {
    "A at nothing" => "Home",
    "B" => "Home",
    "Y" => "no undo; games 1",
    "Y held" => "no undo; games 1",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home"
  }.freeze
  def test_on_stats_with_undo = check(WAYS.fetch(:stats_with_undo), STATS_WITH_UNDO)

  # Achievements, in the smallest window, where the grid scrolls; a drag that starts on a cell scrolls it.
  ACHIEVEMENTS = {
    "A at nothing" => "Home",
    "B" => "Home",
    "X" => "Home, achievements, dialog",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home",
    "End" => "scrolled",
    "wheel" => "scrolled",
    "right stick" => "scrolled",
    "drag" => "scrolled",
    "drag from a row" => "scrolled"
  }.freeze
  def test_on_achievements = check(WAYS.fetch(:achievements), ACHIEVEMENTS)

  # An achievement's dialog, for Pro: LB and RB step through them, and nothing under it scrolls.
  ACHIEVEMENT_DIALOG = {
    "A at nothing" => "Home, achievements",
    "B" => "Home, achievements",
    "LB" => "dialog long_haul",
    "RB" => "dialog sharp_trio",
    "Start" => "Home, achievements",
    "Start held" => "Home, achievements",
    "Enter" => "Home, achievements",
    "Space" => "Home, achievements",
    "Escape" => "Home, achievements",
    "tap beside the card" => "Home, achievements"
  }.freeze
  def test_on_achievement_dialog = check(WAYS.fetch(:achievement_dialog), ACHIEVEMENT_DIALOG)

  # Themes, for Pro: LB and RB use the previous and next theme.
  THEMES = {
    "A at nothing" => "Home",
    "B" => "Home",
    "LB" => "theme jack_o_lantern",
    "RB" => "theme ghost",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home"
  }.freeze
  def test_on_themes = check(WAYS.fetch(:themes), THEMES)

  # Themes, for a Free player: using another theme opens the offer.
  THEMES_FOR_A_FREE_PLAYER = {
    "A at nothing" => "Home",
    "B" => "Home",
    "LB" => "Home, themes, offer",
    "RB" => "Home, themes, offer",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home"
  }.freeze
  def test_on_themes_for_a_free_player = check(WAYS.fetch(:themes_for_a_free_player), THEMES_FOR_A_FREE_PLAYER)

  # Settings, in the smallest window, where its list scrolls.
  SETTINGS = {
    "A at nothing" => "Home",
    "B" => "Home",
    "X" => "Home, credits",
    "Y" => "Home, privacy",
    "Y held" => "Home, privacy",
    "LB" => "dot size standard",
    "RB" => "display borderless",
    "View" => "muted",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home",
    "C" => "Home, credits",
    "End" => "scrolled",
    "wheel" => "scrolled",
    "right stick" => "scrolled",
    "drag" => "scrolled"
  }.freeze
  def test_on_settings = check(WAYS.fetch(:settings), SETTINGS)

  # Credits and licenses, over Settings: the left stick reads it too.
  CREDITS = {
    "A at nothing" => "Home, settings",
    "B" => "Home, settings",
    "Start" => "Home, settings",
    "Start held" => "Home, settings",
    "Enter" => "Home, settings",
    "Space" => "Home, settings",
    "Escape" => "Home, settings",
    "End" => "scrolled",
    "wheel" => "scrolled",
    "right stick" => "scrolled",
    "left stick" => "scrolled",
    "drag" => "scrolled"
  }.freeze
  def test_on_credits = check(WAYS.fetch(:credits), CREDITS)

  # Privacy, over Settings, for a player the group server knows: Y held deletes their friend group data.
  PRIVACY = {
    "A at nothing" => "Home, settings",
    "B" => "Home, settings",
    "X" => "opened https://dot-popper.setdef.com/privacy",
    "Y" => "tick 0.7",
    "Y held" => "bonk 0.7",
    "Start" => "Home, settings",
    "Start held" => "Home, settings",
    "Enter" => "Home, settings",
    "Space" => "Home, settings",
    "Escape" => "Home, settings"
  }.freeze
  def test_on_privacy = check(WAYS.fetch(:privacy), PRIVACY)

  # Change Server, while setdef is gone, with a server's address copied.
  CHANGE_SERVER = {
    "A at nothing" => "Home, settings",
    "B" => "Home, settings",
    "Start" => "Home, settings",
    "Start held" => "Home, settings",
    "Enter" => "Home, settings",
    "Space" => "Home, settings",
    "Escape" => "Home, settings",
    "Ctrl+V" => "server https://groups.example.org"
  }.freeze
  def test_on_change_server = check(WAYS.fetch(:change_server), CHANGE_SERVER)

  # The friend groups' list, for a member of two.
  FRIEND_GROUPS = {
    "A at nothing" => "Home",
    "B" => "Home",
    "X" => "Home, groups list, join notice",
    "Y" => "Home, groups list, create notice",
    "Y held" => "Home, groups list, create notice",
    "RB" => "Home, groups group; group 2",
    "Start" => "Home",
    "Start held" => "Home",
    "Enter" => "Home",
    "Space" => "Home",
    "Escape" => "Home"
  }.freeze
  def test_on_friend_groups = check(WAYS.fetch(:friend_groups), FRIEND_GROUPS)

  # A friend group: Start held leaves it.
  A_FRIEND_GROUP = {
    "A at nothing" => "Home, groups list",
    "B" => "Home, groups list",
    "X" => "code shown",
    "Y" => "Home, groups history",
    "Y held" => "Home, groups history",
    "LB" => "group 2",
    "RB" => "group 2",
    "Start" => "tick 0.7",
    "Start held" => "Home, groups list",
    "Enter" => "Home, groups list",
    "Space" => "Home, groups list",
    "Escape" => "Home, groups list"
  }.freeze
  def test_on_a_friend_group = check(WAYS.fetch(:a_friend_group), A_FRIEND_GROUP)

  # The notice a first Join shows over the list.
  JOIN_NOTICE = {
    "A at nothing" => "Home, groups join",
    "B" => "Home, groups list",
    "X" => "opened https://dot-popper.setdef.com/privacy",
    "Start" => "Home, groups join",
    "Start held" => "Home, groups join",
    "Enter" => "Home, groups join",
    "Space" => "Home, groups join",
    "Escape" => "Home, groups list"
  }.freeze
  def test_on_join_notice = check(WAYS.fetch(:join_notice), JOIN_NOTICE)

  # The keypad that joins a group, with a digit typed.
  KEYPAD = {
    "A at nothing" => "tick 0.8",
    "B" => "Home, groups list",
    "X" => "code ",
    "Start" => "tick 0.8",
    "Start held" => "tick 0.8",
    "Enter" => "tick 0.8",
    "Space" => "tick 0.8",
    "Escape" => "Home, groups list",
    "7" => "code 27",
    "Backspace" => "code "
  }.freeze
  def test_on_keypad = check(WAYS.fetch(:keypad), KEYPAD)

  # What the renderer and Shell::App ask of the screen on top, which no
  # press shows here: whether it veils the screens under it, whether a
  # title change's announcement shows over it, and whether a press away
  # from its buttons waits to be let go, as on Game Over's pile.
  DRAWN = {
    home: "announces",
    new_theme: "announces",
    tutorial: "",
    game: "",
    game_over: "announces, waits",
    share_preview: "announces",
    offer: "veils",
    offer_on_a_phone: "veils",
    offer_over_game_over: "veils",
    stats: "veils",
    stats_with_undo: "veils",
    achievements: "veils",
    achievement_dialog: "",
    themes: "veils",
    themes_for_a_free_player: "veils",
    settings: "veils",
    credits: "veils",
    privacy: "veils",
    change_server: "veils",
    friend_groups: "veils",
    a_friend_group: "veils",
    join_notice: "veils",
    keypad: "veils"
  }.freeze

  def test_what_each_screen_shows_of_what_is_under_it
    misses = WAYS.filter_map do |name, way|
      actual = drawn(arrive(way))
      "#{name}: expected #{DRAWN.fetch(name).inspect}, got #{actual.inspect}" unless actual == DRAWN.fetch(name)
    end
    assert_empty misses
  end

  def test_every_way_has_its_table
    assert_equal WAYS.keys.sort, DRAWN.keys.sort
    WAYS.each_key { assert ScreenAnswersTest.const_defined?(it.upcase), it }
  end

  # A screen added later fails here until a way reaches it and a table
  # says what each press does on it.
  def test_every_screen_object_has_a_table
    screens = P::Screens.constants.map { P::Screens.const_get(it) }.select { it.is_a?(Class) && it < P::Screens::Screen } - [P::Screens::Page]
    tabled = WAYS.values.map { arrive(it).show.screen.class }.uniq
    assert_empty screens - tabled
  end

  private

  # Runs every press on the screen +way+ leads to, each from a fresh
  # Fixture, and says which came out otherwise than +table+ says, with
  # every press it leaves out doing nothing.
  def check(way, table)
    unknown = table.keys - PRESSES.keys
    assert_empty unknown, "presses with no way to press them"
    misses = PRESSES.each_key.filter_map do |press|
      expected = table.fetch(press, "nothing")
      player = arrive(way)
      before = player.look
      PRESSES.fetch(press).call(player)
      player.fixture.tick(0.1)
      actual = Answers.outcome(before, player.look)
      "#{press}: expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected
    end
    assert_empty misses
  end

  # A Fixture at the end of +way+, and a player there.
  def arrive(way)
    fixture = Fixture.new(**way[:fixture])
    finger = Finger.new(fixture)
    way[:path].each { |step| assert_equal :pressed, step == :play_game ? finger.play : finger.press(step), "on the way: #{step}" }
    fixture.tick(0.6)
    Answers.new(fixture)
  end

  def drawn(player)
    show = player.show
    point = player.nothing
    [("veils" if show.screen.covers?), ("announces" if show.screen.announces?),
     ("waits" if point && show.waits_for_release?(*point))].compact.join(", ")
  end
end
