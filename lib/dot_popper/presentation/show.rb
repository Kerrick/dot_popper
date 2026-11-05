# frozen_string_literal: true

module DotPopper
  module Presentation
    # Everything the player sees and hears that is not a rule. The Show
    # listens to the rules' events and cues the effects, the dots'
    # animations, the HUD, and the sounds; it hands every tap straight to
    # the game on the frame it happens, and keeps the time that all its
    # animations play against. A renderer draws from it; it draws nothing
    # itself.
    #
    # +sounds+ answers play(name, pitch:, pan:), muted?, and toggle_mute;
    # +haptics+ answers buzz(seconds). +lifetime+ (Lifetime) adds up every
    # round the device has played. +sizing_store+ keeps the player's
    # DotSizing, chosen on the title. +radius+ is the usual dot's, which
    # sizes the buttons' reach; a round's effects follow its own dots.
    # +input+ (InputKind) is what the player last pressed with, and the
    # words follow it. +keeper+ (RecordKeeper) clears the records, from
    # the Records screen, and puts them back. +measure+ sizes the screens' words (RoughMeasure's
    # methods), and +hint+ gives Game Over's line on playing with the
    # pile, or nil.
    class Show
      # The dot-size choices in the order the title draws their segments.
      SIZINGS = [DotSizing::STANDARD, DotSizing::SIZED_TO_SCREEN].freeze

      attr_reader :game, :effects, :animations, :hud, :attract, :layout, :marquee, :finale, :sounds, :now, :look,
                  :lifetime, :input, :words, :clearing

      def initialize(game:, layout:, sounds:, radius:, look: Look, random: Random.new, calm: false,
                     tutor: Tutor.new(BestScore::Memory.new, times: look::LESSON.times), haptics: NoHaptics.new, clipboard: MemoryClipboard.new,
                     lifetime: Lifetime.new(BestScore::Memory.new), sizing_store: BestScore::Memory.new,
                     input: InputKind::MOUSE, measure: RoughMeasure.new, hint: -> {},
                     keeper: RecordKeeper.new(best: game.best, lifetime:))
        @game = game
        @measure = measure
        @hint = hint
        @lifetime = lifetime
        @layout = layout
        @sounds = sounds
        @haptics = haptics
        @radius = radius
        @scale = radius
        @sizing_store = sizing_store
        @look = look
        @input = input
        @words = look::WORDS.for(input)
        @random = random
        @effects = Effects.new(radius:, random:, calm:)
        @animations = DotAnimations.new(look::MOTION)
        @hud = Hud.blank(look::HUD, words)
        @attract = Attract.spawn(game.field, look::TITLE)
        @now = 0.0
        @marquee = Marquee.new(look: look::TITLE, best: game.best.of(game.size_class), at: @now)
        @finale = nil
        @tutor = tutor
        @clipboard = clipboard
        @hid_fresh = false
        @penalized_at = -Float::INFINITY
        @recorder = RoundStats::Recorder.new
        @records = nil
        @keeper = keeper
        @clearing = HoldToConfirm.idle(look::RECORDS_CLEAR.hold)
        @undo = nil
        game.subscribe(@recorder)
        game.subscribe(self)
      end

      # The numbers of the round in play, or of the one just finished.
      def stats = @recorder.stats

      def palette = look::PALETTE

      # The player pressed with +kind+ (InputKind): from now on the words
      # say what to do with it, the lesson on Game Over too.
      def input=(kind)
        return if kind == input

        @input = kind
        @words = look::WORDS.for(kind)
        @finale = finale.with(lesson: words.covered) if finale&.lesson
      end

      def title? = game.state.is_a?(Game::Title)

      # Whether the Records screen is open over the title. It is the
      # presentation's alone: the game stays on its title meanwhile, and
      # no tap there reaches the game.
      def records? = !@records.nil?

      # What the Records screen shows, while it is open.
      def records = @records

      # Whether the title offers "Your records" and the choice of dot size:
      # only once a round has finished, so a first-time player's title says
      # only how to play. A player who cleared their records has played, so
      # it still offers them, though it shows no best or goal until their
      # next round (#played?).
      def records_offered? = played? || @keeper.cleared?

      # Whether a round has finished since the records were last cleared:
      # the title shows today's goal only then.
      def played? = lifetime.stats.rounds.positive?

      # Whether the Records screen offers "Clear my records…": while it has
      # records to clear, and no Undo is offered.
      def clear_offered? = records? && !records.empty && !undo_offer

      # Undo, while it is offered on the Records screen (UndoOffer), or nil.
      def undo_offer = (@undo if records?)

      # What the choice of dot size would do on this screen, worked out
      # afresh each time, so a resized window is always seen as it is now.
      def sizing_preview = SizingPreview.of(game.screen, look::SIZING)

      # Whether the title offers the choice of dot size: once a round has
      # finished, and only where the two sizes look different. Where they
      # look alike, the saved choice stays as it was, and rounds follow it.
      def sizing_offered? = records_offered? && sizing_preview.offered?
      def playing? = game.state.is_a?(Game::Playing)
      def finished? = game.state.is_a?(Game::GameOver)

      # A tap anywhere, by +by+ (a finger's id, :mouse, or :gamepad), which
      # #let_go names when it lets go. On the title, the mute button, "Your
      # records", and the dot-size choice take their own taps, as "Copy my
      # result" does on Game Over. On the Records screen, a press on "Clear
      # my records…" starts holding it, and one on Undo undoes, and a tap
      # anywhere else goes back. Every other tap goes to the game at once.
      # A tap on one of the title's fresh dots also pops it, as the round
      # starts.
      def tap(x, y, by: :tap)
        if records? then records_tap(x, y, by)
        elsif title? && layout.mute_button.contains?(x, y) then sounds.toggle_mute
        elsif title? && records_offered? && records_reach.contains?(x, y) then open_records
        elsif title? && sizing_offered? && (sizing = sizing_at(x, y)) then choose_sizing(sizing)
        elsif finished? && share_reach&.contains?(x, y) then share
        else
          scenery = attract.dots.top_at(x, y) if title?
          game.press(x, y)
          toy_pop(scenery, x, y) if scenery&.fresh?
        end
      end

      # Whether a press at +x+, +y+ waits to be let go before it counts: on
      # Game Over, anywhere but "Copy my result", since it may become a
      # drag of the pile (PileGrabs). Everywhere else a press counts the
      # moment it goes down.
      def waits_for_release?(x, y) = finished? && !share_reach&.contains?(x, y)

      # A gamepad's Start: on the title it starts the usual round, and
      # after one it continues, as a tap on empty space would, grace and
      # all; where it presses does not matter on either screen. In a round
      # it does nothing, since only a press at a place may touch the score.
      def start
        return close_records if records?

        game.press(layout.center_x, layout.center_y) unless playing?
      end

      # Escape, or a gamepad's B: leaves the Records screen. Says whether
      # there was one to leave, so that elsewhere the key can do its usual
      # job.
      def back
        return false unless records?

        close_records
        true
      end

      # Switches how dots are sized (DotSizing) to the other choice, as a
      # gamepad's shoulder button does, while the title offers it.
      def toggle_sizing = choose_sizing(game.sizing.toggled)

      # Sizes dots as +sizing+ (DotSizing) says, on the title while it
      # offers the choice, and remembers it. The title's dots and best
      # change with it, so the choice shows at once.
      def choose_sizing(sizing)
        return unless title? && sizing_offered?
        return sounds.play(:tick, pitch: 0.8) if sizing == game.sizing

        game.sizing = sizing
        @sizing_store.write(game.sizing.to_text)
        @attract = Attract.spawn(game.field, look::TITLE)
        @marquee = marquee.with(best: game.best.of(game.size_class))
        sounds.play(:tick, pitch: game.sizing.sized_to_screen? ? 1.2 : 0.9)
      end

      # Opens the Records screen over the title, with the stats as they
      # are now.
      def open_records
        return unless title?

        @records = records_sheet
        sounds.play(:tick)
      end

      def close_records
        @records = nil
        @clearing = clearing.cancel
        sounds.play(:tick, pitch: 0.8)
      end

      # A gamepad's Y on the Records screen, held by +by+: Undo while it is
      # offered, or else the start of holding "Clear my records…".
      def clear_or_undo(by)
        return undo if undo_offer

        hold_clear(by) if clear_offered?
      end

      # +by+ (as #tap names it) let go. A hold of "Clear my records…" it
      # made ends, with nothing cleared, if it was let go too soon.
      def let_go(by) = @clearing = clearing.release(by, now)

      # Whatever holds "Clear my records…" stops, with nothing cleared, as
      # when the window loses focus and a release may never be heard.
      def let_go_of_everything = @clearing = clearing.cancel

      # Where a press reaches "Clear my records…" and Undo on the Records
      # screen, as the title's buttons do.
      def clear_reach = within_safe(layout.clear_records_button.reach(2 * @radius))
      def undo_reach = within_safe(layout.undo_button.reach(2 * @radius))

      # The gamepad button that holds "Clear my records…", for its words.
      def holding_button = clearing.by == :y ? "Y" : "A"

      # A gamepad's Y, or a tap on "Copy my result": on Game Over, copies
      # the round's result to share. Anywhere else it does nothing.
      def share
        return unless finished? && finale

        @clipboard.copy(words.share_text(finale.score, finale.stats, best: finale.best, new_best: finale.new_best?,
                                         record: finale.record, screen: finale.screen, first: finale.first))
        @finale = finale.copy(now)
        sounds.play(:tick)
      end

      # Where a tap reaches "Copy my result", where it is drawn: never
      # less than a dot's width. Nil without one.
      def share_reach = finale_plan&.share_button&.reach(2 * @radius)

      # Where a tap reaches "Your records": never less than a dot's width,
      # and never past the safe area's bottom.
      def records_reach = within_safe(title_plan.records_button.reach(2 * @radius))

      # Where a tap reaches each segment of the dot-size choice, as a
      # DotSizing and its Rect: never less than a dot's width, and never
      # past the safe area's bottom.
      def sizing_reaches = SIZINGS.zip(title_plan.sizing_control.options.map { within_safe(it.reach(2 * @radius)) })

      # Where the title's words and buttons go (TitlePlan).
      def title_plan
        goal = lifetime.goal_done? ? words.goal_done_line(lifetime.goal) : words.goal(lifetime.goal) if played?
        TitleScreen.new(layout:, type: look::TYPE, words:, measure: @measure, best: marquee.best, goal:,
                        done: lifetime.goal_done?, streak: lifetime.streak, records: records_offered?,
                        sizing: sizing_offered?).plan
      end

      # Where Game Over's words and "Copy my result" go (FinalePlan), or
      # nil away from Game Over.
      def finale_plan = finale_screen&.plan

      # Game Over's words to lay out (FinaleScreen), or nil away from it.
      def finale_screen
        return unless finale

        FinaleScreen.new(layout:, type: look::TYPE, words:, measure: @measure, scrim: look::FINALE_BACKING, finale:,
                         below: hud_bottom, hint: @hint.call)
      end

      # The window changed size. The title's dots are respawned if their
      # size changes with it, as dots sized to the screen do.
      def resize(layout, field)
        @layout = layout
        @attract = field.radius == attract.field.radius ? attract.refit(field) : Attract.spawn(field, look::TITLE)
      end

      def update(seconds)
        @now += seconds
        clear_records if clearing.done?(now)
        @undo = nil unless @undo&.open?(now)
        effects.update(seconds)
        @attract = attract.update(seconds) if title?
        @hud = hud.read(game.round, now) { tick(it) if playing? } if game.round
        follow_finale if finished?
      end

      # Hears one of the rules' events (Game#subscribe).
      def call(event)
        case event
        when Events::RoundStarted then round_started(event)
        when Events::Popped then popped(event)
        when Events::Penalized then penalized(event)
        when Events::Missed then effects.ring(event.x, event.y, look::TOUCH_RIPPLE)
        when Events::RoundEnded then round_ended(event)
        when Events::TitleShown then title_shown(event)
        end
      end

      private

      def records_tap(x, y, by)
        if undo_offer && undo_reach.contains?(x, y) then undo
        elsif clear_offered? && clear_reach.contains?(x, y) then hold_clear(by)
        else close_records
        end
      end

      def hold_clear(by)
        @clearing = clearing.press(by, now)
        sounds.play(:tick, pitch: 0.7)
      end

      # "Clear my records…" was held long enough: the records go, and Undo
      # is offered.
      def clear_records
        @clearing = clearing.cancel
        @undo = UndoOffer.new(cleared: @keeper.clear, at: now, seconds: look::RECORDS_CLEAR.undo)
        records_changed
        sounds.play(:bonk, pitch: 0.7)
        @haptics.buzz(look::HAPTICS.penalty)
      end

      def undo
        @keeper.restore(@undo.cleared)
        @undo = nil
        records_changed
        sounds.play(:tick, pitch: 1.2)
      end

      # The records changed under the Records screen: it, and the title's
      # best, show them as they are now.
      def records_changed
        @records = records_sheet if records?
        @marquee = marquee.with(best: game.best.of(game.size_class))
      end

      def records_sheet
        size_class = game.size_class
        RecordsSheet.build(lifetime.stats, best: game.best.of(size_class), words:, streak: lifetime.streak,
                           size_class:, field: game.field, sizing: game.sizing)
      end

      # The dot-size choice whose segment a tap at +x+, +y+ reaches, or nil.
      def sizing_at(x, y) = sizing_reaches.find { |_, reach| reach.contains?(x, y) }&.first

      # Where the HUD's pill ends, at the safe area's top.
      def hud_bottom
        type = look::TYPE
        layout.top + Hud.height(@measure.height(:bold, layout.scaled(type.hud_number)),
                                @measure.height(:semibold, layout.scaled(type.hud_label)))
      end

      def within_safe(reach) = reach.with(height: [reach.height, layout.safe.bottom - reach.y].min)

      def round_started(event)
        @scale = event.round.field.radius
        effects.clear
        effects.scale_to(@scale)
        animations.clear
        @hud = Hud.blank(look::HUD, words)
        event.round.dots.each { animations.spawn(it.id, now) }
        @finale = nil
        @hid_fresh = false
        @undo = nil # the round's records would be lost to an undo
        sounds.play(:start)
      end

      def popped(event)
        dot = event.dot
        animations.pop(dot.id, now)
        animations.spawn(event.spawned.id, now)
        effects.burst(event.x, event.y, look::POP_BURST, palette.confetti)
        effects.ring(dot.x, dot.y, look::SHOCKWAVE, follow: dot.id)
        effects.ring(event.spawned.x, event.spawned.y, look::SPAWN_RIPPLE, follow: event.spawned.id)
        float_pair(event.x, event.y, Words.points(event.points), Words.seconds(event.seconds),
                   palette.cream, palette.gain, look::GAIN_FLOAT)
        sounds.play(:pop, pitch: pop_pitch, pan: pan(event.x))
        @haptics.buzz(look::HAPTICS.pop)
      end

      def penalized(event)
        @penalized_at = now
        animations.wobble(event.dot.id, now)
        effects.ring(event.dot.x, event.dot.y, look::ALARM_RING, follow: event.dot.id)
        hidden = game.round.dots.fresh_beneath(event.dot, event.x, event.y)
        effects.reveal(hidden, look::REVEAL) if hidden
        @hid_fresh ||= !hidden.nil?
        effects.kick(look::PENALTY_SHAKE)
        effects.light(look::PENALTY_FLASH)
        # The floor can keep the score from falling; say only what was lost.
        points = event.points.zero? ? nil : Words.points(event.points)
        float_pair(event.x, event.y, points, Words.seconds(event.seconds), palette.alarm, palette.alarm,
                   look::LOSS_FLOAT)
        sounds.play(:bonk, pan: pan(event.x))
        @haptics.buzz(look::HAPTICS.penalty)
      end

      def round_ended(event)
        result = lifetime.record(stats, event.size_class)
        lesson = @tutor.lesson(words.covered) if @hid_fresh
        @finale = Finale.new(look: look::FINALE, score: event.score, best: event.best, new_best: event.new_best, at: now,
                             stats:, record: result.records.first, goal_met: result.goal_met, lesson:,
                             first: event.first, screen: words.played_on(event.round.field, sized: event.size_class == SizeClass::FITTED))
        sounds.play(event.new_best ? :new_best : :game_over)
      end

      def title_shown(event)
        @records = nil
        @clearing = clearing.cancel
        effects.clear
        @finale = nil
        @marquee = Marquee.new(look: look::TITLE, best: event.best, at: now)
      end

      # The title's dot, popped by the tap that started the round: its
      # droplets, its ring, and its bloop, but no score.
      def toy_pop(dot, x, y)
        effects.burst(x, y, look::POP_BURST, palette.confetti)
        effects.ring(dot.x, dot.y, look::SHOCKWAVE)
        sounds.play(:pop, pan: pan(x))
      end

      # One floater to the left and one to the right of the tap; with only
      # one, it sits over the tap.
      def float_pair(x, y, left, right, left_color, right_color, float)
        spread = look::FLOAT_SPREAD * @scale
        spread = 0.0 unless left && right
        effects.float(left, x - spread, y, left_color, float) if left
        effects.float(right, x + spread, y, right_color, float) if right
      end

      # Where across the stereo field a sound at +x+ plays.
      def pan(x) = look::SOUND.stereo.pan(x, layout.width)

      def pop_pitch
        sound = look::SOUND
        [1.0 + (game.round.score * sound.pop_climb), sound.pop_highest].min
      end

      def tick(seconds)
        return if now - @penalized_at < 0.1

        sounds.play(:tick, pitch: 1.0 + ((look::HUD.urgent_below - seconds) * look::SOUND.tick_climb))
        effects.light(look::TICK_FLASH)
      end

      def follow_finale
        @finale = finale.ready(now) if game.state.ready?
        goal_burst if finale.goal_due?(now)
        return unless finale.celebration_due?(now)

        @finale = finale.celebrate
        celebrate
      end

      # A small burst of twinkles where "You met today's goal!" appears.
      def goal_burst
        @finale = finale.goal_celebrate
        sounds.play(:tick, pitch: 1.5)
        line = finale_plan[:goal] or return
        effects.burst(line.center_x, line.center_y, look::FINALE.goal_sparkles, palette.confetti,
                      longest: look::FINALE.sparkle_life)
      end

      def celebrate
        sparkles = look::FINALE.sparkles
        [0.3, 0.5, 0.7].each do |across|
          effects.burst(layout.safe.x + (layout.safe.width * across), layout.top + (layout.safe.height * 0.2),
                        sparkles, palette.confetti, longest: look::FINALE.sparkle_life)
        end
      end
    end
  end
end
