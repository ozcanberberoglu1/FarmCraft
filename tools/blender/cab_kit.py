"""Cab interiors for the vehicles (tools/blender/build_pickup_interior.py and the
dealership builders): a dashboard with its instrument binnacle (printed dial faces,
needles the game turns), vents, a centre stack with the radio and the heater sliders,
a glovebox; the steering column with its stalks and the ignition; bucket seats with
bolsters, pleated cloth panels, piping and headrests; door cards with armrests, door
handles, window winders, pockets and speaker grilles; the gear lever, the handbrake
and the console; pedals, rubber matting, a perforated headliner, sun visors, the
inside mirror, a dome lamp and seat belts.

Everything is modelled where it sits in the Lightbody '90 pickup's cab (Blender axes:
front +X, left +Y, up +Z, the driver on the left) and each group takes a matrix `xf`
that moves and stretches it into another cab.

The game dresses the parts by their material names (scripts/vehicles/vehicle_look.gd):
"Interior_<Kind>_<Part>" gets the cab shader with the grain set of its kind (Plastic,
Vinyl, Cloth, Rubber, Liner: art/textures/cab, tools/make_cab_textures.py) laid on by
position (no UVs), tinted with the material's colour; "Interior_Decal" is the sheet of
printed faces (UVs into DECALS). Meshes the game looks for by name: "Radio" and
"RadioDisplay" (the radio and its lit display), "Needle_Speed" and "Needle_Fuel" (they
turn about their node's glTF +Y, clockwise for the driver: 270 degrees for 0-160 km/h,
120 degrees from empty to full).
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vehicle_kit as K  # noqa: E402

# The decal sheet's rectangles in pixels (x, y, w, h), as tools/make_cab_textures.py draws them.
SHEET = 1024
DECALS = {
    "cluster": (0, 0, 640, 240),
    "radio": (0, 256, 512, 152),
    "heater": (0, 424, 512, 120),
    "speaker": (656, 0, 256, 256),
    "shift": (656, 272, 128, 128),
    "label": (800, 272, 208, 104),
    "slats": (656, 416, 256, 128),
}

# A cab's colours: the dash plastic, lighter trim plastic, seat vinyl, door vinyl, seat
# cloth, headliner. "saddle": the pickup's tan; "grey": a work truck's; "tan": the estate's.
SCHEMES = {
    "saddle": {"dash": (0.085, 0.077, 0.068), "trim": (0.17, 0.145, 0.115), "seat": (0.3, 0.165, 0.085),
               "door": (0.24, 0.17, 0.115), "cloth": (0.42, 0.33, 0.22), "liner": (0.52, 0.48, 0.4)},
    "grey": {"dash": (0.055, 0.057, 0.062), "trim": (0.12, 0.125, 0.135), "seat": (0.1, 0.105, 0.12),
             "door": (0.13, 0.135, 0.15), "cloth": (0.2, 0.22, 0.26), "liner": (0.5, 0.5, 0.5)},
    "tan": {"dash": (0.05, 0.045, 0.04), "trim": (0.22, 0.17, 0.11), "seat": (0.33, 0.22, 0.12),
            "door": (0.3, 0.21, 0.125), "cloth": (0.4, 0.31, 0.2), "liner": (0.55, 0.5, 0.42)},
    "green": {"dash": (0.05, 0.055, 0.05), "trim": (0.1, 0.11, 0.1), "seat": (0.06, 0.065, 0.06),
              "door": (0.09, 0.1, 0.09), "cloth": (0.14, 0.16, 0.13), "liner": (0.42, 0.42, 0.38)},
}

_scheme = SCHEMES["saddle"]


def use_scheme(name: str) -> None:
    global _scheme
    _scheme = SCHEMES[name]


def m_dash():
    return K.mat("Interior_Plastic_Dash", _scheme["dash"], 0.0, 0.62)


def m_trim():
    return K.mat("Interior_Plastic_Trim", _scheme["trim"], 0.0, 0.6)


def m_black():
    return K.mat("Interior_Plastic_Black", (0.02, 0.02, 0.022), 0.0, 0.55)


def m_seat():
    return K.mat("Interior_Vinyl_Seat", _scheme["seat"], 0.0, 0.55)


def m_door():
    return K.mat("Interior_Vinyl_Door", _scheme["door"], 0.0, 0.58)


def m_cloth():
    return K.mat("Interior_Cloth_Seat", _scheme["cloth"], 0.0, 0.92)


def m_belt():
    return K.mat("Interior_Cloth_Belt", (0.04, 0.04, 0.045), 0.0, 0.85)


def m_liner():
    return K.mat("Interior_Liner_Roof", _scheme["liner"], 0.0, 0.75)


def m_floor():
    return K.mat("Interior_Rubber_Floor", (0.04, 0.04, 0.042), 0.0, 0.8)


def m_mat():
    return K.mat("Interior_Rubber_Mat", (0.065, 0.065, 0.068), 0.0, 0.75)


def m_chrome():
    return K.mat("Interior_Chrome", (0.82, 0.82, 0.8), 1.0, 0.1)


def m_steel():
    return K.mat("Interior_Steel", (0.3, 0.3, 0.3), 1.0, 0.12)


def m_mirror():
    return K.mat("Interior_Mirror", (0.9, 0.9, 0.9), 1.0, 0.03)


def m_decal():
    return K.mat("Interior_Decal", (1.0, 1.0, 1.0), 0.0, 0.42)


def m_display():
    return K.mat("Interior_Display", (0.02, 0.04, 0.03), 0.0, 0.3)


def m_needle():
    return K.mat("Interior_Needle", (0.95, 0.22, 0.04), 0.0, 0.45)


def m_lamp():
    return K.mat("Interior_Lamp", (0.75, 0.72, 0.62), 0.0, 0.35)


# --- Helpers ------------------------------------------------------------------------------

def decal(name, centre, right, up, w, h, key):
    """A printed face from the sheet: `right` and `up` as whoever faces it sees them."""
    c, r, u = Vector(centre), Vector(right).normalized(), Vector(up).normalized()
    ob = K.sheet(name, [c - r * (w * 0.5) - u * (h * 0.5), c + r * (w * 0.5) - u * (h * 0.5),
                        c + r * (w * 0.5) + u * (h * 0.5), c - r * (w * 0.5) + u * (h * 0.5)], m_decal())
    x, y, pw, ph = DECALS[key]
    uvs = [(x / SHEET, 1.0 - (y + ph) / SHEET), ((x + pw) / SHEET, 1.0 - (y + ph) / SHEET),
           ((x + pw) / SHEET, 1.0 - y / SHEET), (x / SHEET, 1.0 - y / SHEET)]
    uvl = ob.data.uv_layers.new(name="UVMap")
    for li, loop in enumerate(ob.data.loops):
        uvl.data[li].uv = uvs[loop.vertex_index]
    return ob


def on_decal(centre, right, up, w, h, key, px, py):
    """Where pixel (px, py) of a decal's rectangle lies on its face."""
    _, _, pw, ph = DECALS[key]
    c, r, u = Vector(centre), Vector(right).normalized(), Vector(up).normalized()
    return c + r * ((px / pw - 0.5) * w) + u * ((0.5 - py / ph) * h)


