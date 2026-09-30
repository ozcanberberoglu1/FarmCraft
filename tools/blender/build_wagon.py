"""Builds the dealership's old estate car (the "Atmaca 1600 SW", a boxy mid-eighties
family estate of the kind half the farmers in Anatolia drove): art/models/vehicles/wagon/wagon.glb.

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_wagon.py [-- --preview=/abs/dir]

Modelled here from primitives (no outside assets) in the model frame of
tools/blender/vehicle_kit.py (front +X, left +Y, up +Z, ground z = 0), rear axle at x = 0:
- the lower body is its side profile extruded and rounded, the wheel arches cut out and
  lined, the cabin hollowed; the glasshouse a thin shell lofted from its plan at the
  waistline to the roof (the sides lean in), its windows cut out, with flush panes in
  rubber seals; panel gaps round the doors, bonnet and tailgate, a rubbing strip;
- chrome wrap-round bumpers with rubber inserts, a black grille with the badge,
  rectangular headlamps and indicators, vertical tail-lamp clusters, number plates,
  door mirrors and handles, wipers, a roof rack, an aerial, mud flaps and the exhaust;
- the cab: dash with its binnacle and dials, the steering wheel, tan vinyl bucket seats,
  door cards, headliner and carpet; the rear bench folded flat into a load floor;
- 13-inch steel wheels (the pickup's modelled wheel scaled down, build_pickup_hd.py).
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_kit as K  # noqa: E402

OUT = os.path.join(K.ROOT, "art/models/vehicles/wagon/wagon.glb")

WB = 2.49
R, W = 0.2875, 0.175
TRACK = 0.69
HW = 0.82            # half width of the lower body
BELT = 0.885         # waistline
ROOF = 1.40
GH_BOT = 0.84        # the glasshouse starts a little under the waist
GH_W0, GH_W1 = 0.785, 0.665   # its half width at GH_BOT and at the roof
WS_X0, WS_X1 = 1.70, 0.98     # windshield line: x at GH_BOT and at the roof
REAR_X0, REAR_X1 = -1.0, -0.975


def paint():
    return K.mat("Wagon_Bodymat", (0.6, 0.52, 0.36), 0.2, 0.4)


def rubber():
    return K.mat("Trim_Rubber", (0.025, 0.025, 0.025), 0.0, 0.8)


def chrome():
    return K.mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12)


def black_plastic():
    return K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.5)


def gap():
    return K.mat("Trim_Gap", (0.008, 0.008, 0.008), 0.0, 0.9)


def interior(kind, color, rough=0.7, metal=0.0):
    return K.mat("Interior_" + kind, color, metal, rough)


def ws_x(z):
    """The windshield's x at height z (its outer surface, the middle)."""
    return WS_X0 + (z - GH_BOT) * (WS_X1 - WS_X0) / (ROOF - GH_BOT)


def gh_w(z):
    return GH_W0 + (z - GH_BOT) * (GH_W1 - GH_W0) / (ROOF - GH_BOT)


def rear_x(z):
    return REAR_X0 + (z - GH_BOT) * (REAR_X1 - REAR_X0) / (ROOF - GH_BOT)


def hood_z(x):
    """The bonnet's top at x (the side profile's top line in front of the windshield)."""
    pts = [(1.66, 0.875), (2.4, 0.845), (3.18, 0.787)]
    if x <= pts[0][0]:
        return pts[0][1]
    for (xa, za), (xb, zb) in zip(pts, pts[1:]):
        if xa <= x <= xb:
            return za + (zb - za) * (x - xa) / (xb - xa)
    return pts[-1][1]


