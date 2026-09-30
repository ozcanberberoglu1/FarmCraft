"""Builds the wild rabbit (a European rabbit, Oryctolagus cuniculus) into art/models/wildlife/rabbit/.

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_rabbit.py [-- --preview=/abs/dir] [--shape]
    --preview=DIR  workbench renders of the result (side, front, back, top)
    --shape        only the body's shape and its previews (no textures, no export)

Modelled here from scratch (no free realistic rabbit can be downloaded without an
account): the body is a signed distance field of ellipsoids and round cones, blended
smoothly and meshed with OpenVDB at about a millimetre, smoothed and reduced; the ears
are rolled, thin leaves (a tube at the base opening into a spoon); the eyes big glossy
spheres set in lidded sockets; whiskers thin tapering tubes. The coat is painted per
texel from the baked surface position (agouti ticking, a rufous nape, a cream belly,
pale eye rings, dark-rimmed ears, a white scut) with baked ambient occlusion, and a
second mesh carries FUR_LAYERS stacked copies of a lighter body for shell fur (the
game offsets them along the normal: UV2.x the layer, UV2.y the fur length).

Sitting pose (the rest pose: hind feet flat under the haunches, front paws down),
Z up, facing +Y (glTF: facing -Z), metres, about 36 cm from nose to scut. Skinned to a
skeleton RabbitRig drives by these names: root, body, spine, chest, neck, head, nose,
jaw, ear_l/ear_l2, ear_r/ear_r2, tail, and per leg {f,r}{l,r}_{up,lo,ft} (l = the
rabbit's left, -X).
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
import openvdb as vdb

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art/models/wildlife/rabbit")
TEX_DIR = os.path.join(OUT_DIR, "textures")

VOXEL = 0.0011
GRID_LO = np.array([-0.08, -0.182, -0.004])
GRID_HI = np.array([0.08, 0.205, 0.215])
TEX_SIZE = 2048
BODY_TRIS = 16000
FUR_TRIS = 5200
FUR_LAYERS = 16
## Longest fur (m): UV2.y is the fur length over this.
FUR_MAX = 0.02

# Landmarks (Blender frame).
EYE_R = 0.0092
NOSE = np.array([0.0, 0.1695, 0.146])
PAD = np.array([0.0095, 0.158, 0.1405])
TAIL = np.array([0.0, -0.13, 0.078])


def args():
    out = {}
    if "--" in sys.argv:
        for a in sys.argv[sys.argv.index("--") + 1:]:
            if a.startswith("--"):
                k, _, v = a[2:].partition("=")
                out[k] = v if v else True
    return out


def norm(v):
    v = np.asarray(v, dtype=np.float64)
    return v / np.linalg.norm(v)


def rot(deg):
    return np.array(mathutils.Euler([math.radians(a) for a in deg], "XYZ").to_matrix())


# --- Signed distance primitives ----------------------------------------------------------------

class Prim:
    """An ellipsoid ("ell": c, r, rot) or a round cone ("cone": a, b, r1, r2), blended into
    the shape with radius k (op "add") or carved out of it ("sub"). `bone` names the bone
    its surface follows; a cone may blend two bones along its axis (bone=(a, b, t0, t1))."""

    def __init__(self, kind, bone, k, op="add", sigma=None, **kw):
        self.kind, self.bone, self.k, self.op = kind, bone, k, op
        self.sigma = sigma if sigma is not None else max(0.0015, k * 0.35)
        if kind == "ell":
            self.c = np.array(kw["c"], dtype=np.float64)
            self.r = np.array(kw["r"], dtype=np.float64)
            self.R = rot(kw.get("rot", (0, 0, 0)))
        else:
            self.a = np.array(kw["a"], dtype=np.float64)
            self.b = np.array(kw["b"], dtype=np.float64)
            self.r1, self.r2 = kw["r1"], kw["r2"]

    def dist(self, p):
        if self.kind == "ell":
            q = (p - self.c) @ self.R
            k0 = np.linalg.norm(q / self.r, axis=-1)
            k1 = np.linalg.norm(q / (self.r * self.r), axis=-1)
            return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
        # Inigo Quilez's round cone.
        ba = self.b - self.a
        l2 = ba @ ba
        rr = self.r1 - self.r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = p - self.a
        y = pa @ ba
        z = y - l2
        xv = pa * l2 - y[..., None] * ba
        x2 = np.einsum("...i,...i->...", xv, xv)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - self.r1
        d1 = np.sqrt(x2 + z2) * il2 - self.r2
        d2 = np.sqrt(x2 + y2) * il2 - self.r1
        return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))

    def bbox(self):
        m = self.k + 0.003
        if self.kind == "ell":
            e = self.r.max() + m
            return self.c - e, self.c + e
        e = max(self.r1, self.r2) + m
        return np.minimum(self.a, self.b) - e, np.maximum(self.a, self.b) + e

    def bones(self, p):
        """[(bone, factor)] for points p."""
        if isinstance(self.bone, str):
            return [(self.bone, np.ones(len(p)))]
        if self.kind == "ell":
            # (b0, b1, lo, hi, axis): b1 takes over from lo to hi metres along axis.
            b0, b1, t0, t1, axis = self.bone
            t = (p - self.c) @ norm(axis)
        else:
            b0, b1, t0, t1 = self.bone
            ba = self.b - self.a
            t = np.clip((p - self.a) @ ba / (ba @ ba), 0.0, 1.0)
        f = np.clip((t - t0) / max(t1 - t0, 1e-6), 0.0, 1.0)
        f = f * f * (3 - 2 * f)
        return [(b0, 1.0 - f), (b1, f)]


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def combine(d, e, prim):
    if prim.op == "add":
        return smin(d, e, prim.k)
    return -smin(-d, e, prim.k)


def sdf_at(prims, p):
    d = np.full(len(p), 1.0)
    for pr in prims:
        d = combine(d, pr.dist(p), pr)
    return d


# --- Anatomy -----------------------------------------------------------------------------------

def eye_center(side):
    return np.array([side * 0.0228, 0.1315, 0.1655])


def eye_dir(side):
    return norm([side * 1.0, 0.42, 0.28])


def anatomy():
    """The body as primitives, in order (later ones blend into or carve the earlier)."""
    P = []
    add = lambda kind, bone, k, **kw: P.append(Prim(kind, bone, k, **kw))
    # Rump and back: the round loaf of a sitting rabbit, highest over the loins.
    add("ell", "body", 0.03, c=(0, -0.058, 0.088), r=(0.064, 0.072, 0.08))
    add("ell", "spine", 0.035, c=(0, -0.008, 0.098), r=(0.056, 0.072, 0.066), rot=(-9, 0, 0))
    add("ell", "spine", 0.03, c=(0, -0.012, 0.058), r=(0.048, 0.064, 0.04))
    add("ell", "chest", 0.03, c=(0, 0.05, 0.088), r=(0.044, 0.05, 0.058), rot=(10, 0, 0))
    # The throat and the chest's front, down between the forelegs.
    add("ell", "chest", 0.025, c=(0, 0.075, 0.082), r=(0.032, 0.03, 0.045), rot=(-15, 0, 0))
    for sx in (-1.0, 1.0):
        n = "l" if sx < 0 else "r"
        # Haunches: the big thigh muscles over the folded hind legs.
        # Its top goes with the pelvis, the part round the knee with the thigh.
        add("ell", ("body", "r%s_up" % n, -0.012, 0.022, (0, 0.35, -1.0)), 0.024, c=(sx * 0.044, -0.042, 0.068),
            r=(0.035, 0.062, 0.054), rot=(14, 0, 0))
        # The shin, inside the haunch; the hock just shows behind it.
        add("cone", ("r%s_up" % n, "r%s_lo" % n, 0.1, 0.4), 0.018, a=(sx * 0.047, 0.004, 0.044),
            b=(sx * 0.048, -0.082, 0.02), r1=0.016, r2=0.0105)
    # Neck: short and thick.
    add("cone", ("chest", "neck", 0.1, 0.7), 0.03, a=(0, 0.064, 0.11), b=(0, 0.094, 0.142), r1=0.034, r2=0.028)
    # Head: the cranium, a blunt muzzle, full cheeks, the whisker pads and the nose.
    add("ell", "head", 0.02, c=(0, 0.113, 0.16), r=(0.029, 0.042, 0.032), rot=(-12, 0, 0))
    add("ell", "head", 0.016, c=(0, 0.143, 0.1495), r=(0.021, 0.025, 0.0225), rot=(-15, 0, 0))
    for sx in (-1.0, 1.0):
        add("ell", "head", 0.016, c=(sx * 0.0185, 0.117, 0.144), r=(0.018, 0.026, 0.021), rot=(-10, 0, 0))
        # Brow over the eye.
        add("ell", "head", 0.01, c=(sx * 0.019, 0.126, 0.179), r=(0.009, 0.015, 0.006), rot=(-10, 0, 0))
        # Ear root.
        add("ell", "head", 0.01, c=(sx * 0.0125, 0.097, 0.188), r=(0.0105, 0.011, 0.012))
    for sx in (-1.0, 1.0):
        add("ell", "nose", 0.008, c=(sx * PAD[0], PAD[1], PAD[2]), r=(0.0118, 0.0118, 0.0115))
    add("ell", "nose", 0.005, c=(0, 0.1645, 0.1465), r=(0.0078, 0.0055, 0.006))
    add("ell", "jaw", 0.009, c=(0, 0.14, 0.1295), r=(0.0115, 0.018, 0.008), rot=(-8, 0, 0))
    # Eye sockets (the eyeballs fill them, the rims lap over their edges).
    for sx in (-1.0, 1.0):
        P.append(Prim("ell", "head", 0.0022, op="sub", c=eye_center(sx) + eye_dir(sx) * 0.0005,
                      r=(EYE_R + 0.0001,) * 3))
    # The split upper lip.
    add("ell", "nose", 0.0, op="sub", c=(0, NOSE[1] - 0.002, NOSE[2] - 0.008), r=(0.0009, 0.004, 0.0035))
    # Forelegs: upper arm in the chest, short forearms straight down, small paws.
    for sx in (-1.0, 1.0):
        n = "l" if sx < 0 else "r"
        add("cone", ("f%s_up" % n, "f%s_lo" % n, 0.5, 0.9), 0.02, a=(sx * 0.028, 0.052, 0.09),
            b=(sx * 0.024, 0.066, 0.046), r1=0.0155, r2=0.012)
        add("cone", "f%s_lo" % n, 0.008, a=(sx * 0.024, 0.066, 0.046), b=(sx * 0.0225, 0.08, 0.013),
            r1=0.0105, r2=0.0082)
        add("ell", "f%s_ft" % n, 0.006, c=(sx * 0.0215, 0.092, 0.008), r=(0.0098, 0.016, 0.0074), rot=(-4, 0, 0))
    # Hind feet: long and flat along the ground from the heel to the toes.
    for sx in (-1.0, 1.0):
        n = "l" if sx < 0 else "r"
        add("ell", "r%s_ft" % n, 0.012, c=(sx * 0.048, -0.066, 0.0145), r=(0.0128, 0.03, 0.0135), rot=(6, 0, 0))
        add("ell", "r%s_ft" % n, 0.01, c=(sx * 0.0475, -0.018, 0.0115), r=(0.0132, 0.036, 0.011))
        add("ell", "r%s_ft" % n, 0.006, c=(sx * 0.0455, 0.028, 0.0088), r=(0.012, 0.021, 0.0087))
    # The scut, held up against the rump.
    add("ell", "tail", 0.012, c=tuple(TAIL), r=(0.018, 0.016, 0.026), rot=(35, 0, 0))
    return P


def ear_frame(side):
    base = np.array([side * 0.0125, 0.0965, 0.193])
    w = norm([side * 0.24, -0.4, 1.0])
    n0 = np.array([side * 0.6, 1.0, 0.05])
    n0 = norm(n0 - (n0 @ w) * w)
    s = np.cross(w, n0) * side
    return base, w, n0, s


EAR_LEN = 0.075


def ear_mesh(side):
    """A rabbit's ear: a rolled tube at the base opening into a long spoon with a rounded
    tip, 1.6-3 mm thick. Returns verts, faces, per-vertex (part, u, v)."""
    base, w, n0, s = ear_frame(side)
    NU, NV = 34, 20
    verts, info = [], []

    def halfwidth(u):
        if u < 0.55:
            t = u / 0.55
            return 0.0085 + (0.0168 - 0.0085) * (1 - (1 - t) ** 2)
        t = (u - 0.55) / 0.45
        return max(0.0168 * math.sqrt(max(1 - t ** 2.3, 0.0)), 0.0012)

    def halfangle(u):
        return 2.3 - 1.5 * (1 - (1 - min(u / 0.5, 1.0)) ** 2) - 0.15 * max(u - 0.5, 0) * 2

    rows = []
    for iu in range(NU + 1):
        u = 1 - (1 - iu / NU) ** 1.25
        W, phi = halfwidth(u), halfangle(u)
        th_ = 0.0031 - 0.0014 * u
        axis = base + w * EAR_LEN * u - n0 * 0.1 * EAR_LEN * u * u
        rho = W / math.sin(min(phi, math.pi / 2))
        C = axis + n0 * rho
        row_o, row_i = [], []
        for iv in range(NV + 1):
            v = -1 + 2 * iv / NV
            th = v * phi
            p = C - n0 * rho * math.cos(th) + s * rho * math.sin(th)
            n_in = norm(C - p)
            row_o.append(len(verts)); verts.append(p - n_in * th_ * 0.5); info.append((1, u, v))
            row_i.append(len(verts)); verts.append(p + n_in * th_ * 0.5); info.append((2, u, v))
        rows.append((row_o, row_i))
    faces = []
    for iu in range(NU):
        o0, i0 = rows[iu]
        o1, i1 = rows[iu + 1]
        for iv in range(NV):
            faces.append((o0[iv], o0[iv + 1], o1[iv + 1], o1[iv]))
            faces.append((i0[iv], i1[iv], i1[iv + 1], i0[iv + 1]))
        # Rims.
        faces.append((o0[0], o1[0], i1[0], i0[0]))
        faces.append((o0[NV], i0[NV], i1[NV], o1[NV]))
    oN, iN = rows[NU]
    for iv in range(NV):
        faces.append((oN[iv], oN[iv + 1], iN[iv + 1], iN[iv]))
    return np.array(verts), faces, info


# --- Meshing -------------------------------------------------------------------------------------

def body_grid(prims):
    shape = np.ceil((GRID_HI - GRID_LO) / VOXEL).astype(int) + 1
    D = np.full(shape, 1.0, dtype=np.float32)
    axes = [GRID_LO[i] + np.arange(shape[i]) * VOXEL for i in range(3)]
    for pr in prims:
        lo, hi = pr.bbox()
        i0 = np.clip(np.floor((lo - GRID_LO) / VOXEL).astype(int), 0, shape - 1)
        i1 = np.clip(np.ceil((hi - GRID_LO) / VOXEL).astype(int) + 1, 1, shape)
        X, Y, Z = np.meshgrid(axes[0][i0[0]:i1[0]], axes[1][i0[1]:i1[1]], axes[2][i0[2]:i1[2]], indexing="ij")
        p = np.stack([X, Y, Z], axis=-1)
        e = pr.dist(p).astype(np.float32)
        sub = D[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]]
        D[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]] = combine(sub, e, pr)
    # The ground: nothing below the soles.
    D = np.maximum(D, (-(axes[2] - 0.0012))[None, None, :].astype(np.float32))
    return D


def mesh_from_grid(D, name):
    g = vdb.FloatGrid(1.0)
    g.copyFromArray(D)
    pts, tris, quads = g.convertToPolygons(0.0, 0.0)
    pts = GRID_LO + pts.astype(np.float64) * VOXEL
    faces = [tuple(q) for q in quads.tolist()] + [tuple(t) for t in tris.tolist()]
    me = bpy.data.meshes.new(name)
    me.from_pydata(pts.tolist(), [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return obj


def apply_modifiers(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)


def smooth_reduce(obj, tris):
    m = obj.modifiers.new("smooth", "SMOOTH")
    m.factor = 0.5
    m.iterations = 3
    apply_modifiers(obj)
    n = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    d = obj.modifiers.new("decimate", "DECIMATE")
    d.ratio = min(1.0, tris / max(n, 1))
    d.use_collapse_triangulate = True
    apply_modifiers(obj)


def add_mesh(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return objs[0]


def shade_smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


# --- Build ---------------------------------------------------------------------------------------

def surface_point(prims, start, direction):
    """First surface crossing from `start` (inside) along `direction`."""
    start, direction = np.array(start, float), norm(direction)
    t0, t1 = 0.0, 0.0
    for i in range(200):
        t1 = t0 + 0.0005
        if sdf_at(prims, (start + direction * t1)[None])[0] > 0:
            break
        t0 = t1
    for i in range(30):
        tm = (t0 + t1) * 0.5
        if sdf_at(prims, (start + direction * tm)[None])[0] > 0:
            t1 = tm
        else:
            t0 = tm
    return start + direction * t1


def build_body(prims):
    D = body_grid(prims)
    body = mesh_from_grid(D, "Body")
    smooth_reduce(body, BODY_TRIS)
    parts = []
    for sx in (-1.0, 1.0):
        v, f, info = ear_mesh(sx)
        ear = add_mesh("Ear", v, f)
        bm = bmesh.new()
        bm.from_mesh(ear.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(ear.data)
        bm.free()
        att = ear.data.attributes.new("partinfo", "FLOAT_COLOR", "POINT")
        att.data.foreach_set("color", np.array([(p / 4.0, u, v * 0.5 + 0.5, 1.0) for p, u, v in info]).ravel())
        parts.append(ear)
    att = body.data.attributes.new("partinfo", "FLOAT_COLOR", "POINT")
    att.data.foreach_set("color", np.tile([0.0, 0.0, 0.0, 1.0], len(body.data.vertices)))
    body = join([body] + parts)
    shade_smooth(body)
    return body


def build_eyes():
    objs = []
    for sx in (-1.0, 1.0):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=16, radius=EYE_R)
        # Pole (+Z) along the eye's look; UVs a planar map across the front.
        q = mathutils.Vector((0, 0, 1)).rotation_difference(mathutils.Vector(eye_dir(sx)))
        uvl = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            for loop in f.loops:
                p = loop.vert.co
                loop[uvl].uv = (0.5 + p.x / (2.2 * EYE_R), 0.5 + p.y / (2.2 * EYE_R))
        for v in bm.verts:
            v.co = q @ v.co + mathutils.Vector(eye_center(sx))
        me = bpy.data.meshes.new("Eye")
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("Eye", me)
        bpy.context.scene.collection.objects.link(o)
        shade_smooth(o)
        objs.append(o)
    return join(objs)


def build_whiskers(prims):
    rng = np.random.default_rng(3)
    verts, faces = [], []

    def whisker(root, d, length, droop, r0):
        seg, sides = 8, 3
        pts = []
        for i in range(seg + 1):
            t = i / seg
            pts.append(root + d * length * t + np.array([0, 0, -1.0]) * droop * length * t * t)
        rings = []
        for i, p in enumerate(pts):
            t = i / seg
            fwd = norm(pts[min(i + 1, seg)] - pts[max(i - 1, 0)])
            a = norm(np.cross(fwd, [0, 0, 1.0]))
            b = np.cross(fwd, a)
            r = r0 * (1 - t) + 0.00005
            ring = []
            for k in range(sides):
                ang = 2 * math.pi * k / sides
                ring.append(len(verts))
                verts.append(p + (a * math.cos(ang) + b * math.sin(ang)) * r)
            rings.append(ring)
        for i in range(seg):
            for k in range(sides):
                k1 = (k + 1) % sides
                faces.append((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))

    for sx in (-1.0, 1.0):
        pad = np.array([sx * PAD[0], PAD[1], PAD[2]])
        for row in range(3):
            for j in range(3 if row < 2 else 2):
                out = norm([sx * 1.0, 0.55 - 0.18 * j + rng.uniform(-0.08, 0.08), 0.28 - row * 0.28 + rng.uniform(-0.06, 0.06)])
                start = pad + np.array([0, -0.002 + 0.003 * j, 0.004 - row * 0.0035])
                root = surface_point(prims, start, out) - out * 0.0015
                d = norm(out + np.array([0, -0.35, 0.0]))
                whisker(root, d, rng.uniform(0.045, 0.068), rng.uniform(0.12, 0.3), 0.00034)
        # Long whiskers over the eye and on the cheek.
        e = eye_center(sx)
        for k in range(2):
            root = surface_point(prims, e + np.array([-sx * 0.006, 0.004 + k * 0.004, 0.004]), [sx * 0.3, 0.2, 1.0])
            whisker(root - np.array([0, 0, 0.001]), norm([sx * 0.8, 0.3 - k * 0.3, 0.7]), rng.uniform(0.035, 0.05), 0.25, 0.0003)
        root = surface_point(prims, np.array([sx * 0.012, 0.13, 0.135]), [sx * 1.0, 0.1, -0.3])
        whisker(root, norm([sx * 1.0, -0.2, -0.2]), 0.035, 0.2, 0.00028)
    return add_mesh("Whiskers", verts, faces)


# --- Skinning ------------------------------------------------------------------------------------

BONES = [
    # name, head, tail, parent
    ("root", (0, 0, 0), (0, 0.03, 0), None),
    ("body", (0, -0.055, 0.088), (0, -0.005, 0.1), "root"),
    ("spine", (0, -0.005, 0.1), (0, 0.045, 0.1), "body"),
    ("chest", (0, 0.045, 0.1), (0, 0.075, 0.114), "spine"),
    ("neck", (0, 0.075, 0.114), (0, 0.1, 0.148), "chest"),
    ("head", (0, 0.1, 0.148), (0, 0.162, 0.15), "neck"),
    ("nose", (0, 0.147, 0.147), (0, 0.171, 0.146), "head"),
    ("jaw", (0, 0.11, 0.141), (0, 0.15, 0.129), "head"),
    ("tail", (0, -0.118, 0.072), (0, -0.136, 0.094), "body"),
]
for _sx, _n in ((-1.0, "l"), (1.0, "r")):
    BONES += [
        ("f%s_up" % _n, (_sx * 0.028, 0.052, 0.09), (_sx * 0.024, 0.066, 0.046), "chest"),
        ("f%s_lo" % _n, (_sx * 0.024, 0.066, 0.046), (_sx * 0.0225, 0.08, 0.013), "f%s_up" % _n),
        ("f%s_ft" % _n, (_sx * 0.0225, 0.08, 0.013), (_sx * 0.0215, 0.105, 0.006), "f%s_lo" % _n),
        ("r%s_up" % _n, (_sx * 0.043, -0.062, 0.082), (_sx * 0.047, 0.004, 0.044), "body"),
        ("r%s_lo" % _n, (_sx * 0.047, 0.004, 0.044), (_sx * 0.048, -0.082, 0.02), "r%s_up" % _n),
        ("r%s_ft" % _n, (_sx * 0.048, -0.082, 0.02), (_sx * 0.046, 0.045, 0.007), "r%s_lo" % _n),
        # Toe tips (no weights): where the feet end, for the rig's foot placement.
        ("f%s_toe" % _n, (_sx * 0.0215, 0.105, 0.006), (_sx * 0.0215, 0.113, 0.006), "f%s_ft" % _n),
        ("r%s_toe" % _n, (_sx * 0.046, 0.045, 0.007), (_sx * 0.046, 0.053, 0.007), "r%s_ft" % _n),
    ]
for _sx, _n in ((-1.0, "l"), (1.0, "r")):
    _b, _w, _n0, _s = ear_frame(_sx)
    _mid = _b + _w * EAR_LEN * 0.45 - _n0 * 0.1 * EAR_LEN * 0.2
    _tip = _b + _w * EAR_LEN - _n0 * 0.1 * EAR_LEN
    BONES += [("ear_%s" % _n, tuple(_b), tuple(_mid), "head"), ("ear_%s2" % _n, tuple(_mid), tuple(_tip), "ear_%s" % _n)]
BONE_NAMES = [b[0] for b in BONES]


def skin_weights(P, info, prims):
    """Per-vertex bone weights (N x bones): each primitive's bone pulls the vertices
    near its own surface; ears follow their two bones along their length."""
    n = len(P)
    W = np.zeros((n, len(BONE_NAMES)))
    adds = [p for p in prims if p.op == "add"]
    Dm = np.stack([p.dist(P) for p in adds])
    dmin = Dm.min(0)
    for i, pr in enumerate(adds):
        gap = Dm[i] - dmin
        infl = np.exp(-gap / pr.sigma) * (gap < pr.sigma * 5)
        for bone, f in pr.bones(P):
            j = BONE_NAMES.index(bone)
            W[:, j] = np.maximum(W[:, j], infl * f)
    part, u, v = info[:, 0], info[:, 1], info[:, 2]
    ear = part > 0.1
    for sx, s in ((-1.0, "l"), (1.0, "r")):
        m = ear & (np.sign(P[:, 0]) == sx)
        if not m.any():
            continue
        W[m] = 0.0
        t = np.clip((u[m] - 0.3) / 0.35, 0, 1)
        t = t * t * (3 - 2 * t)
        hb = np.clip(1 - u[m] / 0.08, 0, 1)
        W[m, BONE_NAMES.index("ear_%s" % s)] = (1 - t) * (1 - hb)
        W[m, BONE_NAMES.index("ear_%s2" % s)] = t
        W[m, BONE_NAMES.index("head")] = hb
    # Four strongest, normalised.
    idx = np.argsort(-W, axis=1)[:, 4:]
    np.put_along_axis(W, idx, 0.0, axis=1)
    W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    return W


def set_weights(obj, W):
    for name in BONE_NAMES:
        if name not in obj.vertex_groups:
            obj.vertex_groups.new(name=name)
    for j, name in enumerate(BONE_NAMES):
        vg = obj.vertex_groups[name]
        nz = np.nonzero(W[:, j] > 1e-4)[0]
        for i in nz:
            vg.add([int(i)], float(W[i, j]), "REPLACE")


def set_single_bone(obj, name, name2=None, split=None):
    if name not in obj.vertex_groups:
        obj.vertex_groups.new(name=name)
    vg = obj.vertex_groups[name]
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def build_armature(meshes):
    arm_data = bpy.data.armatures.new("RabbitRig")
    arm = bpy.data.objects.new("RabbitRig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for name, head, tail, parent in BONES:
        b = eb.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for m in meshes:
        m.parent = arm
        mod = m.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    return arm


def vertex_info(obj):
    me = obj.data
    n = len(me.vertices)
    P = np.empty(n * 3)
    me.vertices.foreach_get("co", P)
    col = np.empty(n * 4)
    me.attributes["partinfo"].data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    info = np.stack([np.round(col[:, 0] * 4.0), col[:, 1], col[:, 2] * 2 - 1], axis=1)
    return P.reshape(-1, 3), info


# --- Coat ------------------------------------------------------------------------------------------

def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float32) / float(0xFFFFFF)


def vnoise(p, seed=0):
    """3D value noise, 0..1, at unit frequency (p pre-scaled)."""
    i = np.floor(p).astype(np.int64)
    f = (p - i).astype(np.float32)
    u = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1]) * (u[:, 2] if dz else 1 - u[:, 2])
                out = out + w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(p, octaves, seed):
    s, a, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = s + a * vnoise(p * (2.0 ** o), seed + o * 17)
        tot += a
        a *= 0.5
    return s / tot


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    """Lerp; a per-texel t spreads over colour channels when a or b is a colour."""
    t = np.asarray(t, dtype=np.float64)
    colour = any(np.ndim(v) > 0 and np.shape(v)[-1] == 3 for v in (a, b))
    if colour and t.ndim == 1:
        t = t[:, None]
    return a * (1 - t) + b * t


def C(r, g, b):
    return np.array([r, g, b], dtype=np.float32)


def coat_colors(P, N, part, eu, ev, ao):
    """sRGB albedo per texel from where it is on the rabbit."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    nz = N[:, 2]
    # Hair lies back along the body and down the legs: ticking streaks that way.
    legs = np.clip(smoothstep(0.05, 0.03, z) + smoothstep(0.06, 0.09, y) * smoothstep(0.075, 0.05, z), 0, 1)
    k = np.stack([x * 2400, y * mix(800.0, 2400.0, legs), z * mix(2400.0, 800.0, legs)], axis=1)
    tick = vnoise(k, 1)
    tick2 = vnoise(k * 1.7 + 7.3, 2)
    streak = vnoise(k * 0.35 + 3.1, 3)
    blotch = fbm(P * 60.0, 3, 5)
    broad = fbm(P * 18.0, 2, 9)
    # Agouti: buff bands and black tips over grey underfur, finely grizzled.
    dark = C(0.1, 0.085, 0.07)
    buff = C(0.56, 0.45, 0.32)
    grey = C(0.38, 0.34, 0.29)
    t_black = smoothstep(0.5, 0.82, tick * 0.7 + streak * 0.3) * 0.8
    t_buff = smoothstep(0.3, 0.75, tick2)
    agouti = mix(mix(grey, buff, t_buff), dark, t_black)
    agouti = agouti * (0.9 + 0.2 * blotch[:, None])
    col = agouti.copy()
    # Back: greyer, more black ticking; flanks warmer and lighter.
    back = smoothstep(0.35, 0.85, nz) * smoothstep(0.06, 0.1, z)
    col = mix(col, col * C(0.86, 0.86, 0.9), back)
    flank = smoothstep(0.7, 0.2, np.abs(nz)) * (1 - back)
    col = mix(col, col * C(1.08, 1.0, 0.88), flank * 0.7)
    # Rufous nape, behind the ears and over the neck.
    nape = smoothstep(0.022, 0.0, np.hypot(y - 0.085, (z - 0.15) * 1.1) - 0.008) * smoothstep(0.1, 0.6, nz)
    col = mix(col, mix(C(0.6, 0.41, 0.25), C(0.38, 0.26, 0.15), t_black * 0.6), nape * 0.7)
    # Chest front and throat: pale buff-grey; the chin white.
    chest = smoothstep(0.3, 0.8, N[:, 1]) * smoothstep(0.13, 0.1, z) * smoothstep(0.05, 0.08, y) * smoothstep(0.02, 0.04, z)
    col = mix(col, mix(C(0.7, 0.63, 0.52), C(0.45, 0.4, 0.33), t_black * 0.5), chest * 0.75)
    chin = smoothstep(-0.2, -0.7, nz) * smoothstep(0.1, 0.13, y) * smoothstep(0.1, 0.125, z)
    col = mix(col, C(0.86, 0.84, 0.79), chin)
    # Belly, the insides of the legs: cream.
    belly = smoothstep(-0.25, -0.65, nz) * smoothstep(0.1, 0.07, z) * (y < 0.1) * (y > -0.11)
    inner = smoothstep(0.02, 0.0, ax - 0.03) * smoothstep(0.045, 0.02, z) * (y > -0.02) * (y < 0.08)
    col = mix(col, mix(C(0.87, 0.84, 0.77), C(0.72, 0.68, 0.6), tick2 * 0.4), np.clip(belly + inner * 0.8, 0, 1))
    # Forelegs and paws: warm cinnamon buff, paler paws.
    fore = smoothstep(0.065, 0.05, z) * smoothstep(0.065, 0.075, y) * (y < 0.125)
    col = mix(col, mix(C(0.62, 0.5, 0.37), C(0.42, 0.33, 0.24), t_black * 0.5), fore * 0.8)
    paw = smoothstep(0.02, 0.01, z) * smoothstep(0.085, 0.095, y)
    col = mix(col, C(0.72, 0.65, 0.55), paw * 0.6)
    # Hind feet: buff on top, the furred soles brownish.
    hind = smoothstep(0.03, 0.02, z) * smoothstep(0.03, 0.036, ax) * (y < 0.06)
    col = mix(col, mix(C(0.64, 0.55, 0.43), C(0.46, 0.39, 0.3), t_black * 0.5), hind * 0.75)
    sole = smoothstep(-0.5, -0.9, nz) * smoothstep(0.012, 0.004, z)
    col = mix(col, C(0.46, 0.38, 0.3), sole)
    # The scut: dark on top, snow white beneath and behind.
    tail = smoothstep(0.012, 0.0, np.linalg.norm(P - TAIL, axis=1) - 0.022)
    tail_top = smoothstep(-0.1, 0.5, nz * 0.8 + N[:, 1] * 0.5)
    col = mix(col, mix(C(0.94, 0.93, 0.9), mix(C(0.2, 0.17, 0.14), C(0.36, 0.31, 0.25), tick2), tail_top), tail)
    # Head: buff muzzle and cheeks, pale eye rings, dark lids, bare nose.
    head = smoothstep(0.1, 0.115, y) * smoothstep(0.12, 0.13, z)
    muzzle = head * smoothstep(0.14, 0.16, y)
    col = mix(col, mix(C(0.66, 0.58, 0.46), C(0.48, 0.41, 0.33), t_black * 0.6), muzzle * 0.6)
    for sx in (-1.0, 1.0):
        e = eye_center(sx)
        de = np.linalg.norm(P - e, axis=1) - EYE_R
        ring = smoothstep(0.0048, 0.0026, de) * smoothstep(0.0006, 0.0016, de)
        col = mix(col, C(0.8, 0.74, 0.62), ring * 0.6)
        lid = smoothstep(0.0012, 0.0004, de)
        col = mix(col, C(0.07, 0.055, 0.05), lid)
    dn = np.linalg.norm((P - NOSE) * np.array([1.0, 1.4, 1.0]), axis=1)
    nose = smoothstep(0.0062, 0.0042, dn) * smoothstep(-0.2, 0.3, N[:, 1])
    col = mix(col, C(0.5, 0.38, 0.35), nose)
    # Nostril slits (a "Y" with the split lip).
    for sx in (-1.0, 1.0):
        a = NOSE + np.array([sx * 0.0012, 0.0, 0.0012])
        b = NOSE + np.array([sx * 0.0045, -0.001, 0.0028])
        ab = b - a
        t = np.clip((P - a) @ ab / (ab @ ab), 0, 1)
        dl = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
        col = mix(col, C(0.16, 0.11, 0.1), smoothstep(0.0009, 0.0003, dl) * nose)
    lip = smoothstep(0.0008, 0.0002, ax) * smoothstep(0.1445, 0.141, z) * smoothstep(0.128, 0.132, z) * smoothstep(0.165, 0.172, y)
    col = mix(col, C(0.2, 0.15, 0.13), lip)
    # Whisker follicles on the pads.
    pad = np.zeros_like(x)
    for sx in (-1.0, 1.0):
        pad = np.maximum(pad, smoothstep(0.011, 0.007, np.linalg.norm(P - np.array([sx * PAD[0], PAD[1], PAD[2]]), axis=1)))
    dots = smoothstep(0.8, 0.9, vnoise(P * 1500.0, 21))
    col = mix(col, C(0.84, 0.78, 0.66), pad * 0.4)
    col = mix(col, C(0.2, 0.15, 0.12), pad * dots * 0.7)
    # Ears: grey-brown backs going dark at the rims near the tip; pink insides with pale hairs.
    ear_o = part == 1
    ear_i = part == 2
    eo = mix(C(0.52, 0.47, 0.4), C(0.43, 0.38, 0.33), eu)
    eo = eo * (0.88 + 0.24 * tick[:, None])
    rim = smoothstep(0.68, 0.92, eu) * smoothstep(0.65, 0.97, np.abs(ev)) + smoothstep(0.9, 0.985, eu)
    eo = mix(eo, C(0.1, 0.085, 0.075), np.clip(rim, 0, 1))
    col = np.where(ear_o[:, None], eo, col)
    skin = mix(C(0.78, 0.6, 0.55), C(0.62, 0.45, 0.42), smoothstep(0.3, 0.0, eu))
    veins = smoothstep(0.62, 0.8, vnoise(np.stack([ev * 30.0, eu * 4.0, np.zeros_like(eu)], axis=1), 31))
    skin = mix(skin, C(0.66, 0.44, 0.42), veins * 0.35)
    hairs = smoothstep(0.55, 0.95, np.abs(ev)) * smoothstep(0.1, 0.3, eu)
    ei = mix(skin, C(0.8, 0.73, 0.62) * (0.8 + 0.3 * tick[:, None]), hairs * 0.85)
    ei = mix(ei, C(0.1, 0.085, 0.075), np.clip(smoothstep(0.62, 0.95, eu) * smoothstep(0.8, 1.0, np.abs(ev)) + smoothstep(0.9, 0.99, eu), 0, 1))
    col = np.where(ear_i[:, None], ei, col)
    col = col * (0.93 + 0.14 * broad[:, None])
    # Ambient occlusion: the creases darken.
    col = col * (0.42 + 0.58 * ao[:, None])
    return np.clip(col, 0, 1)


