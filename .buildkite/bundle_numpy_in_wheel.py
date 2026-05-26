#!/usr/bin/env python3
"""
Repack a GDAL wheel to include numpy's package files.

Adds the numpy package directory into the wheel so that `import numpy`
works without a separate install. Does NOT add numpy's dist-info to
avoid confusing pip (it's a vendored copy, not an installed package).
"""
import base64
import glob
import hashlib
import os
import shutil
import sys
import zipfile
from pathlib import Path


def file_digest(path: Path) -> tuple[str, int]:
    h = hashlib.sha256()
    size = 0
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
            size += len(chunk)
    digest = base64.urlsafe_b64encode(h.digest()).rstrip(b"=").decode("ascii")
    return f"sha256={digest}", size


def main():
    wheel_dir = sys.argv[1]
    numpy_dir = sys.argv[
        2
    ]  # path to numpy package dir (e.g. /opt/python/lib/.../numpy)

    whl_files = glob.glob(os.path.join(wheel_dir, "gdal-*.whl"))
    if len(whl_files) != 1:
        sys.exit(f"Expected exactly one gdal wheel in {wheel_dir}, found: {whl_files}")

    whl_path = whl_files[0]
    work_dir = Path(wheel_dir) / "_repack"
    if work_dir.exists():
        shutil.rmtree(work_dir)
    work_dir.mkdir()

    # Unzip
    with zipfile.ZipFile(whl_path, "r") as zf:
        zf.extractall(work_dir)

    # Copy numpy package into the wheel
    dest_numpy = work_dir / "numpy"
    shutil.copytree(numpy_dir, dest_numpy)

    # Copy numpy.libs/ (vendored OpenBLAS etc.) if present
    numpy_libs = Path(numpy_dir).parent / "numpy.libs"
    if numpy_libs.is_dir():
        shutil.copytree(numpy_libs, work_dir / "numpy.libs")

    # Find the dist-info dir and its RECORD
    dist_info = list(work_dir.glob("gdal-*.dist-info"))
    if len(dist_info) != 1:
        sys.exit(f"Expected one dist-info, found {dist_info}")
    record_path = dist_info[0] / "RECORD"

    # Read existing RECORD entries
    existing = record_path.read_text()

    # Add entries for all numpy files
    new_entries = []
    for root, dirs, files in os.walk(dest_numpy):
        for fname in files:
            fpath = Path(root) / fname
            rel = fpath.relative_to(work_dir)
            digest, size = file_digest(fpath)
            new_entries.append(f"{rel},{digest},{size}")

    # Rewrite RECORD
    # Strip trailing newlines, add numpy entries, then the RECORD self-reference
    lines = existing.rstrip("\n")
    # Remove old RECORD self-reference line if present
    record_rel = str(record_path.relative_to(work_dir))
    filtered = "\n".join(l for l in lines.split("\n") if not l.startswith(record_rel))
    filtered += "\n" + "\n".join(new_entries)
    filtered += f"\n{record_rel},,\n"
    record_path.write_text(filtered)

    # Re-zip
    os.remove(whl_path)
    with zipfile.ZipFile(whl_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(work_dir):
            for fname in sorted(files):
                fpath = Path(root) / fname
                arcname = fpath.relative_to(work_dir)
                zf.write(fpath, arcname)

    shutil.rmtree(work_dir)
    print(f"Repacked {whl_path} with numpy bundled")


if __name__ == "__main__":
    main()
