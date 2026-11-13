# frozen_string_literal: true

require_relative "../presentation/presentation_helper"
require "dot_popper/shell/vulkan_rescue"

# Which errors the Vulkan rescue takes (Shell::VulkanRescue): LÖVE's
# words for a renderer that can't start the game, and only while Vulkan
# may still be tried, so the game never starts a third time.
class VulkanRescueTest < Minitest::Test
  RendererChoice = DotPopper::Shell::RendererChoice
  VulkanRescue = DotPopper::Shell::VulkanRescue

  WINDOWS = "x64-mingw-ucrt"
  LINUX = "x86_64-linux"
  MAC = "arm64-darwin25"
  ANDROID = "aarch64-linux-android"
  NO_GPU = RuntimeError.new("Vulkan: failed to find a suitable GPU.")

  def rescue_for(asked: [], platform: WINDOWS, vulkan_failed: false)
    VulkanRescue.new(RendererChoice.decide(asked:, ruby_platform: platform, vulkan_failed:), title: "Dot Popper", env: {})
  end

  def test_it_rescues_vulkan_finding_no_gpu_while_vulkan_may_be_tried
    assert rescue_for.rescues?(NO_GPU)
    assert rescue_for(platform: ANDROID).rescues?(NO_GPU)
    assert rescue_for(asked: [:vulkan], platform: MAC).rescues?(
      RuntimeError.new("Cannot create graphics: no supported renderer on this system.")
    )
    assert rescue_for.rescues?(RuntimeError.new("Could not set window mode"))
  end

  def test_it_never_rescues_twice_or_where_vulkan_was_not_tried
    refute rescue_for(vulkan_failed: true).rescues?(NO_GPU), "the second start shows the error"
    refute rescue_for(platform: LINUX).rescues?(NO_GPU)
    refute rescue_for(platform: MAC).rescues?(NO_GPU)
  end

  def test_it_leaves_the_games_own_errors_to_the_error_screen
    refute rescue_for.rescues?(RuntimeError.new("score went below zero"))
    refute rescue_for.rescues?(NoMethodError.new("undefined method 'x' for an instance of Vulkan"))
    assert_nil rescue_for.rescue(RuntimeError.new("score went below zero"))
  end
end
