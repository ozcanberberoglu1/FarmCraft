"""Builds the dealership's compact farm tractor (the "Tarla 45", an 1980s 45 hp
two-wheel-drive utility tractor): art/models/vehicles/tractor/tractor.glb.

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_tractor.py [-- --preview=/abs/dir]

Modelled here from primitives (no outside assets), in the model frame of
tools/blender/vehicle_kit.py (front +X, left +Y, up +Z, the ground at z = 0), with the
rear axle at x = 0:
- bias-ply bar-lug drive tyres (12.4-28) on painted steel rims with a dished centre, bolted
  clamps and a hub; three-rib front tyres (6.00-16) on dished rims with hub caps;
- a red bonnet with louvred sides and a grille with the head lamps, the scuttle with the
  fuel filler and the dash, cast-iron engine, gearbox and rear axle, a front axle on its
  pivot and a stack of front weights, round fenders with lamps, chequer-plate footboards,
  a pan seat, a two-post roll bar, an upright exhaust, an air pre-cleaner, pedals and
  levers, the three-point linkage and a steel carry box on it (the load space).
The body is red paint ("Tractor_Bodymat"); cast iron, steel, rubber, the seat and the
lenses are trim ("Trim_*") and lamps, read by the game by name.
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_kit as K  # noqa: E402

hd = K.hd
TAU = math.tau
OUT = os.path.join(K.ROOT, "art/models/vehicles/tractor/tractor.glb")
RUBBER, RIM, HARDWARE, BRAKE = range(4)

# Axles: rear at x = 0, front at WB; hub heights are the tyre radii.
WB = 1.93
R_REAR, W_REAR, RIM_REAR = 0.635, 0.315, 0.3556
R_FRONT, W_FRONT, RIM_FRONT = 0.355, 0.16, 0.2032
TRACK_REAR = 0.71
TRACK_FRONT = 0.68


def paint():
    return K.mat("Tractor_Bodymat", (0.5, 0.06, 0.04), 0.1, 0.4)


def cast():
    return K.mat("Trim_Cast", (0.2, 0.21, 0.2), 0.35, 0.62)


def steel():
    return K.mat("Trim_Steel", (0.035, 0.036, 0.038), 0.55, 0.55)


def rubber():
    return K.mat("Trim_Rubber", (0.025, 0.025, 0.025), 0.0, 0.8)


def chrome():
    return K.mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12)


def black():
    return K.mat("Trim_BlackPaint", (0.02, 0.02, 0.022), 0.3, 0.38)


def seat_vinyl():
    return K.mat("Trim_Seat", (0.03, 0.03, 0.03), 0.0, 0.55)


def chequer():
    return K.mat("Trim_Chequer", (0.3, 0.3, 0.3), 0.8, 0.45)


def box_paint():
    return K.mat("Trim_CarryBox", (0.18, 0.19, 0.2), 0.45, 0.5)


# --- Tyres and wheels ---------------------------------------------------------------------

class AgTyre(hd.Tyre):
    """A bias-ply tractor tyre: a tall, round carcass of outer radius R (to the lug tops)
    and section width W on a rim of radius rim_r, bead half width bead_a, with bar lugs
    of height lug_h in a chevron (or, lug_h 0, three ribs for a front tyre)."""

    def __init__(self, R, W, rim_r, bead_a, lug_h):
        self.R, self.W, self.rim_r, self.rim_a, self.lug_h = R, W, rim_r, bead_a, lug_h
        hw = W * 0.5
        Rc = R - lug_h
        self.Rc = Rc
        H = Rc - rim_r
        ctrl = [(0.0, Rc), (0.35 * hw, Rc - 0.012 * H), (0.62 * hw, Rc - 0.06 * H), (0.84 * hw, Rc - 0.19 * H),
                (0.97 * hw, Rc - 0.4 * H), (hw, Rc - 0.56 * H), (0.96 * hw, Rc - 0.74 * H), (0.84 * hw, Rc - 0.88 * H),
                (bead_a + 0.02, rim_r + 0.028), (bead_a + 0.004, rim_r + 0.004)]
        self.half = hd.catmull(ctrl, 4)
        self.s = [0.0]
        for a, b in zip(self.half, self.half[1:]):
            self.s.append(self.s[-1] + math.dist(a, b))
        self.wall_top = Rc - 0.3 * H
        self.s_tread = self._s_at_y(0.9 * hw)

    def build_carcass(self, b, y0, ribs=False):
        full = [(-y, r) for y, r in reversed(self.half)] + [(y, r) for y, r in self.half[1:]]
        wall = self.wall_top

        def expo(y, r):
            if ribs:
                return 0.62 if r < wall else 0.0
            return 0.0 if r > wall else 0.62
        b.revolve([(y0 + y, r) for y, r in reversed(full)], RUBBER, 96, expo)

    def lug(self, b, y0, side, theta0, s_a, s_b, width, slope):
        """A bar lug on one half of the tread from arc length s_a to s_b (over the
        shoulder), leaning `slope` metres round the tyre per metre across."""
        h = self.lug_h
        n = 7
        rows = []
        for i in range(n + 1):
            t = i / n
            s = s_a + (s_b - s_a) * t
            (y, r), (ny, nr) = self.surf(s)
            arc = (s - s_a) * slope
            # The lug narrows a little towards its outer end.
            w = width * (1.0 - 0.18 * t)
            ring = []
            for dw, dh, e in ((-w * 0.5, -0.004, 0.35), (w * 0.5, -0.004, 0.35), (w * 0.4, h, 1.0), (-w * 0.4, h, 1.0)):
                th = theta0 + (arc + dw) / self.R
                rr = r + nr * dh
                ring.append(b.vert((rr * math.cos(th), y0 + side * (y + ny * dh), rr * math.sin(th)), e))
            rows.append(ring)
        for a, c in zip(rows, rows[1:]):
            for k in range(4):
                k2 = (k + 1) % 4
                if side > 0:
                    b.face((a[k], a[k2], c[k2], c[k]), RUBBER)
                else:
                    b.face((a[k], c[k], c[k2], a[k2]), RUBBER)
        for ring, flip in ((rows[0], side > 0), (rows[-1], side < 0)):
            b.face(tuple(reversed(ring)) if flip else tuple(ring), RUBBER)

    def build(self, b, y0, pitches, font, text):
        self.build_carcass(b, y0)
        s_end = self._s_at_y(0.985 * self.W * 0.5)
        for k in range(pitches):
            th = TAU * k / pitches
            for side in (1.0, -1.0):
                off = 0.0 if side > 0 else 0.5 * TAU / pitches
                self.lug(b, y0, side, th + off, 0.02, s_end, 0.052, 0.95)
        # Lettering on the outer wall.
        rt = self.rim_r + 0.55 * (self.wall_top - self.rim_r)
        for t, size, ang in text:
            self._text(b, y0, 1.0, font, t, size, rt, math.radians(ang))

    def build_ribbed(self, b, y0, font, text):
        """Three raised ribs round the crown (a front steering tyre)."""
        self.build_carcass(b, y0, ribs=True)
        hw = self.W * 0.5
        Rc = self.Rc
        for yc in (-0.34 * hw, 0.0, 0.34 * hw):
            prof = [(yc - 0.016, Rc - 0.004), (yc - 0.012, Rc + 0.016), (yc + 0.012, Rc + 0.016), (yc + 0.016, Rc - 0.004)]
            b.revolve([(y0 + y, r) for y, r in prof], RUBBER, 96, lambda y, r: 1.0 if r > Rc + 0.01 else 0.3)
        rt = self.rim_r + 0.55 * (self.wall_top - self.rim_r)
        for t, size, ang in text:
            self._text(b, y0, 1.0, font, t, size, rt, math.radians(ang))


def rear_rim(b, rim_r, a):
    """A painted steel rim with a dished centre disc on eight clamps and a hub."""
    hd.rim_barrel(b, 0.0, rim_r, a)
    # Clamp lugs welded inside the rim, the disc bolted to them.
    yd = 0.02
    for k in range(8):
        th = TAU * (k + 0.5) / 8
        c = Vector((math.cos(th), 0.0, math.sin(th)))
        t = Vector((-math.sin(th), 0.0, math.cos(th)))
        base = c * (rim_r - 0.045)
        hd.prism(b, base + Vector((0, yd - 0.03, 0)), Vector((0, 1, 0)), [(0.0, 0.03, 4), (0.05, 0.03, 4)], RIM, th + math.pi * 0.25, 0.6)
        del t
    prof = [(yd - 0.01, rim_r - 0.05), (yd, rim_r - 0.07), (yd + 0.012, 0.22), (yd + 0.028, 0.17), (yd + 0.03, 0.13),
            (yd + 0.024, 0.11), (yd + 0.024, 0.095)]
    b.revolve(prof, RIM, 72, 1.0)
    back = [(y - 0.006, r) for y, r in reversed(prof)]
    b.revolve(back, RIM, 72, 0.4)
    # Hub: a boss with its studs and nuts, and the axle's end cap.
    hd.prism(b, Vector((0, yd + 0.02, 0)), Vector((0, 1, 0)), [(0.0, 0.1, 40), (0.05, 0.1, 40), (0.056, 0.092, 40)], HARDWARE, 0.0, 0.5)
    hd.lug_nuts(b, yd + 0.058, 1.0, 8, 0.075)
    hd.dome(b, yd + 0.058, 1.0, [(0.0, 0.05), (0.03, 0.05), (0.045, 0.04), (0.052, 0.02), (0.054, 0.002)])


def front_rim(b, rim_r, a):
    hd.rim_barrel(b, 0.0, rim_r, a)
    yd = 0.015
    prof = [(yd - 0.006, rim_r - 0.03), (yd, rim_r - 0.045), (yd + 0.01, 0.13), (yd + 0.024, 0.1), (yd + 0.026, 0.07),
            (yd + 0.02, 0.06)]
    b.revolve(prof, RIM, 72, 1.0)
    b.revolve([(y - 0.005, r) for y, r in reversed(prof)], RIM, 72, 0.4)
    hd.lug_nuts(b, yd + 0.026, 1.0, 6, 0.08)
    hd.dome(b, yd + 0.026, 1.0, [(0.0, 0.058), (0.02, 0.056), (0.04, 0.046), (0.052, 0.03), (0.058, 0.01), (0.06, 0.002)])


def tractor_wheel(name, centre, rear):
    """A wheel in its canonical frame (axle y, outer side +y), turned and placed; the
    mesh's own axis is its axle (glTF y)."""
    font = K._get_font()
    mats = K.wheel_mats()
    b = hd.Builder()
    if rear:
        a = 0.14
        AgTyre(R_REAR, W_REAR, RIM_REAR, a, 0.036).build(b, 0.0, 20, font,
                [("TARLA-GRIP  R-1", 0.034, 90), ("TARLA-GRIP  R-1", 0.034, 270), ("12.4-28  6 PLY  TT", 0.02, 0),
                 ("12.4-28  6 PLY  TT", 0.02, 180)])
        rear_rim(b, RIM_REAR, a)
    else:
        a = 0.058
        AgTyre(R_FRONT, W_FRONT, RIM_FRONT, a, 0.0).build_ribbed(b, 0.0, font,
                [("6.00-16  F-2", 0.016, 90), ("6.00-16  F-2", 0.016, 270)])
        front_rim(b, RIM_FRONT, a)
    ob = b.to_object(name, mats)
    me = ob.data
    c = Vector(centre)
    if c.y < 0.0:
        me.transform(Matrix.Rotation(math.pi, 4, "Z"))
    R = R_REAR if rear else R_FRONT
    col = me.color_attributes["Col"]
    for li, loop in enumerate(me.loops):
        p = me.vertices[loop.vertex_index].co
        cc = col.data[li].color
        col.data[li].color = (cc[0], min(math.hypot(p.x, p.z) / R, 1.0), cc[2], 1.0)
    # Axle along the mesh's own z (glTF y), the wheel at its centre.
    me.transform(Matrix.Rotation(math.pi * 0.5, 4, "X"))
    ob.matrix_world = Matrix.Translation(c) @ Matrix.Rotation(-math.pi * 0.5, 4, "X")
    return ob


