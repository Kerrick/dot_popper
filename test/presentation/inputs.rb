# frozen_string_literal: true

require_relative "presentation_helper"
require "platforms_helper"

# The three inputs that must each be enough on their own: touch, a
# controller, and a mouse with its keyboard. Each (Input) works a
# Fixture's Show the way Shell::App hands that input's presses to it, and
# nothing else, so what an input cannot reach here, it cannot reach in
# the game. Used by inputs_test.rb.
module Inputs
  include PresentationTest

  Memory = DotPopper::ScoreRecord::Memory
  P = DotPopper::Presentation

  # Opens nothing, and remembers what it was asked to open: the share
  # sheet's and the links' URLs.
  class Opener
    attr_reader :urls

    def initialize = @urls = []
    def open(url) = (@urls << url) && true
  end

  # A friend-group server with fixed answers, at once, in this process:
  # every request is taken, and answered as the real server answers it.
  # Nothing leaves the process.
  class Server
    # +groups+ is how many groups the player is in, once joined.
    def initialize(groups: 2) = (@answers = []) && (@groups = (1..groups).map { group(it) })

    def start(job, _token) = @answers << [job, DotPopper::Network::Reply.new(status: job.kind == :create || job.kind == :join ? 201 : 200, body: answer(job))]
    def finished = @answers.shift(@answers.size)

    private

    def answer(job)
      case job.kind
      when :player then { "token" => "t" }
      when :groups then @groups
      when :create, :join, :group then @groups.first
      when :history then []
      when :achievement then { "groups" => @groups }
      when :game then { "groups" => [{ "group" => group(1).merge("champion_number" => 2, "top_score" => 99), "won_title" => true }] }
      else {}
      end
    end

    def group(id)
      { "id" => id, "join_code" => "2345678", "you" => 2, "champion_number" => 1, "top_score" => 18,
        "reign_started_at" => "2026-11-01", "members" => [1, 2].map { { "number" => it, "top_score" => it } } }
    end
  end

  # A Show, built as Composition::Root builds it in a test build on +os+ (as
  # Lota::System.os names it, and Shell::Platforms makes its Platform), at +width+ by +height+, with what the game
  # keeps for a player: Pro or not, games left, a friend group, a new theme
  # to tell, setdef gone. It moves on as frames do: the Cabinet, then the
  # Show.
  class Fixture
    include PresentationTest

    THEMES = %i[ghost jack_o_lantern].freeze

    attr_reader :os, :show, :cabinet, :sounds, :window, :clipboard, :opener, :entitlement, :games, :storefront, :server_choice, :to_pop,
                :shell

    # What the InputHandler asks of the engine, remembered: the splash is
    # long over, and the game is asked to quit or to switch fullscreen.
    class Shell
      attr_reader :quits, :switches

      def initialize = @quits = @switches = 0
      def splash? = false
      def skip_splash = nil
      def quit = @quits += 1
      def toggle_fullscreen = @switches += 1
    end

    # +to_pop+ is how many bright dots a game is played for (Input#play)
    # before it is left to its clock: 20 in a row earn Steady input, so
    # Game Over has an achievement's line to open. +copied+ is on the
    # clipboard, as text the player copied elsewhere.
    # +channel+ is the build's (Build::CHANNEL), nil for a test build.
    # +groups+ is how many friend groups a member is in.
    def initialize(os:, width:, height:, pro: false, games_left: 20, played: true, member: false, arrival: false, gone: false, to_pop: 3,
                   copied: nil, channel: nil, groups: 2)
      @os = os
      @to_pop = to_pop
      @day = Date.new(2026, 11, 12)
      @sounds = FakeSounds.new
      @opener = Opener.new
      @clipboard = MemoryClipboard.new
      @clipboard.copy(copied) if copied
      @window = phone? ? NoWindowControl.new : FakeWindow.new
      @cabinet = DotPopper::Cabinet.new(field(width, height), random: Random.new(5), sizing: DotPopper::DotSizing.parse(nil))
      @gone = DotPopper::Continuity::Gone.new(Memory.new)
      @gone.heard(:gone, @day - 200) if gone
      license = DotPopper::Continuity::License.new(Memory.new, pins: DotPopper::Continuity::TEST_PINS)
      @entitlement = DotPopper::Entitlement.new(forced: pro, license:, trust: DotPopper::Receipt::TEST)
      @storefront = DotPopper::Store.for(platform, entitlement:, native: DotPopper::FakeStore.new(Memory.new), fake: DotPopper::FakeStore.new(Memory.new),
                                          website: ->(fake:) { website(fake:) }, channel:)
      @games = DotPopper::FreeGames.new(Memory.new, today: -> { @day }, entitlement:, metered: storefront.offered?, first_games: [games_left - 3, 0].max)
      (3 - games_left.clamp(0, 3)).times { games.spend! }
      themes = DotPopper::Themes.new(Memory.new)
      themes.release(THEMES.map(&:to_s))
      (arrival ? themes.choices[0...-1] : themes.choices).each { themes.told(it) }
      book = DotPopper::StatsBook.new(Memory.new, today: -> { @day })
      book.record(DotPopper::GameStats.start, @cabinet.size_class) if played
      session = DotPopper::Groups::Session.new(store: Memory.new, worker: Server.new(groups:))
      @server_choice = P::ServerChoice.new(Memory.new, gone: @gone, clipboard:)
      @show = new_show(cabinet:, layout: layout(width, height), sounds:, radius: R, random: Random.new(5), clipboard:, window:, stats_book: book,
                       sharing: P::SheetSharing.for(platform, opener:), links: opener, entitlement:, storefront:, games:,
                       themes:, groups: session, group_notice: P::GroupNotice.new(Memory.new),
                       tutorial_flag: P::TutorialFlag.new(Memory.new((P::TutorialFlag::SEEN if played))), input: P::InputKind.starting(touch: phone?),
                       server_choice: @server_choice)
      storefront.connect
      @shell = Shell.new
      @keys = P::InputHandler.new(show:, platform:, shell:, pile: nil,
                                  cursor: P::GamepadCursor.centered(show.layout.whole, style: P::Style::GAMEPAD, radius: R))
      join(session) if member
      # A new theme's card takes presses once it has been up a moment
      # (Style::ARRIVAL_GRACE); at launch that passes during the splash.
      tick(arrival ? 0.5 + Style::ARRIVAL_GRACE : 0.5)
    end

    def phone? = platform.touch?

    # A key on a keyboard (+key+, as Shell::LotaInput names it), with the
    # modifier keys +held+, handed on as Shell::App hands it.
    def key(key, *held) = @keys.call(P::KeyPress.new(key:, held:))
    def platform = DotPopperTest.platform(os)

    # The frames of +seconds+, each at most Rules::LONGEST_FRAME, as
    # Shell::App#update runs them.
    def tick(seconds)
      while seconds.positive?
        step = [seconds, DotPopper::Rules::LONGEST_FRAME].min
        cabinet.update(step)
        show.update(step)
        seconds -= step
      end
    end

    private

    def website(fake:)
      checkout = fake ? DotPopper::FakeCheckout.new(clipboard:) : DotPopper::BrowserCheckout.new(opener:)
      DotPopper::WebsiteStore.new(checkout:, entitlement:, gone: @gone, clipboard:)
    end

    def join(session)
      session.join("2345678")
      3.times { session.update(quiet: true) }
      session.refresh
      3.times { session.update(quiet: true) }
    end
  end

  # One input, the only one a player has. It points at a place on the
  # screen and presses there, as InputHandler#press hands a press to the
  # Show (InputRouter's Tap, then Show#tap, or the pile on Game Over away
  # from its buttons), lets go (Show#let_go), and scrolls a list its own
  # way. Every press first says what made it (Show#input=), as
  # App#heard does.
  class Input
    CLICK = 0.05 # seconds a press is held, unless it is a hold
    LOOK = 0.5 # seconds a player takes to see a screen before pressing
    REACT = 0.5 # seconds a player takes to see a new bright dot and reach for it

    attr_reader :fixture

    def initialize(fixture)
      @fixture = fixture
      show.input = kind
    end

    def show = fixture.show

    # Presses the control named +name+ (Control#name) on the open
    # screen, scrolling it into view first: says :pressed, or why not.
    # A press that starts a hold (Clear my stats…, Leave, Delete my data)
    # is held until it is done.
    def press(name)
      fixture.tick(LOOK)
      control = reveal(name) or return :not_shown
      point = aim(control) or return :out_of_reach
      x, y = point
      return :out_of_reach unless show.control_at(x, y)&.name == name

      down(x, y)
      fixture.tick(holding ? holding.seconds + 0.2 : CLICK)
      up
      fixture.tick(CLICK)
      :pressed
    end

    # What this input presses besides a place on the screen, by name
    # (#act): none for a finger, but where the system has a Back of its own.
    def presses = fixture.os == "Android" ? ["Back"] : []

    # Presses +name+, one of #presses, as Shell::App hands it on (Presentation::InputHandler).
    def act(name)
      fixture.tick(LOOK)
      show.input = kind
      case name
      in "Back" then press_key(:escape)
      end
      fixture.tick(CLICK)
      :pressed
    end

    # Plays the game in view, or the Tutorial over it: pops the dot the
    # Tutorial waits for, or the game's bright dots, Fixture#to_pop of them,
    # then lets the clock run out. Says :pressed once it is over, and
    # Game Over will take a press.
    def play
      popped = 0
      spent = 0.0
      while (show.playing? || show.tutorial?) && spent < 300
        dot = target(popped)
        if dot && pop(dot.id)
          popped += 1
        else
          fixture.tick(0.1)
          spent += 0.1
        end
      end
      return :still_playing if show.playing? || show.tutorial?

      fixture.tick(DotPopper::Rules::GAME_OVER_GRACE) if show.game_over? # Game Over takes no press before it
      :pressed
    end

    # The dot to pop next, as a player would choose it: the one the
    # Tutorial waits for, or a bright dot on top of the stack.
    def target(popped)
      if show.tutorial?
        id = P::Tutorial::TURNS[show.tutorial.beat]
        return id && show.tutorial.dots.find { it.id == id && !it.popped? }
      end
      return if popped >= fixture.to_pop

      dots = show.cabinet.game.dots
      dots.find { it.bright? && dots.top_at(it.x, it.y)&.id == it.id }
    end

    # Where the dot +id+ is now, or nil once it is gone.
    def dot(id)
      dots = show.tutorial? ? show.tutorial.dots : show.cabinet.game&.dots
      dots&.find { it.id == id }
    end

    # Whether a press at +x+, +y+ lands on the dot +id+, not on a dot
    # over it, so a careful player makes no mistake.
    def clear?(id, x, y)
      dots = show.tutorial? ? show.tutorial.dots : show.cabinet.game&.dots
      dots&.top_at(x, y)&.id == id
    end

    # Taps the dot +id+ where it is when the player has seen it, unless
    # another dot has come over it.
    def pop(id)
      fixture.tick(REACT)
      spot = dot(id) or return
      return unless clear?(id, spot.x, spot.y)

      down(spot.x, spot.y)
      up
      true
    end

    # Scrolls the open list by about a page, down for +by+ positive.
    # Says whether it moved.
    def scroll(by)
      before = show.scroll&.offset
      scroll_by(by)
      !before.nil? && show.scroll&.offset != before
    end

    # Every control the open screen offers this input, top to bottom of
    # its list.
    def sweep
      seen = show.controls.map(&:name)
      return seen unless show.scroll

      40.times { break unless scroll(-1) }
      40.times do
        seen |= show.controls.map(&:name)
        break unless scroll(1)
      end
      seen | show.controls.map(&:name)
    end

    private

    def holding
      [show.clearing, show.group_panel.hold].find(&:held?)
    end

    # A key, handed on as Shell::App hands it (Presentation::InputHandler).
    def press_key(name) = fixture.key(name)

    # The control named +name+, scrolled into view.
    def reveal(name)
      find = -> { show.controls.find { it.name == name } }
      return find.call if find.call || !show.scroll

      40.times { break unless scroll(-1) }
      40.times do
        found = find.call and return found
        break unless scroll(1)
      end
      nil
    end

    def aim(control) = aim_at(control.reach.center_x, control.reach.center_y)

    # Where this input can press, aiming for +x+, +y+, or nil.
    def aim_at(x, y) = [x, y]

    def down(x, y)
      show.input = kind
      return pile(x, y) if show.waits_for_release?(x, y)

      show.tap(x, y, by: key)
    end

    # A press on Game Over's pile, away from its buttons: Shell::Dragging
    # hears it, and a press that drags nothing is heard as a press when
    # it lets go (Dragging's click, then Show#tap).
    def pile(x, y) = @pile = [x, y]

    def up
      x, y = @pile
      @pile = nil
      show.tap(x, y, by: key) if x
      show.let_go(key)
    end
  end

  # A finger on a touchscreen: a tap where it lands, and a list dragged
  # by a finger that starts away from its buttons.
  class Finger < Input
    def kind = P::InputKind::TOUCH
    def key = 7 # a touch id

    def scroll_by(by)
      point = empty or return
      x, y = point
      down(x, y)
      distance = show.layout.page.height * 0.6 * by
      steps = 6
      steps.times { |i| show.drag_scroll(key, y - (distance * (i + 1) / steps)) }
      up
    end

    # A place in the list's window with no control under it, where a
    # drag starts, or a list's row, which waits for its release.
    def empty
      page = show.layout.page
      points = (1..9).to_a.product((1..19).to_a).map { |i, j| [page.x + (page.width * i / 10.0), page.y + (page.height * j / 20.0)] }
      points.find { |x, y| show.control_at(x, y).nil? || show.list_row_at?(x, y) }
    end
  end

  # A mouse, and the keyboard beside it: a click where the pointer is,
  # and the wheel, three lines a notch.
  class Mouse < Finger
    # The keyboard's keys: Enter, Escape, the letters H and C, a digit,
    # Backspace, and the system's paste and Buy chords.
    KEYS = { "Enter" => :enter, "Escape" => :escape, "H" => :h, "C" => :c, "7" => :"7", "Backspace" => :backspace }.freeze

    def kind = P::InputKind::MOUSE
    def key = :mouse

    def presses = [*KEYS.keys, "Ctrl+V", "Ctrl+B"]

    def act(name)
      fixture.tick(LOOK)
      show.input = kind
      case name
      in "Ctrl+V" then fixture.key(:v, :ctrl)
      in "Ctrl+B" then fixture.key(:b, :ctrl)
      else press_key(KEYS.fetch(name))
      end
      fixture.tick(CLICK)
      :pressed
    end

    def scroll_by(by) = show.wheel_scroll(-3 * by)
  end

  # A controller: the left stick steers the cursor (GamepadCursor), A
  # presses where it points, and the right stick scrolls a list. The
  # cursor is steered, frame by frame, as a player would steer it, and the
  # time it takes passes in the Fixture.
  class Pad < Input
    FRAME = 1 / 60.0
    LONGEST = 6.0 # seconds to reach anything, the window's diagonal taking 1

    def initialize(fixture)
      super
      @cursor = P::GamepadCursor.centered(show.layout.whole, style: P::Style::GAMEPAD, radius: DotPopperTest::R)
    end

    # The buttons besides A at a place (GamepadButtons): A with the cursor
    # on no button, B, X, Y, the bumpers, the left trigger, View and Start.
    BUTTONS = { "B" => :leave, "X" => :x, "Y" => :y, "LB" => :lb, "RB" => :rb, "LT" => :lt, "View" => :select, "Start" => :start }.freeze

    def kind = P::InputKind::GAMEPAD
    def key = :gamepad

    def presses = BUTTONS.keys

    # A button pressed as Shell::App hands it on (App#gamepad_pressed), and
    # let go; a press that starts a hold (Y's Clear my stats…, Start's
    # Leave) is held until it is done.
    def act(name)
      fixture.tick(LOOK)
      show.input = kind
      return a_at_nothing if name == "A at nothing"

      button = BUTTONS.fetch(name)
      case button
      in :leave then show.back || (fixture.platform.quits_itself? && show.ask_to_quit)
      in :start then show.start
      else show.pad(button)
      end
      fixture.tick(holding ? holding.seconds + 0.2 : CLICK)
      show.let_go(button)
      fixture.tick(CLICK)
      :pressed
    end

    def scroll_by(by)
      stick = P::Stick.new(x: 0.0, y: by.positive? ? 1.0 : -1.0)
      seconds = show.layout.page.height * 0.6 / (P::Style::CREDITS.stick * show.scroll_line)
      (seconds / FRAME).ceil.times { show.stick_scroll(stick, FRAME) }
    end

    # Steers the cursor onto the dot +id+ as it moves, a frame at a time,
    # and presses A once the cursor is well inside it.
    def pop(id)
      fixture.tick(REACT)
      spent = 0.0
      loop do
        spot = dot(id) or return
        break if Math.hypot(spot.x - @cursor.x, spot.y - @cursor.y) < spot.radius * 0.3 && clear?(id, @cursor.x, @cursor.y)
        return if spent > LONGEST

        @cursor = @cursor.update(FRAME, push(spot.x, spot.y, spot.velocity_x, spot.velocity_y))
        fixture.tick(FRAME)
        spent += FRAME
      end
      @cursor = @cursor.update(FRAME, P::Stick.rest)
      down(@cursor.x, @cursor.y)
      up
      true
    end

    private

    # A with the cursor steered to a place no button reaches, nearest the
    # middle of the screen.
    def a_at_nothing
      safe = show.layout.safe
      points = (1..9).to_a.product((1..9).to_a).map { |i, j| [safe.x + (safe.width * i / 10.0), safe.y + (safe.height * j / 10.0)] }
      x, y = points.select { |px, py| show.control_at(px, py).nil? }.min_by { |px, py| Math.hypot(px - safe.center_x, py - safe.center_y) }
      return :no_place unless x

      point = aim_at(x, y) or return :out_of_reach
      return :out_of_reach if show.control_at(*point)

      down(*point)
      fixture.tick(CLICK)
      up
      fixture.tick(CLICK)
      :pressed
    end

    # Steers the cursor to +x+, +y+ with the left stick, a full tilt when
    # far and gentler as it nears, and lets go there.
    def aim_at(x, y)
      spent = 0.0
      until Math.hypot(x - @cursor.x, y - @cursor.y) < 2.0
        return if spent > LONGEST

        @cursor = @cursor.update(FRAME, push(x, y))
        spent += FRAME
      end
      @cursor = @cursor.update(FRAME, P::Stick.rest)
      fixture.tick(spent)
      [@cursor.x, @cursor.y]
    end

    # The push that moves the cursor toward +x+, +y+ (going at
    # +velocity_x+, +velocity_y+): as fast as it goes there, closing the
    # gap in a tenth of a second, at most a full tilt, through the stick's
    # dead zone and curve (Stick#shaped) worked backward.
    def push(x, y, velocity_x = 0.0, velocity_y = 0.0)
      want_x = velocity_x + ((x - @cursor.x) / 0.1)
      want_y = velocity_y + ((y - @cursor.y) / 0.1)
      speed = Math.hypot(want_x, want_y)
      return P::Stick.rest if speed.zero?

      style = P::Style::GAMEPAD
      strength = [speed / @cursor.top_speed, 1.0].min
      tilt = style.dead_zone + ((1.0 - style.dead_zone) * (strength**(1.0 / style.curve)))
      P::Stick.new(x: want_x / speed * tilt, y: want_y / speed * tilt)
    end
  end

  # What a screen is, as the player sees it: the state of the game under
  # it, and which screen the Show has open over it.
  def self.screen(show)
    [show.cabinet.state.class.name.split("::").last, Inputs.page(show), (show.group_panel.page if show.group_open?),
     (show.group_panel.asking if show.group_open?), show.offer?, !show.dialog.nil?, show.sharing?, show.tutorial?, show.arrival?,
     show.screen.class]
  end

  # The screen over Home that a player sees, the topmost one open
  # (Screens::Page), by its name in Screens.made_for, or nil.
  def self.page(show) = show.screens.key(show.layers.reverse.find { it.is_a?(P::Screens::Page) })

  # A screen as words, for a failure's message: "Home, settings".
  def self.say(screen)
    state, page, group, asking, offer, dialog, sharing, tutorial, arrival, = screen
    [state, page, (:"groups #{group}" if group), (:"#{asking} notice" if asking), (:offer if offer), (:dialog if dialog),
     (:share_preview if sharing), (:tutorial if tutorial), (:new_theme if arrival)].compact.join(", ")
  end

  # Everything one input can find from the Fixture +build+ makes, starting
  # at Home and pressing every control of every screen it comes to, each
  # from a fresh Fixture: the screens (with the controls each offers this
  # input, its list scrolled from top to bottom), and what each press did.
  # A screen is told apart by Inputs.screen and by the kinds of control it
  # offers, so a new screen, or a new layer over one, is a new place to
  # explore without anyone listing it.
  class Exploration
    # The step that is no control's: playing the game, or the Tutorial,
    # in view.
    PLAY = :"(play)"

    # +pressed+ is each step's outcome: :pressed, :no_effect, or why it
    # was not pressed; +leads+ the other screens the steps led to.
    Node = Struct.new(:screen, :names, :path, :pressed, :leads, :went, keyword_init: true)

    attr_reader :nodes

    def initialize(build, input)
      @build = build
      @input = input
      @nodes = {}
      explore
    end

    def screens = nodes.values.map(&:screen).uniq

    # A fresh Fixture with the steps of +path+ taken by this input, and the
    # input, or nil if a step could not be taken; and the last step's
    # outcome.
    def replay(path)
      fixture = @build.call
      input = @input.new(fixture)
      outcome = nil
      path.each_with_index do |step, i|
        before = trace(fixture) if i == path.size - 1
        outcome = take(step, fixture, input)
        return [nil, nil, outcome] unless outcome == :pressed

        outcome = :no_effect if before && before == trace(fixture)
      end
      [fixture, input, outcome]
    end

    private

    # From Home, every control of every screen it comes to, each leading
    # on to the screen it opens; and on each screen the input's own presses
    # (Input#presses), whose outcome and screen are noted but not explored
    # from, since the controls already reach every screen.
    def explore
      queue = [[[], nil]]
      until queue.empty?
        path, from = queue.shift
        fixture, input, outcome = replay(path)
        node = fixture && (path.last.is_a?(String) ? nil : visit(fixture, input, path, queue))
        next unless from

        from.pressed[path.last] = outcome
        from.went[path.last] = fixture && Inputs.screen(fixture.show)
        from.leads << node.screen if node && node.screen != from.screen
      end
    end

    def visit(fixture, input, path, queue)
      screen = Inputs.screen(fixture.show)
      names = fixture.show.controls.map(&:name)
      swept = input.sweep
      # An input that cannot scroll a list without leaving its screen (a
      # finger's drag beside an achievement's dialog closes it) sees only
      # what is in view.
      names = swept if Inputs.screen(fixture.show) == screen
      key = [screen, names.map { P::Control.kind(it) }.uniq.sort_by(&:to_s)]
      return @nodes[key] if @nodes[key]

      node = @nodes[key] = Node.new(screen:, names:, path:, pressed: {}, leads: [], went: {})
      presses = input.presses if (@pressed_on ||= []).none?(screen)
      @pressed_on << screen
      (names + presses.to_a).each { queue << [path + [it], node] }
      queue << [path + [PLAY], node] if fixture.show.playing? || fixture.show.tutorial?
      node
    end

    # A step: playing the game in view, one of the input's own presses
    # (Input#presses, named by a String), or a control pressed at its place.
    def take(step, fixture, input)
      return input.play if step == PLAY
      return input.act(step) if step.is_a?(String)

      input.press(step)
    end

    # What a press can be seen to do.
    def trace(fixture)
      show = fixture.show
      [Inputs.screen(show), fixture.sounds.played.size, fixture.window.display, (fixture.window.quits if fixture.window.respond_to?(:quits)),
       fixture.opener.urls.size, fixture.clipboard.paste, fixture.storefront.status, show.offer_status, show.scroll&.offset]
    end
  end
end
