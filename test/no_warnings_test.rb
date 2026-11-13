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
    _, warnings, status = Open3.capture3(RbConfig.ruby, "-w", "-e",
                                         "ARGV.each { RubyVM::InstructionSequence.compile_file(it) }", *files)

    assert_predicate status, :success?, warnings
    assert_empty warnings
  end
end
