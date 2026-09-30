"""Builds the dealership's light truck (the "Yayla 35", a cab-over 3.5-tonne dropside of
the nineties that carries a whole harvest to the market): art/models/vehicles/truck/truck.glb.

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_truck.py [-- --preview=/abs/dir]

Modelled here from primitives (no outside assets) in the model frame of
tools/blender/vehicle_kit.py (front +X, left +Y, up +Z, ground z = 0), rear axle at x = 0:
- a cab-over cab: a thin shell lofted from its plan at five heights (the windshield leans
  back, the roof crowns), windows cut out and glazed in rubber seals, the front wheel
  arches cut into its sides and lined; doors with gaps, handles and steps, long-armed
  mirrors, a black grille and bumper with the headlamps and indicators, roof markers,
  wipers; inside a dash, a bench seat and a big, flat steering wheel;
- a ladder frame with crossmembers, a fuel tank, battery box, side guards, the exhaust,
  a rear underrun bar with the lamp clusters and the plate, mud flaps;
- a dropside body: a wooden floor on bearers, galvanised hinged sides and tailgate with
  latches, a headboard with a guard over the cab's back window;
- 16-inch steel wheels, singles in front and duals at the rear (the pickup's modelled
  wheel, build_pickup_hd.py).
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_kit as K  # noqa: E402

OUT = os.path.join(K.ROOT, "art/models/vehicles/truck/truck.glb")

WB = 3.35
R = 0.39
TRACK_F = 0.8
TRACK_R = 0.74
CAB_X0, CAB_X1 = 2.25, 3.97   # cab back and front
CAB_HW = 0.975
CAB_BOT = 0.52
BELT = 1.32
ROOF = 2.2
FRAME_Y = 0.43
FRAME_TOP = 0.84
BED_X0, BED_X1 = 2.12, -1.82
BED_HW = 1.02
BED_FLOOR = 1.06
SIDE_H = 0.56


def paint():
    return K.mat("Truck_Bodymat", (0.75, 0.75, 0.72), 0.2, 0.35)


def steel():
    return K.mat("Trim_Steel", (0.035, 0.036, 0.038), 0.55, 0.55)


def rubber():
    return K.mat("Trim_Rubber", (0.025, 0.025, 0.025), 0.0, 0.8)


def black_plastic():
    return K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.5)


def chrome():
    return K.mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12)


def galv():
    return K.mat("Trim_Galv", (0.55, 0.56, 0.56), 0.9, 0.42)


def gap():
    return K.mat("Trim_Gap", (0.008, 0.008, 0.008), 0.0, 0.9)


def interior(kind, color, rough=0.7):
    return K.mat("Interior_" + kind, color, 0.0, rough)


def front_x(z):
    """The cab's front face at height z (upright below the windshield, leaning back above)."""
    if z <= BELT + 0.04:
        return CAB_X1
    return CAB_X1 - (z - BELT - 0.04) / (ROOF - 0.06 - BELT - 0.04) * 0.13