def lbox(name, pivot, rot, local, size, material, bevel=0.0, segs=2):
    """A box in a tilted frame: `local` from `pivot`, turned by the 3x3 `rot`."""
    return K.box(name, Vector(pivot) + rot @ Vector(local), size, material, bevel=bevel, segs=segs, rot=rot)


def needle(name, pivot, normal, zero_dir, length):
    """A dial needle lying on a face whose normal is `normal`, pointing along `zero_dir`
    at rest, turning about its own origin (its node's glTF +Y is the face normal)."""
    n = Vector(normal).normalized()
    x = Vector(zero_dir).normalized()
    y = n.cross(x).normalized()
    blade = K.prism(name, [(-0.01, -0.0022), (length * 0.8, -0.0014), (length, 0.0), (length * 0.8, 0.0014), (-0.01, 0.0022)],
                    0.0015, 0.003, m_needle(), plane="XY")
    hub = K.cyl(name + "_hub", (0, 0, 0.0005), (0, 0, 0.0045), 0.0075, m_black(), 14)
    ob = K.join([blade, hub], name)
    ob.matrix_world = Matrix.Translation(Vector(pivot)) @ Matrix((x, y, n)).transposed().to_4x4()
    return ob


def place(obs, xf):
    """Moves a group into another cab: meshes are baked through `xf`; a needle keeps
    its own frame and only its pivot moves."""
    if xf is None:
        return obs
    for ob in obs:
        if ob.name.startswith("Needle_"):
            ob.matrix_world = Matrix.Translation(xf @ ob.matrix_world.translation) @ ob.matrix_world.to_3x3().to_4x4()
        else:
            ob.data.transform(xf @ ob.matrix_world)
            ob.matrix_world = Matrix.Identity(4)
            if xf.determinant() < 0.0:
                ob.data.flip_normals()
    return obs