def fur_length(P, N, part, eu):
    """Fur length (m) per vertex."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    L = np.full(len(P), 0.0088)
    head = smoothstep(0.1, 0.125, y) * smoothstep(0.115, 0.135, z)
    L = mix(L, 0.0038, head)
    L = mix(L, 0.0022, smoothstep(0.15, 0.172, y) * head)
    belly = smoothstep(-0.3, -0.7, N[:, 2]) * smoothstep(0.09, 0.06, z)
    L = mix(L, 0.01, belly)
    legs = smoothstep(0.06, 0.04, z) * smoothstep(0.06, 0.075, y)
    L = mix(L, 0.004, legs)
    feet = smoothstep(0.028, 0.018, z)
    L = mix(L, 0.0042, feet)
    tail = smoothstep(0.012, 0.0, np.linalg.norm(P - TAIL, axis=1) - 0.022)
    L = mix(L, 0.015, tail)
    for sx in (-1.0, 1.0):
        de = np.linalg.norm(P - eye_center(sx), axis=1) - EYE_R
        L = L * smoothstep(0.0015, 0.0065, de)
    dn = np.linalg.norm(P - NOSE, axis=1)
    L = L * smoothstep(0.004, 0.009, dn)
    L = np.where(part == 1, 0.0016 * (1 - 0.4 * eu), L)
    L = np.where(part == 2, 0.0008 * smoothstep(0.4, 0.9, eu), L)
    return L


def bake_maps(obj, size):
    """Object-space position, normal and the part info baked to float images."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.margin = 8
    sc.render.bake.use_clear = True
    world = bpy.data.worlds.new("bake")
    sc.world = world
    world.light_settings.distance = 0.03
    mat = bpy.data.materials.new("bake")
    mat.use_nodes = True
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    nt = mat.node_tree
    out = {}
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for key in ("pos", "nor", "part", "ao"):
        nt.nodes.clear()
        o = nt.nodes.new("ShaderNodeOutputMaterial")
        img = bpy.data.images.new("bake_" + key, size, size, alpha=True, float_buffer=True)
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.nodes.active = tex
        if key == "ao":
            bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
            nt.links.new(bsdf.outputs[0], o.inputs[0])
            sc.cycles.samples = 48
            bpy.ops.object.bake(type="AO")
            sc.cycles.samples = 1
        else:
            em = nt.nodes.new("ShaderNodeEmission")
            if key == "part":
                a = nt.nodes.new("ShaderNodeAttribute")
                a.attribute_name = "partinfo"
                nt.links.new(a.outputs["Color"], em.inputs[0])
            else:
                g = nt.nodes.new("ShaderNodeNewGeometry")
                nt.links.new(g.outputs["Position" if key == "pos" else "Normal"], em.inputs[0])
            nt.links.new(em.outputs[0], o.inputs[0])
            bpy.ops.object.bake(type="EMIT")
        a = np.empty(size * size * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        out[key] = a.reshape(-1, 4)
        # Coverage: texels the bake wrote (margins included).
        if key == "pos":
            out["mask"] = a.reshape(-1, 4)[:, 3] > 0.5
    obj.data.materials.clear()
    bpy.data.materials.remove(mat)
    return out


def save_png(pixels, size, path, alpha=False):
    im = bpy.data.images.new(os.path.basename(path).split(".")[0], size, size, alpha=alpha)
    im.pixels.foreach_set(pixels.astype(np.float32).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    return im


def paint_coat(obj):
    maps = bake_maps(obj, TEX_SIZE)
    m = maps["mask"]
    P = maps["pos"][m, :3].astype(np.float64)
    N = maps["nor"][m, :3].astype(np.float64)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-6)
    part = np.round(maps["part"][m, 0] * 4.0)
    eu = maps["part"][m, 1]
    ev = maps["part"][m, 2] * 2 - 1
    ao = np.clip(maps["ao"][m, 0], 0, 1)
    col = coat_colors(P, N, part, eu, ev, ao)
    px = np.zeros((TEX_SIZE * TEX_SIZE, 4), dtype=np.float32)
    px[:, :3] = C(0.4, 0.34, 0.27)
    px[:, 3] = 1.0
    px[m, :3] = col
    return save_png(px, TEX_SIZE, os.path.join(TEX_DIR, "rabbit_coat.png"))


def strand_texture(path, size=512, cells=64):
    """Shell fur strands, tileable: R the strand's length (short underfur, long guard
    hairs), G the distance from its middle (0 .. 1 at half a cell), B a shade."""
    rng = np.random.default_rng(11)
    cs = size / cells
    cx = (np.arange(cells)[:, None] + 0.5 + rng.uniform(-0.3, 0.3, (cells, cells))) * cs
    cy = (np.arange(cells)[None, :] + 0.5 + rng.uniform(-0.3, 0.3, (cells, cells))) * cs
    guard = rng.random((cells, cells)) < 0.28
    length = np.where(guard, rng.uniform(0.82, 1.0, (cells, cells)), rng.uniform(0.42, 0.72, (cells, cells)))
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
    px = np.stack([R, G, B, np.ones_like(R)], axis=-1)
    return save_png(px, size, path, alpha=False)


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


def eye_texture():
    """Dark brown iris all but filling the eye, a black pupil, a darker limbal ring."""
    n = 256
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    u = (xs + 0.5) / n * 2 - 1
    v = (ys + 0.5) / n * 2 - 1
    r = np.hypot(u, v) * 1.1
    ang = np.arctan2(v, u)
    rng = np.random.default_rng(4)
    streak = np.zeros_like(r)
    for f in (23, 41, 67):
        streak += np.sin(ang * f + rng.uniform(0, 6)) * 0.33
    iris = np.stack([0.13 + 0.035 * streak, 0.07 + 0.02 * streak, 0.035 + 0.01 * streak], axis=-1)
    iris *= (0.7 + 0.5 * smoothstep(0.95, 0.55, r))[..., None]
    col = np.where((r < 0.5)[..., None], np.array([0.015, 0.012, 0.01]), iris)
    col = col * (1 - 0.6 * smoothstep(0.78, 0.98, r))[..., None]
    col = np.where((r > 0.98)[..., None], np.array([0.05, 0.035, 0.03]), col)
    px = np.concatenate([col, np.ones_like(r)[..., None]], axis=-1)
    return save_png(px[::-1], n, os.path.join(TEX_DIR, "rabbit_eye.png"))


def material(name, image=None, color=(0.8, 0.8, 0.8), rough=0.8, spec=0.3):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = image
        m.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = spec
    return m


# --- Shell fur -------------------------------------------------------------------------------------

def build_fur(body, prims):
    """FUR_LAYERS copies of a lighter body; UV2 = (layer / FUR_LAYERS, length / FUR_MAX)."""
    src = body.copy()
    src.data = body.data.copy()
    bpy.context.scene.collection.objects.link(src)
    d = src.modifiers.new("decimate", "DECIMATE")
    d.ratio = min(1.0, FUR_TRIS / max(len(src.data.polygons), 1))
    d.use_collapse_triangulate = True
    apply_modifiers(src)
    me = src.data
    me.calc_loop_triangles()
    nv = len(me.vertices)
    co = np.empty(nv * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    nor = np.empty(nv * 3)
    me.vertices.foreach_get("normal", nor)
    nor = nor.reshape(-1, 3)
    P, info = vertex_info(src)
    L = fur_length(P, nor, info[:, 0], info[:, 1])
    tris = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tris)
    tris = tris.reshape(-1, 3)
    tl = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("loops", tl)
    uv_loops = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv_loops)
    uv_loops = uv_loops.reshape(-1, 2)
    # Per-vertex UV (a vertex on a seam takes one side's: vertices are split by UV below).
    # Split vertices along UV seams: one output vertex per (vertex, uv) pair.
    keys = {}
    vmap, vuv = [], []
    corner_v = []
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
    length = np.tile(np.clip(L[vmap] / FUR_MAX, 0, 1), FUR_LAYERS)
    uv2 = fur.uv_layers.new(name="Fur")
    uv2.data.foreach_set("uv", np.stack([layer, length], axis=1)[loop_v].ravel())
    for p in fur.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("Fur", fur)
    bpy.context.scene.collection.objects.link(obj)
    # Weights from the reduced body.
    Wsrc = np.zeros((nv, len(BONE_NAMES)))
    for v in me.vertices:
        for g in v.groups:
            nm = src.vertex_groups[g.group].name
            if nm in BONE_NAMES:
                Wsrc[v.index, BONE_NAMES.index(nm)] = g.weight
    set_weights(obj, np.tile(Wsrc[vmap], (FUR_LAYERS, 1)))
    bpy.data.objects.remove(src)
    print("fur: %d verts per layer, %d layers" % (n1, FUR_LAYERS))
    return obj


