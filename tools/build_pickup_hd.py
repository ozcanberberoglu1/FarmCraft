"""Builds the pickup's modelled wheels and steering wheel:
art/models/vehicles/pickup_90/hd_parts.glb.

Run headless from the project root:
    /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/build_pickup_hd.py

The downloaded pickup (pickup_90/scene.gltf) keeps its body. Its wheels (a smooth
tyre with a painted tread, faceted rims) and its twelve-sided steering wheel are
replaced by meshes modelled here; Vehicle swaps them in by node name
(VehicleLook.add_detail).
- Tyres: an all-terrain tread of skewed centre blocks and wrap-around shoulder lugs
  of alternating length, a serrated band and a rim protector rib on the sidewall,
  raised lettering (Barlow Condensed Bold, SIL OFL, from art/fonts).
- Steel rims: rolled flanges, bead seats and drop well, a dished face with oval hand
  holes, eight lug nuts with washers and studs, a domed hub cap in front and the
  axle hub on the rear duals, a valve stem.
- Brakes behind them: vented discs in front, finned drums at the rear.
- A three-spoke steering wheel with an oval grip and a padded horn boss.
Every part is built in the frame of the mesh it replaces and fills exactly the same
box, so the wheel radius and hub positions, and the steering wheel's pivot, stay as
they were.
Vertex colours carry what shaders/vehicle_wheel.gdshader needs: r exposure (tread
tops 1, groove floors 0, sidewall between), g distance from the axle over the tyre
radius, b raised sidewall marks.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector


def _root() -> str:
    script = globals().get("__file__") or sys.argv[sys.argv.index("--python") + 1]
    return os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(script)), ".."))


ROOT = _root()
SRC = os.path.join(ROOT, "art/models/vehicles/pickup_90/scene.gltf")
OUT = os.path.join(ROOT, "art/models/vehicles/pickup_90/hd_parts.glb")
FONT = os.path.join(ROOT, "art/fonts/BarlowCondensed-Bold.ttf")

WHEELS = ["WheelStock_FL", "WheelStock_FR", "WheelStock_RL", "WheelStock_RR"]
STEER = "Steering_Wheel"
# Material slots of a wheel mesh.
RUBBER, RIM, HARDWARE, BRAKE = range(4)
SEG = 96
TAU = math.tau


# --- Reference -------------------------------------------------------------------------

def reference() -> dict:
    """World boxes and frames of the meshes to replace, and where the steering wheel's
    grip, spokes and boss sit in the cab atlas."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    ref = {}
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        for key in WHEELS + [STEER]:
            if key not in o.name:
                continue
            pts = [o.matrix_world @ v.co for v in o.data.vertices]
            lo = Vector([min(p[i] for p in pts) for i in range(3)])
            hi = Vector([max(p[i] for p in pts) for i in range(3)])
            ref[key] = {"name": o.name, "mw": o.matrix_world.copy(), "lo": lo, "hi": hi}
            if key == STEER:
                ref[key]["uv"] = _steer_uvs(o, (lo + hi) * 0.5)
    return ref


