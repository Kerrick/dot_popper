# frozen_string_literal: true

require_relative "presentation_helper"

# The three inputs that must each be enough on their own: touch, a
# controller, and a mouse with its keyboard. Each is a hand that works a
# World's Show the way Shell::App hands that input's presses to it, and
# nothing else, so what a hand cannot reach here, that input cannot reach
# in the game. Used by inputs_test.rb.
module Hands
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
    def initialize = (@answers = []) && (@groups = [group(1), group(2)])

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

  # A Show, built as Shell::App#load builds it in a test build on +os+ (as
  # Lota::System.os names it), at +width+ by +height+, with what the game
  # keeps for a player: Pro or not, games left, a friend group, a new theme
  # to tell, setdef gone. It moves on as frames do: the Cabinet, then the
  # Show.
  class World
    include PresentationTest

    PHONES = %w[iOS Android].freeze
    THEMES = %i[ghost jack_o_lantern].freeze

    attr_reader :os, :show, :cabinet, :sounds, :window, :clipboard, :opener, :entitlement, :games, :storefront, :server_choice, :to_pop

    # +to_pop+ is how many bright dots a game is played for (Hand#play)
    # before it is left to its clock: 20 in a row earn Steady hand, so
    # Game Over has an achievement's line to open. +copied+ is on the
    # clipboard, as text the player copied elsewhere.
    # +channel+ is the build's (Build::CHANNEL), nil for a test build.
    def initialize(os:, width:, height:, pro: false, games_left: 20, played: true, member: false, arrival: false, gone: false, to_pop: 3,
                   copied: nil, channel: nil)
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
      @storefront = P::Storefront.for(os, entitlement:, native: P::FakeStore.new(Memory.new), fake: P::FakeStore.new(Memory.new),
                                          website: ->(fake:) { website(license, fake:) }, channel:)
      @games = DotPopper::FreeGames.new(Memory.new, today: -> { @day }, entitlement:, metered: storefront.offered?, bank: [games_left - 3, 0].max)
      (3 - games_left.clamp(0, 3)).times { games.spend! }
      themes = P::ThemeKeeper.new(Memory.new, themes: Style::THEMES, entitlement:)
      themes.receive(THEMES.map(&:to_s))
      (arrival ? themes.shown[0...-1] : themes.shown).each { themes.told(it) }
      book = DotPopper::StatsBook.new(Memory.new, today: -> { @day })
      book.record(DotPopper::GameStats.start, @cabinet.size_class) if played
      session = DotPopper::Groups::Session.new(store: Memory.new, worker: Server.new)
      @server_choice = P::ServerChoice.new(Memory.new, gone: @gone, clipboard:)
      @show = Show.new(cabinet:, layout: layout(width, height), sounds:, radius: R, random: Random.new(5), clipboard:, window:, stats_book: book,
                       sharing: P::SheetSharing.for(os, opener:), links: opener, entitlement:, storefront:, games:,
                       theme_keeper: themes, groups: session, group_notice: P::GroupNotice.new(Memory.new),
                       tutorial_flag: P::TutorialFlag.new(Memory.new((P::TutorialFlag::SEEN if played))), input: P::InputKind.starting(touch: phone?),
                       server_choice: @server_choice)
      storefront.connect
      join(session) if member
      tick(0.5)
    end

    def phone? = PHONES.include?(os)

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

    def website(license, fake:)
      checkout = fake ? P::FakeCheckout.new(clipboard:) : P::BrowserCheckout.new(opener:)
      P::WebsiteStore.new(checkout:, license:, gone: @gone, clipboard:)
    end

    def join(session)
      session.join("2345678")
      3.times { session.update(quiet: true) }
      session.refresh
      3.times { session.update(quiet: true) }
    end
  end

  # A hand: the one input a player has. It points at a place on the
  # screen and presses there, as Shell::App#press hands a press to the
  # Show (InputRouter's Tap, then Show#tap, or the pile on Game Over away
  # from its buttons), lets go (Show#let_go), and scrolls a list its own
  # way. Every press first says what made it (Show#input=), as
  # App#heard does.
  class Hand
    CLICK = 0.05 # seconds a press is held, unless it is a hold
    LOOK = 0.5 # seconds a player takes to see a screen before pressing
    REACT = 0.5 # seconds a player takes to see a new bright dot and reach for it

    attr_reader :world

    def initialize(world)
      @world = world
      show.input = kind
    end

    def show = world.show

    # Presses the control named +name+ (Control#name) on the open
    # screen, scrolling it into view first: says :pressed, or why not.
    # A press that starts a hold (Clear my stats…, Leave, Delete my data)
    # is held until it is done.
    def press(name)
      world.tick(LOOK)
      control = reveal(name) or return :not_shown
      point = aim(control) or return :out_of_reach
      x, y = point
      return :out_of_reach unless show.control_at(x, y)&.name == name

      down(x, y)
      world.tick(holding ? holding.seconds + 0.2 : CLICK)
      up
      world.tick(CLICK)
      :pressed
    end

    # Plays the game in view, or the Tutorial over it: pops the dot the
    # Tutorial waits for, or the game's bright dots, World#to_pop of them,
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
          world.tick(0.1)
          spent += 0.1
        end
      end
      return :still_playing if show.playing? || show.tutorial?

      world.tick(DotPopper::Rules::GAME_OVER_GRACE) if show.game_over? # Game Over takes no press before it
      :pressed
    end

    # The dot to pop next, as a player would choose it: the one the
    # Tutorial waits for, or a bright dot on top of the stack.
    def target(popped)
      if show.tutorial?
        id = P::Tutorial::TURNS[show.tutorial.beat]
        return id && show.tutorial.dots.find { it.id == id && !it.popped? }
      end
      return if popped >= world.to_pop

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
      world.tick(REACT)
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

    # Every control the open screen offers this hand, top to bottom of
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

    # Where this hand can press, aiming for +x+, +y+, or nil.
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
  class Finger < Hand
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
    def kind = P::InputKind::MOUSE
    def key = :mouse

    def scroll_by(by) = show.wheel_scroll(-3 * by)
  end

  # A controller: the left stick steers the cursor (GamepadCursor), A
  # presses where it points, and the right stick scrolls a list. The
  # cursor is steered, frame by frame, as a player would steer it, and the
  # time it takes passes in the World.
  class Pad < Hand
    FRAME = 1 / 60.0
    LONGEST = 6.0 # seconds to reach anything, the window's diagonal taking 1

    def initialize(world)
      super
      @cursor = P::GamepadCursor.centered(show.layout.whole, style: P::Style::GAMEPAD, radius: DotPopperTest::R)
    end

    def kind = P::InputKind::GAMEPAD
    def key = :gamepad

    def scroll_by(by)
      stick = P::Stick.new(x: 0.0, y: by.positive? ? 1.0 : -1.0)
      seconds = show.layout.page.height * 0.6 / (P::Style::CREDITS.stick * show.scroll_line)
      (seconds / FRAME).ceil.times { show.stick_scroll(stick, FRAME) }
    end

    # Steers the cursor onto the dot +id+ as it moves, a frame at a time,
    # and presses A once the cursor is well inside it.
    def pop(id)
      world.tick(REACT)
      spent = 0.0
      loop do
        spot = dot(id) or return
        break if Math.hypot(spot.x - @cursor.x, spot.y - @cursor.y) < spot.radius * 0.3 && clear?(id, @cursor.x, @cursor.y)
        return if spent > LONGEST

        @cursor = @cursor.update(FRAME, push(spot.x, spot.y, spot.velocity_x, spot.velocity_y))
        world.tick(FRAME)
        spent += FRAME
      end
      @cursor = @cursor.update(FRAME, P::Stick.rest)
      down(@cursor.x, @cursor.y)
      up
      true
    end

    private

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
      world.tick(spent)
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
    [show.cabinet.state.class.name.split("::").last, show.page, (show.group_panel.page if show.group_open?),
     (show.group_panel.asking if show.group_open?), show.offer?, !show.dialog.nil?, show.sharing?, show.tutorial?, show.arrival?]
  end

  # A screen as words, for a failure's message: "Home, settings".
  def self.say(screen)
    state, page, group, asking, offer, dialog, sharing, tutorial, arrival = screen
    [state, page, (:"groups #{group}" if group), (:"#{asking} notice" if asking), (:offer if offer), (:dialog if dialog),
     (:share_preview if sharing), (:tutorial if tutorial), (:new_theme if arrival)].compact.join(", ")
  end

  # A control's kind: a list's rows, a row of choices, and the themes
  # each count as one.
  def self.kind(name)
    case name
    when Array then name.first
    when P::Theme then :theme
    when DotPopper::DotSizing then :dot_size
    else name
    end
  end

  # Everything one hand can find from the World +build+ makes, starting
  # at Home and pressing every control of every screen it comes to, each
  # from a fresh World: the screens (with the controls each offers this
  # hand, its list scrolled from top to bottom), and what each press did.
  # A screen is told apart by Hands.screen and by the kinds of control it
  # offers, so a new screen, or a new layer over one, is a new place to
  # explore without anyone listing it.
  class Map
    # The step that is no control's: playing the game, or the Tutorial,
    # in view.
    PLAY = :"(play)"

    # +pressed+ is each step's outcome: :pressed, :no_effect, or why it
    # was not pressed; +leads+ the other screens the steps led to.
    Node = Struct.new(:screen, :names, :path, :pressed, :leads, keyword_init: true)

    attr_reader :nodes

    def initialize(build, hand)
      @build = build
      @hand = hand
      @nodes = {}
      explore
    end

    def screens = nodes.values.map(&:screen).uniq

    # A fresh World with the steps of +path+ taken by this hand, and the
    # hand, or nil if a step could not be taken; and the last step's
    # outcome.
    def replay(path)
      world = @build.call
      hand = @hand.new(world)
      outcome = nil
      path.each_with_index do |step, i|
        before = trace(world) if i == path.size - 1
        outcome = take(step, world, hand)
        return [nil, nil, outcome] unless outcome == :pressed

        outcome = :no_effect if before && before == trace(world)
      end
      [world, hand, outcome]
    end

    private

    def explore
      queue = [[[], nil]]
      until queue.empty?
        path, from = queue.shift
        world, hand, outcome = replay(path)
        node = world && visit(world, hand, path, queue)
        next unless from

        from.pressed[path.last] = outcome
        from.leads << node.screen if node && node.screen != from.screen
      end
    end

    def visit(world, hand, path, queue)
      screen = Hands.screen(world.show)
      names = world.show.controls.map(&:name)
      swept = hand.sweep
      # A hand that cannot scroll a list without leaving its screen (a
      # finger's drag beside an achievement's dialog closes it) sees only
      # what is in view.
      names = swept if Hands.screen(world.show) == screen
      key = [screen, names.map { Hands.kind(it) }.uniq.sort_by(&:to_s)]
      return @nodes[key] if @nodes[key]

      node = @nodes[key] = Node.new(screen:, names:, path:, pressed: {}, leads: [])
      names.each { queue << [path + [it], node] }
      queue << [path + [PLAY], node] if world.show.playing? || world.show.tutorial?
      node
    end

    def take(step, world, hand)
      step == PLAY ? hand.play : hand.press(step)
    end

    # What a press can be seen to do.
    def trace(world)
      show = world.show
      [Hands.screen(show), world.sounds.played.size, world.window.display, (world.window.quits if world.window.respond_to?(:quits)),
       world.opener.urls.size, world.clipboard.paste, world.storefront.status, show.offer_status, show.scroll&.offset]
    end
  end
end
