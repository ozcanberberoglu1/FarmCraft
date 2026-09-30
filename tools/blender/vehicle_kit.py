"""Shared modelling kit for the dealership's vehicles (tools/blender/build_*.py).

Everything is built in the vehicle's model frame, in Blender's axes: front along +X,
left along +Y, up +Z, the ground at z = 0 (the glTF export turns it into the game's
model frame: front +X, left -Z, up +Y). The game dresses a model by the names of its
meshes and materials (scripts/vehicles/vehicle_look.gd, vehicle.gd):
- materials with "Bodymat" in the name: the body paint (vehicle_paint.gdshader);
- "Trim_<kind>": bumpers, grilles, chassis, rubber, chrome, wood... (vehicle_trim);
- "Interior_<kind>": the cab (vehicle_interior);
- "Tire_Rubber/Rim/Hardware/Brake": the wheels (vehicle_wheel, from build_pickup_hd);
- meshes "WheelStock_FL/FR/RL/RR" (the wheels, axle along the mesh's glTF y),
  "Steering_Wheel", "Lamp_Head*", "Lamp_Brake*", "Lamp_Reverse*", "Lens_*" (lamp
  covers), "Glass_*" / "Windshield" (window panes, each its own mesh with 0..1 UVs
  across it), "Numberplate_*" (a plate, its face towards the mesh's glTF +z).
Untextured materials carry their colour, roughness and metalness; the game turns them
into the shaders' inputs.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
import build_pickup_hd as hd  # noqa: E402

TAU = math.tau
FONT = os.path.join(ROOT, "art/fonts/BarlowCondensed-Bold.ttf")


def args() -> dict:
    out = {}
    if "--" in sys.argv:
        for a in sys.argv[sys.argv.index("--") + 1:]:
            if a.startswith("--"):
                k, _, v = a[2:].partition("=")
                out[k] = v or "true"
    return out


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


# --- Materials -------------------------------------------------------------------------

def mat(name: str, color=(0.5, 0.5, 0.5), metal=0.0, rough=0.5, alpha=None):
    """A material the game reads by name (see the module docstring)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*color, 1.0 if alpha is None else alpha)
    m.metallic = metal
    m.roughness = rough
    if alpha is not None:
        bsdf.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    m.use_backface_culling = False
    return m


def wheel_mats() -> list:
    return [mat("Tire_Rubber", (0.03, 0.03, 0.03), 0.0, 0.85), mat("Tire_Rim", (0.7, 0.7, 0.7), 1.0, 0.3),
            mat("Tire_Hardware", (0.8, 0.8, 0.8), 1.0, 0.2), mat("Tire_Brake", (0.35, 0.34, 0.33), 1.0, 0.45)]


# --- Objects ----------------------------------------------------------------------------

def _link(name: str, me):
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def from_bm(name: str, bm, material, smooth_deg=None):
    """An object from a bmesh (freed), one material; smooth shaded with sharp edges
    above `smooth_deg` (None: flat)."""
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    if smooth_deg is not None:
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(smooth_deg))
    return _link(name, me)


def _bevel_all(bm, width: float, segs: int, angle_deg=None) -> None:
    if width <= 0.0:
        return
    edges = bm.edges[:] if angle_deg is None else [e for e in bm.edges if e.is_manifold and
            e.calc_face_angle(0.0) > math.radians(angle_deg)]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segs, profile=0.5,
                affect="EDGES", clamp_overlap=True)


