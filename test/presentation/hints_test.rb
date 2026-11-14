# frozen_string_literal: true

require_relative "inputs"

# A button's label names the controller button or key that presses it
# ("Share my score (Y)", "Hold Y to clear my stats…", "Buy for $1.99
# (Ctrl+B)"), and that input must do what the label says, on the screen
# that shows it. Every word that names an input is listed here with the
# screen it is shown on and what its input does there, so a hint can
# name no input that does nothing, and a new hint fails here until it is
# listed.
class HintsTest < Minitest::Test
  include Inputs

  P = DotPopper::Presentation

  # What only the engine can do, remembered.
  class FakeShell
    attr_reader :quits

    def initialize = @quits = 0
    def splash? = false
    def quit = @quits += 1
    def toggle_fullscreen = nil
    def press(*) = nil
    def move(*) = nil
    def release(*) = nil
    def drop = nil
  end

  # Each word that names an input, by where it is in Style::WORDS (or
  # GroupWords' method), the screen it is shown on, the button it names,
  # and what that button does there. A is a press at the cursor: aimed
  # at no button, it presses the screen's main button, so only the main
  # button's label names A, and a button A presses only when aimed at it
  # (Get Pro in an achievement's dialog) names no button.
  HINTS = {
    [:play] => [:home, :a, ->(t) { t.show.playing? }],
    # On Game Over A away from the buttons waits on the pile, so it is
    # aimed at Play again.
    [:play_again] => [:game_over, :a, ->(t) { t.show.playing? }, :play_again],
    [:share] => [:game_over, :y, ->(t) { t.show.sharing? }],
    [:copy] => [:share, :a, ->(t) { t.fixture.clipboard.text }],
    [:close] => [:share, :b, ->(t) { !t.show.sharing? }],
    [:how_to_play] => [:home, :y, ->(t) { t.show.tutorial? }],
    [:go_back] => [:stats, :b, ->(t) { t.show.on_home? }],
    [:quit] => [:home, :b, ->(t) { t.show.quit_prompt.positive? }],
    [:clear] => [:stats, :y, ->(t) { t.show.clearing.held? }],
    [:hold_to_clear] => [:stats, :y, ->(t) { t.show.clearing.held? }],
    [:undo] => [:cleared, :y, ->(t) { t.show.played? }],
    %i[buttons settings] => [:home, :select, ->(t) { t.show.settings? }],
    %i[buttons skip] => [:tutorial, :b, ->(t) { !t.show.tutorial? }],
    %i[buttons home] => [:game_over, :b, ->(t) { t.show.on_home? }],
    %i[buttons sound] => [:settings, :select, ->(t) { t.show.sounds.muted? }],
    # Dot size is offered only where the two sizes look different, as on
    # an upright phone.
    %i[buttons dot_size] => [:phone_settings, :lb, ->(t) { t.show.cabinet.sizing != t.sizing }],
    %i[buttons display] => [:settings, :rb, ->(t) { t.fixture.window.display != :window }],
    %i[buttons credits_licenses] => [:settings, :x, ->(t) { t.show.credits? }],
    %i[buttons privacy] => [:settings, :y, ->(t) { t.show.privacy? }],
    %i[buttons privacy_policy] => [:privacy, :x, ->(t) { t.fixture.opener.urls.any? }],
    %i[buttons privacy_hold] => [:privacy, :y, ->(t) { t.show.group_panel.hold&.held? }],
    %i[buttons achievement_close] => [:dialog, :b, ->(t) { t.show.dialog.nil? }],
    %i[buttons how_to_earn] => [:achievements, :x, ->(t) { t.show.dialog }],
    %i[groups notice_policy] => [:notice, :x, ->(t) { t.fixture.opener.urls.any? }],
    %i[groups notice_later] => [:notice, :b, ->(t) { t.show.group_panel.asking.nil? }],
    %i[groups notice_go] => [:notice, :a, ->(t) { t.show.group_panel.page == :join }]
  }.freeze

  def test_every_word_that_names_an_input_is_listed
    named = words_naming_an_input

    assert_empty named - HINTS.keys, "a hint with no proof that its input works"
    assert_empty HINTS.keys - named, "a listed hint no word has"
  end

  def test_each_hint_names_the_button_that_does_what_its_label_says
    HINTS.each do |path, (at, button, done, aimed)|
      assert_includes gamepad_text(path), label(button), path.inspect
      given(at)
      press(button, aimed)

      assert done.call(self), "#{path.inspect}: #{label(button)} on #{at}"
    end
  end

  # Buy names its key and its button from the offer's own tables: the key
  # that buys there (Ctrl or Cmd with B) and the button that buys (Y).
  def test_buy_names_the_key_and_the_button_that_buy
    { "Linux" => "Ctrl+B", "OS X" => "⌘B" }.each do |os, hint|
      given(:offer, os:)
      handler.call(P::KeyPress.new(key: :tab))

      assert_includes show.buy_label, "(#{hint})"
      handler.call(P::KeyPress.new(key: :b, held: [os == "OS X" ? :command : :ctrl]))

      assert_match(/\ADP-/, fixture.clipboard.text, "#{hint} buys")
    end
    given(:offer)
    show.input = P::InputKind::GAMEPAD

    assert_includes show.buy_label, "(Y)"
    press(:y)

    assert_match(/\ADP-/, fixture.clipboard.text, "Y buys")
  end

  # Home's large buttons carry a badge naming the controller's button
  # that opens each (Words#tile_badge): that button opens it.
  def test_each_of_homes_badges_names_the_button_that_opens_it
    { stats: -> { show.stats? }, achievements: -> { show.achievements_open? }, themes: -> { show.themes? },
      groups: -> { show.group_open? } }.each do |tile, opened|
      given(:home)
      badge = show.words.tile_badge(tile)
      if badge == "LT"
        handler.call(P::TriggerPull.new(trigger: :left, value: 1.0))
      else
        press(P::GamepadButtons::LABELS.key(badge) || flunk("#{tile}: #{badge} names no button"))
      end

      assert opened.call, "#{tile}: #{badge}"
    end
  end

  attr_reader :fixture, :handler, :sizing

  def show = fixture.show

  private

  def label(button) = P::GamepadButtons::LABELS.fetch(button)

  def given(at, os: "Linux")
    phone = at == :phone_settings
    @fixture = Fixture.new(os: phone ? "iOS" : os, width: phone ? 400 : 1200, height: phone ? 850 : 800, pro: at == :notice)
    start = P::GamepadCursor.centered(show.layout.whole, style: P::Style::GAMEPAD, radius: DotPopperTest::R)
    @handler = P::InputHandler.new(show:, platform: fixture.platform, shell: FakeShell.new, pile: FakeShell.new, cursor: start)
    @sizing = show.cabinet.sizing
    reach(at)
    fixture.tick(0.1)
  end

  # A controller's +button+, pressed with the cursor on the control
  # +aimed+, or else at a place with no control under it.
  def press(button, aimed = nil)
    reach = aimed && show.reach_of(aimed)
    handler.fake_pad(:move, *(reach ? [reach.center_x, reach.center_y] : [5.0, show.layout.height / 2.0]))
    handler.call(P::ButtonPress.new(button:))
  end

  def reach(at)
    case at
    when :stats then show.open_stats
    when :cleared then show.open_stats.then { hold_clear }
    when :achievements then show.open_achievements
    when :dialog then show.open_achievements.then { show.open_achievement(DotPopper::Achievement::IDS.first) }
    when :settings, :phone_settings then show.open_settings
    when :privacy then show.open_settings.then { show.open_privacy }
    when :offer then show.open_offer
    when :notice then show.group_panel.open.then { show.group_panel.pad(:x) }
    when :tutorial then show.how_to_play
    when :game_over, :share
      show.play
      fixture.tick(DotPopper::Rules::STARTING_SECONDS + 1)
      fixture.tick(DotPopper::Rules::GAME_OVER_GRACE + 0.1)
      show.pad(:y) if at == :share
    end
  end

  def hold_clear
    show.pad(:y)
    fixture.tick(P::Style::HOLD.seconds + 0.2) if defined?(P::Style::HOLD)
    fixture.tick(5.0)
    show.let_go(:y)
  end

  def gamepad_text(path)
    word = path.first == :groups ? group_word(path.last) : dig(path)
    word.gamepad
  end

  def group_word(name) = name == :notice_go ? P::GroupWords.notice_go(:join) : P::GroupWords.public_send(name)

  def dig(path) = path.reduce(P::Style::WORDS.to_h) { |at, key| at.fetch(key) }

  # Every ByInput among the words whose controller text names a button,
  # in parentheses or as "Hold Y".
  def words_naming_an_input
    names = P::GamepadButtons::LABELS.values.join("|")
    pattern = /\((#{names})\)|\bHold (#{names})\b/
    top = P::Style::WORDS.to_h.filter_map { |key, word| [key] if word.is_a?(P::ByInput) && word.gamepad.match?(pattern) }
    buttons = P::Style::WORDS.buttons.filter_map { |key, word| [:buttons, key] if word.is_a?(P::ByInput) && word.gamepad.match?(pattern) }
    groups = %i[notice_policy notice_later notice_go].map { [:groups, it] }
    top + buttons + groups
  end
end
