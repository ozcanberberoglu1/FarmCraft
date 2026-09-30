"""Builds the parts that turn the Lightbody '90 pickup (art/models/vehicles/pickup_90)
into the dealership's other bodies on the same chassis:
  art/models/vehicles/pickup_90/canopy.glb   a cab-high fibreglass canopy over the bed
  art/models/vehicles/pickup_90/stake.glb    a flat wooden deck with a headboard, stakes
                                             and drop-side boards (the steel bed comes off)
  art/models/vehicles/pickup_90/box.glb      a closed aluminium box body with barn doors
                                             (the steel bed comes off)
Each is in the pickup's model frame and is added to it by the game (VehicleTable
"extra"; "hide_parts" names the pickup's meshes it replaces).

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_pickup_variants.py [-- --preview=/abs/dir]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_kit as K  # noqa: E402

SRC = os.path.join(K.ROOT, "art/models/vehicles/pickup_90/scene.gltf")
OUT = os.path.join(K.ROOT, "art/models/vehicles/pickup_90")

# The pickup's bed (Blender axes): rails on top at RAIL, outer skins at +-BED_W, from
# the cab (BED_X0) to the tailgate (BED_X1). The cab's roof tops out at CAB_TOP.
RAIL = 1.229
BED_W = 0.985
BED_X0 = 0.07
BED_X1 = -2.30
CAB_TOP = 1.686
# Frame rails under the bed: tops at about FRAME_TOP, at y = +-FRAME_Y.
FRAME_TOP = 0.62
FRAME_Y = 0.47


def paint():
    return K.mat("Extra_Bodymat", (0.3, 0.3, 0.3), 0.4, 0.35)


def steel():
    return K.mat("Trim_Steel", (0.035, 0.036, 0.038), 0.55, 0.55)


def rubber():
    return K.mat("Trim_Rubber", (0.025, 0.025, 0.025), 0.0, 0.8)


def chrome():
    return K.mat("Trim_Chrome", (0.8, 0.8, 0.8), 1.0, 0.12)


def galv():
    return K.mat("Trim_Galv", (0.55, 0.56, 0.56), 0.9, 0.42)


def rrect(x, w0, w1, z0, z1, r, n=6, bottom_r=0.0):
    """A cross-section at x: a trapezoid from +-w0 at z0 to +-w1 at z1, top corners
    rounded by r (bottom ones by bottom_r); points go round anticlockwise seen from +x."""
    pts = []

    def corner(cy, cz, rr, a0, a1):
        for k in range(n + 1):
            a = a0 + (a1 - a0) * k / n
            pts.append((x, cy + rr * math.cos(a), cz + rr * math.sin(a)))
    # Bottom edge (right to left is -y to +y), up the left side, over the top, down the right.
    if bottom_r > 0.0:
        corner(-w0 + bottom_r, z0 + bottom_r, bottom_r, math.pi * 1.0, math.pi * 1.5)
        corner(w0 - bottom_r, z0 + bottom_r, bottom_r, math.pi * 1.5, math.pi * 2.0)
    else:
        pts.append((x, -w0, z0))
        pts.append((x, w0, z0))
    corner(w1 - r, z1 - r, r, 0.0, math.pi * 0.5)
    corner(-w1 + r, z1 - r, r, math.pi * 0.5, math.pi)
    return pts


# --- Canopy --------------------------------------------------------------------------------

def canopy():
    """A cab-high fibreglass canopy: a moulded shell painted like the truck, big bonded
    tinted side windows, a small front window, a lift-up rear door in a black frame on
    gas struts, a third brake lamp, bed-rail clamps and a pair of roof bars."""
    obs = []
    top = CAB_TOP + 0.02
    x0, x1 = BED_X0 - 0.01, BED_X1 + 0.005
    w0, w1 = BED_W - 0.01, BED_W - 0.075

    def sec(x, inset=0.0, zlo=RAIL, ztop=top):
        return rrect(x, w0 - inset, w1 - inset, zlo, ztop - inset, 0.09 - inset * 0.5, 7)
    # Outer shell: a gentle curve into the front and a slight lean at the back.
    outer = K.loft("canopy_outer", [sec(x0 - 0.0, 0.035, RAIL, top - 0.03), sec(x0 - 0.035), sec(x1 + 0.04), sec(x1 + 0.005, 0.02, RAIL, top - 0.015)],
                   paint(), smooth=35.0)
    inner = K.loft("canopy_inner", [sec(x0 - 0.03, 0.03, RAIL - 0.1, top - 0.03), sec(x1 - 0.1, 0.03, RAIL - 0.1, top - 0.03)], paint())
    K.cut(outer, inner)
    # Window openings: sides, front, rear door.
    cutters = [inner]
    for side in (1.0, -1.0):
        cutters.append(K.box("win_side", (-1.08, side * (w0 - 0.02), 1.47), (1.86, 0.3, 0.3), paint(), bevel=0.06, segs=3))
    cutters.append(K.box("win_front", (x0, 0.0, 1.46), (0.2, 1.1, 0.24), paint(), bevel=0.05, segs=3))
    cutters.append(K.box("win_rear", (x1, 0.0, 1.455), (0.2, 1.72, 0.36), paint(), bevel=0.04, segs=3))
    for c in cutters[1:]:
        K.cut(outer, c)
    K.apply(outer)
    K.remove(*cutters)
    obs.append(outer)
    # Side glass: dark tinted, bonded flush in the shell (its lean follows the side).
    lean = math.atan2(w0 - w1, top - RAIL)
    for side, name in ((1.0, "Glass_Canopy_L"), (-1.0, "Glass_Canopy_R")):
        g = K.box(name, (-1.08, side * (w0 - 0.012 - 0.045), 1.47), (1.9, 0.006, 0.33),
                  K.mat("Glass_Tinted", (0.02, 0.025, 0.03), 0.0, 0.05, alpha=0.75), bevel=0.0,
                  rot=Matrix.Rotation(side * lean, 3, "X"))
        K.uv_pane(g)
        obs.append(g)
        seal = K.box("seal", (-1.08, side * (w0 - 0.012 - 0.045), 1.47), (1.92, 0.012, 0.35), rubber(), bevel=0.012,
                     rot=Matrix.Rotation(side * lean, 3, "X"))
        hole = K.box("seal_hole", (-1.08, side * (w0 - 0.012 - 0.045), 1.47), (1.84, 0.1, 0.29), rubber())
        K.cut(seal, hole)
        K.apply(seal)
        K.remove(hole)
        obs.append(seal)
    g = K.box("Glass_Canopy_Front", (x0 - 0.02, 0.0, 1.46), (0.006, 1.08, 0.23), K.mat("Glass_Tinted", (0.02, 0.025, 0.03), 0.0, 0.05, alpha=0.75))
    K.uv_pane(g)
    obs.append(g)
    # Rear lift door: a black-framed panel filling the canopy's back, hinged at the
    # roof, with the glass in it, two struts and a locking T-handle.
    door_x = x1 + 0.005
    back = [(p[1], p[2]) for p in sec(door_x)]
    frame = K.prism("door_frame", back, door_x - 0.035, door_x, K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.45),
                    plane="YZ")
    hole = K.box("door_hole", (door_x - 0.02, 0.0, 1.47), (0.2, 1.6, 0.33), rubber(), bevel=0.04, segs=3)
    K.cut(frame, hole)
    K.apply(frame)
    K.remove(hole)
    obs.append(frame)
    g = K.box("Glass_Canopy_Rear", (door_x - 0.02, 0.0, 1.47), (0.006, 1.62, 0.35), K.mat("Glass_Tinted", (0.02, 0.025, 0.03), 0.0, 0.05, alpha=0.75))
    K.uv_pane(g)
    obs.append(g)
    obs.append(K.box("handle", (door_x - 0.05, 0.0, 1.285), (0.03, 0.16, 0.03), chrome(), bevel=0.01))
    obs.append(K.cyl("lock", (door_x - 0.035, 0.09, 1.285), (door_x - 0.065, 0.09, 1.285), 0.012, chrome(), 12))
    for side in (1.0, -1.0):
        obs.append(K.box("hinge", (door_x - 0.01, side * 0.55, top - 0.035), (0.05, 0.12, 0.02), steel(), bevel=0.005))
        obs.append(K.tube("strut", [(door_x - 0.05, side * 0.8, 1.33), (door_x - 0.05, side * 0.78, 1.6)], 0.008, steel(), 8))
    # Third brake lamp over the door.
    obs += K.lamp_rect("Brake_Canopy", (door_x - 0.036, 0.0, top - 0.06), (-1, 0, 0), 0.34, 0.035,
                       K.mat("Lamp_Red", (0.45, 0.02, 0.015), 0.0, 0.15), depth=0.02, bezel_mat=K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.45))
    # Clamps over the bed rails and a rubber seal along the base.
    for x in (-0.3, -1.2, -2.05):
        for side in (1.0, -1.0):
            obs.append(K.box("clamp", (x, side * (BED_W - 0.02), RAIL - 0.04), (0.07, 0.04, 0.1), steel(), bevel=0.006))
    for side in (1.0, -1.0):
        obs.append(K.box("base_seal", ((x0 + x1) * 0.5, side * (w0 - 0.01), RAIL + 0.006), (x0 - x1 - 0.02, 0.05, 0.012), rubber(), bevel=0.004))
    # Roof bars on feet.
    for x in (-0.45, -1.85):
        obs.append(K.box("roof_bar", (x, 0.0, top + 0.07), (0.05, 1.62, 0.035), K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.45), bevel=0.012))
        for side in (1.0, -1.0):
            obs.append(K.box("roof_foot", (x, side * 0.76, top + 0.03), (0.08, 0.07, 0.06), K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.45),
                             bevel=0.015))
    return obs


# --- Stake bed -----------------------------------------------------------------------------

DECK_TOP = 0.92
DECK_X0 = 0.03
DECK_X1 = -2.58
DECK_W = 1.0


def subframe(x0, x1, top):
    """Longitudinal bearers on the chassis rails and crossmembers under a deck whose
    underside is at `top`."""
    obs = []
    for side in (1.0, -1.0):
        obs.append(K.box("bearer", ((x0 + x1) * 0.5, side * FRAME_Y, (FRAME_TOP + top - 0.06) * 0.5), (x0 - x1 - 0.1, 0.07, top - 0.06 - FRAME_TOP),
                         steel(), bevel=0.004))
        # U-bolts round the chassis rails.
        for x in (-0.3, -1.3, -2.1):
            obs.append(K.box("ubolt", (x, side * FRAME_Y, FRAME_TOP - 0.05), (0.03, 0.1, 0.16), steel()))
    n = int((x0 - x1) / 0.42)
    for k in range(n + 1):
        x = x0 - 0.04 - k * (x0 - x1 - 0.08) / n
        obs.append(K.box("cross", (x, 0.0, top - 0.035), (0.06, 2 * DECK_W - 0.04, 0.07), steel(), bevel=0.004))
    return obs


def planks(x0, x1, y_w, top, thick=0.04, n=9, material=None):
    obs = []
    material = material or K.mat("Trim_Wood", (0.42, 0.33, 0.24), 0.0, 0.8)
    gap = 0.008
    w = (2 * y_w - (n - 1) * gap) / n
    for k in range(n):
        y = -y_w + w * 0.5 + k * (w + gap)
        p = K.box("plank", ((x0 + x1) * 0.5, y, top - thick * 0.5), (x0 - x1, w, thick), material, bevel=0.004, segs=1)
        obs.append(p)
    return obs


def stake_bed():
    obs = []
    top = DECK_TOP
    obs += subframe(DECK_X0, DECK_X1, top - 0.04)
    deck = planks(DECK_X0 - 0.02, DECK_X1 + 0.02, DECK_W - 0.05, top)
    obs += deck
    # Steel edge rails with stake pockets, and the rear sill.
    for side in (1.0, -1.0):
        obs.append(K.box("edge", ((DECK_X0 + DECK_X1) * 0.5, side * (DECK_W - 0.025), top - 0.05), (DECK_X0 - DECK_X1, 0.05, 0.12), paint(), bevel=0.006))
    obs.append(K.box("sill", (DECK_X1 + 0.025, 0.0, top - 0.05), (0.05, 2 * DECK_W, 0.12), paint(), bevel=0.006))
    # Headboard: a painted steel frame with a mesh of bars over the cab's back window.
    hb_x = DECK_X0 - 0.015
    hb_top = CAB_TOP + 0.03
    obs.append(K.box("hb_base", (hb_x, 0.0, top + 0.2), (0.04, 2 * DECK_W - 0.02, 0.4), paint(), bevel=0.008))
    for side in (1.0, -1.0):
        obs.append(K.box("hb_post", (hb_x, side * (DECK_W - 0.04), (top + hb_top) * 0.5), (0.06, 0.06, hb_top - top), paint(), bevel=0.008))
    obs.append(K.box("hb_top", (hb_x, 0.0, hb_top - 0.03), (0.06, 2 * DECK_W - 0.02, 0.06), paint(), bevel=0.008))
    for k in range(9):
        y = -0.72 + k * 0.18
        obs.append(K.cyl("hb_bar", (hb_x, y, top + 0.4), (hb_x, y, hb_top - 0.06), 0.011, paint(), 8))
    # Stakes in the pockets, three boards on each side and on the tailgate.
    wood = K.mat("Trim_Wood", (0.42, 0.33, 0.24), 0.0, 0.8)
    stake_h = 0.56
    xs = [DECK_X0 - 0.12, -0.83, -1.7, DECK_X1 + 0.05]
    for side in (1.0, -1.0):
        for x in xs:
            obs.append(K.box("stake", (x, side * (DECK_W - 0.03), top + stake_h * 0.5 - 0.06), (0.055, 0.055, stake_h + 0.12), paint(), bevel=0.006))
        for k in range(3):
            z = top + 0.09 + k * 0.17
            obs.append(K.box("board", ((xs[0] + xs[-1]) * 0.5, side * (DECK_W - 0.065), z), (xs[0] - xs[-1] - 0.05, 0.028, 0.14), wood, bevel=0.005, segs=1))
    for k in range(3):
        z = top + 0.09 + k * 0.17
        obs.append(K.box("gate_board", (DECK_X1 + 0.02, 0.0, z), (0.028, 2 * DECK_W - 0.14, 0.14), wood, bevel=0.005, segs=1))
    for side in (1.0, -1.0):
        # Gate chains and pins.
        obs.append(K.tube("chain", [(DECK_X1 + 0.03, side * (DECK_W - 0.07), top + stake_h - 0.03), (DECK_X1 + 0.0, side * (DECK_W - 0.2), top + stake_h - 0.12),
                                    (DECK_X1 + 0.0, side * (DECK_W - 0.33), top + stake_h - 0.05)], 0.006, galv(), 6))
        # Mud flaps behind the rear wheels.
        obs.append(K.box("flap", (-1.72, side * 0.78, 0.5), (0.012, 0.44, 0.48), rubber(), bevel=0.004))
        obs.append(K.box("flap_bar", (-1.72, side * 0.78, 0.77), (0.03, 0.46, 0.03), steel()))
    return obs


# --- Box body ------------------------------------------------------------------------------

def box_body():
    obs = []
    floor = DECK_TOP
    bx0, bx1 = DECK_X0 - 0.01, DECK_X1 - 0.04
    bw = 1.04
    roof = 2.38
    alu = K.mat("Trim_BoxPanel", (0.72, 0.72, 0.7), 0.15, 0.38)
    prof = K.mat("Trim_Alu", (0.62, 0.63, 0.64), 0.85, 0.35)
    obs += subframe(DECK_X0, DECK_X1, floor - 0.04)
    # Floor sill in steel all round.
    obs.append(K.box("sill", ((bx0 + bx1) * 0.5, 0.0, floor - 0.04), (bx0 - bx1, 2 * bw, 0.1), steel(), bevel=0.006))
    # Panels: sides, front, roof, set inside the corner profiles.
    for side in (1.0, -1.0):
        obs.append(K.box("side", ((bx0 + bx1) * 0.5, side * (bw - 0.012), (floor + roof) * 0.5), (bx0 - bx1 - 0.06, 0.024, roof - floor), alu))
        # Vertical joint strips and a rub rail.
        for k in range(1, 3):
            x = bx0 - k * (bx0 - bx1) / 3.0
            obs.append(K.box("joint", (x, side * (bw + 0.002), (floor + roof) * 0.5), (0.05, 0.01, roof - floor - 0.04), prof, bevel=0.003))
        obs.append(K.box("rub", ((bx0 + bx1) * 0.5, side * (bw + 0.006), floor + 0.28), (bx0 - bx1 - 0.08, 0.02, 0.06), prof, bevel=0.006))
        # Amber side markers, one near each end.
        for x in (bx0 - 0.15, bx1 + 0.15):
            obs.append(K.box("marker", (x, side * (bw + 0.012), floor + 0.05), (0.07, 0.012, 0.03), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1), bevel=0.004))
    obs.append(K.box("front", (bx0 - 0.012, 0.0, (floor + roof) * 0.5), (0.024, 2 * bw - 0.06, roof - floor), alu))
    obs.append(K.box("roof", ((bx0 + bx1) * 0.5, 0.0, roof - 0.012), (bx0 - bx1 - 0.06, 2 * bw - 0.06, 0.024), K.mat("Trim_BoxRoof", (0.66, 0.66, 0.64), 0.1, 0.45)))
    # Corner profiles: vertical at the four corners, along the roof edges.
    for x in (bx0, bx1 + 0.06):
        for side in (1.0, -1.0):
            obs.append(K.box("post", (x - 0.03, side * (bw - 0.03), (floor + roof) * 0.5), (0.07, 0.07, roof - floor), prof, bevel=0.015, segs=2))
    for side in (1.0, -1.0):
        obs.append(K.box("roof_rail", ((bx0 + bx1) * 0.5, side * (bw - 0.03), roof - 0.03), (bx0 - bx1, 0.07, 0.07), prof, bevel=0.015, segs=2))
    obs.append(K.box("roof_rail_f", (bx0 - 0.03, 0.0, roof - 0.03), (0.07, 2 * bw, 0.07), prof, bevel=0.015, segs=2))
    # Rear portal and barn doors: two panels, three hinges each on the outer edges,
    # two galvanised lock bars each with cams top and bottom and a handle.
    rx = bx1 + 0.02
    obs.append(K.box("portal_top", (rx, 0.0, roof - 0.07), (0.06, 2 * bw, 0.14), steel(), bevel=0.01))
    obs.append(K.box("portal_sill", (rx, 0.0, floor - 0.02), (0.07, 2 * bw, 0.1), steel(), bevel=0.01))
    for side in (1.0, -1.0):
        obs.append(K.box("portal_post", (rx, side * (bw - 0.04), (floor + roof) * 0.5), (0.07, 0.08, roof - floor), steel(), bevel=0.01))
        door_c = side * (bw - 0.08) * 0.5
        obs.append(K.box("door", (rx - 0.03, door_c, (floor + roof) * 0.5 - 0.02), (0.035, bw - 0.1, roof - floor - 0.2), alu, bevel=0.006))
        obs.append(K.box("door_seal", (rx - 0.01, door_c, (floor + roof) * 0.5 - 0.02), (0.02, bw - 0.08, roof - floor - 0.17), rubber()))
        for z in (floor + 0.25, (floor + roof) * 0.5, roof - 0.3):
            obs.append(K.box("hinge", (rx - 0.055, side * (bw - 0.1), z), (0.03, 0.16, 0.05), galv(), bevel=0.004))
            obs.append(K.cyl("hinge_pin", (rx - 0.07, side * (bw - 0.02), z - 0.04), (rx - 0.07, side * (bw - 0.02), z + 0.04), 0.012, galv(), 8))
        for off in (0.18, 0.36):
            y = side * off
            obs.append(K.cyl("lockbar", (rx - 0.07, y, floor + 0.02), (rx - 0.07, y, roof - 0.06), 0.013, galv(), 10))
            for z in (floor + 0.03, roof - 0.07):
                obs.append(K.box("cam", (rx - 0.07, y, z), (0.05, 0.04, 0.06), galv(), bevel=0.006))
            obs.append(K.box("lever", (rx - 0.1, y - side * 0.08, floor + 0.62), (0.03, 0.18, 0.03), galv(), bevel=0.008))
    # Underrun bar with the lamp clusters and the plate on it.
    ux = bx1 + 0.08
    obs.append(K.box("underrun", (ux, 0.0, 0.48), (0.08, 1.7, 0.1), steel(), bevel=0.008))
    for side in (1.0, -1.0):
        obs.append(K.box("underrun_arm", (ux + 0.15, side * 0.6, 0.62), (0.3, 0.06, 0.06), steel()))
        c = Vector((ux - 0.045, side * 0.62, 0.48))
        obs.append(K.box("lamp_house", c + Vector((0.01, 0, 0)), (0.05, 0.36, 0.1), K.mat("Trim_BlackPlastic", (0.03, 0.03, 0.032), 0.0, 0.45), bevel=0.008))
        obs += K.lamp_rect("Brake_Box_%s" % ("L" if side > 0 else "R"), c + Vector((-0.02, side * 0.06, 0)), (-1, 0, 0), 0.16, 0.07,
                           K.mat("Lamp_Red", (0.45, 0.02, 0.015), 0.0, 0.15), ribs=3)
        obs += K.lamp_rect("Reverse_Box_%s" % ("L" if side > 0 else "R"), c + Vector((-0.02, -side * 0.11, 0)), (-1, 0, 0), 0.07, 0.07,
                           K.mat("Lamp_White", (0.8, 0.8, 0.78), 0.0, 0.1))
        obs.append(K.box("ind", c + Vector((-0.022, side * 0.155, 0)), (0.004, 0.04, 0.07), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1)))
        # Red and amber marker lamps at the top corners.
        obs.append(K.box("top_marker", (rx - 0.02, side * (bw - 0.05), roof + 0.02), (0.04, 0.06, 0.04), K.mat("Lamp_RedMarker", (0.5, 0.03, 0.02), 0.0, 0.1), bevel=0.008))
        obs.append(K.box("top_marker_f", (bx0 + 0.02, side * (bw - 0.05), roof + 0.02), (0.04, 0.06, 0.04), K.mat("Trim_Amber", (0.8, 0.35, 0.02), 0.0, 0.1), bevel=0.008))
        obs.append(K.box("flap", (-1.72, side * 0.78, 0.5), (0.012, 0.44, 0.48), rubber(), bevel=0.004))
        obs.append(K.box("flap_bar", (-1.72, side * 0.78, 0.77), (0.03, 0.46, 0.03), steel()))
    obs.append(K.plate("Numberplate_Box", (ux - 0.05, 0.0, 0.46), (-1, 0, 0)))
    return obs


def import_pickup(hide):
    bpy.ops.import_scene.gltf(filepath=SRC)
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and any(h in o.name for h in hide):
            bpy.data.objects.remove(o, do_unlink=True)


def build(name, fn, hide, lamps):
    K.reset()
    obs = fn()
    # Groups: one mesh per material family, the lamps and panes on their own.
    keep = [o for o in obs if any(o.name.startswith(p) for p in lamps + ["Glass_", "Numberplate", "Lens_"])]
    rest = [o for o in obs if o not in keep]
    body = K.join(rest, name.capitalize() + "_Parts")
    out = keep + [body]
    K.export(out, os.path.join(OUT, name + ".glb"))
    return out, hide


def main():
    a = K.args()
    jobs = [("canopy", canopy, [], ["Lamp_"]),
            ("stake", stake_bed, ["Truckbed_"], ["Lamp_"]),
            ("box", box_body, ["Truckbed_"], ["Lamp_"])]
    for name, fn, hide, lamps in jobs:
        build(name, fn, hide, lamps)
        if a.get("preview"):
            import_pickup(hide + ["Truck_Numberplate_rear"] if name == "box" else hide)
            K.preview(os.path.join(a["preview"], name), centre=(-0.6, 0.0, 1.0), dist=9.0, views=("front3q", "back3q"))


if __name__ == "__main__":
    main()
