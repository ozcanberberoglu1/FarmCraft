"""Builds the chick model (a day-old chick in yellow down) into art/models/animals/source/chick/.

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_chick.py [-- --preview=/abs/dir]

Modelled here from scratch (no source asset): a round downy body and a big round head,
a short beak, black eyes, stubby wings and thin orange legs with four toes. The down is
a painted fibre texture with a matching normal map, and the surface is tufted so the
outline is soft and uneven. Skinned to a small skeleton the game's PhotoRig
drives with the chicken's procedural gait: root, body, neck, head, wing_l/r and per leg
thigh, shank and foot (config: PhotoRig.MODELS["chick"]). Z up, facing -Y; metres, a
chick of about ten centimetres.
"""
import math
import os
import sys

import bpy
import bmesh
import mathutils
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art/models/animals/source/chick")
TEX_DIR = os.path.join(OUT_DIR, "textures")

BODY_C = mathutils.Vector((0.0, 0.004, 0.047))
BODY_R = mathutils.Vector((0.031, 0.04, 0.032))
HEAD_C = mathutils.Vector((0.0, -0.03, 0.086))
HEAD_R = 0.023
HIP_Z = 0.036
FOOT_Z = 0.004
LEG_X = 0.012


def args():
    out = {}
    if "--" in sys.argv:
        for a in sys.argv[sys.argv.index("--") + 1:]:
            if a.startswith("--") and "=" in a:
                k, v = a[2:].split("=", 1)
                out[k] = v
    return out


# --- Textures ----------------------------------------------------------------------------

def down_texture(path, size=512, normal_path=None):
    """Soft yellow down: fine fibres streaked in every direction over a warm base (and,
    with `normal_path`, the fibres' relief as a tangent-space normal map)."""
    rng = np.random.default_rng(5)
    img = np.zeros((size, size), dtype=np.float32)
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    # Many short fibres drawn as oriented streaks of noise.
    noise = rng.random((size, size)).astype(np.float32)
    acc = np.zeros_like(noise)
    for k in range(10):
        ang = rng.random() * math.pi
        dx, dy = math.cos(ang), math.sin(ang)
        shifted = noise.copy()
        for s in range(1, 9):
            shifted += np.roll(np.roll(noise, int(round(dx * s)), axis=1), int(round(dy * s)), axis=0)
        acc += shifted / 9.0
    acc /= 10.0
    acc = (acc - acc.min()) / (acc.max() - acc.min())
    blotch = np.zeros_like(acc)
    for f in [4, 9, 17]:
        blotch += np.sin(xs / size * math.pi * 2 * f + rng.random() * 6) * np.sin(ys / size * math.pi * 2 * f * 0.8 + rng.random() * 6)
    blotch = blotch / 3.0
    fib = np.clip((acc - 0.5) * 3.2 + 0.5 + blotch * 0.08, 0, 1)
    base = np.array([0.97, 0.78, 0.26], dtype=np.float32)
    tip = np.array([1.0, 0.9, 0.5], dtype=np.float32)
    col = base[None, None, :] * (0.8 + 0.2 * fib[..., None])
    col = col * (1 - fib[..., None] * 0.3) + tip * fib[..., None] * 0.3
    alpha = np.ones((size, size), dtype=np.float32)
    if normal_path:
        h = acc
        dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 3.0
        dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 3.0
        n = np.dstack([-dx, -dy, np.ones_like(h)])
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        nim = bpy.data.images.new(os.path.basename(normal_path).split(".")[0], size, size, alpha=False)
        nim.colorspace_settings.name = "Non-Color"
        nim.pixels = np.dstack([n * 0.5 + 0.5, np.ones_like(h)]).ravel()
        nim.filepath_raw = normal_path
        nim.file_format = "PNG"
        nim.save()
    out = np.dstack([col, alpha])
    im = bpy.data.images.new(os.path.basename(path).split(".")[0], size, size, alpha=True)
    im.pixels = out.ravel()
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    return im


