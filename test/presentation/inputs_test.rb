# frozen_string_literal: true

require_relative "hands"

# Each input alone is enough to play and to buy Pro. Asked whether each
# of keyboard, mouse, controller and touch must be, the maintainer
# answered: "\"Keyboard alone\" isn't a thing; touch alone is, controller
# alone is, and mouse-and-keyboard-without-touch-without-controller is."
# So there are three inputs: touch, a controller, and a mouse with its
# keyboard (Hands).
#
# Nothing here lists the screens or their controls. Each hand explores
# the Show from Home, pressing everything it is offered (Hands::Map), in
# Worlds that between them bring out every screen; then each hand must
# reach every screen the others reach, and press every control it is
# offered there, to some effect. A screen or control added later is
# found the same way, and fails here if an input cannot reach it. What
# keeps that honest is that the code is read too: every control a screen
# answers (each Screens file's #pressed, and GroupPanel#press), and every
# screen Show#open_page and GroupPanel::PAGES name, must be found by the
# exploring, or be listed in NOT_FOUND with the reason no screen offers it.
#
# What this cannot see is Shell::App's own part, which needs Lota: which
# key or button calls which of the Show's methods (App#key_pressed,
# App#gamepad_pressed), the splash, and the system's rules there (iOS
# leaves quitting to the system; a phone's keyboard never quits). The
# hands press as App#press does, at a place, which every input can.
class InputsTest < Minitest::Test
  include Hands

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
  WORLDS = {
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
  # and the friend groups, where a cursor is slower than a hand.
  PAD_ONLY = {
    theme_prev: "a tap on the theme", theme_next: "a tap on the theme",
    achievement_prev: "Close, then a tap on the achievement", achievement_next: "Close, then a tap on the achievement",
    group_prev: "Back, then a tap on the group", group_next: "Back, then a tap on the group",
    group_open_first: "a tap on the group"
  }.freeze

  # Controls the Show answers that no screen offers, and why.
  NOT_FOUND = {
    group_delete: "no friend-group screen offers it; Delete my friend group data is Privacy's (:privacy_delete)"
  }.freeze

  # Where an input cannot reach a screen or work a control today, as
  # "Hand, screen: control outcome" (#gaps). None, today.
  KNOWN_GAPS = {}.freeze

  def self.maps(world)
    (@maps ||= {})[world] ||= INPUTS.fetch(WORLDS.fetch(world)[:os]).to_h do |hand|
      [hand, Map.new(-> { World.new(**WORLDS.fetch(world)) }, hand)]
    end
  end

  def self.slug(text) = text.downcase.gsub(/[^a-z0-9]+/, "_").delete_suffix("_")

  WORLDS.each_key do |world|
    define_method(:"test_on_#{slug(world)}_each_input_alone_reaches_every_screen_and_works_every_control") do
      assert_equal KNOWN_GAPS.fetch(world, []), gaps(InputsTest.maps(world)), world
    end
  end

  # What each hand cannot do that its World offers: a screen another
  # input reaches and it never does; a control it is offered and cannot
  # press, or presses to no effect; a control the others are offered and
  # it is not (PAD_ONLY aside); and a screen it cannot leave.
  def gaps(maps)
    maps.flat_map do |hand, map|
      others = maps.except(hand).values.flat_map { it.nodes.values }
      nodes = map.nodes.values
      label = hand.name.split("::").last
      missed = (others.map(&:screen).uniq - map.screens).map { "#{label}, #{Hands.say(it)}: never reached" }
      missed + map.screens.flat_map do |screen|
        here = nodes.select { it.screen == screen }
        offered = here.flat_map(&:names).uniq
        failed = (offered - here.flat_map { |node| node.pressed.select { |_, outcome| outcome == :pressed }.keys }).map do |name|
          "#{label}, #{Hands.say(screen)}: #{name.inspect} #{here.filter_map { it.pressed[name] }.first || :never_tried}"
        end
        unoffered = (others.select { it.screen == screen }.flat_map(&:names).uniq - offered - PAD_ONLY.keys).map do |name|
          "#{label}, #{Hands.say(screen)}: #{name.inspect} not offered"
        end
        stuck = here.all? { it.leads.empty? } ? ["#{label}, #{Hands.say(screen)}: cannot leave"] : []
        failed + unoffered + stuck
      end
    end
  end

  # The controls each screen answers (Screens::Screen#pressed in each
  # screen's file, and GroupPanel#press for the friend groups'), by kind
  # (Hands.kind). A screen that answers controls has a pressed method, or
  # takes its taps itself (the Tutorial's and a game's #tap).
  def answered
    folder = File.expand_path("../../lib/dot_popper/presentation", __dir__)
    texts = Dir["#{folder}/screens/*.rb"].map { File.read(it) }
    refute_empty texts, "no screens"
    texts.each { |text| assert_match(/def (pressed|tap)\(/, text) unless text.include?("< Page") }
    bodies = texts.filter_map { it[/^ +def pressed\(name.*?\n {8}end\n/m] }
    bodies << (File.read("#{folder}/group_panel.rb")[/^      def press\(name.*?\n      end\n/m] or flunk "no GroupPanel#press")
    kinds = { "Theme" => :theme, "DotSizing" => :dot_size }
    bodies.flat_map { it.scan(/^\s+in \[?:(\w+)/).flatten.map(&:to_sym) + it.scan(/^\s+in (\w+) =>/).flatten.filter_map { kinds[it] } }
  end

  def found = WORLDS.each_key.flat_map { |world| InputsTest.maps(world).values.flat_map { |map| map.nodes.values.flat_map(&:names) } }

  def test_every_control_the_show_answers_is_found_or_is_offered_by_no_screen
    kinds = found.map { Hands.kind(it) }.uniq
    assert_empty answered - kinds - NOT_FOUND.keys, "found by no input in any World: add a World that shows it, or to NOT_FOUND why none does"
    assert_empty NOT_FOUND.keys & kinds, "found after all: take it out of NOT_FOUND"
    assert_includes kinds, :skip, "the Tutorial's Skip, which Show#tap answers itself"
  end

  def test_every_screen_the_show_opens_is_found
    show = File.read(File.expand_path("../../lib/dot_popper/presentation/show.rb", __dir__))
    pages = show.scan(/open_page\(:(\w+)\)/).flatten.map(&:to_sym).uniq
    seen = WORLDS.each_key.flat_map { |world| InputsTest.maps(world).values.flat_map(&:screens) }

    refute_empty pages
    assert_empty pages - seen.map { it[1] }, "screens over Home that no World reaches"
    assert_empty P::GroupPanel::PAGES - seen.map { it[2] }, "friend-group screens that no World reaches"
    %w[Playing Paused GameOver].each { |state| assert_includes seen.map(&:first), state }
    %w[notice offer dialog share_preview tutorial new_theme].each.with_index(3) do |layer, at|
      assert seen.any? { it[at] }, "a World shows the #{layer}"
    end
  end

  # The journey, by each input alone, on each system: a Free player with
  # no games left starts at Home, whose Play says Get Pro; it opens the
  # offer; Buy, in a test build's store, makes them Pro (on a computer,
  # Buy puts a license key on the clipboard, and Paste license key enters
  # it); Back is Home, where Play starts a game, played to Game Over, and
  # Home goes Home.
  INPUTS.each do |os, hands|
    hands.each do |hand|
      define_method(:"test_by_#{slug(hand.name.split("::").last)}_alone_on_#{slug(os)}_a_free_player_buys_pro_and_plays_a_game") do
        world = World.new(os:, width: os == "iOS" || os == "Android" ? 400 : 1200, height: 850, games_left: 0)
        player = hand.new(world)
        show = world.show

        assert_equal show.words.button(:get_pro), show.play_word
        assert_equal :pressed, player.press(:play)
        assert_predicate show, :offer?
        # A store's copy, on a phone, has Restore Purchases and never takes a
        # license key; a computer's test build sells as a website copy does.
        assert_includes show.controls.map(&:name), world.phone? ? :restore : :paste
        assert_equal :pressed, player.press(:buy)
        assert_equal :pressed, player.press(:paste) if world.storefront.keys?
        world.tick(1.0)

        assert_predicate world.entitlement, :pro?
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
  INPUTS.values.flatten.uniq.each do |hand|
    define_method(:"test_by_#{slug(hand.name.split("::").last)}_alone_how_to_play_plays_to_its_end") do
      world = World.new(os: hand == Mouse ? "Linux" : "Android", width: 850, height: 400)
      player = hand.new(world)

      assert_equal :pressed, player.press(:how_to_play)
      assert_predicate world.show, :tutorial?
      player.play while world.show.tutorial?

      refute_predicate world.show, :tutorial?
    end
  end

  # The systems' own rules, which no input changes: a phone or tablet is
  # left by the system, so Home has no Quit there (and iOS leaves quitting
  # to the system altogether: Shell::App ignores Escape and B there); a
  # computer's Home has Quit, which a press quits at once.
  def test_only_a_computer_has_quit
    phone = World.new(os: "iOS", width: 400, height: 850)

    refute_includes phone.show.controls.map(&:name), :quit
    INPUTS.fetch("Windows").each do |hand|
      computer = World.new(os: "Windows", width: 1200, height: 800)
      assert_equal :pressed, hand.new(computer).press(:quit)
      assert_equal 1, computer.window.quits, hand.name
    end
  end

  # On a phone, Share my score hands the score to the system's share
  # sheet, by any input, and opens no preview of its own.
  def test_a_phone_shares_through_the_systems_sheet
    INPUTS.fetch("Android").each do |hand|
      world = World.new(os: "Android", width: 400, height: 850)
      player = hand.new(world)
      player.press(:play)
      player.play

      assert_equal :pressed, player.press(:share)
      refute_predicate world.show, :sharing?
      assert_match(/\Adotpopper-share:/, world.opener.urls.last, hand.name)
    end
  end

  # During a game no control is offered to any input: only a press at a
  # place reaches the game, so nothing scores without aiming.
  def test_a_game_offers_no_control_and_ends_only_by_its_clock
    INPUTS.values.flatten.uniq.each do |hand|
      world = World.new(os: "Windows", width: 1200, height: 800)
      hand.new(world).press(:play)

      assert_predicate world.show, :playing?
      assert_empty world.show.controls, hand.name
      refute world.show.back, "Back does nothing in a game"
    end
  end

  # Known gap: a copy no store controls (the website channel) sells Pro
  # in the player's browser, and the license key comes by email. Inside
  # the game, Buy only opens the browser, and the key comes in only by
  # Paste license key, from the clipboard, or typed on a keyboard. A
  # controller alone can do neither: it cannot copy the key from an email
  # onto the clipboard. Today's behavior, stated so that a way in for a
  # controller changes this test.
  def test_known_gap_a_controller_alone_cannot_bring_in_a_license_key_bought_on_the_website
    world = World.new(os: "Windows", width: 1200, height: 800, games_left: 0, channel: "website")
    player = Pad.new(world)
    player.press(:play)
    player.press(:buy)

    assert_equal P::BrowserCheckout::URL, world.opener.urls.last
    assert_equal world.show.words.offer[:browser], world.show.offer_status
    assert_equal :pressed, player.press(:paste)
    assert_equal world.show.words.offer[:empty], world.show.offer_status, "Copy your license key first."
    refute_predicate world.entitlement, :pro?
  end

  # Known gap: Change Server, offered while setdef is gone, takes a
  # server's address only from the clipboard (Paste server address),
  # which a controller alone cannot fill. Today's behavior.
  def test_known_gap_a_controller_alone_cannot_choose_another_server
    world = World.new(os: "Linux", width: 1200, height: 800, gone: true)
    player = Pad.new(world)
    %i[settings server server_paste].each { assert_equal :pressed, player.press(it) }

    assert_equal :empty, world.server_choice.status
    assert_nil world.server_choice.address
    refute_includes world.show.controls.map(&:name), :server_reset, "nothing was chosen"
  end
end