# --- Body ---------------------------------------------------------------------------------

def bonnet():
    """The bonnet (side profile extruded, edges rounded), louvres, grille and badges."""
    obs = []
    x0, x1 = 0.66, 2.26
    hw = 0.3
    prof = [(x0, 0.95), (x1, 0.95), (x1 - 0.035, 1.33), (x1 - 0.12, 1.345), (x0 + 0.1, 1.365), (x0, 1.365)]
    hood = K.prism("hood", prof, -hw, hw, paint(), plane="XZ", bevel=0.075, segs=4, smooth=40.0)
    obs.append(hood)
    # A seam along the top where the lid lifts, and the hinge line.
    for side in (1.0, -1.0):
        obs.append(K.box("seam", ((x0 + x1) * 0.5 - 0.02, side * (hw - 0.07), 1.358), (x1 - x0 - 0.2, 0.006, 0.006), black()))
        # Louvres: a panel of slots near the front of each side.
        for k in range(7):
            z = 1.02 + k * 0.038
            obs.append(K.box("louvre", (1.72, side * (hw + 0.001), z), (0.42, 0.004, 0.018), black(), bevel=0.003, segs=1))
        # Badge on each side.
    # Grille: a chrome-edged opening with black mesh bars and the two lamps.
    gx = x1 + 0.002
    obs.append(K.box("grille_back", (gx - 0.03, 0.0, 1.135), (0.03, 0.5, 0.3), black()))
    for k in range(11):
        z = 1.0 + k * 0.026
        obs.append(K.box("grille_bar", (gx - 0.005, 0.0, z), (0.02, 0.46, 0.008), K.mat("Trim_Grille", (0.1, 0.1, 0.1), 0.6, 0.4)))
    for side in (1.0, -1.0):
        obs.append(K.box("grille_side", (gx, side * 0.245, 1.135), (0.02, 0.02, 0.3), chrome(), bevel=0.006))
    obs.append(K.box("grille_top", (gx - 0.006, 0.0, 1.29), (0.02, 0.51, 0.02), chrome(), bevel=0.006))
    obs.append(K.box("grille_bot", (gx, 0.0, 0.98), (0.02, 0.51, 0.02), chrome(), bevel=0.006))
    # Badge plate over the grille.
    obs.append(K.box("badge", (gx - 0.012, 0.0, 1.312), (0.012, 0.16, 0.035), chrome(), bevel=0.006))
    return obs