def box(name, center, size, material, bevel=0.0, segs=2, rot=None, smooth=30.0):
    """A box of `size` round `center`, edges rounded by `bevel`; `rot` a 3x3 Matrix or
    Euler (radians, xyz)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    _bevel_all(bm, bevel, segs)
    m = _rot(rot)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)) @ m, verts=bm.verts)
    return from_bm(name, bm, material, smooth if bevel > 0.0 else None)


def _rot(rot) -> Matrix:
    if rot is None:
        return Matrix.Identity(4)
    if isinstance(rot, Matrix):
        return rot.to_4x4()
    from mathutils import Euler
    return Euler(rot, "XYZ").to_matrix().to_4x4()


def cyl(name, p0, p1, r, material, segs=24, r1=None, cap=True, bevel=0.0, smooth=40.0, phase=0.0):
    """A cylinder (a cone with `r1`) from p0 to p1."""
    p0, p1 = Vector(p0), Vector(p1)
    axis = p1 - p0
    ln = axis.length
    axis.normalize()
    u = axis.orthogonal().normalized()
    v = axis.cross(u)
    r1 = r if r1 is None else r1
    bm = bmesh.new()
    rings = []
    for t, rr in ((0.0, r), (1.0, r1)):
        rings.append([bm.verts.new(p0 + axis * (ln * t) + (u * math.cos(phase + TAU * k / segs) +
                v * math.sin(phase + TAU * k / segs)) * rr) for k in range(segs)])
    for k in range(segs):
        k2 = (k + 1) % segs
        bm.faces.new((rings[0][k], rings[0][k2], rings[1][k2], rings[1][k]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0.0 and cap:
        cap_edges = [e for e in bm.edges if all(len(f.verts) > 4 for f in e.link_faces) is False and
                     any(len(f.verts) > 4 for f in e.link_faces)]
        bmesh.ops.bevel(bm, geom=cap_edges, offset=bevel, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    return from_bm(name, bm, material, smooth)


def prism(name, poly, a0, a1, material, plane="XZ", bevel=0.0, segs=3, smooth=30.0, bevel_angle=None):
    """A polygon in `plane` ("XZ": side profile, extruded along Y from a0 to a1; "YZ":
    cross-section along X; "XY": plan, along Z), its edges rounded by `bevel`."""
    bm = bmesh.new()

    def pt(p, a):
        if plane == "XZ":
            return Vector((p[0], a, p[1]))
        if plane == "YZ":
            return Vector((a, p[0], p[1]))
        return Vector((p[0], p[1], a))
    lo = [bm.verts.new(pt(p, a0)) for p in poly]
    hi = [bm.verts.new(pt(p, a1)) for p in poly]
    n = len(poly)
    bm.faces.new(lo)
    bm.faces.new(list(reversed(hi)))
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((lo[k], lo[k2], hi[k2], hi[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _bevel_all(bm, bevel, segs, bevel_angle)
    return from_bm(name, bm, material, smooth if bevel > 0.0 else None)


def loft(name, sections, material, closed=True, cap=True, smooth=35.0):
    """A surface through `sections` (lists of points, the same count each)."""
    bm = bmesh.new()
    rings = [[bm.verts.new(Vector(p)) for p in s] for s in sections]
    n = len(sections[0])
    for a, b in zip(rings, rings[1:]):
        for k in range(n if closed else n - 1):
            k2 = (k + 1) % n
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if cap and closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(name, bm, material, smooth)


def tube(name, pts, r, material, segs=12, smooth=60.0):
    """A round bar along a polyline, mitred at its corners."""
    pts = [Vector(p) for p in pts]
    bm = bmesh.new()
    rings = []
    prev_u = None
    for i, p in enumerate(pts):
        if i == 0:
            d = (pts[1] - p).normalized()
        elif i == len(pts) - 1:
            d = (p - pts[i - 1]).normalized()
        else:
            d = ((p - pts[i - 1]).normalized() + (pts[i + 1] - p).normalized()).normalized()
        u = d.orthogonal().normalized() if prev_u is None else (prev_u - d * prev_u.dot(d)).normalized()
        prev_u = u
        v = d.cross(u)
        scale = 1.0
        if 0 < i < len(pts) - 1:
            a = (p - pts[i - 1]).normalized()
            scale = 1.0 / max(math.cos(0.5 * a.angle(pts[i + 1] - p)), 0.3)
        rings.append([bm.verts.new(p + (u * math.cos(TAU * k / segs) * scale + v * math.sin(TAU * k / segs)) * r)
                      for k in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for k in range(segs):
            k2 = (k + 1) % segs
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(name, bm, material, smooth)


def revolve(name, prof, centre, axis, material, segs=32, smooth=50.0, cap=True):
    """A surface of revolution: (along, radius) points round `axis` through `centre`."""
    axis = Vector(axis).normalized()
    u = axis.orthogonal().normalized()
    v = axis.cross(u)
    c = Vector(centre)
    bm = bmesh.new()
    rings = [[bm.verts.new(c + axis * h + (u * math.cos(TAU * k / segs) + v * math.sin(TAU * k / segs)) * r)
              for k in range(segs)] for h, r in prof]
    for a, b in zip(rings, rings[1:]):
        for k in range(segs):
            k2 = (k + 1) % segs
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(name, bm, material, smooth)


def sheet(name, quad_pts, material, thickness=0.0, smooth=None):
    """A flat polygon (list of points), optionally thickened along its normal."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in quad_pts]
    f = bm.faces.new(vs)
    if thickness > 0.0:
        f.normal_update()
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=-f.normal * thickness, verts=moved)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(name, bm, material, smooth)


