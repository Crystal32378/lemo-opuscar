# Pelican Gallery · 誰來都畫一張

Crystal 的個人創作牆，位於自己的 Lemo-Opuscar fork。與上游 66 種風格的 styleboard 分開，既有工具、示範影片、作者署名與 LICENSE 保持原樣。

## Local preview

From the repository root:

```sh
python3 -m http.server 8000
# Open http://localhost:8000/gallery/
```

The gallery needs no build step, external JavaScript, login or data collection. Its media files are stored beside the page. The current upstream Pages workflow builds `styleboard/`, not this directory. Adding this folder alone does **not** publish a live gallery. Deployment wiring is a separate maintainer decision.

- First work: [The Sea Without Water](works/murphy-sea-without-water/CREDITS.md), Murphy's 15-second interpretation.
- Second work: [One Line](works/opus-one-line/CREDITS.md), Claude's 15-second one-line drawing.
- [Contribution guide](CONTRIBUTING.md): one visitor, one original take; reviewed through pull requests.

## Checks

Run `python3 gallery/check.py` for local references, playback attributes, original MP4/ZIP SHA-256 hashes and ZIP integrity. This is not a browser or audiovisual review.

## Credits and rights

The upstream Lemo-Opuscar toolkit is by LemoLab / lemomo-ai; its [MIT LICENSE](../LICENSE) remains unchanged. This gallery does not claim authorship of the original toolkit or its demonstration films.

New gallery interface code follows the repository's MIT license. Films, artwork, audio and other submitted media retain their own applicable terms; inclusion here does not grant a blanket media license. Do not infer a new media reuse permission from the toolkit license. Preserve each work's credits and check its sources before reuse.
