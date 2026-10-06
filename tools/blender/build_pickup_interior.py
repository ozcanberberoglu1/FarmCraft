"""Builds the Lightbody '90 pickup's cab interior (art/models/vehicles/pickup_90/interior.glb),
which the game puts in place of the downloaded model's low-poly cab (VehicleTable
"interior"; every body on that chassis shares it): the shared cab kit's dashboard,
seats, door cards, console and pedals (tools/blender/cab_kit.py) and the trim that is
this cab's own: the headliner, the windshield and rear headers, the rails over the
doors, the pillars, the rear corners, the rear wall, the kick panels. That trim is
fitted to the body it sits in: the build loads the exterior model, finds its roof skin,
its panes' rims and its walls by ray casts (tools/blender/cab_shell.py) and lays the
trim a clearance inside them, then pulls in whatever of the kit still stands outside
and stops if anything does (so nothing of the cab shows above the roof, behind the
rear wall or through the sides).

Meshes: Cab (everything that stands still, one surface a material), and by name for the
game Radio, RadioDisplay, Needle_Speed, Needle_Fuel. The steering wheel stays the
modelled one (tools/build_pickup_hd.py).

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_pickup_interior.py [-- --preview=/abs/dir]
"""
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cab_kit as CK  # noqa: E402
import cab_shell  # noqa: E402
import vehicle_kit as K  # noqa: E402

OUT = os.path.join(K.ROOT, "art/models/vehicles/pickup_90/interior.glb")
# The body the cab has to fit inside: its skin, frames and panes are measured here, at
# every build (tools/blender/cab_shell.py), not copied in as numbers.
BODY = os.path.join(K.ROOT, "art/models/vehicles/pickup_90/scene.gltf")
# Trim stands this far inside the skin; its lips at the panes' rims this far.
CLEAR = 0.02
LIP = 0.006
# What the kit's own parts (dash, door cards, seats...) keep from the painted skin and the panes.
KIT_CLEAR = 0.008
# The headliner in plan: its half width, its rear edge, and how far behind the
# windshield's top edge its front edge runs (the header trim fills that band).
LINER_HW = 0.57
LINER_REAR = 0.32
HEADER = 0.07
# Rows of the headliner (front to back, across), of a strip from the liner to a pane,
# and down the pillars.
NX, NY, NV, NP = 10, 14, 2, 6
# The welt round the headliner and the rubber welt on the trim's edge round each pane.
WELT_R = 0.004
SEAL_R = 0.005
# The rear wall's face, and where the rear corners' trim meets it and the door cards
# below the windows (x, y of the wall end and the door end, the heights).
WALL_X = 0.207
CORNER_WALL = (WALL_X, 0.57)
CORNER_DOOR = (0.35, 0.742)
CORNER_Z = (1.19, 1.0, 0.8, 0.585)

# The kick panels in plan, from the door card's front end forwards (the wheel housing
# pushes them in), and their heights.
KICK_PLAN = ((1.3, 0.75), (1.38, 0.765), (1.45, 0.75), (1.5, 0.7), (1.55, 0.64), (1.6, 0.56))
KICK_Z = (0.57, 0.75, 0.95, 1.2)

S = None
_fits = {}


def fit(p, clear):
    """A point pulled inside the body until it has `clear` to the skin and the panes
    (the same point always lands in the same place, so strips share their edges)."""
    key = (round(p[0], 5), round(p[1], 5), round(p[2], 5), clear)
    if key not in _fits:
        _fits[key] = S.fit(p, clear)
    return _fits[key].copy()


def at_rim(rim, clear):
    """A point of a pane's rim moved straight in from the pane (along its normal there)
    until it has `clear` to the skin, the frames and the pane: the trim's edge stands
    at the rim, not over the glass. (Its lip is still pulled towards the cab's middle,
    a little over the glass: a look along the pane from across the cab must end on the
    glass under the lip, not pass behind the trim onto the bare skin.)"""
    key = (round(rim[0], 5), round(rim[1], 5), round(rim[2], 5), clear, "rim")
    if key not in _fits:
        rim = Vector(rim)
        _fits[key] = S.fit(rim, clear, toward=rim + S.into_cab(rim) * 0.3)
    return _fits[key].copy()