def lamps():
    obs = []
    head = K.mat("Lamp_HeadReflector", (0.85, 0.85, 0.82), 1.0, 0.12)
    lens = K.mat("Lens_Clear", (0.95, 0.95, 0.95), 0.0, 0.05, alpha=0.25)
    red = K.mat("Lamp_Red", (0.45, 0.02, 0.015), 0.0, 0.15)
    amber = K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1)
    for side, s in ((1.0, "L"), (-1.0, "R")):
        # Head lamps set in the grille.
        obs += K.lamp_rect("Head_G" + s, (2.268, side * 0.165, 1.2), (1, 0, 0), 0.11, 0.075, head, depth=0.02,
                           bezel_mat=chrome(), lens_mat=lens)
        # Round lamps on the fenders' front corners, on brackets.
        c = Vector((0.52, side * 0.86, 1.33))
        obs += K.lamp_round("Head_F" + s, c, (1, 0, 0), 0.07, 0.06, housing_mat=black(), lamp_mat=head, lens_mat=lens, ring_mat=chrome())
        obs.append(K.box("lamp_bracket", c + Vector((-0.08, 0, -0.07)), (0.06, 0.03, 0.08), black()))
        # Tail lamp and indicator on the fenders' rear.
        t = Vector((-0.66, side * 0.86, 1.02))
        obs.append(K.box("tail_house", t + Vector((0.03, 0, 0)), (0.06, 0.1, 0.16), black(), bevel=0.01))
        obs += K.lamp_rect("Brake_" + s, t + Vector((-0.002, 0, 0.035)), (-1, 0, 0), 0.08, 0.06, red, depth=0.015, ribs=3)
        obs.append(K.box("ind", t + Vector((-0.003, 0, -0.04)), (0.012, 0.08, 0.05), amber, bevel=0.004))
    return obs


