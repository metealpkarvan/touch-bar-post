#!/usr/bin/env python3
"""Create a standard UTF-8 ZIP, retaining Unix executable permissions."""
from pathlib import Path
import sys
import unicodedata
import zipfile

source = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
assert source.is_dir() and source not in target.parents
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(source.rglob("*")):
        if path.is_symlink():
            raise RuntimeError("Unexpected packaging symlink: " + str(path))
        if path.is_file():
            name = unicodedata.normalize("NFC", path.relative_to(source).as_posix())
            archive.write(path, name)
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    binary = archive.getinfo("Şerit.app/Contents/MacOS/TouchBarPost")
    assert (binary.external_attr >> 16) & 0o111
    assert binary.flag_bits & 0x800, "UTF-8 file name flag is missing"
print("UTF-8 archive and executable file mode verified.")
