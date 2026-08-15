# Handover: fix the asset cook on the Synty asset server

**For:** an agent with access to the asset server host and its cook/conversion tooling.
**From:** the Gutshot game repo, which is a *consumer* of this server. We can see the
damage precisely but cannot fix it — the cook tooling is not in our repo.

**Server:** `http://srv.blastedstudios.com:49200/`, plain static file host.
`index.json` lists two trees, `raw` (artist source: FBX + Textures) and `cooked`
(glTF the converter produced). Games fetch the cooked tree. Note the URL prefixes
do not match the index key names: raw files are served under `raw/…`, but cooked
files are served under **`assets/…`**, not `cooked/…`. Pack subdirectory naming is
also inconsistent (`SourceFiles` vs `Source_Files`) — take exact paths from
`index.json` rather than constructing them.

**One-line problem statement:** the FBX→glTF cook resolves texture references
literally from each FBX's `RelativeFilename` field, but those paths point outside the
pack into the original artist's Unity project layout, so for affected packs the
converter finds nothing, silently drops the material→texture binding, and never
copies the texture into the cooked tree. Those meshes render flat white in engine.

---

## 1. Verified evidence

Everything in this section I confirmed directly against the live server. Commands are
copy-pasteable.

### 1a. Cooked glTFs arrive with no textures at all

```bash
B=http://srv.blastedstudios.com:49200
for f in \
  "assets/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Large_01.gltf" \
  "assets/POLYGON_SciFi_City_SourceFiles_v5/Source_Files/FBX/SM_Bld_Background_Med_02.gltf" \
  "assets/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_01.gltf" \
  "assets/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Bld_Door_Roller_Large_01.gltf" ; do
  printf '%-46s ' "$(basename $f)"
  curl -fsS "$B/$f" | python3 -c 'import json,sys
g=json.load(sys.stdin)
print("images=%-3d materials=%s" % (len(g.get("images") or []),
      [m.get("name") for m in g.get("materials",[])][:2]))'
done
```

Actual output — all four ship zero images:

```
SM_Bld_Large_01.gltf                           images=0   materials=['lambert874']
SM_Bld_Background_Med_02.gltf                  images=0   materials=['lambert2']
SM_Prop_Shipping_Container_01.gltf             images=0   materials=['lambert2167']
SM_Bld_Door_Roller_Large_01.gltf               images=0   materials=['Polygon_Generic_01_A']
```

This is what the server serves — nothing downstream of the server causes it.

**Compare a correctly cooked pack** (CyberCity), which shows the target output shape:

```bash
curl -fsS "$B/assets/POLYGON_CyberCity_SourceFiles_v3/SourceFiles/FBX/Buildings/SM_Bld_Background_Building_04.gltf" \
  | python3 -c 'import json,sys; g=json.load(sys.stdin);
print([i.get("uri") for i in g.get("images",[])])'
# -> ['../../Textures/PolygonCyberCity_Texture_01_A.png']
```

A relative URI into the pack's own `Textures/` directory. That is what a fixed cook
should emit for the broken packs.

Note the fourth material above is named **`Polygon_Generic_01_A`** — the material
name itself names the texture (`Generic_01_A.png`). Where `RelativeFilename` fails,
the material name is often a usable second resolution route; see §2.1.

Confirmed-broken meshes (the ones our game hit):

| pack | mesh | symptom |
|---|---|---|
| Military_Warehouse | `SM_Prop_Shipping_Container_01` | flat white |
| Military_Warehouse | `SM_Bld_Door_Roller_Large_01` | flat white |
| SciFi_City | `SM_Bld_Large_01` | flat white |
| SciFi_City | `SM_Bld_Background_Med_01/02/04/07` | no texture **and** UVs tile v −0.53..2.25 |
| SciFi_City | `SM_Bld_Background_Small_02/03/04` | same |

### 1b. Root cause: FBX texture paths point outside the pack