def fit(src_lo, src_hi, dst_lo, dst_hi) -> Matrix:
    """The matrix that takes the box src (lo, hi) onto dst, axis by axis."""
    s = [(dst_hi[i] - dst_lo[i]) / (src_hi[i] - src_lo[i]) for i in range(3)]
    t = [dst_lo[i] - src_lo[i] * s[i] for i in range(3)]
    return Matrix.Translation(Vector(t)) @ Matrix.Diagonal((s[0], s[1], s[2], 1.0))


def shift(dx=0.0, dy=0.0, dz=0.0) -> Matrix:
    return Matrix.Translation(Vector((dx, dy, dz)))


# --- The dashboard --------------------------------------------------------------------------

# The fascia stands at X_FACE, the instruments ahead of the wheel at Y_DRIVER.
X_FACE = 1.19
Y_DRIVER = 0.377
HALF_W = 0.75


def vent(name, y, z, w=0.115, h=0.06, x=X_FACE):
    """A face vent: a frame, louvres behind it and the thumb tab."""
    obs = [K.box(name + "_frame", (x - 0.004, y, z), (0.014, w + 0.016, h + 0.016), m_black(), bevel=0.004)]
    obs.append(decal(name + "_slats", (x - 0.0115, y, z), (0, -1, 0), (0, 0, 1), w, h, "slats"))
    for k in range(4):
        zz = z - h * 0.5 + h * (k + 0.5) / 4.0
        obs.append(K.box(name + "_louvre", (x - 0.014, y, zz), (0.012, w - 0.004, 0.0035), m_black(), rot=(0.0, math.radians(-28), 0.0)))
    obs.append(K.box(name + "_tab", (x - 0.02, y, z), (0.012, 0.012, 0.02), m_black(), bevel=0.003))
    return obs