def cab_shell():
    levels = []
    for z, xf, hw, r in ((CAB_BOT, CAB_X1, CAB_HW, 0.13), (BELT + 0.04, CAB_X1, CAB_HW, 0.13),
                         (ROOF - 0.06, front_x(ROOF - 0.06), CAB_HW - 0.03, 0.14), (ROOF, front_x(ROOF - 0.06) - 0.05, CAB_HW - 0.08, 0.12)):
        levels.append((z, K.plan_outline(xf, CAB_X0 + (0.03 if z > ROOF - 0.01 else 0.0), hw, r, 5, 0.05)))
    cab = K.plan_loft("cab", levels, paint(), cap_bottom=False, top_bevel=0.05, smooth=35.0)
    K.solidify(cab, 0.022)
    K.apply(cab)
    cutters = []
    # Windshield, door windows, the back window.
    cutters.append(K.loft("ws_cut", [[(front_x(z) + 0.2, -0.86, z), (front_x(z) + 0.2, 0.86, z), (front_x(z) - 0.2, 0.86, z),
                                      (front_x(z) - 0.2, -0.86, z)] for z in (BELT + 0.07, ROOF - 0.12)], paint(), smooth=None))
    for side in (1.0, -1.0):
        cutters.append(K.prism("door_cut", door_window(), side * 0.6, side * 1.2, paint(), plane="XZ"))
        # Front wheel arch through the lower sides.
        cutters.append(K.cyl("arch_cut", (WB, side * 0.62, R), (WB, side * 1.2, R), R + 0.075, paint(), 40))
    cutters.append(K.box("back_cut", (CAB_X0, 0.0, 1.78), (0.2, 0.9, 0.3), paint(), bevel=0.04))
    for c in cutters:
        K.cut(cab, c)
    K.apply(cab)
    K.remove(*cutters)
    obs = [cab]
    # Floor, the cab's bottom and the arch liners.
    obs.append(K.box("cab_floor", ((CAB_X0 + CAB_X1) * 0.5, 0.0, 0.86), (CAB_X1 - CAB_X0 - 0.05, 2 * CAB_HW - 0.05, 0.04), steel()))
    for side in (1.0, -1.0):
        pts = []
        for k in range(17):
            a = math.radians(-8 + 196 * k / 16)
            pts.append((WB + (R + 0.07) * math.cos(a), R + (R + 0.07) * math.sin(a)))
        obs.append(K.loft("liner", [[(px, side * yy, pz) for px, pz in pts] for yy in (0.6, CAB_HW - 0.01)],
                          K.mat("Trim_Liner", (0.02, 0.02, 0.02), 0.0, 0.9), closed=False, cap=False))
    return obs


def door_window():
    a0, a1 = BELT + 0.02, ROOF - 0.16
    return [(2.62, a0), (CAB_X1 - 0.16, a0), (front_x(a1) - 0.16, a1), (2.62, a1)]


def glazing():
    obs = []
    glass = K.mat("Glass_Clear", (0.86, 0.9, 0.9), 0.0, 0.05, alpha=0.2)
    z0, z1 = BELT + 0.07, ROOF - 0.12
    lean = Vector((ROOF - 0.06 - BELT - 0.04, 0.0, 0.13)).normalized()
    ws = [(front_x(z0) - 0.012, -0.86, z0), (front_x(z0) - 0.012, 0.86, z0), (front_x(z1) - 0.012, 0.86, z1), (front_x(z1) - 0.012, -0.86, z1)]
    obs.append(K.pane("Windshield", [(p[0], p[1] * 1.01, p[2]) for p in ws], glass))
    obs.append(K.seal("seal", [(front_x(z) + 0.002, y, z) for x, y, z in ws], 0.024, rubber(), lean, 0.01))
    for side, s in ((1.0, "L"), (-1.0, "R")):
        poly = door_window()
        y = side * (CAB_HW - 0.014)
        corners = [(x, y, z) for x, z in poly]
        obs.append(K.pane("Glass_Door" + s, corners, glass))
        obs.append(K.seal("seal", [(x, side * (CAB_HW + 0.001), z) for x, z in poly], 0.02, rubber(), (0.0, side, 0.0), 0.01))
    rb = [(CAB_X0 + 0.012, 0.44, 1.64), (CAB_X0 + 0.012, -0.44, 1.64), (CAB_X0 + 0.012, -0.44, 1.92), (CAB_X0 + 0.012, 0.44, 1.92)]
    obs.append(K.pane("Glass_Back", rb, glass))
    obs.append(K.seal("seal", [(CAB_X0 - 0.002, y, z) for x, y, z in rb], 0.02, rubber(), (-1.0, 0.0, 0.0), 0.01))
    return obs


