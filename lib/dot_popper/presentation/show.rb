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
    # +haptics+ answers buzz(seconds). +stats_book+ (StatsBook) adds up every
    # game the device has played. +sizing_store+ keeps the player's
    # DotSizing, chosen on Home. +radius+ is the usual dot's, which
    # sizes the buttons' reach; a game's effects follow its own dots.
    # +input+ (InputKind) is what the player last pressed with, and the
    # words follow it. +keeper+ (StatsKeeper) clears Stats, from
    # the Stats screen, and puts them back. +measure+ sizes the screens' words (RoughMeasure's
    # methods). +sharing+ (InGameSharing's methods) offers Game
    # Over's result to share, in a preview or a phone's own sheet, and
    # +clipboard+ takes it when the player copies it. +achievements+
    # (Achievements) keeps the achievements a game earns, as it ends, and the
    # Stats screen lists them once the +entitlement+ says the pro
    # version was bought. +tutorial_flag+
    # (TutorialFlag) says whether Play opens the Tutorial first. +window+
    # (NoWindowControl's methods) is the desktop's window, which
    # Home's "Full screen" and Quit switch and close where it offers them.
    # +games+ (FreeGames) counts the games a free player may start: Play
    # spends one, and with none left leads to the offer of Pro.
    class Show
      # The dot-size choices in the order Home draws their segments:
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
                     groups: Groups::Session.off, storefront: NoStorefront.new, games: FreeGames.unlimited, links: NoLinks.new,
                     group_notice: GroupNotice.read, server_choice: nil,
                     use_theme: UseCases::UseTheme.new(themes: theme_keeper, entitlement:))
        @cabinet = cabinet
        @server_choice = server_choice
        @window = window
        @links = links
        @tutorial_flag = tutorial_flag
        @entitlement = entitlement
        @theme_keeper = theme_keeper
        @achievements = achievements
        @achievement_watch = AchievementWatch.new
        @groups = GroupPanel.new(groups:, joining: UseCases::JoinFriendGroup.new(groups:, entitlement:), sounds:, pro_offer: ->(feature) { open_offer_for(feature) }, notice: group_notice,
                                shown: ->(open) { open ? open_layer(:friend_groups) : close_layer(:friend_groups) })
        @groups.copy = ->(text) { clipboard.copy(text) }
        @offer_focus = nil
        @storefront = storefront
        @games = games
        @start_game = UseCases::StartGame.new(cabinet:, free_games: games)
        @finish_game = UseCases::FinishGame.new(stats_book:, achievements:, entitlement:, friend_groups: groups)
        @use_theme = use_theme
        @view_achievements = UseCases::ViewAchievements.new(achievements:, entitlement:, stats_book:, score_record: cabinet.score_record)
        @buy_pro = UseCases::BuyPro.new(store: storefront, entitlement:, cabinet:, achievements:, friend_groups: groups)
        entitlement.subscribe(->(granted) { pro_arrived(granted) })
        @layers = [] # the screens open over the game's state, the top one last
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
        @calm = calm
        @effects = Effects.new(radius:, random:, calm:)
        @animations = DotAnimations.new(style::MOTION)
        @hud = Hud.blank(style::HUD, words)
        @attract = Attract.spawn(cabinet.field, style::HOME)
        @now = 0.0
        @marquee = Marquee.new(style: style::HOME, score_record: cabinet.score_record.of(cabinet.size_class), at: @now)
        @game_over = nil
        @tutor = tutor
        @clipboard = clipboard
        @sharing = sharing
        @mistake = nil
        @penalized_at = -Float::INFINITY
        @beckoned_at = nil
        @recorder = GameStats::Recorder.new
        @stats = nil
        @credits = nil
        @credits_drag = nil
        @keeper = keeper
        @clearing = HoldToConfirm.idle(style::STATS_CLEAR.hold)
        @undo = nil
        @pointer = nil
        @hover = Hover.none
        @screens = Screens.made_for(self, clipboard:)
        cabinet.subscribe(@recorder)
        cabinet.subscribe(self)
      end

      # The screen on top, which every press, button, key and scroll asks
      # (Screens), and the renderer draws: the one place that decides it.
      # It is the last screen opened over the others, or with none open,
      # the screen for the game's state.
      def screen = @layers.last || state_screen

      # The screens open over the screen for the game's state, the top
      # one last, for the renderer to draw.
      attr_reader :layers

      # The screen for Cabinet's state, under any opened over it: Home,
      # or the card telling of a new theme over it; the Tutorial over the
      # paused game; a game; or Game Over.
      def state_screen
        if tutorial? then @screens[:tutorial]
        elsif home? then arrival? ? @screens[:new_theme] : @screens[:home]
        elsif game_over? then @screens[:game_over]
        else @screens[:game]
        end
      end

      # The usual dot's radius, which sizes the buttons' reach.
      attr_reader :radius

      # The numbers of the game in play, or of the one just finished.
      def game_stats = @recorder.stats

      # The colors of the theme in use (ThemeKeeper), which only changes
      # between games.
      def palette = in_use.palette

      # Whether the Themes screen is open over the Stats screen, and what
      # it shows: every theme the player can use, and the one in use.
      def themes? = page == :themes

      # The new theme to tell the player of, once, at Home, when nothing
      # else is asked of them; nil the rest of the time.
      def arrival = (@theme_keeper.arrival if on_home?)
      def arrival? = !arrival.nil?
      # Whether the card for this theme has been up ARRIVAL_GRACE since it
      # first appeared, so a press meant for Home as it came answers nothing.
      def arrival_settled? = @arrival_seen&.first == arrival&.key && now - @arrival_seen.last >= style::ARRIVAL_GRACE
      def arrival_plan = ArrivalPlan.new(layout:, word: (arrival_use_word if arrival?), measure: @measure)

      # The switch's word: a Free player's is "Get Pro", since it opens the offer.
      def arrival_use_word = themes_locked? ? words.offer.fetch(:entry) : format(words.themes.fetch(:use), words.themes.fetch(arrival.key))
      def themes = @theme_keeper.shown
      def in_use = @use_theme.current

      # Whether tapping a theme leads to Pro, as it does for a Free player;
      # whether +theme+ is one this player has earned; and whether it is open
      # to use, earned or in season. They show the same to either player.
      def themes_locked? = @use_theme.locked?
      def theme_earned?(theme) = @theme_keeper.earned?(theme)
      def theme_open?(theme) = @theme_keeper.open?(theme)

      # Whether the Stats screen offers Themes: always, the same to a Free
      # player and a Pro one.
      def themes_offered? = true

      # Where the Themes screen's cards go (LooksLayout).
      def themes_layout = ThemesLayout.new(layout:, themes: themes, style: style::THEMES_LAYOUT)

      def open_themes = open_page(:themes)
      def close_themes = close_page

      # Uses +theme+ from now on, and the whole screen takes its colors at
      # once, so the choice is seen before it is left.
      def use(theme)
        return unless themes?

        case @use_theme.call(theme)
        in :offer then open_offer_for(:themes)
        in :same then sounds.play(:tick, pitch: 0.8)
        in :used then sounds.play(:tick, pitch: 1.2)
        end
      end

      # The player pressed with +kind+ (InputKind): from now on the words
      # say what to do with it.
      def input=(kind)
        @key_hint = nil # a pointer or a controller took over from the keyboard
        return if kind == input

        @input = kind
        @words = style::WORDS.for(kind)
      end

      # Whether Home is showing.
      def home? = cabinet.state.is_a?(Cabinet::Home)

      # Whether the Tutorial is playing (#tutorial) over the game, which is
      # paused meanwhile (Cabinet::Paused), so its clock is not running,
      # and no tap reaches it but the ones the Tutorial passes on; once it
      # ends, or is skipped, the game plays on from the state it is in.
      def tutorial? = !@tutorial.nil?

      # Whether the Stats screen is open over Home. It is the
      # presentation's alone: the game stays on its title meanwhile, and
      # no tap there reaches the game.
      def stats? = page == :stats

      # Home itself, with no other screen open over it.
      def on_home? = home? && @layers.empty?

      # The screen open over Home (Screens::Page), by the name
      # Screens.made_for gives it, or nil: the topmost, as Credits, Privacy
      # and Change Server open over Settings.
      def page
        at = @layers.rindex { it.is_a?(Screens::Page) } or return
        @screens.key(@layers[at])
      end

      # The Achievements screen, the achievement open in its dialog (or
      # nil), Settings, and Privacy.
      def achievements_open? = page == :achievements
      def dialog = (@screens[:achievement_dialog].achievement if layer?(:achievement_dialog))
      def settings? = page == :settings
      def privacy? = page == :privacy

      # The friend groups' screens' state and their announcements (GroupPanel).
      def group_panel = @groups

      # Whether the Friend group screen is open over Home.
      def group_open? = @groups.open?

      # Where the Friend group screen's parts go, while it is open.
      def group_plan
        where = [@groups.page, @groups.group_id]
        @scroll = nil unless @group_scroll_at == where
        @group_scroll_at = where
        plan = GroupScreen.new(layout:, style: style::GROUPS, measure: @measure, panel: @groups, standard_dots: !cabinet.sizing.sized_to_screen?,
                               back_text: words.go_back, offset: @scroll&.offset || 0.0, input:).plan
        list_fit(plan.content, plan.window.height) if plan.window
        plan
      end

      # Where the notice of a first Join or Create puts its parts, while it
      # is open over the friend groups' screen (GroupNoticePlan), or nil.
      def group_notice_plan
        return unless group_open? && @groups.asking && !offer?

        GroupNoticeDialog.new(layout:, measure: @measure, policy_text: group_word(GroupWords.notice_policy),
                              later_text: group_word(GroupWords.notice_later), go_text: group_word(GroupWords.notice_go(@groups.asking))).plan
      end

      # A friend groups' word (a ByInput), said as the player's input would
      # press it.
      def group_word(word) = word.for(input)

      # Whether Home offers the way in to groups: where there is a
      # server, once a game has finished, or for someone in a group.
      def group_offered? = @groups.available?

      # Where an announcement goes: under the HUD at Game Over, and at
      # the top of Home, clear of the Group button's row.
      def banner_y = layout.top

      # What the Stats screen shows, while it is open.
      def stats = @stats

      # The Stats screen laid out for the fonts this screen is measured with.
      def stats_layout
        StatsLayout.measured(layout:, sheet: stats, style: style::STATS, measure: @measure)
      end

      # Whether Home offers "Your stats" and the choice of dot size:
      # only once a game has finished, so a first-time player's title says
      # only how to play. A player who cleared their Stats has played, so
      # it still offers them, though it shows no score record or goal until their
      # next game (#played?).
      def stats_offered? = played? || @keeper.cleared?

      # Whether a game has finished since Stats were last cleared:
      # the title shows today's goal only then.
      def played? = stats_book.stats.games.positive?

      # What stands under Stats' heading where the two dot sizes differ:
      # "Stats for smaller dots".
      def stats_note
        return unless sizing_offered?

        "Stats for #{words.sizing(cabinet.sizing, sizing_preview).downcase} dots"
      end

      # Whether the Stats screen offers "Clear my stats…": while it has
      # Stats to clear, and no Undo is offered.
      def clear_offered? = stats? && !stats.empty && !undo_offer

      # Undo, while it is offered on the Stats screen (UndoOffer), or nil.
      def undo_offer = (@undo if stats?)

      # What the choice of dot size would do on this screen, worked out
      # afresh each time, so a resized window is always seen as it is now.
      def sizing_preview = SizingPreview.of(cabinet.screen, style::SIZING)

      # Whether Home offers the choice of dot size: once a game has
      # finished, and only where the two sizes look different. Where they
      # look alike, the saved choice stays as it was, and games follow it.
      def sizing_offered? = sizing_preview.offered?
      def playing? = cabinet.playing?
      def game_over? = cabinet.state.is_a?(Cabinet::GameOver)

      # A tap at +x+, +y+, by +by+ (a finger's id, :mouse, or :gamepad),
      # which #let_go names when it lets go. In a game, every tap goes to
      # the game at once. Elsewhere a tap presses the screen's button under
      # it (#controls): on Home, Play, the mute button, "How to play",
      # "Your stats", the dot-size choice, and on a desktop "Full screen"
      # and Quit; on Game Over, Play again, Home and
      # "Share my score", and over it, the share preview's Copy and Close;
      # and on the
      # Stats screen, Back, Undo, or "Clear my stats…", which a press
      # starts holding. Empty space does nothing, but a tap on one of
      # Home's bright dots pops it, for fun, and a tap away from the share
      # preview's card closes it. A gamepad's A, which aims at no button,
      # presses the screen's main one (#primary).
      def tap(x, y, by: :tap) = screen.tap(x, y, by)

      # A key typed on a keyboard (+key+, as Shell::LotaInput names it)
      # that the screen on top takes as its own: the keypad's digits that
      # join a friend group, a license key on the offer, H on Home and C on
      # Settings. Says whether it took it.
      def type_key(key) = screen.type(key)

      # A key typed into the offer of a copy that takes a license key, on a
      # computer: Paste license key's other way in (WebsiteStore#type).
      def typed_license_key(key) = @buy_pro.type(key)

      # What a press does on the screen on top: the control +name+, or
      # with none, empty space at +x+, +y+ (Screens::Screen#press).
      def press(name, x, y, by) = screen.press(name, x, y, by)

      # The buttons this screen offers (Control), each where it is drawn
      # and where a press reaches it, no two reaching the same point, so a
      # press reaches one button. Taps and the mouse's hover both go by
      # these.
      def controls = Control.apart(screen.controls)

      # The button a press at +x+, +y+ reaches (Control), or nil; on an
      # edge two reaches share, the one drawn nearer.
      def control_at(x, y) = controls.select { it.reach.contains?(x, y) }.min_by { it.distance(x, y) }

      # Where a press reaches the button named +name+ on this screen, or
      # nil when it is not offered.
      def reach_of(name) = controls.find { it.name == name }&.reach

      # Presses this screen's main button, as Enter, Space, a gamepad's
      # Start, or its A aimed at no button do: Play on Home, Back on
      # the Stats screen and the Pro offer (Buy has only its own button),
      # Play again on Game Over, once its grace is over, and Copy in the
      # share preview. In a game it does nothing, since
      # only a press at a place may touch the score.
      def primary = screen.primary

      # Home's Play: a game starts, or on a first Play, a game with
      # the Tutorial over it (TutorialFlag), which is seen from then on.
      def play
        return unless on_home?
        return open_tutorial if @tutorial_flag.due?(played: stats_offered?)

        offer_for_play if @start_game.call == :none_left
      end

      # Home's "How to play", H, or a gamepad's Y there: a game with
      # the Tutorial over it, at once, whether it was seen or not, as on a
      # first Play.
      def how_to_play
        open_tutorial if on_home?
      end

      # The Tutorial's skip button, Escape, or a gamepad's B: the Tutorial
      # goes, showing at once what it had yet to show of the game, and the
      # game plays on from the state it is in. Nothing starts or ends: the
      # game began when the Tutorial opened.
      def skip_tutorial
        return unless tutorial?

        @tutorial.catch_up
        play_on
      end

      # Where a tap reaches the Tutorial's skip button, where it is drawn.
      def skip_reach = reach_of(:skip)

      # Game Over's Home: back Home, once the game will hear a press
      # (Rules::GAME_OVER_GRACE).
      def continue_on
        cabinet.press(layout.center_x, layout.center_y) if game_over?
      end

      # Game Over's Play again: Home, and at once Play, so another game is
      # one press. With no game left it says Get Pro, and opens the offer
      # over Game Over, which Back closes to Game Over as it was.
      def play_again
        return unless game_over? && cabinet.state.ready?
        return offer_over_game_over if @start_game.none_left? && offer_offered?

        continue_on
        play
      end

      def offer_over_game_over
        @offer_for_play = true
        open_offer
        @offer_focus = :games
      end

      # One of Game Over's lines that opens something: a new achievement
      # in its dialog, or the friend group whose title the game took.
      def open_from_game_over(what)
        return unless game_over? && cabinet.state.ready?

        achievement = game_over.achievements.first
        group = @groups.game_title_taken
        continue_on
        case what
        when :achievement
          open_achievements
          open_achievement(achievement) if achievement
        when :group then group ? @groups.open_at(group) : @groups.open
        end
      end

      # Game Over's lines in pills of their own (GameOverChip): today's
      # goal met, a new achievement, which opens it, and what the game did
      # in the friend groups, which opens the group whose title it took.
      def game_over_chips
        over = game_over or return []
        group = @groups.game_line.to_s.strip
        [(GameOverChip.new(name: :over_goal, text: words.goal_met, glyph: :check, opens: false) if over.goal_met),
         (GameOverChip.new(name: :over_achievement, text: AchievementWords.earned(over.achievements), glyph: :achievement, opens: true) if over.achievements.any?),
         (GameOverChip.new(name: :over_group, text: group, glyph: :crown, opens: !@groups.game_title_taken.nil?) unless group.empty?)].compact
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
      def waits_for_release?(x, y) = screen.waits_for_release?(x, y)

      # A gamepad's Start: the screen's main button (#primary), except on
      # a friend group, where holding it leaves the group (GroupPanel#start).
      def start = screen.start

      QUIT_ASK = 2.0 # seconds a second B has to quit from the title

      # B on Home, where a controller has no other way to quit: the
      # first press asks, and :quit if a second comes within QUIT_ASK
      # seconds, so a stray press never closes the game.
      def ask_to_quit
        return unless on_home?
        return :quit if quit_asked?

        @quit_asked_at = now
        sounds.play(:tick, pitch: 0.8)
        :asked
      end

      # How much of "Press B again to quit" shows: all of it while a second
      # press would quit, fading out in its last third of a second.
      def quit_prompt
        return 0.0 unless quit_asked? && home?

        ((QUIT_ASK - (now - @quit_asked_at)) / 0.3).clamp(0.0, 1.0)
      end

      def quit_asked? = @quit_asked_at && now - @quit_asked_at <= QUIT_ASK

      # Escape, Android's Back, or a gamepad's B: closes the share
      # preview, leaves the Stats screen, and goes on from Game Over to
      # Home, as its Home button does. Says whether there was somewhere to go
      # back from, so that elsewhere the key can do its usual job.
      def back = screen.back

      # Sizes dots as +sizing+ (DotSizing) says, on Home while it
      # offers the choice, and remembers it. Home's dots and score record
      # change with it, so the choice shows at once.
      def choose_sizing(sizing)
        return unless settings? && sizing_offered?
        return sounds.play(:tick, pitch: 0.8) if sizing == cabinet.sizing

        cabinet.sizing = sizing
        @sizing_store.write(cabinet.sizing.to_text)
        @attract = Attract.spawn(cabinet.field, style::HOME)
        @marquee = marquee.with(score_record: cabinet.score_record.of(cabinet.size_class))
        sounds.play(:tick, pitch: cabinet.sizing.sized_to_screen? ? 1.2 : 0.9)
      end

      # Opens the screen +name+ over Home, with its list at the top.
      def open_page(name)
        return unless page || home?

        close_layer(page) if page && !(page == :settings && SETTINGS_PAGES.include?(name))
        open_layer(name)
        @scroll = nil
        @list_press = nil
        sounds.play(:tick)
      end

      # The screens Settings opens over itself, which Back returns to it.
      SETTINGS_PAGES = %i[credits privacy server].freeze

      # Leaves the open screen: Credits, Privacy and Change Server go back
      # to Settings, the others to Home.
      def close_page
        close_layer(page) if page
        @clearing = clearing.cancel
        @scroll = nil
        close_layer(:achievement_dialog)
        sounds.play(:tick, pitch: 0.8)
      end

      def open_stats
        return unless on_home?

        @stats = stats_sheet
        open_page(:stats)
      end

      def close_stats
        close_page
        close_layer(:offer)
        @offer_focus = nil
        @offer_for_play = false
      end

      # Back, from the Credits screen to the Stats screen, or from the
      # Stats screen to Home.
      def leave
        return close_offer if offer?
        return @groups.back if group_open?

        close_page if page
      end

      def close_offer
        @offer_for_play = false
        close_layer(:offer)
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

        open_layer(:offer)
        @offer_focus = feature
        @buy_pro.open
        sounds.play(:tick)
      end

      # Whether Pro can be offered at all: where there is a store, to a
      # player who has not bought it. No screen has a button for it. The
      # offer opens from what Pro brings (an achievement, a theme, a friend
      # group) and from Play with no game left
      # (doc/design/store-and-pro.md).
      def offer_offered? = @buy_pro.offered?

      # Whether the store takes a license key (WebsiteStore), rather than
      # restoring its purchases.
      def keys? = @storefront.keys?

      # Restore Purchases, on the offer.
      def restore = @buy_pro.restore

      # Friend groups, opened from Home.
      def open_groups = (@groups.open if on_home?)

      # Whether the player has Pro.
      def pro? = @entitlement.pro?

      # Whether the offer of Pro is open, over the screen it was opened from.
      def offer? = layer?(:offer)

      # Opens the offer over the screen in view, and asks the store for the
      # price, or asks again if an earlier request was never answered.
      def open_offer
        return unless offer_offered?

        open_layer(:offer)
        @offer_focus = nil
        @buy_pro.open
        sounds.play(:tick)
      end

      # Where the offer's words and buttons go (OfferPlan), or nil while it
      # is closed.
      def offer_plan
        return unless offer?

        offer_screen.plan
      end

      # The offer's words and parts to lay out (OfferScreen).
      def offer_screen
        OfferScreen.new(layout:, type: style::TYPE, words:, measure: @measure, offering: !@entitlement.pro?,
                        note: (words.offer[:no_games] if @offer_for_play), focus: @offer_focus, art: offer_art,
                        sold: @storefront.sold?, second: @storefront.keys? ? :paste : :restore)
      end

      # How tall the offer's picture of what was tapped is: the themes'
      # cards, the achievement's card, or a feature's sign.
      def offer_art
        case @offer_focus
        when :themes then layout.short? ? 64.0 : 100.0
        when :achievements then layout.short? ? 84.0 : 110.0
        else layout.short? ? 40.0 : 56.0
        end
      end

      # The themes the offer shows: every one but the ordinary, as Pro
      # would give them now.
      def offer_themes = themes.reject(&:ordinary?)

      # The achievement a Free player tapped, which the offer leads with.
      attr_reader :offer_achievement

      # The price the store gave, or nil before it has.
      def offer_price = @storefront.price

      # What the offer says of how the store is getting on: thanks once the
      # player owns it, and otherwise a word only when there is something to
      # say.
      def offer_status
        return words.offer[:thanks] if @entitlement.pro?
        return "#{words.offer[:typing]} #{typed_tail}" if @storefront.respond_to?(:typed) && !@storefront.typed.empty? && @storefront.status == :ready

        words.offer.fetch(@storefront.status, "")
      end

      # The last of the key being typed, for the line to show.
      def typed_tail
        typed = @storefront.typed
        typed.length > 24 ? "…#{typed[-24..]}" : typed
      end

      # Paste license key: what is on the clipboard, entered as a key, on a
      # copy that takes one (WebsiteStore). A key that is good is Pro at
      # once, which Entitlement announces as Pro arriving.
      def paste_key
        return unless offer? && @storefront.keys?

        @buy_pro.paste
        sounds.play(:tick)
      end

      # Buy where the store gave a price, and otherwise the same button's
      # "Try again" (UseCases::BuyPro).
      def buy = @buy_pro.buy

      # Buy's words, with the controller's button that presses it (Y) while
      # a controller is in use. Buy's other ways are its own button, tapped
      # or clicked, and Ctrl+B or Cmd+B; none is a press that means
      # continue or back elsewhere.
      def buy_label
        label = offer_price ? format(words.offer[:buy], offer_price) : words.offer[:retry]
        return "#{label} (Y)" if input == InputKind::GAMEPAD

        @key_hint ? "#{label} (#{@key_hint})" : label
      end

      # A key was pressed on a computer's keyboard: until a pointer or a
      # controller is used, Buy names its key, +buy_key+ ("Ctrl+B", or
      # "⌘B" on a Mac).
      def keyboard_used(buy_key)
        @key_hint = buy_key
      end

      # Ctrl+B or Cmd+B, or a controller's Y, on the offer: Buy, where Pro
      # is sold and not yet bought. Says whether it took the press.
      def buy_shortcut = screen.buy

      def credits? = page == :credits

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
        return unless settings?

        open_page(:credits)
        @credits = CreditsScroll.at_top(content: 0.0, window: 0.0)
        lay_out_credits
      end

      # What a screen's list scrolls by, for Credits and the lists
      # (CreditsScroll), or nil where nothing scrolls.
      def scroll = credits? ? @credits : @scroll

      def scrolling? = screen.scrolls?

      # Whether the left stick and d-pad scroll the screen on top, as on
      # Credits, rather than move the gamepad's cursor.
      def stick_scrolls? = screen.stick_scrolls?

      # The line a list moves by, per wheel notch or stick second.
      def scroll_line = credits? ? credits_layout.line : 40.0

      # Keeps the open list's scroll, moved by +pixels+.
      def scroll_by(pixels)
        return @credits = @credits.by(pixels) if credits?

        @scroll = @scroll&.by(pixels)
      end

      # A list reports its content's height and the window it shows in.
      def list_fit(content, window)
        @scroll = @scroll ? @scroll.fitted(content:, window:) : CreditsScroll.at_top(content:, window:)
      end

      # A mouse wheel's notches, +notches+ of them, positive for up.
      def wheel_scroll(notches)
        scroll_by(-notches * style::CREDITS.wheel * scroll_line) if scrolling?
      end

      # A gamepad's stick or d-pad (Stick) held for +seconds+.
      def stick_scroll(stick, seconds)
        return unless scrolling?

        push = stick.shaped(style::GAMEPAD.dead_zone, style::GAMEPAD.curve)
        scroll_by(push.y * style::CREDITS.stick * scroll_line * seconds)
      end

      # A key that scrolls the Credits screen; says whether it was one.
      def scroll_key(name)
        return false unless scrolling? && scroll

        moved = scroll.key(name, line: scroll_line)
        credits? ? @credits = moved : @scroll = moved
        %i[up down page_up page_down home end].include?(name)
      end

      # A finger or the mouse, +by+ (as #tap names it), dragged to +y+,
      # drags the page along with it.
      def drag_scroll(by, y)
        held, from = @drag
        return unless held == by && scrolling?

        scroll_by(from - y)
        @list_press = nil if @list_press&.first == by && (from - y).abs > 3
        @drag = [by, y]
      end

      def start_scroll(by, y) = @drag = [by, y]

      # A press on a row of a scrolling list waits for its release, so a
      # drag that starts on a row scrolls the list instead of opening it.
      def press_list(x, y, by)
        @list_press = [by, control_at(x, y).name, x, y]
        @drag = [by, y]
      end

      def list_row_at?(x, y) = screen.list_row?(control_at(x, y)&.name)


      # A gamepad's Y on the Stats screen, held by +by+: Undo while it is
      # offered, or else the start of holding "Clear my stats…".
      def clear_or_undo(by)
        return if !stats? || offer?
        return undo if undo_offer

        hold_clear(by) if clear_offered?
      end

      # +by+ (as #tap names it) let go. A hold of "Clear my stats…" it
      # made ends, with nothing cleared, if it was let go too soon.
      def let_go(by)
        @drag = nil if @drag&.first == by
        if @list_press&.first == by
          _, name, x, y = @list_press
          @list_press = nil
          press(name, x, y, by)
        end
        @clearing = clearing.release(by, now)
        @groups.let_go(by, now)
      end

      # Whatever holds "Clear my stats…" stops, with nothing cleared, as
      # when the window loses focus and a release may never be heard.
      def let_go_of_everything
        @clearing = clearing.cancel
        @groups.cancel_hold
      end

      # Where a press reaches "Clear my stats…" and Undo on the Stats
      # screen, as Home's buttons do.
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
        return unless game_over? && game_over && !offer?

        preview = @sharing.offer(share_text, now) or return sounds.play(:tick)
        @screens[:share_preview].open_with(preview)
        sounds.play(:tick)
      end

      # Whether the share preview is open over Game Over. It is the
      # presentation's alone: the game stays on Game Over meanwhile, its
      # grace counting as ever, and no tap there reaches the game.
      def sharing? = layer?(:share_preview)

      # What the share preview shows (SharePreview), while it is open.
      def share_preview = (@screens[:share_preview].preview if sharing?)

      # Where the share preview's card, words and buttons go (SharePlan),
      # or nil while it is closed.
      def share_plan = (@screens[:share_preview].plan if sharing?)

      # The share preview's Copy, the one press that writes the clipboard:
      # it copies exactly the text the preview shows.
      def copy_result = (@screens[:share_preview].copy if sharing?)

      # Closes the share preview, back to Game Over as it was.
      def close_share = @screens[:share_preview].close

      # Where a tap reaches "Share my score", where it is drawn: never
      # less than a dot's width, short of where Play again's reach begins.
      # Nil without one, and while the share preview covers it.
      def share_reach = reach_of(:share)

      # Where a tap reaches the share preview's Copy and Close.
      def copy_reach = reach_of(:copy)
      def close_reach = reach_of(:close)

      # Where a tap reaches Game Over's Play again and Home, and Home's Play.
      def play_again_reach = reach_of(:play_again)
      def home_reach = reach_of(:home)
      def play_reach = reach_of(:play)

      # Where a tap reaches "Your stats": never less than a dot's width
      # where it has room, and never past the safe area's bottom.
      def stats_reach = reach_of(:stats)

      # Where a tap reaches the Stats screen's Back.
      def back_reach = reach_of(:back)

      # Where a tap reaches each segment of the dot-size choice, as a
      # DotSizing and its Rect, while Home offers it.
      def sizing_reaches = SIZINGS.map { [it, reach_of(it)] }

      # Where Home's parts go (HomePlan).
      def home_plan
        planned(HomeScreen.new(layout:, type: style::TYPE, words:, measure: @measure, played: stats_offered?,
                               tile_names:, window: window.offered?))
      end

      # The four large buttons on Home, Friend groups only where a server is offered.
      def tile_names = [:stats, :achievements, :themes, *(:groups if group_offered?)]

      # What Home says of the games left, or nil where none are counted.
      def games_line = (words.games_left(games.left) if games.metered?)

      # What Play says, and what it leaves to say beneath it.
      def play_word = @start_game.none_left? ? words.button(:get_pro) : words.play

      def play_note
        return unless games.metered?

        @start_game.none_left? ? words.no_games_left(games.daily) : words.games_left(games.left)
      end

      # A large button's name and its one value.
      def tile_word(name) = words.tile(name)

      def tile_note(name)
        case name
        when :stats then words.score_record_line(marquee.score_record)
        when :achievements then achievement_count&.then { AchievementWords.count(it) } || words.tile_note(:to_earn)
        when :themes then words.themes.fetch(in_use.key)
        when :groups then @groups.member? ? words.titles_held(@groups.titles_held, @groups.groups.groups.size) : words.tile_note(:take_title)
        end
      end

      # A screen's heading's type size and middle, fitted beside Back
      # (Layout#heading_place).
      def heading_place(text) = layout.heading_place(text, @measure)

      def open_settings = open_page(:settings)
      def open_privacy = open_page(:privacy)

      # Change Server, from Settings, only while setdef is gone
      # (ServerChoice).
      def open_server
        open_page(:server) if settings? && server_offered?
      end

      def server? = page == :server
      def server_offered? = @server_choice&.offered? || false

      # The words and buttons of Change Server (ServerScreen).
      def server_plan
        choice = @server_choice
        now = format(words.button(:server_now), choice&.address || words.button(:server_setdef))
        status = choice&.status && words.button(:"server_#{choice.status}")
        ServerScreen.new(layout:, measure: @measure, lines: [[:crown, words.button(:server_warning)], [:copy, words.button(:server_how)]],
                         now:, status:, resettable: !choice&.address.nil?).plan
      end

      def paste_server
        return unless server?

        @server_choice.paste
        sounds.play(:tick)
      end

      def reset_server
        return unless server?

        @server_choice.reset
        sounds.play(:tick, pitch: 0.8)
      end

      # The system's paste shortcut (Ctrl+V, or Cmd+V on a Mac) on a
      # computer: Paste license key on the offer, or Paste server address on
      # Change Server. Says whether it was taken.
      def paste_shortcut = screen.paste
      def open_policy = @links.open(PRIVACY_URL)

      def open_achievements = open_page(:achievements)
      def achievements_layout = AchievementsScreen.new(layout:, ids: Achievement::IDS)
      # How many achievements are earned, or nil where that is Pro's.
      def achievement_count = @view_achievements.count

      # The Achievements grid, each cell where it is on screen, with the
      # list scrolled to fit its window.
      def achievement_cells
        grid = achievements_layout
        list_fit(grid.height, grid.window.height)
        grid.cells(@scroll.offset)
      end

      # A Free player sees only how each is earned; Pro also sees its day.
      def achievement_earned?(id) = @view_achievements.earned?(id)

      def open_achievement(id)
        open_layer(:achievement_dialog)
        @screens[:achievement_dialog].achievement = id
        sounds.play(:tick)
      end

      def close_dialog
        close_layer(:achievement_dialog)
        sounds.play(:tick, pitch: 0.8)
      end

      def step_achievement(by)
        ids = Achievement::IDS
        @screens[:achievement_dialog].achievement = ids[((ids.index(dialog) || 0) + by) % ids.size]
        sounds.play(:tick)
      end

      # Get Pro, from a Free player's achievement dialog.
      def achievement_pro
        id = dialog
        open_offer_for(:achievements)
        @offer_achievement = id
        close_layer(:achievement_dialog)
      end

      # What the dialog says of how far along the player is: [record, goal]
      # for the four the game measures (Steady hand, Unshaken, Big score,
      # Long haul), or nil for the rest and for a Free player.
      def achievement_progress(id) = @view_achievements.progress(id)

      def dialog_plan
        id = dialog or return
        AchievementDialog.new(layout:, measure: @measure, how: AchievementWords.how(id), status: dialog_status(id), progress: achievement_progress(id),
                              buttons: dialog_buttons).plan
      end

      # What the dialog says of its state: the earned day or "Not earned
      # yet", or nothing for a Free player.
      def dialog_status(id)
        return if @view_achievements.locked?

        day = @view_achievements.day(id)
        day ? AchievementWords.earned_on(day) : words.button(:not_earned)
      end

      def dialog_buttons
        steps = input == InputKind::GAMEPAD ? [[:achievement_prev, :prev], [:achievement_next, :next]] : []
        return [[:achievement_close, :close], *steps] unless @view_achievements.locked?

        [[:achievement_pro, :get_pro], [:achievement_close, :close], *steps]
      end

      def settings_plan
        rows = [[:sound, words.button(:sound), :speaker, [[words.button(:on), !sounds.muted?, [:sound, true]], [words.button(:off), sounds.muted?, [:sound, false]]]]]
        if sizing_offered?
          rows << [:dot_size, words.button(:dot_size), :dot, SIZINGS.map { [words.sizing(it, sizing_preview), it == cabinet.sizing, it] }]
        end
        rows << [:display, words.button(:display), :corners, display_choices] if window.offered?
        plan = SettingsScreen.new(layout:, rows:, offset: settings? && @scroll ? @scroll.offset : 0.0, server: server_offered?).plan
        list_fit(plan.height, layout.page.height) if settings?
        plan
      end

      def display_choices
        { window: :windowed, borderless: :full_screen_borderless, exclusive: :full_screen }.map { |mode, word| [words.button(word), window.display == mode, [:display, mode]] }
      end

      def set_sound(on)
        sounds.toggle_mute if sounds.muted? == on
        sounds.play(:tick)
      end

      def privacy_plan
        lines = [[:bars, words.button(:privacy_stats)], [:crown, words.button(:privacy_groups)]]
        PrivacyScreen.new(layout:, measure: @measure, lines:, note: words.button(:privacy_delete_note), deletable: @groups.known?).plan
      end

      # A gamepad's button (+name+, a GamepadButtons intent) on the screen
      # on top.
      def pad(name) = screen.pad(name)

      PRIVACY_URL = "https://dot-popper.setdef.com/privacy"

      # What the title says of the games left, or nil where none are counted.
      # Where Game Over's words and "Share my score" go (FinalePlan), or
      # nil away from Game Over.
      def game_over_plan = game_over_screen&.then { planned(it) }

      # The plan of +screen+ (a HomeScreen or a FinaleScreen), laid out
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
                           below: layout.safe.y, radius: cabinet.game&.field&.radius || @radius, chips: game_over_chips,
                           play_word: @start_game.none_left? ? words.button(:get_pro) : words.play_again, play_note:)
      end

      # The window changed size. Home's dots are respawned if their
      # size changes with it, as dots sized to the screen do.
      def resize(layout, field)
        @layout = layout
        lay_out_credits if credits?
        @attract = field.radius == attract.field.radius ? attract.refit(field) : Attract.spawn(field, style::HOME)
      end

      def update(seconds)
        @now += seconds
        @groups.update(now, quiet: !playing?, showing: screen.announces?)
        @buy_pro.update(seconds)
        @arrival_seen = [arrival.key, now] if arrival? && @arrival_seen&.first != arrival.key
        clear_stats if clearing.done?(now)
        @undo = nil unless @undo&.open?(now)
        @hover = hover.at(hovered).update(seconds, style::HOVER)
        effects.update(seconds)
        follow_tutorial(seconds) if tutorial?
        @attract = attract.update(seconds) if home?
        follow_game if cabinet.game && !tutorial?
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
        when Events::HomeShown then home_shown(event)
        end
      end

      # The player has answered the notice of a new theme. A Pro player's
      # switch uses it at once; a Free player's opens the offer, the same
      # as tapping Themes.
      def answer_arrival(use:)
        return :waiting unless arrival_settled?

        theme = arrival
        return unless theme

        @theme_keeper.told(theme)
        return sounds.play(:tick, pitch: 0.8) unless use
        return open_offer_for(:themes) if @use_theme.call(theme) == :offer

        sounds.play(:tick, pitch: 1.2)
      end

      def step_theme(by)
        list = themes
        use(list[(list.index(in_use).to_i + by) % list.size])
      end

      def next_display
        return unless window.offered?

        order = %i[window borderless exclusive]
        window.display = order[(order.index(window.display).to_i + 1) % order.size]
      end

      # A tap in the Tutorial: its skip button, or the scene's.
      def tutorial_tap(x, y)
        return skip_tutorial if control_at(x, y)&.name == :skip

        @tutorial.tap(x, y)
      end

      # A tap on Home away from its buttons: a bright dot there pops
      # for fun, with no score; anywhere else, nothing happens.
      def toy_tap(x, y)
        dot = attract.dots.top_at(x, y)
        toy_pop(dot, x, y) if dot&.bright?
      end

      def undo
        @keeper.restore(@undo.cleared)
        @undo = nil
        stats_changed
        sounds.play(:tick, pitch: 1.2)
      end

      def hold_clear(by)
        @clearing = clearing.press(by, now)
        sounds.play(:tick, pitch: 0.7)
      end

      # Opens +screen+ (a Screens::Screen, or its name in Screens.made_for)
      # over the screens open now, unless it is open already.
      def open_layer(screen)
        layer = screen.is_a?(Symbol) ? @screens.fetch(screen) : screen
        @layers << layer unless @layers.include?(layer)
      end

      # Closes +screen+, wherever it is on the stack.
      def close_layer(screen) = @layers.delete(screen.is_a?(Symbol) ? @screens.fetch(screen) : screen)

      # Whether +screen+ is open over the others.
      def layer?(screen) = @layers.include?(screen.is_a?(Symbol) ? @screens.fetch(screen) : screen)

      # What sizes the screens' words (RoughMeasure's methods).
      attr_reader :measure

      private

      # Opens the offer straight from Home, as Play does when no play
      # is left; Back from it returns to Home.
      def offer_for_play
        return unless home? && offer_offered?

        @stats = stats_sheet
        @offer_for_play = true
        open_offer
        @offer_focus = :games
      end

      # Plays the Tutorial over a game started paused on the field a game
      # would start on, through the one way into a game (UseCases::StartGame),
      # and sizes the effects to its dots. With no game left, the offer of
      # Pro opens instead, and the Tutorial stays due.
      def open_tutorial
        opening = Tutorial.opening(cabinet.field, [layout.center_x, layout.center_y], style:)
        started = @start_game.call(opening)
        return offer_for_play if started == :none_left
        return unless started == :started

        @tutorial_flag.seen!
        effects.clear
        effects.scale_to(cabinet.field.radius)
        @tutorial = Tutorial.new(cabinet:, effects:, sounds:, haptics: @haptics, style:, now:, calm: @calm, palette:)
      end

      # The Tutorial moves on, and once it is over, the game plays on, and
      # only its clock starts, lit as it starts to run (LeadIn).
      def follow_tutorial(seconds)
        @tutorial.update(seconds)
        return unless @tutorial.over?

        play_on
        @lead_in = LeadIn.new(at: now, style: style::TUTORIAL.lead)
      end

      # The Tutorial goes, and its game plays on as it is (Cabinet#unpause),
      # drawn as the Tutorial drew it (#game_started).
      def play_on
        @handing_over, @tutorial = @tutorial, nil
        cabinet.unpause
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

      # Pro arrived (Entitlement::ProGranted): a tick marks a store's
      # purchase landing while the offer is open. A license key entered has
      # had its own tick as it was pressed.
      def pro_arrived(granted)
        sounds.play(:tick, pitch: 1.3) if offer? && granted.by == :receipt
      end

      # "Clear my stats…" was held long enough: Stats go, and Undo
      # is offered.
      def clear_stats
        @clearing = clearing.cancel
        @undo = UndoOffer.new(cleared: @keeper.clear, at: now, seconds: style::STATS_CLEAR.undo)
        stats_changed
        sounds.play(:bonk, pitch: 0.7)
        @haptics.buzz(style::HAPTICS.penalty)
      end

      # Stats changed under the Stats screen: it, and Home's
      # score record, show them as they are now.
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

      # Play begins: afresh, its dot growing in, or, under the Tutorial,
      # with the dots as it drew them, their animations, its effects still
      # playing, and its HUD, so nothing on screen jumps.
      def game_started(event)
        scene, @handing_over = @handing_over, nil
        @scale = event.field.radius
        effects.scale_to(@scale)
        if scene
          @animations = scene.animations
          @hud = scene.hud.with(words:)
        else
          effects.clear
          animations.clear
          @hud = Hud.blank(style::HUD, words)
          event.dots.each { animations.spawn(it.id, now) }
        end
        @tutorial_game = !scene.nil?
        @groups.game_started
        @game_over = nil
        close_layer(:share_preview)
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
        sounds.play(:pop, pitch: pop_pitch(event.score), pan: pan(event.x))
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

        dot = cabinet.game.dots.find { it.bright? && it.bonus? } or return @beckoned_at = nil
        @beckoned_at = now
        effects.ring(dot.x, dot.y, style::BONUS_BEACON, follow: dot.id)
      end

      def penalized(event)
        @penalized_at = now
        animations.wobble(event.dot.id, now)
        effects.ring(event.dot.x, event.dot.y, style::ALARM_RING, follow: event.dot.id)
        hidden = event.dots.bright_beneath(event.dot, event.x, event.y)
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

      # The game is finished (UseCases::FinishGame), and Game Over shows
      # what it did.
      def game_ended(event)
        result = @finish_game.call(event, stats: game_stats, earned: @achievement_watch.earned, tutorial: @tutorial_game)
        lesson = @tutor.lesson(@mistake) if @mistake&.among(event.dots)
        @game_over = GameOver.new(style: style::GAME_OVER, score: event.score, score_record: event.score_record, new_score_record: event.new_score_record, at: now,
                             stats: game_stats, record: result.record, goal_met: result.goal_met, lesson:, achievements: result.achievements,
                             first: event.first, screen: words.played_on(event.field, sized: event.size_class == SizeClass::FITTED))
        sounds.play(event.new_score_record ? :new_score_record : :game_over)
      end

      def home_shown(event)
        @use_theme.refresh
        @stats = nil
        @offer_for_play = false
        @groups.close if group_open?
        @layers.clear
        @credits = nil
        @clearing = clearing.cancel
        effects.clear
        @game_over = nil
        @marquee = Marquee.new(style: style::HOME, score_record: event.score_record, at: now)
      end

      # One of Home's dots, popped by a tap: its droplets, its ring,
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

      # The pop's pitch climbs with +score+, the score it reached.
      def pop_pitch(score)
        sound = style::SOUND
        [1.0 + (score * sound.pop_climb), sound.pop_highest].min
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

      # The stacking rule, taught with no word: the mistake the game
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
        line = game_over_plan[[:chip, 0]] or return
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
