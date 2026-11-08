# frozen_string_literal: true

module DotPopper
  module Shell
    # Finds and reads the license texts the running build carries, for the
    # Credits screen, and gives them as Presentation::Notices. What a
    # build lacks it leaves out, without error, and so a file it cannot read.
    #
    # +game+ is the game's own folder (the folder main.rb is in), which holds
    # assets/fonts/OFL.txt and Iosevka-LICENSE.md, and
    # assets/emoji/LICENSE.txt, fused or run from the repository.
    # The rest is looked for in the game's folder and the folders above it,
    # and above each of +starts+ (the folder of the running program), at
    # most +reach+ up, nearest first, since where an app puts it depends on
    # the platform:
    #
    # [NOTICES.txt] Lota's, which <tt>lota fuse</tt> writes from Lota 0.2.1
    #   on and Fledge puts at the top of the app's +app+ folder, above the
    #   game's: in a macOS app's Contents/Resources/app, in a Windows
    #   app's folder as app, and in an AppImage's mounted AppDir as app.
    # [notices/] Fledge's, in a fused app on a computer beside +app+
    #   (Contents/Resources/notices, notices next to app in a Windows
    #   folder and in the AppDir), and in an Android or iOS app in the root
    #   with the game's own files. Its top level's +.txt+ files are read,
    #   NOTICES.txt first; its +sources+ folder is the source of the LGPL
    #   libraries, for whoever asks for it.
    class NoticeFiles
      LOTA = "NOTICES.txt"
      FLEDGE = "notices"
      REACH = 4

      def initialize(game:, starts: [], reach: REACH)
        @game = game
        @roots = [game, *starts].compact.flat_map { climb(it, reach) }.uniq
      end

      def notices
        Presentation::Notices.new(ofl: read(@game, "assets", "fonts", "OFL.txt"),
                                  iosevka: read(@game, "assets", "fonts", "Iosevka-LICENSE.md"),
                                  emoji: read(@game, "assets", "emoji", "LICENSE.txt"),
                                  lota: lota, fledge: fledge)
      end

      private

      # +folder+ and the folders above it, +reach+ of them.
      def climb(folder, reach)
        path = File.expand_path(folder)
        [path, *Array.new(reach) { path = File.dirname(path) }]
      end

      def lota
        root = @roots.find { File.file?(File.join(it, LOTA)) }
        read(root, LOTA) if root
      end

      def fledge
        root = @roots.find { File.directory?(File.join(it, FLEDGE)) } or return []
        names = Dir.children(File.join(root, FLEDGE)).select { it.end_with?(".txt") }
        names.sort_by { [it == LOTA ? 0 : 1, it] }.filter_map { read(root, FLEDGE, it) }
      rescue SystemCallError
        []
      end

      def read(*path)
        text = File.read(File.join(*path), encoding: "UTF-8")
        text.valid_encoding? ? text : text.scrub
      rescue SystemCallError
        nil
      end
    end
  end
end