def lower_body():
    prof = [(-0.96, 0.25), (3.1, 0.24), (3.22, 0.3), (3.265, 0.46), (3.262, 0.765), (3.18, 0.787), (2.4, 0.845),
            (1.66, 0.875), (0.4, BELT), (-0.97, BELT), (-1.045, 0.86), (-1.062, 0.52), (-1.04, 0.31)]
    body = K.prism("lower", prof, -HW, HW, paint(), plane="XZ", bevel=0.05, segs=4, smooth=35.0)
    cutters = []
    for x in (0.0, WB):
        cutters.append(K.cyl("arch", (x, -1.2, R), (x, 1.2, R), R + 0.06, paint(), 40))
    cutters.append(K.box("cabin", (0.29, 0.0, 0.72), (2.52, 2 * (HW - 0.05), 0.66), paint()))
    for c in cutters:
        K.cut(body, c)
    K.apply(body)
    K.remove(*cutters)
    obs = [body]
    # Arch liners and lips.
    for x in (0.0, WB):
        for side in (1.0, -1.0):
            pts = []
            for k in range(17):
                a = math.radians(-10 + 200 * k / 16)
                pts.append((x + (R + 0.055) * math.cos(a), R + (R + 0.055) * math.sin(a)))
            sections = []
            for yy in (side * 0.55, side * (HW - 0.01)):
                sections.append([(px, yy, pz) for px, pz in pts])
            liner = K.loft("liner", sections, K.mat("Trim_Liner", (0.02, 0.02, 0.02), 0.0, 0.9), closed=False, cap=False)
            obs.append(liner)
    return obs


def glasshouse():
    lo = K.plan_outline(WS_X0, REAR_X0, GH_W0, 0.09, 5, 0.1)
    hi = K.plan_outline(WS_X1, REAR_X1, GH_W1, 0.06, 5, 0.06)
    gh = K.plan_loft("glasshouse", [(GH_BOT, lo), (ROOF, hi)], paint(), cap_bottom=False, top_bevel=0.045, smooth=35.0)
    K.solidify(gh, 0.02)
    K.apply(gh)
    cutters = []
    # Windshield: a slab along its plane, the A-pillars left standing.
    zs = (0.93, 1.345)
    secs = []
    for z in zs:
        x = ws_x(z)
        w = gh_w(z) - 0.085
        secs.append([(x + 0.15, -w, z), (x + 0.15, w, z), (x - 0.15, w, z), (x - 0.15, -w, z)])
    cutters.append(K.loft("ws_cut", secs, paint(), smooth=None))
    for side in (1.0, -1.0):
        for poly in windows():
            c = K.prism("side_cut", poly, side * 0.5, side * 1.0, paint(), plane="XZ")
            cutters.append(c)
    cutters.append(K.box("rear_cut", (REAR_X0, 0.0, 1.13), (0.2, 2 * 0.575, 0.4), paint()))
    for c in cutters:
        K.cut(gh, c)
    K.apply(gh)
    K.remove(*cutters)
    return gh


def windows():
    """Side window openings (XZ): front door, rear door, rear quarter."""
    a0, a1 = 0.93, 1.335
    front = [(0.56, a0), (ws_x(a0) - 0.12, a0), (ws_x(a1) - 0.1, a1), (0.56, a1)]
    rear = [(-0.34, a0), (0.46, a0), (0.46, a1), (-0.34, a1)]
    quarter = [(-0.9, a0), (-0.44, a0), (-0.44, a1), (-0.9, a1)]
    return [front, rear, quarter]


