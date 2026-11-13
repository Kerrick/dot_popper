# frozen_string_literal: true

require "test_helper"
require "open3"
require "rake"

# test/gui/scenarios_test.rb starts the real game in a window once a
# test, so it refuses to load unless the windows were asked for:
# rake test:gui asks, by setting DOT_POPPER_OPEN_WINDOWS=1 before it
# loads the file. Each check here runs the file with a name filter no
# test matches, and with no PATH, so no `bundle exec lota run` could
# start: even a guard that let it through would open nothing.
class GuiGuardTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCENARIOS = File.join(ROOT, "test/gui/scenarios_test.rb")
  NO_TEST = "/\\Anothing matches this\\z/"

  def test_the_scenarios_refuse_to_load_unless_windows_are_asked_for
    [nil, "", "0", "yes"].each do |asked|
      output, status = run_scenarios(asked)
      refute status.success?, "with DOT_POPPER_OPEN_WINDOWS=#{asked.inspect} the scenarios should refuse"
      assert_includes output, "bundle exec rake test:gui"
      assert_includes output, "DOT_POPPER_OPEN_WINDOWS=1"
      refute_match(/\d+ runs/, output, "the refusal should come before Minitest runs anything")
    end
  end

  def test_the_scenarios_load_when_windows_are_asked_for
    output, = run_scenarios("1") # Minitest fails a filter that matched nothing
    refute_includes output, "runs only when asked"
    assert_match(/^0 runs, 0 assertions/, output)
  end

  def test_rake_test_gui_asks_for_the_windows
    rake = Rake::Application.new
    Rake.with_application(rake) do
      Dir.chdir(ROOT) { rake.load_rakefile }
      assert_equal ["open_windows"], rake["test:gui"].prerequisites
      before = ENV.delete("DOT_POPPER_OPEN_WINDOWS")
      begin
        rake["test:open_windows"].invoke
        assert_equal "1", ENV.fetch("DOT_POPPER_OPEN_WINDOWS", nil)
      ensure
        before ? ENV["DOT_POPPER_OPEN_WINDOWS"] = before : ENV.delete("DOT_POPPER_OPEN_WINDOWS")
      end
    end
  end

  private

  def run_scenarios(asked)
    env = { "DOT_POPPER_OPEN_WINDOWS" => asked, "PATH" => "" }
    Open3.capture2e(env, RbConfig.ruby, SCENARIOS, "-n", NO_TEST, chdir: ROOT)
  end
end
