# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = true
end

# Type-checks the rules core against sig/. Steep runs as its own command,
# so rake test never loads it.
desc "Type-check the rules core with Steep"
task :steep do
  sh "bundle exec steep check"
end

task default: %i[test steep]