def cab_details():
    obs = []
    g = gap()
    for side in (1.0, -1.0):
        y = side * (CAB_HW + 0.0005)
        n = (0.0, side, 0.0)
        # Door gaps: the rear edge, the front edge (down to the arch), the bottom.
        obs.append(K.strip("gap", (2.52, y, 0.92), (2.52, y, ROOF - 0.08), 0.005, 0.0015, g, n))
        obs.append(K.strip("gap", (CAB_X1 - 0.07, y, R + R + 0.1), (CAB_X1 - 0.07, y, BELT + 0.03), 0.005, 0.0015, g, n))
        obs.append(K.strip("gap", (2.52, y, 0.92), (WB - R - 0.1, y, 0.92), 0.005, 0.0015, g, n))
        for k in range(8):
            a0 = math.radians(95 + 70 * k / 8)
            a1 = math.radians(95 + 70 * (k + 1) / 8)
            ra = R + 0.12
            obs.append(K.strip("gap", (WB + ra * math.cos(a0), y, R + ra * math.sin(a0)), (WB + ra * math.cos(a1), y, R + ra * math.sin(a1)),
                               0.005, 0.0015, g, n))
        obs.append(K.box("handle", (2.72, side * (CAB_HW + 0.012), BELT - 0.08), (0.16, 0.02, 0.035), black_plastic(), bevel=0.008))
        obs.append(K.box("lock", (2.68, side * (CAB_HW + 0.008), BELT - 0.14), (0.025, 0.012, 0.025), chrome(), bevel=0.005))
        # Steps behind the arch, a grab handle by the door.
        for z in (0.5, 0.74):
            obs.append(K.box("step", (2.66, side * (CAB_HW - 0.1), z), (0.34, 0.2, 0.03), K.mat("Trim_Chequer", (0.3, 0.3, 0.3), 0.8, 0.45)))
        obs.append(K.box("step_hanger", (2.66, side * (CAB_HW - 0.02), 0.62), (0.3, 0.015, 0.3), black_plastic()))
        obs.append(K.tube("grab", [(2.36, side * (CAB_HW + 0.01), 1.05), (2.33, side * (CAB_HW + 0.05), 1.1),
                                   (2.33, side * (CAB_HW + 0.05), 1.6), (2.36, side * (CAB_HW + 0.01), 1.65)], 0.013, black_plastic(), 8))
        # Mirrors: a tall head on tubular arms off the door's front.
        arm_a = Vector((CAB_X1 - 0.12, side * (CAB_HW + 0.01), 1.45))
        arm_b = Vector((CAB_X1 - 0.12, side * (CAB_HW + 0.01), 1.95))
        head = Vector((CAB_X1 - 0.18, side * (CAB_HW + 0.26), 1.7))
        obs.append(K.tube("mirror_arm", [arm_a, arm_a + Vector((0, side * 0.2, 0.05)), head + Vector((0, 0, -0.18))], 0.012, black_plastic(), 8))
        obs.append(K.tube("mirror_arm", [arm_b, arm_b + Vector((0, side * 0.2, -0.05)), head + Vector((0, 0, 0.18))], 0.012, black_plastic(), 8))
        obs.append(K.box("mirror_head", head, (0.06, 0.2, 0.36), black_plastic(), bevel=0.02))
        obs.append(K.box("mirror_glass", head + Vector((-0.032, 0, 0)), (0.004, 0.18, 0.33), K.mat("Trim_Mirror", (0.9, 0.9, 0.9), 1.0, 0.03)))
        # Roof marker lamps at the front corners.
        obs.append(K.box("roof_marker", (front_x(ROOF) - 0.1, side * 0.7, ROOF + 0.02), (0.06, 0.1, 0.04), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1), bevel=0.01))
    # Front: the grille band, the badge, the bumper with the lamps set in it.
    fx = CAB_X1 + 0.002
    obs.append(K.box("grille", (fx, 0.0, 1.06), (0.03, 1.3, 0.3), K.mat("Trim_Grille", (0.015, 0.015, 0.015), 0.2, 0.6), bevel=0.02))
    for k in range(5):
        obs.append(K.box("slat", (fx + 0.012, 0.0, 0.95 + k * 0.055), (0.02, 1.24, 0.02), black_plastic(), bevel=0.005, segs=1))
    obs.append(K.box("badge", (fx + 0.03, 0.0, 1.25), (0.012, 0.36, 0.06), chrome(), bevel=0.01))
    obs.append(K.box("bumper", (CAB_X1 + 0.03, 0.0, 0.62), (0.16, 2 * CAB_HW + 0.02, 0.26), K.mat("Trim_BumperGrey", (0.22, 0.23, 0.24), 0.2, 0.5),
                     bevel=0.03, segs=2))
    obs.append(K.box("bumper_step", (CAB_X1 + 0.05, 0.0, 0.5), (0.14, 0.7, 0.02), K.mat("Trim_Chequer", (0.3, 0.3, 0.3), 0.8, 0.45)))
    head = K.mat("Lamp_HeadReflector", (0.85, 0.85, 0.82), 1.0, 0.12)
    lens = K.mat("Lens_Clear", (0.95, 0.95, 0.95), 0.0, 0.05, alpha=0.25)
    for side, s in ((1.0, "L"), (-1.0, "R")):
        obs += K.lamp_rect("Head_" + s, (CAB_X1 + 0.02, side * 0.68, 0.87), (1, 0, 0), 0.34, 0.16, head, depth=0.03, bezel_mat=chrome(), lens_mat=lens)
        obs.append(K.box("ind", (CAB_X1 + 0.03, side * 0.9, 0.87), (0.02, 0.1, 0.16), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1), bevel=0.01))
        obs.append(K.box("fog", (CAB_X1 + 0.11, side * 0.62, 0.6), (0.02, 0.14, 0.07), K.mat("Trim_Fog", (0.8, 0.78, 0.6), 0.0, 0.1), bevel=0.01))
    obs.append(K.plate("Numberplate_Front", (CAB_X1 + 0.115, 0.0, 0.64), (1, 0, 0)))
    for y0, y1 in ((0.78, 0.05), (-0.04, -0.77)):
        z = BELT + 0.06
        obs.append(K.tube("wiper", [(front_x(z) + 0.035, y0, z), (front_x(z + 0.02) + 0.03, y1, z + 0.02)], 0.007, black_plastic(), 6))
    # Sun visor over the windshield.
    obs.append(K.box("visor", (front_x(ROOF) + 0.06, 0.0, ROOF - 0.03), (0.16, 1.8, 0.02), paint(), bevel=0.008, rot=(0.0, math.radians(8), 0.0)))
    return obs


