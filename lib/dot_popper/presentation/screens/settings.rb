# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Settings, over Home (SettingsScreen): its rows of choices, Credits
      # and licenses, Privacy, Change Server while setdef is gone, and
      # Back. Only the buttons in view take presses.
      class Settings < Page
        def controls
          plan = show.settings_plan
          rows = plan.rows.flat_map { |row| row.choices.zip(row.rects).map { |(_, _, name), rect| button(name, rect) } }
          page = layout.page
          seen = (rows + [button(:credits, plan.credits), button(:privacy, plan.privacy), *(button(:server, plan.server) if plan.server)])
                 .select { it.frame.center_y.between?(page.y, page.bottom) }
          seen.map { it.with(frame: it.frame.cut(top: page.y, bottom: page.bottom), reach: it.reach.cut(top: page.y, bottom: page.bottom)) } <<
            back_button
        end

        # C opens Credits and licenses.
        def type(key)
          return false unless key == :c

          show.open_credits
          true
        end

        # View/Select Sound, LB Dot size where it is offered, RB Display,
        # X Credits and licenses, Y Privacy.
        def pad(button)
          case button
          in :lb then show.choose_sizing(show.cabinet.sizing.toggled) if show.sizing_offered?
          in :rb then show.next_display
          in :x then show.open_credits
          in :y then show.open_privacy
          in :select then show.set_sound(show.sounds.muted?)
          else nil
          end
        end
      end
    end
  end
end
