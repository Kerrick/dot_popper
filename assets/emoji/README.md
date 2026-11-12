# Emoji

`emoji_u1f446.svg` is Noto Emoji's 👆, U+1F446 BACKHAND INDEX POINTING UP, in its default (yellow) skin tone. The tutorial's guide draws it for touch, as the hand that taps. Noto Emoji is Google's emoji, copyright 2013 Google, Inc. Its images are licensed under the Apache License, version 2.0 (its fonts are under the SIL Open Font License, but no font is used here). `LICENSE.txt` beside them holds Noto's notice, as `2D/svg/LICENSE` in its repository words it, followed by the license's full text, which is also in `LICENSES/Apache-2.0.txt`.

The SVG is unchanged from https://github.com/googlefonts/noto-emoji/blob/99701e07d3d1fe1bdbcdb14964547f0fd592966f/2D/svg/emoji_u1f446.svg, at commit 99701e07d3d1fe1bdbcdb14964547f0fd592966f of https://github.com/googlefonts/noto-emoji.

The `hand-SIZE.png` files are modified from it: `script/make_hand.rb` (`ruby script/make_hand.rb`, with `rsvg-convert` and `magick`) renders it at each size, a square cut close around the hand, and gives each clear pixel the color of the hand's nearest pixel, so the edge never darkens as the game draws it smaller. The drawing itself is Noto's, unchanged.
