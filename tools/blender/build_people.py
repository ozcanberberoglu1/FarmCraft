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


def transfer_weights(target, source):
    """Skin `target` like the nearest surface of `source` (the body)."""
    activate(target)
    for g in source.vertex_groups:
        if g.name not in target.vertex_groups:
            target.vertex_groups.new(name=g.name)
    mod = target.modifiers.new("dt", "DATA_TRANSFER")
    mod.object = source
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.modifier_apply(modifier="dt")


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
    transfer_weights(o, body)
    add_armature(o, arm)
    return o


def apron(body, arm):
    """A bib apron over the shirt: a sheet from the chest to below the knees, laid on the
    front of the figure (flat across the legs), a neck strap and waist ties."""
    pelvis = bone_head(arm, "pelvis")
    chest = bone_head(arm, "spine_03")
    neck = bone_head(arm, "neck_01")
    knee = bone_head(arm, "calf_l")
    deps = bpy.context.evaluated_depsgraph_get()
    solids = [o for o in bpy.data.objects if o.type == "MESH" and o.name.split(".", 1)[-1].startswith("male_")] + [body]
    top = chest.z + 0.08
    bottom = knee.z + 0.03
    cols, rows = 12, 22
    verts = []
    front = []
    for r in range(rows + 1):
        z = top + (bottom - top) * r / rows
        width = 0.12 if z > pelvis.z + 0.18 else 0.21
        if pelvis.z + 0.1 < z <= pelvis.z + 0.18:
            t = (z - pelvis.z - 0.1) / 0.08
            width = 0.21 + (0.12 - 0.21) * t
        row = []
        for c in range(cols + 1):
            x = pelvis.x + (c / cols * 2.0 - 1.0) * width
            y = 0.2
            for o in solids:
                inv = o.matrix_world.inverted()
                ok, loc, _n, _i = o.ray_cast(inv @ mathutils.Vector((x, -1.0, z)), (inv.to_3x3() @ mathutils.Vector((0, 1, 0))).normalized(), depsgraph=deps)
                if ok:
                    y = min(y, (o.matrix_world @ loc).y)
            row.append([x, y, z])
        front.append(row)
    # Below the crotch the cloth hangs flat from leg to leg (the front-most point of the row).
    for r, row in enumerate(front):
        z = row[0][2]
        if z < pelvis.z - 0.05:
            ymin = min(p[1] for p in row)
            for p in row:
                p[1] = ymin
        valid = [p[1] for p in row if p[1] < 0.19]
        fill = min(valid) if valid else 0.0
        for p in row:
            if p[1] >= 0.19:
                p[1] = fill
    # Smooth across and down, then off the clothes.
    for _ in range(4):
        for r in range(rows + 1):
            for c in range(1, cols):
                front[r][c][1] = (front[r][c - 1][1] + 2 * front[r][c][1] + front[r][c + 1][1]) / 4
        for r in range(1, rows):
            for c in range(cols + 1):
                front[r][c][1] = min(front[r][c][1], (front[r - 1][c][1] + 2 * front[r][c][1] + front[r + 1][c][1]) / 4)
    bm = bmesh.new()
    grid = []
    for r in range(rows + 1):
        line = []
        for c in range(cols + 1):
            x, y, z = front[r][c]
            line.append(bm.verts.new((x, y - 0.012, z)))
        grid.append(line)
    uv = bm.loops.layers.uv.new()
    for r in range(rows):
        for c in range(cols):
            f = bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
            for loop, (cc, rr) in zip(f.loops, ((c, r), (c + 1, r), (c + 1, r + 1), (c, r + 1))):
                loop[uv].uv = (cc / cols, 1.0 - rr / rows)
    # The neck strap: a band from the bib's top corners round the back of the neck.
    for sx in (-1.0, 1.0):
        a = mathutils.Vector(front[0][0 if sx < 0 else cols])
        pts = [a, mathutils.Vector((neck.x + sx * 0.07, neck.y - 0.02, neck.z + 0.02)),
               mathutils.Vector((neck.x + sx * 0.055, neck.y + 0.06, neck.z + 0.03)),
               mathutils.Vector((neck.x, neck.y + 0.075, neck.z + 0.035))]
        prev = None
        for p in pts:
            v0 = bm.verts.new(p + mathutils.Vector((0, 0, -0.012)))
            v1 = bm.verts.new(p + mathutils.Vector((0, 0, 0.012)))
            if prev:
                bm.faces.new((prev[0], v0, v1, prev[1]))
            prev = (v0, v1)
    me = bpy.data.meshes.new("apron")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(body.name.split(".")[0] + ".apron", me)
    bpy.context.scene.collection.objects.link(o)
    activate(o)
    solid = o.modifiers.new("solid", "SOLIDIFY")
    solid.thickness = 0.005
    bpy.ops.object.modifier_apply(modifier="solid")
    bpy.ops.object.shade_smooth()
    o.data.materials.append(cloth_material("cloth_apron", (0.07, 0.12, 0.1)))
    transfer_weights(o, body)
    add_armature(o, arm)
    return o


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
    extras = []
    if "headscarf" in spec["extras"]:
        extras.append(headscarf(body, arm))
    if "apron" in spec["extras"]:
        extras.append(apron(body, arm))
    covers = [o for o in bpy.data.objects if o.type == "MESH" and o is not body
              and o.data.materials and o.data.materials[0].name.startswith("cloth_")]
    # Garments push poking skin under them; head wear (built off the skin) doesn't.
    hide_covered(body, covers, [o for o in covers if not any(k in o.name for k in ("headscarf", "cap", "hat"))])
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