def dash(xf=None, glovebox=True):
    """The dashboard across the cab, with the instrument binnacle, the vents, the centre
    stack (radio, heater sliders, ashtray) and the glovebox. Returns its parts; the radio,
    its display and the needles are separate, named objects among them."""
    obs = []
    P, T, B, C = m_dash(), m_trim(), m_black(), m_chrome()
    # The body of the dash: fascia, a padded brow, the top running to the windshield.
    prof = [(1.215, 0.9), (X_FACE, 0.94), (X_FACE, 1.158), (1.166, 1.176), (1.162, 1.196), (1.176, 1.214), (1.22, 1.224),
            (1.51, 1.238), (1.53, 1.2), (1.53, 0.9)]
    obs.append(K.prism("dash_body", prof, -HALF_W, HALF_W, P, plane="XZ", bevel=0.007, segs=2, bevel_angle=20.0))
    # Defroster slots under the windshield.
    for y in (-0.36, 0.36):
        obs.append(K.box("defrost", (1.43, y, 1.2345), (0.022, 0.42, 0.004), B))
        for k in range(12):
            obs.append(K.box("defrost_rib", (1.43, y - 0.2 + 0.4 * (k + 0.5) / 12.0, 1.2365), (0.022, 0.004, 0.003), P))
    # The binnacle: a hood round the recessed cluster.
    y0 = Y_DRIVER
    obs.append(K.box("binnacle_top", (1.15, y0, 1.192), (0.115, 0.43, 0.034), P, bevel=0.014, segs=3))
    obs.append(K.box("binnacle_bottom", (1.165, y0, 1.026), (0.07, 0.43, 0.026), P, bevel=0.01))
    for s in (-1, 1):
        obs.append(K.box("binnacle_side", (1.16, y0 + s * 0.2, 1.108), (0.085, 0.03, 0.17), P, bevel=0.012, segs=3))
    face_c = (1.168, y0, 1.108)
    fw, fh = 0.365, 0.365 * 240.0 / 640.0
    right, up = (0, -1, 0), (0, 0, 1)
    obs.append(decal("cluster", face_c, right, up, fw, fh, "cluster"))
    obs.append(K.box("cluster_back", (1.176, y0, 1.108), (0.012, 0.38, 0.15), B))
    out = Vector((-1, 0, 0))
    sp = on_decal(face_c, right, up, fw, fh, "cluster", 170, 125) + out * 0.001
    a = math.radians(225)
    obs.append(needle("Needle_Speed", sp, out, (0.0, -math.cos(a), math.sin(a)), 0.047))
    fu = on_decal(face_c, right, up, fw, fh, "cluster", 430, 95) + out * 0.001
    a = math.radians(150)
    obs.append(needle("Needle_Fuel", fu, out, (0.0, -math.cos(a), math.sin(a)), 0.027))
    te = on_decal(face_c, right, up, fw, fh, "cluster", 560, 95) + out * 0.001
    a = math.radians(105)
    temp = needle("needle_temp", te, out, (0.0, -math.cos(a), math.sin(a)), 0.027)
    K.bake_transform(temp)
    obs.append(temp)
    # Pull knobs left of the binnacle (lights, wipers), the outer vents.
    for k, z in enumerate((1.045, 0.99)):
        obs.append(K.cyl("knob_stem", (X_FACE, 0.665, z), (X_FACE - 0.02, 0.665, z), 0.006, C, 10))
        obs.append(K.cyl("knob", (X_FACE - 0.018, 0.665, z), (X_FACE - 0.034, 0.665, z), 0.015, B, 16, bevel=0.003))
    obs += vent("vent_l", 0.665, 1.112)
    obs += vent("vent_r", -0.665, 1.112)
    # The centre stack: two vents, the radio, the heater panel, the ashtray and the lighter.
    xs = X_FACE - 0.022
    obs.append(K.box("stack", (X_FACE - 0.006, 0.0, 1.04), (0.034, 0.31, 0.27), P, bevel=0.009, segs=2))
    obs += vent("vent_cl", 0.075, 1.135, w=0.115, h=0.05, x=xs)
    obs += vent("vent_cr", -0.075, 1.135, w=0.115, h=0.05, x=xs)
    rw, rh = 0.19, 0.19 * 152.0 / 512.0
    rc = Vector((xs - 0.008, 0.0, 1.062))
    radio = [K.box("radio_body", rc + Vector((0.006, 0, 0)), (0.016, rw + 0.006, rh + 0.006), B, bevel=0.003),
             decal("radio_face", rc + Vector((-0.0025, 0, 0)), right, up, rw, rh, "radio")]
    for px in (62, 450):
        kc = on_decal(rc, right, up, rw, rh, "radio", px, 70)
        radio.append(K.cyl("radio_knob", kc, kc + out * 0.016, 0.0115, B, 18, bevel=0.002))
        radio.append(K.cyl("radio_knob_cap", kc + out * 0.016, kc + out * 0.0175, 0.008, C, 14))
    obs.append(K.join(radio, "Radio"))
    dc = on_decal(rc, right, up, rw, rh, "radio", 256, 41) + out * 0.0032
    disp = K.sheet("RadioDisplay", [dc + Vector((0, 0.038, -0.0065)), dc + Vector((0, -0.038, -0.0065)),
                                    dc + Vector((0, -0.038, 0.0065)), dc + Vector((0, 0.038, 0.0065))], m_display())
    K.uv_pane(disp)
    obs.append(disp)
    hw_, hh = 0.2, 0.2 * 120.0 / 512.0
    hc = Vector((xs - 0.0005, 0.0, 0.985))
    obs.append(decal("heater", hc, right, up, hw_, hh, "heater"))
    for k, px in enumerate((330, 150, 215)):
        lc = on_decal(hc, right, up, hw_, hh, "heater", px, 30 + k * 32)
        obs.append(K.box("heater_lever", lc + out * 0.007, (0.014, 0.008, 0.007), B, bevel=0.002))
        obs.append(K.box("heater_grip", lc + out * 0.016, (0.008, 0.016, 0.012), B, bevel=0.003))
    obs.append(K.box("ashtray", (xs - 0.002, 0.03, 0.932), (0.012, 0.11, 0.034), B, bevel=0.004))
    obs.append(K.box("ashtray_lip", (xs - 0.01, 0.03, 0.944), (0.006, 0.06, 0.006), C, bevel=0.002))
    obs.append(K.cyl("lighter", (xs, -0.075, 0.932), (xs - 0.014, -0.075, 0.932), 0.011, B, 14, bevel=0.002))
    obs.append(K.cyl("lighter_ring", (xs - 0.001, -0.075, 0.932), (xs - 0.004, -0.075, 0.932), 0.014, C, 16))
    if glovebox:
        obs.append(K.box("glovebox", (X_FACE - 0.003, -0.44, 1.0), (0.016, 0.42, 0.125), T, bevel=0.007, segs=2))
        obs.append(K.box("glovebox_gap", (X_FACE + 0.001, -0.44, 1.0), (0.01, 0.43, 0.135), B))
        obs.append(K.cyl("glovebox_latch", (X_FACE - 0.01, -0.44, 1.04), (X_FACE - 0.019, -0.44, 1.04), 0.012, C, 16, bevel=0.002))
        obs.append(K.box("grab_bar", (X_FACE - 0.03, -0.44, 1.142), (0.016, 0.3, 0.018), B, bevel=0.007, segs=2))
        for y in (-0.31, -0.57):
            obs.append(K.box("grab_post", (X_FACE - 0.015, y, 1.142), (0.03, 0.02, 0.018), B, bevel=0.005))
    # A parcel shelf lip under the fascia.
    obs.append(K.box("under_lip", (1.2, 0.0, 0.905), (0.03, 2 * HALF_W - 0.02, 0.022), T, bevel=0.008))
    return place(obs, xf)


