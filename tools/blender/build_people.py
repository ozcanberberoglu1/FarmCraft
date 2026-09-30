"""Builds Yeşilova's townspeople from MakeHuman/MPFB2 CC0 assets (see tools/fetch_people.py,
which downloads MPFB2 and the asset packs and runs this):

    BLENDER_USER_RESOURCES=<cache>/bl_user Blender -b --python \
        tools/blender/build_people.py -- --data <cache>/packs/data --out art/models/people \
        [--tmp <dir>] [--only farmer] [--preview <dir>]

Every character is an MPFB2 human (base mesh, macro phenotype, a CC0 skin, eyes, brows,
lashes, hair, clothes from the asset packs) on the "game_engine" rig, plus what the
packs don't have and a Turkish country town needs, modelled here on the body itself:
the headscarf (yemeni) tied under the chin and the shopkeeper's apron. The body faces
the clothes cover are deleted, the targets baked, heavy parts decimated, everything
joined into one skinned mesh (one surface per material: skin, eyes, brows, lashes,
hair, beard, cloth_*) and exported as <name>.gltf with its textures downsized (skin 2k,
the rest 1k, JPEG where opaque) into textures/, named after their source asset so
characters wearing the same thing share them. The game animates the skeleton itself
(scripts/npc/human_rig.gd), so no clips are exported.
Blender units are metres, Z up, the human faces -Y (the glTF export turns it to +Z).
"""
import bmesh
import bpy
import math
import os
import sys

import mathutils

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


OUT = os.path.abspath(arg("--out", "art/models/people"))
DATA = os.path.abspath(arg("--data", "packs/data"))
ONLY = arg("--only")
PREVIEW = arg("--preview")
TMP = os.path.abspath(arg("--tmp", os.path.join(os.path.dirname(DATA), "_textures")))

MALE_BASE = {"gender": 1.0, "proportions": 0.5, "cupsize": 0.5, "firmness": 0.5,
             "race": {"caucasian": 0.8, "asian": 0.12, "african": 0.08}}
FEMALE_BASE = {"gender": 0.0, "proportions": 0.5, "cupsize": 0.5, "firmness": 0.45,
               "race": {"caucasian": 0.82, "asian": 0.12, "african": 0.06}}


def pheno(base, **kw):
    d = dict(base)
    d["race"] = dict(base["race"])
    d.update(kw)
    return d


# Age: 0.5 is 25 years, 1.0 is 90. "decimate": asset -> target vertex count.
PEOPLE = {
    "shopkeeper": {
        "phenotype": pheno(MALE_BASE, age=0.68, muscle=0.45, weight=0.7, height=0.45),
        "skin": "jartur69_middleage_slavic_male_with_genitals_and_beard",
        "hair": "short02", "eyebrows": "eyebrow001", "eyes": "brown",
        "clothes": ["male_casualsuit03", "shoes04", "rehmanpolanski_moustache_viking"],
        "extras": ["apron"],
    },
    "worker": {
        "phenotype": pheno(MALE_BASE, age=0.56, muscle=0.6, weight=0.5, height=0.55),
        "skin": "young_caucasian_male2",
        "hair": "short01", "eyebrows": "eyebrow002", "eyes": "brownlight",
        "clothes": ["male_worksuit01", "shoes03"],
        "extras": [],
    },
    "salesman": {
        "phenotype": pheno(MALE_BASE, age=0.64, muscle=0.5, weight=0.62, height=0.55),
        "skin": "middleage_caucasian_male",
        "hair": "short02", "eyebrows": "eyebrow003", "eyes": "brown",
        "clothes": ["male_elegantsuit01", "shoes04", "rehmanpolanski_moustache_viking"],
        "extras": [],
    },
    "farmer": {
        "phenotype": pheno(MALE_BASE, age=0.86, muscle=0.45, weight=0.55, height=0.42),
        "skin": "jartur69_old_slavic_male_with_genitals_and_beard",
        "hair": "short02", "eyebrows": "eyebrow001", "eyes": "brown",
        "clothes": ["male_casualsuit05", "shoes03", "jujube_newsboy_cap"],
        "extras": [],
    },
    "elder": {
        "phenotype": pheno(MALE_BASE, age=0.93, muscle=0.35, weight=0.5, height=0.4),
        "skin": "old_caucasian_male",
        "hair": "short02", "eyebrows": "eyebrow001", "eyes": "brown",
        "clothes": ["male_elegantsuit01", "shoes04", "fedora01", "rehmanpolanski_moustache_viking"],
        "extras": [],
    },
    "villager": {
        "phenotype": pheno(FEMALE_BASE, age=0.72, muscle=0.4, weight=0.68, height=0.35),
        "skin": "middleage_caucasian_female",
        "hair": "", "eyebrows": "eyebrow006", "eyes": "brown",
        "clothes": ["toigo_fisherman_sweater", "toigo_harem_pants", "toigo_flats"],
        "extras": ["headscarf"],
        # (inner, outer): the şalvar's waist stays under the sweater.
        "tuck": [("toigo_harem_pants", "toigo_fisherman_sweater")],
    },
    "young": {
        "phenotype": pheno(MALE_BASE, age=0.52, muscle=0.55, weight=0.45, height=0.6),
        "skin": "young_caucasian_male",
        "hair": "short04", "eyebrows": "eyebrow004", "eyes": "brown",
        "clothes": ["male_casualsuit01", "shoes05"],
        "extras": [],
    },
}
# Parts heavier than the rest of the figure together: decimated to about this many vertices.
MAX_VERTS = 2600