def glazing():
    """Panes in the openings, flush under the seals."""
    obs = []
    glass = K.mat("Glass_Clear", (0.86, 0.9, 0.9), 0.0, 0.05, alpha=0.2)
    names = ["F", "R", "Q"]
    for side, s in ((1.0, "L"), (-1.0, "R")):
        for poly, n in zip(windows(), names):
            corners = []
            for x, z in poly:
                corners.append((x, side * (gh_w(z) - 0.014), z))
            # A little larger than the opening, under the seal.
            cx = sum(p[0] for p in corners) / 4
            cz = sum(p[2] for p in corners) / 4
            big = [(cx + (p[0] - cx) * 1.02, p[1], cz + (p[2] - cz) * 1.04) for p in corners]
            # The side leans in: its outward normal tips up.
            normal = Vector((0.0, side, (GH_W0 - GH_W1) / (ROOF - GH_BOT))).normalized()
            obs.append(K.pane("Glass_%s%s" % (n, s), big, glass))
            obs.append(K.seal("seal", [(x, side * (gh_w(z) + 0.001), z) for x, z in poly], 0.016, rubber(), normal, 0.008))
    # Windshield and the tailgate glass.
    z0, z1 = 0.93, 1.345
    w0 = gh_w(z0) - 0.075
    w1 = gh_w(z1) - 0.075
    n_ws = Vector((ROOF - GH_BOT, 0.0, WS_X0 - WS_X1)).normalized()
    corners = [(ws_x(z0) - 0.012, -w0, z0), (ws_x(z0) - 0.012, w0, z0), (ws_x(z1) - 0.012, w1, z1), (ws_x(z1) - 0.012, -w1, z1)]
    obs.append(K.pane("Windshield", corners, glass))
    obs.append(K.seal("seal", [(ws_x(z0) + 0.002, -w0, z0), (ws_x(z0) + 0.002, w0, z0), (ws_x(z1) + 0.002, w1, z1),
                               (ws_x(z1) + 0.002, -w1, z1)], 0.02, rubber(), n_ws, 0.008))
    rz0, rz1 = 0.93, 1.33
    corners = [(rear_x(rz0) + 0.012, 0.585, rz0), (rear_x(rz0) + 0.012, -0.585, rz0), (rear_x(rz1) + 0.012, -0.585, rz1),
               (rear_x(rz1) + 0.012, 0.585, rz1)]
    obs.append(K.pane("Glass_Rear", corners, glass))
    obs.append(K.seal("seal", [(rear_x(z) - 0.002, y, z) for x, y, z in corners], 0.02, rubber(), (-1.0, 0.0, 0.0), 0.008))
    return obs


def gaps_and_trim():
    obs = []
    g = gap()
    for side in (1.0, -1.0):
        y = side * (HW + 0.0005)
        n = (0.0, side, 0.0)
        for x in (1.56, 0.51, -0.39):
            z0 = 0.3 if x > 0.4 else 0.44
            obs.append(K.strip("gap", (x, y, z0), (x, y, BELT - 0.02), 0.004, 0.0015, g, n))
            # Up the pillar to the roof.
            obs.append(K.strip("gap", (x if x < 1.5 else x, side * (gh_w(BELT) + 0.001), BELT + 0.01),
                               (x if x < 1.5 else x, side * (gh_w(1.36) + 0.001), 1.36), 0.004, 0.0015, g,
                               (0.0, side, (GH_W0 - GH_W1) / (ROOF - GH_BOT))) if x < 1.5 else None)
        # The doors' bottom edges: the front door's along the sill, the rear door's
        # round the wheel arch.
        obs.append(K.strip("gap", (0.44, y, 0.3), (1.56, y, 0.3), 0.004, 0.0015, g, n))
        ra = R + 0.13
        arc = [(0.44, 0.3)]
        for k in range(13):
            a = math.radians(5 + 154 * k / 12)
            arc.append((ra * math.cos(a), R + ra * math.sin(a)))
        for (xa, za), (xb, zb) in zip(arc, arc[1:]):
            if xb < -0.39:
                break
            obs.append(K.strip("gap", (xa, y, za), (xb, y, zb), 0.004, 0.0015, g, n))
        # Rubbing strip with a chrome insert along the doors and wings, broken at the arches.
        for x0, x1 in ((-0.92, -0.25), (0.25, 2.25), (2.73, 3.1)):
            obs.append(K.strip("rub", (x0, side * (HW + 0.001), 0.56), (x1, side * (HW + 0.001), 0.56), 0.045, 0.012, black_plastic(), n))
            obs.append(K.strip("rub_chrome", (x0 + 0.02, side * (HW + 0.012), 0.56), (x1 - 0.02, side * (HW + 0.012), 0.56), 0.008, 0.003, chrome(), n))
        # Door handles (pull-out chrome), the fuel flap on the right rear wing.
        for x in (0.66, -0.25):
            obs.append(K.box("handle", (x, side * (HW + 0.008), BELT - 0.09), (0.11, 0.014, 0.024), chrome(), bevel=0.006))
        # Bonnet edges.
        pts = [(1.7 + k * 0.1, hood_z(1.7 + k * 0.1)) for k in range(15)] + [(3.17, hood_z(3.17))]
        for (xa, za), (xb, zb) in zip(pts, pts[1:]):
            nn = Vector((-(zb - za), 0.0, xb - xa)).normalized()
            obs.append(K.strip("hood_gap", (xa, side * 0.74, za + 0.0005), (xb, side * 0.74, zb + 0.0005), 0.004, 0.0015, g, nn))
    obs.append(K.strip("fuel", (-0.72, -HW - 0.0005, 0.64), (-0.6, -HW - 0.0005, 0.64), 0.1, 0.0015, K.mat("Wagon_Bodymat", (0.6, 0.52, 0.36), 0.2, 0.4), (0, -1, 0)))
    for x0, x1 in ((-0.72, -0.6),):
        for z in (0.59, 0.69):
            obs.append(K.strip("gap", (x0, -HW - 0.002, z), (x1, -HW - 0.002, z), 0.003, 0.0015, g, (0, -1, 0)))
    # Bonnet's rear and front edge, tailgate outline.
    obs.append(K.strip("gap", (1.72, -0.74, hood_z(1.72) + 0.001), (1.72, 0.74, hood_z(1.72) + 0.001), 0.004, 0.0015, g, (0.05, 0, 1)))
    for side in (1.0, -1.0):
        obs.append(K.strip("gap", (-1.0625, side * 0.73, 0.42), (-1.05, side * 0.73, BELT - 0.03), 0.004, 0.0015, g, (-1, 0, 0)))
    obs.append(K.strip("gap", (-1.0625, -0.73, 0.42), (-1.0625, 0.73, 0.42), 0.004, 0.0015, g, (-1, 0, 0)))
    return [o for o in obs if o is not None]


