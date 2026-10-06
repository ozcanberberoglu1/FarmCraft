"""Builds the two trailers a vehicle tows (scripts/vehicles/trailer.gd):
art/models/vehicles/trailer/livestock.glb (Grandpa's single-axle stock trailer: a painted
steel tub under galvanised slats, a rear gate that drops into a ramp, an A-frame tongue
with a coupling head and a jockey wheel) and art/models/vehicles/trailer/flatbed.glb (the
dealership's cargo trailer: a plank deck behind low galvanised drop sides and a headboard
rack).

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_trailer.py [-- --preview=/abs/dir]

Model frame of tools/blender/vehicle_kit.py (front +X, left +Y, up +Z, ground z = 0), the
axle at x = 0. Meshes the game moves by name: "Ramp" (the gate, hinged along y at its
foot: x = BOX_X1, z = FLOOR), "Jockey" (the jockey wheel and its stem, wound up when
hitched), "WheelStock_RL/RR" (the wheels).
"""
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_kit as K  # noqa: E402

OUT_DIR = os.path.join(K.ROOT, "art/models/vehicles/trailer")

R = 0.33
TRACK = 0.93
FLOOR = 0.52
BOX_X0, BOX_X1 = 1.55, -1.35
HW = 0.78
TUB = 0.62          # the painted tub's height above the floor
TOP = FLOOR + 1.34  # top rail
HITCH_X = 3.0
HITCH_Z = 0.47


def paint():
    return K.mat("Trailer_Bodymat", (0.2, 0.34, 0.36), 0.2, 0.4)


def steel():
    return K.mat("Trim_Steel", (0.035, 0.036, 0.038), 0.55, 0.55)


def galv():
    # Weathered zinc: dull and mid grey (a brighter, shinier one reads white in the sun).
    return K.mat("Trim_Galv", (0.2, 0.205, 0.21), 0.6, 0.55)


def wood():
    return K.mat("Trim_Wood", (0.36, 0.27, 0.18), 0.0, 0.75)


def rubber():
    return K.mat("Trim_Rubber", (0.025, 0.025, 0.025), 0.0, 0.8)


def lamp_red():
    return K.mat("Lamp_Red", (0.5, 0.03, 0.02), 0.0, 0.25)


def amber():
    return K.mat("Trim_Amber", (0.75, 0.35, 0.03), 0.0, 0.3)


def tongue(deck_x0: float, frame_z: float, hw: float) -> list:
    """The A-frame from the body's front corners to the coupling head, with the jockey
    wheel's clamp, the safety chain and the lighting cable."""
    obs = []
    z = frame_z
    for side in (1.0, -1.0):
        a = Vector((deck_x0, side * (hw - 0.2), z))
        b = Vector((HITCH_X - 0.3, side * 0.05, z))
        mid = (a + b) * 0.5
        ln = (b - a).length
        yaw = math.atan2(b.y - a.y, b.x - a.x)
        obs.append(K.box("a_frame", mid, (ln, 0.06, 0.09), galv(), bevel=0.008, rot=(0.0, 0.0, yaw)))
    obs.append(K.box("draw_bar", ((deck_x0 + HITCH_X - 0.1) * 0.5, 0.0, z), (HITCH_X - 0.1 - deck_x0, 0.07, 0.09), galv(), bevel=0.008))
    # Coupling head: a pressed steel cup over the ball, its handle and the overrun bellows.
    obs.append(K.box("coupling", (HITCH_X - 0.03, 0.0, HITCH_Z + 0.01), (0.2, 0.1, 0.085), steel(), bevel=0.02, segs=3))
    obs.append(K.cyl("coupling_cup", (HITCH_X, 0.0, HITCH_Z - 0.045), (HITCH_X, 0.0, HITCH_Z + 0.03), 0.045, steel(), 16, bevel=0.008))
    obs.append(K.box("coupling_handle", (HITCH_X - 0.12, 0.0, HITCH_Z + 0.085), (0.18, 0.03, 0.025), K.mat("Trim_Red", (0.5, 0.05, 0.04), 0.0, 0.45), bevel=0.008,
            rot=(0.0, -0.25, 0.0)))
    obs.append(K.cyl("bellows", (HITCH_X - 0.42, 0.0, z + 0.005), (HITCH_X - 0.14, 0.0, HITCH_Z), 0.04, rubber(), 14))
    # Jockey clamp on the draw bar's left side.
    obs.append(K.box("jockey_clamp", (2.45, 0.075, z + 0.01), (0.1, 0.07, 0.13), steel(), bevel=0.01))
    obs.append(K.cyl("clamp_screw", (2.45, 0.11, z + 0.01), (2.45, 0.2, z + 0.01), 0.008, steel(), 8))
    obs.append(K.box("clamp_knob", (2.45, 0.21, z + 0.01), (0.02, 0.02, 0.07), steel(), bevel=0.004))
    # The breakaway chain and the lighting cable hung along the bar.
    obs.append(K.tube("chain", [(HITCH_X - 0.3, -0.04, z - 0.04), (HITCH_X - 0.12, -0.05, z - 0.13), (HITCH_X + 0.04, -0.03, z - 0.07)], 0.007, galv(), 6))
    obs.append(K.tube("cable", [(deck_x0 + 0.1, 0.03, z + 0.05), (2.2, 0.03, z + 0.055), (HITCH_X - 0.35, 0.05, z + 0.06),
            (HITCH_X - 0.15, 0.09, z - 0.06), (HITCH_X + 0.02, 0.07, z - 0.02)], 0.008, rubber(), 6))
    return obs


