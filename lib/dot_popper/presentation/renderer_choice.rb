# frozen_string_literal: true

module DotPopper
  module Presentation
    # Which of LÖVE's graphics renderers the game lets it try, decided in
    # conf.rb before the window opens. +renderers+ is the list for
    # t.graphics.renderers, or nil for LÖVE's own; +excluded+ is the list
    # for t.graphics.excluderenderers; +platform+ is RUBY_PLATFORM.
    #
    # LÖVE tries Vulkan first wherever it may, and falls back to OpenGL
    # only when Vulkan can't be created at all, not when it is created but
    # finds no GPU it can use (a virtual machine, a remote desktop, old
    # integrated graphics). So Linux allows only OpenGL, and once Vulkan
    # has failed to start the game on a computer (VulkanFailure), Vulkan
    # is left out there, and LÖVE takes its next renderer: OpenGL on
    # Windows, Metal on a Mac. Android's own "linux" gets LÖVE's order,
    # since it isn't the Linux of a desktop: Vulkan first, then OpenGL ES.
    class RendererChoice < Data.define(:renderers, :excluded, :platform)
      # What a start says when the renderer LÖVE picked can't draw: Vulkan
      # finding no GPU it can use ("Vulkan: failed to find a suitable
      # GPU."), or any other Vulkan error, none of the listed renderers
      # creating at all, or the system refusing the window.
      FAILED_START = Regexp.union("Vulkan", "suitable GPU", "no supported renderer", "Could not set window mode")

      # The choice for +asked+, the renderers DOT_POPPER_RENDERERS names
      # (RendererChoice.asked), on +platform+, once Vulkan has failed here
      # or not.
      def self.decide(asked:, platform:, vulkan_failed: false)
        listed = asked.empty? ? usual(platform) : asked
        return new(renderers: listed, excluded: [], platform:) unless vulkan_failed

        rest = listed&.-([:vulkan])
        new(renderers: rest&.empty? ? nil : rest, excluded: [:vulkan], platform:)
      end

      # The renderers a comma-separated +text+ names, such as "opengl" or
      # "vulkan, opengl", as Symbols.
      def self.asked(text) = text.to_s.split(",").map(&:strip).reject(&:empty?).map(&:to_sym)

      # Only OpenGL on Linux; LÖVE's own order elsewhere, Android's too.
      def self.usual(platform) = platform.include?("linux") && !platform.include?("android") ? [:opengl] : nil

      # Whether LÖVE may try Vulkan: Apple's systems have only Metal.
      def vulkan_allowed?
        return false if excluded.include?(:vulkan)

        renderers ? renderers.include?(:vulkan) : !platform.match?(/darwin|ios/)
      end

      # Whether +error+, raised before or while the game started, is one
      # leaving Vulkan out may get past. Once Vulkan is out, none is, so
      # the game never starts again more than once.
      def rescues?(error) = vulkan_allowed? && error.is_a?(RuntimeError) && FAILED_START.match?(error.message)
    end
  end
end