def cab_inside():
    obs = []
    dash = interior("Dash", (0.05, 0.05, 0.055), 0.6)
    seat = interior("Seat", (0.1, 0.11, 0.13), 0.75)
    card = interior("DoorCard", (0.22, 0.22, 0.23), 0.7)
    obs.append(K.box("dash", (CAB_X1 - 0.25, 0.0, 1.2), (0.36, 2 * CAB_HW - 0.1, 0.24), dash, bevel=0.05, segs=3))
    obs.append(K.box("binnacle", (CAB_X1 - 0.43, 0.48, 1.34), (0.14, 0.42, 0.08), dash, bevel=0.03))
    face = interior("Gauge", (0.7, 0.7, 0.66), 0.3)
    for y in (0.38, 0.58):
        obs.append(K.cyl("dial", (CAB_X1 - 0.5, y, 1.32), (CAB_X1 - 0.508, y, 1.32), 0.055, face, 24))
    obs.append(K.cyl("column", (CAB_X1 - 0.35, 0.48, 1.0), (CAB_X1 - 0.62, 0.48, 1.33), 0.035, dash, 12))
    # Bench seat for three.
    obs.append(K.box("seat", (2.72, 0.0, 1.22), (0.5, 2 * CAB_HW - 0.14, 0.14), seat, bevel=0.05, segs=3))
    obs.append(K.box("seat_back", (2.43, 0.0, 1.58), (0.12, 2 * CAB_HW - 0.14, 0.6), seat, bevel=0.05, segs=3, rot=(0.0, math.radians(-10), 0.0)))
    obs.append(K.box("seat_box", (2.7, 0.0, 1.02), (0.5, 2 * CAB_HW - 0.14, 0.28), dash))
    obs.append(K.tube("gear", [(3.3, 0.12, 0.9), (3.2, 0.16, 1.3)], 0.01, chrome(), 8))
    obs.append(K.cyl("knob", (3.2, 0.16, 1.29), (3.19, 0.16, 1.35), 0.024, dash, 12))
    for side in (1.0, -1.0):
        obs.append(K.box("card", (3.1, side * (CAB_HW - 0.035), 1.15), (1.2, 0.02, 0.45), card, bevel=0.01))
    obs.append(K.box("headliner", ((CAB_X0 + CAB_X1) * 0.5, 0.0, ROOF - 0.04), (CAB_X1 - CAB_X0 - 0.2, 2 * CAB_HW - 0.2, 0.01),
                     interior("Headliner", (0.5, 0.5, 0.47), 0.9)))
    return obs


