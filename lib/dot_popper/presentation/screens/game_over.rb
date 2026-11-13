# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Game Over, over the finished game's pile (GameOverScreen): Play
      # again, Home, Share my score, and the lines that open something.
      # Play again starts the next game through +start_game+
      # (UseCases::StartGame); Share my score offers the result through
      # +sharing+ (InGameSharing's methods).
      class GameOver < Screen
        def initialize(show, start_game:, sharing:)
          super(show)
          @start_game = start_game
          @sharing = sharing
          @planned = nil
        end

        # Home: back Home, once the game will hear a press
        # (Rules::GAME_OVER_GRACE).
        def continue_on
          show.cabinet.press(layout.center_x, layout.center_y) if show.game_over?
        end

        # Play again: Home, and at once Play, so another game is one press.
        # With no game left it says Get Pro, and opens the offer over Game
        # Over, which Back closes to Game Over as it was.
        def play_again
          return unless show.game_over? && show.cabinet.state.ready?
          return show.offer.open_for_play if @start_game.none_left? && show.offer_offered?

          continue_on
          show.play
        end

        # One of its lines that opens something: a new achievement in its
        # dialog, or the friend group whose title the game took.
        def open_from(what)
          return unless show.game_over? && show.cabinet.state.ready?

          achievement = show.game_over.achievements.first
          group = show.group_panel.game_title_taken
          continue_on
          case what
          when :achievement
            show.open_achievements
            show.screens.fetch(:achievement_dialog).open_at(achievement) if achievement
          when :group then group ? show.group_panel.open_at(group) : show.group_panel.open
          end
        end

        # Its lines in pills of their own (GameOverChip): today's goal met,
        # a new achievement, which opens it, and what the game did in the
        # friend groups, which opens the group whose title it took.
        def chips
          over = show.game_over or return []
          groups = show.group_panel
          group = groups.game_line.to_s.strip
          [(GameOverChip.new(name: :over_goal, text: words.goal_met, glyph: :check, opens: false) if over.goal_met),
           (GameOverChip.new(name: :over_achievement, text: AchievementWords.earned(over.achievements), glyph: :achievement, opens: true) if over.achievements.any?),
           (GameOverChip.new(name: :over_group, text: group, glyph: :crown, opens: !groups.game_title_taken.nil?) unless group.empty?)].compact
        end

        # Its words to lay out (GameOverScreen), or nil before a game has
        # finished.
        def layout_screen
          over = show.game_over or return
          GameOverScreen.new(layout:, type: style::TYPE, words:, measure:, scrim: style::GAME_OVER_BACKING, game_over: over,
                             below: layout.safe.y, radius: show.cabinet.game&.field&.radius || show.radius, chips:,
                             play_word: @start_game.none_left? ? words.button(:get_pro) : words.play_again, play_note: show.play_note)
        end

        # Where its words and buttons go (GameOverPlan), laid out again only
        # when what it shows has changed, since laying it out measures every
        # line, and a frame asks for it more than once.
        def plan
          screen = layout_screen or return
          @planned = [screen, screen.plan] unless @planned&.first == screen
          @planned.last
        end

        # Share my score: offers the game's result to share, which in the
        # game opens the share preview, and copies nothing yet; on a phone
        # it opens the system's share sheet, and no preview.
        def share
          return unless show.game_over? && show.game_over

          preview = @sharing.offer(share_text, now) or return sounds.play(:tick)
          show.screens.fetch(:share_preview).open_with(preview)
          sounds.play(:tick)
        end

        def controls
          plan = self.plan or return []
          buttons = chips.each_with_index.filter_map { |chip, i| button(chip.name, plan[[:chip, i]]) if chip.opens && plan[[:chip, i]] }
          [*buttons, (button(:home, plan.home_button) if plan.home_button), (button(:share, plan.share_button) if plan.share_button),
           (primary_button(:play_again, plan.play_button) if plan.play_button)].compact
        end

        def primary = play_again

        # Y Share my score; LB opens the new achievement, and RB the friend
        # group, as their lines say.
        def pad(button)
          return share if button == :y

          chip = { lb: :over_achievement, rb: :over_group }[button] or return
          open_from(chip == :over_achievement ? :achievement : :group) if chips.any? { it.name == chip && it.opens }
        end

        # Escape or B goes Home, as Home does.
        def back
          continue_on
          true
        end

        def answers = %i[play_again home share over_achievement over_group]

        def pressed(name, by)
          case name
          in :play_again then play_again
          in :home then continue_on
          in :share then share
          in :over_achievement then open_from(:achievement)
          in :over_group then open_from(:group)
          else nil
          end
        end

        # A press away from its buttons waits, as it may drag the pile.
        def waits_for_release?(x, y) = show.control_at(x, y).nil?

        def announces? = true

        private

        # The finished game's result, as Words#share_text says it.
        def share_text
          over = show.game_over
          words.share_text(over.score, over.stats, score_record: over.score_record, new_score_record: over.new_score_record?,
                           record: over.record, screen: over.screen, first: over.first)
        end
      end
    end
  end
end
