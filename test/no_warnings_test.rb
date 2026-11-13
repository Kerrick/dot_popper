# frozen_string_literal: true

require "open3"
require "test_helper"

# Ruby only warns at a mistake such as a key written twice in one hash,
# where the second silently wins, so every file is compiled with warnings
# on, and any warning fails. A duplicated key in Home's words once
# reached a build this way.
class NoWarningsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_no_file_warns_when_compiled
    files = Dir[File.join(ROOT, "{lib,script,test}/**/*.rb")] + Dir[File.join(ROOT, "*.rb")]
    # The files' names go in on standard input, not as arguments: a system
    # limits how long a command line may be, and Windows' limit is shorter
    # than the names of every file put end to end.
    _, warnings, status = Open3.capture3(RbConfig.ruby, "-w", "-e",
                                         "$stdin.each_line(chomp: true) { RubyVM::InstructionSequence.compile_file(it) }",
                                         stdin_data: files.join("\n"))

    assert_predicate status, :success?, warnings
    assert_empty warnings
  end
end
