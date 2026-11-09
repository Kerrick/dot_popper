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
    # +haptics+ answers buzz(seconds). +lifetime+ (StatsBook) adds up every
    # game the device has played. +sizing_store+ keeps the player's
    # DotSizing, chosen on the title. +radius+ is the usual dot's, which
    # sizes the buttons' reach; a game's effects follow its own dots.
    # +input+ (InputKind) is what the player last pressed with, and the
    # words follow it. +keeper+ (RecordKeeper) clears the records, from
    # the Stats screen, and puts them back. +measure+ sizes the screens' words (RoughMeasure's
    # methods). +sharing+ (InGameSharing's methods) offers Game
    # Over's result to share, in a preview or a phone's own sheet, and
    # +clipboard+ takes it when the player copies it. +achievements+
    # (Achievements) keeps the achievements a game earns, as it ends, and the
    # Stats screen lists them once the +entitlement+ says the pro
    # version was bought. +tutorial_flag+
    # (TutorialFlag) says whether Play opens the Tutorial first. +window+
    # (NoWindowControl's methods) is the desktop's window, which the
    # title's "Full screen" and Quit switch and close where it offers them.
    # +games+ (FreeGames) counts the games a free player may start: Play
    # spends one, and with none left leads to the offer of Pro.
    class Show
      # The dot-size choices in the order the title draws their segments:
      # the default, dots sized to the screen, first.
      SIZINGS = [DotSizing::SIZED_TO_SCREEN, DotSizing::STANDARD].freeze

      attr_reader :cabinet, :effects, :animations, :hud, :attract, :layout, :marquee, :game_over, :sounds, :now, :style,
                  :stats_book, :input, :words, :clearing, :tutorial, :lead_in, :window, :games

      def initialize(cabinet:, layout:, sounds:, radius:, style: Style, random: Random.new, calm: false,
                     tutor: Tutor.new(ScoreRecord::Memory.new, times: style::LESSON.times), haptics: NoHaptics.new, clipboard: MemoryClipboard.new,
                     stats_book: StatsBook.new(ScoreRecord::Memory.new), sizing_store: ScoreRecord::Memory.new,
                     input: InputKind::MOUSE, measure: RoughMeasure.new,
                     achievements: Achievements.new(ScoreRecord::Memory.new),
                     keeper: StatsKeeper.new(score_record: cabinet.score_record, stats_book:, achievements:), notices: Notices.none,
                     sharing: InGameSharing.new, tutorial_flag: TutorialFlag.never, window: NoWindowControl.new,
                     entitlement: Entitlement.free, theme_keeper: ThemeKeeper.plain(style::THEMES),
                     groups: Groups::Session.off, storefront: NoStorefront.new, games: FreeGames.unlimited)
        @cabinet = cabinet
        @window = window
        @tutorial_flag = tutorial_flag
        @entitlement = entitlement
        @theme_keeper = theme_keeper
        @themes = false
        @achievements = achievements
        @achievement_watch = AchievementWatch.new
        @groups = GroupPanel.new(groups:, entitlement:, sounds:, pro_offer: ->(feature) { open_offer_for(feature) })
        @offer_focus = nil
        @storefront = storefront
        @games = games
        @offer = false
        @offer_for_play = false
        @tutorial = nil
        @handing_over = nil
        @lead_in = nil
        @notices = notices
        @measure = measure
        @plans = {}
        @stats_book = stats_book
        @layout = layout
        @sounds = sounds
        @haptics = haptics
        @radius = radius
        @scale = radius
        @sizing_store = sizing_store
        @style = style
        @input = input
        @words = style::WORDS.for(input)
        @random = random
        @calm = calm
        @effects = Effects.new(radius:, random:, calm:)
        @animations = DotAnimations.new(style::MOTION)
        @hud = Hud.blank(style::HUD, words)
        @attract = Attract.spawn(cabinet.field, style::TITLE)
        @now = 0.0
        @marquee = Marquee.new(style: style::TITLE, score_record: cabinet.score_record.of(cabinet.size_class), at: @now)
        @game_over = nil
        @tutor = tutor
        @clipboard = clipboard
        @sharing = sharing
        @preview = nil
        @mistake = nil
        @penalized_at = -Float::INFINITY
        @beckoned_at = nil
        @recorder = GameStats::Recorder.new
        @stats = nil
        @credits = nil
        @credits_drag = nil
        @keeper = keeper
        @clearing = HoldToConfirm.idle(style::RECORDS_CLEAR.hold)
        @undo = nil
        @pointer = nil
        @hover = Hover.none
        cabinet.subscribe(@recorder)
        cabinet.subscribe(self)
      end

      # The numbers of the game in play, or of the one just finished.
      def game_stats = @recorder.stats

      # The colors of the theme being worn (ThemeKeeper), which only changes
      # between games.
      def palette = @theme_keeper.palette

      # Whether the Themes screen is open over the Stats screen, and what
      # it shows: every theme the player can wear, and the one worn.
      def themes? = @themes

      # The new theme to tell the player of, once, at the title, when nothing
      # else is asked of them; nil the rest of the time.
      def arrival = (@theme_keeper.arrival if title? && !stats? && !themes? && !group_open?)
      def arrival? = !arrival.nil?
      def arrival_plan = ArrivalPlan.new(layout)

      # The switch's word: a Free player's says how, since it opens the offer.
      def arrival_wear_word = words.themes.fetch(themes_locked? ? :wear_pro : :wear)
      def themes = @theme_keeper.shown
      def worn = @theme_keeper.worn

      # Whether tapping a theme leads to Pro, as it does for a Free player;
      # whether +theme+ is one this player has earned; and whether it is open
      # to wear, earned or in season. They show the same to either player.
      def themes_locked? = @theme_keeper.locked?
      def theme_earned?(theme) = @theme_keeper.earned?(theme)
      def theme_open?(theme) = @theme_keeper.open?(theme)

      # Whether the Stats screen offers Themes: always, the same to a Free
      # player and a Pro one.
      def themes_offered? = stats? && !credits? && !themes? && @theme_keeper.offered?

      # Where the Themes screen's cards go (LooksLayout).
      def themes_layout = ThemesLayout.new(layout:, themes: themes, style: style::THEMES_LAYOUT)

      def open_themes
        return unless themes_offered?

        @themes = true
        sounds.play(:tick)
      end

      def close_themes
        @themes = false
        sounds.play(:tick, pitch: 0.8)
      end

      # Wears +theme+ from now on, and the whole screen takes its colors at
      # once, so the choice is seen before it is left.
      def wear(theme)
        return unless themes?
        return open_offer_for(:themes) if themes_locked?
        return sounds.play(:tick, pitch: 0.8) if theme == worn || !theme_open?(theme)

        @theme_keeper.wear(theme)
        sounds.play(:tick, pitch: 1.2)
      end

      # The player pressed with +kind+ (InputKind): from now on the words
      # say what to do with it.
      def input=(kind)
        return if kind == input

        @input = kind
        @words = style::WORDS.for(kind)
      end

      # Whether the title is showing: the game is on its title, and the
      # Tutorial is not playing over it.
      def title? = cabinet.state.is_a?(Cabinet::Title) && !tutorial?

      # Whether the Tutorial is playing (#tutorial). The game stays on its
      # title meanwhile, so its clock is not running, and no tap there
      # reaches the game; once it ends, the game goes on from where it
      # left its dots, score and time.
      def tutorial? = !@tutorial.nil?

      # Whether the Stats screen is open over the title. It is the
      # presentation's alone: the game stays on its title meanwhile, and
      # no tap there reaches the game.
      def stats? = !@stats.nil?

      # The friend groups' screens' state and their announcements (GroupPanel).
      def group_panel = @groups

      # Whether the Friend group screen is open over the title.
      def group_open? = @groups.open?

      # Where the Friend group screen's parts go, while it is open.
      def group_plan
        GroupScreen.new(layout:, style: style::GROUPS, measure: @measure, panel: @groups,
                        standard_dots: !cabinet.sizing.sized_to_screen?, back_text: words.go_back).plan
      end

      # Whether the title offers the way in to groups: where there is a
      # server, once a game has finished, or for someone in a group.
      def group_offered? = @groups.available? && (stats_offered? || @groups.member?)

      # The title's way in to groups.
      def group_button = GroupScreen.button(layout, labelled: layout.safe.width >= 480)

      # Where an announcement goes: under the HUD at Game Over, and at
      # the top of the title, clear of the Group button's row.
      def banner_y = game_over? ? hud_bottom + layout.margin : layout.top + layout.button_size + layout.margin

      # What the Stats screen shows, while it is open.
      def stats = @stats

      # The Stats screen laid out for the fonts this screen is measured with.
      def stats_layout
        StatsLayout.measured(layout:, sheet: stats, style: style::RECORDS, measure: @measure, themes: themes_offered?,
                             offer: offer_offered?)
      end

      # Whether the title offers "Your stats" and the choice of dot size:
      # only once a game has finished, so a first-time player's title says
      # only how to play. A player who cleared their records has played, so
      # it still offers them, though it shows no best or goal until their
      # next game (#played?).
      def stats_offered? = played? || @keeper.cleared?

      # Whether a game has finished since the records were last cleared:
      # the title shows today's goal only then.
      def played? = stats_book.stats.games.positive?

      # Whether the Stats screen offers "Clear my stats…": while it has
      # records to clear, and no Undo is offered.
      def clear_offered? = stats? && !stats.empty && !undo_offer

      # Undo, while it is offered on the Stats screen (UndoOffer), or nil.
      def undo_offer = (@undo if stats?)

      # What the choice of dot size would do on this screen, worked out
      # afresh each time, so a resized window is always seen as it is now.
      def sizing_preview = SizingPreview.of(cabinet.screen, style::SIZING)

      # Whether the title offers the choice of dot size: once a game has
      # finished, and only where the two sizes look different. Where they
      # look alike, the saved choice stays as it was, and games follow it.
      def sizing_offered? = stats_offered? && sizing_preview.offered?
      def playing? = cabinet.state.is_a?(Cabinet::Playing)
      def game_over? = cabinet.state.is_a?(Cabinet::GameOver)

      # A tap at +x+, +y+, by +by+ (a finger's id, :mouse, or :gamepad),
      # which #let_go names when it lets go. In a game, every tap goes to
      # the game at once. Elsewhere a tap presses the screen's button under
      # it (#controls): on the title, Play, the mute button, "How to play",
      # "Your stats", the dot-size choice, and on a desktop "Full screen"
      # and Quit; on Game Over, Continue and
      # "Share my score", and over it, the share preview's Copy and Close;
      # and on the
      # Stats screen, Back, Undo, or "Clear my stats…", which a press
      # starts holding. Empty space does nothing, but a tap on one of the
      # title's fresh dots pops it, for fun, and a tap away from the share
      # preview's card closes it. A gamepad's A, which aims at no button,
      # presses the screen's main one (#primary).
      def tap(x, y, by: :tap)
        return cabinet.press(x, y) if playing?
        return tutorial_tap(x, y) if tutorial?

        case control_at(x, y)&.name
        in :play then play
        in :continue then continue_on
        in :back then leave
        in :credits then open_credits
        in :themes then open_themes
        in Theme => theme then wear(theme)
        in :mute then sounds.toggle_mute
        in :how_to_play then how_to_play
        in :fullscreen then window.toggle_fullscreen
        in :quit then window.quit
        in :stats then open_stats
        in :arrival_wear then answer_arrival(wear: true)
        in :arrival_later then answer_arrival(wear: false)
        in :group_open then @groups.open
        in :offer then open_offer
        in :achievements then open_offer_for(:achievements)
        in :buy then buy
        in :restore then @storefront.restore
        in DotSizing => sizing then choose_sizing(sizing)
        in :share then share
        in :copy then copy_result
        in :close then close_share
        in :undo then undo
        in :clear then hold_clear(by)
        in Symbol | Array => name if group_open? then @groups.press(name, by, now)
        in nil if group_open? then @groups.tap_away
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
          if arrival? then arrival_controls
          elsif tutorial? then [Control.new(name: :skip, reach: layout.skip_button)]
          elsif offer? then offer_controls
          elsif credits? then [button(:back, layout.back_button)]
          elsif group_open? then group_controls
          elsif themes? then themes_controls
          elsif stats? then stats_controls
          elsif title? then title_controls
          elsif sharing? then share_controls
          elsif game_over? then game_over_controls
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
      # the Stats screen, Continue on Game Over, once its grace is over,
      # and Copy in the share preview. In a game it does nothing, since
      # only a press at a place may touch the score.
      def primary
        if arrival? then answer_arrival(wear: true)
        elsif group_open? then leave
        elsif sharing? then copy_result
        elsif offer? || stats? then leave
        elsif title? then play
        elsif game_over? then continue_on
        end
      end

      # The title's Play: a game starts, or on a first Play, the Tutorial
      # (TutorialFlag), which is seen from then on.
      def play
        return unless title? && !stats? && !group_open?
        return open_tutorial if @tutorial_flag.due?(played: stats_offered?)

        start_game
      end

      # The title's "How to play", H, or a gamepad's Y there: the Tutorial,
      # at once, whether it was seen or not, handing over into a game as
      # it does on a first Play.
      def how_to_play
        open_tutorial if title? && !stats? && !group_open?
      end

      # The Tutorial's skip button, Escape, or a gamepad's B: the game
      # starts at once, as a Play would start it.
      def skip_tutorial
        return unless tutorial?

        @tutorial = nil
        start_game
      end

      # Where a tap reaches the Tutorial's skip button, where it is drawn.
      def skip_reach = reach_of(:skip)

      # Game Over's Continue: back to the title, once the game will hear a
      # press (Rules::GAME_OVER_GRACE).
      def continue_on
        cabinet.press(layout.center_x, layout.center_y) if game_over?
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
      def waits_for_release?(x, y) = game_over? && !sharing? && control_at(x, y).nil?

      # A gamepad's Start: the screen's main button (#primary).
      def start = primary

      QUIT_ASK = 2.0 # seconds a second B has to quit from the title

      # B on the title, where a controller has no other way to quit: the
      # first press asks, and :quit if a second comes within QUIT_ASK
      # seconds, so a stray press never closes the game.
      def ask_to_quit
        return unless title? && !stats? && !group_open?
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
      # preview, leaves the Stats screen, and goes on from Game Over to
      # the title, as Continue does. Says whether there was somewhere to go
      # back from, so that elsewhere the key can do its usual job.
      def back
        if arrival? then answer_arrival(wear: false)
        elsif tutorial? then skip_tutorial
        elsif group_open? then leave
        elsif sharing? then close_share
        elsif stats? then leave
        elsif game_over? then continue_on
        else return false
        end
        true
      end

      # Switches how dots are sized (DotSizing) to the other choice, as a
      # gamepad's shoulder button does, while the title offers it.
      def toggle_sizing = choose_sizing(cabinet.sizing.toggled)

      # Sizes dots as +sizing+ (DotSizing) says, on the title while it
      # offers the choice, and remembers it. The title's dots and best
      # change with it, so the choice shows at once.
      def choose_sizing(sizing)
        return unless title? && sizing_offered?
        return sounds.play(:tick, pitch: 0.8) if sizing == cabinet.sizing

        cabinet.sizing = sizing
        @sizing_store.write(cabinet.sizing.to_text)
        @attract = Attract.spawn(cabinet.field, style::TITLE)
        @marquee = marquee.with(score_record: cabinet.score_record.of(cabinet.size_class))
        sounds.play(:tick, pitch: cabinet.sizing.sized_to_screen? ? 1.2 : 0.9)
      end

      # Opens the Stats screen over the title, with the stats as they
      # are now.
      def open_stats
        return unless title?

        @stats = stats_sheet
        sounds.play(:tick)
      end

      def close_stats
        @stats = nil
        @themes = false
        @credits = nil
        @offer = false
        @offer_focus = nil
        @offer_for_play = false
        @clearing = clearing.cancel
        sounds.play(:tick, pitch: 0.8)
      end

      # Back, from the Credits screen to the Stats screen, or from the
      # Stats screen to the title.
      def leave
        return close_offer if offer?
        return @groups.back if group_open?

        if offer? then close_offer
        elsif credits? then close_credits
        elsif themes? then close_themes
        else close_stats
        end
      end

      def close_offer
        return close_stats if @offer_for_play

        @offer = false
        @offer_focus = nil
        sounds.play(:tick, pitch: 0.8)
      end

      # What the open offer leads with, or nil when it was not opened by a
      # tap on something Pro has.
      attr_reader :offer_focus

      # A Free player tapped something that comes with Pro (+feature+ is
      # :achievements, :themes or :groups): the offer opens over the screen
      # they are on, leading with it, and Back closes it to that same screen,
      # open as it was, so no one loses their place.
      def open_offer_for(feature)
        return if @entitlement.pro? || offer?

        @offer = true
        @offer_focus = feature
        @storefront.connect
        sounds.play(:tick)
      end

      # Whether the Stats screen offers the way to Pro: where
      # there is a store, to a player who has not bought it. It is offered
      # here and nowhere else, and asks for nothing; a player finds it or
      # does not (doc/decisions.md).
      def offer_offered? = @storefront.offered? && !@entitlement.pro?

      # Whether the offer of Pro is open, over the Stats screen.
      def offer? = @offer

      # Opens the offer over the Stats screen, and asks the store for the
      # price, or asks again if an earlier request was never answered.
      def open_offer
        return unless stats? && !credits? && offer_offered?

        @themes = false
        @offer = true
        @offer_focus = nil
        @storefront.connect
        sounds.play(:tick)
      end

      # Where the offer's words and buttons go (OfferPlan), or nil while it
      # is closed.
      def offer_plan
        return unless offer?

        OfferScreen.new(layout:, type: style::TYPE, words:, measure: @measure, offering: !@entitlement.pro?,
                        note: words.offer_note(games.left, games.daily), focus: @offer_focus).plan
      end

      # The price the store gave, or nil before it has.
      def offer_price = @storefront.price

      # What the offer says of how the store is getting on: thanks once the
      # player owns it, and otherwise a word only when there is something to
      # say.
      def offer_status
        return words.offer[:thanks] if @entitlement.pro?

        words.offer.fetch(@storefront.status, "")
      end

      # Buy where the store gave a price, and otherwise the same button's
      # "Try again".
      def buy
        return @storefront.connect unless offer_price

        @storefront.buy
      end

      # Whether the Credits screen is open over the Stats screen.
      def credits? = !@credits.nil?

      # How far down the Credits screen is scrolled (CreditsScroll), while
      # it is open.
      def credits = @credits

      # The Credits screen's lines (CreditsLines), laid out for the
      # screen's size, while it is open.
      def credits_lines = @credits_lines&.last

      # Where the Credits screen's heading and its window of text go.
      def credits_layout
        page = CreditsLayout.new(layout:, style: style::CREDITS)
        page.with(wanted: CreditsLines.widest_as_written(credits_book, size: page.text_size, measure: @measure))
      end

      def credits_book = (@credits_book ||= CreditsBook.compose(words, @notices))

      # Opens the Credits screen over the Stats screen, at the top.
      def open_credits
        return unless stats? && !credits? && !offer?

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
      def wheel_credits(notches) = scroll_credits(-notches * style::CREDITS.wheel * credits_layout.line)

      # A gamepad's left stick or d-pad (Stick) held for +seconds+.
      def stick_credits(stick, seconds)
        push = stick.shaped(style::GAMEPAD.dead_zone, style::GAMEPAD.curve)
        scroll_credits(push.y * style::CREDITS.stick * credits_layout.line * seconds)
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

      # A gamepad's Y on the Stats screen, held by +by+: Undo while it is
      # offered, or else the start of holding "Clear my stats…".
      def clear_or_undo(by)
        return if credits? || offer?
        return undo if undo_offer

        hold_clear(by) if clear_offered?
      end

      # +by+ (as #tap names it) let go. A hold of "Clear my stats…" it
      # made ends, with nothing cleared, if it was let go too soon.
      def let_go(by)
        @credits_drag = nil if @credits_drag&.first == by
        @clearing = clearing.release(by, now)
        @groups.let_go(by, now)
      end

      # Whatever holds "Clear my stats…" stops, with nothing cleared, as
      # when the window loses focus and a release may never be heard.
      def let_go_of_everything
        @clearing = clearing.cancel
        @groups.cancel_hold
      end

      # Where a press reaches "Clear my stats…" and Undo on the Records
      # screen, as the title's buttons do.
      def clear_reach = reach_of(:clear)
      def undo_reach = reach_of(:undo)

      # The gamepad button that holds "Clear my stats…", for its words.
      def holding_button = clearing.by == :y ? "Y" : "A"

      # A gamepad's Y, or a tap on "Share my score": on Game Over, offers
      # the game's result to share (+sharing+), which in the game opens
      # the share preview, and copies nothing yet; on a phone it opens the
      # system's share sheet, and no preview. In the preview, Y
      # copies, as Copy does. Anywhere else it does nothing.
      def share
        return copy_result if sharing?
        return unless game_over? && game_over

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

        ShareScreen.new(layout:, type: style::TYPE, words:, measure: @measure, style: style::SHARE_PREVIEW,
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

      # Where a tap reaches "Your stats": never less than a dot's width
      # where it has room, and never past the safe area's bottom.
      def stats_reach = reach_of(:stats)

      # Where a tap reaches the Stats screen's Back.
      def back_reach = reach_of(:back)

      # Where a tap reaches each segment of the dot-size choice, as a
      # DotSizing and its Rect, while the title offers it.
      def sizing_reaches = SIZINGS.map { [it, reach_of(it)] }

      # Where the title's words and buttons go (TitlePlan). Play is sized
      # from dots fitted to the screen, whichever size is chosen, so the
      # Dot size choice beside it never moves or resizes it.
      def title_plan
        goal = stats_book.goal_done? ? words.goal_done_line(stats_book.goal) : words.goal(stats_book.goal) if played?
        planned(TitleScreen.new(layout:, type: style::TYPE, words:, measure: @measure, score_record: marquee.score_record, goal:,
                                done: stats_book.goal_done?, streak: stats_book.streak, stats: stats_offered?,
                                sizing: sizing_offered?, radius: DotSize.fitted(layout.width, layout.height).radius,
                                window: window.offered?, games: games_line))
      end

      # What the title says of the games left, or nil where none are counted.
      def games_line = (words.games_left(games.left) if games.metered?)

      # Where Game Over's words and "Share my score" go (FinalePlan), or
      # nil away from Game Over.
      def game_over_plan = game_over_screen&.then { planned(it) }

      # The plan of +screen+ (a TitleScreen or a FinaleScreen), laid out
      # again only when the screen differs from the last of its kind, since
      # laying one out measures every line, a millisecond a frame on a
      # phone, and each frame asks for it more than once.
      def planned(screen)
        last = @plans[screen.class]
        return last.last if last&.first == screen

        (@plans[screen.class] = [screen, screen.plan]).last
      end

      # Game Over's words to lay out (FinaleScreen), or nil away from it.
      def game_over_screen
        return unless game_over

        GameOverScreen.new(layout:, type: style::TYPE, words:, measure: @measure, scrim: style::GAME_OVER_BACKING, game_over:,
                         below: hud_bottom, radius: cabinet.game&.field&.radius || @radius, group_line: @groups.game_line)
      end

      # The window changed size. The title's dots are respawned if their
      # size changes with it, as dots sized to the screen do.
      def resize(layout, field)
        @layout = layout
        @tutorial&.refit(Field.new(field.width, field.height, @tutorial.field.radius))
        lay_out_credits if credits?
        @attract = field.radius == attract.field.radius ? attract.refit(field) : Attract.spawn(field, style::TITLE)
      end

      def update(seconds)
        @now += seconds
        @groups.update(now, quiet: !playing?, showing: (title? && !stats?) || game_over?)
        follow_store(seconds) unless playing?
        clear_stats if clearing.done?(now)
        @undo = nil unless @undo&.open?(now)
        @hover = hover.at(hovered).update(seconds, style::HOVER)
        effects.update(seconds)
        follow_tutorial(seconds) if tutorial?
        @attract = attract.update(seconds) if title?
        follow_game if cabinet.game
        follow_game_over if game_over?
      end

      # Hears one of the rules' events (Cabinet#subscribe).
      def call(event)
        @achievement_watch.call(event)
        case event
        when Events::GameStarted then game_started(event)
        when Events::Popped then popped(event)
        when Events::Penalized then penalized(event)
        when Events::Missed then effects.ring(event.x, event.y, style::TOUCH_RIPPLE)
        when Events::GameEnded then game_ended(event)
        when Events::TitleShown then title_shown(event)
        end
      end

      private

      # The one way into a real game: Play, Skip, and the Tutorial's end
      # all come through here. It spends a game (FreeGames) and starts it
      # with the block; with none left, the offer of Pro opens instead.
      def with_a_game
        return offer_for_play unless games.spend!

        yield
      end

      def start_game = with_a_game { cabinet.press(layout.center_x, layout.center_y) }

      # Opens the offer straight from the title, as Play does when no play
      # is left; Back from it returns to the title.
      def offer_for_play
        return unless title? && offer_offered?

        @stats = stats_sheet
        @offer_for_play = true
        open_offer
      end

      # Plays the Tutorial on the field a game would start on, and sizes
      # the effects to its dots.
      def open_tutorial
        @tutorial_flag.seen!
        field = cabinet.field
        effects.clear
        effects.scale_to(field.radius)
        @tutorial = Tutorial.new(field:, center: [layout.center_x, layout.center_y], effects:, sounds:,
                                 haptics: @haptics, style:, now:, random: @random, calm: @calm, palette:)
      end

      # A tap in the Tutorial: its skip button, or the scene's.
      def tutorial_tap(x, y)
        return skip_tutorial if control_at(x, y)&.name == :skip

        @tutorial.tap(x, y)
      end

      # The Tutorial moves on, and once it is over, the game goes on from
      # exactly where it left its dots, score, time and row (Cabinet#resume), and
      # only its clock starts, lit as it starts to run (LeadIn).
      def follow_tutorial(seconds)
        @tutorial.update(seconds)
        return unless @tutorial.over?

        scene, @tutorial = @tutorial, nil
        effects.clear unless games.can_play?
        with_a_game { go_on_from(scene) }
      end

      def go_on_from(scene)
        @handing_over = scene
        cabinet.resume(field: scene.field, dots: scene.dots, score: scene.score, seconds: scene.seconds,
                       dots_in_a_row: scene.dots_in_a_row)
        @lead_in = LeadIn.new(at: now, style: style::TUTORIAL.lead)
      end

      # The HUD reads the game. While the Tutorial's lead-in lights the
      # clock, its first second down ticks, as the urgent ones do.
      def follow_game
        before = hud.seconds
        @hud = hud.read(cabinet.game, now) { tick(it) if playing? }
        beckon
        @lead_in = nil if @lead_in&.over?(now)
        return unless @lead_in && playing? && before && hud.seconds < before && now - @penalized_at >= 0.1

        sounds.play(:tick)
      end

      def group_controls = group_plan.controls.map { |name, frame| button(name, frame) }

      def title_controls
        plan = title_plan
        buttons = [Control.new(name: :mute, reach: layout.mute_button)]
        buttons << button(:group_open, group_button) if group_offered?
        buttons << button(:how_to_play, plan.how_to_play_button)
        buttons << button(:stats, plan.stats_button) if stats_offered?
        if (window_buttons = plan.window_buttons)
          buttons << button(:fullscreen, window_buttons.fullscreen) << button(:quit, window_buttons.quit)
        end
        buttons.concat(SIZINGS.zip(plan.sizing_control.options).map { button(*it) }) if sizing_offered?
        buttons << primary_button(:play, plan.play_button) if plan.play_button
        buttons
      end

      def share_controls
        plan = share_plan
        [button(:close, plan.close), button(:copy, plan.copy)]
      end

      def game_over_controls
        plan = game_over_plan or return []
        [(button(:share, plan.share_button) if plan.share_button),
         (primary_button(:continue, plan.continue_button) if plan.continue_button)].compact
      end

      # The Credits text broken into lines for this screen, and the scroll
      # kept at the same place on it.
      def lay_out_credits
        page = credits_layout
        key = [page.text_size, page.room]
        if @credits_lines&.first != key
          @credits_lines = [key, CreditsLines.set(credits_book, size: page.text_size, room: page.room, line: style::CREDITS.line,
                                                  measure: @measure)]
        end
        @credits = @credits.fitted(content: credits_lines.height, window: page.window.height)
      end

      def arrival_controls
        plan = arrival_plan
        [button(:arrival_later, plan.later_button), button(:arrival_wear, plan.wear_button)]
      end

      # The player has answered the news of a new theme. A Pro player's
      # switch wears it at once; a Free player's opens the offer, the same
      # as tapping Themes.
      def answer_arrival(wear:)
        theme = arrival
        return unless theme

        @theme_keeper.told(theme)
        if !wear then sounds.play(:tick, pitch: 0.8)
        elsif themes_locked? then open_offer_for(:themes)
        else
          @theme_keeper.wear(theme)
          sounds.play(:tick, pitch: 1.2)
        end
      end

      def themes_controls
        themes_layout.cards.map { button(it.theme, it.rect) } << button(:back, layout.back_button)
      end

      def offer_controls
        plan = offer_plan
        [(button(:buy, plan[:buy]) if plan.key?(:buy)),
         (button(:restore, plan[:restore]) if plan.key?(:restore)),
         button(:back, layout.back_button)].compact
      end

      # Hears the store, outside a game; a tick marks the purchase landing
      # while the offer is open.
      def follow_store(seconds)
        free = !@entitlement.pro?
        @storefront.update(seconds)
        sounds.play(:tick, pitch: 1.3) if free && offer? && @entitlement.pro?
      end

      # Where the achievements are on the Stats screen, which a Free player
      # taps to ask for Pro, or nil for a Pro player or where they are not listed.
      def achievements_frame
        return if @entitlement.pro? || !stats? || stats.empty || stats.achievements.nil?

        stats_layout.achievements_frame
      end

      def stats_controls
        [(button(:credits, layout.credits_button)),
         (button(:themes, layout.themes_button) if themes_offered?),
         (button(:offer, layout.offer_button) if offer_offered?),
         (button(:achievements, achievements_frame) if achievements_frame),
         (button(:undo, layout.undo_button) if undo_offer),
         (button(:clear, layout.clear_stats_button) if clear_offered?),
         button(:back, layout.back_button)].compact
      end

      # A button drawn at +frame+, which a press reaches within a dot's
      # width, short of the safe area's bottom.
      def button(name, frame) = Control.new(name:, frame:, reach: within_safe(frame.reach(2 * @radius)))

      # A screen's main button, which a press reaches more generously.
      def primary_button(name, frame) = Control.new(name:, frame:, reach: layout.primary_reach(frame, cabinet.field.radius))

      def hold_clear(by)
        @clearing = clearing.press(by, now)
        sounds.play(:tick, pitch: 0.7)
      end

      # "Clear my stats…" was held long enough: the records go, and Undo
      # is offered.
      def clear_stats
        @clearing = clearing.cancel
        @undo = UndoOffer.new(cleared: @keeper.clear, at: now, seconds: style::RECORDS_CLEAR.undo)
        stats_changed
        sounds.play(:bonk, pitch: 0.7)
        @haptics.buzz(style::HAPTICS.penalty)
      end

      def undo
        @keeper.restore(@undo.cleared)
        @undo = nil
        stats_changed
        sounds.play(:tick, pitch: 1.2)
      end

      # The records changed under the Stats screen: it, and the title's
      # best, show them as they are now.
      def stats_changed
        @stats = stats_sheet if stats?
        @marquee = marquee.with(score_record: cabinet.score_record.of(cabinet.size_class))
      end

      def stats_sheet
        size_class = cabinet.size_class
        StatsSheet.build(stats_book.stats, score_record: cabinet.score_record.of(size_class), words:, streak: stats_book.streak,
                           size_class:, field: cabinet.field, sizing: cabinet.sizing, achievements: @achievements,
)
      end

      # Where the HUD's pill ends, at the safe area's top.
      def hud_bottom
        type = style::TYPE
        layout.top + Hud.height(@measure.height(:bold, layout.scaled(type.hud_number)),
                                @measure.height(:semibold, layout.scaled(type.hud_label)))
      end

      def within_safe(reach) = reach.with(height: [reach.height, layout.safe.bottom - reach.y].min)

      # A game begins: afresh, its dot growing in, or, from the Tutorial,
      # with the scene's dots as they were drawn, their animations, its
      # effects still playing, and its HUD, so nothing on screen jumps.
      def game_started(event)
        scene, @handing_over = @handing_over, nil
        @scale = event.game.field.radius
        effects.scale_to(@scale)
        if scene
          @animations = scene.animations
          @hud = scene.hud.with(words:)
        else
          effects.clear
          animations.clear
          @hud = Hud.blank(style::HUD, words)
          event.game.dots.each { animations.spawn(it.id, now) }
        end
        @tutorial_game = !scene.nil?
        @groups.game_started
        @game_over = nil
        @preview = nil
        @mistake = nil
        @undo = nil # the game's records would be lost to an undo
        @lead_in = nil
        @beckoned_at = nil
        sounds.play(:start)
      end

      def popped(event)
        dot = event.dot
        animations.pop(dot.id, now)
        animations.spawn(event.spawned.id, now)
        effects.burst(event.x, event.y, style::POP_BURST, palette.confetti)
        effects.ring(dot.x, dot.y, style::SHOCKWAVE, follow: dot.id)
        effects.ring(event.spawned.x, event.spawned.y, style::SPAWN_RIPPLE, follow: event.spawned.id)
        float_pair(event.x, event.y, Words.points(event.points), Words.seconds(event.seconds),
                   palette.cream, palette.gain, style::GAIN_FLOAT)
        sounds.play(:pop, pitch: pop_pitch, pan: pan(event.x))
        @haptics.buzz(style::HAPTICS.pop)
        bonus_popped(event) if dot.bonus?
        bonus_earned(event.spawned) if event.spawned.bonus?
      end

      # The row's payoff: a larger burst and a second, wider shockwave
      # over the pop's own, and a chord.
      def bonus_popped(event)
        effects.burst(event.x, event.y, style::BONUS_BURST, style::BONUS_CONFETTI)
        effects.ring(event.dot.x, event.dot.y, style::BONUS_SHOCKWAVE, follow: event.dot.id)
        sounds.play(:bonus_pop, pan: pan(event.x))
        @haptics.buzz(style::HAPTICS.penalty)
      end

      # The row's result: the bonus dot arrives in place of the ordinary
      # one, in a wide ripple and a chime, and keeps a ring pulsing about
      # it (#beckon).
      def bonus_earned(dot)
        effects.ring(dot.x, dot.y, style::BONUS_RIPPLE, follow: dot.id)
        sounds.play(:bonus, pan: pan(dot.x))
        @beckoned_at = now
      end

      # While a bonus dot waits, a mint ring pulses about it every so often.
      def beckon
        return unless @beckoned_at && playing? && now - @beckoned_at >= style::BONUS_BEACON_EVERY

        dot = cabinet.game.dots.find { it.fresh? && it.bonus? } or return @beckoned_at = nil
        @beckoned_at = now
        effects.ring(dot.x, dot.y, style::BONUS_BEACON, follow: dot.id)
      end

      def penalized(event)
        @penalized_at = now
        animations.wobble(event.dot.id, now)
        effects.ring(event.dot.x, event.dot.y, style::ALARM_RING, follow: event.dot.id)
        hidden = cabinet.game.dots.fresh_beneath(event.dot, event.x, event.y)
        effects.reveal(hidden, style::REVEAL) if hidden
        @mistake = Mistake.new(popped: event.dot.id, bright: hidden.id) if hidden
        effects.kick(style::PENALTY_SHAKE)
        effects.light(style::PENALTY_FLASH)
        # The floor can keep the score from falling; say only what was lost.
        points = event.points.zero? ? nil : Words.points(event.points)
        float_pair(event.x, event.y, points, Words.seconds(event.seconds), palette.alarm, palette.alarm,
                   style::LOSS_FLOAT)
        sounds.play(:bonk, pan: pan(event.x))
        @haptics.buzz(style::HAPTICS.penalty)
      end

      # The finished game's result, as Words#share_text says it.
      def share_text
        words.share_text(game_over.score, game_over.stats, score_record: game_over.score_record, new_score_record: game_over.new_score_record?,
                         record: game_over.record, screen: game_over.screen, first: game_over.first)
      end

      def game_ended(event)
        result = stats_book.record(game_stats, event.size_class)
        @groups.game_finished(score: event.score, sized_to_screen: event.size_class == SizeClass::FITTED && !@tutorial_game)
        achievements = @achievements.award(@achievement_watch.earned, day: stats_book.today.iso8601)
        achievements = [] unless @entitlement.pro? # kept, and shown once Pro is bought
        lesson = @tutor.lesson(@mistake) if @mistake&.among(event.game.dots)
        @game_over = GameOver.new(style: style::GAME_OVER, score: event.score, score_record: event.score_record, new_score_record: event.new_score_record, at: now,
                             stats: game_stats, record: result.records.first, goal_met: result.goal_met, lesson:, achievements:,
                             first: event.first, screen: words.played_on(event.game.field, sized: event.size_class == SizeClass::FITTED))
        sounds.play(event.new_score_record ? :new_score_record : :game_over)
      end

      def title_shown(event)
        @theme_keeper.refresh
        @stats = nil
        @themes = false
        @groups.close if group_open?
        @credits = nil
        @clearing = clearing.cancel
        effects.clear
        @game_over = nil
        @preview = nil
        @marquee = Marquee.new(style: style::TITLE, score_record: event.score_record, at: now)
      end

      # A tap on the title away from its buttons: a fresh dot there pops
      # for fun, with no score; anywhere else, nothing happens.
      def toy_tap(x, y)
        return unless title? && !stats? && !group_open?

        dot = attract.dots.top_at(x, y)
        toy_pop(dot, x, y) if dot&.fresh?
      end

      # One of the title's dots, popped by a tap: its droplets, its ring,
      # and its bloop, but no score.
      def toy_pop(dot, x, y)
        effects.burst(x, y, style::POP_BURST, palette.confetti)
        effects.ring(dot.x, dot.y, style::SHOCKWAVE)
        sounds.play(:pop, pan: pan(x))
      end

      # One floater to the left and one to the right of the tap; with only
      # one, it sits over the tap.
      def float_pair(x, y, left, right, left_color, right_color, float)
        spread = style::FLOAT_SPREAD * @scale
        spread = 0.0 unless left && right
        effects.float(left, x - spread, y, left_color, float) if left
        effects.float(right, x + spread, y, right_color, float) if right
      end

      # Where across the stereo field a sound at +x+ plays.
      def pan(x) = style::SOUND.stereo.pan(x, layout.width)

      def pop_pitch
        sound = style::SOUND
        [1.0 + (cabinet.game.score * sound.pop_climb), sound.pop_highest].min
      end

      def tick(seconds)
        return if now - @penalized_at < 0.1

        sounds.play(:tick, pitch: 1.0 + ((style::HUD.urgent_below - seconds) * style::SOUND.tick_climb))
        effects.light(style::TICK_FLASH)
      end

      def follow_game_over
        @game_over = game_over.ready(now) if cabinet.state.ready?
        replay_mistake if game_over.lesson && game_over.counted?(now) &&
                       style::LESSON.replay_due?(game_over.replayed, now - game_over.at - style::GAME_OVER.tally.duration)
        goal_burst if game_over.goal_due?(now)
        return unless game_over.celebration_due?(now)

        @game_over = game_over.celebrate
        celebrate
      end

      # The stacking rule, taught with no word: the wrong tap the game
      # ended up teaching (Mistake) replays on the pile as it played, the
      # popped dot's shudder and alarm ring and the dashed outline of the
      # bright dot under it, and the bright dot pulses gently. Its effects
      # follow both dots wherever the pile has them, are only outlines, so
      # they hide no dot, and the screen never shakes.
      def replay_mistake
        mistake = game_over.lesson
        @game_over = game_over.replay
        dots = cabinet.game.dots
        popped, bright = [mistake.popped, mistake.bright].map { |id| dots.find { it.id == id } }
        animations.wobble(popped.id, now)
        effects.ring(popped.x, popped.y, style::ALARM_RING, follow: popped.id)
        effects.reveal(bright, style::REVEAL)
        effects.ring(bright.x, bright.y, style::SPAWN_RIPPLE, follow: bright.id)
      end

      # A small burst of twinkles where "You met today's goal!" appears.
      def goal_burst
        @game_over = game_over.goal_celebrate
        sounds.play(:tick, pitch: 1.5)
        line = game_over_plan[:goal] or return
        effects.burst(line.center_x, line.center_y, style::GAME_OVER.goal_sparkles, palette.confetti,
                      longest: style::GAME_OVER.sparkle_life)
      end

      def celebrate
        sparkles = style::GAME_OVER.sparkles
        [0.3, 0.5, 0.7].each do |across|
          effects.burst(layout.safe.x + (layout.safe.width * across), layout.top + (layout.safe.height * 0.2),
                        sparkles, palette.confetti, longest: style::GAME_OVER.sparkle_life)
        end
      end
    end
  end
end