def jockey(frame_z: float):
    """The jockey wheel: a tube stem through the clamp, a crank on top, a small solid
    wheel in a fork. Modelled standing on the ground (the trailer level on it)."""
    x, y = 2.45, 0.135
    obs = [K.cyl("jockey_stem", (x, y, 0.2), (x, y, frame_z + 0.42), 0.024, galv(), 12),
           K.cyl("jockey_inner", (x, y, 0.13), (x, y, 0.3), 0.019, steel(), 10),
           K.box("jockey_fork", (x, y, 0.13), (0.05, 0.085, 0.14), steel(), bevel=0.008),
           K.cyl("jockey_wheel", (x, y - 0.03, 0.085), (x, y + 0.03, 0.085), 0.085, rubber(), 20, bevel=0.012),
           K.cyl("jockey_hub", (x, y - 0.034, 0.085), (x, y + 0.034, 0.085), 0.03, galv(), 10),
           K.tube("jockey_crank", [(x, y, frame_z + 0.42), (x, y, frame_z + 0.47), (x, y + 0.09, frame_z + 0.47), (x, y + 0.09, frame_z + 0.53)], 0.008, steel(), 6),
           K.cyl("jockey_grip", (x, y + 0.09, frame_z + 0.5), (x, y + 0.09, frame_z + 0.57), 0.014, rubber(), 8)]
    return K.join(obs, "Jockey")


def running_gear(hw: float, frame_z: float, x0: float, x1: float, guard_top: float) -> list:
    """Chassis rails and crossmembers, the axle on its leaf springs, mudguards over the
    wheels, the rear lamp bar with its lamps, reflectors and the plate."""
    obs = []
    for side in (1.0, -1.0):
        obs.append(K.box("rail", ((x0 + x1) * 0.5, side * (hw - 0.2), frame_z), (x0 - x1, 0.06, 0.1), galv(), bevel=0.006))
        obs.append(K.box("spring", (0.0, side * (hw - 0.2), R + 0.06), (0.8, 0.05, 0.035), steel(), bevel=0.006))
        for sx in (-0.4, 0.4):
            obs.append(K.box("shackle", (sx, side * (hw - 0.2), (R + 0.06 + frame_z) * 0.5), (0.04, 0.04, frame_z - R - 0.06 + 0.04), steel()))
        # Mudguard: a flat top with two sloped ends, a stay to the body.
        gy = side * (TRACK + 0.01)
        gw = 0.3
        obs.append(K.box("guard_top", (0.0, gy, guard_top), (0.5, gw, 0.025), paint(), bevel=0.006))
        for sx in (-1.0, 1.0):
            obs.append(K.box("guard_end", (sx * 0.4, gy, guard_top - 0.105), (0.36, gw, 0.025), paint(), bevel=0.006, rot=(0.0, sx * 0.62, 0.0)))
        obs.append(K.box("guard_skirt", (0.0, side * (TRACK - 0.14), guard_top - 0.1), (0.5, 0.02, 0.2), paint(), bevel=0.004))
        obs.append(K.box("marker", (x0 - 0.25, side * (hw + 0.012), frame_z + 0.02), (0.09, 0.012, 0.04), amber(), bevel=0.004))
    n = 5
    for k in range(n):
        x = x1 + 0.1 + (x0 - x1 - 0.2) * k / (n - 1)
        obs.append(K.box("crossmember", (x, 0.0, frame_z - 0.005), (0.05, 2 * hw - 0.42, 0.08), galv(), bevel=0.005))
    obs.append(K.cyl("axle", (0.0, -TRACK + 0.08, R), (0.0, TRACK - 0.08, R), 0.032, steel(), 12))
    # Lamp bar under the tail.
    bx = x1 + 0.03
    obs.append(K.box("lamp_bar", (bx, 0.0, frame_z - 0.02), (0.05, 2 * hw, 0.13), steel(), bevel=0.008))
    for side in (1.0, -1.0):
        obs += K.lamp_rect("Brake_L" if side > 0 else "Brake_R", (bx - 0.027, side * (hw - 0.17), frame_z - 0.02), (-1.0, 0.0, 0.0), 0.2, 0.09,
                lamp_red(), bezel_mat=rubber(), ribs=3)
        obs.append(K.box("reflector", (bx - 0.027, side * (hw - 0.36), frame_z - 0.02), (0.01, 0.07, 0.07), K.mat("Trim_Red", (0.5, 0.05, 0.04), 0.0, 0.45), bevel=0.004))
    obs.append(K.plate("Numberplate_rear", (bx - 0.03, 0.0, frame_z - 0.02), (-1.0, 0.0, 0.0), size=(0.32, 0.15)))
    return obs