def bumper(x_face, wrap_x, z0, z1, front):
    """A chrome bar wrapping round the corners with a black rubber insert."""
    obs = []
    d = 1.0 if front else -1.0
    outer = []
    inner = []
    n = 8
    r = 0.16
    # The plan path: along one side from wrap_x, round the corner, across, back.
    path = []
    for side in (1.0, -1.0):
        seg = [(wrap_x, side * (HW + 0.03))]
        for k in range(n + 1):
            a = math.pi * 0.5 * k / n
            seg.append((x_face - d * r + d * r * math.sin(a), side * (HW + 0.03 - r + r * math.cos(a))))
        path.append(seg if side > 0 else list(reversed(seg)))
    pts = path[0] + path[1]
    # Offset inwards for the back face (a C-section 7 cm deep).
    for i, (x, y) in enumerate(pts):
        a = Vector(pts[max(i - 1, 0)])
        b = Vector(pts[min(i + 1, len(pts) - 1)])
        t = (b - a).normalized()
        nrm = Vector((t.y, -t.x)) * (1.0 if front else -1.0)
        outer.append((x, y))
        inner.append((x - nrm.x * 0.07, y - nrm.y * 0.07))
    outline = outer + list(reversed(inner))
    bar = K.plan_loft("bumper", [(z0, outline), (z1, outline)], chrome(), top_bevel=0.012, smooth=40.0)
    K.bevel_mod(bar, 0.012, 2, 40.0)
    obs.append(bar)
    # Rubber insert.
    ins_o = []
    ins_i = []
    for (x, y), (xi, yi) in zip(outer, inner):
        v = Vector((x - xi, y - yi)).normalized()
        ins_o.append((x + v.x * 0.01, y + v.y * 0.01))
        ins_i.append((x - v.x * 0.01, y - v.y * 0.01))
    zi = (z0 + z1) * 0.5
    obs.append(K.plan_loft("bumper_rubber", [(zi - 0.02, ins_o + list(reversed(ins_i))), (zi + 0.02, ins_o + list(reversed(ins_i)))],
                           black_plastic(), smooth=40.0))
    return obs


