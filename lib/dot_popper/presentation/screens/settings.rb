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
      end
    end
  end
end