def material(name, color=None, image=None, rough=0.8, clip=False, spec=0.3, normal=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    if normal:
        nt = m.node_tree.nodes.new("ShaderNodeTexImage")
        nt.image = normal
        nm = m.node_tree.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 0.6
        m.node_tree.links.new(nt.outputs["Color"], nm.inputs["Color"])
        m.node_tree.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = image
        m.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        if clip:
            m.node_tree.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
            m.blend_method = "CLIP"
    if color:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = spec
    return m


# --- Geometry ----------------------------------------------------------------------------

def sphere_uv(bm, uvl, center):
    for f in bm.faces:
        for loop in f.loops:
            d = (loop.vert.co - center).normalized()
            u = math.atan2(d.x, -d.y) / (2 * math.pi) + 0.5
            v = math.acos(max(-1.0, min(1.0, d.z))) / math.pi
            loop[uvl].uv = (u * 0.999, v)


def tufts(p, amount, seed):
    """Radial jitter over a unit sphere: soft uneven tufts of down."""
    n = (math.sin(p.x * 9.0 + seed) * math.sin(p.y * 11.0 + seed * 1.7) * math.sin(p.z * 8.0 + seed * 0.6)
         + 0.5 * math.sin(p.x * 23.0 + p.z * 17.0 + seed) * math.sin(p.y * 19.0 - seed))
    return p * (1.0 + amount * n)


def ellipsoid(bm, center, radii, segs=24, rings=16, warp=None, tuft=0.0, seed=0.0):
    ret = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    verts = ret["verts"]
    for v in verts:
        p = v.co.copy()
        if tuft > 0.0:
            p = tufts(p, tuft, seed)
        if warp:
            p = warp(p)
        v.co = center + mathutils.Vector((p.x * radii.x, p.y * radii.y, p.z * radii.z))
    return verts


def body_warp(p):
    # Fuller at the breast, a little pointed tail tuft at the back, a flat underside.
    q = p.copy()
    if q.y > 0.3:
        q.z += (q.y - 0.3) * 0.35
        q.x *= 1.0 - (q.y - 0.3) * 0.35
    if q.z < -0.55:
        q.z = -0.55 + (q.z + 0.55) * 0.5
    return q


def build_mesh(name, parts, mats):
    """parts: list of (builder(bm) -> verts, material index, bone name, uv center or None)."""
    me = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for m in mats:
        me.materials.append(m)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    groups = {}
    for build, mi, bone, uvc in parts:
        before = set(bm.faces)
        verts = build(bm)
        faces = [f for f in bm.faces if f not in before]
        for f in faces:
            f.material_index = mi
            f.smooth = True
        if uvc is not None:
            sub = bmesh.new()
            for f in faces:
                for loop in f.loops:
                    d = (loop.vert.co - uvc).normalized()
                    u = math.atan2(d.x, -d.y) / (2 * math.pi) + 0.5
                    v = math.acos(max(-1.0, min(1.0, d.z))) / math.pi
                    loop[uvl].uv = (u * 0.999, v)
            sub.free()
        groups.setdefault(bone, []).extend(v.index if v.is_valid else -1 for v in verts)
        bm.verts.index_update()
        groups[bone] = [v for v in groups[bone]]
        groups.setdefault("_verts_" + bone, []).extend(verts)
    bm.verts.index_update()
    bm.to_mesh(me)
    idx = {}
    for key, vs in groups.items():
        if key.startswith("_verts_"):
            idx[key[7:]] = [v.index for v in vs]
    bm.free()
    for bone, ids in idx.items():
        vg = obj.vertex_groups.new(name=bone)
        vg.add(ids, 1.0, "REPLACE")
    return obj


def cone(bm, base, tip, r, segs=10):
    d = tip - base
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=segs, radius1=r, radius2=0.0004,
            depth=d.length)
    rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=mathutils.Matrix.Translation((base + tip) * 0.5) @ rot, verts=ret["verts"])
    return ret["verts"]


def rod(bm, a, b, r0, r1, segs=6):
    d = b - a
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r0, radius2=r1, depth=d.length)
    rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=mathutils.Matrix.Translation((a + b) * 0.5) @ rot, verts=ret["verts"])
    return ret["verts"]


def leg_parts(side):
    x = LEG_X * side
    knee = mathutils.Vector((x, 0.006, HIP_Z - 0.012))
    ankle = mathutils.Vector((x, 0.002, FOOT_Z + 0.004))
    shank = lambda bm: rod(bm, knee + mathutils.Vector((0, 0, 0.004)), ankle, 0.0033, 0.0027)

    def toes(bm):
        vs = []
        for ang in (-28.0, 0.0, 28.0):
            a = math.radians(ang)
            d = mathutils.Vector((math.sin(a) * side * -1.0 * -1.0, -math.cos(a), 0.0))
            vs += rod(bm, ankle + mathutils.Vector((0, 0, -0.002)), ankle + d * 0.017 + mathutils.Vector((0, 0, -0.0035)), 0.002, 0.0011, 5)
        vs += rod(bm, ankle + mathutils.Vector((0, 0, -0.002)), ankle + mathutils.Vector((0, 0.008, -0.0035)), 0.0018, 0.001, 5)
        return vs
    s = "l" if side < 0 else "r"
    return [(shank, 2, "shank_" + s, None), (toes, 2, "foot_" + s, None)]