def column(hub=(0.928, Y_DRIVER, 1.128), axis=(1.0, 0.0, -0.36), xf=None, length=0.3):
    """The steering column behind the wheel's hub: a shroud, the indicator and wiper
    stalks, the ignition barrel with the key in it, the shaft down to the firewall."""
    h = Vector(hub)
    a = Vector(axis).normalized()
    side = Vector((0.0, 1.0, 0.0))
    obs = []
    B, C = m_black(), m_chrome()
    obs.append(K.cyl("shroud", h + a * 0.03, h + a * length, 0.047, B, 20, r1=0.052, bevel=0.006))
    obs.append(K.cyl("shaft", h + a * length, h + a * (length + 0.4), 0.018, m_steel(), 10))
    for s, name in ((1, "indicator"), (-1, "wiper")):
        root = h + a * 0.075 + side * (s * 0.04)
        tip = root + side * (s * 0.1) - a * 0.022 + Vector((0, 0, 0.004))
        obs.append(K.tube("stalk_" + name, [root, root + side * (s * 0.045) - a * 0.004, tip], 0.0065, B, 10))
        obs.append(K.cyl("stalk_end_" + name, tip, tip + (tip - root).normalized() * 0.034, 0.0105, B, 14, bevel=0.003))
    key = h + a * 0.17 - side * 0.05 + Vector((0, 0, -0.012))
    obs.append(K.cyl("ignition", key + side * 0.012, key - side * 0.012, 0.016, C, 16, bevel=0.002))
    obs.append(K.box("key", key - side * 0.024, (0.016, 0.022, 0.003), m_steel(), bevel=0.001))
    obs.append(K.box("key_fob", key - side * 0.03 + Vector((0.0, 0.0, -0.03)), (0.022, 0.004, 0.036), m_seat(), bevel=0.0015))
    return place(obs, xf)


# --- Seats -----------------------------------------------------------------------------------

def seat(y0, xf=None, width=0.52, headrest=True, recline=10.0, name="seat"):
    """A bucket seat centred on y0: bolsters, a pleated cloth panel, piping, a headrest
    on two posts, the base on its runners. The cushion's front edge is at x = 0.99, its
    top at z = 0.87, the backrest rises to about 1.3."""
    V, Cl, B, C = m_seat(), m_cloth(), m_black(), m_chrome()
    obs = []
    hw = width * 0.5
    inner = width - 0.17
    tilt = Matrix.Rotation(math.radians(-3.0), 3, "Y")
    piv = Vector((0.715, y0, 0.8))
    obs.append(K.box(name + "_base", (0.7, y0, 0.645), (0.5, width - 0.08, 0.13), B, bevel=0.012))
    for s in (-1, 1):
        obs.append(K.box(name + "_rail", (0.7, y0 + s * (hw - 0.07), 0.573), (0.56, 0.03, 0.022), m_steel()))
        obs.append(lbox(name + "_bolster", piv, tilt, (0.0, s * (hw - 0.045), 0.0), (0.56, 0.09, 0.15), V, bevel=0.036, segs=3))
        obs.append(K.tube(name + "_piping", [piv + tilt @ Vector((-0.26, s * (hw - 0.088), 0.068)),
                                             piv + tilt @ Vector((0.2, s * (hw - 0.088), 0.068)),
                                             piv + tilt @ Vector((0.262, s * (hw - 0.088), 0.03))], 0.0045, V, 6))
    obs.append(lbox(name + "_front", piv, tilt, (0.25, 0.0, -0.004), (0.07, inner + 0.02, 0.15), V, bevel=0.03, segs=3))
    n = 5
    for k in range(n):
        x = -0.265 + 0.48 * (k + 0.5) / n
        obs.append(lbox(name + "_pleat", piv, tilt, (x, 0.0, -0.004), (0.48 / n + 0.004, inner, 0.14), Cl, bevel=0.022, segs=2))
    # The backrest, leaning back about its hinge.
    lean = Matrix.Rotation(math.radians(-recline), 3, "Y")
    hp = Vector((0.455, y0, 0.84))
    for s in (-1, 1):
        obs.append(lbox(name + "_back_bolster", hp, lean, (-0.06, s * (hw - 0.045), 0.235), (0.125, 0.09, 0.47), V, bevel=0.036, segs=3))
        obs.append(K.tube(name + "_back_piping", [hp + lean @ Vector((0.006, s * (hw - 0.088), 0.01)),
                                                  hp + lean @ Vector((0.006, s * (hw - 0.088), 0.4))], 0.0045, V, 6))
    obs.append(lbox(name + "_back_top", hp, lean, (-0.06, 0.0, 0.438), (0.125, inner + 0.02, 0.07), V, bevel=0.03, segs=3))
    for k in range(n):
        z = 0.01 + 0.395 * (k + 0.5) / n
        obs.append(lbox(name + "_back_pleat", hp, lean, (-0.058, 0.0, z), (0.11, inner, 0.395 / n + 0.004), Cl, bevel=0.022, segs=2))
    obs.append(lbox(name + "_back_shell", hp, lean, (-0.122, 0.0, 0.225), (0.022, width - 0.03, 0.45), V, bevel=0.009))
    obs.append(K.cyl(name + "_recliner", (0.455, y0 - hw - 0.004, 0.83), (0.455, y0 - hw + 0.02, 0.83), 0.03, B, 14, bevel=0.004))
    if headrest:
        obs.append(lbox(name + "_headrest", hp, lean, (-0.07, 0.0, 0.565), (0.1, 0.25, 0.145), V, bevel=0.04, segs=3))
        for s in (-1, 1):
            obs.append(K.cyl(name + "_post", hp + lean @ Vector((-0.07, s * 0.065, 0.45)), hp + lean @ Vector((-0.07, s * 0.065, 0.52)), 0.006, C, 8))
    return place(obs, xf)