def slatted_wall(name, a: Vector, b: Vector, out: Vector, z0: float, tub: float, slats: int, posts) -> list:
    """A wall from `a` to `b` (plan points), `out` its outward normal: a painted tub panel
    with pressed ribs, galvanised slats above it up to TOP, posts at `posts` (0..1 along)."""
    obs = []
    mid = (a + b) * 0.5
    ln = (b - a).length
    yaw = math.atan2(b.y - a.y, b.x - a.x)
    rot = (0.0, 0.0, yaw)
    obs.append(K.box(name + "_tub", (mid.x, mid.y, z0 + tub * 0.5), (ln, 0.025, tub), paint(), bevel=0.004, rot=rot))
    for z in (z0 + tub * 0.3, z0 + tub * 0.7):
        p = mid + out * 0.016
        obs.append(K.box(name + "_rib", (p.x, p.y, z), (ln - 0.14, 0.012, 0.045), paint(), bevel=0.005, segs=1, rot=rot))
    gap = (TOP - 0.04 - (z0 + tub + 0.05)) / slats
    for k in range(slats):
        z = z0 + tub + 0.05 + gap * (k + 0.5)
        obs.append(K.box(name + "_slat", (mid.x, mid.y, z), (ln, 0.02, gap * 0.5), galv(), bevel=0.004, rot=rot))
    obs.append(K.box(name + "_rail", (mid.x, mid.y, TOP), (ln, 0.05, 0.045), galv(), bevel=0.01, rot=rot))
    for t in posts:
        p = a.lerp(b, t) + out * 0.012
        obs.append(K.box(name + "_post", (p.x, p.y, (z0 - 0.08 + TOP) * 0.5), (0.055, 0.055, TOP - z0 + 0.08), galv(), bevel=0.008, rot=rot))
    return obs


def livestock() -> list:
    obs = []
    # Floor: boards along the box on the chassis, a kick strip round it.
    n = 7
    bw = (2 * HW - 0.06) / n
    for k in range(n):
        y = -HW + 0.03 + bw * (k + 0.5)
        obs.append(K.box("floor_board", ((BOX_X0 + BOX_X1) * 0.5, y, FLOOR - 0.02), (BOX_X0 - BOX_X1, bw - 0.006, 0.04), wood(), bevel=0.003, segs=1))
    for side in (1.0, -1.0):
        obs += slatted_wall("side", Vector((BOX_X1, side * (HW - 0.012), 0)), Vector((BOX_X0, side * (HW - 0.012), 0)), Vector((0, side, 0)), FLOOR - 0.05,
                TUB + 0.05, 4, (0.0, 0.5, 1.0))
        # Gate latches on the rear posts, tie rings inside.
        obs.append(K.box("latch", (BOX_X1 - 0.01, side * (HW - 0.01), TOP - 0.3), (0.05, 0.03, 0.09), steel(), bevel=0.006))
        obs.append(K.tube("latch_pin", [(BOX_X1 - 0.03, side * (HW - 0.01), TOP - 0.22), (BOX_X1 - 0.03, side * (HW - 0.01), TOP - 0.4)], 0.008, galv(), 6))
    # Headboard: a higher tub (the animals' chests ride against it) under two slats.
    obs += slatted_wall("head", Vector((BOX_X0 - 0.012, -HW, 0)), Vector((BOX_X0 - 0.012, HW, 0)), Vector((1, 0, 0)), FLOOR - 0.05, 0.95, 2, ())
    obs.append(K.tube("tie_rail", [(BOX_X0 - 0.06, -HW + 0.08, FLOOR + 1.0), (BOX_X0 - 0.06, HW - 0.08, FLOOR + 1.0)], 0.014, galv(), 8))
    obs += running_gear(HW, FLOOR - 0.09, BOX_X0, BOX_X1, 2 * R + 0.08)
    obs += tongue(BOX_X0, FLOOR - 0.09, HW)
    return obs


