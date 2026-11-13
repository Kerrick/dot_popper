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
    # (Achievements) are listed on the Achievements screen. +tutorial_flag+
    # (TutorialFlag) says whether Play opens the Tutorial first. +window+
    # (NoWindowControl's methods) is the desktop's window, which
    # Home's "Full screen" and Quit switch and close where it offers them.
    #
    # What a player does that needs two of the game's areas goes through
    # the use cases it is given, made by the composition root (ADR-0017):
    # +start_game+, +finish_game+, +buy_pro+, +use_theme+,
    # +join_or_create_friend_group+ and +view_achievements+. It is never
    # given what decides Pro, the store or the free games, so nothing here
    # can ask them.
    class Show
      # The dot-size choices in the order Settings draws them
      # (Screens::Settings::SIZINGS).
      SIZINGS = Screens::Settings::SIZINGS

      attr_reader :cabinet, :effects, :animations, :hud, :attract, :layout, :marquee, :game_over, :sounds, :now, :style,
                  :stats_book, :input, :words, :tutorial, :lead_in, :window

      def initialize(cabinet:, layout:, sounds:, radius:, start_game:, finish_game:, buy_pro:, use_theme:, join_or_create_friend_group:,
                     view_achievements:, stats_book:, achievements:, groups:, theme_keeper: nil,
                     themes: theme_keeper&.rules || DotPopper::Themes.new(ScoreRecord::Memory.new), style: Style, random: Random.new, calm: false,
                     tutor: Tutor.new(ScoreRecord::Memory.new, times: style::LESSON.times), haptics: NoHaptics.new, clipboard: MemoryClipboard.new,
                     sizing_store: ScoreRecord::Memory.new, input: InputKind::MOUSE, measure: RoughMeasure.new,
                     keeper: StatsKeeper.new(score_record: cabinet.score_record, stats_book:, achievements:), notices: Notices.none,
                     sharing: InGameSharing.new, tutorial_flag: TutorialFlag.never, window: NoWindowControl.new,
                     links: NoLinks.new, group_notice: GroupNotice.read, server_choice: nil)
        @cabinet = cabinet
        @window = window
        @links = links
        @tutorial_flag = tutorial_flag
        @theme_keeper = theme_keeper
        @themes = themes
        # Methods, not blocks, so that what the panel keeps holds the Show
        # and the clipboard alone, and none of what the Show was given.
        @groups = GroupPanel.new(groups:, joining: join_or_create_friend_group, sounds:, pro_offer: method(:open_offer_for), notice: group_notice,
                                 shown: method(:friend_groups_shown))
        @groups.copy = clipboard.method(:copy)
        @finish_game = finish_game
        @use_theme = use_theme
        @view_achievements = view_achievements
        @layers = [] # the screens open over the game's state, the top one last
        @tutorial = nil
        @handing_over = nil
        @lead_in = nil
        @measure = measure
        @stats_book = stats_book
        @layout = layout
        @sounds = sounds
        @haptics = haptics
        @radius = radius
        @scale = radius
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
        @mistake = nil
        @penalized_at = -Float::INFINITY
        @beckoned_at = nil
        @keeper = keeper
        @pointer = nil
        @hover = Hover.none
        @screens = Screens.made_for(self, clipboard:, buy_pro:, start_game:, sharing:, view_achievements:, keeper:, stats_book:,
                                          achievements:, haptics:, notices:, sizing_store:, server_choice:, themes:, use_theme:,
                                          tutorial_flag:)
      end

      # The screen on top, which every press, button, key and scroll asks
      # (Screens), and the renderer draws: the one place that decides it.
      # It is the last screen opened over the others, or with none open,
      # the screen for the game's state.
      def screen = @layers.last || state_screen

      # The screens open over the screen for the game's state, the top
      # one last, for the renderer to draw.
      attr_reader :layers

      # One of each screen, open or not, by its name in Screens.made_for.
      attr_reader :screens

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
      def game_stats = @finish_game.stats

      # The colors of the theme in use (ThemeKeeper), which only changes
      # between games.
      def palette = in_use.palette

      # Whether the Themes screen is open over the Stats screen, and what
      # it shows: every theme the player can use, and the one in use.
      def themes? = page == :themes

      # The new theme to tell the player of, once, at Home, when nothing
      # else is asked of them; nil the rest of the time.
      def arrival = (theme_of(@themes.new_theme) if on_home?)
      def arrival? = !arrival.nil?
      # Whether the card for this theme has been up ARRIVAL_GRACE since it
      # first appeared, so a press meant for Home as it came answers nothing.
      def arrival_settled? = @arrival_seen&.first == arrival&.key && now - @arrival_seen.last >= style::ARRIVAL_GRACE
      def arrival_plan = @screens[:new_theme].plan

      # The switch's word: a Free player's is "Get Pro", since it opens the offer.
      def arrival_use_word = @screens[:new_theme].use_word
      def themes = @themes.choices.map { theme_of(it) }
      # The art of the theme in use (UseCases::UseTheme answers its key).
      def in_use = theme_of(@use_theme.current)

      # Whether tapping a theme leads to Pro, as it does for a Free player,
      # and whether +theme+ is open to use, earned or in season. They show
      # the same to either player.
      def themes_locked? = @use_theme.locked?
      def theme_open?(theme) = @themes.open?(theme.key)

      # Where the Themes screen's cards go (LooksLayout).
      def themes_layout = @screens[:themes].plan

      def open_themes = open_page(:themes)
      def close_themes = close_page

      # Uses +theme+ from now on, from Themes (Screens::Themes#use).
      def use(theme) = @screens[:themes].use(theme)

      # The player pressed with +kind+ (InputKind): from now on the words
      # say what to do with it.
      def input=(kind)
        @screens[:offer].key_hint = nil # a pointer or a controller took over from the keyboard
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
      # presentation's alone: the game stays on Home meanwhile, and
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
      def group_plan = @screens[:friend_groups].plan

      # Where the notice of a first Join or Create puts its parts, while it
      # is open over the friend groups' screen (GroupNoticePlan), or nil.
      def group_notice_plan = @screens[:friend_groups].notice_plan

      # A friend groups' word (a ByInput), said as the player's input would
      # press it.
      def group_word(word) = @screens[:friend_groups].word(word)

      # Whether Home offers the way in to groups: where there is a
      # server, once a game has finished, or for someone in a group.
      def group_offered? = @groups.available?

      # Where an announcement goes: under the HUD at Game Over, and at
      # the top of Home, clear of the Group button's row.
      def banner_y = layout.top

      # What the Stats screen shows, while it is open.
      def stats = @screens[:stats].sheet

      # The hold of "Clear my stats…" (HoldToConfirm).
      def clearing = @screens[:stats].clearing

      # The Stats screen laid out for the fonts this screen is measured with.
      def stats_layout = @screens[:stats].plan

      # Whether Home offers "Your stats" and the choice of dot size:
      # only once a game has finished, so a first-time player's Home says
      # only how to play. A player who cleared their Stats has played, so
      # it still offers them, though it shows no score record or goal until their
      # next game (#played?).
      def stats_offered? = played? || @keeper.cleared?

      # Whether a game has finished since Stats were last cleared:
      # Home shows today's goal only then.
      def played? = stats_book.stats.games.positive?

      # What stands under Stats' heading where the two dot sizes differ:
      # "Stats for smaller dots".
      def stats_note
        return if sizing_preview.alike?

        "Stats for #{words.sizing(cabinet.sizing, sizing_preview).downcase} dots"
      end

      # Whether the Stats screen offers "Clear my stats…": while it has
      # Stats to clear, and no Undo is offered.
      def clear_offered? = @screens[:stats].clear_offered?

      # Undo, while it is offered on the Stats screen (UndoOffer), or nil.
      def undo_offer = @screens[:stats].undo_offer

      # What the choice of dot size would do on this screen, worked out
      # afresh each time, so a resized window is always seen as it is now.
      def sizing_preview = SizingPreview.of(cabinet.screen, style::SIZING)

      # Whether Settings offers the choice of dot size: where the two sizes
      # look different, and wherever the fixed size is saved
      # (SizingPreview#offered?). Where they look alike and Standard is
      # saved, the choice is left out, and games follow it.
      def sizing_offered? = sizing_preview.offered?(cabinet.sizing)
      def playing? = cabinet.playing?
      def game_over? = cabinet.state.is_a?(Cabinet::GameOver)

      # A tap at +x+, +y+, by +by+ (a finger's id, :mouse, or :gamepad),
      # which #let_go names when it lets go, on the screen on top
      # (Screens::Screen#tap): in a game it goes to the game at once;
      # elsewhere it presses the button under it (#controls), or empty
      # space, which each screen answers for itself. A gamepad's A, which
      # aims at no button, presses the screen's main one (#primary).
      def tap(x, y, by: :tap) = screen.tap(x, y, by)

      # A key typed on a keyboard (+key+, as Shell::LotaInput names it)
      # that the screen on top takes as its own: the keypad's digits that
      # join a friend group, a license key on the offer, H on Home and C on
      # Settings. Says whether it took it.
      def type_key(key) = screen.type(key)


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

      # Home's Play (Screens::Home#play) and How to play.
      def play = @screens[:home].play
      def how_to_play = @screens[:home].how_to_play

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

      # Game Over's Play again (Screens::GameOver#play_again).
      def play_again = @screens[:game_over].play_again

      # Game Over's lines in pills of their own (Screens::GameOver#chips).
      def game_over_chips = @screens[:game_over].chips

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

      QUIT_ASK = Screens::Home::QUIT_ASK # seconds a second B has to quit from Home

      # B on Home (Screens::Home#ask_to_quit), and how much of "Press B
      # again to quit" shows.
      def ask_to_quit = @screens[:home].ask_to_quit
      def quit_prompt = @screens[:home].quit_prompt

      # Escape, Android's Back, or a gamepad's B, on the screen on top
      # (Screens::Screen#back): its Back, Close or Home. Says whether it had
      # one, so that elsewhere the key can do its usual job.
      def back = screen.back

      # Sizes dots as +sizing+ (DotSizing) says, from Settings
      # (Screens::Settings#choose_sizing).
      def choose_sizing(sizing) = @screens[:settings].choose_sizing(sizing)

      # The player chose another size of dots: Home's dots are spawned
      # afresh at it, and its score record is the size's.
      def sizing_changed
        @attract = Attract.spawn(cabinet.field, style::HOME)
        score_record_changed
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
        @screens[:stats].cancel_hold
        @scroll = nil
        close_layer(:achievement_dialog)
        sounds.play(:tick, pitch: 0.8)
      end

      def open_stats = @screens[:stats].open

      def close_stats
        close_page
        offer.close(quiet: true)
      end

      # What the open offer leads with (Screens::Offer#focus).
      def offer_focus = offer.focus

      # A Free player tapped something that comes with Pro (+feature+ is
      # :achievements, :themes or :groups): the offer opens over the screen
      # they are on, leading with it (Screens::Offer#open_led_by).
      def open_offer_for(feature) = offer.open_led_by(feature)

      # Whether Pro can be offered at all: where there is a store, to a
      # player who has not bought it. No screen has a button for it. The
      # offer opens from what Pro brings (an achievement, a theme, a friend
      # group) and from Play with no game left
      # (doc/design/store-and-pro.md).
      def offer_offered? = offer.offered?

      # Whether the store takes a license key (WebsiteStore), rather than
      # restoring its purchases.
      def keys? = offer.keys?

      # The friend groups' screens opened (+open+) or closed, on the stack.
      def friend_groups_shown(open) = open ? open_layer(:friend_groups) : close_layer(:friend_groups)

      # Friend groups, opened from Home.
      def open_groups = (@groups.open if on_home?)

      # Whether the offer of Pro is open, over the screen it was opened from.
      def offer? = layer?(:offer)

      # The offer of Pro (Screens::Offer), open or not.
      def offer = @screens[:offer]

      # Opens the offer over the screen in view (Screens::Offer#open_plainly).
      def open_offer = offer.open_plainly

      # Where the offer's words and buttons go (OfferPlan), or nil while it
      # is closed.
      def offer_plan = (offer.plan if offer?)

      # The offer's words and parts to lay out (OfferScreen).
      def offer_screen = offer.layout_screen


      # The themes the offer shows: every one but the ordinary, as Pro
      # would give them now.
      def offer_themes = themes.reject(&:ordinary?)

      # The achievement a Free player tapped, which the offer leads with.
      def offer_achievement = offer.achievement

      # The price the store gave, or nil before it has.
      def offer_price = offer.price

      # What the offer says of how the store is getting on.
      def offer_status = offer.status


      # Paste license key, on the offer (Screens::Offer#paste_key).
      def paste_key = offer.paste_key


      # Buy's words (Screens::Offer#buy_label).
      def buy_label = offer.buy_label

      # A key was pressed on a computer's keyboard: until a pointer or a
      # controller is used, Buy names its key, +buy_key+ ("Ctrl+B", or
      # "⌘B" on a Mac).
      def keyboard_used(buy_key) = offer.key_hint = buy_key

      # Ctrl+B or Cmd+B, or a controller's Y, on the offer: Buy, where Pro
      # is sold and not yet bought. Says whether it took the press.
      def buy_shortcut = screen.buy

      def credits? = page == :credits

      # How far down the Credits screen is scrolled (CreditsScroll), while
      # it is open.
      def credits = @screens[:credits].scroll

      # The Credits screen's lines (CreditsLines), laid out for the
      # screen's size, while it is open.
      def credits_lines = @screens[:credits].lines

      # Where the Credits screen's heading and its window of text go.
      def credits_layout = @screens[:credits].plan

      # Opens the Credits screen over the Stats screen, at the top.
      def open_credits = @screens[:credits].open

      # What a screen's list scrolls by, for Credits and the lists
      # (CreditsScroll), or nil where nothing scrolls.
      def scroll = credits? ? credits : @scroll

      def scrolling? = screen.scrolls?

      # Whether the left stick and d-pad scroll the screen on top, as on
      # Credits, rather than move the gamepad's cursor.
      def stick_scrolls? = screen.stick_scrolls?

      # The line a list moves by, per wheel notch or stick second.
      def scroll_line = credits? ? credits_layout.line : 40.0

      # Keeps the open list's scroll, moved by +pixels+.
      def scroll_by(pixels)
        return @screens[:credits].scroll = credits.by(pixels) if credits?

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
        credits? ? @screens[:credits].scroll = moved : @scroll = moved
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

      # The open list goes back to its top, as when a screen's list changes.
      def list_scroll_from_top = @scroll = nil

      # A press on a row of a scrolling list waits for its release, so a
      # drag that starts on a row scrolls the list instead of opening it.
      def press_list(x, y, by)
        @list_press = [by, control_at(x, y).name, x, y]
        @drag = [by, y]
      end

      def list_row_at?(x, y) = screen.list_row?(control_at(x, y)&.name)


      # +by+ (as #tap names it) let go. A hold of "Clear my stats…" it
      # made ends, with nothing cleared, if it was let go too soon.
      def let_go(by)
        @drag = nil if @drag&.first == by
        if @list_press&.first == by
          _, name, x, y = @list_press
          @list_press = nil
          press(name, x, y, by)
        end
        @screens[:stats].release(by)
        @groups.let_go(by, now)
      end

      # Whatever holds "Clear my stats…" stops, with nothing cleared, as
      # when the window loses focus and a release may never be heard.
      def let_go_of_everything
        @screens[:stats].cancel_hold
        @groups.cancel_hold
      end

      # Where a press reaches "Clear my stats…" and Undo on the Stats
      # screen, as Home's buttons do.
      def clear_reach = reach_of(:clear)
      def undo_reach = reach_of(:undo)

      # The gamepad button that holds "Clear my stats…", for its words.
      def holding_button = clearing.by == :y ? "Y" : "A"

      # Whether the share preview is open over Game Over. It is the
      # presentation's alone: the game stays on Game Over meanwhile, its
      # grace counting as ever, and no tap there reaches the game.
      def sharing? = layer?(:share_preview)

      # What the share preview shows (SharePreview), while it is open.
      def share_preview = (@screens[:share_preview].preview if sharing?)

      # Where the share preview's card, words and buttons go (SharePlan),
      # or nil while it is closed.
      def share_plan = (@screens[:share_preview].plan if sharing?)

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

      # Where Home's parts go (HomePlan), its large buttons, what it says
      # of the games left, and what Play says (Screens::Home).
      def home_plan = @screens[:home].plan
      def tile_names = @screens[:home].tile_names
      def games_line = @screens[:home].games_line
      def play_word = @screens[:home].play_word
      def play_note = @screens[:home].play_note

      # A large button's name and its one value.
      def tile_word(name) = words.tile(name)

      def tile_note(name) = @screens[:home].tile_note(name)

      # A screen's heading's type size and middle, fitted beside Back
      # (Layout#heading_place).
      def heading_place(text) = layout.heading_place(text, @measure)

      def open_settings
        @screens[:settings].visit
        open_page(:settings)
      end
      def open_privacy = open_page(:privacy)

      # Change Server, from Settings, only while setdef is gone
      # (ServerChoice).
      def open_server = @screens[:server].open

      def server? = page == :server
      def server_offered? = @screens[:server].offered?

      # The words and buttons of Change Server (ServerScreen).
      def paste_server = @screens[:server].paste_address

      # The system's paste shortcut (Ctrl+V, or Cmd+V on a Mac) on a
      # computer: Paste license key on the offer, or Paste server address on
      # Change Server. Says whether it was taken.
      def paste_shortcut = screen.paste
      def open_policy = @links.open(PRIVACY_URL)

      def open_achievements = open_page(:achievements)
      def achievements_layout = @screens[:achievements].grid
      # How many achievements are earned, or nil where that is Pro's.
      def achievement_count = @view_achievements.count

      # The Achievements grid, each cell where it is on screen, with the
      # list scrolled to fit its window.
      def achievement_cells = @screens[:achievements].cells

      # A Free player sees only how each is earned; Pro also sees its day.
      def achievement_earned?(id) = @view_achievements.earned?(id)

      # An achievement's dialog (Screens::AchievementDialog): opened at
      # +id+, and its Get Pro.
      def open_achievement(id) = @screens[:achievement_dialog].open_at(id)
      def achievement_pro = @screens[:achievement_dialog].get_pro

      # What the dialog says of how far along the player is: [record, goal]
      # for the four the game measures (Steady hand, Unshaken, Big score,
      # Long haul), or nil for the rest and for a Free player.
      def achievement_progress(id) = @view_achievements.progress(id)

      def dialog_plan = (@screens[:achievement_dialog].plan if dialog)

      # What the dialog says of +id+'s state (Screens::AchievementDialog#status).
      def dialog_status(id) = @screens[:achievement_dialog].status(id)

      def settings_plan = @screens[:settings].plan
      def privacy_plan = @screens[:privacy].plan

      # A gamepad's button (+name+, a GamepadButtons intent) on the screen
      # on top.
      def pad(name) = screen.pad(name)

      PRIVACY_URL = "https://dot-popper.setdef.com/privacy"

      # Where Game Over's words and buttons go (GameOverPlan), or nil
      # before a game has finished.
      def game_over_plan = @screens[:game_over].plan

      # Game Over's words to lay out (GameOverScreen), or nil before a game
      # has finished.
      def game_over_screen = @screens[:game_over].layout_screen

      # The window changed size. Home's dots are respawned if their
      # size changes with it, as standard dots do.
      def resize(layout, field)
        @layout = layout
        @screens[:credits].lay_out if credits?
        @attract = field.radius == attract.field.radius ? attract.refit(field) : Attract.spawn(field, style::HOME)
      end

      def update(seconds)
        @now += seconds
        @groups.update(now, quiet: !playing?, showing: screen.announces?)
        offer.update(seconds)
        @arrival_seen = [arrival.key, now] if arrival? && @arrival_seen&.first != arrival.key
        @screens[:stats].update
        @hover = hover.at(hovered).update(seconds, style::HOVER)
        effects.update(seconds)
        follow_tutorial(seconds) if tutorial?
        @attract = attract.update(seconds) if home?
        follow_game if cabinet.game && !tutorial?
        follow_game_over if game_over?
      end

      # Hears one of the rules' events (Cabinet#subscribe).
      def call(event)
        case event
        when Events::GameStarted then game_started(event)
        when Events::Popped then popped(event)
        when Events::Penalized then penalized(event)
        when Events::Missed then effects.ring(event.x, event.y, style::TOUCH_RIPPLE)
        when Events::GameEnded then game_ended(event)
        when Events::HomeShown then home_shown(event)
        end
      end

      # A tap in the Tutorial: its skip button, or the scene's.
      def tutorial_tap(x, y)
        return skip_tutorial if control_at(x, y)&.name == :skip

        @tutorial.tap(x, y)
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

      # Home's score record shows the records as they are now, as after
      # clearing Stats or an undo.
      def score_record_changed = @marquee = marquee.with(score_record: cabinet.score_record.of(cabinet.size_class))


      # The Tutorial opened over a game started paused (Screens::Home):
      # the effects are sized to its dots, and it plays.
      def tutorial_began
        effects.clear
        effects.scale_to(cabinet.field.radius)
        @tutorial = Tutorial.new(cabinet:, effects:, sounds:, haptics: @haptics, style:, now:, calm: @calm, palette:)
      end

      # One of Home's dots, popped by a tap: its droplets, its ring,
      # and its bloop, but no score.
      def toy_pop(dot, x, y)
        effects.burst(x, y, style::POP_BURST, palette.confetti)
        effects.ring(dot.x, dot.y, style::SHOCKWAVE)
        sounds.play(:pop, pan: pan(x))
      end
      private

      # The art of the theme +key+ (Theme), or nil for none.
      def theme_of(key) = key && style::THEMES.find { it.key == key }


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
        @groups.game_started
        @game_over = nil
        close_layer(:share_preview)
        @mistake = nil
        @screens[:stats].forget_undo # the game's records would be lost to an undo
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


      # The game is finished (UseCases::FinishGame, which heard it first),
      # and Game Over shows what it did.
      def game_ended(event)
        result = @finish_game.result
        lesson = @tutor.lesson(@mistake) if @mistake&.among(event.dots)
        @game_over = GameOver.new(style: style::GAME_OVER, score: event.score, score_record: event.score_record, new_score_record: event.new_score_record, at: now,
                             stats: game_stats, record: result.record, goal_met: result.goal_met, lesson:, achievements: result.achievements,
                             first: event.first, screen: words.played_on(event.field, standard: event.size_class == SizeClass::STANDARD))
        sounds.play(event.new_score_record ? :new_score_record : :game_over)
      end

      def home_shown(event)
        @use_theme.refresh
        @screens[:stats].forget
        offer.closed_at_home
        @groups.close if group_open?
        @layers.clear
        @screens[:credits].forget
        @screens[:stats].cancel_hold
        effects.clear
        @game_over = nil
        @marquee = Marquee.new(style: style::HOME, score_record: event.score_record, at: now)
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
