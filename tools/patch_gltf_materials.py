#!/usr/bin/env python3
"""
Post-process cooked gltf files under assets/meshes/:
  1. alphaMode BLEND → MASK + alphaCutoff 0.5
     Foliage/plant gltfs export with BLEND, causing depth-sort artifacts in
     Godot's Forward+ renderer at isometric angles. MASK uses alpha-test
     instead (no sorting, binary transparency) which is correct for grass,
     bushes, flowers, and Synty billboard foliage in general.
  2. Out-of-bounds texture indices → clamped to the images array length.
     Some materials reference image index N when only N-1 images exist;
     Godot falls back to a default error material.
  3. Missing atlas reference → reattached.
     Some cooked packs (SciFi_City buildings et al) export materials with NO
     images/textures array at all, so every surface renders untextured white.
     Synty packs are single-atlas: the meshes already carry the right UVs, so
     pointing every material at the pack's one Textures/*.png restores them.
  4. Stray emissiveFactor without an emissiveTexture → removed.
     Synty "custom shader" materials (Samurai packs et al) translate to a
     Principled BSDF with full-white emission; the export then washes the
     whole prop out to pure white regardless of its base texture.

Run: python3 tools/patch_gltf_materials.py
Idempotent: skips files already patched. Deletes stale .gltf.import sidecars
for any file it modifies so Godot re-imports with correct materials.
"""
import json
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).parent.parent / "assets" / "meshes"
ALPHA_CUTOFF = 0.5


def _texture_has_alpha(gltf_path: pathlib.Path, g: dict, tex_index: int) -> bool:
    """True if the PNG behind texture[tex_index] carries an alpha channel
    (IHDR color type 4 or 6). Non-PNG or unresolvable → False."""
    try:
        img_index = g["textures"][tex_index]["source"]
        uri = g["images"][img_index].get("uri", "")
    except (KeyError, IndexError):
        return False
    if not uri or uri.startswith("data:") or not uri.lower().endswith(".png"):
        return False
    img_path = (gltf_path.parent / uri).resolve()
    try:
        with open(img_path, "rb") as fh:
            head = fh.read(26)
        return len(head) == 26 and head[25] in (4, 6)
    except OSError:
        return False


def _find_atlas(gltf_path: pathlib.Path):
    """The pack's single Synty atlas, searching upward for a Textures dir."""
    for parent in list(gltf_path.parents)[:5]:
        for name in ("Textures", "textures"):
            tex_dir = parent / name
            if not tex_dir.is_dir():
                continue
            pngs = sorted(tex_dir.glob("*.png"))
            if not pngs:
                continue
            # Prefer the "_A" albedo atlas when the pack ships several maps.
            albedo = [x for x in pngs if x.stem.endswith("_A")]
            return (albedo or pngs)[0]
    return None


def _attach_atlas(gltf_path: pathlib.Path, g: dict) -> bool:
    """Give texture-less materials the pack atlas. Meshes must have UVs —
    every Synty mesh does, which is why this works at all."""
    if not g.get("materials") or g.get("images"):
        return False
    if not any("TEXCOORD_0" in p.get("attributes", {})
               for m in g.get("meshes", []) for p in m.get("primitives", [])):
        return False
    atlas = _find_atlas(gltf_path)
    if atlas is None:
        return False
    uri = os.path.relpath(atlas, gltf_path.parent).replace(os.sep, "/")
    g["images"] = [{"mimeType": "image/png", "name": atlas.stem, "uri": uri}]
    if not g.get("samplers"):
        g["samplers"] = [{"magFilter": 9729, "minFilter": 9987,
                          "wrapS": 10497, "wrapT": 10497}]
    g["textures"] = [{"sampler": 0, "source": 0}]
    for mat in g["materials"]:
        pbr = mat.setdefault("pbrMetallicRoughness", {})
        pbr.setdefault("baseColorTexture", {"index": 0})
    return True


def patch_file(path: pathlib.Path) -> bool:
    with open(path) as f:
        g = json.load(f)

    images = g.get("images", [])
    max_idx = max(len(images) - 1, 0)
    changed = False
    changed |= _attach_atlas(path, g)

    for mat in g.get("materials", []):
        if mat.get("alphaMode") == "BLEND":
            mat["alphaMode"] = "MASK"
            mat.setdefault("alphaCutoff", ALPHA_CUTOFF)
            changed = True

        pbr = mat.get("pbrMetallicRoughness", {})
        bct = pbr.get("baseColorTexture")
        if bct is not None and bct.get("index", 0) > max_idx:
            bct["index"] = max_idx
            changed = True

        if "emissiveFactor" in mat and "emissiveTexture" not in mat:
            del mat["emissiveFactor"]
            changed = True

        # Foliage cards: a base texture WITH an alpha channel on an opaque
        # material renders as solid rectangles. Alpha-test it.
        if bct is not None and "alphaMode" not in mat:
            if _texture_has_alpha(path, g, bct.get("index", 0)):
                mat["alphaMode"] = "MASK"
                mat.setdefault("alphaCutoff", ALPHA_CUTOFF)
                changed = True

    if not changed:
        return False

    with open(path, "w") as f:
        json.dump(g, f, separators=(",", ":"))

    sidecar = path.with_suffix(path.suffix + ".import")
    if sidecar.exists():
        sidecar.unlink()

    return True


def main():
    if not ROOT.exists():
        print(f"assets/meshes/ not found at {ROOT} — run fetch_assets.sh first")
        sys.exit(1)

    patched = 0
    for gltf in ROOT.rglob("*.gltf"):
        if patch_file(gltf):
            print(f"patched  {gltf.relative_to(ROOT)}")
            patched += 1

    print(f"\n{patched} file(s) patched.")


if __name__ == "__main__":
    main()