def mpfb():
    import addon_utils
    import importlib
    addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
    return importlib.import_module("bl_ext.user_default.mpfb.services.humanservice").HumanService


def clear():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images,
                 bpy.data.cameras, bpy.data.lights, bpy.data.worlds):
        for block in list(coll):
            coll.remove(block)


def find_asset(folder, filename):
    for dirpath, _dirs, files in os.walk(os.path.join(DATA, folder)):
        if filename in files:
            return os.path.join(dirpath, filename)
    return None


def build_human(name, spec):
    HumanService = mpfb()
    info = HumanService._create_default_human_info_dict()
    info["name"] = name
    info["phenotype"] = spec["phenotype"]
    info["rig"] = "game_engine"
    info["eyes"] = "low-poly.mhclo"
    info["eyebrows"] = spec["eyebrows"] + ".mhclo"
    info["eyelashes"] = "eyelashes01.mhclo"
    info["hair"] = (spec["hair"] + ".mhclo") if spec["hair"] else ""
    info["clothes"] = [c + ".mhclo" for c in spec["clothes"]]
    info["skin_mhmat"] = spec["skin"] + ".mhmat"
    info["skin_material_type"] = "GAMEENGINE"
    info["eyes_material_type"] = "MAKESKIN"
    info["clothes_material_type"] = "GAMEENGINE"
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    return HumanService.deserialize_from_dict(info, settings)


# --- Materials ---------------------------------------------------------------------------