# --- Modifiers, joining ------------------------------------------------------------------

def bevel_mod(ob, width, segs=2, angle=30.0):
    md = ob.modifiers.new("bevel", "BEVEL")
    md.width = width
    md.segments = segs
    md.limit_method = "ANGLE"
    md.angle_limit = math.radians(angle)
    md.use_clamp_overlap = True
    md.harden_normals = False
    return md


def subsurf(ob, levels=2):
    md = ob.modifiers.new("subsurf", "SUBSURF")
    md.levels = levels
    md.render_levels = levels
    return md


def cut(ob, cutter, op="DIFFERENCE"):
    md = ob.modifiers.new("bool", "BOOLEAN")
    md.operation = op
    md.solver = "EXACT"
    md.object = cutter
    cutter.hide_render = True
    cutter.display_type = "WIRE"
    return md


def apply(ob) -> None:
    """Bakes the modifiers into the mesh."""
    if not ob.modifiers:
        return
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)


def remove(*obs) -> None:
    for ob in obs:
        bpy.data.objects.remove(ob, do_unlink=True)


def join(obs, name):
    """One object from several (modifiers applied, materials merged), named `name`."""
    obs = [o for o in obs if o is not None]
    for o in obs:
        apply(o)
    if len(obs) == 1:
        obs[0].name = name
        obs[0].data.name = name
        return obs[0]
    with bpy.context.temp_override(active_object=obs[0], object=obs[0], selected_editable_objects=obs,
            selected_objects=obs):
        bpy.ops.object.join()
    ob = obs[0]
    ob.name = name
    ob.data.name = name
    return ob


def mirror_y(ob, name=None):
    """A copy mirrored left to right (y -> -y) with its placement baked in, normals
    kept outwards."""
    me = ob.data.copy()
    me.transform(Matrix.Diagonal((1.0, -1.0, 1.0, 1.0)) @ ob.matrix_world)
    me.flip_normals()
    return _link(name or ob.name + "_m", me)


def both_sides(ob):
    """Joins `ob` with its left-right mirror image."""
    return join([ob, mirror_y(ob)], ob.name)


def bake_transform(ob) -> None:
    ob.data.transform(ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)


# --- UVs ---------------------------------------------------------------------------------

def uv_box(ob, scale=1.0) -> None:
    """UVs in metres (times `scale`), each face projected along its main axis."""
    me = ob.data
    uvl = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    mw = ob.matrix_world
    for p in me.polygons:
        n = (mw.to_3x3() @ p.normal)
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                uv = (co.y, co.z)
            elif ax == 1:
                uv = (co.x, co.z)
            else:
                uv = (co.x, co.y)
            uvl.data[li].uv = (uv[0] * scale, uv[1] * scale)


