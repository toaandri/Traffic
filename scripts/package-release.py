import hashlib
import json
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
release = root / "dist/Traffic"
archive = root / "dist/Traffic-1.0-Windows-x64.zip"
manifest = {"version": "1.0.0", "date": "2026-10-13", "platform": "Windows x64",
            "python": "3.14.2", "godot": "4.7.2", "sumo": "1.28.0",
            "sha256": {str(path.relative_to(release)): hashlib.file_digest(path.open("rb"), "sha256").hexdigest()
                       for path in (release / "Traffic.exe", release / "runtime/traffic.pck")}}
(release / "release-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
excluded = {"generated", "logs", "results", "projects", "profile"}
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
    for path in release.rglob("*"):
        if not path.is_file(): continue
        relative = path.relative_to(release)
        if len(relative.parts) > 1 and relative.parts[0] == "data" and relative.parts[1] in excluded: continue
        output.write(path, Path("Traffic") / relative)
with archive.open("rb") as file:
    checksum = hashlib.file_digest(file, "sha256").hexdigest()
archive.with_suffix(".sha256").write_text(checksum + "  " + archive.name + "\n", encoding="ascii")
print(f"Archive : {archive} ({archive.stat().st_size / 1024 ** 2:.1f} Mio)")