def drivetrain():
    obs = []
    # Engine block, head and sump below the bonnet, the clutch housing flaring into the gearbox.
    obs.append(K.box("engine", (1.42, 0.0, 0.8), (1.25, 0.42, 0.34), cast(), bevel=0.03))
    obs.append(K.box("sump", (1.45, 0.0, 0.6), (1.0, 0.34, 0.12), cast(), bevel=0.03))
    for k in range(4):
        obs.append(K.box("manifold", (1.05 + k * 0.28, -0.24, 0.9), (0.1, 0.06, 0.08), K.mat("Trim_Rust", (0.2, 0.1, 0.06), 0.3, 0.8), bevel=0.01))
    obs.append(K.box("starter", (0.95, 0.24, 0.72), (0.25, 0.1, 0.1), black(), bevel=0.03))
    obs.append(K.box("clutch", (0.66, 0.0, 0.72), (0.2, 0.5, 0.44), cast(), bevel=0.05))
    obs.append(K.box("gearbox", (0.28, 0.0, 0.68), (0.8, 0.42, 0.42), cast(), bevel=0.04))
    # Rear axle: the centre housing and the trumpets out to the wheels.
    obs.append(K.box("diff", (-0.05, 0.0, 0.66), (0.45, 0.62, 0.46), cast(), bevel=0.08, segs=3))
    for side in (1.0, -1.0):
        obs.append(K.cyl("trumpet", (0.0, side * 0.28, R_REAR), (0.0, side * 0.56, R_REAR), 0.1, cast(), 24, r1=0.075))
    # Front support casting, axle on its pivot, stub axles, tie rod, front weights.
    obs.append(K.box("front_support", (2.1, 0.0, 0.72), (0.34, 0.36, 0.42), cast(), bevel=0.04))
    obs.append(K.box("front_axle", (WB, 0.0, 0.43), (0.12, 1.2, 0.1), cast(), bevel=0.02))
    obs.append(K.cyl("pivot", (WB - 0.1, 0.0, 0.47), (WB + 0.12, 0.0, 0.47), 0.05, cast(), 16))
    for side in (1.0, -1.0):
        obs.append(K.cyl("kingpin", (WB, side * 0.6, 0.3), (WB, side * 0.6, 0.47), 0.035, cast(), 12))
        obs.append(K.cyl("stub", (WB, side * 0.6, R_FRONT), (WB, side * 0.63, R_FRONT), 0.04, cast(), 12))
    obs.append(K.cyl("tie_rod", (WB - 0.16, 0.56, 0.36), (WB - 0.16, -0.56, 0.36), 0.015, steel(), 8))
    for k in range(5):
        obs.append(K.box("weight", (2.33, 0.0, 0.54 + k * 0.058), (0.13, 0.52, 0.052), K.mat("Trim_Weights", (0.12, 0.12, 0.12), 0.3, 0.6),
                         bevel=0.012, segs=1))
    obs.append(K.box("weight_bar", (2.33, 0.0, 0.83), (0.06, 0.18, 0.05), steel(), bevel=0.01))
    # Radiator cap and the drawbar under the carry box.
    return obs


