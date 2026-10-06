"""Builds the Lightbody '90 pickup's cab interior (art/models/vehicles/pickup_90/interior.glb),
which the game puts in place of the downloaded model's low-poly cab (VehicleTable
"interior"; every body on that chassis shares it): the shared cab kit's dashboard,
seats, door cards, console, pedals and roof (tools/blender/cab_kit.py) and the trim
that is this cab's own (the rear wall and the rear window's surround, the pillars, the
roof rails, the windshield header, the kick panels).

Meshes: Cab (everything that stands still, one surface a material), and by name for the
game Radio, RadioDisplay, Needle_Speed, Needle_Fuel. The steering wheel stays the
modelled one (tools/build_pickup_hd.py).

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_pickup_interior.py [-- --preview=/abs/dir]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cab_kit as CK  # noqa: E402
import vehicle_kit as K  # noqa: E402

OUT = os.path.join(K.ROOT, "art/models/vehicles/pickup_90/interior.glb")

# The cab as measured on the model (Blender axes, left side; the right is its mirror):
# the door glass from its sill up to the roof rail, its front edge along the pillar,
# and the windshield's side edge.
GLASS_TOP_FRONT = Vector((0.955, 0.633, 1.561))
GLASS_KNEE = Vector((1.176, 0.708, 1.334))
GLASS_SILL_FRONT = Vector((1.166, 0.752, 1.202))
SHIELD_TOP = Vector((1.029, 0.569, 1.602))
SHIELD_FOOT = Vector((1.381, 0.665, 1.251))
# The rear window leans forward by this much (degrees).
REAR_LEAN = 19.5


def shell():
    """The trim that closes the cab: rear wall, rear window surround, pillars, roof
    rails, windshield header, kick panels."""
    T, V = CK.m_trim(), CK.m_door()
    obs = [K.box("rear_wall", (0.19, 0.0, 0.905), (0.03, 1.52, 0.7), V, bevel=0.008)]
    obs.append(K.box("rear_sill", (0.205, 0.0, 1.25), (0.06, 1.5, 0.022), T, bevel=0.008))
    lean = Matrix.Rotation(math.radians(REAR_LEAN), 3, "Y")
    obs.append(K.box("rear_header", (0.3, 0.0, 1.612), (0.05, 1.24, 0.06), T, bevel=0.012))
    obs.append(K.box("shield_header", (1.035, 0.0, 1.628), (0.07, 1.16, 0.036), T, bevel=0.012))
    for s in (-1, 1):
        m = Vector((1.0, s, 1.0))

        def side(p):
            return Vector((p.x * m.x, p.y * m.y, p.z * m.z))
        obs.append(K.box("rear_corner", (0.245, s * 0.66, 1.42), (0.03, 0.2, 0.37), T, bevel=0.008, rot=lean))
        obs.append(K.box("b_pillar", (0.33, s * 0.675, 1.41), (0.24, 0.03, 0.45), T, bevel=0.01,
                         rot=Matrix.Rotation(math.radians(s * 18.5), 3, "X")))
        obs.append(K.box("roof_rail", (0.7, s * 0.588, 1.627), (0.6, 0.05, 0.046), T, bevel=0.015, segs=2))
        obs.append(K.box("kick_panel", (1.46, s * 0.765, 0.88), (0.26, 0.03, 0.66), T, bevel=0.008))
        obs.append(K.box("rear_quarter", (0.255, s * 0.765, 0.9), (0.15, 0.03, 0.62), V, bevel=0.008))
        # The windshield pillar: a panel from the door glass's front edge to the
        # windshield's side edge, with a moulding along each.
        inward = Vector((-0.3, -s, -0.05)).normalized()
        ring = [side(p) + inward * 0.012 for p in (GLASS_TOP_FRONT, SHIELD_TOP, SHIELD_FOOT, GLASS_SILL_FRONT, GLASS_KNEE)]
        obs.append(K.sheet("a_pillar", ring, T, thickness=0.02, smooth=30.0))
        obs.append(K.tube("a_pillar_garnish", [side(SHIELD_TOP) + inward * 0.02, side(SHIELD_FOOT) + inward * 0.02], 0.012, T, 8))
        obs.append(K.tube("a_pillar_seal", [side(GLASS_TOP_FRONT) + inward * 0.02, side(GLASS_KNEE) + inward * 0.02,
                                            side(GLASS_SILL_FRONT) + inward * 0.02], 0.011, T, 8))
    return obs


def preview(obs, folder):
    """Workbench renders from the driver's eyes (shape checks while modelling)."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 800
    eye = Vector((0.42, 0.38, 1.52))
    for name, target, lens in (("ahead", (2.0, 0.3, 1.25), 16), ("right", (1.0, -1.0, 1.05), 16), ("down", (1.2, 0.2, 0.2), 16),
                               ("left", (0.75, 1.5, 1.0), 16)):
        data = bpy.data.cameras.new(name)
        data.lens = lens
        data.clip_start = 0.03
        cam = bpy.data.objects.new(name, data)
        sc.collection.objects.link(cam)
        fwd = (Vector(target) - eye).normalized()
        right = fwd.cross(Vector((0, 0, 1))).normalized()
        cam.matrix_world = Matrix.Translation(eye) @ Matrix((right, right.cross(fwd), -fwd)).transposed().to_4x4()
        sc.camera = cam
        sc.render.filepath = os.path.join(folder, "cab_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    a = K.args()
    K.reset()
    CK.use_scheme("saddle")
    parts = shell() + CK.dash() + CK.column()
    parts += CK.seat(0.375, name="seat_l") + CK.seat(-0.375, name="seat_r") + CK.belt(1) + CK.belt(-1)
    parts += CK.door_card(1) + CK.door_card(-1)
    parts += CK.floor() + CK.console() + CK.pedals()
    parts += CK.headliner() + CK.visors_and_mirror()
    out = CK.group(parts, "Cab")
    K.export(out, OUT)
    if a.get("preview"):
        preview(out, a["preview"])


if __name__ == "__main__":
    main()
