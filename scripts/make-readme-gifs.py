"""Convert real Godot captures into small GitHub-ready animations.

Requires Pillow only for documentation media, not for running Traffic.
Run frontend/godot/tests/readme_capture.gd against the local backend first.
"""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".tools/readme-frames"
DESTINATION = ROOT / "docs/media"


def main():
    manifest = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for sequence, count in manifest["frames"].items():
        frames = []
        for index in range(count):
            with Image.open(SOURCE / sequence / f"{index:04d}.png") as source:
                frame = source.convert("RGB").resize((960, 600), Image.Resampling.LANCZOS)
            frames.append(frame)
        # A shared palette keeps static chrome stable and allows delta compression.
        montage = Image.new("RGB", (960, 600 * 4))
        for row, index in enumerate((0, count // 3, count * 2 // 3, count - 1)):
            montage.paste(frames[index], (0, row * 600))
        palette = montage.quantize(colors=128, method=Image.Quantize.MEDIANCUT)
        indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
        target = DESTINATION / f"traffic-{sequence}.gif"
        indexed[0].save(
            target,
            save_all=True,
            append_images=indexed[1:],
            duration=round(1000 / manifest["fps"] / 10) * 10,
            loop=0,
            optimize=True,
            disposal=1,
        )
        with Image.open(target) as check:
            durations = []
            for index in range(check.n_frames):
                check.seek(index)
                durations.append(check.info["duration"])
            assert sum(durations) > 0 and check.size == (960, 600)
            print(
                f"{target.name}: {check.n_frames} frames, {sum(durations) / 1000:.1f}s, "
                f"{target.stat().st_size / 1024**2:.2f} MiB"
            )


if __name__ == "__main__":
    main()