def scuttle_and_cockpit():
    obs = []
    # Scuttle with the fuel tank and dash (painted), the filler cap on top.
    prof = [(0.34, 0.95), (0.68, 0.95), (0.68, 1.37), (0.5, 1.43), (0.36, 1.43), (0.34, 1.35)]
    obs.append(K.prism("scuttle", prof, -0.31, 0.31, paint(), plane="XZ", bevel=0.04, segs=3))
    obs.append(K.cyl("filler", (0.55, 0.12, 1.43), (0.55, 0.12, 1.47), 0.045, chrome(), 20, bevel=0.005))
    # The dash on the scuttle's back: a black panel with two dials, the key and switches.
    dash = K.mat("Trim_Dash", (0.03, 0.03, 0.035), 0.0, 0.5)
    obs.append(K.box("dash", (0.335, 0.0, 1.28), (0.02, 0.44, 0.16), dash, bevel=0.01, rot=(0.0, math.radians(-20), 0.0)))
    face = K.mat("Trim_GaugeFace", (0.75, 0.74, 0.7), 0.0, 0.3)
    for y in (0.1, -0.1):
        obs.append(K.cyl("gauge_ring", (0.33, y, 1.29), (0.318, y, 1.29), 0.05, chrome(), 24))
        obs.append(K.cyl("gauge_face", (0.321, y, 1.29), (0.316, y, 1.29), 0.043, face, 24))
        obs.append(K.box("needle", (0.314, y + 0.012, 1.3), (0.002, 0.03, 0.004), K.mat("Trim_Needle", (0.8, 0.15, 0.05), 0.0, 0.4)))
    obs.append(K.cyl("key", (0.32, 0.0, 1.23), (0.29, 0.0, 1.23), 0.012, chrome(), 10))
    for k, y in enumerate((-0.18, 0.18)):
        obs.append(K.cyl("switch", (0.325, y, 1.23), (0.3, y, 1.23), 0.01, black(), 8))
    # Steering column up to the wheel.
    obs.append(K.cyl("column", (0.42, 0.0, 1.32), (0.15, 0.0, 1.64), 0.03, black(), 16))
    obs.append(K.cyl("column_boot", (0.4, 0.0, 1.33), (0.34, 0.0, 1.41), 0.045, rubber(), 16))
    # Footboards in chequer plate between the fenders and the gearbox.
    for side in (1.0, -1.0):
        obs.append(K.box("footboard", (0.33, side * 0.37, 0.735), (0.62, 0.3, 0.012), chequer()))
        for k in range(9):
            for j in range(4):
                obs.append(K.box("chq", (0.07 + k * 0.065, side * (0.26 + j * 0.07), 0.743), (0.03, 0.008, 0.005), chequer(),
                                 rot=(0.0, 0.0, math.radians(45 if (k + j) % 2 else -45))))
        obs.append(K.box("step", (0.36, side * 0.56, 0.52), (0.26, 0.1, 0.02), chequer()))
        obs.append(K.box("step_hanger", (0.36, side * 0.54, 0.63), (0.02, 0.02, 0.22), steel()))
    # Pedals (clutch left, the brakes right), the gear and range levers, the hand throttle.
    for y, name in ((0.3, "clutch"), (-0.26, "brake_l"), (-0.33, "brake_r")):
        obs.append(K.tube(name + "_arm", [(0.52, y, 0.72), (0.5, y, 0.82), (0.44, y, 0.9)], 0.012, steel(), 8))
        obs.append(K.box(name + "_pad", (0.43, y, 0.9), (0.03, 0.065, 0.1), rubber(), bevel=0.008, rot=(0.0, math.radians(-30), 0.0)))
    for p, top in (((0.36, 0.06, 0.92), (0.2, 0.1, 1.33)), ((0.3, -0.08, 0.92), (0.16, -0.13, 1.28))):
        obs.append(K.tube("lever", [p, top], 0.01, chrome(), 8))
        obs.append(K.cyl("knob", Vector(top) - Vector((0, 0, 0.02)), Vector(top) + Vector((0, 0, 0.03)), 0.022, black(), 12))
    obs.append(K.tube("throttle", [(0.3, -0.12, 1.5), (0.26, -0.2, 1.53)], 0.008, chrome(), 8))
    # Seat: a pan seat on its sprung post, the backrest raked back.
    obs.append(K.box("seat_post", (-0.28, 0.0, 1.0), (0.12, 0.14, 0.34), steel(), bevel=0.01))
    obs.append(K.box("seat_pan", (-0.3, 0.0, 1.19), (0.46, 0.46, 0.05), steel(), bevel=0.015))
    obs.append(K.box("seat", (-0.3, 0.0, 1.235), (0.44, 0.44, 0.075), seat_vinyl(), bevel=0.03, segs=3))
    obs.append(K.box("backrest", (-0.51, 0.0, 1.42), (0.07, 0.42, 0.3), seat_vinyl(), bevel=0.03, segs=3, rot=(0.0, math.radians(-12), 0.0)))
    return obs


