# frozen_string_literal: true

require "test_helper"
require "prism"

# The shell talks to Lota, so most of it runs only with a window. This
# test loads it without one and checks, for every class in it, that each
# method it calls on itself is one it has: a call to a method that does
# not exist would otherwise surface only when that line first runs in
# front of a player, as a definition hidden behind a trailing `if` once
# did.
class DefinedCallsTest < Minitest::Test
  SHELL = File.expand_path("../../lib/dot_popper/shell", __dir__)

  def setup
    require "lota"
    require "dot_popper/shell"
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  def test_every_method_a_shell_class_calls_on_itself_exists
    Dir[File.join(SHELL, "*.rb")].each do |path|
      Prism.parse_file(path).value.statements.body.each { check(it, [], path) }
    end
  end

  # main.rb hands each Lota callback to a method of the App; one it lacks
  # would fail only when Lota first called it in front of a player.
  def test_every_method_main_hands_a_lota_callback_to_exists
    main = File.expand_path("../../main.rb", __dir__)
    handed = main_calls(Prism.parse_file(main).value)
    refute_empty handed
    handed.each { assert DotPopper::Shell::App.method_defined?(it), "main.rb hands a callback to App##{it}, which it doesn't define" }
  end

  private

  def main_calls(node, found = [])
    found << node.name if node.is_a?(Prism::CallNode) && node.receiver.is_a?(Prism::InstanceVariableReadNode) && node.receiver.name == :@app
    node.compact_child_nodes.each { main_calls(it, found) }
    found.uniq
  end

  def check(node, namespace, path)
    case node
    when Prism::ModuleNode, Prism::ClassNode
      inner = namespace + [node.constant_path.slice]
      node.body&.body&.each { check(it, inner, path) }
      verify(inner.join("::"), node, path) if node.is_a?(Prism::ClassNode)
    end
  end

  def verify(name, klass_node, path)
    klass = Object.const_get(name)
    calls(klass_node).each do |call|
      known = klass.method_defined?(call) || klass.private_method_defined?(call) ||
              klass.respond_to?(call, true) || Kernel.respond_to?(call, true)
      assert known, "#{File.basename(path)}: #{name} calls #{call}, which it doesn't define"
    end
  end

  # Receiverless calls inside the class's own method bodies, leaving out
  # nested classes, which are checked on their own.
  def calls(klass_node, found = [])
    stack = klass_node.body ? [klass_node.body] : []
    until stack.empty?
      node = stack.pop
      next if node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)

      found << node.name if node.is_a?(Prism::CallNode) && node.receiver.nil? && !node.name.end_with?("=")
      stack.concat(node.compact_child_nodes)
    end
    found.uniq - local_names(klass_node)
  end

  # Block and method parameters, and locals, that Prism reports as calls
  # never are, but a bare `it` or a local read is a LocalVariableReadNode,
  # so only names that are methods remain. Data members are methods too.
  def local_names(_klass_node) = %i[it]
end