def front_end():
    obs = bumper(3.33, 3.0, 0.36, 0.48, True)
    # Grille: black slats in a frame between the lamps, the badge.
    gx = 3.262
    obs.append(K.box("grille_back", (gx - 0.02, 0.0, 0.655), (0.04, 0.74, 0.19), K.mat("Trim_Grille", (0.015, 0.015, 0.015), 0.2, 0.6)))
    for k in range(6):
        obs.append(K.box("slat", (gx + 0.004, 0.0, 0.585 + k * 0.028), (0.014, 0.72, 0.01), black_plastic(), bevel=0.003, segs=1))
    obs.append(K.box("grille_frame_t", (gx + 0.006, 0.0, 0.753), (0.02, 0.76, 0.014), chrome(), bevel=0.005))
    obs.append(K.box("grille_frame_b", (gx + 0.006, 0.0, 0.557), (0.02, 0.76, 0.014), chrome(), bevel=0.005))
    obs.append(K.box("badge", (gx + 0.018, 0.0, 0.655), (0.012, 0.13, 0.06), chrome(), bevel=0.012, segs=2))
    obs.append(K.box("badge_in", (gx + 0.023, 0.0, 0.655), (0.004, 0.1, 0.04), K.mat("Trim_BadgeRed", (0.45, 0.04, 0.03), 0.3, 0.3)))
    head = K.mat("Lamp_HeadReflector", (0.85, 0.85, 0.82), 1.0, 0.12)
    lens = K.mat("Lens_Clear", (0.95, 0.95, 0.95), 0.0, 0.05, alpha=0.25)
    for side, s in ((1.0, "L"), (-1.0, "R")):
        obs += K.lamp_rect("Head_" + s, (gx + 0.002, side * 0.575, 0.66), (1, 0, 0), 0.33, 0.15, head, depth=0.03,
                           bezel_mat=chrome(), lens_mat=lens)
        obs.append(K.box("ind", (3.3, side * 0.62, 0.535), (0.02, 0.13, 0.045), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1), bevel=0.006))
        obs.append(K.box("side_rep", (2.95, side * (HW + 0.004), 0.66), (0.06, 0.01, 0.025), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1), bevel=0.005))
    obs.append(K.plate("Numberplate_Front", (3.35, 0.0, 0.42), (1, 0, 0)))
    # Wipers, aerial.
    for y0, y1 in ((0.52, -0.02), (-0.06, -0.58)):
        obs.append(K.tube("wiper", [(ws_x(0.9) + 0.03, y0, 0.905), (ws_x(0.915) + 0.02, y1, 0.92)], 0.006, black_plastic(), 6))
        obs.append(K.cyl("wiper_pivot", (ws_x(0.9) + 0.06, y0, 0.89), (ws_x(0.9) + 0.06, y0, 0.915), 0.012, black_plastic(), 10))
    obs.append(K.tube("aerial", [(2.95, -0.72, 0.8), (2.62, -0.74, 1.62)], 0.0025, chrome(), 5))
    obs.append(K.cyl("aerial_base", (2.95, -0.72, 0.795), (2.95, -0.72, 0.82), 0.012, black_plastic(), 10))
    return obs


def rear_end():
    obs = bumper(-1.13, -0.82, 0.34, 0.46, False)
    red = K.mat("Lamp_Red", (0.45, 0.02, 0.015), 0.0, 0.15)
    white = K.mat("Lamp_White", (0.8, 0.8, 0.78), 0.0, 0.1)
    for side, s in ((1.0, "L"), (-1.0, "R")):
        c = Vector((-1.063, side * 0.69, 0.68))
        obs.append(K.box("tail_house", c + Vector((0.01, 0, 0)), (0.02, 0.2, 0.36), black_plastic(), bevel=0.01))
        obs += K.lamp_rect("Brake_" + s, c + Vector((-0.004, 0, 0.1)), (-1, 0, 0), 0.17, 0.13, red, depth=0.012, ribs=4)
        obs.append(K.box("tail_amber", c + Vector((-0.006, 0, -0.03)), (0.01, 0.17, 0.09), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1), bevel=0.004))
        obs += K.lamp_rect("Reverse_" + s, c + Vector((-0.004, side * -0.03, -0.125)), (-1, 0, 0), 0.1, 0.06, white, depth=0.012)
        obs.append(K.box("reflector", c + Vector((-0.004, side * 0.06, -0.125)), (0.008, 0.05, 0.06), K.mat("Trim_Reflector", (0.6, 0.02, 0.02), 0.0, 0.15)))
    obs.append(K.plate("Numberplate_Rear", (-1.07, 0.0, 0.56), (-1, 0, 0)))
    obs.append(K.box("tail_handle", (-1.07, 0.0, 0.67), (0.02, 0.26, 0.03), chrome(), bevel=0.008))
    obs.append(K.cyl("lock", (-1.064, 0.16, 0.67), (-1.08, 0.16, 0.67), 0.012, chrome(), 10))
    # Exhaust, mud flaps.
    obs.append(K.cyl("exhaust", (-0.7, 0.42, 0.24), (-1.12, 0.42, 0.25), 0.024, K.mat("Trim_Exhaust", (0.09, 0.05, 0.03), 0.4, 0.75), 12))
    for side in (1.0, -1.0):
        obs.append(K.box("flap", (-0.37, side * 0.7, 0.2), (0.008, 0.2, 0.22), rubber(), bevel=0.003))
    return obs


