"""Builds Karamel, Zeynep's dog, into art/models/animals/dog/ (DogRig drives it in game).

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_dog.py [-- --preview=/abs/dir] [--shape]
    --preview=DIR  renders of the result (side, front, back, top, head), joints marked
    --shape        only the reshaped body, its joints and previews (no textures, no export)

Source: "Dog" by Yury Misiyuk (Tim0) on Sketchfab, CC-BY-4.0 (see the folder's
CREDITS.md), kept as art/models/animals/dog/source/dog_source.glb (Godot ignores the
folder). A young Labrador-type dog modelled in inches, its left and right halves apart
along the back and its ears separate flaps. Here it is:
  - welded along the back, turned to face +Y (glTF: -Z), grown up a little (lower legs
    lengthened, the head a touch smaller, the tail longer) and scaled to a dog of 56 cm
    at the withers standing on z = 0, centred between its feet;
  - skinned to a skeleton DogRig drives by these names: root (the hips' pivot), pelvis,
    spine1, spine2, neck1, neck2, head, jaw, ear_l/ear_l2, ear_r/ear_r2, tail1-tail4, and
    per leg (l = the dog's left, -X) f?_sh (shoulder blade), f?_up, f?_lo, f?_ft,
    f?_toe and r?_up, r?_lo, r?_ft, r?_toe (the toe bones run along the paw), and markers
    without weights: ??_tip (a paw's tip), nose (its tip) and pet (the spot on the back,
    behind the withers, a stroking hand goes to);
  - recoloured from its cream-and-tan coat to a warm caramel (darker along the back and
    on the ears, cream under the chest, belly and tail), keeping the painted hair, the
    nose, eyes and pads; a normal map from the hair strokes and a roughness map (wet
    nose, glossy eyes) are made from it;
  - given shell fur: a second, lighter mesh of FUR_LAYERS stacked copies (UV2.x the
    layer, UV2.y the fur's length over FUR_MAX) the game pushes out along the normals.
"""
import hashlib
import json
import math
import os
import sys

import bmesh
import bpy
import mathutils
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art/models/animals/dog")
SRC = os.path.join(OUT_DIR, "source", "dog_source.glb")
TEX_DIR = os.path.join(OUT_DIR, "textures")

## Withers height of the finished dog, metres.
WITHERS = 0.56
## Source units: the withers' height before reshaping, the lower legs' span that is
## lengthened (z from, z to) and by how much, the head's scale about its pivot (blended in
## over the neck from y0 to y1), the tail's lengthening.
SRC_WITHERS = 18.0
LEG_SPAN = (1.5, 7.0)
LEG_GROW = 0.16
HEAD_PIVOT = np.array([0.0, 11.0, 19.4])
HEAD_SCALE = 0.92
HEAD_BLEND = (9.6, 12.0)
TAIL_BASE = np.array([0.0, -11.2, 16.7])
TAIL_TIP = np.array([0.0, -16.3, 21.6])
TAIL_GROW = 1.45
TEX_SIZE = 1024
FUR_TRIS = 7000
FUR_LAYERS = 14
## Longest fur (m): UV2.y is the fur length over this.
FUR_MAX = 0.02


def args():
    out = {}
    if "--" in sys.argv:
        for a in sys.argv[sys.argv.index("--") + 1:]:
            if a.startswith("--"):
                k, _, v = a[2:].partition("=")
                out[k] = v if v else True
    return out


def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def apply_modifiers(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)


# --- Source and shape ---------------------------------------------------------------------------

def load_source():
    """The source mesh in its own units, turned to face +Y, the halves welded; returns
    (object, per-vertex part: 0 body, 1 left ear, 2 right ear)."""
    bpy.ops.import_scene.gltf(filepath=SRC)
    src = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    me = src.data.copy()
    me.transform(src.matrix_world)
    # Nose from -X to +Y: (x, y) -> (y, -x); the dog's right side ends up on +X.
    me.transform(mathutils.Matrix.Rotation(-math.pi * 0.5, 4, "Z"))
    for o in list(bpy.context.scene.objects):
        bpy.data.objects.remove(o)
    me.name = "Body"
    obj = bpy.data.objects.new("Body", me)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(me)
    seam = [v for v in bm.verts if abs(v.co.x) < 0.02]
    bmesh.ops.remove_doubles(bm, verts=seam, dist=0.02)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    # Parts: the ears are loose flaps beside the head.
    n = len(me.vertices)
    parent = np.arange(n)

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    ev = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", ev)
    for a, b in ev.reshape(-1, 2):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    roots = np.array([find(i) for i in range(n)])
    co = vertices(obj)
    part = np.zeros(n, dtype=np.int64)
    sizes = {r: np.count_nonzero(roots == r) for r in np.unique(roots)}
    for r, s in sizes.items():
        if s < n * 0.2:
            m = roots == r
            part[m] = 1 if co[m, 0].mean() < 0 else 2
    print("source: %d verts, %d faces, ear verts %d/%d" % (n, len(me.polygons), np.count_nonzero(part == 1), np.count_nonzero(part == 2)))
    return obj, part