def ramp():
    """The rear gate, closed (standing): a galvanised frame, a painted outer skin with
    ribs, the inner face boarded with cleats (the ramp's tread once it is down)."""
    x = BOX_X1 - 0.03
    h = TOP - FLOOR
    w = 2 * HW - 0.09
    obs = [K.box("ramp_skin", (x - 0.012, 0.0, FLOOR + h * 0.5), (0.02, w, h), paint(), bevel=0.004)]
    for z in (FLOOR + h * 0.22, FLOOR + h * 0.5, FLOOR + h * 0.78):
        obs.append(K.box("ramp_rib", (x - 0.028, 0.0, z), (0.014, w - 0.16, 0.05), paint(), bevel=0.005, segs=1))
    for side in (1.0, -1.0):
        obs.append(K.box("ramp_stile", (x, side * (w * 0.5 - 0.025), FLOOR + h * 0.5), (0.05, 0.05, h), galv(), bevel=0.008))
        obs.append(K.cyl("ramp_hinge", (x + 0.01, side * (w * 0.5 - 0.22), FLOOR), (x + 0.01, side * (w * 0.5 - 0.08), FLOOR), 0.022, galv(), 10))
        obs.append(K.box("ramp_catch", (x - 0.01, side * (w * 0.5 - 0.02), TOP - 0.3), (0.03, 0.05, 0.06), steel(), bevel=0.006))
    for z in (FLOOR + 0.025, TOP - 0.025):
        obs.append(K.box("ramp_bar", (x, 0.0, z), (0.05, w, 0.05), galv(), bevel=0.008))
    n = 6
    bw = (w - 0.1) / n
    for k in range(n):
        y = -w * 0.5 + 0.05 + bw * (k + 0.5)
        obs.append(K.box("ramp_board", (x + 0.022, y, FLOOR + h * 0.5), (0.024, bw - 0.005, h - 0.1), wood(), bevel=0.003, segs=1))
    for k in range(6):
        z = FLOOR + 0.16 + (h - 0.3) * k / 5.0
        obs.append(K.box("ramp_cleat", (x + 0.04, 0.0, z), (0.018, w - 0.14, 0.03), wood(), bevel=0.004, segs=1))
    obs.append(K.box("ramp_handle", (x - 0.045, 0.0, TOP - 0.14), (0.02, 0.26, 0.03), steel(), bevel=0.008))
    return K.join(obs, "Ramp")


# --- The flatbed --------------------------------------------------------------------------

DECK = 0.64
FLAT_X0, FLAT_X1 = 1.95, -1.55
FLAT_HW = 0.8
SIDE_H = 0.3