def mirrors_and_rack():
    obs = []
    for side in (1.0, -1.0):
        obs += K.mirror_arm("mirror", (1.44, side * (HW - 0.01), BELT + 0.02), (1.4, side * (HW + 0.09), BELT + 0.07),
                            (0.05, 0.13, 0.09), black_plastic(), K.mat("Trim_Mirror", (0.9, 0.9, 0.9), 1.0, 0.03))
        # Roof rack: galvanised rails on feet.
        y = side * 0.58
        obs.append(K.cyl("rail", (-0.86, y, ROOF + 0.06), (0.82, y, ROOF + 0.06), 0.014, K.mat("Trim_Galv", (0.55, 0.56, 0.56), 0.9, 0.42), 10))
        for x in (-0.82, 0.0, 0.78):
            obs.append(K.box("rack_foot", (x, y, ROOF + 0.02), (0.05, 0.04, 0.08), black_plastic(), bevel=0.01))
    for x in (-0.6, 0.0, 0.6):
        obs.append(K.cyl("crossbar", (x, 0.6, ROOF + 0.075), (x, -0.6, ROOF + 0.075), 0.012, K.mat("Trim_Galv", (0.55, 0.56, 0.56), 0.9, 0.42), 8))
    return obs


def cab():
    obs = []
    carpet = interior("Carpet", (0.07, 0.065, 0.06), 0.95)
    dash = interior("Dash", (0.035, 0.035, 0.04), 0.6)
    vinyl = interior("Vinyl", (0.36, 0.21, 0.1), 0.55)
    card = interior("DoorCard", (0.3, 0.19, 0.1), 0.65)
    head = interior("Headliner", (0.55, 0.53, 0.48), 0.9)
    obs.append(K.box("floor", (0.3, 0.0, 0.39), (2.6, 2 * (HW - 0.05), 0.02), carpet))
    obs.append(K.box("tunnel", (0.9, 0.0, 0.44), (1.2, 0.2, 0.1), carpet, bevel=0.04))
    # Load floor over the folded rear bench, to the tailgate.
    obs.append(K.box("load_floor", (-0.27, 0.0, 0.53), (1.42, 2 * (HW - 0.06), 0.04), carpet, bevel=0.01))
    obs.append(K.box("load_riser", (-0.27, 0.0, 0.45), (1.42, 2 * (HW - 0.07), 0.12), dash))
    # Dash with the binnacle and dials, the column and the wheel.
    obs.append(K.box("dash", (1.5, 0.0, 0.8), (0.3, 2 * (HW - 0.06), 0.2), dash, bevel=0.04, segs=3))
    obs.append(K.box("dash_low", (1.48, 0.0, 0.62), (0.2, 1.2, 0.18), dash, bevel=0.03))
    obs.append(K.box("binnacle", (1.39, 0.36, 0.93), (0.12, 0.4, 0.08), dash, bevel=0.03, segs=3))
    face = interior("Gauge", (0.7, 0.7, 0.66), 0.3)
    for y in (0.27, 0.45):
        obs.append(K.cyl("dial", (1.336, y, 0.905), (1.33, y, 0.905), 0.055, face, 24))
    obs.append(K.cyl("column", (1.44, 0.36, 0.86), (1.19, 0.36, 0.975), 0.03, dash, 12))
    # Front bucket seats in tan vinyl, the folded bench's back behind them.
    for y in (0.36, -0.36):
        obs.append(K.box("cushion", (0.82, y, 0.53), (0.5, 0.48, 0.13), vinyl, bevel=0.04, segs=3))
        obs.append(K.box("back", (0.54, y, 0.86), (0.11, 0.47, 0.56), vinyl, bevel=0.04, segs=3, rot=(0.0, math.radians(-14), 0.0)))
        obs.append(K.box("headrest", (0.47, y, 1.2), (0.08, 0.26, 0.17), vinyl, bevel=0.03, segs=3, rot=(0.0, math.radians(-10), 0.0)))
        obs.append(K.box("seat_base", (0.8, y, 0.43), (0.4, 0.36, 0.08), dash))
    obs.append(K.box("gear_boot", (1.05, 0.0, 0.5), (0.1, 0.1, 0.03), dash))
    obs.append(K.tube("gear", [(1.05, 0.0, 0.5), (1.02, 0.0, 0.7)], 0.008, K.mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12), 8))
    obs.append(K.cyl("knob", (1.02, 0.0, 0.69), (1.02, 0.0, 0.74), 0.02, dash, 12))
    # Door cards, headliner, the mirror at the top of the windshield.
    for side in (1.0, -1.0):
        obs.append(K.box("card", (0.58, side * (HW - 0.055), 0.66), (1.9, 0.02, 0.42), card, bevel=0.01))
        obs.append(K.box("armrest", (0.9, side * (HW - 0.075), 0.72), (0.3, 0.04, 0.04), card, bevel=0.012))
    obs.append(K.box("headliner", (0.0, 0.0, ROOF - 0.035), (1.9, 2 * (GH_W1 - 0.04), 0.01), head))
    obs.append(K.box("rv_mirror", (ws_x(1.3) - 0.07, 0.0, 1.28), (0.02, 0.2, 0.06), dash, bevel=0.01))
    return obs


