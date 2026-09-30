"""Builds the dealership's old four-by-four (the "Kaya 88", a short-wheelbase British-style
utility from the late seventies, the vet's and the shepherd's favourite):
art/models/vehicles/offroad/offroad.glb.

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_offroad.py [-- --preview=/abs/dir]

Modelled here from primitives (no outside assets) in the model frame of
tools/blender/vehicle_kit.py (front +X, left +Y, up +Z, ground z = 0), rear axle at x = 0:
flat, rolled-edge body panels in bronze green: the front wings with round headlamps set
in them, the grille panel, the bonnet with the spare wheel on it, the bulkhead with its
vents, an upright split windscreen in a frame with the wipers hung from the top, doors
with sliding windows and outside hinges, the rear tub with its wheel boxes; a white
hardtop with side windows and a rear door carrying a jerry can; a steel bumper with a
towing jaw, the chassis rails, sills, lamps, mirrors on the wings, a rear step; inside
a flat dash, a bench, the big wheel and the gear and transfer levers; 16-inch ivory
steel wheels on mud tyres (the pickup's modelled wheel, build_pickup_hd.py).
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_kit as K  # noqa: E402

OUT = os.path.join(K.ROOT, "art/models/vehicles/offroad/offroad.glb")

WB = 2.24
R, W = 0.405, 0.215
TRACK = 0.66
HW = 0.84
BELT = 1.12
ROOF = 1.93
FRONT = 2.93
REAR = -0.72
BULK = 2.02      # the bulkhead's front face


def paint():
    return K.mat("Offroad_Bodymat", (0.17, 0.22, 0.14), 0.1, 0.45)


def hardtop():
    return K.mat("Trim_Hardtop", (0.72, 0.72, 0.68), 0.05, 0.45)


def steel():
    return K.mat("Trim_Steel", (0.035, 0.036, 0.038), 0.55, 0.55)


def galv():
    return K.mat("Trim_Galv", (0.55, 0.56, 0.56), 0.9, 0.42)


def rubber():
    return K.mat("Trim_Rubber", (0.025, 0.025, 0.025), 0.0, 0.8)


def black_plastic():
    return K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.5)


def chrome():
    return K.mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12)


def gap():
    return K.mat("Trim_Gap", (0.008, 0.008, 0.008), 0.0, 0.9)


def interior(kind, color, rough=0.7, metal=0.0):
    return K.mat("Interior_" + kind, color, metal, rough)


def arch_cut(ob, x, y0, y1):
    c = K.cyl("arch", (x, y0, R), (x, y1, R), R + 0.085, paint(), 40)
    K.cut(ob, c)
    return c


def body_panels():
    obs = []
    cut = []
    for side in (1.0, -1.0):
        # Front wing: flat top, the headlamp's recess in its front.
        wing = K.box("wing", ((BULK + FRONT) * 0.5, side * 0.68, 0.9), (FRONT - BULK, 0.32, 0.36), paint(), bevel=0.02, segs=2)
        cut.append(arch_cut(wing, WB, side * 0.4, side * 1.0))
        cut.append(K.cyl("lamp_recess", (FRONT + 0.05, side * 0.66, 0.93), (FRONT - 0.06, side * 0.66, 0.93), 0.1, paint(), 28))
        K.cut(wing, cut[-1])
        obs.append(wing)
        # Inner wing (the wheel's mudguard) behind the arch.
        obs.append(K.box("inner_wing", ((BULK + FRONT) * 0.5, side * 0.52, 0.86), (FRONT - BULK - 0.02, 0.02, 0.4), steel()))
        # The body side from the bulkhead to the tail: door and tub panels.
        side_panel = K.box("side", ((REAR + BULK) * 0.5, side * (HW - 0.015), (0.56 + BELT) * 0.5), (BULK - REAR, 0.03, BELT - 0.56), paint(), bevel=0.015, segs=2)
        cut.append(arch_cut(side_panel, 0.0, side * 0.6, side * 1.0))
        obs.append(side_panel)
        # Capping strip along the top of the body side.
        obs.append(K.box("capping", ((REAR + 1.08) * 0.5, side * (HW - 0.01), BELT + 0.012), (1.08 - REAR, 0.05, 0.025), paint(), bevel=0.008))
        # The tub's wheel box inside.
        obs.append(K.box("wheel_box", (0.0, side * 0.6, 0.9), (1.0, 0.26, 0.34), paint(), bevel=0.02))
        # Sill under the door.
        obs.append(K.box("sill", (1.52, side * (HW - 0.04), 0.52), (0.9, 0.1, 0.08), steel()))
        # Arch lips in black on the tub.
        obs.append(K.box("tub_floor_edge", (-0.36, side * (HW - 0.04), 0.57), (0.72, 0.06, 0.02), steel()))
    # Bonnet, grille panel, bulkhead with vents, the rear panel and the tub floor.
    obs.append(K.box("bonnet", ((BULK + FRONT) * 0.5 - 0.04, 0.0, 1.075), (FRONT - BULK - 0.1, 1.0, 0.05), paint(), bevel=0.02, segs=2,
                     rot=(0.0, math.radians(1.5), 0.0)))
    obs.append(K.box("grille_panel", (FRONT - 0.07, 0.0, 0.8), (0.04, 1.0, 0.5), K.mat("Trim_Grille", (0.015, 0.015, 0.015), 0.2, 0.6), bevel=0.01))
    for k in range(9):
        obs.append(K.box("grille_bar", (FRONT - 0.045, 0.0, 0.6 + k * 0.05), (0.012, 0.92, 0.012), K.mat("Trim_GrilleMesh", (0.3, 0.3, 0.3), 0.7, 0.4)))
    for k in range(13):
        obs.append(K.box("grille_bar_v", (FRONT - 0.045, -0.45 + k * 0.075, 0.8), (0.012, 0.012, 0.44), K.mat("Trim_GrilleMesh", (0.3, 0.3, 0.3), 0.7, 0.4)))
    obs.append(K.box("grille_frame", (FRONT - 0.04, 0.0, 1.035), (0.03, 1.0, 0.04), paint(), bevel=0.008))
    obs.append(K.box("radiator", (FRONT - 0.2, 0.0, 0.8), (0.1, 0.8, 0.46), steel()))
    obs.append(K.box("bulkhead", (BULK - 0.03, 0.0, 0.92), (0.06, 2 * HW, 0.4), paint(), bevel=0.012))
    for side in (1.0, -1.0):
        obs.append(K.box("vent", (BULK + 0.004, side * 0.36, 1.02), (0.012, 0.42, 0.08), paint(), bevel=0.01, rot=(0.0, math.radians(-12), 0.0)))
    obs.append(K.box("rear_panel", (REAR + 0.015, 0.0, (0.56 + BELT) * 0.5), (0.03, 2 * HW, BELT - 0.56), paint(), bevel=0.015))
    obs.append(K.box("tub_floor", ((REAR + 1.1) * 0.5, 0.0, 0.76), (1.1 - REAR, 2 * HW - 0.06, 0.03), steel()))
    obs.append(K.box("cab_floor", ((BULK + 1.1) * 0.5, 0.0, 0.62), (BULK - 1.1, 2 * HW - 0.06, 0.03), steel()))
    obs.append(K.box("seatbox", (1.25, 0.0, 0.76), (0.4, 2 * HW - 0.08, 0.3), paint(), bevel=0.015))
    obs.append(K.box("tunnel", (1.75, 0.0, 0.72), (0.5, 0.3, 0.2), paint(), bevel=0.02))
    for o in obs:
        K.apply(o)
    K.remove(*cut)
    return obs


def door_lines():
    obs = []
    g = gap()
    for side in (1.0, -1.0):
        y = side * (HW + 0.0005)
        n = (0.0, side, 0.0)
        for x in (1.1, BULK - 0.04):
            obs.append(K.strip("gap", (x, y, 0.58), (x, y, BELT), 0.005, 0.0015, g, n))
        obs.append(K.strip("gap", (1.1, y, 0.58), (BULK - 0.04, y, 0.58), 0.005, 0.0015, g, n))
        # Outside hinges on the door's front, a push-button handle at its back.
        for z in (0.72, 1.02):
            obs.append(K.box("hinge", (BULK - 0.03, side * (HW + 0.012), z), (0.1, 0.02, 0.05), galv(), bevel=0.008))
        obs.append(K.box("handle", (1.2, side * (HW + 0.01), 1.0), (0.09, 0.02, 0.03), chrome(), bevel=0.008))
        # Rivet lines along the tub.
        for k in range(12):
            obs.append(K.cyl("rivet", (REAR + 0.1 + k * 0.15, y, 1.08), (REAR + 0.1 + k * 0.15, side * (HW + 0.004), 1.08), 0.005, galv(), 6))
    return obs


def screen_and_top():
    obs = []
    ws_x = BULK - 0.06
    frame = paint()
    # Windscreen frame: upright, two panes either side of a centre bar.
    obs.append(K.box("ws_bottom", (ws_x, 0.0, BELT + 0.02), (0.06, 2 * HW - 0.02, 0.04), frame, bevel=0.008))
    wtop = ROOF - 0.07
    obs.append(K.box("ws_top", (ws_x - 0.06, 0.0, wtop), (0.06, 2 * HW - 0.02, 0.05), frame, bevel=0.008))
    for y in (-(HW - 0.03), 0.0, HW - 0.03):
        obs.append(K.box("ws_post", (ws_x - 0.03, y, (BELT + wtop) * 0.5), (0.05, 0.05 if y else 0.04, wtop - BELT), frame, bevel=0.008,
                         rot=(0.0, math.radians(-5), 0.0)))
    glass = K.mat("Glass_Clear", (0.86, 0.9, 0.9), 0.0, 0.05, alpha=0.2)
    lean = Vector((1.0, 0.0, math.tan(math.radians(5)))).normalized()
    for side, s in ((1.0, "L"), (-1.0, "R")):
        z0, z1 = BELT + 0.05, wtop - 0.025
        xa, xb = ws_x - 0.005, ws_x - 0.005 - (z1 - z0) * math.tan(math.radians(5))
        y0, y1 = side * 0.03, side * (HW - 0.06)
        obs.append(K.pane("Windshield_" + s, [(xa, y0, z0), (xa, y1, z0), (xb, y1, z1), (xb, y0, z1)], glass))
        # Wiper motor on the top rail, the arm hanging down the glass.
        obs.append(K.box("wiper_motor", (ws_x - 0.01, side * 0.42, wtop), (0.06, 0.1, 0.07), black_plastic(), bevel=0.01))
        obs.append(K.tube("wiper", [(ws_x - 0.005, side * 0.42, wtop - 0.03), (ws_x + 0.005, side * 0.16, wtop - 0.36)], 0.006, black_plastic(), 6))
    # Door tops: frames with two sliding panes.
    for side, s in ((1.0, "L"), (-1.0, "R")):
        x0, x1 = 1.12, BULK - 0.08
        y = side * (HW - 0.02)
        for x in (x0, x1):
            obs.append(K.box("door_frame_v", (x, y, (BELT + wtop) * 0.5), (0.04, 0.035, wtop - BELT), frame, bevel=0.008))
        obs.append(K.box("door_frame_t", ((x0 + x1) * 0.5, y, wtop), (x1 - x0 + 0.04, 0.035, 0.04), frame, bevel=0.008))
        obs.append(K.box("door_frame_b", ((x0 + x1) * 0.5, y, BELT + 0.02), (x1 - x0 + 0.04, 0.04, 0.04), frame, bevel=0.008))
        xm = (x0 + x1) * 0.5
        for k, (a, b) in enumerate(((x0 + 0.02, xm + 0.03), (xm - 0.03, x1 - 0.02))):
            yy = side * (HW - 0.02 - 0.012 * (1 if k else -1))
            obs.append(K.pane("Glass_Door%s%d" % (s, k), [(a, yy, BELT + 0.045), (b, yy, BELT + 0.045), (b, yy, wtop - 0.02), (a, yy, wtop - 0.02)], glass))
        obs.append(K.box("slide_rail", ((x0 + x1) * 0.5, y, BELT + 0.045), (x1 - x0, 0.05, 0.015), black_plastic()))
    # The hardtop: sides over the tub with windows, the roof out to the screen, the
    # rear door with its window and a jerry can.
    top = hardtop()
    # Panels: the roof out to the screen's top rail, the sides over the tub (their
    # windows cut out), the back with the door's window; rolled edges.
    ht = []
    roof_x0 = ws_x - 0.07
    ht.append(K.box("ht_roof", ((REAR + roof_x0) * 0.5, 0.0, ROOF - 0.02), (roof_x0 - REAR, 2 * HW - 0.02, 0.04), top, bevel=0.018, segs=3))
    for side in (1.0, -1.0):
        wall = K.box("ht_side", ((REAR + 1.1) * 0.5, side * (HW - 0.012), (BELT + ROOF) * 0.5 - 0.01), (1.1 - REAR, 0.024, ROOF - BELT - 0.02), top,
                     bevel=0.01, segs=2)
        win = K.box("ht_win", (0.28, side * HW, 1.5), (1.2, 0.2, 0.42), top, bevel=0.03)
        K.cut(wall, win)
        K.apply(wall)
        K.remove(win)
        ht.append(wall)
        # The roof's rolled edge along the side and its drip rail.
        ht.append(K.cyl("ht_edge", (REAR, side * (HW - 0.02), ROOF - 0.035), (roof_x0, side * (HW - 0.02), ROOF - 0.035), 0.022, top, 12))
        ht.append(K.box("drip", ((REAR + roof_x0) * 0.5, side * (HW + 0.004), ROOF - 0.06), (roof_x0 - REAR, 0.012, 0.012), top))
        # Above the door: the side of the roof's front part down to the door top.
        ht.append(K.box("ht_door_top", ((1.1 + roof_x0) * 0.5, side * (HW - 0.012), ROOF - 0.04), (roof_x0 - 1.1, 0.024, 0.08), top, bevel=0.008))
    back = K.box("ht_back", (REAR + 0.012, 0.0, (BELT + ROOF) * 0.5 - 0.01), (0.024, 2 * HW - 0.02, ROOF - BELT - 0.02), top, bevel=0.01, segs=2)
    bwin = K.box("ht_door_win", (REAR, 0.0, 1.5), (0.2, 0.72, 0.42), top, bevel=0.03)
    K.cut(back, bwin)
    K.apply(back)
    K.remove(bwin)
    ht.append(back)
    ht.append(K.cyl("ht_edge_b", (REAR + 0.02, HW - 0.02, ROOF - 0.035), (REAR + 0.02, -(HW - 0.02), ROOF - 0.035), 0.022, top, 12))
    obs += ht
    for side, s in ((1.0, "L"), (-1.0, "R")):
        yy = side * (HW - 0.018)
        obs.append(K.pane("Glass_Side" + s, [(-0.33, yy, 1.28), (0.89, yy, 1.28), (0.89, yy, 1.72), (-0.33, yy, 1.72)], glass))
        obs.append(K.seal("seal", [(-0.32, side * (HW + 0.001), 1.29), (0.88, side * (HW + 0.001), 1.29), (0.88, side * (HW + 0.001), 1.71),
                                   (-0.32, side * (HW + 0.001), 1.71)], 0.02, rubber(), (0.0, side, 0.0), 0.01))
    obs.append(K.pane("Glass_Back", [(REAR + 0.01, 0.37, 1.28), (REAR + 0.01, -0.37, 1.28), (REAR + 0.01, -0.37, 1.72), (REAR + 0.01, 0.37, 1.72)], glass))
    obs.append(K.seal("seal", [(REAR - 0.004, 0.36, 1.29), (REAR - 0.004, -0.36, 1.29), (REAR - 0.004, -0.36, 1.71), (REAR - 0.004, 0.36, 1.71)],
                      0.02, rubber(), (-1.0, 0.0, 0.0), 0.01))
    # Rear door outline, hinges, handle; the jerry can in its holder.
    g = gap()
    for y in (0.46, -0.46):
        obs.append(K.strip("gap", (REAR - 0.0005, y, 0.58), (REAR - 0.0005, y, ROOF - 0.05), 0.005, 0.0015, g, (-1, 0, 0)))
    obs.append(K.strip("gap", (REAR - 0.0005, -0.46, 0.58), (REAR - 0.0005, 0.46, 0.58), 0.005, 0.0015, g, (-1, 0, 0)))
    for z in (0.8, 1.6):
        obs.append(K.box("rear_hinge", (REAR - 0.012, 0.47, z), (0.02, 0.1, 0.05), galv(), bevel=0.006))
    obs.append(K.box("rear_handle", (REAR - 0.015, -0.38, 1.05), (0.03, 0.03, 0.12), chrome(), bevel=0.008))
    can = K.mat("Trim_JerryCan", (0.18, 0.24, 0.12), 0.3, 0.5)
    obs.append(K.box("jerrycan", (REAR - 0.1, 0.0, 0.9), (0.16, 0.34, 0.46), can, bevel=0.02, segs=2))
    obs.append(K.box("can_holder", (REAR - 0.03, 0.0, 0.9), (0.04, 0.38, 0.04), steel()))
    obs.append(K.box("can_strap", (REAR - 0.1, 0.0, 1.05), (0.18, 0.36, 0.02), steel()))
    return obs


def front_and_rear():
    obs = []
    head = K.mat("Lamp_HeadReflector", (0.85, 0.85, 0.82), 1.0, 0.12)
    lens = K.mat("Lens_Clear", (0.95, 0.95, 0.95), 0.0, 0.05, alpha=0.25)
    red = K.mat("Lamp_Red", (0.45, 0.02, 0.015), 0.0, 0.15)
    white = K.mat("Lamp_White", (0.8, 0.8, 0.78), 0.0, 0.1)
    for side, s in ((1.0, "L"), (-1.0, "R")):
        obs += K.lamp_round("Head_" + s, (FRONT - 0.03, side * 0.66, 0.93), (1, 0, 0), 0.085, 0.07, lamp_mat=head, lens_mat=lens, ring_mat=chrome())
        obs.append(K.box("side_lamp", (FRONT + 0.004, side * 0.7, 0.76), (0.02, 0.06, 0.05), K.mat("Trim_LensWhite", (0.8, 0.8, 0.76), 0.0, 0.1), bevel=0.01))
        obs.append(K.box("ind_f", (FRONT + 0.004, side * 0.6, 0.76), (0.02, 0.06, 0.05), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1), bevel=0.01))
        # Wing mirror on a stalk.
        base = Vector((2.66, side * 0.8, 1.08))
        obs.append(K.tube("mirror_stalk", [base, base + Vector((0.0, side * 0.02, 0.28)), base + Vector((-0.02, side * 0.08, 0.36))], 0.01, black_plastic(), 8))
        obs.append(K.box("mirror_head", base + Vector((-0.03, side * 0.1, 0.38)), (0.04, 0.14, 0.1), black_plastic(), bevel=0.02))
        obs.append(K.box("mirror_glass", base + Vector((-0.052, side * 0.1, 0.38)), (0.004, 0.12, 0.085), K.mat("Trim_Mirror", (0.9, 0.9, 0.9), 1.0, 0.03)))
        # Rear lamps on the body's lower corners.
        c = Vector((REAR - 0.008, side * 0.7, 0.72))
        obs.append(K.box("tail_house", c + Vector((0.006, 0, 0)), (0.02, 0.16, 0.24), black_plastic(), bevel=0.01))
        obs += K.lamp_rect("Brake_" + s, c + Vector((-0.006, 0, 0.06)), (-1, 0, 0), 0.12, 0.08, red, depth=0.012, ribs=2)
        obs.append(K.box("tail_amber", c + Vector((-0.008, 0, -0.02)), (0.01, 0.12, 0.06), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1)))
        obs += K.lamp_rect("Reverse_" + s, c + Vector((-0.006, 0, -0.085)), (-1, 0, 0), 0.12, 0.045, white, depth=0.012)
    # Bumpers: a steel box section with the towing jaw; the rear crossmember and step.
    obs.append(K.box("bumper", (FRONT + 0.06, 0.0, 0.54), (0.12, 2 * HW + 0.06, 0.14), steel(), bevel=0.01))
    obs.append(K.box("jaw", (FRONT + 0.14, 0.0, 0.54), (0.06, 0.12, 0.1), steel(), bevel=0.01))
    obs.append(K.cyl("jaw_pin", (FRONT + 0.14, 0.0, 0.48), (FRONT + 0.14, 0.0, 0.62), 0.012, galv(), 8))
    obs.append(K.box("rear_x", (REAR - 0.05, 0.0, 0.52), (0.1, 2 * HW - 0.1, 0.14), steel(), bevel=0.01))
    obs.append(K.box("rear_step", (REAR - 0.14, 0.0, 0.44), (0.16, 0.5, 0.03), K.mat("Trim_Chequer", (0.3, 0.3, 0.3), 0.8, 0.45)))
    obs.append(K.box("tow_plate", (REAR - 0.12, 0.0, 0.5), (0.12, 0.2, 0.1), steel()))
    obs.append(K.plate("Numberplate_Front", (FRONT + 0.125, 0.18, 0.54), (1, 0, 0)))
    obs.append(K.plate("Numberplate_Rear", (REAR - 0.02, -0.5, 0.92), (-1, 0, 0)))
    # Spare wheel on the bonnet.
    obs.append(K.cyl("spare_tyre", (2.52, 0.0, 1.1), (2.52, 0.0, 1.31), R, rubber(), 32, bevel=0.05))
    obs.append(K.cyl("spare_rim", (2.52, 0.0, 1.3), (2.52, 0.0, 1.315), 0.22, K.mat("Trim_Ivory", (0.66, 0.64, 0.56), 0.4, 0.4), 28))
    obs.append(K.cyl("spare_clamp", (2.52, 0.0, 1.3), (2.52, 0.0, 1.35), 0.04, galv(), 12))
    # Chassis rails, springs, the exhaust.
    for side in (1.0, -1.0):
        obs.append(K.box("rail", ((REAR + FRONT) * 0.5, side * 0.42, 0.46), (FRONT - REAR, 0.07, 0.14), steel()))
        for x in (0.0, WB):
            obs.append(K.box("leaf", (x, side * 0.42, 0.34), (1.1, 0.06, 0.05), steel(), bevel=0.01))
        obs.append(K.cyl("axle", (0.0, side * 0.08, R), (0.0, side * 0.56, R), 0.05, steel(), 14))
        obs.append(K.cyl("axle_f", (WB, side * 0.08, R), (WB, side * 0.56, R), 0.05, steel(), 14))
    obs.append(K.revolve("diff", [(-0.14, 0.04), (-0.1, 0.13), (0.0, 0.15), (0.1, 0.12), (0.14, 0.04)], (0.0, -0.1, R), (0, 1, 0), steel(), 20))
    obs.append(K.revolve("diff_f", [(-0.14, 0.04), (-0.1, 0.13), (0.0, 0.15), (0.1, 0.12), (0.14, 0.04)], (WB, 0.1, R), (0, 1, 0), steel(), 20))
    obs.append(K.tube("exhaust", [(1.9, -0.3, 0.42), (0.6, -0.32, 0.4), (-0.6, -0.3, 0.4), (-0.82, -0.3, 0.42)], 0.024,
                      K.mat("Trim_Exhaust", (0.09, 0.05, 0.03), 0.4, 0.75), 10))
    return obs


def cab():
    obs = []
    dash = interior("Dash", (0.12, 0.13, 0.12), 0.55)
    seat = interior("Seat", (0.07, 0.07, 0.075), 0.6)
    obs.append(K.box("dash", (BULK - 0.12, 0.0, 1.05), (0.12, 2 * HW - 0.08, 0.14), dash, bevel=0.02))
    obs.append(K.box("binnacle", (BULK - 0.2, 0.0, 1.1), (0.08, 0.36, 0.14), dash, bevel=0.02))
    face = interior("Gauge", (0.7, 0.7, 0.66), 0.3)
    for y in (-0.08, 0.08):
        obs.append(K.cyl("dial", (BULK - 0.242, y, 1.1), (BULK - 0.25, y, 1.1), 0.045, face, 20))
    obs.append(K.cyl("column", (BULK - 0.12, 0.38, 0.95), (1.72, 0.38, 1.2), 0.03, dash, 12))
    for y in (0.4, 0.0, -0.4):
        obs.append(K.box("cushion", (1.25, y, 0.95), (0.4, 0.4 if y else 0.34, 0.1), seat, bevel=0.03, segs=3))
        obs.append(K.box("back", (1.03, y, 1.22), (0.08, 0.4 if y else 0.34, 0.42), seat, bevel=0.03, segs=3, rot=(0.0, math.radians(-8), 0.0)))
    obs.append(K.tube("gear", [(1.62, 0.02, 0.8), (1.52, 0.03, 1.1)], 0.01, K.mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12), 8))
    obs.append(K.tube("transfer", [(1.58, -0.1, 0.8), (1.47, -0.12, 1.02)], 0.009, K.mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12), 8))
    for p in ((1.52, 0.03, 1.1), (1.47, -0.12, 1.02)):
        obs.append(K.cyl("knob", Vector(p) - Vector((0, 0, 0.02)), Vector(p) + Vector((0, 0, 0.025)), 0.022, K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.5), 12))
    obs.append(K.box("headliner", (0.6, 0.0, ROOF - 0.04), (2.4, 2 * HW - 0.2, 0.01), interior("Headliner", (0.5, 0.5, 0.47), 0.9)))
    return obs


def main():
    a = K.args()
    K.reset()
    parts = body_panels() + door_lines() + screen_and_top() + front_and_rear() + cab()
    steer = K.steering("Steering_Wheel", (1.68, 0.38, 1.24), (0.9, 0.0, -0.5), 0.21, interior("Steer", (0.03, 0.03, 0.03), 0.5))
    wheels = [K.wheel("WheelStock_FL", (WB, TRACK, R), R, W), K.wheel("WheelStock_FR", (WB, -TRACK, R), R, W),
              K.wheel("WheelStock_RL", (0.0, TRACK, R), R, W), K.wheel("WheelStock_RR", (0.0, -TRACK, R), R, W)]
    lamps = [o for o in parts if o.name.startswith(("Lamp_", "Lens_"))]
    named = [o for o in parts if o.name.startswith(("Glass_", "Windshield", "Numberplate"))]
    rest = [o for o in parts if o not in lamps and o not in named]
    groups = {}
    for o in lamps:
        key = o.name.split(".")[0]
        role = "Lens" if key.startswith("Lens_") else "_".join(key.split("_")[:2])
        groups.setdefault(role, []).append(o)
    lamp_meshes = [K.join(v, k) for k, v in groups.items()]
    inside = [o for o in rest if o.data.materials and o.data.materials[0].name.startswith("Interior_")]
    body = K.join([o for o in rest if o not in inside], "Offroad_Body")
    cabin = K.join(inside, "Offroad_Cab")
    K.export([body, cabin, steer] + wheels + lamp_meshes + named, OUT)
    if a.get("preview"):
        K.preview(os.path.join(a["preview"], "offroad"), centre=(1.0, 0.0, 1.0), dist=8.0,
                  views=("front3q", "back3q", "side", "left3q"))


if __name__ == "__main__":
    main()
