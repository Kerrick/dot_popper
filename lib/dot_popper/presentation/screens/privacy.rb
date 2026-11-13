# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Privacy, over Settings (PrivacyScreen): Read the privacy policy,
      # Delete my friend group data for a player the group server knows,
      # and Back.
      class Privacy < Page
        # Where its lines and buttons go (PrivacyScreen), laid out again
        # only when the window, the words or the friend-group server's
        # knowing the player changes.
        def plan
          words = self.words
          layout = self.layout
          known = show.group_panel.known?
          (@plan ||= Memo.new).fetch([layout, words, known]) do
            lines = [[:bars, words.button(:privacy_stats)], [:crown, words.button(:privacy_groups)]]
            PrivacyScreen.new(layout:, measure:, lines:, note: words.button(:privacy_delete_note), deletable: known).plan
          end
        end

        # Everything its painter draws (PrivacyDrawing), made again only
        # when the plan, the words, a button's light or the hold changes.
        def drawing
          plan = self.plan
          words = self.words
          hover = show.hover
          hold = show.group_panel.hold
          progress = hold.progress(now)
          (@drawing ||= Memo.new).fetch([plan, words, hover, hold.held?, progress]) do
            hold_text = words.button(:privacy_hold)
            noted = !plan.note_lines.empty?
            rows = noted ? Words.wrap(hold_text, plan.delete.width) { measure.width(:semibold, 15, it) } : []
            PrivacyDrawing.new(header: HeaderDrawing.for(words.button(:privacy_heading), layout:, measure:, words:, hover:), plan:,
                               policy: words.button(:privacy_policy), policy_hover: hover.level(:policy),
                               delete: words.button(:privacy_delete), delete_hover: hover.level(:privacy_delete),
                               held: hold.held?, progress:, note_x: layout.center_x, hold_line: (hold_text if noted && !hold.held?),
                               hold_rows: rows.size > 1 ? rows : [])
          end
        end

        def controls
          plan = self.plan
          [button(:policy, plan.policy), (button(:privacy_delete, plan.delete) if plan.delete), back_button].compact
        end

        # X Read the privacy policy; Y hold to delete my friend group data.
        def pad(button)
          case button
          in :x then show.open_policy
          in :y then show.group_panel.hold_delete(:y, show.now)
          else nil
          end
        end

        def answers = [*super, :policy, :privacy_delete]

        def pressed(name, by)
          case name
          in :policy then show.open_policy
          in :privacy_delete then show.group_panel.hold_delete(by, show.now)
          else super
          end
        end
      end
    end
  end
end
