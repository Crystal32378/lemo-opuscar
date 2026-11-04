# One Line / 一筆

- Creator: **Claude (Anthropic's Opus model) for Crystal**, 2026-11-04.
- Format: 15.000 seconds, 1920 × 1080, 24 fps; H.264 video and stereo AAC audio, −14 LUFS. No narration, no dialogue, no on-screen text.
- Story: a line running along the sea curls up into a pelican, rests on the tip of its beak, draws the pouch in gold, then goes back to the water and runs out of the picture: left for whoever draws the next one.
- Sound: solo clarinet and the pen on paper. While the pen rests on the beak (about 7.6–9.4 s) the music and its reverb stop completely; a faint paper room tone and the soft swell of the ink blot stay, at about −45 dB RMS. It is a near-silence, not digital silence.

## Original and interpretation

Crystal invited every visitor to draw a pelican, in any way they like. This is Claude's own take; it does not reuse or replace Murphy's film, or the Golden Pelican site's scenes. The gold of the pouch is a nod to Crystal's golden pelican.

- Style: Lemo-Opuscar's **One-line Drawing** guide (`styles/one-line/STYLE.md`), original toolkit by LemoLab / lemomo-ai, via [Crystal's fork](https://github.com/Crystal32378/lemo-opuscar).
- The line renderer (`geom.js`, `ink.js`, `paper.js`, `cam.js`, `hands.js`) is copied from that style's demo engine (MIT) and adapted: a gold accent for the pouch, a smaller ink blot, a camera that can let the line leave the frame. The demo's story, drawing, shots, score and voice are not used.
- New for this film: the drawing (`pelican.js`), the treatment, the camera, the solo-clarinet score and the mix.

Music: original score, solo clarinet, played with the toolkit's sampler from **VS Chamber Orchestra: Community Edition** (Versilian Studios), CC0 1.0. Sound effects (pen on paper, the ink blot, the pen setting down again, room tone) are synthesised in code. No third-party image, footage, font, logo, voice or generated media is embedded.

Tools: Node.js, headless Chromium (Playwright), Python (NumPy, SciPy, soundfile) and ffmpeg; not bundled.

## Files

- [Film (MP4)](one-line-pelican.mp4)
- [Source (ZIP)](one-line-pelican-source.zip): the drawing, renderer, score, mix, `build.sh`, the treatment, the original `CREDITS` and the toolkit's MIT `LICENSE`. Its README says how to rebuild inside a clone of the toolkit and which files the licence covers. The film was built from exactly this code; the second version of the ZIP only adds the licence, the per-file licence lines and corrected comments about the near-silence (checked: the mix renders to the same bytes).
- [Poster](poster.jpg): the last frame, the whole picture.

SHA-256:

```text
4d59abe40bf04aaed2db464c03bb6cdbc48b616d02c8796dcdce888693a11150  one-line-pelican.mp4
f0ea9dcc947713fd4f1a864475c7cf41e684bfe14ff01dc45d250beee883b900  one-line-pelican-source.zip
```

Code licence: `geom.js`, `ink.js`, `paper.js`, `cam.js` and `hands.js` are adapted from Lemo-Opuscar (Copyright (c) 2026 LemoLab, MIT); the full MIT text is in the ZIP as `LICENSE`, and each of those files names it in its first line. The code written for this film is offered under the same MIT terms. No new reuse permission is granted for the film itself beyond what Crystal decides for this gallery.
