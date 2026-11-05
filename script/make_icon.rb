#!/usr/bin/env ruby
# frozen_string_literal: true

# Draws Dot Popper's icon from code and writes the files fledge.yml's
# `icon: icons/icon` names: icons/icon-SIZE.png (16 to 1024), icons/icon.ico
# (16 to 256, PNG entries), and on macOS icons/icon.icns (with iconutil).
# The icon is CC0-1.0 (LICENSES/ICONS.md). Run it from the
# repository's root: ruby script/make_icon.rb
#
# Design: a deep ink rounded square (#141127), a bold coral dot (#FF6B5E)
# with an ink gap and a mint ring (#5EE6C0), and a small mint dot popping
# off to the upper right. Each pixel's coverage comes from its distance
# to each shape's edge, so every size is drawn sharp, not scaled down.

require "zlib"
require "fileutils"
require "tmpdir"

INK = [0x14, 0x11, 0x27].freeze
CORAL = [0xFF, 0x6B, 0x5E].freeze
MINT = [0x5E, 0xE6, 0xC0].freeze

# Signed distances, in units of the icon's side (0..1); negative inside.
def rounded_square(x, y, inset, radius)
  qx = (x - 0.5).abs - (0.5 - inset - radius)
  qy = (y - 0.5).abs - (0.5 - inset - radius)
  outside = Math.hypot([qx, 0].max, [qy, 0].max)
  outside + [[qx, qy].max, 0].min - radius
end

def circle(x, y, cx, cy, r) = Math.hypot(x - cx, y - cy) - r

def ring(x, y, cx, cy, r, width) = (Math.hypot(x - cx, y - cy) - r).abs - width / 2.0

# Layers, bottom to top: [colour, distance function].
LAYERS = [
  [INK, ->(x, y) { rounded_square(x, y, 0.04, 0.2) }],
  [MINT, ->(x, y) { ring(x, y, 0.43, 0.57, 0.305, 0.05) }],
  [CORAL, ->(x, y) { circle(x, y, 0.43, 0.57, 0.24) }],
  [MINT, ->(x, y) { circle(x, y, 0.76, 0.25, 0.1) }],
].freeze

def render(size)
  rows = Array.new(size) do |j|
    row = +"\0".b
    size.times do |i|
      x = (i + 0.5) / size
      y = (j + 0.5) / size
      r = g = b = a = 0.0
      LAYERS.each do |colour, distance|
        coverage = (0.5 - distance.call(x, y) * size).clamp(0.0, 1.0)
        next if coverage.zero?

        # "Over" compositing, premultiplied.
        r = colour[0] * coverage + r * (1 - coverage)
        g = colour[1] * coverage + g * (1 - coverage)
        b = colour[2] * coverage + b * (1 - coverage)
        a = coverage + a * (1 - coverage)
      end
      pixel = a.zero? ? [0, 0, 0, 0] : [r / a, g / a, b / a, a * 255].map { |c| c.round.clamp(0, 255) }
      row << pixel.pack("C4")
    end
    row
  end
  png(size, rows.join)
end

def chunk(type, data) = [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")

def png(size, raw)
  "\x89PNG\r\n\x1A\n".b +
    chunk("IHDR", [size, size, 8, 6, 0, 0, 0].pack("NNC5")) +
    chunk("IDAT", Zlib::Deflate.deflate(raw, Zlib::BEST_COMPRESSION)) +
    chunk("IEND", "")
end

# An ICO whose entries are PNGs, which Windows Vista and later read.
def ico(pngs)
  header = [0, 1, pngs.size].pack("v3")
  offset = 6 + 16 * pngs.size
  entries = +"".b
  pngs.each do |size, data|
    entries << [size % 256, size % 256, 0, 0, 1, 32, data.bytesize, offset].pack("C4v2V2")
    offset += data.bytesize
  end
  header + entries + pngs.map(&:last).join
end

FileUtils.mkdir_p("icons")
pngs = [16, 24, 32, 48, 64, 72, 96, 128, 144, 192, 256, 512, 1024].to_h { |size| [size, render(size)] }
pngs.each { |size, data| File.binwrite("icons/icon-#{size}.png", data) }
File.binwrite("icons/icon.ico", ico(pngs.slice(16, 24, 32, 48, 64, 128, 256)))

if system("which iconutil > /dev/null 2>&1")
  Dir.mktmpdir do |dir|
    set = File.join(dir, "icon.iconset")
    FileUtils.mkdir_p(set)
    { 16 => [16, 32], 32 => [32, 64], 128 => [128, 256], 256 => [256, 512], 512 => [512, 1024] }.each do |point, (one, two)|
      File.binwrite(File.join(set, "icon_#{point}x#{point}.png"), pngs.fetch(one))
      File.binwrite(File.join(set, "icon_#{point}x#{point}@2x.png"), pngs.fetch(two))
    end
    system("iconutil", "-c", "icns", set, "-o", "icons/icon.icns", exception: true)
  end
else
  warn "iconutil not found (it comes with macOS); icons/icon.icns not rewritten"
end
puts Dir["icons/*"].sort