# --- Previews ------------------------------------------------------------------------------------

def cam(name, pos, target, lens=60):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.clip_start = 0.001
    c = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(c)
    pos = mathutils.Vector(pos)
    fwd = (mathutils.Vector(target) - pos).normalized()
    up = mathutils.Vector((0, 0, 1)) if abs(fwd.z) < 0.95 else mathutils.Vector((0, 1, 0))
    right = fwd.cross(up).normalized()
    m = mathutils.Matrix((right, right.cross(fwd), -fwd)).transposed()
    c.matrix_world = mathutils.Matrix.Translation(pos) @ m.to_4x4()
    return c


def previews(d, textured):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE" if textured else "SINGLE"
    sc.display.shading.single_color = (0.62, 0.55, 0.47)
    sc.display.shading.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 800, 640
    t = (0, 0.0, 0.1)
    views = {"side": (0.75, 0.0, 0.12), "front3q": (0.45, 0.6, 0.2), "back3q": (-0.4, -0.6, 0.3),
             "front": (0.0, 0.8, 0.14), "top": (0.001, 0.0, 0.85), "head": (0.2, 0.3, 0.2)}
    for k, p in views.items():
        target = (0, 0.13, 0.15) if k == "head" else t
        sc.camera = cam(k, p, target, lens=90 if k == "head" else 60)
        sc.render.filepath = os.path.join(d, "rabbit_%s.png" % k)
        bpy.ops.render.render(write_still=True)