def main():
    a = K.args()
    K.reset()
    parts = lower_body() + [glasshouse()] + gaps_and_trim() + front_end() + rear_end() + mirrors_and_rack() + cab()
    panes = glazing()
    steer = K.steering("Steering_Wheel", (1.16, 0.36, 0.98), (1.0, 0.0, -0.36), 0.185, interior("Steer", (0.03, 0.03, 0.03), 0.5))
    wheels = [K.wheel("WheelStock_FL", (WB, TRACK, R), R, W), K.wheel("WheelStock_FR", (WB, -TRACK, R), R, W),
              K.wheel("WheelStock_RL", (0.0, TRACK, R), R, W), K.wheel("WheelStock_RR", (0.0, -TRACK, R), R, W)]
    everything = parts + panes
    lamps = [o for o in everything if o.name.startswith(("Lamp_", "Lens_"))]
    named = [o for o in everything if o.name.startswith(("Glass_", "Windshield", "Numberplate"))]
    rest = [o for o in everything if o not in lamps and o not in named]
    groups = {}
    for o in lamps:
        key = o.name.split(".")[0]
        role = "Lens" if key.startswith("Lens_") else "_".join(key.split("_")[:2])
        groups.setdefault(role, []).append(o)
    lamp_meshes = [K.join(v, k) for k, v in groups.items()]
    inside = [o for o in rest if o.data.materials and o.data.materials[0].name.startswith("Interior_")]
    body = K.join([o for o in rest if o not in inside], "Wagon_Body")
    cabin = K.join(inside, "Wagon_Cab")
    K.export([body, cabin, steer] + wheels + lamp_meshes + named, OUT)
    if a.get("preview"):
        K.preview(os.path.join(a["preview"], "wagon"), centre=(1.1, 0.0, 0.7), dist=8.0,
                  views=("front3q", "back3q", "side", "left3q"))


if __name__ == "__main__":
    main()
