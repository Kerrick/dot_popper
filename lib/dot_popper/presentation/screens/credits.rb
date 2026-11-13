# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Credits and licenses, over Settings (CreditsLayout): the text that
      # scrolls, and Back.
      class Credits < Page
        def controls = [back_button]
      end
    end
  end
end