def uv_pane(ob) -> None:
    """0..1 UVs across a window pane (its two longest extents)."""
    me = ob.data
    uvl = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    pts = [v.co for v in me.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    size = hi - lo
    axes = sorted(range(3), key=lambda i: -size[i])[:2]
    # Horizontal first, the vertical (z) second when it is one of the two.
    if 2 in axes:
        a, b = [i for i in axes if i != 2][0], 2
    else:
        a, b = axes
    for li, loop in enumerate(me.loops):
        co = me.vertices[loop.vertex_index].co
        uvl.data[li].uv = ((co[a] - lo[a]) / max(size[a], 1e-6), (co[b] - lo[b]) / max(size[b], 1e-6))


# --- Wheels and steering ----------------------------------------------------------------

_font = None


def _get_font():
    global _font
    if _font is None:
        _font = bpy.data.fonts.load(FONT)
    return _font


def wheel(name, centre, R, W, dual=False):
    """The pickup's all-terrain tyre on a pressed steel rim (tools/build_pickup_hd.py),
    fitted to a tyre of radius R and width W (duals: both tyres) at `centre`; its axle
    is the mesh's glTF y."""
    c = Vector(centre)
    left = c.y > 0.0
    lo = Vector((c.x - R, c.y - W * 0.5, c.z - R))
    hi = Vector((c.x + R, c.y + W * 0.5, c.z + R))
    mw = Matrix.Translation(c) @ Matrix.Rotation(-math.pi * 0.5, 4, "X")
    info = {"name": name, "mw": mw, "lo": lo, "hi": hi}
    key = "WheelStock_RL" if dual else "WheelStock_FL"
    ob = hd.make_wheel(key, info, wheel_mats(), _get_font())
    ob.name = name
    ob.data.name = name
    ob.matrix_world = mw
    del left
    return ob


def steering(name, centre, axis, radius, material, spokes=3):
    """A steering wheel round `centre` turning about `axis` (towards the column), with
    an oval grip of `radius` and a padded boss."""
    C = Vector(centre)
    ax = Vector(axis).normalized()
    u = Vector((0.0, 1.0, 0.0))
    u = (u - ax * u.dot(ax)).normalized()
    v = ax.cross(u).normalized()
    if v.z < 0:
        v = -v
    b = hd.Builder()
    Rm, n_major, n_minor = radius, 72, 14
    rings = []
    for i in range(n_major):
        psi = TAU * i / n_major
        d = u * math.cos(psi) + v * math.sin(psi)
        g = 1.0 + 0.08 * max(0.0, math.cos(2 * psi)) ** 4
        rings.append([b.vert(C + d * (Rm + 0.016 * g * math.cos(TAU * j / n_minor)) + ax * (0.018 * g * math.sin(TAU * j / n_minor)))
                      for j in range(n_minor)])
    for i in range(n_major):
        a, c = rings[i], rings[(i + 1) % n_major]
        for j in range(n_minor):
            j2 = (j + 1) % n_minor
            b.face((a[j], a[j2], c[j2], c[j]), 0)
    angles = (math.radians(-12), math.radians(192), math.radians(270)) if spokes == 3 else (0.0, math.pi)
    for psi in angles:
        d = u * math.cos(psi) + v * math.sin(psi)
        side = ax.cross(d).normalized()
        secs = []
        for t in (0.0, 0.35, 0.7, 1.0):
            r = 0.045 + (Rm - 0.012 - 0.045) * t
            depth = -0.024 * (1.0 - t) ** 1.5
            w = 0.026 - 0.01 * t
            th = 0.0075 - 0.002 * t
            cc = C + d * r + ax * depth
            secs.append([b.vert(cc + side * (w * math.cos(TAU * k / 10)) + ax * (th * math.sin(TAU * k / 10))) for k in range(10)])
        for a, c in zip(secs, secs[1:]):
            b.bridge(a, c, 0)
    layers = [(0.012, 0.9), (-0.012, 1.0), (-0.03, 0.97), (-0.04, 0.55)]
    made = []
    for depth, k in layers:
        ring = []
        for j in range(32):
            t = TAU * j / 32
            cx, sx = math.cos(t), math.sin(t)
            ex = abs(cx) ** 0.5 * (1 if cx >= 0 else -1)
            ey = abs(sx) ** 0.5 * (1 if sx >= 0 else -1)
            ring.append(b.vert(C + ax * depth + u * (0.062 * k * ex) + v * (0.048 * k * ey)))
        made.append(ring)
    for a, c in zip(made, made[1:]):
        b.bridge(a, c, 0)
    b.cap(made[-1], C + ax * -0.04, 0)
    b.cap(made[0], C + ax * 0.012, 0)
    ob = b.to_object(name, [material], sharp_deg=50.0)
    # The pivot is the box centre (Vehicle turns it there): keep it on the column.
    return ob


# --- Lamps, plates, mirrors ----------------------------------------------------------------

def lamp_round(prefix, centre, facing, r, depth=0.08, housing_mat=None, lamp_mat=None, lens_mat=None, ring_mat=None):
    """A round lamp facing `facing`: a chrome reflector bowl ("Lamp_<prefix>", glows),
    a fluted lens cover ("Lens_<prefix>"), a bezel ring and a housing."""
    c = Vector(centre)
    f = Vector(facing).normalized()
    obs = []
    lamp_mat = lamp_mat or mat("Lamp_Reflector", (0.85, 0.85, 0.82), 1.0, 0.12)
    lens_mat = lens_mat or mat("Lens_Clear", (0.95, 0.95, 0.95), 0.0, 0.05, alpha=0.25)
    ring_mat = ring_mat or mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12)
    prof = [(-depth * 0.9, r * 0.25), (-depth * 0.6, r * 0.62), (-depth * 0.3, r * 0.86), (-0.004, r * 0.97)]
    bowl = revolve("Lamp_" + prefix, prof, c, f, lamp_mat, 28, cap=False)
    obs.append(bowl)
    lens = revolve("Lens_" + prefix, [(0.0, r * 0.98), (0.006, r * 0.9), (0.012, r * 0.6), (0.014, 0.0)], c, f, lens_mat, 28, cap=False)
    obs.append(lens)
    ring = revolve("Bezel_" + prefix, [(-0.01, r * 1.1), (0.004, r * 1.08), (0.012, r * 1.0), (0.004, r * 0.97), (-0.004, r * 0.97)],
                   c, f, ring_mat, 28, cap=False)
    obs.append(ring)
    if housing_mat is not None:
        obs.append(revolve("Housing_" + prefix, [(-depth * 1.2, r * 0.6), (-depth, r * 1.05), (-0.01, r * 1.1)], c, f, housing_mat, 24))
    return obs


