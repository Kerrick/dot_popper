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
    # pile, or nil. +sharing+ (InGameSharing's methods) offers Game
    # Over's result to share, in a preview or a phone's own sheet, and
    # +clipboard+ takes it when the player copies it. +tutorial_flag+
    # (TutorialFlag) says whether Play opens the Tutorial first.
    class Show
      # The dot-size choices in the order the title draws their segments:
      # the default, dots sized to the screen, first.
      SIZINGS = [DotSizing::SIZED_TO_SCREEN, DotSizing::STANDARD].freeze

      attr_reader :game, :effects, :animations, :hud, :attract, :layout, :marquee, :finale, :sounds, :now, :look,
                  :lifetime, :input, :words, :clearing, :tutorial, :lead_in

      def initialize(game:, layout:, sounds:, radius:, look: Look, random: Random.new, calm: false,
                     tutor: Tutor.new(BestScore::Memory.new, times: look::LESSON.times), haptics: NoHaptics.new, clipboard: MemoryClipboard.new,
                     lifetime: Lifetime.new(BestScore::Memory.new), sizing_store: BestScore::Memory.new,
                     input: InputKind::MOUSE, measure: RoughMeasure.new, hint: -> {},
                     keeper: RecordKeeper.new(best: game.best, lifetime:), notices: Notices.none,
                     sharing: InGameSharing.new, tutorial_flag: TutorialFlag.never)
        @game = game
        @tutorial_flag = tutorial_flag
        @tutorial = nil
        @lead_in = nil
        @notices = notices
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
        @sharing = sharing
        @preview = nil
        @hid_fresh = false
        @penalized_at = -Float::INFINITY
        @recorder = RoundStats::Recorder.new
        @records = nil
        @credits = nil
        @credits_drag = nil
        @keeper = keeper
        @clearing = HoldToConfirm.idle(look::RECORDS_CLEAR.hold)
        @undo = nil
        @pointer = nil
        @hover = Hover.none
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

      # Whether the title is showing: the game is on its title, and the
      # Tutorial is not playing over it.
      def title? = game.state.is_a?(Game::Title) && !tutorial?

      # Whether the Tutorial is playing (#tutorial). It is the
      # presentation's alone, as the Records screen is: the game stays on
      # its title meanwhile, so nothing in it is a round's, and no tap
      # there reaches the game.
      def tutorial? = !@tutorial.nil?

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

      # A tap at +x+, +y+, by +by+ (a finger's id, :mouse, or :gamepad),
      # which #let_go names when it lets go. In a round, every tap goes to
      # the game at once. Elsewhere a tap presses the screen's button under
      # it (#controls): on the title, Play, the mute button, "Your records",
      # and the dot-size choice; on Game Over, Continue and "Share my
      # score", and over it, the share preview's Copy and Close; and on the
      # Records screen, Back, Undo, or "Clear my records…", which a press
      # starts holding. Empty space does nothing, but a tap on one of the
      # title's fresh dots pops it, for fun, and a tap away from the share
      # preview's card closes it. A gamepad's A, which aims at no button,
      # presses the screen's main one (#primary).
      def tap(x, y, by: :tap)
        return game.press(x, y) if playing?
        return tutorial_tap(x, y) if tutorial?

        case control_at(x, y)&.name
        in :play then play
        in :continue then continue_on
        in :back then leave
        in :credits then open_credits
        in :mute then sounds.toggle_mute
        in :records then open_records
        in DotSizing => sizing then choose_sizing(sizing)
        in :share then share
        in :copy then copy_result
        in :close then close_share
        in :undo then undo
        in :clear then hold_clear(by)
        in nil if by == :gamepad then primary
        in nil if sharing? then (close_share unless share_plan.card.contains?(x, y))
        in nil then credits? ? @credits_drag = [by, y] : toy_tap(x, y)
        end
      end

      # The buttons this screen offers (Control), each where it is drawn
      # and where a press reaches it, no two reaching the same point, so a
      # press reaches one button. Taps and the mouse's hover both go by
      # these.
      def controls
        Control.apart(
          if tutorial? then [Control.new(name: :skip, reach: layout.skip_button)]
          elsif credits? then [button(:back, layout.back_button)]
          elsif records? then records_controls
          elsif title? then title_controls
          elsif sharing? then share_controls
          elsif finished? then finale_controls
          else []
          end
        )
      end

      # The button a press at +x+, +y+ reaches (Control), or nil; on an
      # edge two reaches share, the one drawn nearer.
      def control_at(x, y) = controls.select { it.reach.contains?(x, y) }.min_by { it.distance(x, y) }

      # Where a press reaches the button named +name+ on this screen, or
      # nil when it is not offered.
      def reach_of(name) = controls.find { it.name == name }&.reach

      # Presses this screen's main button, as Enter, Space, a gamepad's
      # Start, or its A aimed at no button do: Play on the title, Back on
      # the Records screen, Continue on Game Over, once its grace is over,
      # and Copy in the share preview. In a round it does nothing, since
      # only a press at a place may touch the score.
      def primary
        if sharing? then copy_result
        elsif records? then leave
        elsif title? then play
        elsif finished? then continue_on
        end
      end

      # The title's Play: a round starts, or on a first Play, the Tutorial
      # (TutorialFlag), which is seen from then on.
      def play
        return unless title? && !records?
        return open_tutorial if @tutorial_flag.due?(played: records_offered?)

        start_round
      end

      # The Tutorial's skip button, Escape, or a gamepad's B: the round
      # starts at once, as a Play would start it.
      def skip_tutorial
        return unless tutorial?

        @tutorial = nil
        start_round
      end

      # Where a tap reaches the Tutorial's skip button, where it is drawn.
      def skip_reach = reach_of(:skip)

      # Game Over's Continue: back to the title, once the game will hear a
      # press (Rules::GAME_OVER_GRACE).
      def continue_on
        game.press(layout.center_x, layout.center_y) if finished?
      end

      # The mouse moved to +x+, +y+, without a button held or with one.
      def pointer_at(x, y) = @pointer = [x, y]

      # The mouse left the window, or the window lost focus.
      def pointer_gone = @pointer = nil

      # The name of the button the mouse is over (as Control names it), or
      # nil. Only a mouse hovers: while the last press was a finger's or a
      # gamepad's, no button is.
      def hovered
        return unless @pointer && input == InputKind::MOUSE

        control_at(*@pointer)&.name
      end

      # How lit each button is by the mouse over it (Hover).
      def hover = @hover

      # Whether a press at +x+, +y+ waits to be let go before it counts: on
      # Game Over, anywhere but its buttons, since it may become a drag of
      # the pile (PileGrabs). Everywhere else, the share preview over Game
      # Over too, a press counts the moment it goes down.
      def waits_for_release?(x, y) = finished? && !sharing? && control_at(x, y).nil?

      # A gamepad's Start: the screen's main button (#primary).
      def start = primary

      QUIT_ASK = 2.0 # seconds a second B has to quit from the title

      # B on the title, where a controller has no other way to quit: the
      # first press asks, and :quit if a second comes within QUIT_ASK
      # seconds, so a stray press never closes the game.
      def ask_to_quit
        return unless title? && !records?
        return :quit if quit_asked?

        @quit_asked_at = now
        sounds.play(:tick, pitch: 0.8)
        :asked
      end

      # How much of "Press B again to quit" shows: all of it while a second
      # press would quit, fading out in its last third of a second.
      def quit_prompt
        return 0.0 unless quit_asked? && title?

        ((QUIT_ASK - (now - @quit_asked_at)) / 0.3).clamp(0.0, 1.0)
      end

      def quit_asked? = @quit_asked_at && now - @quit_asked_at <= QUIT_ASK

      # Escape, Android's Back, or a gamepad's B: closes the share
      # preview, leaves the Records screen, and goes on from Game Over to
      # the title, as Continue does. Says whether there was somewhere to go
      # back from, so that elsewhere the key can do its usual job.
      def back
        if tutorial? then skip_tutorial
        elsif sharing? then close_share
        elsif records? then leave
        elsif finished? then continue_on
        else return false
        end
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
        @credits = nil
        @clearing = clearing.cancel
        sounds.play(:tick, pitch: 0.8)
      end

      # Back, from the Credits screen to the Records screen, or from the
      # Records screen to the title.
      def leave = credits? ? close_credits : close_records

      # Whether the Credits screen is open over the Records screen.
      def credits? = !@credits.nil?

      # How far down the Credits screen is scrolled (CreditsScroll), while
      # it is open.
      def credits = @credits

      # The Credits screen's lines (CreditsLines), laid out for the
      # screen's size, while it is open.
      def credits_lines = @credits_lines&.last

      # Where the Credits screen's heading and its window of text go.
      def credits_layout
        page = CreditsLayout.new(layout:, look: look::CREDITS)
        page.with(wanted: CreditsLines.widest_as_written(credits_book, size: page.text_size, measure: @measure))
      end

      def credits_book = (@credits_book ||= CreditsBook.compose(words, @notices))

      # Opens the Credits screen over the Records screen, at the top.
      def open_credits
        return unless records? && !credits?

        @credits = CreditsScroll.at_top(content: 0.0, window: 0.0)
        lay_out_credits
        sounds.play(:tick)
      end

      def close_credits
        @credits = nil
        @credits_drag = nil
        sounds.play(:tick, pitch: 0.8)
      end

      # Scrolls the Credits screen down by +pixels+ (up for fewer).
      def scroll_credits(pixels) = (@credits = @credits.by(pixels) if credits?)

      # A mouse wheel's notches, +notches+ of them, positive for up.
      def wheel_credits(notches) = scroll_credits(-notches * look::CREDITS.wheel * credits_layout.line)

      # A gamepad's left stick or d-pad (Stick) held for +seconds+.
      def stick_credits(stick, seconds)
        push = stick.shaped(look::GAMEPAD.dead_zone, look::GAMEPAD.curve)
        scroll_credits(push.y * look::CREDITS.stick * credits_layout.line * seconds)
      end

      # A key that scrolls the Credits screen; says whether it was one.
      def credits_key(name)
        return false unless credits?

        @credits = @credits.key(name, line: credits_layout.line)
        %i[up down pageup pagedown home end].include?(name.to_s.to_sym)
      end

      # A finger or the mouse, +by+ (as #tap names it), dragged to +y+,
      # drags the page along with it.
      def drag_credits(by, y)
        held, from = @credits_drag
        return unless credits? && held == by

        scroll_credits(from - y)
        @credits_drag = [by, y]
      end

      # A gamepad's Y on the Records screen, held by +by+: Undo while it is
      # offered, or else the start of holding "Clear my records…".
      def clear_or_undo(by)
        return if credits?
        return undo if undo_offer

        hold_clear(by) if clear_offered?
      end

      # +by+ (as #tap names it) let go. A hold of "Clear my records…" it
      # made ends, with nothing cleared, if it was let go too soon.
      def let_go(by)
        @credits_drag = nil if @credits_drag&.first == by
        @clearing = clearing.release(by, now)
      end

      # Whatever holds "Clear my records…" stops, with nothing cleared, as
      # when the window loses focus and a release may never be heard.
      def let_go_of_everything = @clearing = clearing.cancel

      # Where a press reaches "Clear my records…" and Undo on the Records
      # screen, as the title's buttons do.
      def clear_reach = reach_of(:clear)
      def undo_reach = reach_of(:undo)

      # The gamepad button that holds "Clear my records…", for its words.
      def holding_button = clearing.by == :y ? "Y" : "A"

      # A gamepad's Y, or a tap on "Share my score": on Game Over, offers
      # the round's result to share (+sharing+), which in the game opens
      # the share preview, and copies nothing yet; on a phone it opens the
      # system's share sheet, and no preview. In the preview, Y
      # copies, as Copy does. Anywhere else it does nothing.
      def share
        return copy_result if sharing?
        return unless finished? && finale

        @preview = @sharing.offer(share_text, now)
        sounds.play(:tick)
      end

      # Whether the share preview is open over Game Over. It is the
      # presentation's alone: the game stays on Game Over meanwhile, its
      # grace counting as ever, and no tap there reaches the game.
      def sharing? = !@preview.nil?

      # What the share preview shows (SharePreview), while it is open.
      def share_preview = @preview

      # Where the share preview's card, words and buttons go (SharePlan),
      # or nil while it is closed.
      def share_plan
        return unless sharing?

        ShareScreen.new(layout:, type: look::TYPE, words:, measure: @measure, look: look::SHARE_PREVIEW,
                        lines: @preview.lines).plan
      end

      # The share preview's Copy, the one press that writes the clipboard:
      # it copies exactly the text the preview shows.
      def copy_result
        return unless sharing?

        @clipboard.copy(@preview.text)
        @preview = @preview.copy(now)
        sounds.play(:tick, pitch: 1.3)
      end

      # Closes the share preview, back to Game Over as it was.
      def close_share
        @preview = nil
        sounds.play(:tick, pitch: 0.8)
      end

      # Where a tap reaches "Share my score", where it is drawn: never
      # less than a dot's width, short of where Continue's reach begins.
      # Nil without one, and while the share preview covers it.
      def share_reach = reach_of(:share)

      # Where a tap reaches the share preview's Copy and Close.
      def copy_reach = reach_of(:copy)
      def close_reach = reach_of(:close)

      # Where a tap reaches Game Over's Continue and the title's Play.
      def continue_reach = reach_of(:continue)
      def play_reach = reach_of(:play)

      # Where a tap reaches "Your records": never less than a dot's width
      # where it has room, and never past the safe area's bottom.
      def records_reach = reach_of(:records)

      # Where a tap reaches the Records screen's Back.
      def back_reach = reach_of(:back)

      # Where a tap reaches each segment of the dot-size choice, as a
      # DotSizing and its Rect, while the title offers it.
      def sizing_reaches = SIZINGS.map { [it, reach_of(it)] }

      # Where the title's words and buttons go (TitlePlan). Play is sized
      # from dots fitted to the screen, whichever size is chosen, so the
      # Dot size choice beside it never moves or resizes it.
      def title_plan
        goal = lifetime.goal_done? ? words.goal_done_line(lifetime.goal) : words.goal(lifetime.goal) if played?
        TitleScreen.new(layout:, type: look::TYPE, words:, measure: @measure, best: marquee.best, goal:,
                        done: lifetime.goal_done?, streak: lifetime.streak, records: records_offered?,
                        sizing: sizing_offered?, radius: DotSize.fitted(layout.width, layout.height).radius).plan
      end

      # Where Game Over's words and "Share my score" go (FinalePlan), or
      # nil away from Game Over.
      def finale_plan = finale_screen&.plan

      # Game Over's words to lay out (FinaleScreen), or nil away from it.
      def finale_screen
        return unless finale

        FinaleScreen.new(layout:, type: look::TYPE, words:, measure: @measure, scrim: look::FINALE_BACKING, finale:,
                         below: hud_bottom, hint: @hint.call, radius: game.round&.field&.radius || @radius)
      end

      # The window changed size. The title's dots are respawned if their
      # size changes with it, as dots sized to the screen do.
      def resize(layout, field)
        @layout = layout
        @tutorial&.refit(Field.new(field.width, field.height, @tutorial.field.radius))
        lay_out_credits if credits?
        @attract = field.radius == attract.field.radius ? attract.refit(field) : Attract.spawn(field, look::TITLE)
      end

      def update(seconds)
        @now += seconds
        clear_records if clearing.done?(now)
        @undo = nil unless @undo&.open?(now)
        @hover = hover.at(hovered).update(seconds, look::HOVER)
        effects.update(seconds)
        follow_tutorial(seconds) if tutorial?
        @attract = attract.update(seconds) if title?
        follow_round if game.round
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

      def start_round = game.press(layout.center_x, layout.center_y)

      # Plays the Tutorial on the field a round would start on, and sizes
      # the effects to its dots.
      def open_tutorial
        @tutorial_flag.seen!
        field = game.field
        effects.clear
        effects.scale_to(field.radius)
        @tutorial = Tutorial.new(field:, center: [layout.center_x, layout.center_y], effects:, sounds:,
                                 haptics: @haptics, look:)
      end

      # A tap in the Tutorial: its skip button, or the scene's.
      def tutorial_tap(x, y)
        return skip_tutorial if control_at(x, y)&.name == :skip

        @tutorial.tap(x, y)
      end

      # The Tutorial moves on, and once it is over, the round starts, its
      # clock lit as it starts to run (LeadIn).
      def follow_tutorial(seconds)
        @tutorial.update(seconds)
        return unless @tutorial.over?

        @tutorial = nil
        start_round
        @lead_in = LeadIn.new(at: now, look: look::TUTORIAL.lead)
      end

      # The HUD reads the round. While the Tutorial's lead-in lights the
      # clock, its first second down ticks, as the urgent ones do.
      def follow_round
        before = hud.seconds
        @hud = hud.read(game.round, now) { tick(it) if playing? }
        @lead_in = nil if @lead_in&.over?(now)
        return unless @lead_in && playing? && before && hud.seconds < before && now - @penalized_at >= 0.1

        sounds.play(:tick)
      end

      def title_controls
        plan = title_plan
        buttons = [Control.new(name: :mute, reach: layout.mute_button)]
        buttons << button(:records, plan.records_button) if records_offered?
        buttons.concat(SIZINGS.zip(plan.sizing_control.options).map { button(*it) }) if sizing_offered?
        buttons << primary_button(:play, plan.play_button) if plan.play_button
        buttons
      end

      def share_controls
        plan = share_plan
        [button(:close, plan.close), button(:copy, plan.copy)]
      end

      def finale_controls
        plan = finale_plan or return []
        [(button(:share, plan.share_button) if plan.share_button),
         (primary_button(:continue, plan.continue_button) if plan.continue_button)].compact
      end

      # The Credits text broken into lines for this screen, and the scroll
      # kept at the same place on it.
      def lay_out_credits
        page = credits_layout
        key = [page.text_size, page.room]
        if @credits_lines&.first != key
          @credits_lines = [key, CreditsLines.set(credits_book, size: page.text_size, room: page.room, line: look::CREDITS.line,
                                                  measure: @measure)]
        end
        @credits = @credits.fitted(content: credits_lines.height, window: page.window.height)
      end

      def records_controls
        [(button(:credits, layout.credits_button)),
         (button(:undo, layout.undo_button) if undo_offer),
         (button(:clear, layout.clear_records_button) if clear_offered?),
         button(:back, layout.back_button)].compact
      end

      # A button drawn at +frame+, which a press reaches within a dot's
      # width, short of the safe area's bottom.
      def button(name, frame) = Control.new(name:, frame:, reach: within_safe(frame.reach(2 * @radius)))

      # A screen's main button, which a press reaches more generously.
      def primary_button(name, frame) = Control.new(name:, frame:, reach: layout.primary_reach(frame, game.field.radius))

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
        @preview = nil
        @hid_fresh = false
        @undo = nil # the round's records would be lost to an undo
        @lead_in = nil
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

      # The finished round's result, as Words#share_text says it.
      def share_text
        words.share_text(finale.score, finale.stats, best: finale.best, new_best: finale.new_best?,
                         record: finale.record, screen: finale.screen, first: finale.first)
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
        @credits = nil
        @clearing = clearing.cancel
        effects.clear
        @finale = nil
        @preview = nil
        @marquee = Marquee.new(look: look::TITLE, best: event.best, at: now)
      end

      # A tap on the title away from its buttons: a fresh dot there pops
      # for fun, with no score; anywhere else, nothing happens.
      def toy_tap(x, y)
        return unless title? && !records?

        dot = attract.dots.top_at(x, y)
        toy_pop(dot, x, y) if dot&.fresh?
      end

      # One of the title's dots, popped by a tap: its droplets, its ring,
      # and its bloop, but no score.
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
