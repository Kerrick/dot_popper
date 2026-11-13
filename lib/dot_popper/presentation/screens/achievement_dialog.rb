# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # An achievement's dialog, over Achievements (the layout is
      # Presentation::AchievementDialog): how to earn it, for Pro the day it
      # was earned and how far along the player is, as +view_achievements+
      # (UseCases::ViewAchievements) may show; Close, Get Pro for a Free
      # player, and with a controller the previous and next achievement.
      class AchievementDialog < Screen
        def initialize(show, view_achievements:)
          super(show)
          @view = view_achievements
        end

        # The achievement it shows (Achievement::IDS).
        attr_reader :achievement

        # Opens over Achievements, showing +id+.
        def open_at(id)
          show.open_layer(self)
          @achievement = id
          sounds.play(:tick)
        end

        def close
          show.close_layer(self)
          sounds.play(:tick, pitch: 0.8)
        end

        # The previous (+by+ -1) or next (1) achievement, round the ends.
        def step(by)
          ids = DotPopper::Achievement::IDS
          @achievement = ids[((ids.index(achievement) || 0) + by) % ids.size]
          sounds.play(:tick)
        end

        # Get Pro, for a Free player: the offer opens over Achievements,
        # leading with this achievement, and the dialog closes.
        def get_pro
          id = achievement
          show.offer.open_led_by(:achievements)
          show.offer.led_by_achievement(id)
          show.close_layer(self)
        end

        # Where its parts go (AchievementDialogPlan).
        def plan
          Presentation::AchievementDialog.new(layout:, measure:, how: AchievementWords.how(achievement), status: status(achievement),
                                              progress: @view.progress(achievement), buttons:).plan
        end

        # What it says of +id+'s state: the earned day or "Not earned yet",
        # or nothing for a Free player.
        def status(id)
          return if @view.locked?

          day = @view.day(id)
          day ? AchievementWords.earned_on(day) : words.button(:not_earned)
        end

        def controls = plan.buttons.map { |name, rect| button(name, rect) }

        def primary = close

        def back
          close
          true
        end

        # LB and RB: the previous and next achievement.
        def pad(button)
          case button
          in :lb then step(-1)
          in :rb then step(1)
          else nil
          end
        end

        def pressed(name, by)
          case name
          in :achievement_close then close
          in :achievement_prev then step(-1)
          in :achievement_next then step(1)
          in :achievement_pro then get_pro
          else nil
          end
        end

        # A tap beside the card closes it; on the card it does nothing.
        def empty(x, y, _by) = (close unless plan.card.contains?(x, y))

        private

        def buttons
          steps = show.input == InputKind::GAMEPAD ? [[:achievement_prev, :prev], [:achievement_next, :next]] : []
          return [[:achievement_close, :close], *steps] unless @view.locked?

          [[:achievement_pro, :get_pro], [:achievement_close, :close], *steps]
        end
      end
    end
  end
end