def fenders():
    obs = []
    rf = R_REAR + 0.1
    for side in (1.0, -1.0):
        # The mudguard: a rolled-lip sheet sweeping over the tyre.
        pts = []
        for i in range(25):
            th = math.radians(22 + (172 - 22) * i / 24)
            pts.append((math.cos(th), math.sin(th)))
        y0, y1 = 0.47, 0.95
        sections = []
        for c, s in pts:
            p = Vector((rf * c, 0.0, R_REAR + rf * s))
            n = Vector((c, 0.0, s))
            sec = []
            for yy, dn in ((y0, 0.0), (y1 - 0.02, 0.0), (y1, -0.012), (y1 + 0.004, -0.045), (y1 - 0.01, -0.05),
                           (y1 - 0.02, -0.006), (y0, -0.006)):
                q = p + n * dn
                sec.append((q.x, side * yy, q.z))
            sections.append(sec)
        obs.append(K.loft("fender", sections, paint(), closed=True, cap=True, smooth=40.0))
        # The inner wall between the tyre and the seat.
        prof = [(rf * c * 0.99, R_REAR + rf * s * 0.99) for c, s in pts] + [(-0.6, 0.72), (0.62, 0.72)]
        obs.append(K.prism("fender_wall", prof, side * 0.465, side * 0.475, paint(), plane="XZ"))
        # Grab handle on top.
        obs.append(K.tube("grab", [(-0.25, side * 0.52, R_REAR + rf + 0.01), (-0.2, side * 0.52, R_REAR + rf + 0.1),
                                   (0.12, side * 0.52, R_REAR + rf + 0.1), (0.17, side * 0.52, R_REAR + rf + 0.01)], 0.013, black(), 8))
    return obs


