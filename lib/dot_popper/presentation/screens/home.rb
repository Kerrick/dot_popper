# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Home: the game's name, Play, today's goal, the large buttons and
      # the bottom row (HomeScreen lays them out). Play starts a game
      # through +start_game+ (UseCases::StartGame), with the Tutorial over
      # it while +tutorial_flag+ says it is due, and says how many games
      # are left.
      class Home < Screen
        QUIT_ASK = 2.0 # seconds a second B has to quit from Home

        def initialize(show, start_game:, tutorial_flag:)
          super(show)
          @start_game = start_game
          @tutorial_flag = tutorial_flag
          @planned = nil
          @quit_asked_at = nil
          @quit_asked_by = :b
        end

        # Play: a game starts, or on a first Play, a game with the Tutorial
        # over it, which is seen from then on. With no game left, the offer
        # of Pro opens, leading with games.
        def play
          return unless show.on_home?
          return open_tutorial if @tutorial_flag.due?(played: show.stats_offered?)

          offer_play if @start_game.call == :none_left
        end

        # How to play, H, or a gamepad's Y: a game with the Tutorial over it,
        # at once, whether it was seen or not, as on a first Play.
        def how_to_play
          open_tutorial if show.on_home?
        end

        # B, where a controller has no other way to quit, or a computer's
        # Escape (+by+ :b or :escape): the first press asks, and :quit if a
        # second, of either, comes within QUIT_ASK seconds, so a stray
        # press never closes the game.
        def ask_to_quit(by = :b)
          return unless show.on_home?
          return :quit if quit_asked?

          @quit_asked_at = now
          @quit_asked_by = by
          sounds.play(:tick, pitch: 0.8)
          :asked
        end

        # The key that asked to quit last (#ask_to_quit), :b or :escape,
        # which "Press B again to quit" names.
        attr_reader :quit_asked_by

        # How much of "Press B again to quit" shows: all of it while a
        # second press would quit, fading out in its last third of a second.
        def quit_prompt
          return 0.0 unless quit_asked? && show.home?

          ((QUIT_ASK - (now - @quit_asked_at)) / 0.3).clamp(0.0, 1.0)
        end

        # The large buttons, Friend groups only where a server is offered.
        def tile_names = [:stats, :achievements, :themes, *(:groups if show.group_offered?)]

        # Where its parts go (HomePlan), laid out again only when what it
        # shows has changed, since laying it out measures every line at
        # every size it tries, and a frame asks for it more than once.
        def plan
          screen = HomeScreen.new(layout:, type: style::TYPE, words:, measure:, played: show.stats_offered?, tile_names:,
                                  window: show.window.offered?)
          @planned = [screen, screen.plan] unless @planned&.first == screen
          @planned.last
        end

        # What it says of the games left, or nil where none are counted.
        def games_line = @start_game.left&.then { words.games_left(it) }

        # What Play says, and what it leaves to say beneath it.
        def play_word = @start_game.none_left? ? words.button(:get_pro) : words.play

        def play_note
          left = @start_game.left or return

          @start_game.none_left? ? words.no_games_left(@start_game.daily) : words.games_left(left)
        end

        # A large button's one value.
        def tile_note(name)
          groups = show.group_panel
          case name
          when :stats then words.score_record_line(show.home_entrance.score_record)
          when :achievements then show.achievement_count&.then { AchievementWords.count(it) } || words.tile_note(:to_earn)
          when :themes then words.themes.fetch(show.in_use.key)
          when :groups then groups.member? ? words.titles_held(groups.titles_held, groups.groups.groups.size) : words.tile_note(:take_title)
          end
        end

        # A tap on one of its bright dots pops it, for fun, with no score;
        # anywhere else, nothing happens.
        def empty(x, y, _by)
          dot = show.attract.dots.top_at(x, y)
          show.pop_home_dot(dot, x, y) if dot&.bright?
        end

        def controls
          plan = self.plan
          buttons = plan.tiles.map { |name, rect| button(name, rect) }
          plan.pills.each { |name, rect| buttons << button(name, rect) }
          buttons << primary_button(:play, plan.play_button)
        end

        def primary = play

        # H opens How to play.
        def key_bindings = KEY_BINDINGS
        KEY_BINDINGS = [KeyBinding.new(keys: :h, does: :type)].freeze

        def type(key)
          return false unless key == :h

          how_to_play
          true
        end

        # X Stats, Y How to play, LB Achievements, RB Themes, LT Friend
        # groups, and View/Select Settings.
        def pad(button)
          case button
          in :x then show.open_stats
          in :y then how_to_play
          in :lb then show.open_achievements
          in :rb then show.open_themes
          in :lt then show.open_groups
          in :select then show.open_settings
          else nil
          end
        end

        def answers = %i[play stats achievements themes groups how_to_play settings quit]

        def pressed(name, by)
          case name
          in :play then play
          in :stats then show.open_stats
          in :achievements then show.open_achievements
          in :themes then show.open_themes
          in :groups then show.group_panel.open
          in :how_to_play then how_to_play
          in :settings then show.open_settings
          in :quit then show.window.quit
          else nil
          end
        end

        def announces? = true

        private

        def quit_asked? = @quit_asked_at && now - @quit_asked_at <= QUIT_ASK

        # The Tutorial over a game started paused on the field a game would
        # start on, through the one way into a game; with no game left, the
        # offer of Pro instead, and the Tutorial stays due.
        def open_tutorial
          cabinet = show.cabinet
          opening = TutorialScene.opening(cabinet.field, [layout.center_x, layout.center_y], style:)
          started = @start_game.call(opening)
          return offer_play if started == :none_left
          return unless started == :started

          @tutorial_flag.seen!
          show.tutorial_began
        end

        # The offer of Pro, from Play with no game left; Back from it
        # returns here.
        def offer_play
          return unless show.home? && show.offer.offered?

          show.screens.fetch(:stats).refresh
          show.offer.open_for_play
        end
      end
    end
  end
end