def resample(pts, n):
    """n + 1 points evenly along a polyline."""
    pts = [Vector(p) for p in pts]
    lens = [0.0]
    for a, b in zip(pts, pts[1:]):
        lens.append(lens[-1] + (b - a).length)
    out = [pts[0].copy()]
    for k in range(1, n):
        d = lens[-1] * k / n
        i = max(j for j in range(len(pts) - 1) if lens[j] <= d)
        out.append(pts[i].lerp(pts[i + 1], (d - lens[i]) / max(lens[i + 1] - lens[i], 1e-9)))
    out.append(pts[-1].copy())
    return out


def across(a, rim, n=NV):
    """From a point of the trim to a pane's rim: [a, points between, the trim's edge
    CLEAR in from the rim, its lip against the pane]."""
    edge = at_rim(rim, CLEAR)
    return [a.copy()] + [fit(a.lerp(edge, k / n), CLEAR) for k in range(1, n)] + [edge, fit(rim, LIP)]


def between(rim_a, rim_b, n=2 * NV, wrap_from=None, rims=True):
    """Across a pillar from one pane's rim to the other's: [lip, edge, points between,
    edge, lip]. With `wrap_from` the points between are pushed out to the skin from
    that point (round a corner post) before they are fitted. `rims` False: the ends
    are points of the trim below the panes, not of a rim."""
    end = at_rim if rims else fit
    ea, eb = end(rim_a, CLEAR), end(rim_b, CLEAR)
    mids = []
    for k in range(1, n):
        p = ea.lerp(eb, k / n)
        if wrap_from is not None:
            o = Vector((wrap_from[0], wrap_from[1], p.z))
            d = (p - o).normalized()
            hit = S.cast(o, d)
            if hit is not None and (hit - o).length > (p - o).length:
                p = hit - d * (CLEAR * 1.6)
        mids.append(fit(p, CLEAR))
    return [fit(rim_a, LIP), ea] + mids + [eb, fit(rim_b, LIP)]


def surface(name, rows, material, smooth=50.0):
    """A skin through rows of points (the same count each; rows may share points)."""
    return skin(name, [rows], material, smooth)


def skin(name, patches, material, smooth=50.0):
    """One skin of several patches (each rows of points, see surface), welded where
    they share their edges: the shading runs across the joins, not to a crease there."""
    bm = bmesh.new()
    mid = Vector((0.7, 0.0, 1.2))
    for rows in patches:
        vs = [[bm.verts.new(p) for p in row] for row in rows]
        faces = []
        for a, b in zip(vs, vs[1:]):
            for k in range(len(a) - 1):
                quad = []
                for v in (a[k], a[k + 1], b[k + 1], b[k]):
                    if all((v.co - u.co).length > 1e-5 for u in quad):
                        quad.append(v)
                if len(quad) >= 3:
                    faces.append(bm.faces.new(quad))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        bm.normal_update()
        # Faces look into the cab.
        if sum((mid - f.calc_center_median()).dot(f.normal) for f in faces) < 0.0:
            bmesh.ops.reverse_faces(bm, faces=faces)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    ob = K.from_bm(name, bm, material, smooth)
    ob["fitted"] = True
    return ob


def bead(name, pts, r, material):
    """A round moulding along points that keep their clearance (the build settles what
    of it still shows through a seam of the body, like the kit's parts)."""
    return K.tube(name, pts, r, material, 6)