def stamp_gltf(path):
    """Writes the buffer's hash into the glTF: Godot reimports a model when its .gltf
    changes, not when only its .bin does."""
    d = json.load(open(path))
    data = open(os.path.join(os.path.dirname(path), d["buffers"][0]["uri"]), "rb").read()
    d.setdefault("asset", {}).setdefault("extras", {})["bin_md5"] = hashlib.md5(data).hexdigest()
    with open(path, "w") as f:
        json.dump(d, f, indent=1)


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(TEX_DIR, exist_ok=True)
    prims = anatomy()
    body = build_body(prims)
    print("body: %d verts, %d faces" % (len(body.data.vertices), len(body.data.polygons)))
    eyes = build_eyes()
    whiskers = build_whiskers(prims)
    if a.get("shape"):
        eyes.data.materials.append(material("eye", color=(0.02, 0.015, 0.01), rough=0.05))
        if "preview" in a:
            previews(a["preview"], False)
        return
    # UVs.
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Skin weights.
    P, info = vertex_info(body)
    set_weights(body, skin_weights(P, info, prims))
    set_single_bone(eyes, "head")
    set_single_bone(whiskers, "nose")
    # Coat.
    coat = paint_coat(body)
    body.data.materials.append(material("rabbit_coat", coat, rough=0.85, spec=0.25))
    eyes.data.materials.append(material("rabbit_eye", eye_texture(), rough=0.04, spec=0.8))
    whiskers.data.materials.append(material("rabbit_whisker", color=(0.05, 0.045, 0.04), rough=0.35, spec=0.4))
    fur = build_fur(body, prims)
    strand_texture(os.path.join(TEX_DIR, "rabbit_strands.png"))
    print("UV: %.4f m per UV unit" % uv_metres(body))
    fur.data.materials.append(material("rabbit_fur", coat, rough=0.9, spec=0.2))
    # The body's own fur length map is not needed on the body: drop the helper attribute.
    for o in (body, fur):
        if "partinfo" in o.data.attributes:
            o.data.attributes.remove(o.data.attributes["partinfo"])
    arm = build_armature([body, eyes, whiskers, fur])
    if "preview" in a:
        fur.hide_render = True
        previews(a["preview"], True)
        fur.hide_render = False
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, "rabbit.gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="textures",
            export_animations=False, export_skins=True, export_yup=True, export_vertex_color="NONE",
            export_tangents=False, export_image_format="AUTO", use_selection=False)
    stamp_gltf(path)
    # Blender re-encodes the textures on export: keep only the exported ones.
    print("RABBIT EXPORTED", path)


if __name__ == "__main__":
    main()
