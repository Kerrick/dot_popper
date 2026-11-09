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
    # guide taps the popped dot and lifts away, +warn+ in all, and stops
    # again once it is +clear+ of the first. A pop's numbers wait +gap+
    # and fly into the HUD in +flight+, or +quick+ on the last pop; time
    # holds +hold+ after they land. The last pop's numbers +linger+, and
    # then the spotlight moves to the clock as time flows again, in
    # +handover+, and the game goes on from there. A beat that waits for
    # the dots to move never waits more than +longest+, should they
    # bounce. +spotlight+, +ghost+ and +lead+ are the spotlight's look,
    # the guide's, and the lead-in's. +notice+ is how long the row of dots
    # in a row rings when it changes.
    class TutorialStyle < Data.define(:drift, :stop, :resume, :slow, :start, :born, :peek, :clear, :warn, :flight,
                                     :quick, :gap, :hold, :linger, :handover, :longest, :spotlight, :ghost, :lead,
                                     :notice); end

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
    class LeadStyle < Data.define(:dim, :halo, :fade); end

    # The Tutorial's last beat, in the real game's first moments, since
    # +at+: the spotlight on the clock as it starts to run, fading, and a
    # halo around it a little longer. Only the clock is lit; the game's
    # own dots are never covered for more than a moment.
    class LeadIn < Data.define(:at, :style)
      def strength(now) = (1 - ((now - at) / style.dim)).clamp(0.0, 1.0)
      def halo(now) = (1 - ((now - at - style.halo) / style.fade)).clamp(0.0, 1.0)
      def over?(now) = now - at >= style.halo + style.fade
    end

    # The tutorial a player sees on their first Play: the first game's
    # opening, while its clock is not yet running. It has the rules' own
    # dots, their real drawing and the slowest real speed, and the real
    # HUD. The game stays on its title until it ends; then the game goes
    # on from exactly where it left its dots, its score and its time
    # (Cabinet#resume), and only the clock starts. It teaches without a word,
    # in four beats, and each tap that moves it on is the player's:
    #
    # 1. A bright dot drifts, time eases to a stop, a spotlight finds it,
    #    and the guide, the player's own hand or pointer drawn faintly
    #    (GhostHand), taps it, over and over, until the player does.
    # 2. Its pop bursts from the dot while it still looks bright, and
    #    holds time still at that instant while "+1" flies out of it into
    #    the HUD's score, and a stopwatch into its time, each ticking up as
    #    it lands. Only as time flows again does it take its popped look
    #    (#settle), so the reward is seen to come from the bright dot. As
    #    the stopwatch lands, the light moves on to the HUD's row of dots
    #    in a row, the game's own, which lights its first and rings.
    # 3. A new bright dot is born under the popped one, as time flows
    #    again: in play it would be born at the pop, which the stopped
    #    clock has held at that instant until now. As it peeks out,
    #    time stops again, and the guide taps the popped dot, once: the
    #    game's own penalty plays, its shudder, the dashed outline of the
    #    bright dot under it, and its cost out of the score and the time,
    #    which drop as it does; the row goes dark and rings red. The guide then waits to one side while time
    #    flows slowly until the bright dot is clear, and moves to it and
    #    taps. All that while the guide is showing, and a tap does nothing.
    #    Only then is it the player's turn again, as it was at the
    #    first tap, and a tap of theirs on the popped dot costs the same.
    # 4. Its pop bursts, still bright, and its numbers fly in; as the
    #    spotlight moves to the clock and time flows again, it takes its
    #    popped look and spawns the next bright dot under them all, as a
    #    pop in play does (#over?). The Show then hands the scene
    #    to the game, whose LeadIn lets the clock run.
    #
    # Every wrong tap here, the guide's too, costs what it does in play
    # (Rules): two points, never below zero, and two seconds, the clock
    # never below zero either. The clock is still, so it can never run
    # out, but the numbers it carries into the game are the true ones,
    # the row among them. What a full row brings is left for the game to
    # surprise the player with: nothing here shows it or says so.
    #
    # It plays its pops, cost, and chimes through the Show's +effects+,
    # +sounds+, and +haptics+, on a +field+ like a game's, from +center+,
    # the screen's middle, as +style+ (Style) says, on the Show's clock from
    # +now+. Its last dot is drawn from +random+, as a game's are.
    class Tutorial
      BRIGHT = 0 # the first bright dot's id
      NEXT = 1 # the one born under it
      LAST = 2 # the one the next one's pop spawns, which the game goes on with
      # The beats that are the player's turn, and the dot each waits for.
      # In every other beat the guide or the scene is showing something,
      # and a tap on the field does nothing at all.
      TURNS = { aim: BRIGHT, aim_next: NEXT }.freeze

      attr_reader :field, :dots, :animations, :hud, :spotlight, :ghost, :beat, :now, :row_notice

      def initialize(field:, center:, effects:, sounds:, haptics:, style:, palette: style::PALETTE, now: 0.0, random: Random.new, calm: false)
        @field = field
        @effects = effects
        @sounds = sounds
        @haptics = haptics
        @style = style
        @palette = palette
        @random = random
        @script = style::TUTORIAL
        @guide = calm ? @script.ghost.with(wag: style::CALM_WAG) : @script.ghost
        @waited_out = Float::INFINITY
        @now = now
        @since = now
        @beat = :drift
        @time = Level.steady(1.0)
        @cues = []
        @flights = []
        @spotlight = Spotlight.off(@script.spotlight)
        @ghost = GhostHand.none(@guide)
        @hud = Hud.blank(style::HUD, style::WORDS).showing(Rules::LOWEST_SCORE, Rules::STARTING_SECONDS.to_i, now)
                  .counting(0, Rules::BONUS.dots_in_a_row, now)
        @animations = DotAnimations.new(style::MOTION)
        @dots = Stack.new.slide_under(first_dot(*center))
        spawned(dots.first)
      end

      def radius = field.radius

      # Whether its last beat is over, and the game should go on from it.
      def over? = beat == :over

      # The score, the whole seconds and the dots in a row it leaves the
      # game, as its HUD shows them.
      def score = hud.score
      def seconds = hud.seconds
      def dots_in_a_row = hud.dots_in_a_row

      # Where the guide is, and how it presses (GhostPose), or nil.
      def ghost_pose = ghost.pose(now, dots, radius)

      # The numbers in the air (Flight).
      def flights = @flights.select { it.flying?(now) }

      # How fast its time flows now: 1 as in the game, 0 when it stands
      # still.
      def rate = @time.value(now)

      def update(seconds)
        before = now
        @now += seconds
        flow = (@time.value(before) + rate) / 2.0
        @dots = dots.map_dots { it.move(seconds * flow, field) } if flow.positive?
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
      # pop; on a popped dot, its cost; on empty space, the game's whisper of
      # a ripple. At any other time, nothing, not even a ripple.
      def tap(x, y)
        target = TURNS[beat] or return

        dot = dots.top_at(x, y)
        if dot.nil? then @effects.ring(x, y, @style::TOUCH_RIPPLE)
        elsif dot.popped? then mistake(dot, x, y)
        elsif dot.id == target then pop_turn(dot, x, y)
        end
      end

      # The window changed size: every dot stays where it was in
      # proportion, as a game's do, on +field+.
      def refit(field)
        old = @field
        @field = field
        @dots = dots.map_dots { it.refit(old, field) }
      end

      private

      def first_dot(center_x, center_y)
        across, down = @script.start
        speed = Rules::SPEEDS.min * radius
        # It drifts away from the middle, so the next dot slides out toward it.
        Dot.new(id: BRIGHT, x: center_x + (across * field.width), y: center_y + (down * field.height),
                velocity_x: -speed, velocity_y: speed, radius:).confine(field)
      end

      def spawned(dot)
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
        in :warn then let_it_slide if waited >= @script.warn
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
        @ghost = ghost.tapping(Anchor.dot(id), now)
        dot = dots.find { it.id == id }
        @effects.ring(dot.x, dot.y, @style::SPAWN_RIPPLE, follow: id)
      end

      def pop_turn(dot, x, y) = beat == :aim ? pop_bright(dot, x, y) : pop_next(dot, x, y)

      # Beat 2: the pop holds time still, and its point and second fly to
      # where they count, out of the dot as it bursts, still bright.
      def pop_bright(dot, x, y)
        burst(dot, x, y)
        enter(:points)
        stop_time
        @ghost = ghost.gone(now)
        points = now + @script.gap
        seconds = points + @script.flight + @script.gap
        cue(points) { @spotlight = spotlight.toward(Anchor.hud(:score), now) } # the light leaves with the point
        fly_in(x, y, :score, points, @script.flight)
        fly_in(x, y, :time, seconds, @script.flight)
        cue(points + @script.flight) { land(points: 1) }
        cue(seconds) { @spotlight = spotlight.toward(Anchor.hud(:time), now) }
        cue(seconds + @script.flight) { second_and_row_land }
        cue(seconds + @script.flight + @script.hold) { resume }
      end

      # The second lands, and the light goes on to the row, which counts
      # the pop and rings, all inside the beat's hold.
      def second_and_row_land
        land(seconds: 1)
        count_the_pop
        @row_notice = RowNotice.new(at: now, tone: :gain, duration: @script.notice)
        @spotlight = spotlight.toward(Anchor.hud(:dots_in_a_row), now)
      end

      def count_the_pop = @hud = hud.counting(hud.dots_in_a_row + 1, hud.size, now)

      # Beat 3: time flows, and the pop takes effect: the dot shows it is
      # popped, and a new bright dot is born under it, as in play, and
      # slides out.
      def resume
        popped, following = parting(settle(BRIGHT))
        @dots = dots.replace(popped).slide_under(following)
        spawned(following)
        enter(:peek)
        @time = @time.toward(1.0, now, @script.resume)
        @spotlight = spotlight.toward(nil, now)
      end

      # The popped dot and the bright one born under it, a little apart,
      # as they part: across, the new one going back the way the popped
      # one came, or, where a side wall is too near for both to get clear
      # that way, as on an upright phone, down, the popped one rising.
      # Either way they part away from where the guide waits, above.
      def parting(popped)
        born = @script.born * radius
        x, y, across, down = popped.to_h.values_at(:x, :y, :velocity_x, :velocity_y)
        if room_across?(popped) then x, across = x - born, -across
        else
          popped = popped.with(velocity_y: -down.abs)
          y, down = y + born, down.abs
        end
        [popped, Dot.new(id: NEXT, x:, y:, velocity_x: across, velocity_y: down, radius:).confine(field)]
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
      # and the cost plays as its press lands, before the player's turn.
      # Then it lifts, waits to one side and wags its finger, "no", and
      # only once it has, and settled, may it go on to the bright dot.
      def show_the_cost
        enter(:warn)
        stop_time
        @spotlight = spotlight.toward(Anchor.dot(BRIGHT), now)
        @ghost = ghost.tapping(Anchor.dot(BRIGHT), now)
        lifted = now + (GhostHand::LIFTED * @guide.loop)
        cue(now + (GhostHand::PRESSED * @guide.loop)) { guide_slips }
        cue(lifted) { @ghost = ghost.hovering(waiting_place, now) }
        @waited_out = lifted + @guide.glide + @guide.waiting
      end

      # Where the guide waits: well above the popped dot, the hand's middle
      # over it, so the whole hand, which hangs below its fingertip, stays
      # clear of both dots, and on screen however near an edge they are,
      # with half a radius more beside it, for its thumb as it wags.
      def waiting_place
        dot = dots.find { it.id == BRIGHT }
        across, down = @guide.hover
        side = radius / 2.0
        Anchor.at((dot.x + (across * radius)).clamp(field.min_x + side, field.max_x - side),
                  (dot.y + (down * radius)).clamp(field.min_y, field.max_y))
      end

      def guide_slips
        dot = dots.find { it.id == BRIGHT }
        mistake(dot, dot.x, dot.y, guide: true)
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
      def pop_next(dot, x, y)
        burst(dot, x, y)
        enter(:runs)
        stop_time
        @ghost = ghost.gone(now)
        flying = now + @script.gap
        cue(flying) { @spotlight = spotlight.toward(nil, now) }
        fly_in(x, y, :score, flying, @script.quick)
        fly_in(x, y, :time, flying, @script.quick)
        landing = flying + @script.quick
        cue(landing) do
          land(points: 1, seconds: 1)
          count_the_pop
        end
        cue(landing + @script.linger) { hand_over }
      end

      # The light moves to the clock, and time flows again, so the pop
      # takes effect: the dot shows it is popped, and spawns the next
      # bright dot under every dot, as a pop in play does. The game goes
      # on from here.
      def hand_over
        settle(NEXT)
        last = Spawner.for(field).spawn(@random, id: LAST, above: dots.to_a).dot
        @dots = dots.slide_under(last)
        spawned(last)
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

      # The dot +id+ popped, as the burst at the stopped instant said it
      # was, with its squash and its change to the popped look.
      def settle(id)
        popped = dots.find { it.id == id }.pop
        @dots = dots.replace(popped)
        animations.pop(id, now)
        popped
      end

      # A tap on a popped dot, the player's or the guide's: the game's own
      # penalty, its shudder and ring, the bright dot under it outlined,
      # the edge's glow and the bonk, and "−2" out of the score and the
      # time, which drop by it as it leaps out (#penalize). The screen never
      # shakes. Only the player's own tap buzzes, since a buzz in the hand
      # says "you did that".
      def mistake(dot, x, y, guide: false)
        animations.wobble(dot.id, now)
        @effects.ring(dot.x, dot.y, @style::ALARM_RING, follow: dot.id)
        hidden = dots.fresh_beneath(dot, x, y)
        @effects.reveal(hidden, @style::REVEAL) if hidden
        @effects.light(@style::PENALTY_FLASH)
        penalize
        empty_the_row
        @sounds.play(:bonk, pan: pan(x))
        @haptics.buzz(@style::HAPTICS.penalty) unless guide
      end

      # A mistake starts the row over, and it rings if that cost it anything.
      def empty_the_row
        return unless hud.dots_in_a_row.positive?

        @hud = hud.counting(0, hud.size, now)
        @row_notice = RowNotice.new(at: now, tone: :alarm, duration: @script.notice)
      end

      # A pop's point (+to+ :score) or second (:time), flying from where
      # the dot was tapped into the HUD.
      def fly_in(x, y, to, born, duration)
        palette = @palette
        score = to == :score
        @flights << Flight.new(text: Words.points(score ? Rules::POP_POINTS : Rules::POP_SECONDS),
                               icon: (:stopwatch unless score), color: score ? palette.cream : palette.gain,
                               from: Anchor.at(x, y), to: Anchor.hud(to), born:, duration:)
      end

      # A wrong tap's cost, as Game#penalize takes it: two points, but
      # never below the lowest score, and two seconds, but never below
      # zero. The HUD drops by it at once, and what it lost leaps out of
      # the score and the time; as in play, a floor that kept a number
      # from falling says only what was lost, and nothing when nothing was.
      def penalize
        points = [Rules::PENALTY_POINTS, hud.score - Rules::LOWEST_SCORE].min
        seconds = [Rules::PENALTY_SECONDS.to_i, hud.seconds].min
        @hud = hud.showing(hud.score - points, hud.seconds - seconds, now)
        fly_out(:score, points) if points.positive?
        fly_out(:time, seconds) if seconds.positive?
      end

      # +lost+ points or seconds, leaping out of the HUD's score or time
      # (+from+).
      def fly_out(from, lost)
        score = from == :score
        @flights << Flight.new(text: Words.points(-lost), icon: (:stopwatch unless score), color: @palette.alarm,
                               from: Anchor.hud(from), to: Anchor.hud(from, below: 3.0), born: now,
                               duration: @style::LOSS_FLOAT.life)
      end

      # A pop's numbers landing in the HUD, which counts them up, with a
      # chime for the point and a tick for the second.
      def land(points: 0, seconds: 0)
        @hud = hud.showing(hud.score + points, hud.seconds + seconds, now)
        @sounds.play(:tick, pitch: 1.5) if points.positive?
        @sounds.play(:tick, pitch: 1.0) if seconds.positive?
      end

      def pan(x) = @style::SOUND.stereo.pan(x, field.width)
    end
  end
end