def rops_and_exhaust():
    obs = []
    for side in (1.0, -1.0):
        obs.append(K.box("rops_post", (-0.66, side * 0.5, 1.5), (0.08, 0.08, 1.56), black(), bevel=0.012))
        obs.append(K.box("rops_foot", (-0.6, side * 0.5, 0.74), (0.2, 0.12, 0.08), black(), bevel=0.01))
    obs.append(K.box("rops_top", (-0.66, 0.0, 2.27), (0.08, 1.08, 0.08), black(), bevel=0.012))
    obs.append(K.box("rops_lamp", (-0.72, 0.0, 2.33), (0.08, 0.14, 0.09), black(), bevel=0.015))
    # Exhaust: up through the bonnet on the right, a silencer, a rain flap.
    ex = Vector((1.86, -0.18, 1.34))
    rust = K.mat("Trim_Exhaust", (0.09, 0.05, 0.03), 0.4, 0.75)
    obs.append(K.cyl("exhaust_boot", ex, ex + Vector((0, 0, 0.03)), 0.05, black(), 16))
    obs.append(K.cyl("exhaust_lo", ex, ex + Vector((0, 0, 0.12)), 0.032, rust, 16))
    obs.append(K.cyl("silencer", ex + Vector((0, 0, 0.12)), ex + Vector((0, 0, 0.5)), 0.055, rust, 20, bevel=0.01))
    obs.append(K.cyl("exhaust_hi", ex + Vector((0, 0, 0.5)), ex + Vector((0, 0, 0.72)), 0.03, rust, 16))
    obs.append(K.box("rain_flap", ex + Vector((0.0, 0, 0.735)), (0.075, 0.07, 0.004), rust, rot=(0.0, math.radians(-8), 0.0)))
    # Air pre-cleaner on the left.
    pc = Vector((1.5, 0.17, 1.36))
    obs.append(K.cyl("intake", pc, pc + Vector((0, 0, 0.14)), 0.03, black(), 16))
    obs.append(K.revolve("precleaner", [(0.0, 0.03), (0.02, 0.06), (0.08, 0.065), (0.1, 0.05), (0.105, 0.0)], pc + Vector((0, 0, 0.14)),
                         (0, 0, 1), K.mat("Trim_Bowl", (0.35, 0.3, 0.22), 0.0, 0.2), 24))
    return obs


