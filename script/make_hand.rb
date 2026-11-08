#!/usr/bin/env ruby
# frozen_string_literal: true

# Renders the tutorial's pointing hand, Noto Emoji's U+1F446 (backhand
# index pointing up, assets/emoji/emoji_u1f446.svg, Apache-2.0;
# assets/emoji/README.md), to the PNGs the game draws:
# assets/emoji/hand-SIZE.png, each SIZE pixels square, for every size in
# Presentation::PointingHand::SIZES. Run it from the repository's root:
# ruby script/make_hand.rb. It needs rsvg-convert (librsvg) and magick
# (ImageMagick).
#
# Each PNG shows VIEW of the SVG's 128-unit square, the hand with a thin
# clear margin, so the game knows its fingertip and wrist from where they
# are in it. Its clear pixels take the colour of the nearest pixel of the
# hand (Bleed), so when the game draws it smaller, with linear filtering
# and mipmaps, the edge blends into the hand's own colour and never into
# black: no dark fringe.

require "open3"
require "tmpdir"
require_relative "../lib/dot_popper/presentation/pointing_hand"

SOURCE = "assets/emoji/emoji_u1f446.svg"
VIEW = DotPopper::Presentation::PointingHand::VIEW

# Gives every clear pixel of an RGBA image the colour of its nearest
# pixel with any opacity, found breadth first, leaving its opacity 0.
module Bleed
  module_function

  def call(rgba, size)
    pixels = rgba.unpack("C*")
    seen = Array.new(size * size) { pixels[(it * 4) + 3].positive? }
    queue = seen.each_index.select { seen[it] }
    until queue.empty?
      queue = queue.flat_map { spread(it, pixels, seen, size) }
    end
    pixels.pack("C*")
  end

  def spread(index, pixels, seen, size)
    x = index % size
    y = index / size
    [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]].filter_map do |nx, ny|
      next unless nx.between?(0, size - 1) && ny.between?(0, size - 1)

      near = (ny * size) + nx
      next if seen[near]

      seen[near] = true
      pixels[near * 4, 3] = pixels[index * 4, 3]
      near
    end
  end
end

def run(*command, stdin_data: nil)
  out, status = Open3.capture2(*command, stdin_data:, binmode: true)
  abort "#{command.first} failed" unless status.success?
  out
end

Dir.mktmpdir do |dir|
  cropped = File.join(dir, "hand.svg")
  File.write(cropped, File.read(SOURCE).sub(/viewBox="[^"]*"/, %(viewBox="#{VIEW.join(" ")}")))
  DotPopper::Presentation::PointingHand::SIZES.each do |size|
    drawn = File.join(dir, "hand-#{size}.png")
    run("rsvg-convert", "-w", size.to_s, "-h", size.to_s, cropped, "-o", drawn)
    rgba = run("magick", drawn, "-depth", "8", "rgba:-")
    out = "assets/emoji/hand-#{size}.png"
    run("magick", "-size", "#{size}x#{size}", "-depth", "8", "rgba:-", "-define", "png:color-type=6",
        "-strip", "PNG32:#{out}", stdin_data: Bleed.call(rgba, size))
    puts out
  end
end
