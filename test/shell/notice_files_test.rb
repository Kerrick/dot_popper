# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "dot_popper/presentation"
require "dot_popper/shell/notice_files"

# Finding the license texts a build carries, from the game's folder up,
# without a window. The fixtures lay out a fused app: app/game is the
# game, app/NOTICES.txt is Lota's, and notices/ beside app is Fledge's.
class NoticeFilesTest < Minitest::Test
  FIXTURES = File.expand_path("../fixtures", __dir__)
  APP = File.join(FIXTURES, "notices")
  LOTA = "Lota fixture notices\n\nLibrary A is MIT.\n"

  def test_a_fused_app_gives_every_text_nearest_first
    notices = DotPopper::Shell::NoticeFiles.new(game: File.join(APP, "app", "game")).notices

    assert_equal LOTA, notices.lota
    assert_equal ["Fledge fixture runtime\n", "Fledge fixture gems\n"], notices.fledge, "NOTICES.txt first, no sources"
  end

  def test_the_games_own_texts_are_read_from_its_folder
    notices = DotPopper::Shell::NoticeFiles.new(game: File.join(APP, "game")).notices

    assert_equal "Fixture AGPL\n", notices.agpl
    assert_equal "Copyright 2016 Fixture Authors\n", notices.ofl
  end

  def test_the_program_folder_is_searched_too
    notices = DotPopper::Shell::NoticeFiles.new(game: File.join(FIXTURES, "bare", "game"),
                                                starts: [File.join(APP, "app", "bin")]).notices

    assert_equal LOTA, notices.lota
  end

  def test_a_build_without_any_of_it_gives_nothing_and_no_error
    notices = DotPopper::Shell::NoticeFiles.new(game: File.join(FIXTURES, "bare", "game"), reach: 1).notices

    assert_equal DotPopper::Presentation::Notices.none, notices
  end

  # An Android or iOS app: the project's top holds NOTICES.txt (written by
  # script/phone_notices.rb), notices/ is Fledge's, and the game is two
  # folders down, in game/dot_popper.
  def test_a_phone_app_finds_the_notices_at_the_projects_top
    Dir.mktmpdir do |root|
      game = File.join(root, "game", "dot_popper")
      FileUtils.mkdir_p([game, File.join(root, "notices")])
      File.write(File.join(root, "NOTICES.txt"), "Phone notices\n")
      File.write(File.join(root, "notices", "NOTICES.txt"), "Fledge phone notices\n")

      notices = DotPopper::Shell::NoticeFiles.new(game:, starts: [root]).notices

      assert_equal "Phone notices\n", notices.lota
      assert_equal ["Fledge phone notices\n"], notices.fledge
    end
  end
end