def vertices(obj):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def set_vertices(obj, co):
    obj.data.vertices.foreach_set("co", co.astype(np.float64).ravel())
    obj.data.update()


def tail_frame():
    d = TAIL_TIP - TAIL_BASE
    return d / np.linalg.norm(d), np.linalg.norm(d)


def grow(P, part=None):
    """The young dog grown up (source units, facing +Y): a longer tail, a smaller head,
    longer lower legs."""
    P = np.array(P, dtype=np.float64).reshape(-1, 3)
    body = np.ones(len(P), dtype=bool) if part is None else part == 0
    # Tail: points past its base along its axis, near the axis, are carried out.
    d, length = tail_frame()
    rel = P - TAIL_BASE
    t = rel @ d
    radial = np.linalg.norm(rel - t[:, None] * d, axis=1)
    near = (t > -0.3) & (radial < 2.4) & body & (P[:, 1] < -10.4)
    w = smoothstep(0.0, 1.2, t) * near
    P = P + (d[None, :] * (np.maximum(t, 0.0) * (TAIL_GROW - 1.0) * w)[:, None])
    # Head: scaled about its pivot, blended in over the neck; the ears go with it.
    hw = smoothstep(HEAD_BLEND[0], HEAD_BLEND[1], P[:, 1])
    if part is not None:
        hw = np.where(part > 0, 1.0, hw)
    s = 1.0 - (1.0 - HEAD_SCALE) * hw
    P = HEAD_PIVOT + (P - HEAD_PIVOT) * s[:, None]
    # Legs: the span between the paws and the elbows/stifles stretched.
    z = P[:, 2]
    P[:, 2] = z + LEG_GROW * np.clip(z - LEG_SPAN[0], 0.0, LEG_SPAN[1] - LEG_SPAN[0])
    return P


## The finished dog: metres, on z = 0, centred between its feet.
SCALE = WITHERS / (SRC_WITHERS + LEG_GROW * (LEG_SPAN[1] - LEG_SPAN[0]))
CENTRE = np.array([0.0, -1.2, -0.12])


def to_metres(P):
    return (np.asarray(P, dtype=np.float64) - CENTRE) * SCALE


def shape(P, part=None):
    return to_metres(grow(P, part))


# --- Skeleton -----------------------------------------------------------------------------------

def ear_chain(co, part, which):
    """Root, middle and tip of an ear flap (source units): its top edge where it hangs from
    the head, down to its lowest point."""
    E = co[part == which]
    top = E[E[:, 2] > E[:, 2].max() - 0.8].mean(0)
    tip = E[E[:, 2] < E[:, 2].min() + 0.8].mean(0)
    mid = E[np.abs(E[:, 2] - (top[2] + tip[2]) * 0.5) < 0.5].mean(0)
    return top, mid, tip


def tail_chain(co, part):
    """Five points along the tail's centre line (source units, before growing)."""
    d, length = tail_frame()
    rel = co - TAIL_BASE
    t = rel @ d
    radial = np.linalg.norm(rel - t[:, None] * d, axis=1)
    m = (part == 0) & (radial < 2.4) & (co[:, 1] < -10.4)
    pts = []
    for k in range(5):
        s = length * k / 4.0
        sel = co[m & (np.abs(t - s) < 0.45)]
        pts.append(sel.mean(0) if len(sel) else TAIL_BASE + d * s)
    pts[0] = TAIL_BASE
    return pts


