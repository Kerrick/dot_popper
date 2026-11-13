# frozen_string_literal: true

require_relative "../presentation/presentation_helper"
require "platforms_helper"
require "dot_popper/composition/root"
require "dot_popper/privacy/save_files"

# What the composition root asks of the engine, answered without Lota:
# memory save files (each name still declared, as Shell::SaveFile
# requires), a window of a fixed size, and stand-ins that remember what
# they were asked.
class FakeEngine
  include PresentationTest

  Memory = DotPopper::ScoreRecord::Memory

  # A computer's window control, made with whether its fullscreen is
  # exclusive.
  class DesktopWindow < FakeWindow
    attr_reader :exclusive

    def initialize(exclusive:)
      super()
      @exclusive = exclusive
    end
  end

  # What draws, which remembers the theme it was last told to use.
  class Pen
    attr_reader :shaders, :theme

    def initialize(shaders:) = @shaders = shaders
    def use(theme) = (@theme != theme) && (@theme = theme)
    def fonts = nil
  end

  # What plays the sounds, with the store its mute is kept in.
  class SoundPlayer < FakeSounds
    attr_reader :store, :theme

    def initialize(store:)
      super()
      @store = store
      @muted = store.read == "muted"
    end

    def use(theme) = @theme = theme
  end

  # The system's URL opener, which takes every URL and remembers it.
  class Opener
    attr_reader :urls

    def initialize = @urls = []
    def open(url) = (@urls << url) && true
  end

  # A computer's store helper, as the shell would start it.
  class StoreHelper < Data.define(:automated)
    def path = "-"
    def open(_url) = !automated
    def read = nil
    def remove = nil
  end

  # The phone host's answer file.
  class Answers < Data.define(:path)
    def read = nil
    def remove = nil
  end

  attr_reader :platform, :unit, :files, :said, :opened, :opener, :buzzer, :clipboard

  # On the system Lota::System.os calls +system+, in a window of +width+
  # by +height+ units.
  def initialize(system, width: 1200, height: 800)
    @platform = DotPopperTest.platform(system)
    @unit = DotPopper::Shell::Platforms.unit(system)
    @width = width
    @height = height
    @files = {}
    @said = []
    @opened = nil
    @opener = Opener.new
    @buzzer = FakeHaptics.new
    @clipboard = MemoryClipboard.new
  end

  def file(name)
    DotPopper::Privacy::SaveFiles.declare!(name)
    @files[name] ||= Memory.new
  end

  def path(name) = "/save/#{name}"
  def say(line) = @said << line
  def dimensions = [@width, @height]
  def layout = Layout.new(width: @width, height: @height, safe: Rect.new(x: 0, y: 0, width: @width, height: @height), style: Style::LAYOUT)
  def fill_screen = @opened = :filled
  def open_window(radius:, wanted:, smallest:) = @opened = { radius:, wanted:, smallest: }
  def desktop_window(exclusive:) = DesktopWindow.new(exclusive:)
  def pen(shaders:) = Pen.new(shaders:)
  def measure(_pen) = RoughMeasure.new
  def speaker(store:) = SoundPlayer.new(store:)
  def notices = Notices.none
  def store_helper(automated:) = StoreHelper.new(automated:)
  def store_answers = Answers.new(path: "/save/store_answer.txt")
end
