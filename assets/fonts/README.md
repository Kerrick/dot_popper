# Fonts

`Fredoka-Bold.ttf` and `Fredoka-SemiBold.ttf` are two weights of Fredoka, a typeface by Milena Brandão and Hafontia. They are copyright 2016 The Fredoka Project Authors and licensed under the SIL Open Font License 1.1, whose text is in `OFL.txt` beside them.

The files are the static TTFs from https://github.com/hafontia-zz/Fredoka-One at commit 35c584ff23450c9bcdf8819706e12fcdeefe1712, which is the upstream commit that Google Fonts' `ofl/fredoka` folder cites as its source. Google Fonts itself now ships Fredoka only as a variable font, a single file that covers every weight. Dot Popper uses fixed-weight files instead, so that its text is drawn at exactly the same weight at every size.

`Iosevka-Bold-setdef.ttf` and `Iosevka-Regular-latin.ttf` are Iosevka, a typeface by Renzhi Li (aka. Belleve Invis), copyright 2015-2026, licensed under the SIL Open Font License 1.1, whose text is in `Iosevka-LICENSE.md` beside them. Both are cut from the official Iosevka v34.9.1 release with `pyftsubset`, which only drops glyphs, so the letters are the release's own. The Bold one keeps only the letters s, e, t, d and f, for the setdef splash (the maker's logotype). The Regular one keeps Latin-1 and common punctuation, and sets the license texts on the Credits screen in monospace.
