# frozen_string_literal: true

module DotPopper
  module Composition
    class Root
      # What a test build puts together where a build for sale has nothing
      # (Root#test_store and the rest): the fake store, its scenarios' themes,
      # the fake setdef server and the fake website checkout, each only when
      # the build has no channel, as before they moved here.
      module TestBuildParts
        private

        def test_store = FakeStore.new(file("fake_store.txt"), fails: FakeStore.failure(settings.env))

        # A scenario's unlocks and theme, in place of the server's.
        def use_fixture(themes, use_theme)
          keys = settings["DOT_POPPER_THEME_UNLOCKS"]
          themes.release(keys.split(",")) if keys
          key = settings["DOT_POPPER_THEME"]&.to_sym or return

          use_theme.call(key)
        end

        def test_watch(license, pins)
          return super if settings.store_build?

          fake = Continuity::FakeSetdef.new(file("fake_setdef.txt"), mode: Continuity::FakeSetdef.mode(settings.env))
          Continuity::Watch.new(server: fake, connectivity: fake, gone: @gone, license:, today: settings.today, pins:)
        end

        def test_checkout(clipboard) = FakeCheckout.new(clipboard:)
      end
      prepend TestBuildParts
    end
  end
end