def chassis():
    obs = []
    for side in (1.0, -1.0):
        obs.append(K.box("rail", ((BED_X1 + CAB_X1) * 0.5 - 0.05, side * FRAME_Y, FRAME_TOP - 0.11), (CAB_X1 - BED_X1 - 0.2, 0.08, 0.22), steel()))
        # Leaf springs and shackles at both axles.
        for x, ln in ((0.0, 1.3), (WB, 1.2)):
            obs.append(K.box("leaf", (x, side * FRAME_Y, 0.56), (ln, 0.07, 0.06), steel(), bevel=0.01))
            obs.append(K.box("u_bolts", (x, side * FRAME_Y, 0.52), (0.14, 0.1, 0.14), steel()))
    for x in (-1.6, -0.9, -0.3, 0.6, 1.4, 2.2, 3.0, 3.8):
        obs.append(K.box("crossmember", (x, 0.0, FRAME_TOP - 0.1), (0.07, 2 * FRAME_Y, 0.16), steel()))
    for side in (1.0, -1.0):
        obs.append(K.cyl("axle", (0.0, side * 0.1, R), (0.0, side * 0.6, R), 0.06, steel(), 16))
    obs.append(K.revolve("diff", [(-0.2, 0.05), (-0.15, 0.17), (0.0, 0.2), (0.15, 0.16), (0.2, 0.05)], (0.0, 0.0, R), (0, 1, 0), steel(), 24))
    obs.append(K.box("front_axle", (WB, 0.0, R + 0.05), (0.1, 1.4, 0.1), steel(), bevel=0.015))
    obs.append(K.cyl("driveshaft", (0.1, 0.0, R + 0.05), (2.4, 0.0, 0.6), 0.04, steel(), 12))
    # Fuel tank on the right, battery box on the left, side guards, the exhaust.
    obs.append(K.box("tank", (1.35, -(FRAME_Y + 0.22), 0.62), (0.7, 0.36, 0.34), K.mat("Trim_Tank", (0.4, 0.41, 0.42), 0.7, 0.4), bevel=0.06, segs=3))
    for x in (1.15, 1.55):
        obs.append(K.box("strap", (x, -(FRAME_Y + 0.22), 0.62), (0.03, 0.38, 0.36), steel()))
    obs.append(K.cyl("filler", (1.5, -(FRAME_Y + 0.4), 0.74), (1.5, -(FRAME_Y + 0.42), 0.78), 0.04, black_plastic(), 12))
    obs.append(K.box("battery", (1.3, FRAME_Y + 0.2, 0.62), (0.5, 0.3, 0.3), black_plastic(), bevel=0.02))
    for side in (1.0, -1.0):
        for z in (0.55, 0.78):
            obs.append(K.box("guard", (1.45 if side > 0 else 0.6, side * (BED_HW - 0.04), z), (1.1 if side > 0 else 0.7, 0.04, 0.05), steel()))
    obs.append(K.tube("exhaust", [(2.0, -0.25, 0.62), (1.0, -0.3, 0.58), (-0.6, -0.3, 0.58), (-0.7, -0.5, 0.55)], 0.03,
                      K.mat("Trim_Exhaust", (0.09, 0.05, 0.03), 0.4, 0.75), 12))
    obs.append(K.cyl("silencer", (1.7, -0.28, 0.6), (0.9, -0.29, 0.58), 0.09, K.mat("Trim_Exhaust", (0.09, 0.05, 0.03), 0.4, 0.75), 16))
    # Spare wheel under the back of the frame.
    obs.append(K.cyl("spare", (-1.2, 0.0, 0.52), (-1.2, 0.0, 0.72), 0.36, rubber(), 28))
    # Rear underrun bar, the lamps and the plate, mud flaps.
    ux = BED_X1 + 0.08
    obs.append(K.box("underrun", (ux, 0.0, 0.46), (0.08, 1.8, 0.12), steel(), bevel=0.01))
    for side in (1.0, -1.0):
        obs.append(K.box("underrun_arm", (ux + 0.18, side * 0.4, 0.62), (0.36, 0.06, 0.06), steel()))
        obs.append(K.box("flap", (-0.55, side * 0.76, 0.42), (0.012, 0.52, 0.5), rubber(), bevel=0.004))
        obs.append(K.box("flap_bar", (-0.55, side * 0.76, 0.7), (0.03, 0.54, 0.03), steel()))
    return obs


