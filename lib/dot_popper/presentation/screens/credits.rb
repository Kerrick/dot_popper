# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Credits and licenses, over Settings (CreditsLayout): the text that
      # scrolls, and Back.
      class Credits < Page
        def controls = [back_button]

        def scrolls? = true

        # The text is read with the left stick too, and the cursor waits.
        def stick_scrolls? = true
      end
    end
  end
end