No FBX in the affected packs embeds its media — zero `Content` blobs — so every
texture is an external reference, and those references are stale absolute/relative
Windows paths from the artist's own project:

```bash
curl -fsS "$B/raw/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/FBX/SM_Prop_Shipping_Container_01.fbx" \
  -o /tmp/c.fbx
python3 -c 'import re;b=open("/tmp/c.fbx","rb").read()
print("embedded Content blobs:",b.count(b"Content"))
for m in sorted(set(re.findall(rb"[A-Za-z0-9_\\/.\-]+\.(?:png|tga)",b,re.I))):
    print("  ",m.decode("utf8","replace"))'
```

Output:

```
embedded Content blobs: 0
..\..\Synty\PolygonMilitary\Textures\Vehicles\Land_Vehicles_03.png
\PLASTIC\MapPack_MilitaryOutpost\MapPack_MilitaryOutpost\Assets\Synty\PolygonMilitary\Textures\Vehicles\Land_Vehicles_03.png
```

and for the roller door, `..\..\..\..\..\..\Synty\Generic_01_A.png`.

Two things follow. First, six-deep `..\` traversals and a `\PLASTIC\...` absolute
path will never resolve relative to the pack root — that is the whole bug. Second,
the container's texture lives in **`PolygonMilitary`, a different pack than the one
shipping the mesh**, so any fix has to search across packs, not just within one.

### 1c. The referenced textures mostly DO exist — resolve them by basename

Searching `index.json` for each referenced basename:

| referenced basename | copies in `raw` | resolvable? |
|---|---|---|
| `Generic_01_A.png` | 13 (Dark_Fortress, Pro_Racer, Samurai_Empire, …) | yes, but ambiguous |
| `PolygonScifi_Background_Building_Emissive.png` | 1 (SciFi_City itself) | yes, unambiguous |
| `Corrigated_Iron_01_Blue.png` | 1 (Military_Warehouse itself) | yes, unambiguous |
| `Land_Vehicles_03.png` | **0** | **no — genuinely absent** |

So most breakage is fixable by resolving on basename instead of path. A residue is
not: `Land_Vehicles_03.png` belongs to a `PolygonMilitary` pack that is not mirrored
on this server, and no amount of cook cleverness conjures it. That case needs the
pack acquired or the mesh marked unusable — see §4.

### 1d. Second, independent defect: present textures still aren't bound

SciFi_City's cooked tree *does* ship `PolygonScifi_01_A.png`, yet its `SM_Bld_*`
meshes still have `images: None`. So binding loss is not purely a
missing-file problem — even when the file is cooked, the material is not wired to it.
Fixing file-copying alone will not fix these meshes.

Also missing from SciFi_City's cooked tree:
`PolygonScifi_Background_Building_Emissive.png`, a 512² grid of lit-window patterns
meant to tile vertically. The `Background_*` meshes' UVs running v −0.53..2.25 are
designed around exactly that texture. Until it is cooked and bound, those meshes
cannot be made to look right — an atlas wrapped across those UVs smears the whole
sheet across the facade, which is how we first noticed the problem.

### 1e. Scope: this is pack-specific, not server-wide

Sampling one mid-list glTF from each of 17 mesh packs, **16 had a valid `images`
array**; only `SIMPLE_Buildings_SourceFiles` did not. The cook works correctly for
the common case — a single-atlas Synty pack — and fails on packs whose FBX
references textures by external or cross-pack paths. Do not rewrite the cook
wholesale; fix the resolution path and re-cook affected packs.

### 1f. Ruled out — do not chase these

- **Sampler wrap modes are fine.** Cooked glTFs either declare
  `wrapS/wrapT = 10497 (REPEAT)` or declare no sampler, and the glTF default is
  REPEAT. Tiling meshes will tile correctly once they have the right texture.
- **Not a download or client-side problem.** Verified by fetching from the server
  with plain `curl` (§1a).

---

## 2. What to change

In the FBX→glTF cook:

1. **Resolve textures by basename, not by `RelativeFilename` path.** For each
   `FbxFileTexture`, take `basename(RelativeFilename)` and resolve in this order:
   1. within the same pack's `Textures/` tree (recursive) — accept;
   2. corpus-wide across all `raw` packs — if exactly one match, accept;
   3. multiple matches (e.g. `Generic_01_A.png`, 13 copies) — disambiguate by content
      hash if the copies are identical; otherwise pick deterministically (stable sort
      by pack name) and **log the ambiguity**;
   4. no match — fall back to the **material name**, which in these packs frequently
      names the texture directly (`Polygon_Generic_01_A` → `Generic_01_A.png`, §1a);
      retry steps 1–3 with that basename;
   5. still no match — record as UNRESOLVED, do not silently emit an unbound material.
2. **Copy every resolved texture into the cooked pack**, not just the first or the
   pack's headline atlas. Multi-material meshes need several.
3. **Preserve per-material bindings.** §1d shows a cooked texture with no material
   pointing at it, so the binding step needs its own fix, independent of file copying.
4. **Fail loudly.** The cook currently produces a plausible-looking glTF with
   `images: None` and no error — which is why this sat undetected until it showed up
   on screen. Emit a per-pack report of unresolved textures and unbound materials.
5. **Add a cook-time assertion:** a glTF that declares `materials` but no `images` is
   a defect. That single check would have caught every case in this document.

## 3. How to verify a fix

1. Re-run §1a — all four meshes should report a non-empty `images` array and
   materials whose `pbrMetallicRoughness.baseColorTexture` is populated, with image
   URIs pointing into the pack's own `Textures/` directory (the CyberCity shape).
2. Re-cook and re-check the seven `SM_Bld_Background_*` meshes; they should bind
   `PolygonScifi_Background_Building_Emissive.png`.
3. Consumer-side check, from this repo: `./fetch_assets.sh` then
   `python3 tools/audit_assets.py --used-only`. It reports TEXTURELESS and TILING
   meshes over everything the game references. Current baseline is
   **106 fine, 2 textureless, 5 tiling**; a successful fix drives textureless to 0
   and should clear the SciFi_City tiling entries once the emissive texture binds.
4. Sweep for regressions: assert no cooked glTF has `materials` without `images`.

## 4. Known limits and open questions

- **`Land_Vehicles_03.png` does not exist anywhere on this server** (§1c). The
  Military_Warehouse shipping container cannot be fixed by re-cooking alone. Either
  mirror the `PolygonMilitary` pack into `raw`, or accept that this mesh is
  unusable — but make the cook *report* it rather than emit a white mesh.
- **Unverified lead, needs your judgment:** comparing atlas-like filenames between
  trees suggests ~89 packs ship fewer atlases than raw contains (e.g. CyberCity 4 of
  51). I did not validate this — my filename pattern likely counts colour variants
  and normal maps as atlases, so the number is probably inflated. Treat it as a
  hint that under-copying is broader than the two packs we hit, not as a finding.
- I could not inspect the cook tooling, so §2 is specified in terms of required
  behaviour rather than concrete diffs.
- Whether `SIMPLE_Buildings_SourceFiles` (§1e) fails for this same reason is
  untested; it is the one other pack our sample caught.

## 5. Consumer-side context (no action needed from you)

Gutshot works around this today, and these are worth knowing so a fix does not
collide with them:

- `tools/patch_gltf_materials.py` reattaches a pack's atlas to texture-less
  materials, but **only when the mesh's UVs sit inside [0,1]**. It deliberately
  refuses tiling meshes, because wrapping an atlas across tiling UVs is what
  produced the "building wearing the entire texture page" artifact.
- `tools/audit_assets.py` reports both defect classes (§3.3).
- We swapped the broken SciFi_City `Background_*` buildings for CyberCity
  equivalents, which cook correctly.

Once the cook is fixed, the patcher's atlas-reattachment becomes dead weight and we
will remove it.