def belt(side, xf=None):
    """A seat belt hanging from the pillar on `side` (1 left, -1 right) to its reel."""
    s = side
    top = Vector((0.37, s * 0.632, 1.5))
    low = Vector((0.39, s * 0.722, 0.72))
    w = Vector((0.046, 0.0, 0.0))
    strap = K.sheet("belt", [top, top + w, low + w, low], m_belt(), thickness=0.003)
    obs = [strap, K.box("belt_guide", top + w * 0.5 + Vector((0, 0, 0.01)), (0.06, 0.016, 0.03), m_black(), bevel=0.005),
           K.box("belt_reel", low + w * 0.5 + Vector((0, s * 0.004, -0.05)), (0.075, 0.03, 0.09), m_black(), bevel=0.008),
           K.box("belt_tongue", (top + low) * 0.5 + w * 0.5 + Vector((0, -s * 0.004, 0)), (0.048, 0.005, 0.055), m_steel(), bevel=0.002)]
    return place(obs, xf)


# --- Doors, floor, console, pedals ------------------------------------------------------------

def door_card(side, xf=None, x0=0.32, x1=1.34, z0=0.6, z1=1.2, y=0.735):
    """The door card on `side` (1 left, -1 right): a vinyl panel with a cloth insert
    between bright strips, an armrest, the door handle, the window winder, a map pocket,
    a speaker grille, the sill cap with its lock button."""
    s = side
    V, T, B, C = m_door(), m_trim(), m_black(), m_chrome()
    obs = []
    cx, lx = (x0 + x1) * 0.5, x1 - x0
    obs.append(K.box("card", (cx, s * (y + 0.02), (z0 + z1) * 0.5), (lx, 0.04, z1 - z0), V, bevel=0.012, segs=2))
    obs.append(K.box("card_insert", (cx - 0.03, s * (y - 0.002), 1.0), (lx - 0.3, 0.012, 0.2), m_cloth(), bevel=0.005))
    for z in (1.108, 0.892):
        obs.append(K.box("card_strip", (cx - 0.03, s * (y - 0.004), z), (lx - 0.28, 0.006, 0.007), C, bevel=0.002))
    obs.append(K.box("armrest", (0.72, s * (y - 0.032), 0.9), (0.4, 0.07, 0.052), T, bevel=0.022, segs=3))
    obs.append(K.box("armrest_foot", (0.72, s * (y - 0.012), 0.87), (0.3, 0.03, 0.05), T, bevel=0.012))
    obs.append(K.box("handle_bezel", (1.12, s * (y - 0.003), 0.985), (0.125, 0.012, 0.058), B, bevel=0.005))
    obs.append(K.box("handle", (1.115, s * (y - 0.014), 0.985), (0.085, 0.011, 0.021), C, bevel=0.004))
    wc = Vector((0.98, s * (y - 0.004), 1.04))
    ax = Vector((0.0, -s, 0.0))
    obs.append(K.cyl("winder_boss", wc, wc + ax * 0.016, 0.021, B, 16, bevel=0.003))
    arm = Vector((math.cos(math.radians(38)), 0.0, math.sin(math.radians(38))))
    obs.append(K.box("winder_arm", wc + ax * 0.02 + arm * 0.036, (0.086, 0.007, 0.015), C, bevel=0.003,
                     rot=(0.0, math.radians(-38), 0.0)))
    obs.append(K.cyl("winder_knob", wc + ax * 0.022 + arm * 0.072, wc + ax * 0.052 + arm * 0.072, 0.0105, B, 12, bevel=0.003))
    obs.append(K.box("pocket", (0.78, s * (y - 0.016), 0.69), (0.5, 0.034, 0.12), T, bevel=0.01))
    obs.append(K.box("pocket_mouth", (0.78, s * (y - 0.018), 0.7505), (0.47, 0.022, 0.003), B))
    obs.append(decal("speaker", (1.19, s * (y - 0.0015), 0.75), (-s, 0, 0), (0, 0, 1), 0.135, 0.135, "speaker"))
    obs.append(K.box("sill_cap", (cx, s * (y + 0.021), z1 + 0.004), (lx + 0.02, 0.058, 0.02), T, bevel=0.008, segs=2))
    obs.append(K.cyl("lock_button", (x0 + 0.17, s * (y + 0.018), z1 + 0.012), (x0 + 0.17, s * (y + 0.018), z1 + 0.042), 0.0055, B, 10, bevel=0.002))
    return place(obs, xf)