def bone_specs(co, part):
    """(name, head, tail, parent) in source units (facing +Y, before growing)."""
    B = [
        ("root", (0, -8.8, 14.4), (0, -8.8, 15.6), None),
        ("pelvis", (0, -8.8, 14.4), (0, -11.3, 15.2), "root"),
        ("spine1", (0, -8.8, 14.4), (0, -2.0, 14.0), "root"),
        ("spine2", (0, -2.0, 14.0), (0, 4.4, 14.9), "spine1"),
        ("neck1", (0, 4.4, 14.9), (0, 7.9, 17.2), "spine2"),
        ("neck2", (0, 7.9, 17.2), (0, 11.0, 19.4), "neck1"),
        ("head", (0, 11.0, 19.4), (0, 19.9, 19.9), "neck2"),
        ("jaw", (0, 12.6, 18.2), (0, 18.9, 18.4), "head"),
    ]
    t = tail_chain(co, part)
    for k in range(4):
        B.append(("tail%d" % (k + 1), tuple(t[k]), tuple(t[k + 1]), "pelvis" if k == 0 else "tail%d" % k))
    for which, n in ((1, "l"), (2, "r")):
        top, mid, tip = ear_chain(co, part, which)
        B.append(("ear_" + n, tuple(top), tuple(mid), "head"))
        B.append(("ear_%s2" % n, tuple(mid), tuple(tip), "ear_" + n))
    for sx, n in ((-1.0, "l"), (1.0, "r")):
        B += [
            ("f%s_sh" % n, (sx * 2.0, 3.6, 16.0), (sx * 2.6, 7.9, 11.3), "spine2"),
            ("f%s_up" % n, (sx * 2.6, 7.9, 11.3), (sx * 2.35, 5.2, 7.2), "f%s_sh" % n),
            ("f%s_lo" % n, (sx * 2.35, 5.2, 7.2), (sx * 2.5, 6.2, 2.3), "f%s_up" % n),
            ("f%s_ft" % n, (sx * 2.5, 6.2, 2.3), (sx * 2.55, 6.9, 0.85), "f%s_lo" % n),
            ("f%s_toe" % n, (sx * 2.55, 6.9, 0.85), (sx * 2.55, 8.95, 0.45), "f%s_ft" % n),
            ("r%s_up" % n, (sx * 2.15, -9.3, 12.3), (sx * 2.2, -6.9, 8.0), "pelvis"),
            ("r%s_lo" % n, (sx * 2.2, -6.9, 8.0), (sx * 1.9, -10.9, 4.7), "r%s_up" % n),
            ("r%s_ft" % n, (sx * 1.9, -10.9, 4.7), (sx * 1.9, -10.0, 0.95), "r%s_lo" % n),
            ("r%s_toe" % n, (sx * 1.9, -10.0, 0.95), (sx * 1.9, -7.8, 0.45), "r%s_ft" % n),
        ]
    # Markers without weights: the paws' tips, the nose tip, the spot on the back a
    # stroking hand goes to.
    for n in ("fl", "fr", "rl", "rr"):
        toe = [b for b in B if b[0] == n + "_toe"][0]
        tip = np.asarray(toe[2], float)
        B.append((n + "_tip", tuple(tip), tuple(tip + np.array([0.0, 0.5, 0.0])), n + "_toe"))
    B.append(("nose", (0, 19.9, 20.2), (0, 20.4, 20.2), "head"))
    B.append(("pet", (0, 2.0, 17.25), (0, 2.0, 17.75), "spine2"))
    return B


