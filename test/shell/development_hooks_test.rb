# frozen_string_literal: true

require_relative "../composition/fake_engine"
require "dot_popper/shell/development_hooks"

# The development and automation hooks (Shell::DevelopmentHooks): a run
# with none of their settings has none, so its frames do nothing for
# them, and a store build obeys them as a test build does (each is in
# Build::HARMLESS), since the packaged-app playthroughs need them.
class DevelopmentHooksTest < Minitest::Test
  include PresentationTest

  HOOKS = { "DOT_POPPER_SHOTS" => "0.5,3", "DOT_POPPER_QUIT_AFTER" => "20", "DOT_POPPER_PERF" => "1",
            "DOT_POPPER_FAKE_DRAG" => "0.5,0.9,0.3,0.3" }.freeze

  def hooks(env, channel: nil)
    settings = DotPopper::Composition::DeveloperSettings.new(env, channel:)
    game = DotPopper::Composition::Root.new(engine: FakeEngine.new("Linux"), settings:)
    DotPopper::Shell::DevelopmentHooks.for(settings, cabinet: game.cabinet, show: game.show, pile: nil, dragging: nil,
                                                     pad: ->(*) {})
  end

  def test_a_run_with_no_hook_set_has_none
    [nil, *DotPopper::Build::CHANNEL_NAMES].each do |channel|
      assert_nil hooks({ "DOT_POPPER_SHOTS" => "", "DOT_POPPER_FAKE_DRAG" => "nonsense" }, channel:), channel.inspect
    end
  end

  def test_each_hook_is_obeyed_in_every_build
    HOOKS.each do |name, value|
      assert_includes DotPopper::Build::HARMLESS, name
      [nil, *DotPopper::Build::CHANNEL_NAMES].each do |channel|
        refute_nil hooks({ name => value }, channel:), "#{name} in #{channel.inspect}"
      end
    end
  end

  def test_the_frame_meter_notes_what_the_game_announces
    hook = hooks({ "DOT_POPPER_PERF" => "1" })
    hook.frame_started(1 / 60.0)
    hook.happened("a resize")

    assert_equal ["a resize", 0.0], hook.instance_variable_get(:@recent)
  end
end
