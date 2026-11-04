# Lock screen art: under the stars

Two of them in the grass at night, one pointing up. Each letter you type lights the next
star of the constellation she's showing him. Drawn by `modules/lock/scenes/SkywardScene.qml`.

- `figures.svg`: the two of them and the grass, 4344×3258. Traced from a 1448×1086 flat
  illustration on a plain navy background:
  1. The background is cut by its exact colour (around `#06102f`), everywhere, so the gaps
     between her braids open onto the sky too. Only specks under 6 px stay.
  2. The cut-out is enlarged 3× (Lanczos, the mask smoothed before its threshold), so the
     thin rim light comes out as smooth curves, then brightened
     (`magick in.png -channel RGB -gamma 2.4 +channel`) so the dark hair keeps its strands.
  3. VectorCraft's Image Trace: colour, 22 colours, paths 80, corners 35, noise 9.
  4. `scripts/qt-svg.py traced.svg cut.png figures.svg 2.4` brings the colours back down
     and makes it draw right in Qt.
- `sky.svg`: the night, drawn by `scripts/skyward-sky.py`. Flat bands, the Milky Way as
  heaped star clouds with pockets of dust, a few thousand pinpricks. Nothing is blurred.

Her fingertip sits at 78.31 % across and 40.24 % down `figures.svg`; the constellation is
laid out from there in `SkywardScene.qml`. If the drawing changes, measure it again.

To check it without locking anything: pick it in Settings › Lock, then
`qs ipc -p . call lock preview` and type. Escape leaves the preview.