def build_armature(specs):
    arm_data = bpy.data.armatures.new("Skeleton")
    arm = bpy.data.objects.new("Skeleton", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for name, head, tail, parent in specs:
        b = eb.new(name)
        b.head = tuple(shape(head)[0])
        b.tail = tuple(shape(tail)[0])
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


# --- Skinning ------------------------------------------------------------------------------------

## Bones that carry no weight: the hips' pivot and the markers.
MARKERS = ("root", "nose", "pet")
## Flesh radius around each bone (source units): how far its pull reaches.
RADIUS = {"root": 3.0, "pelvis": 3.4, "spine1": 4.0, "spine2": 4.4, "neck1": 3.2, "neck2": 3.0, "head": 3.0,
          "jaw": 1.2, "sh": 2.2, "f_up": 1.7, "f_lo": 1.0, "f_ft": 0.8, "f_toe": 0.9, "r_up": 2.3, "r_lo": 1.4,
          "r_ft": 0.8, "r_toe": 0.9, "tail": 0.9}


def _radius(name):
    if name in RADIUS:
        return RADIUS[name]
    if name.startswith("tail"):
        return RADIUS["tail"]
    if name[0] in "fr" and name[2] == "_":
        return RADIUS.get(name[0] + name[2:], RADIUS["sh"])
    return 1.0


def _seg_dist(P, a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1), t


def skin_weights(co, part, specs, adjacency):
    """Per-vertex weights (N x bones) in the source frame: each bone pulls the flesh
    around it (distance over its flesh radius), legs only on their own side and not over
    the chest's or belly's middle, the tail only behind the rump, the jaw only under the
    mouth line; ears follow their own bones; smoothed over the surface; four strongest."""
    names = [s[0] for s in specs]
    n = len(co)
    W = np.zeros((n, len(names)))
    body = part == 0
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    d_tail, _ = tail_frame()
    t_tail = (co - TAIL_BASE) @ d_tail
    for j, (name, a, b, parent) in enumerate(specs):
        if name in MARKERS or name.endswith("_tip") or name.startswith("ear_"):
            continue
        d, t = _seg_dist(co, a, b)
        w = 1.0 / (0.02 + (d / _radius(name)) ** 4)
        if name[0] in "fr" and len(name) > 2 and name[2] == "_":
            sx = -1.0 if name[1] == "l" else 1.0
            side = smoothstep(0.35, 1.3, x * sx)
            if name.startswith("f"):
                # The foreleg's reach ends at the chest wall and the shoulder.
                keep = side * (1.0 - smoothstep(9.2, 11.8, z) * (name != "fl_sh" and name != "fr_sh"))
            else:
                keep = side
            w = w * keep
        elif name.startswith("tail"):
            w = w * smoothstep(-0.6, 0.4, t_tail) * (y < -10.0)
        elif name == "jaw":
            mouth = 18.95 + (y - 14.0) * 0.07
            w = w * smoothstep(0.35, -0.25, z - mouth) * smoothstep(13.2, 14.6, y) * (np.abs(x) < 2.6)
        W[:, j] = w * body
    # Ears: along their two bones, the root with the head.
    head = names.index("head")
    for which, s in ((1, "l"), (2, "r")):
        m = part == which
        i1, i2 = names.index("ear_" + s), names.index("ear_%s2" % s)
        top = np.asarray(specs[i1][1], float)
        tip = np.asarray(specs[i2][2], float)
        u = np.clip(((co[m] - top) @ (tip - top)) / max(np.sum((tip - top) ** 2), 1e-9), 0, 1)
        W[m] = 0.0
        hb = smoothstep(0.12, 0.0, u)
        t2 = smoothstep(0.3, 0.7, u)
        W[m, head] = hb
        W[m, i1] = (1 - hb) * (1 - t2)
        W[m, i2] = (1 - hb) * t2
    W /= np.maximum(W.sum(1, keepdims=True), 1e-12)
    # Smoothed over the surface (the body; the ears are set).
    nb = adjacency
    for it in range(6):
        acc = np.zeros_like(W)
        cnt = np.zeros(n)
        np.add.at(acc, nb[:, 0], W[nb[:, 1]])
        np.add.at(acc, nb[:, 1], W[nb[:, 0]])
        np.add.at(cnt, nb[:, 0], 1)
        np.add.at(cnt, nb[:, 1], 1)
        avg = acc / np.maximum(cnt[:, None], 1)
        W = np.where(body[:, None], W * 0.5 + avg * 0.5, W)
    idx = np.argsort(-W, axis=1)[:, 4:]
    np.put_along_axis(W, idx, 0.0, axis=1)
    W[W < 0.01] = 0.0
    W /= np.maximum(W.sum(1, keepdims=True), 1e-12)
    return W


def set_weights(obj, W, names):
    for name in names:
        if name not in obj.vertex_groups:
            obj.vertex_groups.new(name=name)
    for j, name in enumerate(names):
        vg = obj.vertex_groups[name]
        nz = np.nonzero(W[:, j] > 1e-4)[0]
        for i in nz:
            vg.add([int(i)], float(W[i, j]), "REPLACE")


def edges(obj):
    ev = np.empty(len(obj.data.edges) * 2, dtype=np.int64)
    obj.data.edges.foreach_get("vertices", ev)
    return ev.reshape(-1, 2)


# --- Coat ------------------------------------------------------------------------------------------

def bake_position(obj, size, attribute=""):
    """Object-space position of every texel (NaN where the mesh has none), or with
    `attribute` that colour attribute's value there."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.margin = 6
    sc.render.bake.use_clear = True
    mats = list(obj.data.materials)
    mat = bpy.data.materials.new("bake")
    mat.use_nodes = True
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    nt = mat.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    img = bpy.data.images.new("bake_pos", size, size, alpha=True, float_buffer=True)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    em = nt.nodes.new("ShaderNodeEmission")
    if attribute:
        g = nt.nodes.new("ShaderNodeAttribute")
        g.attribute_name = attribute
        nt.links.new(g.outputs["Color"], em.inputs[0])
    else:
        g = nt.nodes.new("ShaderNodeNewGeometry")
        nt.links.new(g.outputs["Position"], em.inputs[0])
    nt.links.new(em.outputs[0], o.inputs[0])
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT")
    a = np.empty(size * size * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    a = a.reshape(size, size, 4)
    obj.data.materials.clear()
    for m in mats:
        obj.data.materials.append(m)
    bpy.data.materials.remove(mat)
    pos = a[..., :3].astype(np.float64)
    pos[a[..., 3] < 0.5] = np.nan
    return pos


def blur(img, r):
    """Box blur (three passes ~ gaussian), edges clamped; img HxW or HxWxC."""
    out = img.astype(np.float64)
    for _ in range(3):
        for axis in (0, 1):
            pad = [(0, 0)] * out.ndim
            pad[axis] = (r, r)
            p = np.pad(out, pad, mode="edge")
            c = np.cumsum(p, axis=axis)
            c = np.concatenate([np.zeros_like(np.take(c, [0], axis=axis)), c], axis=axis)
            hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
            out = (hi - lo) / (2 * r + 1)
    return out


def image_pixels(name):
    im = bpy.data.images[name]
    w, h = im.size
    a = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    return a.reshape(h, w, 4).astype(np.float64)


def save_png(pixels, path, alpha=False, non_color=False):
    h, w = pixels.shape[:2]
    im = bpy.data.images.new(os.path.basename(path).split(".")[0], w, h, alpha=alpha)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    px = np.ones((h, w, 4), dtype=np.float32)
    px[..., :pixels.shape[2]] = pixels
    im.pixels.foreach_set(px.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    return im


def C(r, g, b):
    return np.array([r, g, b], dtype=np.float64)


def coat_colour(P):
    """The caramel coat by where a texel is on the dog (source units, facing +Y, sRGB):
    darker along the back, the top of the neck and on the ears, cream under the chest,
    belly, inside the legs and under the tail, a lighter muzzle and feet."""
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    base = C(0.74, 0.5, 0.26)
    col = np.broadcast_to(base, P.shape).copy()
    # The top line darker (a saddle down the back and the top of the neck and tail).
    back = smoothstep(12.5, 17.5, z) * (1.0 - smoothstep(11.0, 13.0, y)) * smoothstep(1.2, 0.0, np.abs(x) - 1.6)
    col = col * (1 - 0.3 * back[..., None]) + C(0.54, 0.32, 0.14) * (0.3 * back[..., None])
    # Underside: chest front, belly, the inside of the legs, the throat, under the tail.
    under = smoothstep(9.5, 6.8, z) * smoothstep(-8.0, -5.0, y) * smoothstep(2.2, 0.8, np.abs(x))
    chest = smoothstep(7.0, 9.5, y) * smoothstep(15.5, 11.0, z) * smoothstep(2.6, 1.0, np.abs(x))
    throat = smoothstep(9.5, 12.0, y) * smoothstep(17.8, 15.5, z) * smoothstep(2.0, 0.6, np.abs(x))
    inner = smoothstep(9.0, 3.0, z) * smoothstep(1.9, 1.2, np.abs(x)) * 0.8
    ttail = smoothstep(-11.0, -13.0, y) * smoothstep(0.2, -0.6, z - (17.0 + (-11.0 - y) * 0.9))
    cream = np.clip(np.maximum.reduce([under, chest, throat, inner, ttail]), 0, 1)
    col = col * (1 - cream[..., None]) + C(0.9, 0.74, 0.52) * cream[..., None]
    # Muzzle a little lighter, feet lighter.
    muzzle = smoothstep(15.0, 17.5, y) * smoothstep(20.5, 18.5, z)
    col = col * (1 - 0.45 * muzzle[..., None]) + C(0.8, 0.6, 0.38) * (0.45 * muzzle[..., None])
    feet = smoothstep(2.2, 0.6, z)
    col = col * (1 - 0.5 * feet[..., None]) + C(0.84, 0.66, 0.44) * (0.5 * feet[..., None])
    return col


def masked_blur(img, mask, r):
    """Blur over the texels in `mask` only (the black around the UV islands left out)."""
    m = mask.astype(np.float64)
    num = blur(img * (m if img.ndim == 2 else m[..., None]), r)
    den = blur(m, r)
    den = den if img.ndim == 2 else den[..., None]
    return num / np.maximum(den, 1e-6)


def coat_maps(obj, part):
    """Albedo, normal and roughness maps from the source texture, recoloured to caramel."""
    src = image_pixels("Image_0")[..., :3]
    size = src.shape[0]
    pos = bake_position(obj, size)
    has = ~np.isnan(pos[..., 0])
    info = obj.data.attributes.new("part_info", "FLOAT_COLOR", "POINT")
    pc = np.zeros((len(part), 4), dtype=np.float32)
    pc[:, 0] = part > 0
    info.data.foreach_set("color", pc.ravel())
    is_ear = np.nan_to_num(bake_position(obj, size, "part_info")[..., 0]) > 0.5
    obj.data.attributes.remove(obj.data.attributes["part_info"])
    island = src.max(-1) > 0.02
    L = src @ np.array([0.299, 0.587, 0.114])
    Lb = masked_blur(L, island, 6)
    # The painted hair: fine light and dark strokes over the smooth colour.
    detail = np.clip(L / np.maximum(Lb, 0.05), 0.55, 1.6)
    detail = np.where(island, detail, 1.0)
    # The source's broad shading and patches, softened.
    Lbb = masked_blur(L, island, 24)
    broad = np.clip(Lbb / np.mean(Lbb[island & has]), 0.75, 1.2)
    P = np.where(has[..., None], pos, 0.0)
    y, z, ax = P[..., 1], P[..., 2], np.abs(P[..., 0])
    col = coat_colour(P)
    col = col * (detail ** 1.1)[..., None] * (0.74 + 0.26 * broad)[..., None]
    # Features kept from the source: the black nose, eyes and lips, the pads and claws,
    # the pink inside of the ears (a little warmer).
    face = smoothstep(12.8, 13.8, y)
    feet = smoothstep(1.6, 0.9, z)
    dark = smoothstep(0.26, 0.12, L) * np.maximum(face, feet)
    sat = src.max(-1) - src.min(-1)
    pink = smoothstep(0.08, 0.16, src[..., 0] - src[..., 2]) * smoothstep(0.45, 0.6, src[..., 0]) * (sat > 0.12)
    ear_inner = pink * is_ear
    keep = np.clip(np.maximum(dark, ear_inner * 0.8), 0, 1)
    warm = src * C(1.0, 0.94, 0.86)
    col = col * (1 - keep[..., None]) + warm * keep[..., None]
    col = np.clip(col, 0, 1)
    col[~has] = C(0.7, 0.5, 0.28)
    # Normal map: the hair strokes as a height field (dark grooves, light crests).
    hgt = blur(np.where(island, L - Lb, 0.0), 1)
    gy, gx = np.gradient(hgt)
    strength = 5.0
    nx, ny = -gx * strength, -gy * strength
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)
    # Roughness (G, glTF metallic-roughness): hair, a wet nose, glossy eyes.
    eye = dark * smoothstep(13.5, 14.5, y) * smoothstep(17.3, 17.0, y) * smoothstep(19.0, 20.0, z) * smoothstep(0.6, 1.2, ax)
    nose = dark * smoothstep(18.6, 19.4, y) * smoothstep(19.4, 20.0, z)
    rough = 0.78 + 0.12 * (1.0 - np.clip(detail - 0.6, 0, 1))
    rough = rough * (1 - eye) + 0.08 * eye
    rough = rough * (1 - nose) + 0.4 * nose
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], axis=-1)
    os.makedirs(TEX_DIR, exist_ok=True)
    # Blender images are stored bottom row first, as read.
    a = save_png(col, os.path.join(TEX_DIR, "dog_albedo.png"))
    nm = save_png(nrm, os.path.join(TEX_DIR, "dog_normal.png"), non_color=True)
    r = save_png(orm, os.path.join(TEX_DIR, "dog_orm.png"), non_color=True)
    return a, nm, r, pos, dark, eye, nose


def material(albedo, normal, orm):
    m = bpy.data.materials.new("dog_coat")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = albedo
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = normal
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 0.6
    nt.links.new(tn.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    tr = nt.nodes.new("ShaderNodeTexImage")
    tr.image = orm
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tr.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    return m


# --- Shell fur -------------------------------------------------------------------------------------

def fur_length(P, part):
    """Fur length (m) by where a vertex is (source units): a short, close coat on the body
    and legs, barely any on the face and none on the muzzle and paws, a little longer on
    the chest, the backs of the forelegs, the thighs and the tail; the ears soft and short."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    L = np.full(len(P), 0.0055)
    head = smoothstep(10.5, 12.5, y)
    L = L * (1 - head) + 0.0025 * head
    muzzle = smoothstep(14.5, 16.0, y)
    L = L * (1 - muzzle)
    legs = smoothstep(6.5, 3.0, z)
    L = L * (1 - legs) + 0.003 * legs
    paws = smoothstep(1.8, 0.9, z)
    L = L * (1 - paws)
    chest = smoothstep(6.0, 9.0, y) * smoothstep(14.0, 10.0, z) * (y < 11.0)
    L = np.maximum(L, 0.011 * chest)
    # Feathering at the backs of the forelegs (elbow to carpus) and the thighs.
    fore_back = smoothstep(3.0, 6.5, z) * smoothstep(8.0, 7.0, z) * smoothstep(5.8, 4.8, y) * smoothstep(3.2, 6.0, y)
    L = np.maximum(L, 0.009 * fore_back)
    breeches = smoothstep(-8.5, -11.0, y) * smoothstep(5.0, 8.0, z) * smoothstep(14.5, 11.0, z)
    L = np.maximum(L, 0.012 * breeches)
    d, _ = tail_frame()
    t = (P - TAIL_BASE) @ d
    tail = smoothstep(-0.5, 0.5, t) * (y < -10.4)
    L = L * (1 - tail) + 0.016 * tail
    ears = part > 0
    L[ears] = 0.003
    return L


def build_fur(body, part, dark_v):
    """FUR_LAYERS copies of a lighter body; UV2 = (layer / FUR_LAYERS, length / FUR_MAX)."""
    src = body.copy()
    src.data = body.data.copy()
    src.modifiers.clear()
    bpy.context.scene.collection.objects.link(src)
    # The part and the dark features ride along as attributes through the decimation.
    me = src.data
    a = me.attributes.new("fur_info", "FLOAT_COLOR", "POINT")
    info = np.zeros((len(me.vertices), 4))
    info[:, 0] = part / 2.0
    info[:, 1] = dark_v
    a.data.foreach_set("color", info.astype(np.float32).ravel())
    d = src.modifiers.new("decimate", "DECIMATE")
    d.ratio = min(1.0, FUR_TRIS / max(len(me.polygons), 1))
    d.use_collapse_triangulate = True
    d.use_symmetry = True
    d.symmetry_axis = "X"
    apply_modifiers(src)
    me = src.data
    me.calc_loop_triangles()
    nv = len(me.vertices)
    co = vertices(src)
    col = np.empty(nv * 4)
    me.attributes["fur_info"].data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    vpart = np.round(col[:, 0] * 2.0).astype(np.int64)
    L = fur_length(unshape(co), vpart) * (1.0 - smoothstep(0.2, 0.6, col[:, 1]))
    tris = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tris)
    tris = tris.reshape(-1, 3)
    tl = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("loops", tl)
    uv_loops = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv_loops)
    uv_loops = uv_loops.reshape(-1, 2)
    keys = {}
    vmap, vuv, corner_v = [], [], []
    for t in range(len(tris)):
        for c in range(3):
            vi = int(tris[t, c])
            uv = uv_loops[tl[t * 3 + c]]
            k = (vi, round(float(uv[0]), 6), round(float(uv[1]), 6))
            if k not in keys:
                keys[k] = len(vmap)
                vmap.append(vi)
                vuv.append(uv)
            corner_v.append(keys[k])
    vmap = np.array(vmap)
    vuv = np.array(vuv)
    faces = np.array(corner_v).reshape(-1, 3)
    # Triangles with no fur anywhere (the nose, eyes, pads) are left out.
    fl = L[vmap]
    faces = faces[fl[faces].max(1) > 0.0015]
    n1 = len(vmap)
    allv = np.tile(co[vmap], (FUR_LAYERS, 1))
    allf = np.concatenate([faces + n1 * k for k in range(FUR_LAYERS)])
    fur = bpy.data.meshes.new("Fur")
    fur.vertices.add(len(allv))
    fur.vertices.foreach_set("co", allv.ravel())
    fur.loops.add(allf.size)
    fur.loops.foreach_set("vertex_index", allf.ravel())
    fur.polygons.add(len(allf))
    fur.polygons.foreach_set("loop_start", np.arange(0, allf.size, 3))
    fur.polygons.foreach_set("loop_total", np.full(len(allf), 3))
    fur.update()
    loop_v = allf.ravel()
    uv1 = fur.uv_layers.new(name="UVMap")
    uv1.data.foreach_set("uv", np.tile(vuv, (FUR_LAYERS, 1))[loop_v].ravel())
    layer = np.repeat(np.arange(1, FUR_LAYERS + 1) / FUR_LAYERS, n1)
    length = np.tile(np.clip(fl / FUR_MAX, 0, 1), FUR_LAYERS)
    uv2 = fur.uv_layers.new(name="Fur")
    uv2.data.foreach_set("uv", np.stack([layer, length], axis=1)[loop_v].ravel())
    for p in fur.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("Fur", fur)
    bpy.context.scene.collection.objects.link(obj)
    # Weights from the body's nearest vertex.
    Wsrc = np.zeros((nv, len(BONE_NAMES)))
    for v in me.vertices:
        for g in v.groups:
            nm = src.vertex_groups[g.group].name
            if nm in BONE_NAMES:
                Wsrc[v.index, BONE_NAMES.index(nm)] = g.weight
    set_weights(obj, np.tile(Wsrc[vmap], (FUR_LAYERS, 1)), BONE_NAMES)
    bpy.data.objects.remove(src)
    print("fur: %d verts per layer, %d tris per layer, %d layers" % (n1, len(faces), FUR_LAYERS))
    return obj


