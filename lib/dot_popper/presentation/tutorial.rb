# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the Tutorial plays, in seconds, radii, and rates of time, where 1
    # is the game's own. The first dot drifts for +drift+ from +start+ (an
    # [x, y] offset from the middle of the screen, as shares of the
    # field's width and height, so it is well away from the middle, where a
    # gamepad's cursor starts, on any screen), and time stops in
    # +stop+ and starts again in +resume+, or at +slow+ while the bright
    # dot slides clear. The next dot is +born+ under the first, a little
    # to its left; time stops as it peeks out, +peek+ away, while the
    # guide taps the popped dot and lifts away, until its cost has landed, and stops
    # again once it is +clear+ of the first. A pop's numbers wait +gap+
    # and fly into the HUD in +flight+, or +quick+ on the last pop; time
    # holds +hold+ after they land. The last pop's numbers +linger+, and
    # then the spotlight moves to the clock as time flows again, in
    # +handover+, and the game goes on from there. A beat that waits for
    # the dots to move never waits more than +longest+, should they
    # bounce. +spotlight+, +guide+ and +clock_highlight+ are the spotlight's
    # look, the guide's, and the clock highlight's. +notice+ is how long the row of dots
    # in a row rings when it changes.
    class TutorialStyle < Data.define(:drift, :stop, :resume, :slow, :start, :born, :peek, :clear, :flight,
                                     :quick, :gap, :hold, :linger, :handover, :longest, :spotlight, :guide, :clock_highlight,
                                     :notice)
      # Its old keyword and reader, +ghost+, until no caller says them.
      def initialize(guide: nil, ghost: nil, **rest) = super(guide: guide || ghost, **rest)
      def ghost = guide
    end

    # The row of dots in a row just changed, since +at+: a ring around it,
    # fading over +duration+, in +tone+, :gain as it counts a pop and
    # :alarm as a mistake empties it. It runs under the beat, and holds up
    # nothing.
    class RowNotice < Data.define(:at, :tone, :duration)
      def strength(now) = (1 - ((now - at) / duration)).clamp(0.0, 1.0)
    end

    # How the Tutorial's last beat goes on into the real game: its
    # spotlight on the clock fades out in +dim+ seconds, and a halo stays
    # around the clock for +halo+, then fades in +fade+.
    class ClockHighlightStyle < Data.define(:dim, :halo, :fade); end

    # The Tutorial's last beat, in the real game's first moments, since
    # +at+: the spotlight on the clock as it starts to run, fading, and a
    # halo around it a little longer. Only the clock is lit; the game's
    # own dots are never covered for more than a moment.
    class ClockHighlight < Data.define(:at, :style)
      def strength(now) = (1 - ((now - at) / style.dim)).clamp(0.0, 1.0)
      def halo(now) = (1 - ((now - at - style.halo) / style.fade)).clamp(0.0, 1.0)
      def over?(now) = now - at >= style.halo + style.fade
    end

    # The tutorial a player sees on their first Play: a layer over the
    # first game, which is paused before its clock first runs
    # (Cabinet::Paused). The game is the one game: its dots, score, clock
    # and rules are the rules' own, and the tutorial keeps no copy of
    # them. It moves the game's dots at its own pace, passes the game
    # only the presses it chooses, and draws over it: the spotlight, the
    # guide, the numbers in flight, and the HUD's numbers as each lands.
    # When it ends, or is skipped, it goes, and the game plays on from
    # the state it is in (Cabinet#unpause). It teaches without a word, in
    # four beats, and each tap that moves it on is the player's:
    #
    # 1. A bright dot drifts, time eases to a stop, a spotlight finds it,
    #    and the guide, the player's own hand or pointer drawn faintly
    #    (GuideHand), taps it, over and over, until the player does.
    # 2. Its pop bursts from the dot while it still looks bright, and
    #    holds time still at that instant while "+1" flies out of it into
    #    the HUD's score, and a stopwatch into its time, each ticking up as
    #    it lands. The rules popped it at the tap, but only as time flows
    #    again is it drawn popped (#settle), so the reward is seen to come
    #    from the bright dot. As
    #    the stopwatch lands, the light moves on to the HUD's row of dots
    #    in a row, the game's own, which lights its first and rings.
    # 3. A new bright dot is born under the popped one, as time flows
    #    again: the rules spawned it at the pop, which the stopped clock
    #    has held at that instant until now, and it is shown born, where
    #    it parts from the popped one (#parting), only now. As it peeks out,
    #    time stops again, and the guide taps the popped dot, once: the
    #    game's own penalty plays, its shudder, the dashed outline of the
    #    bright dot under it, and its cost out of the score and the time,
    #    which drop as it does; the row goes dark and rings red. The guide then waits to one side while time
    #    flows slowly until the bright dot is clear, and moves to it and
    #    taps. All that while the guide is showing, and a tap does nothing.
    #    Only then is it the player's turn again, as it was at the
    #    first tap.
    # 4. Its pop bursts, still bright, and its numbers fly in; as the
    #    spotlight moves to the clock and time flows again, it takes its
    #    popped look, and the bright dot the rules spawned under them all
    #    at the pop is shown born (#over?). The Show then unpauses the
    #    game, whose ClockHighlight lets the clock run.
    #
    # The guide's mistake is a press on the game, so it costs what it
    # does in play, by the rules. A player's tap on a popped dot never
    # reaches the game, even on their turn: the tutorial shows that cost
    # and never charges it to them. What a full row brings is left for the
    # game to surprise the player with: nothing here shows it or says so.
    #
    # It plays the sounds of its popping, cost, and chimes through the Show's +effects+,
    # +sounds+, and +haptics+, on the +cabinet+'s game, already paused with
    # its first dot (Tutorial.opening, started by UseCases::StartGame), as
    # +style+ (Style) says, on the Show's clock from +now+.
    class Tutorial
      BRIGHT = 0 # the first bright dot's id
      NEXT = 1 # the one the game spawns under it
      LAST = 2 # the one the next one's pop spawns, which the game goes on with
      # The beats that are the player's turn, and the dot each waits for.
      # In every other beat the guide or the scene is showing something,
      # and a tap on the field does nothing at all.
      TURNS = { aim: BRIGHT, aim_next: NEXT }.freeze

      attr_reader :animations, :hud, :spotlight, :guide, :beat, :now, :row_notice

      # The dots the tutorial's game begins with on +field+: its first
      # bright dot, placed from +center+, the screen's middle, as +style+
      # says. The game is started paused with them (Cabinet::Starter#paused).
      def self.opening(field, center, style: Style)
        across, down = style::TUTORIAL.start
        center_x, center_y = center
        speed = Rules::SPEEDS.min * field.radius
        # It drifts away from the middle, so the next dot slides out toward it.
        Stack.new.slide_under(Dot.new(id: BRIGHT, x: center_x + (across * field.width), y: center_y + (down * field.height),
                                      velocity_x: -speed, velocity_y: speed, radius: field.radius).confine(field))
      end

      def initialize(cabinet:, effects:, sounds:, haptics:, style:, palette: style::PALETTE, now: 0.0, calm: false)
        @cabinet = cabinet
        @effects = effects
        @sounds = sounds
        @haptics = haptics
        @style = style
        @palette = palette
        @script = style::TUTORIAL
        @guide_style = calm ? @script.guide.with(wag: style::CALM_WAG) : @script.guide
        @waited_out = Float::INFINITY
        @now = now
        @since = now
        @beat = :drift
        @time = EasedValue.steady(1.0)
        @cues = []
        @flights = []
        @spotlight = Spotlight.off(@script.spotlight)
        @guide = GuideHand.none(@guide_style)
        @animations = DotAnimations.new(style::MOTION)
        @shown = [] # the ids of the game's dots it has shown born
        @bright = [] # the ids of dots the rules popped that it still draws bright
        @hud = Hud.blank(style::HUD, style::WORDS).showing(game.score, game.countdown.whole_seconds, now)
                  .counting(game.dots_in_a_row, game.bonus.dots_in_a_row, now)
        spawned(game.dots.first)
      end

      def field = game.field
      def radius = field.radius

      # Whether its last beat is over, and the game should play on from it.
      def over? = beat == :over

      # The game's dots as it draws them: only those it has shown born, and
      # a dot the rules popped as still bright until it shows it popping.
      def dots
        all = game.dots
        return @view if all.equal?(@viewed)

        @viewed = all
        @view = Stack.new(dots: all.filter_map do |dot|
          next unless @shown.include?(dot.id)

          @bright.include?(dot.id) ? dot.with(popped: false) : dot
        end)
      end

      # Skipped: it shows at once what it had yet to show of the game, each
      # dot the rules popped taking its popped look and each they spawned
      # born, so that the game, drawn as it is, plays on with nothing
      # hidden.
      def catch_up
        @bright.each { animations.pop(it, now) }
        @bright = []
        @viewed = nil
        game.dots.each { spawned(it) unless @shown.include?(it.id) }
      end

      # Where the guide is, and how it presses (GuidePose), or nil.
      def guide_pose = guide.pose(now, dots, radius)

      # Their old names, until no caller says them.
      alias ghost guide
      alias ghost_pose guide_pose

      # The numbers in the air (TravelingNumber).
      def flights = @flights.select { it.flying?(now) }

      # How fast its time flows now: 1 as in the game, 0 when it stands
      # still.
      def rate = @time.value(now)

      def update(seconds)
        before = now
        @now += seconds
        flow = (@time.value(before) + rate) / 2.0
        @cabinet.move_paused(seconds * flow) if flow.positive?
        @hud = hud.showing(hud.score, hud.seconds, now)
        @flights = @flights.reject { now - it.born >= it.duration }
        play_cues
        follow
      end

      # Whether a tap on the field counts now. It does only on the player's
      # turn; while the guide demonstrates, and while the scene plays,
      # it is not heard.
      def players_turn? = TURNS.key?(beat)

      # A tap at +x+, +y+ on the player's turn: on the dot it waits for, a
      # pop, which the game hears; on empty space, the game's whisper of a
      # ripple; on a popped dot, nothing, since the cost is shown, never
      # charged, here. At any other time, nothing at all, not even a
      # ripple. Only the pop reaches the game.
      def tap(x, y)
        target = TURNS[beat] or return

        dot = game.dots.top_at(x, y)
        if dot.nil? then @effects.ring(x, y, @style::TOUCH_RIPPLE)
        elsif dot.bright? && dot.id == target then pop_turn(dot, x, y)
        end
      end

      private

      # The paused game it plays over.
      def game = @cabinet.game

      def dot(id) = game.dots.find { it.id == id }

      # The game's +dot+ is shown born, growing in with a ripple.
      def spawned(dot)
        @shown << dot.id
        @viewed = nil
        animations.spawn(dot.id, now)
        @effects.ring(dot.x, dot.y, @style::SPAWN_RIPPLE, follow: dot.id)
      end

      def enter(beat)
        @beat = beat
        @since = now
      end

      def waited = now - @since

      # How far apart the two dots' middles are, in radii.
      def apart
        bright, following = [BRIGHT, NEXT].map { |id| dots.find { it.id == id } }
        following ? Math.hypot(bright.x - following.x, bright.y - following.y) / radius : 0.0
      end

      def follow
        case beat
        in :drift then aim_at_bright if waited >= @script.drift
        in :peek then show_the_cost if apart >= @script.peek || waited >= @script.longest
        in :slide then aim_at_next if (apart >= @script.clear && now >= @waited_out) || waited >= @script.longest
        in :ending then enter(:over) if waited >= @script.handover
        else nil
        end
      end

      # A thing to do at +at+, in order with the others.
      def cue(at, &action) = @cues << [at, action]

      def play_cues
        due, @cues = @cues.partition { |at, _| at <= now }
        due.sort_by(&:first).each { |_, action| action.call }
      end

      def stop_time = @time = @time.toward(0.0, now, @script.stop)

      # Beat 1: time stops, and the guide shows the tap.
      def aim_at_bright
        enter(:aim)
        hand_the_turn_to_the_player(BRIGHT)
      end

      # The turn passes to the player: time stops, the light finds the
      # dot, the guide goes to it, and a ripple opens from the dot itself,
      # the one thing on the field that now answers a tap.
      def hand_the_turn_to_the_player(id)
        stop_time
        @spotlight = spotlight.toward(Anchor.dot(id), now)
        @guide = guide.tapping(Anchor.dot(id), now)
        dot = dot(id)
        @effects.ring(dot.x, dot.y, @style::SPAWN_RIPPLE, follow: id)
      end

      # The player's tap on the dot the turn waits for reaches the game,
      # which pops it and spawns the next under it; the tutorial draws it
      # bright, and the new dot unborn, until it shows them so.
      def pop_turn(dot, x, y)
        popped = @cabinet.press_paused(x, y)
        return unless popped.is_a?(Events::Popped)

        @bright << dot.id
        @viewed = nil
        beat == :aim ? pop_bright(dot, x, y, popped) : pop_next(dot, x, y, popped)
      end

      # Beat 2: the pop holds time still, and its point and second fly to
      # where they count, out of the dot as it bursts, still bright.
      def pop_bright(dot, x, y, popped)
        burst(dot, x, y)
        enter(:points)
        stop_time
        @guide = guide.gone(now)
        ends = one_by_one(x, y, gains(popped), light: true)
        cue(ends + @script.hold) { resume }
      end

      # What the pop earned (Events::Popped), in turn: its points, its
      # seconds, and a dot in the row.
      def gains(popped)
        points = popped.points
        seconds = popped.seconds.to_i
        [[:score, points, @palette.cream, -> { land(points:) }],
         [:time, seconds, @palette.gain, -> { land(seconds:) }],
         [:dots_in_a_row, 1, @palette.gain, -> { count_the_pop }]]
      end

      # What the guide's mistake cost (Events::Penalized), in the same
      # turn, leaving out what was already at nothing: the score and the
      # seconds the rules took, and the row shown.
      def losses(penalty)
        return [] unless penalty.is_a?(Events::Penalized)

        alarm = @palette.alarm
        points = penalty.points
        seconds = penalty.seconds.to_i
        [[:score, points, alarm, -> { land(points:) }],
         [:time, seconds, alarm, -> { land(seconds:) }],
         [:dots_in_a_row, -hud.dots_in_a_row, alarm, -> { empty_the_row }]].reject { |_, amount, *| amount.zero? }
      end

      # Each of +steps+ flies from +x+, +y+ into its place in the HUD and
      # lands, one after another, so each is seen. With +light+, the
      # spotlight goes along. Answers when the last one lands.
      def one_by_one(x, y, steps, light: false)
        at = now + @script.gap
        steps.each do |to, amount, color, landing|
          cue(at) { @spotlight = spotlight.toward(Anchor.hud(to), now) } if light
          fly_in(x, y, to, amount, color, at, @script.flight)
          cue(at + @script.flight, &landing)
          at += @script.flight + @script.gap
        end
        at - @script.gap
      end

      # A dot joins the row, which bumps it and rings.
      def count_the_pop
        @sounds.play(:tick, pitch: 1.25)
        count_a_dot
        @row_notice = RowNotice.new(at: now, tone: :gain, duration: @script.notice)
      end

      def count_a_dot = @hud = hud.counting(hud.dots_in_a_row + 1, hud.size, now)

      # Beat 3: time flows, and the pop is seen to take effect: the dot
      # shows it is popped, and the bright dot the rules spawned under it
      # is born where it parts from it, and slides out.
      def resume
        popped, following = parting(settle(BRIGHT))
        @cabinet.arrange(popped, following)
        spawned(dot(NEXT))
        enter(:peek)
        @time = @time.toward(1.0, now, @script.resume)
        @spotlight = spotlight.toward(nil, now)
      end

      # The popped dot and the bright one born under it, a little apart,
      # as they part: across, the new one going back the way the popped
      # one came, or, where a side wall is too near for both to get clear
      # that way, as on an upright phone, down, the popped one rising.
      # Either way they part away from where the guide waits, above. The
      # rules spawned the new one at random under the popped one; the
      # tutorial puts it here, while the game is paused, to show the
      # parting the same way on every screen.
      def parting(popped)
        born = @script.born * radius
        x, y, across, down = popped.to_h.values_at(:x, :y, :velocity_x, :velocity_y)
        if room_across?(popped) then x, across = x - born, -across
        else
          popped = popped.with(velocity_y: -down.abs)
          y, down = y + born, down.abs
        end
        [popped, dot(NEXT).with(x:, y:, velocity_x: across, velocity_y: down).confine(field)]
      end

      # Whether both dots have room to get clear of each other across,
      # each going its own way, before either meets a wall.
      def room_across?(popped)
        reach = @script.clear * radius / 2.0
        ahead, behind = [field.max_x - popped.x, popped.x - field.min_x]
        ahead, behind = behind, ahead if popped.velocity_x.negative?
        ahead >= reach && behind >= reach
      end

      # ...and as it peeks out, the guide taps the popped dot over it, once,
      # and the cost plays as its press lands. As the last of it flies
      # (#guide_makes_a_mistake), the guide goes to wait to one side and wags its
      # finger, "no", and only once it has, and settled, may it go on to
      # the bright dot.
      def show_the_cost
        enter(:warn)
        stop_time
        @spotlight = spotlight.toward(Anchor.dot(BRIGHT), now)
        @guide = guide.tapping(Anchor.dot(BRIGHT), now)
        cue(now + (GuideHand::PRESSED * @guide_style.loop)) { guide_makes_a_mistake }
      end

      # Where the guide waits: well above the popped dot, the hand's middle
      # over it, so the whole hand, which hangs below its fingertip, stays
      # clear of both dots, and on screen however near an edge they are,
      # with half a radius more beside it, for its thumb as it wags.
      def waiting_place
        dot = dot(BRIGHT)
        across, down = @guide_style.hover
        side = radius / 2.0
        Anchor.at((dot.x + (across * radius)).clamp(field.min_x + side, field.max_x - side),
                  (dot.y + (down * radius)).clamp(field.min_y, field.max_y))
      end

      # The guide's press reaches the game, which charges it as in play,
      # and the game's own penalty plays: its shudder and ring, the bright
      # dot under it outlined, the edge's glow and the bonk. Then what it
      # cost flies out of the dot, to the score, the time and the row, in
      # turn, as a pop's reward does. The light stays on the dot and the
      # hand. The screen never shakes, and no buzz says the player did
      # this; and since it is the guide's, not the player's, nothing but the
      # tutorial hears of it.
      def guide_makes_a_mistake
        dot = dot(BRIGHT)
        x = dot.x
        y = dot.y
        penalty = @cabinet.press_paused(x, y)
        animations.wobble(dot.id, now)
        @effects.ring(x, y, @style::ALARM_RING, follow: dot.id)
        hidden = game.dots.bright_beneath(dot, x, y)
        @effects.reveal(hidden, @style::REVEAL) if hidden
        @effects.light(@style::PENALTY_FLASH)
        @sounds.play(:bonk, pan: pan(x))
        ends = one_by_one(x, y, losses(penalty))
        goes = ends - @script.flight
        cue(goes) { @guide = guide.hovering(waiting_place, now) }
        @waited_out = goes + @guide_style.glide + @guide_style.waiting
        cue(ends) { let_it_slide }
      end

      def let_it_slide
        enter(:slide)
        @time = @time.toward(@script.slow, now, @script.resume)
        @spotlight = spotlight.toward(Anchor.dot(NEXT), now)
      end

      def aim_at_next
        enter(:aim_next)
        hand_the_turn_to_the_player(NEXT)
      end

      # Beat 4: the pop bursts, still bright, and its numbers fly in.
      def pop_next(dot, x, y, popped)
        burst(dot, x, y)
        enter(:runs)
        stop_time
        @guide = guide.gone(now)
        flying = now + @script.gap
        cue(flying) { @spotlight = spotlight.toward(nil, now) }
        gains(popped).each { |to, amount, color, _| fly_in(x, y, to, amount, color, flying, @script.quick) }
        landing = flying + @script.quick
        cue(landing) do
          land(points: popped.points, seconds: popped.seconds.to_i)
          count_a_dot
        end
        cue(landing + @script.linger) { hand_over }
      end

      # The light moves to the clock, and time flows again, so the pop is
      # seen to take effect: the dot shows it is popped, and the bright dot
      # the rules spawned under every dot at the pop is born. The game
      # plays on from here.
      def hand_over
        settle(NEXT)
        spawned(dot(LAST))
        enter(:ending)
        @time = @time.toward(1.0, now, @script.handover)
        @spotlight = spotlight.toward(Anchor.hud(:time), now)
      end

      # A pop's burst, its shockwave, its sound and its buzz, at the
      # instant of the tap, over the dot still bright; time stops there, and
      # the dot takes its popped look as it flows again (#settle).
      def burst(dot, x, y)
        @effects.burst(x, y, @style::POP_BURST, @palette.confetti)
        @effects.ring(dot.x, dot.y, @style::SHOCKWAVE, follow: dot.id)
        @sounds.play(:pop, pitch: 1.0 + (hud.score * @style::SOUND.pop_climb), pan: pan(x))
        @haptics.buzz(@style::HAPTICS.pop)
      end

      # The dot +id+, which the rules popped at the stopped instant of its
      # burst, now drawn popped, with its squash and its change to the
      # popped look.
      def settle(id)
        @bright.delete(id)
        @viewed = nil
        animations.pop(id, now)
        dot(id)
      end

      # The mistake's cost reaches the row, which starts over and rings.
      def empty_the_row
        return unless hud.dots_in_a_row.positive?

        @hud = hud.counting(0, hud.size, now)
        @row_notice = RowNotice.new(at: now, tone: :alarm, duration: @script.notice)
      end

      # A number flying from where the dot was tapped into the HUD's score,
      # time or row (+to+), as +amount+, with what it counts drawn after it.
      def fly_in(x, y, to, amount, color, born, duration)
        @flights << TravelingNumber.new(text: Words.points(amount), icon: { time: :stopwatch, dots_in_a_row: :dot }[to], color:,
                               from: Anchor.at(x, y), to: Anchor.hud(to), born:, duration:)
      end

      # Numbers landing in the HUD, which counts them, with a chime for a
      # point gained and a tick for a second.
      def land(points: 0, seconds: 0)
        @hud = hud.showing(hud.score + points, hud.seconds + seconds, now)
        @sounds.play(:tick, pitch: 1.5) if points.positive?
        @sounds.play(:tick, pitch: 1.0) if seconds.positive?
      end

      def pan(x) = @style::SOUND.stereo.pan(x, field.width)
    end
  end
end
