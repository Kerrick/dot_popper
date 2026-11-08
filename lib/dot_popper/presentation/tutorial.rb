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
    # guide taps the popped dot and then waits, +warn+ in all, and stops
    # again once it is +clear+ of the first. A pop's numbers wait +gap+
    # and fly into the HUD in +flight+, or +quick+ on the last pop; time
    # holds +hold+ after they land. The last pop's numbers +linger+, and
    # then the spotlight moves to the clock as time flows again, in
    # +handover+, and the round goes on from there. A beat that waits for
    # the dots to move never waits more than +longest+, should they
    # bounce. +spotlight+, +ghost+ and +lead+ are the spotlight's look,
    # the guide's, and the lead-in's.
    class TutorialLook < Data.define(:drift, :stop, :resume, :slow, :start, :born, :peek, :clear, :warn, :flight,
                                     :quick, :gap, :hold, :linger, :handover, :longest, :spotlight, :ghost, :lead); end

    # How the Tutorial's last beat goes on into the real round: its
    # spotlight on the clock fades out in +dim+ seconds, and a halo stays
    # around the clock for +halo+, then fades in +fade+.
    class LeadLook < Data.define(:dim, :halo, :fade); end

    # The Tutorial's last beat, in the real round's first moments, since
    # +at+: the spotlight on the clock as it starts to run, fading, and a
    # halo around it a little longer. Only the clock is lit; the round's
    # own dots are never covered for more than a moment.
    class LeadIn < Data.define(:at, :look)
      def strength(now) = (1 - ((now - at) / look.dim)).clamp(0.0, 1.0)
      def halo(now) = (1 - ((now - at - look.halo) / look.fade)).clamp(0.0, 1.0)
      def over?(now) = now - at >= look.halo + look.fade
    end

    # The tutorial a player sees on their first Play: the first round's
    # opening, while its clock is not yet running. It has the rules' own
    # dots, their real drawing and the slowest real speed, and the real
    # HUD. The game stays on its title until it ends; then the round goes
    # on from exactly where it left its dots, its score and its time
    # (Game#resume), and only the clock starts. It teaches without a word,
    # in four beats, and each tap that moves it on is the player's:
    #
    # 1. A bright dot drifts, time eases to a stop, a spotlight finds it,
    #    and the guide, the player's own hand or pointer drawn faintly
    #    (GhostHand), taps it, over and over, until the player does.
    # 2. Its pop holds time still while "+1" flies into the HUD's score,
    #    and a stopwatch into its time, each ticking up as it lands.
    # 3. A new bright dot is born under the popped one. As it peeks out,
    #    time stops again, and the guide taps the popped dot, once: the
    #    game's own penalty plays, its shudder, the dashed outline of the
    #    bright dot under it, and its cost out of the score and the time,
    #    which drop as it does. The guide then waits to one side while time
    #    flows slowly until the bright dot is clear, and moves to it and
    #    taps. A tap of the player's on the popped dot costs the same, and
    #    the beat goes on.
    # 4. Its pop spawns the next bright dot under them all, as a pop in
    #    play does, its numbers fly in, and the spotlight moves to the
    #    clock as time flows again (#over?). The Show then hands the scene
    #    to the round, whose LeadIn lets the clock run.
    #
    # Every wrong tap here, the guide's too, costs what it does in play
    # (Rules): two points, never below zero, and two seconds, the clock
    # never below zero either. The clock is still, so it can never run
    # out, but the numbers it carries into the round are the true ones.
    #
    # It plays its pops, cost, and chimes through the Show's +effects+,
    # +sounds+, and +haptics+, on a +field+ like a round's, from +center+,
    # the screen's middle, as +look+ (Look) says, on the Show's clock from
    # +now+. Its last dot is drawn from +random+, as a round's are.
    class Tutorial
      BRIGHT = 0 # the first bright dot's id
      NEXT = 1 # the one born under it
      LAST = 2 # the one the next one's pop spawns, which the round goes on with
      SLIDING = %i[peek warn slide aim_next].freeze # the beats the next dot may be popped in
      DONE = %i[runs ending over].freeze # the beats no tap changes

      attr_reader :field, :dots, :animations, :hud, :spotlight, :ghost, :beat, :now

      def initialize(field:, center:, effects:, sounds:, haptics:, look:, now: 0.0, random: Random.new)
        @field = field
        @effects = effects
        @sounds = sounds
        @haptics = haptics
        @look = look
        @random = random
        @script = look::TUTORIAL
        @now = now
        @since = now
        @beat = :drift
        @time = Level.steady(1.0)
        @cues = []
        @flights = []
        @spotlight = Spotlight.off(@script.spotlight)
        @ghost = GhostHand.none(@script.ghost)
        @hud = Hud.blank(look::HUD, look::WORDS).showing(Rules::LOWEST_SCORE, Rules::STARTING_SECONDS.to_i, now)
        @animations = DotAnimations.new(look::MOTION)
        @dots = Stack.new.slide_under(first_dot(*center))
        spawned(dots.first)
      end

      def radius = field.radius

      # Whether its last beat is over, and the round should go on from it.
      def over? = beat == :over

      # The score and the whole seconds it leaves the round, as its HUD
      # shows them.
      def score = hud.score
      def seconds = hud.seconds

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

      # A tap at +x+, +y+: on the bright dot, a pop; on a popped dot, its
      # cost; on empty space, the game's whisper of a ripple. A
      # bright dot is popped only once the scene has shown it; the next
      # one waits for beat 3.
      def tap(x, y)
        return if DONE.include?(beat)

        dot = dots.top_at(x, y)
        if dot.nil? then @effects.ring(x, y, @look::TOUCH_RIPPLE)
        elsif dot.popped? then slip(dot, x, y)
        elsif dot.id == BRIGHT then pop_bright(dot, x, y)
        elsif SLIDING.include?(beat) then pop_next(dot, x, y)
        end
      end

      # The window changed size: every dot stays where it was in
      # proportion, as a round's do, on +field+.
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
        @effects.ring(dot.x, dot.y, @look::SPAWN_RIPPLE, follow: dot.id)
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
        in :slide then aim_at_next if apart >= @script.clear || waited >= @script.longest
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
        stop_time
        @spotlight = spotlight.toward(Anchor.dot(BRIGHT), now)
        @ghost = ghost.tapping(Anchor.dot(BRIGHT), now)
      end

      # Beat 2: the pop holds time still, and its point and second fly to
      # where they count. A new bright dot is born under it, as in play.
      def pop_bright(dot, x, y)
        popped = pop(dot, x, y)
        following = Dot.new(id: NEXT, x: popped.x - (@script.born * radius), y: popped.y,
                            velocity_x: -popped.velocity_x, velocity_y: popped.velocity_y, radius:).confine(field)
        @dots = dots.slide_under(following)
        spawned(following)
        enter(:points)
        stop_time
        @ghost = ghost.gone(now)
        @spotlight = spotlight.toward(Anchor.hud(:score), now)
        points = now + @script.gap
        seconds = points + @script.flight + @script.gap
        fly_in(x, y, :score, points, @script.flight)
        fly_in(x, y, :time, seconds, @script.flight)
        cue(points + @script.flight) { land(points: 1) }
        cue(seconds) { @spotlight = spotlight.toward(Anchor.hud(:time), now) }
        cue(seconds + @script.flight) { land(seconds: 1) }
        cue(seconds + @script.flight + @script.hold) { resume }
      end

      # Beat 3: time flows, and the new dot slides out.
      def resume
        enter(:peek)
        @time = @time.toward(1.0, now, @script.resume)
        @spotlight = spotlight.toward(nil, now)
      end

      # ...and as it peeks out, the guide taps the popped dot over it, once,
      # and the cost plays as its press lands, before the player's turn.
      # Then it lifts, and waits to one side.
      def show_the_cost
        enter(:warn)
        stop_time
        @spotlight = spotlight.toward(Anchor.dot(BRIGHT), now)
        @ghost = ghost.tapping(Anchor.dot(BRIGHT), now)
        loop = @script.ghost.loop
        cue(now + (GhostHand::PRESSED * loop)) { guide_slips }
        cue(now + (GhostHand::LIFTED * loop)) { @ghost = ghost.hovering(waiting_place, now) }
      end

      # Where the guide waits: well above and a little left of the popped
      # dot, so the whole hand, which reaches down and to the right, stays
      # clear of both dots, and on screen however near an edge they are.
      def waiting_place
        dot = dots.find { it.id == BRIGHT }
        across, down = @script.ghost.hover
        Anchor.at((dot.x + (across * radius)).clamp(field.min_x, field.max_x),
                  (dot.y + (down * radius)).clamp(field.min_y, field.max_y))
      end

      def guide_slips
        dot = dots.find { it.id == BRIGHT }
        slip(dot, dot.x, dot.y, guide: true)
      end

      def let_it_slide
        enter(:slide)
        @time = @time.toward(@script.slow, now, @script.resume)
        @spotlight = spotlight.toward(Anchor.dot(NEXT), now)
      end

      def aim_at_next
        enter(:aim_next)
        stop_time
        @spotlight = spotlight.toward(Anchor.dot(NEXT), now)
        @ghost = ghost.tapping(Anchor.dot(NEXT), now)
      end

      # Beat 4: the pop spawns the next bright dot under every dot, as a
      # pop in play does, and its numbers fly in.
      def pop_next(dot, x, y)
        @cues.clear # the guide's tap on the popped dot, should it not have landed
        pop(dot, x, y)
        last = Spawner.for(field).spawn(@random, id: LAST, above: dots.to_a).dot
        @dots = dots.slide_under(last)
        spawned(last)
        enter(:runs)
        stop_time
        @ghost = ghost.gone(now)
        @spotlight = spotlight.toward(nil, now)
        flying = now + @script.gap
        fly_in(x, y, :score, flying, @script.quick)
        fly_in(x, y, :time, flying, @script.quick)
        landing = flying + @script.quick
        cue(landing) { land(points: 1, seconds: 1) }
        cue(landing + @script.linger) { hand_over }
      end

      # The light moves to the clock, and time flows again: the round goes
      # on from here.
      def hand_over
        enter(:ending)
        @time = @time.toward(1.0, now, @script.handover)
        @spotlight = spotlight.toward(Anchor.hud(:time), now)
      end

      def pop(dot, x, y)
        popped = dot.pop
        @dots = dots.replace(popped)
        animations.pop(dot.id, now)
        @effects.burst(x, y, @look::POP_BURST, @look::PALETTE.confetti)
        @effects.ring(dot.x, dot.y, @look::SHOCKWAVE, follow: dot.id)
        @sounds.play(:pop, pitch: 1.0 + (hud.score * @look::SOUND.pop_climb), pan: pan(x))
        @haptics.buzz(@look::HAPTICS.pop)
        popped
      end

      # A tap on a popped dot, the player's or the guide's: the game's own
      # penalty, its shudder and ring, the bright dot under it outlined,
      # the edge's glow and the bonk, and "−2" out of the score and the
      # time, which drop by it as it leaps out (#penalize). The screen never
      # shakes. Only the player's own tap buzzes, since a buzz in the hand
      # says "you did that".
      def slip(dot, x, y, guide: false)
        animations.wobble(dot.id, now)
        @effects.ring(dot.x, dot.y, @look::ALARM_RING, follow: dot.id)
        hidden = dots.fresh_beneath(dot, x, y)
        @effects.reveal(hidden, @look::REVEAL) if hidden
        @effects.light(@look::PENALTY_FLASH)
        penalize
        @sounds.play(:bonk, pan: pan(x))
        @haptics.buzz(@look::HAPTICS.penalty) unless guide
      end

      # A pop's point (+to+ :score) or second (:time), flying from where
      # the dot was tapped into the HUD.
      def fly_in(x, y, to, born, duration)
        palette = @look::PALETTE
        score = to == :score
        @flights << Flight.new(text: Words.points(score ? Rules::POP_POINTS : Rules::POP_SECONDS),
                               icon: (:stopwatch unless score), color: score ? palette.cream : palette.gain,
                               from: Anchor.at(x, y), to: Anchor.hud(to), born:, duration:)
      end

      # A wrong tap's cost, as Round#penalize takes it: two points, but
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
        @flights << Flight.new(text: Words.points(-lost), icon: (:stopwatch unless score), color: @look::PALETTE.alarm,
                               from: Anchor.hud(from), to: Anchor.hud(from, below: 1.6), born: now,
                               duration: @look::LOSS_FLOAT.life)
      end

      # A pop's numbers landing in the HUD, which counts them up, with a
      # chime for the point and a tick for the second.
      def land(points: 0, seconds: 0)
        @hud = hud.showing(hud.score + points, hud.seconds + seconds, now)
        @sounds.play(:tick, pitch: 1.5) if points.positive?
        @sounds.play(:tick, pitch: 1.0) if seconds.positive?
      end

      def pan(x) = @look::SOUND.stereo.pan(x, field.width)
    end
  end
end