def unshape(Pm):
    """Metres back to source units (approximately: the growth is left in). Only used for
    the fur length map, whose regions are broad."""
    P = np.asarray(Pm, dtype=np.float64) / SCALE + CENTRE
    z = P[:, 2]
    lo, hi = LEG_SPAN
    top = lo + (hi - lo) * (1 + LEG_GROW)
    P[:, 2] = np.where(z <= lo, z, np.where(z >= top, z - LEG_GROW * (hi - lo), lo + (z - lo) / (1 + LEG_GROW)))
    return P


def strand_texture(path, size=512, cells=48):
    """Shell fur strands, tileable: R the strand's length, G the distance from its middle
    (0 .. 1 at half a cell), B a shade."""
    rng = np.random.default_rng(23)
    cs = size / cells
    cx = (np.arange(cells)[:, None] + 0.5 + rng.uniform(-0.35, 0.35, (cells, cells))) * cs
    cy = (np.arange(cells)[None, :] + 0.5 + rng.uniform(-0.35, 0.35, (cells, cells))) * cs
    guard = rng.random((cells, cells)) < 0.35
    length = np.where(guard, rng.uniform(0.8, 1.0, (cells, cells)), rng.uniform(0.45, 0.75, (cells, cells)))
    shade = rng.random((cells, cells))
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
    best = np.full((size, size), 1e9, dtype=np.float32)
    R = np.zeros((size, size), dtype=np.float32)
    B = np.zeros((size, size), dtype=np.float32)
    ix = np.floor(xs / cs).astype(int)
    iy = np.floor(ys / cs).astype(int)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            jx = (ix + dx) % cells
            jy = (iy + dy) % cells
            px = cx[jx, jy] + (ix + dx - jx) * cs
            py = cy[jx, jy] + (iy + dy - jy) * cs
            d = np.hypot(xs - px, ys - py)
            closer = d < best
            best = np.where(closer, d, best)
            R = np.where(closer, length[jx, jy], R)
            B = np.where(closer, shade[jx, jy], B)
    G = np.clip(best / (cs * 0.5), 0, 1)
    return save_png(np.stack([R, G, B], axis=-1), path, non_color=True)