def _steer_uvs(o, centre: Vector) -> dict:
    """Median atlas coordinates of the old wheel's grip, spokes and boss."""
    me = o.data
    uv = me.uv_layers.active.data
    axis = Vector((1.0, 0.0, -0.36)).normalized()
    parts = {"grip": [], "spoke": [], "boss": []}
    for p in me.polygons:
        for li in p.loop_indices:
            d = o.matrix_world @ me.vertices[me.loops[li].vertex_index].co - centre
            r = (d - axis * d.dot(axis)).length
            key = "grip" if r > 0.12 else ("spoke" if r > 0.05 else "boss")
            parts[key].append(tuple(uv[li].uv))
    out = {}
    for key, l in parts.items():
        us = sorted(u for u, _ in l)
        vs = sorted(v for _, v in l)
        out[key] = (us[len(us) // 2], vs[len(vs) // 2])
    return out


# --- Mesh building ---------------------------------------------------------------------

class Builder:
    """Vertices with an (exposure, raised) colour and faces with a material slot."""

    def __init__(self):
        self.v = []
        self.c = []
        self.uv = []
        self.f = []
        self.m = []

    def vert(self, co, exposure=1.0, raised=0.0, uv=(0.0, 0.0)) -> int:
        self.v.append(Vector(co))
        self.c.append((exposure, raised))
        self.uv.append(uv)
        return len(self.v) - 1

    def face(self, idx, mat: int) -> None:
        if len(set(idx)) >= 3:
            self.f.append(tuple(idx))
            self.m.append(mat)

    def ring(self, y: float, r: float, seg=SEG, exposure=1.0, raised=0.0, phase=0.0, uv=(0.0, 0.0)) -> list:
        return [self.vert((r * math.cos(phase + TAU * k / seg), y, r * math.sin(phase + TAU * k / seg)),
                exposure, raised, uv) for k in range(seg)]

    def bridge(self, a: list, b: list, mat: int) -> None:
        n = len(a)
        for k in range(n):
            k2 = (k + 1) % n
            self.face((a[k], a[k2], b[k2], b[k]), mat)

    def cap(self, ring: list, centre, mat: int, exposure=1.0) -> None:
        c = self.vert(centre, exposure, 0.0, self.uv[ring[0]])
        n = len(ring)
        for k in range(n):
            self.face((ring[k], ring[(k + 1) % n], c), mat)

    def revolve(self, prof, mat: int, seg=SEG, exposure=None, raised=0.0) -> list:
        """A surface of revolution about the y axis through (y, r) points; exposure is
        a number or a function of (y, r)."""
        rings = []
        for y, r in prof:
            e = exposure(y, r) if callable(exposure) else (1.0 if exposure is None else exposure)
            rings.append(self.ring(y, r, seg, e, raised))
        for a, b in zip(rings, rings[1:]):
            self.bridge(a, b, mat)
        return rings

    def to_object(self, name: str, mats: list, sharp_deg=38.0):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in self.v], [], self.f)
        for p, m in zip(me.polygons, self.m):
            p.material_index = m
            p.use_smooth = True
        for m in mats:
            me.materials.append(m)
        col = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        uvl = me.uv_layers.new(name="UVMap")
        for li, loop in enumerate(me.loops):
            e, r = self.c[loop.vertex_index]
            col.data[li].color = (e, 0.0, r, 1.0)
            uvl.data[li].uv = self.uv[loop.vertex_index]
        me.color_attributes.active_color = col
        me.validate()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.set_sharp_from_angle(angle=math.radians(sharp_deg))
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def catmull(points, per=5):
    """A smooth curve through (y, r) points (Catmull-Rom, `per` samples per span)."""
    out = []
    pts = [points[0]] + list(points) + [points[-1]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (Vector(p) for p in pts[i - 1:i + 3])
        for s in range(per):
            t = s / per
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                    + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
            out.append((q.x, q.y))
    out.append(tuple(points[-1]))
    return out


# --- Tyre ------------------------------------------------------------------------------

class Tyre:
    """An all-terrain tyre of outer radius R and section width W on a rim of bead
    radius rim_r, in the wheel frame (axle along y, the outer side towards +y)."""

    DEPTH = 0.0135

    def __init__(self, R: float, W: float, rim_r: float, rim_a: float):
        self.R, self.W, self.rim_r, self.rim_a = R, W, rim_r, rim_a
        d = self.DEPTH
        hw = W * 0.5
        self.th = th = W * 0.39
        # Outer carcass half profile from the crown to the bead (the groove floor
        # under the tread), tucked behind the rim flange at the bead.
        ctrl = [(0.0, R - d), (0.5 * th, R - d - 0.0014), (th, R - d - 0.0048),
                (th + 0.45 * (hw - th), R - d - 0.013), (hw - 0.003, R - 0.058),
                (hw, R - 0.088), (hw - 0.004, rim_r + 0.05), (hw - 0.014, rim_r + 0.03),
                (rim_a + 0.009, rim_r + 0.017), (rim_a + 0.002, rim_r + 0.004)]
        self.half = catmull(ctrl, 3)
        # Arc length along the half profile.
        self.s = [0.0]
        for a, b in zip(self.half, self.half[1:]):
            self.s.append(self.s[-1] + math.dist(a, b))
        self.s_tread = self._s_at_y(th)
        # Where the sidewall starts (below the shoulder lugs).
        self.wall_top = R - 0.06

    def _s_at_y(self, y: float) -> float:
        for (a, b), s0, s1 in zip(zip(self.half, self.half[1:]), self.s, self.s[1:]):
            if a[0] <= y <= b[0] and b[0] > a[0]:
                return s0 + (s1 - s0) * (y - a[0]) / (b[0] - a[0])
        return self.s[-1]

    def surf(self, s: float):
        """(y, r) and the outward normal in the profile plane at arc length s
        (negative s: the inner half)."""
        sign = -1.0 if s < 0 else 1.0
        s = abs(s)
        for i in range(len(self.s) - 1):
            if self.s[i + 1] >= s:
                break
        s0, s1 = self.s[i], self.s[i + 1]
        t = (s - s0) / max(s1 - s0, 1e-9)
        a, b = self.half[i], self.half[i + 1]
        y = a[0] + (b[0] - a[0]) * t
        r = a[1] + (b[1] - a[1]) * t
        ty, tr = (b[0] - a[0]), (b[1] - a[1])
        ln = math.hypot(ty, tr)
        # Outward: the travel direction turned anticlockwise (y right, r up).
        ny, nr = -tr / ln, ty / ln
        return (sign * y, r), (sign * ny, nr)

    def wall_y(self, r: float) -> float:
        """The sidewall's axial position at radius r (outer side)."""
        pts = [p for p in self.half if p[1] <= self.wall_top + 0.01]
        best = pts[0][0]
        for a, b in zip(pts, pts[1:]):
            if min(a[1], b[1]) <= r <= max(a[1], b[1]):
                t = (r - a[1]) / (b[1] - a[1]) if b[1] != a[1] else 0.0
                return a[0] + (b[0] - a[0]) * t
        return best

    def build(self, b: Builder, y0: float, pitches: int, lettering: bool, font) -> None:
        R = self.R
        full = [(-y, r) for y, r in reversed(self.half)] + [(y, r) for y, r in self.half[1:]]
        # Carcass from the inner bead over the crown to the outer bead: groove floors
        # (0) in the tread, dust film (0.6) down the sidewalls.
        def expo(y, r):
            return 0.0 if r > self.wall_top else 0.62
        b.revolve([(y0 + y, r) for y, r in reversed(full)], RUBBER, 72, expo)
        self._tread(b, y0, pitches)
        for side in ([1.0] if lettering else []):
            self._wall_marks(b, y0, side, font)

    # Tread ------------------------------------------------------------------------

    def _block(self, b: Builder, y0: float, outline, theta0: float) -> None:
        """A tread block over the outline [(s, arc)] (arc: metres round the crown)."""
        R, d = self.R, self.DEPTH
        pts = []
        n = len(outline)
        for i in range(n):
            s0, a0 = outline[i]
            s1, a1 = outline[(i + 1) % n]
            steps = max(1, int(math.hypot(s1 - s0, a1 - a0) / 0.011))
            for k in range(steps):
                t = k / steps
                pts.append((s0 + (s1 - s0) * t, a0 + (a1 - a0) * t))

        def place(s, arc, h):
            (y, r), (ny, nr) = self.surf(s)
            th = theta0 + arc / R
            rr = r + nr * h
            return (rr * math.cos(th), y0 + y + ny * h, rr * math.sin(th))

        top = [b.vert(place(s, a, d), 1.0) for s, a in pts]
        bot = [b.vert(place(s, a, -0.0025), 0.0) for s, a in pts]
        cs = sum(p[0] for p in pts) / len(pts)
        ca = sum(p[1] for p in pts) / len(pts)
        c = b.vert(place(cs, ca, d), 1.0)
        m = len(pts)
        for i in range(m):
            j = (i + 1) % m
            b.face((top[i], top[j], c), RUBBER)
            b.face((top[j], top[i], bot[i], bot[j]), RUBBER)

    def _tread(self, b: Builder, y0: float, pitches: int) -> None:
        P = TAU * self.R / pitches
        st = self.s_tread
        c0, c1 = 0.07 * st, 0.45 * st
        s0 = 0.55 * st
        for k in range(pitches):
            th = TAU * k / pitches
            for side in (1.0, -1.0):
                off = 0.0 if side > 0 else 0.5 * P
                sk = 0.2 * P
                # Centre block: a skewed parallelogram with a jog in its trailing edge.
                centre = [(c0, 0.0), (c1, sk), (c1, sk + 0.66 * P),
                          (0.5 * (c0 + c1), 0.5 * sk + 0.66 * P + 0.07 * P), (c0, 0.66 * P)]
                # Shoulder lug over the tread edge onto the shoulder, long and short in turn.
                s1 = st + (0.024 if k % 2 == 0 else 0.013)
                shoulder = [(s0, 0.08 * P), (s1, 0.02 * P), (s1, 0.66 * P), (s0, 0.74 * P)]
                for outline in (centre, shoulder):
                    ol = [(side * s, a) for s, a in outline]
                    if side < 0:
                        ol.reverse()
                    self._block(b, y0, ol, th + off / self.R)

    # Sidewall ------------------------------------------------------------------------

    def _wall_point(self, y0, side, r, th, h):
        return (r * math.cos(th), y0 + side * (self.wall_y(r) + h), r * math.sin(th))

    def _wall_marks(self, b: Builder, y0: float, side: float, font) -> None:
        R = self.R
        # Serrations: short radial ribs below the shoulder lugs.
        r0, r1 = R - 0.066, R - 0.05
        n = 150
        for k in range(n):
            th = TAU * k / n
            w = 0.0022 / r0
            q = []
            for r, a in ((r0, -w), (r1, -w), (r1, w), (r0, w)):
                q.append((r, th + a))
            lo = [b.vert(self._wall_point(y0, side, r, t, -0.001), 0.62, 1.0) for r, t in q]
            hi = [b.vert(self._wall_point(y0, side, r, t, 0.0013), 0.62, 1.0) for r, t in q]
            b.face(hi, RUBBER)
            for i in range(4):
                j = (i + 1) % 4
                b.face((hi[i], hi[j], lo[j], lo[i]), RUBBER)
        # Ribs: under the serrations and the rim protector above the bead.
        for rc in (r0 - 0.004, self.rim_r + 0.034):
            prof = [(rc - 0.003, -0.0008), (rc - 0.0015, 0.0014), (rc + 0.0015, 0.0014), (rc + 0.003, -0.0008)]
            rings = [[b.vert(self._wall_point(y0, side, r, TAU * k / SEG, h), 0.62, 1.0) for k in range(SEG)]
                     for r, h in prof]
            for a, c in zip(rings, rings[1:]):
                b.bridge(a, c, RUBBER)
        # Lettering, reading clockwise with the tops outwards.
        rt = 0.5 * (self.rim_r + 0.034 + r0 - 0.004)
        self._text(b, y0, side, font, "TERRA TRAC  A/T", 0.029, rt, math.radians(90))
        self._text(b, y0, side, font, "TERRA TRAC  A/T", 0.029, rt, math.radians(270))
        self._text(b, y0, side, font, "LT235/85R16  LOAD RANGE E", 0.0115, rt, math.radians(180))
        self._text(b, y0, side, font, "M+S  RADIAL  TUBELESS", 0.0115, rt, math.radians(0))

    def _text(self, b: Builder, y0, side, font, text, size, rt, centre_th) -> None:
        cu = bpy.data.curves.new("txt", "FONT")
        cu.body = text
        cu.font = font
        cu.size = size
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
        cu.resolution_u = 2
        ob = bpy.data.objects.new("txt", cu)
        bpy.context.scene.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        h = 0.0012
        # Extruded letters: the (x, y) outline goes round the arc, z out of the wall.
        index = {}
        for v in bm.verts:
            index[v] = (v.co.x, v.co.y)
        edges_out = [e for e in bm.edges if len(e.link_faces) == 1]

        def put(x, y, z):
            th = centre_th + side * x / rt
            return self._wall_point(y0, side, rt + y, th, z)

        top = {v: b.vert(put(*index[v], h), 0.62, 1.0) for v in bm.verts}
        low = {v: b.vert(put(*index[v], -0.0008), 0.62, 1.0) for v in bm.verts}
        for f in bm.faces:
            b.face([top[v] for v in f.verts], RUBBER)
        for e in edges_out:
            a, c = e.verts
            b.face((top[a], top[c], low[c], low[a]), RUBBER)
        bm.free()
        bpy.data.objects.remove(ob)
        bpy.data.curves.remove(cu)
        bpy.data.meshes.remove(me)


# --- Rim, hardware and brakes ------------------------------------------------------------

def rim_barrel(b: Builder, y0: float, rim_r: float, a: float) -> None:
    """Rolled flanges, bead seats and the drop well (one sheet, both sides drawn)."""
    prof = [(a + 0.004, rim_r + 0.019), (a + 0.0085, rim_r + 0.014), (a + 0.0085, rim_r + 0.006),
            (a + 0.003, rim_r + 0.0005), (a - 0.013, rim_r), (a - 0.022, rim_r - 0.003),
            (a - 0.03, rim_r - 0.018), (a * 0.3, rim_r - 0.031), (-a * 0.5, rim_r - 0.031),
            (-a + 0.03, rim_r - 0.018), (-a + 0.02, rim_r), (-a - 0.003, rim_r + 0.0005),
            (-a - 0.0085, rim_r + 0.006), (-a - 0.0085, rim_r + 0.014), (-a - 0.004, rim_r + 0.019)]
    b.revolve([(y0 + y, r) for y, r in prof], RIM, SEG, lambda y, r: 0.35 if abs(y - y0) < a - 0.02 else 1.0)


def rim_face(y_d: float, rim_r: float, facing: float, holes: int, name: str, mats: list):
    """The wheel's pressed face (dished, with a raised ring and oval hand holes), as a
    solid plate with the holes cut; facing +1: its show side towards +y."""
    b = Builder()
    f = facing
    prof = [(0.003, rim_r - 0.031), (0.009, 0.162), (0.016, 0.151), (0.013, 0.141), (0.004, 0.118),
            (0.0, 0.100), (0.006, 0.091), (0.006, 0.074), (-0.003, 0.066), (-0.003, 0.060)]
    b.revolve([(y_d + f * y, r) for y, r in prof], RIM, 72, 1.0)
    ob = b.to_object(name, mats)
    sol = ob.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.005
    sol.offset = -f
    sol.use_rim = True
    if holes:
        cb = Builder()
        for k in range(holes):
            th = TAU * (k + 0.5) / holes
            c = Vector((0.132 * math.cos(th), 0.0, 0.132 * math.sin(th)))
            t = Vector((-math.sin(th), 0.0, math.cos(th)))
            rr = Vector((math.cos(th), 0.0, math.sin(th)))
            rings = []
            for yy in (y_d - 0.05, y_d + 0.05):
                ring = []
                for j in range(24):
                    a = TAU * j / 24
                    # A slot: 58 mm round, 30 mm across.
                    p = c + t * (0.029 * math.cos(a)) + rr * (0.015 * math.sin(a))
                    ring.append(cb.vert((p.x, yy, p.z), 0.6))
                rings.append(ring)
            cb.bridge(rings[0], rings[1], RIM)
            cb.cap(rings[0], (c.x, y_d - 0.05, c.z), RIM, 0.6)
            cb.cap(rings[1], (c.x, y_d + 0.05, c.z), RIM, 0.6)
        cut = cb.to_object(name + "_cut", mats)
        boo = ob.modifiers.new("holes", "BOOLEAN")
        boo.operation = "DIFFERENCE"
        boo.solver = "EXACT"
        boo.object = cut
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    ob.data = me
    if holes:
        bpy.data.objects.remove(cut)
    me.set_sharp_from_angle(angle=math.radians(38))
    return ob


def prism(b: Builder, base: Vector, axis: Vector, rings, mat: int, phase=0.0, exposure=1.0) -> None:
    """A closed solid along `axis` through rings of (height, radius, sides)."""
    u = axis.orthogonal().normalized()
    v = axis.cross(u).normalized()
    made = []
    for h, r, n in rings:
        made.append([b.vert(base + axis * h + (u * math.cos(phase + TAU * k / n) + v * math.sin(phase + TAU * k / n)) * r,
                exposure) for k in range(n)])
    for a, c in zip(made, made[1:]):
        if len(a) == len(c):
            b.bridge(a, c, mat)
    b.cap(made[0], base + axis * rings[0][0], mat, exposure)
    b.cap(made[-1], base + axis * rings[-1][0], mat, exposure)


def lug_nuts(b: Builder, y_seat: float, facing: float, count=8, bolt_r=0.0826) -> None:
    ax = Vector((0.0, facing, 0.0))
    for k in range(count):
        th = TAU * k / count
        base = Vector((bolt_r * math.cos(th), y_seat, bolt_r * math.sin(th)))
        # Washer, hex with a chamfered crown, and the stud's end.
        prism(b, base, ax, [(0.0, 0.0158, 20), (0.0035, 0.0158, 20)], HARDWARE)
        prism(b, base, ax, [(0.003, 0.0128, 6), (0.017, 0.0128, 6), (0.0205, 0.0098, 6)], HARDWARE, th)
        prism(b, base, ax, [(0.02, 0.0068, 12), (0.0265, 0.0068, 12), (0.028, 0.0052, 12)], HARDWARE)


def dome(b: Builder, y_b: float, facing: float, prof, mat=HARDWARE) -> None:
    rings = b.revolve([(y_b + facing * y, r) for y, r in prof], mat, 48)
    b.cap(rings[-1], (0.0, y_b + facing * prof[-1][0], 0.0), mat)


def valve(b: Builder, y_d: float, facing: float) -> None:
    th = TAU * 0.25 / 6 + 0.1
    base = Vector((0.172 * math.cos(th), y_d, 0.172 * math.sin(th)))
    ax = Vector((0.25 * math.cos(th), facing, 0.25 * math.sin(th))).normalized()
    prism(b, base, ax, [(0.0, 0.0055, 12), (0.03, 0.0045, 12)], RUBBER)
    prism(b, base, ax, [(0.029, 0.0042, 12), (0.041, 0.0042, 12)], HARDWARE)


def disc_brake(b: Builder, y_face: float) -> None:
    """A vented disc behind the wheel face with its hat (spins with the wheel)."""
    y1 = y_face - 0.034
    y2 = y1 - 0.029
    for ya, yb in ((y1 - 0.009, y1), (y2, y2 + 0.009)):
        prof = [(ya, 0.084), (yb, 0.084), (yb, 0.150), (ya, 0.150), (ya, 0.084)]
        b.revolve(prof, BRAKE, 72, lambda y, r: 1.0 if r > 0.09 and r < 0.149 else 0.2)
    for k in range(36):
        th = TAU * k / 36
        u = Vector((math.cos(th), 0.0, math.sin(th)))
        t = Vector((-math.sin(th), 0.0, math.cos(th)))
        pts = []
        for r, w in ((0.09, 0.004), (0.146, 0.006)):
            for s in (-1, 1):
                pts.append(u * r + t * (w * s))
        quad = [pts[0], pts[1], pts[3], pts[2]]
        lo = [b.vert((p.x, y2 + 0.009, p.z), 0.1) for p in quad]
        hi = [b.vert((p.x, y1 - 0.009, p.z), 0.1) for p in quad]
        for i in range(4):
            j = (i + 1) % 4
            b.face((lo[i], lo[j], hi[j], hi[i]), BRAKE)
    hat = [(y2 + 0.009, 0.086), (y2 + 0.009, 0.074), (y_face - 0.004, 0.074), (y_face - 0.004, 0.062)]
    b.revolve(hat, BRAKE, 72, 0.2)


def drum_brake(b: Builder, y_in: float, y_out: float) -> None:
    prof = [(y_out, 0.06), (y_out, 0.158), (y_out - 0.01, 0.163)]
    fins = 5
    for k in range(fins):
        y = y_out - 0.02 - k * (y_out - y_in - 0.03) / fins
        prof += [(y, 0.163), (y - 0.004, 0.169), (y - 0.01, 0.169), (y - 0.014, 0.163)]
    prof += [(y_in, 0.163), (y_in, 0.17), (y_in - 0.004, 0.17)]
    b.revolve(prof, BRAKE, 72, 0.2)


# --- Wheels ------------------------------------------------------------------------------

def make_wheel(key: str, info: dict, mats: list, font):
    """One wheel in its canonical frame (axle y, outer side +y), then set into place."""
    lo, hi = info["lo"], info["hi"]
    size = hi - lo
    R = 0.5 * max(size.x, size.z)
    rim_r = 0.2032
    rear = key in ("WheelStock_RL", "WheelStock_RR")
    b = Builder()
    parts = []
    if not rear:
        W = size.y
        a = 0.0825
        Tyre(R, W, rim_r, a).build(b, 0.0, 36, True, font)
        rim_barrel(b, 0.0, rim_r, a)
        y_d = 0.026
        parts.append(rim_face(y_d, rim_r, 1.0, 6, key + "_face", mats))
        lug_nuts(b, y_d + 0.006 + 0.0025, 1.0)
        dome(b, y_d + 0.004, 1.0, [(0.0, 0.0605), (0.013, 0.0595), (0.026, 0.0545), (0.037, 0.0445),
                                   (0.044, 0.03), (0.047, 0.014), (0.0475, 0.002)])
        valve(b, y_d + 0.004, 1.0)
        disc_brake(b, y_d)
    else:
        gap = 0.035
        W = 0.5 * (size.y - gap)
        yc = 0.5 * (W + gap)
        a = 0.07
        Tyre(R, W, rim_r, a).build(b, yc, 36, True, font)
        Tyre(R, W, rim_r, a).build(b, -yc, 36, False, font)
        rim_barrel(b, yc, rim_r, a)
        rim_barrel(b, -yc, rim_r, a)
        # The outer wheel's face sits at its inboard edge: a deep dish round the axle hub.
        y_d = yc - a + 0.012
        parts.append(rim_face(y_d, rim_r, 1.0, 6, key + "_face", mats))
        parts.append(rim_face(-y_d, rim_r, -1.0, 0, key + "_face_in", mats))
        lug_nuts(b, y_d + 0.006 + 0.0025, 1.0)
        dome(b, y_d + 0.004, 1.0, [(0.0, 0.058), (0.05, 0.056), (0.062, 0.053), (0.066, 0.047),
                                   (0.072, 0.045), (0.078, 0.036), (0.081, 0.018), (0.082, 0.002)])
        prism(b, Vector((0.0, -y_d, 0.0)), Vector((0.0, 1.0, 0.0)), [(0.0, 0.06, 32), (2 * y_d, 0.06, 32)], HARDWARE)
        valve(b, y_d + 0.004, 1.0)
        drum_brake(b, -yc - a + 0.02, -y_d - 0.006)
    ob = b.to_object(info["name"], mats)
    parts.append(ob)
    with bpy.context.temp_override(active_object=ob, object=ob, selected_editable_objects=parts,
            selected_objects=parts):
        bpy.ops.object.join()
    me = ob.data
    # Canonical -> world: the right side's wheels turn round so their face looks out.
    left = (lo.y + hi.y) > 0.0
    turn = Matrix.Identity(4) if left else Matrix.Rotation(math.pi, 4, "Z")
    me.transform(turn)
    _fit(me, lo, hi)
    _radial(me, (lo + hi) * 0.5, R)
    me.transform(info["mw"].inverted())
    return ob


def _fit(me, lo: Vector, hi: Vector) -> None:
    """Scales and moves the mesh to fill the box lo..hi exactly."""
    pts = [v.co for v in me.vertices]
    a = Vector([min(p[i] for p in pts) for i in range(3)])
    c = Vector([max(p[i] for p in pts) for i in range(3)])
    s = Vector([(hi[i] - lo[i]) / (c[i] - a[i]) for i in range(3)])
    print("fit", me.name, "scale", tuple(round(x, 4) for x in s))
    me.transform(Matrix.Translation(lo) @ Matrix.Diagonal((*s, 1.0)) @ Matrix.Translation(-a))


def _radial(me, centre: Vector, R: float) -> None:
    """Colour g: distance from the axle (world y) over the tyre radius."""
    col = me.color_attributes["Col"]
    for li, loop in enumerate(me.loops):
        p = me.vertices[loop.vertex_index].co - centre
        c = col.data[li].color
        col.data[li].color = (c[0], min(math.hypot(p.x, p.z) / R, 1.0), c[2], 1.0)


# --- Steering wheel ----------------------------------------------------------------------

def make_steering(info: dict, mat):
    """Three spokes and a padded boss inside an oval grip, round the old wheel's centre
    and turning about the column (Vehicle turns it about (1, 0, -0.36) here)."""
    lo, hi = info["lo"], info["hi"]
    C = (lo + hi) * 0.5
    ax = Vector((1.0, 0.0, -0.36)).normalized()
    u = Vector((0.0, 1.0, 0.0))
    v = ax.cross(u).normalized()
    if v.z < 0:
        v = -v
    uv = info["uv"]
    b = Builder()
    # Grip: an oval section round a 0.144 m circle, thicker where the hands go.
    Rm, n_major, n_minor = 0.1435, 96, 18
    rings = []
    for i in range(n_major):
        psi = TAU * i / n_major
        dirv = u * math.cos(psi) + v * math.sin(psi)
        grip = 1.0 + 0.08 * max(0.0, math.cos(2 * psi)) ** 4
        ring = []
        for j in range(n_minor):
            phi = TAU * j / n_minor
            p = C + dirv * (Rm + 0.0165 * grip * math.cos(phi)) + ax * (0.0185 * grip * math.sin(phi))
            ring.append(b.vert(p, uv=uv["grip"]))
        rings.append(ring)
    for i in range(n_major):
        a, c = rings[i], rings[(i + 1) % n_major]
        for j in range(n_minor):
            j2 = (j + 1) % n_minor
            b.face((a[j], a[j2], c[j2], c[j]), 0)
    # Spokes: flattened ovals lofted from the boss (nearer the driver) to the grip.
    for psi in (math.radians(-12), math.radians(192), math.radians(270)):
        dirv = u * math.cos(psi) + v * math.sin(psi)
        side = ax.cross(dirv).normalized()
        secs = []
        for t in (0.0, 0.35, 0.7, 1.0):
            r = 0.045 + (Rm - 0.012 - 0.045) * t
            depth = -0.024 * (1.0 - t) ** 1.5
            w = 0.028 - 0.011 * t
            th = 0.0075 - 0.002 * t
            centre = C + dirv * r + ax * depth
            secs.append([b.vert(centre + side * (w * math.cos(TAU * k / 12)) + ax * (th * math.sin(TAU * k / 12)),
                    uv=uv["spoke"]) for k in range(12)])
        for a, c in zip(secs, secs[1:]):
            b.bridge(a, c, 0)
    # Boss: a rounded pad (superellipse outline) over a hub that runs into the column.
    layers = [(0.012, 0.9), (-0.012, 1.0), (-0.03, 0.97), (-0.037, 0.86), (-0.04, 0.55)]
    made = []
    for depth, k in layers:
        ring = []
        for j in range(40):
            t = TAU * j / 40
            cx, sx = math.cos(t), math.sin(t)
            ex = abs(cx) ** 0.5 * (1 if cx >= 0 else -1)
            ey = abs(sx) ** 0.5 * (1 if sx >= 0 else -1)
            p = C + ax * depth + u * (0.068 * k * ex) + v * (0.052 * k * ey - 0.006)
            ring.append(b.vert(p, uv=uv["boss"]))
        made.append(ring)
    for a, c in zip(made, made[1:]):
        b.bridge(a, c, 0)
    b.cap(made[-1], C + ax * -0.04 - v * 0.006, 0)
    b.cap(made[0], C + ax * 0.012 - v * 0.006, 0)
    prism(b, C, ax, [(0.0, 0.03, 24), (0.05, 0.03, 24)], 0)
    ob = b.to_object(info["name"], [mat], sharp_deg=50.0)
    me = ob.data
    _fit_centre(me, C)
    me.transform(info["mw"].inverted())
    return ob


def _fit_centre(me, C: Vector) -> None:
    """Moves the mesh so its box centre is the old wheel's (the pivot Vehicle uses)."""
    pts = [v.co for v in me.vertices]
    a = Vector([min(p[i] for p in pts) for i in range(3)])
    c = Vector([max(p[i] for p in pts) for i in range(3)])
    me.transform(Matrix.Translation(C - (a + c) * 0.5))


# --- Materials and export ----------------------------------------------------------------

def material(name: str, color, metal: float, rough: float):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    m.use_backface_culling = False
    return m


def main() -> None:
    ref = reference()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Named for Vehicle's restyling: "Tire_*" become vehicle_wheel.gdshader parts; the
    # steering wheel keeps the model's own cab material (same name).
    mats = [material("Tire_Rubber", (0.03, 0.03, 0.03), 0.0, 0.85),
            material("Tire_Rim", (0.7, 0.7, 0.7), 1.0, 0.3),
            material("Tire_Hardware", (0.8, 0.8, 0.8), 1.0, 0.2),
            material("Tire_Brake", (0.35, 0.34, 0.33), 1.0, 0.45)]
    cab = material("UCB_Interiors_1", (0.05, 0.05, 0.05), 0.0, 0.6)
    font = bpy.data.fonts.load(FONT)
    made = [make_wheel(k, ref[k], mats, font) for k in WHEELS]
    made.append(make_steering(ref[STEER], cab))
    for ob in made:
        print(ob.name, "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True,
            export_normals=True, export_tangents=False, export_materials="EXPORT",
            export_image_format="NONE", export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
