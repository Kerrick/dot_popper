# frozen_string_literal: true

require_relative "inputs"

# Each input alone is enough to play and to buy Pro. Asked whether each
# of keyboard, mouse, controller and touch must be, the maintainer
# answered: "\"Keyboard alone\" isn't a thing; touch alone is, controller
# alone is, and mouse-and-keyboard-without-touch-without-controller is."
# So there are three inputs: touch, a controller, and a mouse with its
# keyboard (Inputs).
#
# Nothing here lists the screens or their controls. Each input explores
# the Show from Home, pressing everything it is offered
# (Inputs::Exploration), in Fixtures that between them bring out every
# screen; then each input must
# reach every screen the others reach, and press every control it is
# offered there, to some effect. A screen or control added later is
# found the same way, and fails here if an input cannot reach it. What
# keeps that honest is that the screens are asked too: every kind of
# control a screen answers (Screens::Screen#answers, which is all a press
# of a control reaches), every screen object, and every friend-group page
# (GroupPanel::PAGES), must be found by the exploring, or be listed in
# NOT_FOUND with the reason no screen offers it.
#
# Each input also presses what it has besides a place (Input#presses):
# a keyboard's keys and Android's Back, handed to Presentation::InputHandler
# as Shell::App hands them, so the system's rules for keys hold here; and a
# controller's buttons, handed to the Show by inputs.rb's own copy of what
# the InputHandler does with each. What this cannot see is the splash.
class InputsTest < Minitest::Test
  include Inputs

  # The inputs each system has. A phone or tablet is played by touch or
  # a paired controller, and a computer by mouse and keyboard or a
  # controller, and on Windows by touch too.
  INPUTS = { "iOS" => [Finger, Pad], "Android" => [Finger, Pad], "Windows" => [Finger, Mouse, Pad],
             "OS X" => [Mouse, Pad], "Linux" => [Mouse, Pad] }.freeze

  # A server's address the player copied, for Change Server to paste.
  SERVER = "https://groups.example.org"

  # Between them these bring out every screen: Free and Pro, games left
  # or none, in friend groups, a new theme to tell, setdef gone, and a
  # first launch, at phone and window sizes from the smallest window up.
  FIXTURES = {
    "an upright phone, Free" => { os: "iOS", width: 400, height: 850 },
    "a phone on its side, Free, no games left, a new theme" => { os: "Android", width: 850, height: 400, games_left: 0, arrival: true },
    "a small phone, Pro, in friend groups" => { os: "iOS", width: 375, height: 667, pro: true, member: true },
    "a phone's first launch, setdef gone" => { os: "Android", width: 412, height: 832, played: false, gone: true, copied: SERVER },
    "a touchscreen computer, Pro, in friend groups, setdef gone" => { os: "Windows", width: 1200, height: 800, pro: true, member: true,
                                                                      gone: true, to_pop: 20, copied: SERVER },
    "the smallest window, Pro, in friend groups, a new theme" => { os: "Linux", width: 400, height: 320, pro: true, member: true,
                                                                    arrival: true },
    "a computer's first launch, Free, no games left" => { os: "OS X", width: 1920, height: 1080, played: false, games_left: 0 }
  }.freeze

  # Controls only a controller is offered, and how a finger or a mouse
  # does the same: stepping through the themes, an achievement's dialogs,
  # and the friend groups, where moving a cursor is slower than a tap or a click.
  PAD_ONLY = {
    theme_prev: "a tap on the theme", theme_next: "a tap on the theme",
    achievement_prev: "Close, then a tap on the achievement", achievement_next: "Close, then a tap on the achievement",
    group_prev: "Back, then a tap on the group", group_next: "Back, then a tap on the group",
    group_open_first: "a tap on the group"
  }.freeze

  # Controls the Show answers that no screen offers, and why.
  NOT_FOUND = {}.freeze

  # Where an input cannot reach a screen or work a control today, as
  # "Input, screen: control outcome" (#gaps). None, today.
  KNOWN_GAPS = {}.freeze

  def self.explorations(fixture)
    (@explorations ||= {})[fixture] ||= INPUTS.fetch(FIXTURES.fetch(fixture)[:os]).to_h do |input|
      [input, Exploration.new(-> { Fixture.new(**FIXTURES.fetch(fixture)) }, input)]
    end
  end

  def self.slug(text) = text.downcase.gsub(/[^a-z0-9]+/, "_").delete_suffix("_")

  FIXTURES.each_key do |fixture|
    define_method(:"test_on_#{slug(fixture)}_each_input_alone_reaches_every_screen_and_works_every_control") do
      assert_equal KNOWN_GAPS.fetch(fixture, []), gaps(InputsTest.explorations(fixture)), fixture
    end
  end

  # What each input cannot do that its Fixture offers: a screen another
  # input reaches and it never does; a control it is offered and cannot
  # press, or presses to no effect; a control the others are offered and
  # it is not (PAD_ONLY aside); and a screen it cannot leave.
  def gaps(explorations)
    explorations.flat_map do |input, exploration|
      others = explorations.except(input).values.flat_map { it.nodes.values }
      nodes = exploration.nodes.values
      label = input.name.split("::").last
      missed = (others.map(&:screen).uniq - exploration.screens).map { "#{label}, #{Inputs.say(it)}: never reached" }
      missed + exploration.screens.flat_map do |screen|
        here = nodes.select { it.screen == screen }
        offered = here.flat_map(&:names).uniq
        failed = (offered - here.flat_map { |node| node.pressed.select { |_, outcome| outcome == :pressed }.keys }).map do |name|
          "#{label}, #{Inputs.say(screen)}: #{name.inspect} #{here.filter_map { it.pressed[name] }.first || :never_tried}"
        end
        unoffered = (others.select { it.screen == screen }.flat_map(&:names).uniq - offered - PAD_ONLY.keys).map do |name|
          "#{label}, #{Inputs.say(screen)}: #{name.inspect} not offered"
        end
        stuck = here.all? { it.leads.empty? } ? ["#{label}, #{Inputs.say(screen)}: cannot leave"] : []
        failed + unoffered + stuck
      end
    end
  end

  # Every screen object of a Show (Show#screens), as each Fixture makes it.
  def screen_objects = Fixture.new(**FIXTURES.values.first).show.screens

  # The kinds of control the screens answer (Screens::Screen#answers).
  def answered = screen_objects.values.flat_map(&:answers).uniq

  def found = FIXTURES.each_key.flat_map { |fixture| InputsTest.explorations(fixture).values.flat_map { |exploration| exploration.nodes.values.flat_map(&:names) } }

  def test_every_control_the_show_answers_is_found_or_is_offered_by_no_screen
    kinds = found.map { P::Control.kind(it) }.uniq
    assert_empty answered - kinds - NOT_FOUND.keys, "found by no input in any Fixture: add a Fixture that shows it, or to NOT_FOUND why none does"
    assert_empty NOT_FOUND.keys & kinds, "found after all: take it out of NOT_FOUND"
    assert_includes kinds, :skip, "the Tutorial's Skip"
  end

  def test_every_screen_the_show_opens_is_found
    pages = screen_objects.filter_map { |name, screen| name if screen.is_a?(P::Screens::Page) }
    seen = FIXTURES.each_key.flat_map { |fixture| InputsTest.explorations(fixture).values.flat_map(&:screens) }

    refute_empty pages
    assert_empty pages - seen.map { it[1] }, "screens over Home that no Fixture reaches"
    assert_empty P::GroupPanel::PAGES - seen.map { it[2] }, "friend-group screens that no Fixture reaches"
    %w[Playing Paused GameOver].each { |state| assert_includes seen.map(&:first), state }
    %w[notice offer dialog share_preview tutorial new_theme].each.with_index(3) do |layer, at|
      assert seen.any? { it[at] }, "a Fixture shows the #{layer}"
    end
  end

  # What each input presses besides a place (Input#presses: a
  # controller's B, X, Y, bumpers, left trigger, View and Start; a
  # keyboard's Enter, Escape, letters, a digit, Backspace and the paste and
  # Buy chords; Android's Back) does something on some screen of some
  # Fixture, so none of them is pressed for nothing everywhere.
  def test_each_press_of_each_input_does_something_somewhere
    explorations = FIXTURES.each_key.flat_map { |fixture| InputsTest.explorations(fixture).to_a }
    idle = explorations.group_by(&:first).flat_map do |input, pairs|
      nodes = pairs.flat_map { |_, exploration| exploration.nodes.values }
      presses = nodes.flat_map { it.pressed.keys.grep(String) }.uniq
      (presses - nodes.flat_map { |node| node.pressed.select { |name, outcome| name.is_a?(String) && outcome == :pressed }.keys }).map do
        "#{input.name.split("::").last}: #{it}"
      end
    end
    assert_empty idle, "pressed on every screen to no effect"
  end

  # B on a controller, Escape on a keyboard and Android's Back go where
  # the screen's own Back, Close or Home button goes, on every screen that
  # has one.
  def test_b_escape_and_androids_back_go_where_the_screens_back_button_goes
    backs = { Pad => "B", Mouse => "Escape", Finger => "Back" }
    wrong = FIXTURES.each_key.flat_map do |fixture|
      InputsTest.explorations(fixture).flat_map do |input, exploration|
        press = backs.fetch(input)
        exploration.nodes.values.filter_map do |node|
          button = (%i[back close home] & node.went.keys).first or next
          next unless node.went.key?(press)
          next if node.went[press] == node.went[button]

          "#{fixture}, #{input.name.split("::").last}, #{Inputs.say(node.screen)}: #{press} went to #{Inputs.say(node.went[press])}, " \
            "#{button.inspect} to #{Inputs.say(node.went[button])}"
        end
      end
    end
    assert_empty wrong
  end

  # Every screen is an object (Screens), and every one of them is on top
  # somewhere an input reaches, so a screen added later fails here until a
  # Fixture shows it.
  def test_every_screen_object_is_reached
    screens = P::Screens.constants.map { P::Screens.const_get(it) }.select { it.is_a?(Class) && it < P::Screens::Screen }
    abstract = [P::Screens::Page]
    seen = FIXTURES.each_key.flat_map { |fixture| InputsTest.explorations(fixture).values.flat_map(&:screens) }.map(&:last).uniq

    assert_operator screens.size, :>=, 16
    assert_empty screens - abstract - seen, "screens no input reaches"
  end

  # The journey, by each input alone, on each system: a Free player with
  # no games left starts at Home, whose Play says Get Pro; it opens the
  # offer; Buy, in a test build's store, makes them Pro (on a computer,
  # Buy puts a license key on the clipboard, and Paste license key enters
  # it); Back is Home, where Play starts a game, played to Game Over, and
  # Home goes Home.
  INPUTS.each do |os, inputs|
    inputs.each do |input|
      define_method(:"test_by_#{slug(input.name.split("::").last)}_alone_on_#{slug(os)}_a_free_player_buys_pro_and_plays_a_game") do
        fixture = Fixture.new(os:, width: os == "iOS" || os == "Android" ? 400 : 1200, height: 850, games_left: 0)
        player = input.new(fixture)
        show = fixture.show

        assert_equal show.words.button(:get_pro), show.play_word
        assert_equal :pressed, player.press(:play)
        assert_predicate show, :offer?
        # A store's copy, on a phone, has Restore Purchases and never takes a
        # license key; a computer's test build sells as a website copy does.
        assert_includes show.controls.map(&:name), fixture.phone? ? :restore : :paste
        assert_equal :pressed, player.press(:buy)
        assert_equal :pressed, player.press(:paste) if fixture.storefront.keys?
        fixture.tick(1.0)

        assert_predicate fixture.entitlement, :pro?
        assert_equal show.words.offer[:thanks], show.offer_status
        assert_equal :pressed, player.press(:back)
        assert_predicate show, :on_home?
        assert_equal :pressed, player.press(:play)
        assert_predicate show, :playing?
        assert_equal :pressed, player.play
        assert_operator show.game_over.score, :>, 0, "popped dots"
        assert_equal :pressed, player.press(:home)
        assert_predicate show, :on_home?
      end
    end
  end

  # How to play is the Tutorial, which waits for the player to pop the
  # dots it shows, as each input can.
  INPUTS.values.flatten.uniq.each do |input|
    define_method(:"test_by_#{slug(input.name.split("::").last)}_alone_how_to_play_plays_to_its_end") do
      fixture = Fixture.new(os: input == Mouse ? "Linux" : "Android", width: 850, height: 400)
      player = input.new(fixture)

      assert_equal :pressed, player.press(:how_to_play)
      assert_predicate fixture.show, :tutorial?
      player.play while fixture.show.tutorial?

      refute_predicate fixture.show, :tutorial?
    end
  end

  # The systems' own rules, which no input changes: a phone or tablet is
  # left by the system, so Home has no Quit there (and iOS leaves quitting
  # to the system altogether: Shell::App ignores Escape and B there); a
  # computer's Home has Quit, which a press quits at once.
  def test_only_a_computer_has_quit
    phone = Fixture.new(os: "iOS", width: 400, height: 850)

    refute_includes phone.show.controls.map(&:name), :quit
    INPUTS.fetch("Windows").each do |input|
      computer = Fixture.new(os: "Windows", width: 1200, height: 800)
      assert_equal :pressed, input.new(computer).press(:quit)
      assert_equal 1, computer.window.quits, input.name
    end
  end

  # On a phone, Share my score hands the score to the system's share
  # sheet, by any input, and opens no preview of its own.
  def test_a_phone_shares_through_the_systems_sheet
    INPUTS.fetch("Android").each do |input|
      fixture = Fixture.new(os: "Android", width: 400, height: 850)
      player = input.new(fixture)
      player.press(:play)
      player.play

      assert_equal :pressed, player.press(:share)
      refute_predicate fixture.show, :sharing?
      assert_match(/\Adotpopper-share:/, fixture.opener.urls.last, input.name)
    end
  end

  # During a game no control is offered to any input: only a press at a
  # place reaches the game, so nothing scores without aiming.
  def test_a_game_offers_no_control_and_ends_only_by_its_clock
    INPUTS.values.flatten.uniq.each do |input|
      fixture = Fixture.new(os: "Windows", width: 1200, height: 800)
      input.new(fixture).press(:play)

      assert_predicate fixture.show, :playing?
      assert_empty fixture.show.controls, input.name
      refute fixture.show.back, "Back does nothing in a game"
    end
  end

  # A controller does everything a website copy's purchase needs inside
  # the game, and the rest is the browser's and the email's. Pro is sold
  # in the player's browser, and the license key comes by email: Buy (Y)
  # opens the browser, and back in the game, Paste license key (X) enters
  # the key the player copied. A controller cannot copy from an email, and
  # typing a key of over a hundred letters with one is not practical, so
  # it is offered no keyboard for it (doc/design/input.md, "A controller
  # alone").
  def test_a_controller_alone_opens_the_website_to_buy_and_pastes_the_key_it_is_sent
    fixture = Fixture.new(os: "Windows", width: 1200, height: 800, games_left: 0, channel: "website")
    player = Pad.new(fixture)
    player.press(:play)
    player.press(:buy)

    assert_equal DotPopper::BrowserCheckout::URL, fixture.opener.urls.last
    assert_equal fixture.show.words.offer[:browser], fixture.show.offer_status
    assert_equal :pressed, player.press(:paste)
    assert_equal fixture.show.words.offer[:empty], fixture.show.offer_status, "Copy your license key first."
    refute_predicate fixture.entitlement, :pro?

    fixture.clipboard.copy(DotPopper::Continuity::LicenseKey.issue(DotPopper::Continuity::TestKeys::LICENSE).text) # copied from the email
    assert_equal :pressed, player.press(:paste)
    fixture.tick(1.0)
    assert_predicate fixture.entitlement, :pro?
  end

  # Change Server, offered while setdef is gone, takes a server's address
  # from the clipboard (Paste server address), which a controller reaches
  # and presses; the address is copied elsewhere, as a license key is.
  def test_a_controller_alone_pastes_the_server_address_it_was_given
    fixture = Fixture.new(os: "Linux", width: 1200, height: 800, gone: true)
    player = Pad.new(fixture)
    %i[settings server server_paste].each { assert_equal :pressed, player.press(it) }

    assert_equal :empty, fixture.server_choice.status
    assert_nil fixture.server_choice.address
    refute_includes fixture.show.controls.map(&:name), :server_reset, "nothing was chosen"

    fixture.clipboard.copy(SERVER)
    assert_equal :pressed, player.press(:server_paste)
    assert_equal SERVER, fixture.server_choice.address
  end
end