def uv_metres(obj):
    """Metres of surface per unit of UV (the square root of the area ratio)."""
    me = obj.data
    me.calc_loop_triangles()
    uv = me.uv_layers[0].data
    a3 = a2 = 0.0
    for t in me.loop_triangles:
        p = [me.vertices[i].co for i in t.vertices]
        q = [uv[i].uv for i in t.loops]
        a3 += (p[1] - p[0]).cross(p[2] - p[0]).length * 0.5
        a2 += abs((q[1] - q[0]).cross(q[2] - q[0])) * 0.5
    return math.sqrt(a3 / max(a2, 1e-12))


# --- Previews ------------------------------------------------------------------------------------

def cam(name, pos, target, lens=60):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.clip_start = 0.01
    c = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(c)
    pos = mathutils.Vector(pos)
    fwd = (mathutils.Vector(target) - pos).normalized()
    up = mathutils.Vector((0, 0, 1)) if abs(fwd.z) < 0.95 else mathutils.Vector((0, 1, 0))
    right = fwd.cross(up).normalized()
    m = mathutils.Matrix((right, right.cross(fwd), -fwd)).transposed()
    c.matrix_world = mathutils.Matrix.Translation(pos) @ m.to_4x4()
    return c


def mark_joints(arm):
    """The bones drawn as red sticks with a ball at each joint (previews only)."""
    out = []
    for b in arm.data.bones:
        a, c = arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.008, location=a, segments=8, ring_count=6)
        out.append(bpy.context.active_object)
        d = c - a
        bpy.ops.mesh.primitive_cylinder_add(radius=0.0035, depth=d.length, location=(a + c) * 0.5, vertices=6)
        cyl = bpy.context.active_object
        cyl.rotation_mode = "QUATERNION"
        cyl.rotation_quaternion = d.to_track_quat("Z", "Y")
        out.append(cyl)
    for o in out:
        o.color = (0.9, 0.1, 0.05, 1.0)
        o.show_in_front = True
    return out