def greenhouse():
    """The trim above the belt line, fitted to the body: the headliner under the roof
    skin's crown, the windshield and rear headers, the rails over the doors, the
    windshield pillars down into the dash and the rear corners down to the floor. One
    skin: each strip starts on its neighbour's edge, so no join is open. A welt runs
    round the headliner and a rubber one along the trim's edge at each pane."""
    T, L = CK.m_trim(), CK.m_liner()
    obs, trim, rims = [], [], {}
    wtop = resample(sorted(S.edge("Windshield", 0, lambda p: p.z > 1.6), key=lambda p: p.y), NY)
    rtop = resample(sorted(S.edge("Glass_Rear", 0, lambda p: p.z > 1.57), key=lambda p: p.y), NY)
    # The headliner: CLEAR under the roof skin wherever it is.
    liner = []
    for i in range(NX + 1):
        row = []
        for j in range(NY + 1):
            y = -LINER_HW + 2.0 * LINER_HW * j / NY
            x = LINER_REAR + (wtop[j].x - HEADER - LINER_REAR) * i / NX
            p = Vector((x, y, S.roof(x, y) - CLEAR))
            row.append(S.fit(p, CLEAR, toward=(x, y, 1.3)))
        liner.append(row)
    obs.append(surface("headliner", liner, L))
    trim.append([across(liner[NX][j], wtop[j]) for j in range(NY + 1)])
    trim.append([across(liner[0][j], rtop[j]) for j in range(NY + 1)])
    for s, door in ((1, "Glass_Driver"), (-1, "Glass_Passenger")):
        j = NY if s > 0 else 0
        d_rear = sorted(S.edge(door, s, lambda p: p.x < 0.47), key=lambda p: -p.z)
        d_front = sorted(S.edge(door, s, lambda p: p.x > 0.95), key=lambda p: -p.z)
        d_top = [d_rear[0]] + sorted(S.edge(door, s, lambda p: p.z > 1.55 and p.x > 0.5), key=lambda p: p.x)
        w_side = sorted(S.edge("Windshield", s, lambda p: abs(p.y) > 0.56 and p.x < 1.39), key=lambda p: -p.z)
        r_side = sorted(S.edge("Glass_Rear", s, lambda p: abs(p.y) > 0.49), key=lambda p: -p.z)
        top = resample(d_top, NX)
        trim.append([across(liner[i][j], top[i]) for i in range(NX + 1)])
        # The windshield pillar: its top row is the header's end and the rail's end, so
        # it runs into both; its foot stands in the dash.
        ws, df = resample(w_side, NP), resample(d_front, NP)
        rows = [list(reversed(across(liner[NX][j], ws[0]))) + across(liner[NX][j], df[0])[1:]]
        rows += [between(ws[k], df[k]) for k in range(1, NP + 1)]
        rows.append([fit(p + Vector((0.0, 0.0, -0.07)), LIP) for p in rows[-1]])
        trim.append(rows)
        # The rear corner: the same at the back, round the corner post, and on down
        # between the rear wall and the door card to the floor.
        rs, dr = resample(r_side, NP), resample(d_rear, NP)
        rims[s] = (ws, df, top, dr, rs)
        post = (0.62, 0.0)
        rows = [list(reversed(across(liner[0][j], rs[0]))) + across(liner[0][j], dr[0])[1:]]
        rows += [between(rs[k], dr[k], wrap_from=post) for k in range(1, NP + 1)]
        for z in CORNER_Z:
            wall = Vector((CORNER_WALL[0], s * CORNER_WALL[1], z))
            card = Vector((CORNER_DOOR[0], s * CORNER_DOOR[1], z))
            rows.append(between(wall + Vector((0.0, -s * 0.05, 0.0)), card + Vector((0.06, 0.0, 0.0)), wrap_from=post, rims=False))
        trim.append(rows)
    obs.append(skin("upper_trim", trim, T))
    # The welt round the headliner and the rubber welt along the trim's edge at each pane.
    welt = liner[0] + [row[NY] for row in liner[1:]] + liner[NX][-2::-1] + [row[0] for row in liner[-2::-1]]
    obs.append(bead("liner_welt", welt, WELT_R, T))
    (wl, dfl, tl, drl, rl), (wr, dfr, tr, drr, rr) = rims[1], rims[-1]
    for run in (wl[::-1] + wtop[::-1] + wr, rl[::-1] + rtop[::-1] + rr, dfl[::-1] + tl[::-1] + drl, dfr[::-1] + tr[::-1] + drr):
        # Up one side of the pane, along its top and down the other (the runs share
        # their corner points).
        ring = [at_rim(p, CLEAR) for k, p in enumerate(run) if k == 0 or (p - run[k - 1]).length > 0.008]
        obs.append(bead("seal", ring, SEAL_R, CK.m_black()))
    return obs, liner