def lamp_rect(prefix, centre, facing, w, h, lamp_mat, depth=0.03, bezel_mat=None, lens_mat=None, ribs=0):
    """A rectangular lamp face (w across, h up) facing `facing`: the glowing face
    "Lamp_<prefix>" (optionally ribbed), a bezel, optionally a clear lens."""
    c = Vector(centre)
    f = Vector(facing).normalized()
    up = Vector((0.0, 0.0, 1.0))
    ac = up.cross(f).normalized()
    obs = []
    rot = Matrix((ac, up, f)).transposed()
    face = box("Lamp_" + prefix, c - f * (depth * 0.5), (w, h, depth), lamp_mat, bevel=min(w, h) * 0.08, segs=2, rot=rot)
    obs.append(face)
    if ribs:
        for k in range(ribs):
            zz = -h * 0.5 + h * (k + 0.5) / ribs
            obs.append(box("Lamp_" + prefix + "_rib%d" % k, c + up * zz + f * 0.002, (w * 0.96, h / ribs * 0.35, 0.006),
                           lamp_mat, rot=rot))
    if bezel_mat is not None:
        bw = 0.012
        for sx, sy, ww, hh in ((0, 1, w + 2 * bw, bw), (0, -1, w + 2 * bw, bw), (1, 0, bw, h), (-1, 0, bw, h)):
            p = c + ac * (sx * (w + bw) * 0.5) + up * (sy * (h + bw) * 0.5) - f * 0.005
            obs.append(box("Bezel_" + prefix, p, (ww, hh, depth + 0.012), bezel_mat, rot=rot))
    if lens_mat is not None:
        obs.append(box("Lens_" + prefix, c + f * 0.004, (w, h, 0.006), lens_mat, rot=rot))
    return obs


def plate(name, centre, outward, material=None, size=(0.34, 0.16)):
    """A number plate backing with its face towards `outward` (±X); the game prints the
    Turkish plate onto its face (its glTF +z)."""
    material = material or mat("Trim_PlateHolder", (0.05, 0.05, 0.05), 0.0, 0.5)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((size[0], 0.012, size[1])), verts=bm.verts)
    _bevel_all(bm, 0.004, 1)
    ob = from_bm(name, bm, material, 30.0)
    # Face at local -y (the glTF +z): turned so it looks along `outward`.
    ang = math.pi * 0.5 if outward[0] > 0 else -math.pi * 0.5
    ob.matrix_world = Matrix.Translation(Vector(centre)) @ Matrix.Rotation(ang, 4, "Z")
    return ob


def mirror_arm(prefix, base, head, head_size, housing_mat, glass_mat):
    """A door mirror: an arm from `base` to a head centred at `head` (glass facing back)."""
    obs = [tube(prefix + "_arm", [base, (Vector(base) + Vector(head)) * 0.5 + Vector((0, 0, 0.02)), head], 0.011, housing_mat, 8)]
    h = Vector(head)
    obs.append(box(prefix + "_head", h, head_size, housing_mat, bevel=0.02, segs=2))
    obs.append(box(prefix + "_glass", h + Vector((-head_size[0] * 0.5 - 0.001, 0, 0)),
                   (0.004, head_size[1] * 0.86, head_size[2] * 0.84), glass_mat))
    return obs


# --- Export and preview ------------------------------------------------------------------

def export(obs, path) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        apply(o)
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
            export_apply=True, export_normals=True, export_tangents=False, export_materials="EXPORT",
            export_image_format="NONE", export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in obs if o.type == "MESH")
    print("wrote", path, "objects", len(obs), "tris", tris)