def read_mhmat(path):
    keys = {}
    for line in open(path, encoding="utf-8", errors="ignore"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        if len(parts) == 2:
            keys[parts[0]] = parts[1]
    return keys


def texture(src, size, out_name, keep_alpha, iris=False):
    """Copy of `src` at `size` (JPEG unless it keeps alpha) as a Blender image. `iris`:
    the red-brown irises of the eye texture turned a dark hazel brown."""
    os.makedirs(TMP, exist_ok=True)
    img = bpy.data.images.load(src, check_existing=False)
    if img.size[0] > size:
        img.scale(size, size)
    if iris:
        import numpy as np
        px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
        rgb = px[:, :3]
        sat = rgb.max(axis=1) - rgb.min(axis=1)
        k = np.clip((sat - 0.12) / 0.2, 0.0, 1.0)[:, None]
        lum = (rgb * np.array([0.3, 0.55, 0.15], dtype=np.float32)).sum(axis=1, keepdims=True)
        hazel = lum * np.array([1.05, 0.78, 0.5], dtype=np.float32) * 0.8
        px[:, :3] = rgb * (1.0 - k) + hazel * k
        img.pixels = px.ravel().tolist()
    fmt = "PNG" if keep_alpha else "JPEG"
    path = os.path.join(TMP, out_name + (".png" if keep_alpha else ".jpg"))
    img.filepath_raw = path
    img.file_format = fmt
    img.save(quality=90) if fmt == "JPEG" else img.save()
    img.name = out_name
    return img


def make_material(mat_name, mhmat_path, kind, tex_name):
    """A plain Principled material from a MakeHuman .mhmat (what the glTF export writes);
    its textures are named after `tex_name` (the source asset), so characters wearing
    the same thing share the files."""
    keys = read_mhmat(mhmat_path)
    folder = os.path.dirname(mhmat_path)
    m = bpy.data.materials.new(mat_name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    alpha = kind in ("hair", "brows", "lashes") or (kind != "eyes" and keys.get("transparent", "False") == "True")
    size = 2048 if kind == "skin" else 1024
    if "diffuseTexture" in keys:
        src = os.path.join(folder, os.path.basename(keys["diffuseTexture"]))
        if os.path.exists(src):
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = texture(src, size, tex_name + "_albedo", alpha, kind == "eyes")
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            if alpha:
                nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    if "normalmapTexture" in keys and kind != "skin":
        src = os.path.join(folder, os.path.basename(keys["normalmapTexture"]))
        if os.path.exists(src):
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = texture(src, 1024 if mat_name.startswith("cloth_male") or mat_name.startswith("cloth_toigo") else 512,
                                tex_name + "_normal", False)
            tex.image.colorspace_settings.name = "Non-Color"
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(tex.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = {"skin": 0.55, "eyes": 0.1, "hair": 0.6}.get(kind, 0.85)
    if alpha:
        m.blend_method = "HASHED" if hasattr(m, "blend_method") else m.blend_method
    return m


def cloth_material(mat_name, color, pattern=None):
    """A material for the modelled extras: `pattern` is an image path (tiling) or None."""
    m = bpy.data.materials.new(mat_name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    if pattern:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(pattern, check_existing=True)
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def assign_materials(name, spec):
    """Every part gets a material named by its role; returns the body object."""
    body = None
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        part = o.name.split(".", 1)[1] if "." in o.name else o.name
        if part == "body":
            body = o
            mat = make_material("skin", find_asset("skins", spec["skin"] + ".mhmat"), "skin", "skin_" + spec["skin"].replace("_with_genitals_and_beard", ""))
        elif part == "low-poly":
            mat = make_material("eyes", find_asset("eyes", spec["eyes"] + ".mhmat"), "eyes", "eyes_" + spec["eyes"])
        elif part.startswith("eyebrow"):
            mat = make_material("brows", find_asset("eyebrows", part + ".mhmat"), "brows", part)
        elif part.startswith("eyelashes"):
            mat = make_material("lashes", find_asset("eyelashes", part + ".mhmat"), "lashes", part)
        elif part == spec["hair"]:
            mat = make_material("hair", find_asset("hair", part + ".mhmat"), "hair", "hair_" + part)
        else:
            clo = find_asset("clothes", part + ".mhclo")
            folder = os.path.dirname(clo)
            mhmats = [f for f in os.listdir(folder) if f.endswith(".mhmat")]
            kind = "beard" if ("moustache" in part or "beard" in part) else "cloth"
            mat = make_material(("beard" if kind == "beard" else "cloth_" + part), os.path.join(folder, mhmats[0]),
                                "hair" if kind == "beard" else "cloth", part)
        o.data.materials.clear()
        o.data.materials.append(mat)
    return body


# --- Mesh clean-up -----------------------------------------------------------------------

def activate(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def bake_and_mask(o):
    activate(o)
    if o.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for m in list(o.modifiers):
        if m.type in ("MASK", "SUBSURF"):
            bpy.ops.object.modifier_apply(modifier=m.name)


def decimate(o, target):
    n = len(o.data.vertices)
    if n <= target:
        return
    activate(o)
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.ratio = target / n
    bpy.ops.object.modifier_move_to_index(modifier="dec", index=0)
    bpy.ops.object.modifier_apply(modifier="dec")


def tuck(inner, outer, gap=0.007, reach=0.03):
    """Moves the vertices of garment `inner` that poke out through `outer` (or lie just
    under it) to `gap` under it, so the one under stays under when they move."""
    from mathutils.bvhtree import BVHTree
    tree = BVHTree.FromObject(outer, bpy.context.evaluated_depsgraph_get())
    moved = 0
    for v in inner.data.vertices:
        loc, nor, _i, _d = tree.find_nearest(v.co, reach)
        if loc is None or nor.dot(v.normal) < 0.3:
            continue
        if (v.co - loc).dot(nor) > -gap:
            v.co = loc - nor * gap
            moved += 1
    print("TUCK", inner.name, "under", outer.name, moved)


def hide_covered(body, covers, pushers):
    """Deletes the body faces under the clothes (the packs' delete groups miss some: the
    chest under a sweater, the scalp under the scarf), so nothing pokes through."""
    from mathutils.bvhtree import BVHTree
    deps = bpy.context.evaluated_depsgraph_get()
    trees = [BVHTree.FromObject(o, deps) for o in covers]
    push = [BVHTree.FromObject(o, deps) for o in pushers]
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.normal_update()
    # Skin poking out through the cloth (or just under it) goes 6 mm under it.
    for v in bm.verts:
        for t in push:
            loc, nor, _i, dist = t.find_nearest(v.co, 0.02)
            # (the outer side of the cloth: its normal along the skin's, not a lining's)
            if loc is not None and nor.dot(v.normal) > 0.3 and (v.co - loc).dot(nor) > -0.004:
                v.co = loc - nor * 0.006
                break
    bm.normal_update()
    covered = set()
    for v in bm.verts:
        n = v.normal
        origin = v.co + n * 0.002
        for t in trees:
            hit = t.ray_cast(origin, n, 0.045)
            if hit[0] is not None:
                covered.add(v)
                break
    dead = [f for f in bm.faces if all(v in covered for v in f.verts)]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(body.data)
    bm.free()


# --- Extras modelled on the body -----------------------------------------------------------

def bone_head(arm, bone):
    bpy.context.view_layer.update()
    return arm.matrix_world @ arm.data.bones[bone].head_local


def add_armature(o, arm):
    o.parent = arm
    mod = o.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def headscarf(body, arm):
    """A yemeni: a shell over the head from just above the brows round the face to under
    the chin, down the neck and flaring onto the shoulders at the back, a knot under the chin."""
    head = bone_head(arm, "head")
    neck = bone_head(arm, "neck_01")
    eyes = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.endswith("low-poly"))
    ev = [eyes.matrix_world @ v.co for v in eyes.data.vertices]
    eye = sum(ev, mathutils.Vector()) / len(ev)
    eye_front = min(v.y for v in ev)
    top_z = max((body.matrix_world @ v.co).z for v in body.data.vertices)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    mw = body.matrix_world
    keep = set()
    for f in bm.faces:
        c = mw @ f.calc_center_median()
        if c.z < neck.z - 0.03:
            continue
        # The face opening: an ellipse on the front, the brows to the chin, cheek to cheek.
        in_face = c.y < eye.y + 0.012 and ((c.x - eye.x) / 0.068) ** 2 + ((c.z - eye.z + 0.035) / 0.086) ** 2 < 1.0
        if in_face:
            continue
        # Only the head and neck (not the shoulders' top) are wrapped.
        if abs(c.x - head.x) > 0.12 and c.z < head.z:
            continue
        keep.add(f)
    for f in [f for f in bm.faces if f not in keep]:
        bm.faces.remove(f)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bm.normal_update()
    # Off the skin: a little more over the crown (the hair under it), loose from the jaw down.
    for v in bm.verts:
        p = mw @ v.co
        lift = 0.006 + 0.012 * max(0.0, min(1.0, (p.z - eye.z) / (top_z - eye.z)))
        if p.z < eye.z - 0.09:
            lift += 0.016 * min(1.0, (eye.z - 0.09 - p.z) / 0.06)
        if p.y > eye.y + 0.08 and neck.z < p.z < eye.z:
            lift += 0.012  # the hair gathered at the nape
        n = v.normal.copy()
        if p.z < eye.z - 0.09:
            n.z *= 0.3
            n.normalize()
        v.co += n * lift
    for _ in range(3):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    me = bpy.data.meshes.new("headscarf")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(body.name.split(".")[0] + ".headscarf", me)
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = body.matrix_world
    activate(o)
    # The back flap over the shoulders and the knot's tails: extrude the lower rim down.
    activate(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(me)
    rim = [e for e in bm.edges if e.is_boundary and (mw @ e.verts[0].co).z < neck.z + 0.02]
    ret = bmesh.ops.extrude_edge_only(bm, edges=rim)
    for v in [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]:
        p = mw @ v.co
        back = max(0.0, min(1.0, (p.y - head.y + 0.02) / 0.08))
        v.co.z -= (0.03 + 0.1 * back) / mw.to_scale().z
        v.co.y += 0.02 * back / mw.to_scale().y
        v.co.x *= 1.0 + 0.25 * back
    bmesh.update_edit_mesh(me)
    bpy.ops.object.mode_set(mode="OBJECT")
    solid = o.modifiers.new("solid", "SOLIDIFY")
    solid.thickness = 0.004 / mw.to_scale().x
    solid.offset = 1.0
    bpy.ops.object.modifier_apply(modifier="solid")
    bpy.ops.object.shade_smooth()
    # UVs: a cylinder round the head (the print tiles).
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cylinder_project(direction="ALIGN_TO_OBJECT", scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    for loop_uv in o.data.uv_layers.active.data:
        loop_uv.uv = (loop_uv.uv[0] * 5.0, loop_uv.uv[1] * 3.0)
    # The knot under the chin.
    knot_at = mathutils.Vector((eye.x, eye_front + 0.05, eye.z - 0.15))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.022)
    for v in bm.verts:
        v.co = mathutils.Vector((v.co.x * 1.3, v.co.y * 0.8, v.co.z))
    for sx in (-1.0, 1.0):
        ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.018, radius2=0.008, depth=0.07)
        for v in ret["verts"]:
            v.co = mathutils.Vector((v.co.x * 1.2 + sx * 0.012, v.co.y * 0.4 - 0.005, v.co.z - 0.04))
    kme = bpy.data.meshes.new("knot")
    bm.to_mesh(kme)
    bm.free()
    k = bpy.data.objects.new("knot", kme)
    bpy.context.scene.collection.objects.link(k)
    k.location = knot_at
    activate(k)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    k.select_set(True)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    o.data.materials.clear()
    o.data.materials.append(cloth_material("cloth_scarf", (0.8, 0.8, 0.8), SCARF_PRINT))
    for p in o.data.polygons:
        p.material_index = 0
    # Skinned like the head, neck and shoulders' top under it (not the upper arms the
    # flap at the back comes near).
    scarf_bones = ("head", "neck_01", "spine_03", "spine_02", "clavicle_l", "clavicle_r")
    set_weights(o, smooth_weights(o, skin_like_torso(o, body, scarf_bones), 2))
    add_armature(o, arm)
    return o


# The bones the torso's clothes may follow (not the arms': in the A pose the forearms
# hang next to the hips, and a nearest-skin transfer would hand them the apron).
TORSO_BONES = ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r")
LIMB_PREFIXES = ("upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky", "head")


def bone_weights(o, bones):
    """Per vertex of `o`: {bone: weight} over the groups named after `bones`."""
    names = {g.index: g.name for g in o.vertex_groups}
    out = []
    for v in o.data.vertices:
        d = {}
        for ge in v.groups:
            n = names.get(ge.group)
            if n in bones and ge.weight > 0.0:
                d[n] = ge.weight
        out.append(d)
    return out


def set_weights(o, weights):
    """Replaces `o`'s vertex groups with `weights` (per vertex {bone: w}), at most four a
    vertex, normalised."""
    o.vertex_groups.clear()
    groups = {}
    for i, d in enumerate(weights):
        top = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        s = sum(w for _n, w in top) or 1.0
        for n, w in top:
            if w / s < 0.01:
                continue
            if n not in groups:
                groups[n] = o.vertex_groups.new(name=n)
            groups[n].add([i], w / s, "REPLACE")


def smooth_weights(o, weights, rounds):
    """Each vertex's weights averaged with its neighbours' `rounds` times (no seams where
    two bones meet)."""
    nb = [[] for _ in o.data.vertices]
    for e in o.data.edges:
        a, b = e.vertices
        nb[a].append(b)
        nb[b].append(a)
    for _ in range(rounds):
        new = []
        for i, d in enumerate(weights):
            acc = dict((k, v * 2.0) for k, v in d.items())
            for j in nb[i]:
                for k, v in weights[j].items():
                    acc[k] = acc.get(k, 0.0) + v
            s = sum(acc.values()) or 1.0
            new.append(dict((k, v / s) for k, v in acc.items()))
        weights = new
    return weights


def skin_like_torso(o, body, bones=TORSO_BONES, k=8):
    """Weights for `o` from the nearest skin or clothes under it that the torso carries
    (the mean of the `k` nearest such vertices of the body and the garments from the
    packs, only `bones`; the body's masked where the clothes cover it)."""
    from mathutils.kdtree import KDTree
    arm = next(x for x in bpy.data.objects if x.type == "ARMATURE")
    names = {b.name for b in arm.data.bones}
    sources = [body] + [x for x in bpy.data.objects if x.type == "MESH" and x is not o and x is not body
                        and x.data.materials and x.data.materials[0].name.startswith("cloth_")
                        and not any(t in x.name for t in ("apron", "headscarf"))]
    pts = []
    for src in sources:
        mw = src.matrix_world
        for v, d in zip(src.data.vertices, bone_weights(src, names)):
            if not d:
                continue
            top = max(d.items(), key=lambda kv: kv[1])[0]
            if top in bones:
                pts.append((mw @ v.co, {n: w for n, w in d.items() if n in bones}))
    tree = KDTree(len(pts))
    for i, (p, _d) in enumerate(pts):
        tree.insert(p, i)
    tree.balance()
    out = []
    for v in o.data.vertices:
        acc = {}
        for _co, i, dist in tree.find_n(o.matrix_world @ v.co, k):
            w0 = 1.0 / (dist + 0.01)
            for n, w in pts[i][1].items():
                acc[n] = acc.get(n, 0.0) + w * w0
        s = sum(acc.values()) or 1.0
        out.append(dict((n, w / s) for n, w in acc.items()))
    return out


def _hull(points):
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def _ray_hull(hull, cx, cy, ang):
    """How far from (cx, cy) the hull's edge is in direction `ang` (0: the front, -Y;
    + towards +X, the figure's left)."""
    dx, dy = math.sin(ang), -math.cos(ang)
    best = 0.0
    n = len(hull)
    for i in range(n):
        x1, y1 = hull[i]
        x2, y2 = hull[(i + 1) % n]
        ex, ey = x2 - x1, y2 - y1
        den = dx * ey - dy * ex
        if abs(den) < 1e-12:
            continue
        t = ((x1 - cx) * ey - (y1 - cy) * ex) / den
        s = ((x1 - cx) * dy - (y1 - cy) * dx) / den
        if -1e-6 <= s <= 1.0 + 1e-6 and t > best:
            best = t
    return best


class Wrap:
    """The dressed figure's outline (skin and clothes, not the arms or head) as a stack of
    horizontal slices round a vertical axis: at height z and direction a (0 the front),
    how far out a cloth laid over it lies: the convex hull of the slice (cloth bridges
    hollows: between the legs, under the chest), draped (it can't tuck in under a belly
    faster than `drape` per metre going down)."""
    ANGLES = [(-3.14159 + 3.14159 * 2 * i / 240) for i in range(241)]

    def __init__(self, meshes, bones, cx, cy, z0, z1, step=0.02):
        self.cx, self.cy, self.z0, self.step = cx, cy, z0, step
        n = int(round((z1 - z0) / step)) + 1
        self.n = n
        rows = [[] for _ in range(n)]
        # Each slice through the surfaces themselves (where their triangles cross it: a big
        # flat triangle can stand out past its corners' slices), not the arms or head.
        for o in meshes:
            names = {g.index: g.name for g in o.vertex_groups}
            mw = o.matrix_world
            limb = []
            for v in o.data.vertices:
                top, tw = None, 0.0
                for ge in v.groups:
                    nm = names.get(ge.group, "")
                    if ge.weight > tw and nm in bones:
                        top, tw = nm, ge.weight
                limb.append(top is None or top.startswith(LIMB_PREFIXES))
            co = [mw @ v.co for v in o.data.vertices]
            o.data.calc_loop_triangles()
            for tri in o.data.loop_triangles:
                ids = tri.vertices
                if sum(1 for i in ids if limb[i]) >= 2:
                    continue
                ps = [co[i] for i in ids]
                lo = min(p.z for p in ps)
                hi = max(p.z for p in ps)
                for k in range(max(0, int(math.ceil((lo - z0) / step))), min(n - 1, int(math.floor((hi - z0) / step))) + 1):
                    z = z0 + k * step
                    for a, b in ((ps[0], ps[1]), (ps[1], ps[2]), (ps[2], ps[0])):
                        if (a.z - z) * (b.z - z) <= 0.0 and a.z != b.z:
                            t = (z - a.z) / (b.z - a.z)
                            rows[k].append((round(a.x + (b.x - a.x) * t, 4), round(a.y + (b.y - a.y) * t, 4)))
        self.r = []
        for k in range(n):
            h = _hull(rows[k]) if len(rows[k]) >= 3 else None
            self.r.append([_ray_hull(h, cx, cy, a) if h else 0.0 for a in self.ANGLES])
        # Rows with nothing in them: from their neighbours.
        for k in range(n):
            if max(self.r[k]) == 0.0:
                src = next((self.r[j] for d in range(1, n) for j in (k - d, k + d) if 0 <= j < n and max(self.r[j]) > 0.0), None)
                if src:
                    self.r[k] = list(src)
        # Round each slice a little.
        for k in range(n):
            r = self.r[k]
            m = len(r)
            s = [(r[(i - 2) % m] + 2 * r[(i - 1) % m] + 3 * r[i] + 2 * r[(i + 1) % m] + r[(i + 2) % m]) / 9.0 for i in range(m)]
            self.r[k] = [max(a, b - 0.002) for a, b in zip(s, r)]

    def drape(self, z_from, z_to, per_m):
        """Cloth hanging from z_from down to z_to can come in towards the body by at most
        `per_m` metres per metre (and bridges hollows going up from z_to the same way)."""
        k0 = int(round((z_from - self.z0) / self.step))
        k1 = int(round((z_to - self.z0) / self.step))
        d = per_m * self.step
        lo, hi = min(k0, k1), max(k0, k1)
        for k in range(hi - 1, lo - 1, -1):
            self.r[k] = [max(a, b - d) for a, b in zip(self.r[k], self.r[k + 1])]
        for k in range(lo + 1, hi + 1):
            self.r[k] = [max(a, b - d) for a, b in zip(self.r[k], self.r[k - 1])]

    def radius(self, z, a):
        f = min(max((z - self.z0) / self.step, 0.0), self.n - 1.0)
        k = min(int(f), self.n - 2)
        t = f - k
        g = (a + 3.14159) / (2 * 3.14159) * 240
        g = min(max(g, 0.0), 239.999)
        i = int(g)
        u = g - i
        r0 = self.r[k][i] * (1 - u) + self.r[k][i + 1] * u
        r1 = self.r[k + 1][i] * (1 - u) + self.r[k + 1][i + 1] * u
        return r0 * (1 - t) + r1 * t

    def point(self, z, a, off):
        r = self.radius(z, a) + off
        return mathutils.Vector((self.cx + r * math.sin(a), self.cy - r * math.cos(a), z))

    def normal(self, z, a):
        e = 0.01
        p = self.point(z, a, 0.0)
        ta = self.point(z, a + e, 0.0) - self.point(z, a - e, 0.0)
        tz = self.point(z + e, a, 0.0) - self.point(z - e, a, 0.0)
        n = tz.cross(ta)
        out = mathutils.Vector((math.sin(a), -math.cos(a), 0.0))
        if n.dot(out) < 0.0:
            n = -n
        return n.normalized() if n.length > 1e-9 else out

    def edge_angle(self, z, half_width, limit):
        """The direction where the surface is `half_width` out to the side."""
        a = 0.0
        while a < limit:
            if self.radius(z, a) * math.sin(a) >= half_width and self.radius(z, -a) * math.sin(a) >= half_width:
                return a
            a += 0.005
        return limit


def _band(bm, path, width, wrap, off, lift=None):
    """A ribbon `width` wide along `path` [(z, a), ...] on the wrap, `off` out from it (or
    `lift(i)` more for point i); its face towards the outside. Returns its vertices."""
    pts = [wrap.point(z, a, off + (lift(i) if lift else 0.0)) for i, (z, a) in enumerate(path)]
    nors = [wrap.normal(z, a) for (z, a) in path]
    verts = []
    faces = []
    prev = None
    facing = 0.0
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = nors[i].cross(t).normalized() * (width * 0.5)
        v0 = bm.verts.new(p - side)
        v1 = bm.verts.new(p + side)
        verts += [v0, v1]
        if prev:
            f = bm.faces.new((prev[0], prev[1], v1, v0))
            f.normal_update()
            facing += f.normal.dot(nors[i])
            faces.append(f)
        prev = (v0, v1)
    # (all one way: a face turned alone would leave a hole where the back is culled)
    if facing < 0.0:
        for f in faces:
            f.normal_flip()
    return verts


def _smooth_path(points, n):
    """`points` [(z, a)] resampled to `n` along a Catmull-Rom curve."""
    P = [points[0]] + list(points) + [points[-1]]
    out = []
    segs = len(points) - 1
    for s in range(n):
        f = s / (n - 1) * segs
        i = min(int(f), segs - 1)
        t = f - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(tuple(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
                         for a, b, c, d in zip(p0, p1, p2, p3)))
    return out


def apron(body, arm):
    """A shopkeeper's bib apron (önlük): cut like the real thing (a narrow bib over the
    chest, curved out under the arms to a skirt that wraps round the hips to the sides and
    hangs to the knees), laid over the shirt: shrink-wrapped on the figure's outline (the
    convex hull of each slice, so it bridges the hollows as cloth does) and hanging
    straight down off the belly; a strap round the back of the neck, ties round the waist
    knotted in a bow at the back. It is skinned like the torso under it (never the arms);
    the skirt follows the thighs part way, evenly across, so it never tears."""
    pelvis = bone_head(arm, "pelvis")
    spine1 = bone_head(arm, "spine_01")
    spine2 = bone_head(arm, "spine_02")
    neck = bone_head(arm, "neck_01")
    hip = bone_head(arm, "thigh_l")
    knee = bone_head(arm, "calf_l")
    figure = [body] + [o for o in bpy.data.objects if o.type == "MESH" and o.name.split(".", 1)[-1].startswith("male_")]
    z_top = neck.z - 0.155
    z_waist = spine1.z + 0.01
    z_hem = knee.z - 0.03
    wrap = Wrap(figure, {b.name for b in arm.data.bones}, 0.0, spine2.y, z_hem - 0.06, neck.z + 0.06)
    wrap.drape(z_waist + 0.1, z_hem - 0.04, 0.22)   # the skirt hangs off the belly
    wrap.drape(z_top + 0.04, z_waist + 0.1, 0.55)  # the bib over the chest and belly

    def half_width(z):
        if z >= z_waist + 0.1:
            return 0.115 + (0.14 - 0.115) * (z_top - z) / max(z_top - z_waist - 0.1, 0.01)
        if z >= z_waist - 0.02:
            t = (z_waist + 0.1 - z) / 0.12
            t = t * t * (3 - 2 * t)
            return 0.14 + (0.215 - 0.14) * t
        return 0.215 + 0.015 * (z_waist - 0.02 - z) / max(z_waist - 0.02 - z_hem, 0.01)

    rows, cols = 44, 18
    zs = [z_top + (z_hem - z_top) * i / rows for i in range(rows + 1)]
    edges = [wrap.edge_angle(z, half_width(z), 1.3) for z in zs]
    edges = [sum(edges[max(0, i - 2):i + 3]) / len(edges[max(0, i - 2):i + 3]) for i in range(len(edges))]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    grid = []
    for i, z in enumerate(zs):
        off = 0.009 + 0.005 * max(0.0, (z_waist - z) / (z_waist - z_hem))
        line = []
        for j in range(cols + 1):
            a = -edges[i] + 2.0 * edges[i] * j / cols
            line.append(bm.verts.new(wrap.point(z, a, off)))
        grid.append(line)
    sheet = []
    facing = 0.0
    for i in range(rows):
        for j in range(cols):
            vs = (grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1])
            f = bm.faces.new(vs)
            f.normal_update()
            c = sum((v.co for v in vs), mathutils.Vector()) / 4.0
            facing += f.normal.dot(mathutils.Vector((c.x - wrap.cx, c.y - wrap.cy, 0.0)))
            sheet.append(f)
            for loop in f.loops:
                p = loop.vert.co
                loop[uv].uv = ((p.x + 0.3) / 0.12, (p.z - z_hem) / 0.12)
    if facing < 0.0:
        for f in sheet:
            f.normal_flip()
    # The neck strap, from the bib's top corners up and round the back of the neck.
    for sgn in (-1.0, 1.0):
        e0 = edges[0]
        path = [(z_top + 0.005, sgn * e0 * 0.9), (z_top + 0.07, sgn * e0 * 0.85), (neck.z - 0.035, sgn * 0.75),
                (neck.z - 0.012, sgn * 1.25), (neck.z + 0.004, sgn * 2.1), (neck.z + 0.01, sgn * 3.1)]
        _band(bm, _smooth_path(path, 16), 0.024, wrap, 0.007)
    # The ties from the waist's sides round the back, a bow and its tails there.
    ew = edges[min(range(len(zs)), key=lambda i: abs(zs[i] - z_waist))]
    for sgn in (-1.0, 1.0):
        path = [(z_waist, sgn * (ew - 0.02)), (z_waist + 0.003, sgn * 1.9), (z_waist + 0.004, sgn * 2.6), (z_waist + 0.004, sgn * 3.08)]
        _band(bm, _smooth_path(path, 12), 0.026, wrap, 0.012)
        # A loop of the bow: a flattened ring standing off the back.
        loop_path = []
        for s in range(13):
            t = s / 12.0 * 2 * math.pi
            loop_path.append((z_waist + 0.004 + math.sin(t) * 0.022, sgn * (3.14159 - 0.2 - 0.2 * math.cos(t))))
        _band(bm, loop_path, 0.02, wrap, 0.018)
        # A tail hanging from the knot.
        tail = [(z_waist - 0.01 - 0.19 * s / 8.0, sgn * (3.14159 - 0.05 - 0.09 * s / 8.0)) for s in range(9)]
        _band(bm, tail, 0.026, wrap, 0.02)
    knot = wrap.point(z_waist + 0.004, 3.14159, 0.02)
    ret = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=0.016)
    for v in ret["verts"]:
        v.co = knot + mathutils.Vector((v.co.x * 1.2, v.co.y * 0.7, v.co.z))
    me = bpy.data.meshes.new("apron")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(body.name.split(".")[0] + ".apron", me)
    bpy.context.scene.collection.objects.link(o)
    activate(o)
    solid = o.modifiers.new("solid", "SOLIDIFY")
    solid.thickness = 0.0025
    solid.offset = -1.0
    bpy.ops.object.modifier_apply(modifier="solid")
    bpy.ops.object.shade_smooth()
    o.data.materials.append(cloth_material("cloth_apron", (0.05, 0.075, 0.14), make_twill()))
    # Skinned like the torso under it; below the hips the skirt follows the thighs part
    # way (evenly across it: no tearing between the legs).
    w = skin_like_torso(o, body)
    for i, v in enumerate(o.data.vertices):
        p = o.matrix_world @ v.co
        s = 0.8 * min(max((hip.z + 0.02 - p.z) / 0.3, 0.0), 1.0)
        s = s * s * (3 - 2 * s)
        if s > 0.0:
            left = min(max((p.x + 0.14) / 0.28, 0.0), 1.0)
            left = left * left * (3 - 2 * left)
            d = dict((n, x * (1.0 - s)) for n, x in w[i].items())
            d["thigh_l"] = d.get("thigh_l", 0.0) + s * left
            d["thigh_r"] = d.get("thigh_r", 0.0) + s * (1.0 - left)
            w[i] = d
    set_weights(o, smooth_weights(o, w, 4))
    add_armature(o, arm)
    return o


TWILL = os.path.join(TMP, "apron_twill.png")


def make_twill():
    """A navy cotton twill (the apron's cloth, tiling 12 cm): diagonal ribs, a little
    mottling and slub."""
    os.makedirs(TMP, exist_ok=True)
    import random
    size = 256
    rnd = random.Random(11)
    img = bpy.data.images.new("apron_twill", size, size)
    base = (0.05, 0.075, 0.14)
    slub = [1.0 + (rnd.random() - 0.5) * 0.12 for _ in range(size)]
    blot = [[0.0] * 17 for _ in range(17)]
    for y in range(17):
        for x in range(17):
            blot[y][x] = (rnd.random() - 0.5) * 0.1
    for y in range(16):
        blot[y][16] = blot[y][0]
    blot[16] = list(blot[0])
    px = [0.0] * (size * size * 4)
    for y in range(size):
        for x in range(size):
            rib = 0.9 + 0.2 * (((x + y) // 3) % 2)
            fx, fy = x / 16.0, y / 16.0
            ix, iy = int(fx), int(fy)
            tx, ty = fx - ix, fy - iy
            m = (blot[iy][ix] * (1 - tx) + blot[iy][ix + 1] * tx) * (1 - ty) + (blot[iy + 1][ix] * (1 - tx) + blot[iy + 1][ix + 1] * tx) * ty
            k = rib * slub[y] * (1.0 + m)
            i = (y * size + x) * 4
            px[i:i + 4] = [base[0] * k, base[1] * k, base[2] * k, 1.0]
    img.pixels = px
    img.filepath_raw = TWILL
    img.file_format = "PNG"
    img.save()
    return TWILL


SCARF_PRINT = os.path.join(TMP, "scarf_print.png")


def make_scarf_print():
    """A cream yemeni print: small dark-red and green flowers on a sprig pattern."""
    os.makedirs(TMP, exist_ok=True)
    size = 256
    img = bpy.data.images.new("scarf_print", size, size)
    px = [0.0] * (size * size * 4)
    base = (0.72, 0.68, 0.6)
    import random
    rnd = random.Random(7)
    spots = [(rnd.random() * size, rnd.random() * size, rnd.choice([(0.55, 0.1, 0.12), (0.2, 0.35, 0.18), (0.62, 0.42, 0.12)])) for _ in range(70)]
    for y in range(size):
        for x in range(size):
            col = base
            for sx, sy, c in spots:
                dx = min(abs(x - sx), size - abs(x - sx))
                dy = min(abs(y - sy), size - abs(y - sy))
                d = math.hypot(dx, dy)
                ang = math.atan2(dy, dx)
                petal = 4.0 + 1.6 * math.cos(ang * 5.0)
                if d < petal:
                    col = (0.85, 0.72, 0.2) if d < 1.8 else c
                    break
            i = (y * size + x) * 4
            px[i:i + 4] = [col[0], col[1], col[2], 1.0]
    img.pixels = px
    img.filepath_raw = SCARF_PRINT
    img.file_format = "PNG"
    img.save()


# --- Assembly ------------------------------------------------------------------------------

def finish(name, spec):
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = assign_materials(name, spec)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in meshes:
        bake_and_mask(o)
    for o in meshes:
        if o is not body:
            decimate(o, MAX_VERTS)
    for inner, outer in spec.get("tuck", []):
        parts = {o.name.split(".", 1)[-1]: o for o in bpy.data.objects if o.type == "MESH"}
        tuck(parts[inner], parts[outer])
    extras = []
    if "headscarf" in spec["extras"]:
        extras.append(headscarf(body, arm))
    if "apron" in spec["extras"]:
        extras.append(apron(body, arm))
    covers = [o for o in bpy.data.objects if o.type == "MESH" and o is not body
              and o.data.materials and o.data.materials[0].name.startswith("cloth_")]
    # Garments push poking skin under them; head wear (built off the skin) doesn't, nor
    # the apron (it lies over the shirt: skin pushed under it would come out over that).
    hide_covered(body, covers, [o for o in covers if not any(k in o.name for k in ("headscarf", "cap", "hat", "apron"))])
    # One skinned mesh.
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = name
    body.data.name = name
    # Clean: loose parts, unused groups.
    activate(body)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("PERSON", name, "verts", len(body.data.vertices), "tris", tris, "mats", [m.name for m in body.data.materials])
    arm.name = "Skeleton"
    return arm, body


def export(name, arm, body):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".gltf"), export_format="GLTF_SEPARATE",
                              export_texture_dir="textures", use_selection=True,
                              export_skins=True, export_animations=False, export_morph=False, export_apply=True,
                              export_image_format="AUTO", export_yup=True, export_def_bones=True)


def preview(name, arm, body):
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x, sc.render.resolution_y = 700, 900
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.55, 0.6, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    sc.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    hz = bone_head(arm, "head").z + 0.08
    for tag, pos, look, lens in (("full", (1.4, -3.6, 1.1), (0, 0, 0.9), 50), ("face", (0.25, -0.75, hz + 0.04), (0, 0, hz), 85)):
        cam.location = pos
        d = mathutils.Vector(look) - mathutils.Vector(pos)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "%s_%s.png" % (name, tag))
        bpy.ops.render.render(write_still=True)


def main():
    for name, spec in PEOPLE.items():
        if ONLY and name not in ONLY.split(","):
            continue
        clear()
        if "headscarf" in spec["extras"]:
            make_scarf_print()
        build_human(name, spec)
        arm, body = finish(name, spec)
        export(name, arm, body)
        if PREVIEW:
            preview(name, arm, body)


main()