def build():
    down = down_texture(os.path.join(TEX_DIR, "chick_down.png"), normal_path=os.path.join(TEX_DIR, "chick_down_normal.png"))
    normal = bpy.data.images["chick_down_normal"]
    m_down = material("chick_down", image=down, rough=0.95, spec=0.15, normal=normal)
    m_eye = material("chick_eye", color=(0.01, 0.01, 0.012), rough=0.08, spec=0.9)
    m_beak = material("chick_beak", color=(0.93, 0.58, 0.28), rough=0.45, spec=0.45)
    mats = [m_down, m_eye, m_beak]
    V = mathutils.Vector
    neck_c = V((0.0, -0.02, 0.068))
    wing = V((0.0045, 0.019, 0.012))
    eye_r = V((0.0048, 0.0048, 0.0052))
    parts = [
        (lambda bm: ellipsoid(bm, BODY_C, BODY_R, 32, 20, warp=body_warp, tuft=0.035, seed=1.0), 0, "body", BODY_C),
        # The neck, so the head sits in the down rather than on top of the body.
        (lambda bm: ellipsoid(bm, neck_c, V((0.019, 0.019, 0.017)), 20, 12, tuft=0.03, seed=2.0), 0, "neck", neck_c),
        (lambda bm: ellipsoid(bm, HEAD_C, V((HEAD_R, HEAD_R * 1.05, HEAD_R)), 28, 18, tuft=0.025, seed=3.0), 0, "head", HEAD_C),
        # Stubby wings held against the sides.
        (lambda bm: ellipsoid(bm, V((-0.0285, 0.008, 0.05)), wing, 12, 8, tuft=0.05, seed=4.0), 0, "wing_l", V((-0.0285, 0.008, 0.05))),
        (lambda bm: ellipsoid(bm, V((0.0285, 0.008, 0.05)), wing, 12, 8, tuft=0.05, seed=5.0), 0, "wing_r", V((0.0285, 0.008, 0.05))),
        # Eyes (bright, beady, standing out of the down) and the beak.
        (lambda bm: ellipsoid(bm, HEAD_C + V((-0.0165, -0.0165, 0.006)), eye_r, 12, 8), 1, "head", None),
        (lambda bm: ellipsoid(bm, HEAD_C + V((0.0165, -0.0165, 0.006)), eye_r, 12, 8), 1, "head", None),
        (lambda bm: cone(bm, HEAD_C + V((0, -0.02, -0.002)), HEAD_C + V((0, -0.035, -0.006)), 0.0055), 2, "head", None),
    ] + leg_parts(-1.0) + leg_parts(1.0)
    obj = build_mesh("Chick", parts, mats)
    return obj


def build_armature(mesh_obj):
    arm_data = bpy.data.armatures.new("ChickRig")
    arm = bpy.data.objects.new("ChickRig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def bone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = eb[parent]
        return b
    V = mathutils.Vector
    bone("root", V((0, 0.004, HIP_Z)), V((0, 0.004, HIP_Z + 0.01)))
    bone("body", BODY_C, BODY_C + V((0, -0.015, 0.005)), "root")
    bone("neck", V((0, -0.022, 0.068)), V((0, -0.027, 0.078)), "body")
    bone("head", V((0, -0.028, 0.08)), V((0, -0.036, 0.1)), "neck")
    bone("wing_l", V((-0.026, -0.006, 0.058)), V((-0.03, 0.02, 0.05)), "body")
    bone("wing_r", V((0.026, -0.006, 0.058)), V((0.03, 0.02, 0.05)), "body")
    bone("tail", BODY_C + V((0, 0.03, 0.01)), BODY_C + V((0, 0.045, 0.016)), "body")
    for side, s in ((-1.0, "l"), (1.0, "r")):
        x = LEG_X * side
        bone("thigh_" + s, V((x, 0.006, HIP_Z)), V((x, 0.006, HIP_Z - 0.008)), "root")
        bone("shank_" + s, V((x, 0.006, HIP_Z - 0.008)), V((x, 0.002, FOOT_Z + 0.004)), "thigh_" + s)
        bone("foot_" + s, V((x, 0.002, FOOT_Z + 0.004)), V((x, -0.012, FOOT_Z)), "shank_" + s)
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh_obj.parent = arm
    mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return arm


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    os.makedirs(TEX_DIR, exist_ok=True)
    mesh = build()
    arm = build_armature(mesh)
    if "preview" in a:
        sys.path.append(os.path.dirname(__file__))
        import render_prev
        c = (0.0, 0.0, 0.055)
        render_prev.render(render_prev.cam("side", (0.3, 0.0, 0.07), c, up=(0, 0, 1)), a["preview"] + "/chick_side.png")
        render_prev.render(render_prev.cam("front", (0.16, -0.22, 0.12), c, up=(0, 0, 1)), a["preview"] + "/chick_front.png")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, "scene.gltf"), export_format="GLTF_SEPARATE",
            export_texture_dir="textures", export_animations=False, export_skins=True, export_yup=True)
    stamp_gltf(os.path.join(OUT_DIR, "scene.gltf"))
    print("CHICK EXPORTED")


def stamp_gltf(path):
    """Writes the buffer's hash into the glTF: Godot reimports a model when its .gltf
    changes, not when only its .bin does."""
    import hashlib
    import json
    d = json.load(open(path))
    data = open(os.path.join(os.path.dirname(path), d["buffers"][0]["uri"]), "rb").read()
    d.setdefault("asset", {}).setdefault("extras", {})["bin_md5"] = hashlib.md5(data).hexdigest()
    with open(path, "w") as f:
        json.dump(d, f, indent=1)


if __name__ == "__main__":
    main()
