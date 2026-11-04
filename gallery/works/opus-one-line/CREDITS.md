# One Line / 一筆

- Creator: **Claude (Anthropic's Opus model) for Crystal**, 2026-11-04.
- Format: 15.000 seconds, 1920 × 1080, 24 fps; H.264 video and stereo AAC audio, −14 LUFS. No narration, no dialogue, no on-screen text.
- Story: a line running along the sea curls up into a pelican, rests on the tip of its beak, draws the pouch in gold, then goes back to the water and runs out of the picture: left for whoever draws the next one.

## Original and interpretation

Crystal invited every visitor to draw a pelican, in any way they like. This is Claude's own take; it does not reuse or replace Murphy's film, or the Golden Pelican site's scenes. The gold of the pouch is a nod to Crystal's golden pelican.

- Style: Lemo-Opuscar's **One-line Drawing** guide (`styles/one-line/STYLE.md`), original toolkit by LemoLab / lemomo-ai, via [Crystal's fork](https://github.com/Crystal32378/lemo-opuscar).
- The line renderer (`geom.js`, `ink.js`, `paper.js`, `cam.js`, `hands.js`) is copied from that style's demo engine (MIT) and adapted: a gold accent for the pouch, a smaller ink blot, a camera that can let the line leave the frame. The demo's story, drawing, shots, score and voice are not used.
- New for this film: the drawing (`pelican.js`), the treatment, the camera, the solo-clarinet score and the mix.

Music: original score, solo clarinet, played with the toolkit's sampler from **VS Chamber Orchestra: Community Edition** (Versilian Studios), CC0 1.0. Sound effects (pen on paper, the ink blot, the pen setting down again, room tone) are synthesised in code. No third-party image, footage, font, logo, voice or generated media is embedded.

Tools: Node.js, headless Chromium (Playwright), Python (NumPy, SciPy, soundfile) and ffmpeg; not bundled.

## Files

- [Film (MP4)](one-line-pelican.mp4)
- [Source (ZIP)](one-line-pelican-source.zip): the drawing, renderer, score, mix, `build.sh`, the treatment and the original `CREDITS`. Its README says how to rebuild inside a clone of the toolkit.
- [Poster](poster.jpg): the last frame, the whole picture.

SHA-256:

```text
4d59abe40bf04aaed2db464c03bb6cdbc48b616d02c8796dcdce888693a11150  one-line-pelican.mp4
68a5ad1150dda22ab3b51b68ce69b519030fbd557127965a9318fdb7e6810162  one-line-pelican-source.zip
```

The code in the source ZIP follows the repository's MIT licence. No new reuse permission is granted for the film itself beyond what Crystal decides for this gallery.
