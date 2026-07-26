#!/usr/bin/env bash
# builds the place the engine lane runs in, at .build/test.rbxl
#
# two steps rather than one because rojo does not resolve luaurc aliases:
# rojo-build-noalias rewrites every @mod/@pkg require into a relative one and
# copies the tree, and only then can rojo build it. the converted tree is also
# reshaped (child $path directories move under the root $path), which is why the
# place project lives here and is copied in rather than sitting next to
# test.project.json.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="$root/.build"
tree="$build/engine"

rm -rf "$tree"
mkdir -p "$build"

rojo-build-noalias --convert-to "$tree" "$root/test.project.json"

cp "$root/scripts/place.project.json" "$tree/place.project.json"
rojo build "$tree/place.project.json" -o "$build/test.rbxl"

echo "built $build/test.rbxl"