def flatbed() -> list:
    obs = []
    n = 8
    bw = 2 * FLAT_HW / n
    for k in range(n):
        y = -FLAT_HW + bw * (k + 0.5)
        obs.append(K.box("deck_board", ((FLAT_X0 + FLAT_X1) * 0.5, y, DECK - 0.02), (FLAT_X0 - FLAT_X1, bw - 0.006, 0.04), wood(), bevel=0.003, segs=1))
    side_mat = K.mat("Trim_BedSide", (0.22, 0.225, 0.23), 0.6, 0.55)
    mid_x = (FLAT_X0 + FLAT_X1) * 0.5
    for side in (1.0, -1.0):
        y = side * (FLAT_HW + 0.012)
        obs.append(K.box("edge", (mid_x, side * FLAT_HW, DECK - 0.05), (FLAT_X0 - FLAT_X1, 0.05, 0.1), paint(), bevel=0.006))
        for x0, x1 in ((FLAT_X0, mid_x + 0.035), (mid_x - 0.035, FLAT_X1)):
            obs.append(K.box("side_panel", ((x0 + x1) * 0.5, y, DECK + SIDE_H * 0.5), (x0 - x1 - 0.02, 0.025, SIDE_H), side_mat, bevel=0.005))
            for z in (DECK + 0.1, DECK + 0.2):
                obs.append(K.box("side_rib", ((x0 + x1) * 0.5, y + side * 0.014, z), (x0 - x1 - 0.1, 0.01, 0.03), side_mat, bevel=0.004, segs=1))
            for x in (x0 - 0.3, x1 + 0.3):
                obs.append(K.cyl("side_hinge", (x - 0.05, y + side * 0.012, DECK + 0.005), (x + 0.05, y + side * 0.012, DECK + 0.005), 0.015, galv(), 8))
        for x in (FLAT_X0 - 0.03, mid_x, FLAT_X1 + 0.03):
            obs.append(K.box("stake", (x, side * (FLAT_HW - 0.005), DECK + SIDE_H * 0.5 - 0.02), (0.06, 0.06, SIDE_H + 0.1), paint(), bevel=0.008))
            obs.append(K.box("side_latch", (x, y + side * 0.02, DECK + SIDE_H - 0.07), (0.05, 0.02, 0.05), steel(), bevel=0.005))
    obs.append(K.box("tail_panel", (FLAT_X1 - 0.012, 0.0, DECK + SIDE_H * 0.5), (0.025, 2 * FLAT_HW - 0.1, SIDE_H), side_mat, bevel=0.005))
    for z in (DECK + 0.1, DECK + 0.2):
        obs.append(K.box("tail_rib", (FLAT_X1 - 0.026, 0.0, z), (0.01, 2 * FLAT_HW - 0.2, 0.03), side_mat, bevel=0.004, segs=1))
    # Headboard rack: two posts, a top bar, a painted panel and bars to tie a load against.
    hx = FLAT_X0 + 0.012
    obs.append(K.box("head_panel", (hx, 0.0, DECK + 0.2), (0.025, 2 * FLAT_HW, 0.4), paint(), bevel=0.005))
    for side in (1.0, -1.0):
        obs.append(K.box("head_post", (hx, side * (FLAT_HW - 0.03), DECK + 0.45), (0.06, 0.06, 0.95), paint(), bevel=0.008))
    obs.append(K.box("head_top", (hx, 0.0, DECK + 0.92), (0.06, 2 * FLAT_HW, 0.06), paint(), bevel=0.01))
    for k in range(7):
        y = -0.6 + k * 0.2
        obs.append(K.cyl("head_bar", (hx, y, DECK + 0.4), (hx, y, DECK + 0.9), 0.011, galv(), 8))
    obs += running_gear(FLAT_HW, DECK - 0.11, FLAT_X0, FLAT_X1, 2 * R + 0.08)
    obs += tongue(FLAT_X0, DECK - 0.11, FLAT_HW)
    return obs


def finish(parts, extra, name, path, preview_dir):
    lamps = [o for o in parts if o.name.startswith(("Lamp_", "Lens_"))]
    named = [o for o in parts if o.name.startswith("Numberplate")]
    rest = [o for o in parts if o not in lamps and o not in named]
    groups = {}
    for o in lamps:
        key = "_".join(o.name.split(".")[0].split("_")[:2])
        groups.setdefault(key, []).append(o)
    lamp_meshes = [K.join(v, k) for k, v in groups.items()]
    body = K.join(rest, name)
    K.uv_box(body)
    wheels = [K.wheel("WheelStock_RL", (0.0, TRACK, R), R, 0.2), K.wheel("WheelStock_RR", (0.0, -TRACK, R), R, 0.2)]
    K.export([body] + extra + wheels + lamp_meshes + named, path)
    if preview_dir:
        K.preview(os.path.join(preview_dir, name.lower()), centre=(0.6, 0.0, 0.9), dist=8.0, views=("front3q", "back3q", "side"))


def main():
    a = K.args()
    K.reset()
    r = ramp()
    K.uv_box(r)
    finish(livestock(), [r, jockey(FLOOR - 0.09)], "Trailer_Stock", os.path.join(OUT_DIR, "livestock.glb"), a.get("preview"))
    K.reset()
    # The kit keeps the tyre lettering's font: gone with the scene just reset.
    K._font = None
    finish(flatbed(), [jockey(DECK - 0.11)], "Trailer_Flat", os.path.join(OUT_DIR, "flatbed.glb"), a.get("preview"))


if __name__ == "__main__":
    main()