def preview(path_prefix, centre=(0.0, 0.0, 0.8), dist=8.0, views=("front3q", "back3q", "side")) -> None:
    """Workbench renders of the scene (shape checks while modelling)."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 1200, 800
    c = Vector(centre)
    dirs = {"front3q": Vector((0.8, -0.65, 0.35)), "back3q": Vector((-0.8, 0.6, 0.4)), "side": Vector((0.0, -1.0, 0.12)),
            "front": Vector((1.0, 0.0, 0.1)), "top": Vector((0.0, 0.0, 1.0)), "back": Vector((-1.0, 0.0, 0.15)),
            "left3q": Vector((0.7, 0.75, 0.3))}
    for name in views:
        d = dirs[name].normalized()
        data = bpy.data.cameras.new(name)
        data.lens = 50
        cam = bpy.data.objects.new(name, data)
        sc.collection.objects.link(cam)
        pos = c + d * dist
        fwd = (c - pos).normalized()
        up = Vector((0, 0, 1)) if abs(fwd.z) < 0.99 else Vector((1, 0, 0))
        right = fwd.cross(up).normalized()
        m = Matrix((right, right.cross(fwd), -fwd)).transposed()
        cam.matrix_world = Matrix.Translation(pos) @ m.to_4x4()
        sc.camera = cam
        sc.render.filepath = "%s_%s.png" % (path_prefix, name)
        bpy.ops.render.render(write_still=True)


# --- Boxy bodies ---------------------------------------------------------------------------

def plan_outline(x0, x1, hw, r, n=5, rr=None):
    """A rounded rectangle in plan (x from x1 at the back to x0 at the front, y +-hw),
    front corners rounded by r and rear ones by rr (default r), n segments a corner;
    anticlockwise seen from above, starting at the front centre."""
    rr = r if rr is None else rr
    pts = [(x0, 0.0)]

    def arc(cx, cy, rad, a0, a1):
        for k in range(n + 1):
            a = a0 + (a1 - a0) * k / n
            pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    arc(x0 - r, hw - r, r, 0.0, math.pi * 0.5)
    arc(x1 + rr, hw - rr, rr, math.pi * 0.5, math.pi)
    arc(x1 + rr, -hw + rr, rr, math.pi, math.pi * 1.5)
    arc(x0 - r, -hw + r, r, math.pi * 1.5, math.pi * 2.0)
    return pts


def plan_loft(name, levels, material, cap_bottom=True, cap_top=True, smooth=35.0, top_bevel=0.0, top_segs=3):
    """A solid through horizontal outlines [(z, [(x, y), ...]), ...] (the same count each),
    the roof edge rounded by `top_bevel`."""
    bm = bmesh.new()
    rings = [[bm.verts.new((x, y, z)) for x, y in pts] for z, pts in levels]
    n = len(levels[0][1])
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    top = None
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        top = bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if top_bevel > 0.0 and top is not None:
        bmesh.ops.bevel(bm, geom=list(top.edges), offset=top_bevel, offset_type="OFFSET", segments=top_segs,
                profile=0.5, affect="EDGES", clamp_overlap=True)
    return from_bm(name, bm, material, smooth)


def solidify(ob, thickness, offset=-1.0):
    md = ob.modifiers.new("solid", "SOLIDIFY")
    md.thickness = thickness
    md.offset = offset
    md.use_rim = True
    md.use_even_offset = True
    return md


def strip(name, a, b, width, depth, material, normal):
    """A thin strip (a panel gap, a seal, a trim line) from a to b lying on a surface
    whose outward normal is `normal`: `width` across, standing `depth` proud."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    ln = d.length
    d.normalize()
    n = Vector(normal).normalized()
    s = n.cross(d).normalized()
    m = Matrix((d, s, n)).transposed()
    return box(name, (a + b) * 0.5 + n * (depth * 0.5 - 0.0005), (ln, width, depth), material, rot=m)


def pane(name, corners, material, inset=0.0, normal=None):
    """A window pane through four corners (0..1 UVs across it), pushed `inset` along
    -normal."""
    c = [Vector(p) for p in corners]
    if normal is not None and inset:
        c = [p - Vector(normal).normalized() * inset for p in c]
    ob = sheet(name, c, material)
    uv_pane(ob)
    return ob


def seal(name, corners, width, material, normal, depth=0.012):
    """A rubber seal round a pane's four corners."""
    obs = []
    c = [Vector(p) for p in corners]
    for i in range(4):
        obs.append(strip(name, c[i], c[(i + 1) % 4], width, depth, material, normal))
    return join(obs, name)
