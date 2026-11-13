# frozen_string_literal: true

module DotPopper
  module Presentation
    # Moved to the core, as Monetization's (DotPopper::Store); this name stays
    # until its last user has moved.
    Storefront = DotPopper::Store
    NativeStore = DotPopper::NativeStore
    NoStorefront = DotPopper::NoStore
  end
end
