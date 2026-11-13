# frozen_string_literal: true

module DotPopper
  # What the system the game runs on means for the game, as the game's own
  # questions. The shell makes one when the game starts, from the engine's
  # name for the system (Shell::Platforms); nothing but the shell compares
  # a system's name.
  #
  # [touch] a phone or tablet: played by touch, filling the screen, and
  #   never quit or taken out of fullscreen from a keyboard
  # [quits_itself] whether the game may quit itself, as every system's
  #   but iOS's may, whose apps are left by the system alone
  # [buzzes] whether a pop and a mistake buzz the device
  # [command_key] whether shortcuts are held with Command, not Ctrl
  # [phone_host] whether the game runs in the phone host, which catches
  #   the game's own URLs for the system's share sheet and its store
  # [own_store] the channel (Build) of the computer's own store, whose
  #   build sells through the store helper shipped beside the game, or nil
  # [website_sales] whether a copy may sell through setdef's website
  #   (never an iOS copy: Apple 3.1.1)
  class Platform < Data.define(:touch, :quits_itself, :buzzes, :command_key, :phone_host, :own_store, :website_sales)
    # A computer, played with a mouse, a keyboard or a gamepad.
    COMPUTER = new(touch: false, quits_itself: true, buzzes: false, command_key: false, phone_host: false, own_store: nil,
                   website_sales: true)

    # A phone or tablet, in the phone host.
    PHONE = new(touch: true, quits_itself: true, buzzes: false, command_key: false, phone_host: true, own_store: nil,
                website_sales: true)

    def touch? = touch
    def quits_itself? = quits_itself
    def buzzes? = buzzes
    def command_key? = command_key
    def phone_host? = phone_host
    def website_sales? = website_sales
  end
end