def rear_lamps():
    obs = []
    red = K.mat("Lamp_Red", (0.45, 0.02, 0.015), 0.0, 0.15)
    white = K.mat("Lamp_White", (0.8, 0.8, 0.78), 0.0, 0.1)
    for side, s in ((1.0, "L"), (-1.0, "R")):
        c = Vector((BED_X1 + 0.035, side * 0.72, 0.62))
        obs.append(K.box("lamp_house", c + Vector((0.02, 0, 0)), (0.06, 0.42, 0.14), black_plastic(), bevel=0.01))
        obs.append(K.box("lamp_bracket", c + Vector((0.12, 0, 0.08)), (0.16, 0.06, 0.04), steel()))
        obs += K.lamp_rect("Brake_" + s, c + Vector((-0.012, side * 0.08, 0)), (-1, 0, 0), 0.2, 0.1, red, depth=0.012, ribs=3)
        obs += K.lamp_rect("Reverse_" + s, c + Vector((-0.012, side * -0.1, 0)), (-1, 0, 0), 0.09, 0.1, white, depth=0.012)
        obs.append(K.box("ind", c + Vector((-0.014, side * 0.19, 0)), (0.008, 0.05, 0.1), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1)))
    obs.append(K.plate("Numberplate_Rear", (BED_X1 + 0.03, 0.0, 0.58), (-1, 0, 0)))
    return obs


