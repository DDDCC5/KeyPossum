#!/usr/bin/env python3
"""Assemble a clean source archive and cross-built Windows zip, then checksums."""
from pathlib import Path
import hashlib
import shutil
import zipfile

root = Path(__file__).resolve().parent.parent
dist = root / "dist"
dist.mkdir(exist_ok=True)
version = "0.1.0-alpha.1"
windows = dist / "KeyPossum-Windows-x64"
if (windows / "KeyPossum.exe").is_file():
    shutil.copy2(root / "LICENSE", windows / "LICENSE")
    shutil.copytree(root / "third-party", windows / "third-party", dirs_exist_ok=True)
    with zipfile.ZipFile(dist / f"KeyPossum-{version}-windows-x64.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(windows.rglob("*")):
            if file.is_file():
                archive.write(file, Path(windows.name) / file.relative_to(windows))

excluded = {".git", ".cache", ".tools", ".superpowers", ".build", "dist", "bin", "obj", "__pycache__"}
source = dist / "KeyPossum-source.zip"
with zipfile.ZipFile(source, "w", zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(root.rglob("*")):
        relative = file.relative_to(root)
        if file.is_file() and not any(part in excluded for part in relative.parts) and file.name != ".DS_Store":
            archive.write(file, Path("KeyPossum") / relative)

lines = []
for file in sorted(dist.glob("*.zip")):
    with file.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest() if hasattr(hashlib, "file_digest") else hashlib.sha256(stream.read()).hexdigest()
    lines.append(f"{digest}  {file.name}")
    print(f"{file.name}: {file.stat().st_size:,} bytes")
(dist / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("Wrote SHA256SUMS.txt")