def linkage_and_box():
    obs = []
    # Three-point linkage: the lower links, the top link, the lift arms and rods.
    for side in (1.0, -1.0):
        obs.append(K.tube("lower_link", [(-0.25, side * 0.28, 0.45), (-1.02, side * 0.42, 0.55)], 0.022, steel(), 10))
        obs.append(K.tube("lift_arm", [(-0.3, side * 0.24, 0.98), (-0.72, side * 0.3, 0.94)], 0.02, steel(), 10))
        obs.append(K.tube("lift_rod", [(-0.72, side * 0.3, 0.94), (-0.72, side * 0.36, 0.52)], 0.014, steel(), 8))
        obs.append(K.tube("check_chain", [(-0.4, side * 0.32, 0.5), (-0.55, side * 0.56, 0.6)], 0.006, steel(), 6))
    obs.append(K.tube("top_link", [(-0.42, 0.0, 0.98), (-0.72, 0.0, 1.0), (-1.02, 0.0, 1.0)], 0.022, steel(), 10))
    obs.append(K.cyl("pto", (-0.27, 0.0, 0.56), (-0.4, 0.0, 0.56), 0.018, steel(), 12))
    obs.append(K.box("pto_guard", (-0.34, 0.0, 0.62), (0.12, 0.2, 0.012), black()))
    # The carry box: a welded steel tray with a headstock frame and a drop-down tail.
    bx0, bx1 = -1.02, -2.09
    hw = 0.745
    floor = 0.52
    top = 1.02
    t = 0.022
    bp = box_paint()
    obs.append(K.box("tray_floor", ((bx0 + bx1) * 0.5, 0.0, floor - t * 0.5), (bx0 - bx1, 2 * hw, t), bp))
    for side in (1.0, -1.0):
        obs.append(K.box("tray_side", ((bx0 + bx1) * 0.5, side * (hw - t * 0.5), (floor + top) * 0.5), (bx0 - bx1, t, top - floor), bp))
        obs.append(K.box("tray_rim", ((bx0 + bx1) * 0.5, side * (hw - 0.01), top), (bx0 - bx1 + 0.02, 0.04, 0.03), bp, bevel=0.008))
        for x in (bx0 - 0.25, bx0 - 0.55, bx0 - 0.82):
            obs.append(K.box("tray_rib", (x, side * (hw + 0.008), (floor + top) * 0.5), (0.03, 0.016, top - floor - 0.04), bp))
    obs.append(K.box("tray_front", (bx0 - t * 0.5, 0.0, (floor + top) * 0.5), (t, 2 * hw, top - floor), bp))
    obs.append(K.box("tray_back", (bx1 + t * 0.5, 0.0, (floor + top) * 0.5 - 0.02), (t, 2 * hw - 0.02, top - floor - 0.04), bp))
    obs.append(K.box("tray_back_rim", (bx1 + 0.01, 0.0, top), (0.04, 2 * hw + 0.02, 0.03), bp, bevel=0.008))
    for x in (bx0 - 0.1, (bx0 + bx1) * 0.5, bx1 + 0.1):
        obs.append(K.box("tray_bearer", (x, 0.0, floor - t - 0.03), (0.06, 2 * hw, 0.06), steel()))
    # Headstock: the A-frame the links pin to.
    obs.append(K.tube("a_frame", [(bx0 - 0.01, 0.42, 0.55), (bx0 - 0.03, 0.0, 1.0), (bx0 - 0.01, -0.42, 0.55)], 0.03, steel(), 10))
    # Tail hinges, the plate on the back and rear reflectors.
    for side in (1.0, -1.0):
        obs.append(K.cyl("hinge", (bx1 - 0.01, side * 0.5, floor + 0.02), (bx1 - 0.01, side * 0.62, floor + 0.02), 0.018, steel(), 10))
        obs.append(K.box("reflector", (bx1 - 0.004, side * 0.62, 0.9), (0.006, 0.08, 0.05), K.mat("Trim_Reflector", (0.6, 0.02, 0.02), 0.0, 0.15)))
    obs.append(K.plate("Numberplate_Rear", (bx1 - 0.02, 0.0, 0.78), (-1, 0, 0)))
    return obs


def main():
    a = K.args()
    K.reset()
    parts = bonnet() + drivetrain() + scuttle_and_cockpit() + fenders() + rops_and_exhaust() + linkage_and_box()
    lamp_obs = lamps()
    steer = K.steering("Steering_Wheel", (0.12, 0.0, 1.665), (0.62, 0.0, -0.78), 0.19, K.mat("Trim_SteerWheel", (0.02, 0.02, 0.02), 0.0, 0.5))
    wheels = [tractor_wheel("WheelStock_FL", (WB, TRACK_FRONT, R_FRONT), False),
              tractor_wheel("WheelStock_FR", (WB, -TRACK_FRONT, R_FRONT), False),
              tractor_wheel("WheelStock_RL", (0.0, TRACK_REAR, R_REAR), True),
              tractor_wheel("WheelStock_RR", (0.0, -TRACK_REAR, R_REAR), True)]
    keep = [o for o in lamp_obs if o.name.startswith(("Lamp_", "Lens_"))]
    rest = [o for o in parts + lamp_obs if o not in keep and not o.name.startswith("Numberplate")]
    plates = [o for o in parts if o.name.startswith("Numberplate")]
    # One mesh per lamp role (the game switches them by name).
    groups = {}
    for o in keep:
        key = o.name.split(".")[0]
        role = "Lens" if key.startswith("Lens_") else "_".join(key.split("_")[:2])
        groups.setdefault(role, []).append(o)
    lamp_meshes = [K.join(v, k) for k, v in groups.items()]
    body = K.join(rest, "Tractor_Body")
    K.export([body, steer] + wheels + lamp_meshes + plates, OUT)
    if a.get("preview"):
        K.preview(os.path.join(a["preview"], "tractor"), centre=(0.2, 0.0, 0.9), dist=7.5,
                  views=("front3q", "back3q", "side", "left3q"))


if __name__ == "__main__":
    main()
