#!/usr/bin/env python3
"""Remove the redundant pkg mount from a converted Rojo project.

rojo-build-noalias relocates pkg/ to src/pkg and rewrites the tree entry to
match, but the root "$path": "src" already mounts that directory as pkg. Rojo
then builds two instances named pkg, which is what ships in the release rbxm
and the Wally artifact.

Fails loudly rather than silently doing nothing if the converted project stops
looking the way this expects, since a silent no-op would reintroduce the bug.

Usage:  python3 .github/scripts/dedupe-pkg-mount.py <project.json>
"""

import json
import sys
from pathlib import Path

EXPECTED = "src/pkg"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    path = Path(sys.argv[1])
    project = json.loads(path.read_text(encoding="utf8"))

    tree = project.get("tree", {})
    root = tree.get("$path")
    pkg = tree.get("pkg", {}).get("$path")

    if root != "src" or pkg != EXPECTED:
        sys.exit(
            f"{path} is not the shape this patch expects "
            f'(root "$path"={root!r}, pkg "$path"={pkg!r}); '
            "recheck rojo-build-noalias before releasing"
        )

    del tree["pkg"]
    path.write_text(json.dumps(project, indent=2) + "\n", encoding="utf8")
    print(f"dropped the redundant pkg mount from {path}")


if __name__ == "__main__":
    main()