def floor(xf=None, x_rear=0.19, x_toe=1.16, x_fire=1.56, z=0.56, z_toe=0.84, hw=0.78, mats=True):
    """The floor covering up the toe board to the firewall, the gearbox tunnel, the
    ribbed mats and the door sill plates."""
    F, M = m_floor(), m_mat()
    obs = [K.prism("floor", [(x_rear, z - 0.06), (x_rear, z), (x_toe, z), (x_fire, z_toe), (x_fire, 1.02), (x_fire + 0.04, 1.02),
                             (x_fire + 0.04, z - 0.06)], -hw, hw, F, plane="XZ")]
    obs.append(K.box("tunnel", (1.19, 0.0, z + 0.03), (0.78, 0.25, 0.12), F, bevel=0.04, segs=3))
    if mats:
        slope = math.atan2(z_toe - z, x_fire - x_toe)
        for y in (-0.42, 0.42):
            obs.append(K.box("mat", (0.83, y, z + 0.005), (0.64, 0.5, 0.012), M, bevel=0.004))
            c = Vector((x_toe + 0.16 * math.cos(slope), y, z + 0.16 * math.sin(slope) + 0.006))
            obs.append(K.box("mat_toe", c, (0.36, 0.5, 0.012), M, bevel=0.004, rot=(0.0, -slope, 0.0)))
    for s in (-1, 1):
        obs.append(K.box("sill_plate", (0.83, s * (hw - 0.03), z + 0.02), (1.0, 0.06, 0.045), m_steel(), bevel=0.008))
    return place(obs, xf)


def console(xf=None, handbrake=True):
    """The low console between the seats with the handbrake, and the gear lever in its
    gaiter with the gear pattern on the knob."""
    T, B, C = m_trim(), m_black(), m_chrome()
    obs = [K.box("console", (0.72, 0.0, 0.655), (0.62, 0.15, 0.17), T, bevel=0.016, segs=2)]
    obs.append(K.box("console_tray", (0.55, 0.0, 0.7385), (0.2, 0.1, 0.006), B, bevel=0.002))
    if handbrake:
        p0, p1 = Vector((0.7, 0.0, 0.745)), Vector((0.9, 0.0, 0.8))
        d = (p1 - p0).normalized()
        obs.append(K.box("handbrake_slot", (0.78, 0.0, 0.741), (0.2, 0.04, 0.005), B))
        obs.append(K.cyl("handbrake", p0, p1 - d * 0.1, 0.009, m_steel(), 10))
        obs.append(K.cyl("handbrake_grip", p1 - d * 0.11, p1, 0.016, B, 14, bevel=0.004))
        obs.append(K.cyl("handbrake_button", p1, p1 + d * 0.01, 0.007, C, 10))
    base = Vector((1.04, 0.0, 0.62))
    up = Vector((-0.2, 0.0, 1.0)).normalized()
    obs.append(K.revolve("gaiter", [(0.0, 0.062), (0.022, 0.05), (0.03, 0.054), (0.052, 0.04), (0.06, 0.044), (0.082, 0.03),
                                    (0.09, 0.033), (0.112, 0.016), (0.118, 0.012)], base, up, m_floor(), 20))
    obs.append(K.box("gaiter_ring", base + Vector((0, 0, 0.002)), (0.15, 0.15, 0.008), B, bevel=0.003))
    top = base + up * 0.33
    obs.append(K.cyl("gear_stick", base + up * 0.1, top, 0.0075, C, 10))
    obs.append(K.revolve("gear_knob", [(-0.012, 0.011), (0.0, 0.021), (0.018, 0.026), (0.034, 0.022), (0.042, 0.012)], top, up, B, 18))
    side = Vector((0.0, -1.0, 0.0))
    obs.append(decal("gear_pattern", top + up * 0.0425, side, up.cross(side), 0.024, 0.024, "shift"))
    return place(obs, xf)