def previews(d, textured, arm=None):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE" if textured else "OBJECT"
    sc.display.shading.show_xray = not textured and arm is not None
    sc.display.shading.xray_alpha = 0.35
    sc.render.resolution_x, sc.render.resolution_y = 1000, 760
    marks = mark_joints(arm) if arm is not None and not textured else []
    t = (0, 0.0, 0.33)
    views = {"side": (2.2, 0.0, 0.4), "front3q": (1.2, 1.7, 0.6), "back3q": (-1.1, -1.7, 0.8),
             "front": (0.0, 2.2, 0.4), "top": (0.001, 0.0, 2.4), "head": (0.45, 0.85, 0.75)}
    for k, p in views.items():
        target = (0, 0.36, 0.58) if k == "head" else t
        sc.camera = cam(k, p, target, lens=85 if k == "head" else 50)
        sc.render.filepath = os.path.join(d, "dog_%s%s.png" % (k, "" if textured else "_shape"))
        bpy.ops.render.render(write_still=True)
    for m in marks:
        bpy.data.objects.remove(m)


def stamp_gltf(path):
    """Writes the buffer's hash into the glTF: Godot reimports a model when its .gltf
    changes, not when only its .bin does."""
    d = json.load(open(path))
    data = open(os.path.join(os.path.dirname(path), d["buffers"][0]["uri"]), "rb").read()
    d.setdefault("asset", {}).setdefault("extras", {})["bin_md5"] = hashlib.md5(data).hexdigest()
    with open(path, "w") as f:
        json.dump(d, f, indent=1)