def dropside():
    obs = []
    wood = K.mat("Trim_Wood", (0.42, 0.33, 0.24), 0.0, 0.8)
    side_mat = K.mat("Trim_BedSide", (0.55, 0.56, 0.56), 0.85, 0.45)
    # Bearers on the frame, cross sills, the plank floor with steel edges.
    for side in (1.0, -1.0):
        obs.append(K.box("bearer", ((BED_X0 + BED_X1) * 0.5, side * FRAME_Y, FRAME_TOP + 0.05), (BED_X0 - BED_X1, 0.09, 0.1), steel()))
    for k in range(10):
        x = BED_X0 - 0.05 - k * (BED_X0 - BED_X1 - 0.1) / 9
        obs.append(K.box("sill", (x, 0.0, FRAME_TOP + 0.13), (0.07, 2 * BED_HW, 0.06), steel()))
    n = 10
    gp = 0.008
    w = (2 * (BED_HW - 0.04) - (n - 1) * gp) / n
    for k in range(n):
        y = -(BED_HW - 0.04) + w * 0.5 + k * (w + gp)
        pl = K.box("plank", ((BED_X0 + BED_X1) * 0.5, y, BED_FLOOR - 0.02), (BED_X0 - BED_X1 - 0.04, w, 0.04), wood, bevel=0.004, segs=1)
        K.uv_box(pl, 0.45)
        obs.append(pl)
    for side in (1.0, -1.0):
        obs.append(K.box("edge", ((BED_X0 + BED_X1) * 0.5, side * (BED_HW - 0.02), BED_FLOOR - 0.04), (BED_X0 - BED_X1, 0.05, 0.12), steel()))
    obs.append(K.box("rear_edge", (BED_X1 + 0.02, 0.0, BED_FLOOR - 0.04), (0.05, 2 * BED_HW, 0.12), steel()))
    # Drop sides: ribbed galvanised panels on hinges, latches at the posts.
    top = BED_FLOOR + SIDE_H
    mid_x = (BED_X0 + BED_X1) * 0.5 + 0.05
    for side in (1.0, -1.0):
        for x0, x1 in ((BED_X0 - 0.06, mid_x + 0.03), (mid_x - 0.03, BED_X1 + 0.06)):
            obs.append(K.box("side_panel", ((x0 + x1) * 0.5, side * (BED_HW - 0.015), BED_FLOOR + SIDE_H * 0.5), (x0 - x1, 0.03, SIDE_H), side_mat, bevel=0.006))
            for z in (BED_FLOOR + 0.14, BED_FLOOR + 0.28, BED_FLOOR + 0.42):
                obs.append(K.box("rib", ((x0 + x1) * 0.5, side * (BED_HW + 0.002), z), (x0 - x1 - 0.06, 0.012, 0.035), side_mat, bevel=0.005, segs=1))
            obs.append(K.box("top_rail", ((x0 + x1) * 0.5, side * (BED_HW - 0.01), top), (x0 - x1, 0.05, 0.04), side_mat, bevel=0.01))
            for x in (x0 - 0.3, x1 + 0.3):
                obs.append(K.cyl("hinge", (x - 0.05, side * (BED_HW + 0.01), BED_FLOOR + 0.01), (x + 0.05, side * (BED_HW + 0.01), BED_FLOOR + 0.01), 0.016, galv(), 8))
        obs.append(K.box("post", (mid_x, side * (BED_HW - 0.02), BED_FLOOR + SIDE_H * 0.5), (0.07, 0.07, SIDE_H + 0.06), steel(), bevel=0.008))
        for x in (mid_x + 0.06, mid_x - 0.06):
            obs.append(K.box("latch", (x, side * (BED_HW + 0.02), top - 0.08), (0.06, 0.02, 0.05), galv(), bevel=0.006))
        obs.append(K.box("post_r", (BED_X1 + 0.035, side * (BED_HW - 0.02), BED_FLOOR + SIDE_H * 0.5), (0.07, 0.07, SIDE_H + 0.06), steel(), bevel=0.008))
    # Tailgate.
    obs.append(K.box("tailgate", (BED_X1 + 0.02, 0.0, BED_FLOOR + SIDE_H * 0.5), (0.03, 2 * BED_HW - 0.12, SIDE_H), side_mat, bevel=0.006))
    for z in (BED_FLOOR + 0.14, BED_FLOOR + 0.28, BED_FLOOR + 0.42):
        obs.append(K.box("rib", (BED_X1 + 0.002, 0.0, z), (0.012, 2 * BED_HW - 0.2, 0.035), side_mat, bevel=0.005, segs=1))
    for side in (1.0, -1.0):
        obs.append(K.box("gate_latch", (BED_X1 - 0.004, side * (BED_HW - 0.1), top - 0.08), (0.02, 0.06, 0.05), galv(), bevel=0.006))
    # Headboard with a guard over the cab's back window.
    hx = BED_X0 - 0.02
    obs.append(K.box("headboard", (hx, 0.0, BED_FLOOR + 0.35), (0.04, 2 * BED_HW, 0.7), side_mat, bevel=0.008))
    for side in (1.0, -1.0):
        obs.append(K.box("hb_post", (hx, side * (BED_HW - 0.04), (BED_FLOOR + ROOF + 0.05) * 0.5), (0.07, 0.07, ROOF + 0.05 - BED_FLOOR), steel(), bevel=0.01))
    obs.append(K.box("hb_top", (hx, 0.0, ROOF + 0.02), (0.07, 2 * BED_HW, 0.07), steel(), bevel=0.01))
    for k in range(11):
        y = -0.9 + k * 0.18
        obs.append(K.cyl("hb_bar", (hx, y, BED_FLOOR + 0.7), (hx, y, ROOF - 0.02), 0.012, steel(), 8))
    return obs


def main():
    a = K.args()
    K.reset()
    parts = cab_shell() + cab_details() + cab_inside() + chassis() + rear_lamps() + dropside()
    panes = glazing()
    steer = K.steering("Steering_Wheel", (CAB_X1 - 0.64, 0.48, 1.36), (0.55, 0.0, -0.83), 0.23, interior("Steer", (0.03, 0.03, 0.03), 0.5))
    wheels = [K.wheel("WheelStock_FL", (WB, TRACK_F, R), R, 0.21), K.wheel("WheelStock_FR", (WB, -TRACK_F, R), R, 0.21),
              K.wheel("WheelStock_RL", (0.0, TRACK_R, R), R, 0.46, dual=True), K.wheel("WheelStock_RR", (0.0, -TRACK_R, R), R, 0.46, dual=True)]
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
    body = K.join([o for o in rest if o not in inside], "Truck_Body")
    cabin = K.join(inside, "Truck_Cab")
    K.export([body, cabin, steer] + wheels + lamp_meshes + named, OUT)
    if a.get("preview"):
        K.preview(os.path.join(a["preview"], "truck"), centre=(1.1, 0.0, 1.1), dist=10.5,
                  views=("front3q", "back3q", "side", "left3q"))


if __name__ == "__main__":
    main()