def pedals(xf=None, ys=(0.525, 0.435, 0.335)):
    """Clutch, brake and accelerator on their arms."""
    obs = []
    R, S = m_mat(), m_steel()
    tilt = (0.0, math.radians(38), 0.0)
    for k, y in enumerate(ys[:2]):
        c = Vector((1.36, y, 0.765))
        obs.append(K.box("pedal_pad", c, (0.014, 0.062, 0.07), R, bevel=0.004, rot=tilt))
        obs.append(K.tube("pedal_arm", [c + Vector((0.008, 0, 0.0)), c + Vector((0.05, 0, 0.1)), c + Vector((0.09, 0, 0.26))], 0.008, S, 8))
    c = Vector((1.35, ys[2], 0.745))
    obs.append(K.box("throttle_pad", c, (0.012, 0.044, 0.15), R, bevel=0.004, rot=(0.0, math.radians(52), 0.0)))
    obs.append(K.tube("throttle_arm", [c + Vector((0.03, 0, 0.03)), c + Vector((0.1, 0, 0.2))], 0.006, S, 8))
    return place(obs, xf)


# --- Roof ------------------------------------------------------------------------------------

def headliner(xf=None, x0=0.27, x1=1.05, hw=0.61, z=1.64):
    """The headliner with its dome lamp."""
    obs = [K.box("headliner", ((x0 + x1) * 0.5, 0.0, z + 0.015), (x1 - x0, 2 * hw, 0.03), m_liner(), bevel=0.012, segs=2)]
    cx = (x0 + x1) * 0.5 - 0.04
    obs.append(K.box("dome_base", (cx, 0.0, z - 0.002), (0.13, 0.085, 0.008), m_trim(), bevel=0.003))
    obs.append(K.box("dome_lens", (cx, 0.0, z - 0.009), (0.1, 0.06, 0.012), m_lamp(), bevel=0.005))
    return place(obs, xf)


def visors_and_mirror(xf=None, x=0.955, z=1.622, mirror_at=(0.975, 0.0, 1.565)):
    """Two padded sun visors on their rods (a label on the driver's) and the inside mirror."""
    obs = []
    C, B = m_chrome(), m_black()
    for s in (-1, 1):
        obs.append(K.box("visor", (x, s * 0.33, z), (0.15, 0.37, 0.018), m_liner(), bevel=0.008, segs=2, rot=(0.0, math.radians(4), 0.0)))
        obs.append(K.cyl("visor_rod", (x + 0.07, s * 0.14, z + 0.004), (x + 0.07, s * 0.53, z + 0.004), 0.005, C, 8))
        obs.append(K.box("visor_clip", (x + 0.07, s * 0.15, z + 0.006), (0.02, 0.02, 0.018), B, bevel=0.004))
    obs.append(decal("visor_label", (x - 0.01, 0.33, z - 0.0102), (0, -1, 0), (1, 0, 0), 0.1, 0.05, "label"))
    m = Vector(mirror_at)
    obs.append(K.tube("mirror_stem", [m + Vector((0.055, 0, 0.05)), m + Vector((0.02, 0, 0.02)), m + Vector((0.008, 0, 0.0))], 0.007, B, 8))
    obs.append(K.box("mirror_case", m, (0.024, 0.25, 0.064), B, bevel=0.01, segs=2))
    obs.append(K.box("mirror_glass", m + Vector((-0.0125, 0, 0)), (0.002, 0.228, 0.046), m_mirror()))
    return place(obs, xf)


def group(obs, name):
    """One mesh of a group's loose parts; the named ones (the radio, its display, the
    needles) stay their own objects. Returns [joined, named...]."""
    named = [o for o in obs if o.name in ("Radio", "RadioDisplay") or o.name.startswith("Needle_")]
    rest = [o for o in obs if o not in named]
    return [K.join(rest, name)] + named