def shell():
    """The trim that closes the cab: the greenhouse's (see there), the rear wall and
    the ledge under the rear window, the kick panels, the dome lamp, the mirror's foot."""
    T, V = CK.m_trim(), CK.m_door()
    obs, liner = greenhouse()
    obs.append(K.box("rear_wall", (WALL_X - 0.015, 0.0, 0.905), (0.03, 1.28, 0.7), V, bevel=0.008))
    obs.append(K.box("rear_sill", (WALL_X + 0.008, 0.0, 1.25), (0.05, 1.2, 0.022), T, bevel=0.008))
    for s in (-1, 1):
        # The footwell's side from the door card round the wheel housing to the firewall.
        rows = [[fit(Vector((x, s * y, z)), CLEAR) for x, y in KICK_PLAN] for z in KICK_Z]
        obs.append(surface("kick_panel", rows, T))
    # The dome lamp on the liner, the pad the mirror's stem stands on.
    cx = 0.62
    z = liner[round(NX * (cx - LINER_REAR) / (liner[NX][NY // 2].x - LINER_REAR))][NY // 2].z
    obs.append(K.box("dome_base", (cx, 0.0, z - 0.003), (0.13, 0.085, 0.008), T, bevel=0.003))
    obs.append(K.box("dome_lens", (cx, 0.0, z - 0.01), (0.1, 0.06, 0.012), CK.m_lamp(), bevel=0.005))
    obs.append(K.box("mirror_foot", (1.03, 0.0, 1.624), (0.04, 0.05, 0.03), CK.m_black(), bevel=0.006))
    return obs


def settle(parts):
    """Pulls what still stands outside the body, or against a pane, in (the kit's parts
    are built for a square cab: the door cards' top edges, the dash's front corners
    under the windshield, the headrests against the rear window...)."""
    for ob in parts:
        if ob.name.startswith("Needle_") or ob.name in ("Radio", "RadioDisplay") or ob.get("fitted"):
            continue
        moved, far = S.fit_object(ob, KIT_CLEAR, outer_only=True)
        if moved:
            print("settled %-22s %4d of %5d vertices, up to %.1f cm" % (ob.name, moved, len(ob.data.vertices), far * 100.0))


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
                               ("left", (0.75, 1.5, 1.0), 16), ("back", (-1.0, 0.1, 1.42), 16), ("roof", (0.55, 1.0, 2.6), 16)):
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
    global S
    a = K.args()
    K.reset()
    S = cab_shell.Shell(BODY)
    CK.use_scheme("saddle")
    parts = shell() + CK.dash() + CK.column()
    parts += CK.seat(0.375, name="seat_l") + CK.seat(-0.375, name="seat_r") + CK.belt(1) + CK.belt(-1)
    parts += CK.door_card(1) + CK.door_card(-1)
    parts += CK.floor() + CK.console() + CK.pedals()
    parts += CK.visors_and_mirror(x=0.93)
    for ob in parts:
        if ob.name.startswith("lock_button"):
            # On the sill cap where the body lets it stand (the door leans in up here).
            ob.data.transform(Matrix.Translation((0.0, -0.022 if ob.data.vertices[0].co.y > 0.0 else 0.022, 0.0)))
    S.report(parts, 0.0, "as built")
    settle(parts)
    worst = S.report(parts, LIP - 0.001, "settled")
    if worst > 0.0:
        raise SystemExit("the cab does not fit inside the body")
    out = CK.group(parts, "Cab")
    K.export(out, OUT)
    if a.get("preview"):
        preview(out, a["preview"])


if __name__ == "__main__":
    main()
