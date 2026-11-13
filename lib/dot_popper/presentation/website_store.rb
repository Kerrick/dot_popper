# frozen_string_literal: true

module DotPopper
  module Presentation
    # Moved to the core, as Monetization's (DotPopper::WebsiteStore); this name stays
    # until its last user has moved.
    WebsiteStore = DotPopper::WebsiteStore
    BrowserCheckout = DotPopper::BrowserCheckout
    FakeCheckout = DotPopper::FakeCheckout
  end
end