BONE_NAMES = []


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body, part = load_source()
    co = vertices(body)
    specs = bone_specs(co, part)
    BONE_NAMES[:] = [s[0] for s in specs]
    adjacency = edges(body)
    W = skin_weights(co, part, specs, adjacency)
    maps = None
    if not a.get("shape"):
        # Textures from the source frame (the coat rules are in its units).
        body.data.materials.clear()
        maps = coat_maps(body, part)
    set_vertices(body, shape(co, part))
    arm = build_armature(specs)
    set_weights(body, W, BONE_NAMES)
    body.parent = arm
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    print("dog: %d verts, %d faces; %.3f m long, %.3f m tall" % (len(body.data.vertices), len(body.data.polygons),
          np.ptp(vertices(body)[:, 1]), vertices(body)[:, 2].max()))
    if a.get("shape"):
        if "preview" in a:
            previews(a["preview"], False, arm)
        return
    albedo, normal, orm, pos, dark, eye, nose = maps
    body.data.materials.append(material(albedo, normal, orm))
    # Dark features per vertex (no fur there): sampled from the texture at the vertex UVs.
    me = body.data
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    lv = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", lv)
    size = dark.shape[0]
    px = np.clip((uv * size).astype(int), 0, size - 1)
    dv = np.zeros(len(me.vertices))
    np.maximum.at(dv, lv, dark[px[:, 1], px[:, 0]])
    fur = build_fur(body, part, dv)
    fur.parent = arm
    fm = fur.modifiers.new("Armature", "ARMATURE")
    fm.object = arm
    strands = strand_texture(os.path.join(TEX_DIR, "dog_strands.png"))
    fmat = material(albedo, normal, orm)
    fmat.name = "dog_fur"
    fur.data.materials.append(fmat)
    print("UV: %.4f m per UV unit" % uv_metres(body))
    if "preview" in a:
        fur.hide_render = True
        previews(a["preview"], True)
        fur.hide_render = False
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, "dog.gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="textures",
            export_animations=False, export_skins=True, export_yup=True, export_vertex_color="NONE",
            export_tangents=True, export_image_format="AUTO", use_selection=False)
    stamp_gltf(path)
    print("DOG EXPORTED", path)


if __name__ == "__main__":
    main()
