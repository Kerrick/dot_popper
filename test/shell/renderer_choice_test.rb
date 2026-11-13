# frozen_string_literal: true

require "test_helper"
require "dot_popper/shell/vulkan_rescue"

class RendererChoiceTest < Minitest::Test
  RendererChoice = DotPopper::Shell::RendererChoice
  VulkanFailure = DotPopper::Shell::VulkanFailure
  Relaunch = DotPopper::Shell::Relaunch

  WINDOWS = "x64-mingw-ucrt"
  LINUX = "x86_64-linux"
  MAC = "arm64-darwin25"
  ANDROID = "aarch64-linux-android"

  def decide(asked: [], platform: WINDOWS, vulkan_failed: false) = RendererChoice.decide(asked:, ruby_platform: platform, vulkan_failed:)

  def test_windows_keeps_loves_order_so_vulkan_comes_first
    choice = decide

    assert_nil choice.renderers
    assert_empty choice.excluded
    assert_predicate choice, :vulkan_allowed?
  end

  def test_linux_allows_only_opengl
    assert_equal [:opengl], decide(platform: LINUX).renderers
  end

  def test_android_keeps_loves_order_so_vulkan_comes_first
    choice = decide(platform: ANDROID)

    assert_nil choice.renderers
    assert_predicate choice, :vulkan_allowed?, "the note can still leave Vulkan out at the next start"
    assert_equal [:opengl], decide(asked: [:opengl], platform: ANDROID).renderers
  end

  def test_apple_systems_never_try_vulkan
    refute_predicate decide(platform: MAC), :vulkan_allowed?
  end

  def test_the_environment_names_the_renderers
    assert_equal %i[vulkan opengl], RendererChoice.asked(" vulkan, opengl ,")
    assert_empty RendererChoice.asked(nil)
    assert_equal [:vulkan], decide(asked: [:vulkan], platform: LINUX).renderers
  end

  def test_once_vulkan_failed_it_is_left_out_so_love_takes_its_next_renderer
    choice = decide(vulkan_failed: true)

    assert_nil choice.renderers
    assert_equal [:vulkan], choice.excluded
    refute_predicate choice, :vulkan_allowed?
  end

  def test_a_failed_vulkan_beats_asking_for_it_alone
    assert_nil decide(asked: [:vulkan], platform: LINUX, vulkan_failed: true).renderers
    assert_equal [:opengl], decide(asked: %i[vulkan opengl], vulkan_failed: true).renderers
    assert_equal [:opengl], decide(platform: LINUX, vulkan_failed: true).renderers
  end

  def test_a_vulkan_failure_holds_for_a_month_then_vulkan_is_tried_again
    note = VulkanFailure.parse("2026-11-07\n")

    assert note.holds?(Date.new(2026, 11, 7))
    assert note.holds?(Date.new(2026, 12, 6))
    refute note.holds?(Date.new(2026, 12, 7))
    assert_equal Date.new(2026, 12, 7), note.retry_on
    assert note.holds?(Date.new(2026, 1, 1)), "a clock set back keeps it"
    assert_equal "2026-11-07", note.to_s
  end

  def test_no_note_or_a_garbled_one_is_no_failure
    assert_nil VulkanFailure.parse(nil)
    assert_nil VulkanFailure.parse("opengl")
  end

  def relaunch(platform: WINDOWS, fused: true, exists: ->(_) { true })
    Relaunch.new(ruby_platform: platform, fused:, program: "C:/Games/Dot Popper/app/main.rb", arguments: ["--x"],
                 ruby: "C:/Games/Dot Popper/ruby/bin/ruby.exe", title: "Dot Popper", exists:)
  end

  def test_under_lota_run_it_runs_lota_again_even_on_windows
    assert_equal ["C:/Games/Dot Popper/ruby/bin/ruby.exe", "C:/Games/Dot Popper/app/main.rb", "run", "--x"],
                 relaunch(fused: false).command
  end

  def test_a_windows_app_starts_its_own_exe_again
    assert_equal ["C:/Games/Dot Popper/Dot Popper.exe", "--x"], relaunch.command
    assert_nil relaunch(exists: ->(_) { false }).command, "with no exe, the player is asked"
  end

  def test_a_mac_or_linux_app_runs_its_program_again_with_its_ruby
    assert_equal ["C:/Games/Dot Popper/ruby/bin/ruby.exe", "C:/Games/Dot Popper/app/main.rb", "--x"],
                 relaunch(platform: LINUX).command
  end

  def test_a_phone_cannot_start_itself_again
    assert_nil relaunch(platform: ANDROID).command
    assert_nil relaunch(platform: "arm64-ios").command
  end
end
