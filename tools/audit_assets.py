#!/usr/bin/env python3
"""
Audit fetched glTFs for the material defects that render as garbage.

Two failure modes, both caused UPSTREAM by the asset cook (see
docs/architecture.md §Asset pipeline) and both invisible until something
looks wrong on screen:

  TEXTURELESS  materials with no images array at all -> renders flat white.
               patch_gltf_materials.py repairs these IF the mesh is
               atlas-mapped.

  TILING       UVs run outside [0,1], so the mesh wants a REPEATING texture,
               not an atlas cell. Wrapping an atlas across it samples the
               whole sheet — the "building wearing the entire texture page"
               bug. These cannot be auto-repaired; either the cook must ship
               the tiling texture, or don't use the mesh.

Run: python3 tools/audit_assets.py [--used-only]
Exit code is always 0 — this is a report, not a gate.
"""
import json
import os
import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).parent.parent
MESHES = ROOT / "assets" / "meshes"
MARGIN = 0.02


def uv_extremes(path: pathlib.Path, g: dict):
    """(min, max) over every UV component, or None when unreadable."""
    lo, hi = None, None
    for mesh in g.get("meshes", []):
        for prim in mesh.get("primitives", []):
            idx = prim.get("attributes", {}).get("TEXCOORD_0")
            if idx is None:
                continue
            try:
                acc = g["accessors"][idx]
                bv = g["bufferViews"][acc["bufferView"]]
                uri = g["buffers"][bv["buffer"]].get("uri", "")
                if not uri or uri.startswith("data:"):
                    return None
                with open(path.parent / uri, "rb") as fh:
                    raw = fh.read()
                off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
                uvs = struct.unpack_from("<%df" % (acc["count"] * 2), raw, off)
            except (KeyError, IndexError, OSError, struct.error):
                return None
            for v in uvs:
                lo = v if lo is None else min(lo, v)
                hi = v if hi is None else max(hi, v)
    return None if lo is None else (lo, hi)


def used_meshes() -> set:
    """Every res:// mesh literal the game actually references."""
    out = set()
    pattern = re.compile(r"res://assets/meshes/([^\"']+?\.(?:gltf|glb))")
    for base in ("scripts", "scenes", "resources"):
        for path in (ROOT / base).rglob("*"):
            if path.suffix not in (".gd", ".tscn", ".tres"):
                continue
            out.update(pattern.findall(path.read_text(errors="ignore")))
    return out


def main() -> int:
    only_used = "--used-only" in sys.argv
    wanted = used_meshes() if only_used else None
    textureless, tiling, ok = [], [], 0
    for path in sorted(MESHES.rglob("*.gltf")):
        rel = str(path.relative_to(MESHES))
        if wanted is not None and rel not in wanted:
            continue
        try:
            g = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        if not g.get("materials"):
            continue
        extremes = uv_extremes(path, g)
        if extremes and (extremes[0] < -MARGIN or extremes[1] > 1.0 + MARGIN):
            tiling.append((rel, extremes))
        elif not g.get("images"):
            textureless.append(rel)
        else:
            ok += 1

    scope = "referenced by the game" if only_used else "fetched"
    print("gltf audit (%s): %d fine, %d textureless, %d tiling"
          % (scope, ok, len(textureless), len(tiling)))
    if textureless:
        print("\nTEXTURELESS — renders flat white (run patch_gltf_materials.py):")
        for rel in textureless:
            print("   ", rel)
    if tiling:
        print("\nTILING — wants a repeating texture; an atlas would smear "
              "the whole sheet across it. Do not use these:")
        for rel, (lo, hi) in tiling:
            print("    %-64s uv %.2f..%.2f" % (rel, lo, hi))
    return 0


if __name__ == "__main__":
    sys.exit(main())
