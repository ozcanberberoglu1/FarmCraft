"""Builds the grey wolf into art/models/animals/wolf/ (WolfRig drives it in game).

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_wolf.py [-- --preview=/abs/dir] [--shape]
    --preview=DIR  renders of the result (side, front, back, top, head), joints marked
    --shape        only the reshaped body, its joints and previews (no textures, no export)

Source: the same "Dog" by Yury Misiyuk (Tim0) on Sketchfab, CC-BY-4.0, that Karamel is
built from (tools/blender/build_dog.py; art/models/animals/dog/source/dog_source.glb), so
the wolf has Karamel's skeleton and DogRig's procedural animation drives it (WolfRig).
Here the young Labrador is made into an Anatolian grey wolf:
  - the floppy ears laid flat against the skull (the flaps pressed onto it, their pink
    linings sunk inside) and new erect ears made for it: pointed, cupped, thick at the
    root, their hollows facing forward, set high on the skull;
  - reshaped (source units, facing +Y): long legs (the lower legs stretched, the body
    raised on them), big paws, a longer, narrower body with a deep chest and a tucked-up
    belly, a long, narrow muzzle with a gentler stop and tight lips, a longer tail;
    scaled to 72 cm at the withers standing on z = 0, centred between its feet;
  - skinned to the dog's skeleton (same bone names, see build_dog.bone_specs), the new
    ears on their own two bones each;
  - recoloured from the dog's painted coat to a grizzled grey wolf (the painted hair kept
    as the detail): a dark saddle over the back with black-tipped hair, buff-grey flanks,
    tawny legs with a dark line down the front of the forelegs, cream under the throat,
    chest and belly, white cheeks and lips, a pale brow over dark-rimmed eyes, a black
    tail tip, tawny backs of the ears with dark rims and pale hair inside; a normal map
    from the hair strokes and a roughness map (wet nose, glossy lips);
  - given eyes of their own (Eyes: two small balls in the sockets, skinned to the head;
    WolfRig's eye shader paints the amber iris and makes them shine back a light near
    the viewer);
  - given shell fur like Karamel's but long: a thick ruff round the neck and cheeks, a
    heavy coat over the shoulders and back, breeches on the thighs and a bushy tail;
    short on the face, legs and ears (FUR_MAX over UV2.y).
It also builds the wolf pelt item's model (wolf_pelt.gltf: a folded grey pelt, the tail
hanging off it) from the same coat.
"""
import math
import os
import sys

import bmesh
import bpy
import mathutils
import numpy as np
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dog as D  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art/models/animals/wolf")
TEX_DIR = os.path.join(OUT_DIR, "textures")

## Withers height of the finished wolf, metres.
WITHERS = 0.72
## Source units (inches, facing +Y): the withers before reshaping; the lower legs' span
## stretched (z from, z to) and by how much; the body lengthened between y0 and y1; the
## belly tucked up behind the ribs; the muzzle lengthened ahead of the stop; the paws
## made bigger; the tail lengthened.
SRC_WITHERS = 18.0
LEG_SPAN = (1.5, 7.0)
LEG_GROW = 0.62
BODY_SPAN = (-5.0, 4.0)
BODY_GROW = 0.08
TUCK = 2.6
STOP_Y = 14.4
MUZZLE_GROW = 0.42
NARROW = 0.86
PAW_GROW = 1.04
## The lower legs slimmed (their girth's share kept), along these bones (source units,
## the right legs: elbow, wrist, knuckle; stifle, hock, knuckle).
LEG_SLIM = 0.74
FORE_CHAIN = ((2.35, 5.2, 7.2), (2.5, 6.2, 2.3), (2.55, 6.9, 0.85))
HIND_CHAIN = ((2.2, -6.9, 8.0), (1.9, -10.9, 4.7), (1.9, -10.0, 0.95))
## The head made bigger about the top of the neck (blended in over the neck from y0 to
## y1), and the neck drawn out forward of the shoulders (y0 to y1, by how much).
HEAD_PIVOT = np.array([0.0, 11.0, 19.4])
HEAD_SCALE = 1.1
HEAD_BLEND = (9.6, 12.0)
NECK_SPAN = (7.0, 11.5)
NECK_GROW = 0.32
TAIL_GROW = 1.6
## The new ears (source units, the right one; the left mirrors it): the middle of the
## root on the skull, height, half-width at the root, the hollow's depth, the thickness,
## and their turns (radians): the hollow toward the outside, the tip out and back.
EAR_ROOT = np.array([2.0, 12.7, 23.35])
EAR_H = 3.6
EAR_W = 1.25
EAR_CUP = 0.5
EAR_THICK = 0.26
EAR_YAW = 0.32
EAR_ROLL = 0.3
EAR_PITCH = 0.2
## Where the ears' faces lie in the coat texture (free space in the dog's atlas): the
## front (hollow) and the back, (u0, v0, u1, v1).
EAR_UV_FRONT = (0.03, 0.03, 0.125, 0.34)
EAR_UV_BACK = (0.135, 0.03, 0.23, 0.34)
## The patches over the holes the dog's ear flaps leave (free space in the atlas).
PATCH_UV = (0.395, 0.01, 0.62, 0.235)
EAR_NU = 12
EAR_NV = 9
## The eyes' ovals on the head (source units): half their length along the head, half
## their height, and how far out of the head the eye mesh stands.
## Where the dog's painted eyes are (source units, the right one).
EYE_CENTRE = np.array([1.67, 17.02, 21.71])
EYE_A = 0.52
EYE_B = 0.36
EYE_OUT = 0.05
TEX_SIZE = 1024
FUR_TRIS = 7000
FUR_LAYERS = 14
## Longest fur (m): UV2.y is the fur length over this.
FUR_MAX = 0.07
## Part ids per vertex: 0 body, 1/2 the dog's ear linings (sunk), 3/4 the new ears.
EAR_L, EAR_R = 3, 4


def smoothstep(e0, e1, x):
    return D.smoothstep(e0, e1, x)


# --- The dog's ears put away --------------------------------------------------------------------

def weld(obj, part):
    """The source's halves welded along the whole back and the top of the head (the dog's
    weld leaves a crack there), and any other coincident vertices. Returns the parts per
    vertex of the welded mesh."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    lay = bm.verts.layers.int.new("part")
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        v[lay] = int(part[v.index])
    seam = [v for v in bm.verts if abs(v.co.x) < 0.06 and v[lay] == 0]
    bmesh.ops.remove_doubles(bm, verts=seam, dist=0.07)
    bmesh.ops.remove_doubles(bm, verts=[v for v in bm.verts if v[lay] == 0], dist=0.01)
    bm.verts.ensure_lookup_table()
    out = np.array([v[lay] for v in bm.verts], dtype=np.int64)
    bnd = sum(1 for e in bm.edges if e.is_boundary)
    bm.to_mesh(me)
    bm.free()
    print("welded: %d verts, %d boundary edges" % (len(out), bnd))
    return out


def find_flaps(obj, co, part):
    """The body vertices of the dog's hanging ear flaps (1 left, 2 right): those on the
    outer side of each flap's pink lining, close to it."""
    me = obj.data
    flap = np.zeros(len(co), dtype=np.int64)
    for which, side in ((1, -1.0), (2, 1.0)):
        idx = np.nonzero(part == which)[0]
        bm = bmesh.new()
        vmap = {}
        for i in idx:
            vmap[int(i)] = bm.verts.new(co[i])
        for p in me.polygons:
            vs = list(p.vertices)
            if part[vs[0]] == which:
                try:
                    bm.faces.new([vmap[v] for v in vs])
                except ValueError:
                    pass
        bm.normal_update()
        tree = BVHTree.FromBMesh(bm)
        cand = np.nonzero((part == 0) & (co[:, 0] * side > 1.1) & (co[:, 1] > 9.0) & (co[:, 1] < 16.5)
                & (co[:, 2] > 16.0) & (co[:, 2] < 24.6))[0]
        for i in cand:
            loc, nrm, fi, dist = tree.find_nearest(mathutils.Vector(co[i]))
            if loc is None:
                continue
            n = np.array(nrm)
            if n[0] * side < 0:
                n = -n
            if dist < 1.2 and np.dot(co[i] - np.array(loc), n) > -0.08:
                flap[i] = which
        bm.free()
    # Specks the test missed (where the flap meets the skull): a vertex mostly among
    # flap vertices is one too.
    nbrs = [[] for _ in range(len(co))]
    for a, b in D.edges(obj):
        nbrs[a].append(b)
        nbrs[b].append(a)
    for which, side in ((1, -1.0), (2, 1.0)):
        for it in range(8):
            add = [i for i in range(len(co)) if part[i] == 0 and flap[i] == 0 and co[i, 0] * side > 1.0
                   and 9.0 < co[i, 1] < 16.5 and 15.5 < co[i, 2] < 24.8
                   and 2 * sum(1 for j in nbrs[i] if flap[j] == which) >= len(nbrs[i])]
            if not add:
                break
            flap[add] = which
    return flap


def fill_hole(bm, loop, lay, uv_layer, onto, c0):
    """Closes one hole whose edge is `loop` (bmesh vertices in order): rings drawn in from
    the edge to its middle, laid on the head's ellipsoid (`onto`) with the edge's own
    offset from it fading inward, then relaxed; planar UVs in PATCH_UV."""
    L = np.array([tuple(v.co) for v in loop])
    c = L.mean(0)
    off = np.array([L[i] - onto(L[i]) for i in range(len(L))])
    small = len(L) < 12
    K = 1 if small else 8
    rings = [loop]
    share = {}
    for k in range(1, K):
        t = k / K
        row = []
        for i in range(len(L)):
            p = c + (L[i] - c) * (1.0 - t)
            v = bm.verts.new(onto(p) + off[i] * (1.0 - t) ** 2)
            share[v] = off[i] * (1.0 - t) ** 2
            row.append(v)
        rings.append(row)
    # (A sliver is closed flat, on its edge's middle.)
    centre = bm.verts.new(c if small else onto(c))
    share[centre] = c - onto(c) if small else np.zeros(3)
    inner = [v for r in rings[1:] for v in r] + [centre]
    for v in inner:
        v[lay] = 0
    made = []
    for k in range(K - 1):
        a_r, b_r = rings[k], rings[k + 1]
        n = len(a_r)
        for i in range(n):
            made.append([a_r[i], a_r[(i + 1) % n], b_r[(i + 1) % n], b_r[i]])
    n = len(rings[-1])
    for i in range(n):
        made.append([rings[-1][i], rings[-1][(i + 1) % n], centre])
    faces = []
    for vs in made:
        try:
            faces.append(bm.faces.new(vs))
        except ValueError:
            pass
    # Relaxed: each inner vertex toward the middle of its neighbours, kept on the
    # ellipsoid (plus its ring's share of the edge's offset).
    for it in range(0 if small else 12):
        new = {}
        for v in inner:
            nb = [e.other_vert(v) for e in v.link_edges]
            if nb:
                new[v] = np.mean([np.array(tuple(u.co)) for u in nb], axis=0)
        for v, p in new.items():
            q = onto(p) + share[v]
            v.co = mathutils.Vector(tuple(np.array(tuple(v.co)) * 0.5 + q * 0.5))
    # Facing out of the head; planar UVs.
    out_dir = c - c0
    nrm = np.cross(L[len(L) // 3] - L[0], L[2 * len(L) // 3] - L[0])
    nrm /= max(np.linalg.norm(nrm), 1e-9)
    e1 = np.array([0.0, 1.0, 0.0]) - nrm * nrm[1]
    e1 /= max(np.linalg.norm(e1), 1e-9)
    e2 = np.cross(nrm, e1)
    ext = max(np.abs((L - c) @ e1).max(), np.abs((L - c) @ e2).max(), 1e-6)
    r = PATCH_UV
    flip = None
    for f in faces:
        f.normal_update()
        if flip is None:
            flip = np.dot(np.array(tuple(f.normal)), out_dir) < 0
        if flip:
            f.normal_flip()
        f.smooth = True
        for lp in f.loops:
            d = np.array(tuple(lp.vert.co)) - c
            lp[uv_layer].uv = (r[0] + (0.5 + 0.5 * float(d @ e1) / ext) * (r[2] - r[0]),
                               r[1] + (0.5 + 0.5 * float(d @ e2) / ext) * (r[3] - r[1]))


def patch_holes(obj, part, flap):
    """The flaps and their linings cut away. Each flap was the skin of the side of the
    head under it, so a hole is left there; it is closed (fill_hole) on an ellipsoid
    fitted to the head about the holes, so the patch bulges as the head does. Returns
    the parts per vertex of the new mesh."""
    me = obj.data
    co = D.vertices(obj)
    cut = (flap > 0) | (part > 0)
    # The ellipsoid: the skull's vertices round both holes (mirrored onto one side).
    ring_pts = co[(~cut) & (part == 0) & (co[:, 1] > 9.0) & (co[:, 1] < 16.5) & (co[:, 2] > 16.0) & (co[:, 2] < 25.0)
                  & (np.abs(co[:, 0]) > 0.8)]
    P = np.abs(ring_pts) * np.array([1.0, 0.0, 0.0]) + ring_pts * np.array([0.0, 1.0, 1.0])
    A = np.stack([2 * P[:, 1], 2 * P[:, 2], np.ones(len(P))], axis=1)
    sol, *_ = np.linalg.lstsq(A, (P ** 2).sum(1), rcond=None)
    c0 = np.array([0.0, sol[0], sol[1]])
    dq = P - c0
    abc, *_ = np.linalg.lstsq(dq ** 2, np.ones(len(P)), rcond=None)
    abc = np.maximum(abc, 1e-4)
    print("head ellipsoid at %s, semi-axes %s" % (c0.round(2), (1.0 / np.sqrt(abc)).round(2)))

    def onto(p):
        v = p - c0
        k = math.sqrt(float((v * v) @ abc))
        return c0 + v / max(k, 1e-6)
    bm = bmesh.new()
    bm.from_mesh(me)
    lay = bm.verts.layers.int.new("part")
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        v[lay] = int(part[v.index])
    uv_layer = bm.loops.layers.uv.active
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if cut[v.index]], context="VERTS")
    for side in (-1.0, 1.0):
        # The holes' edges: boundary edges in the ear's region on this side, each walked
        # round from a vertex to its nearest unvisited neighbour (the big hole, and a
        # sliver or two by it).
        edges = [e for e in bm.edges if e.is_boundary and all(
            v.co.x * side > 0.8 and 9.0 < v.co.y < 17.0 and 15.5 < v.co.z < 25.0 for v in e.verts)]
        nbr = {}
        for e in edges:
            a, b = e.verts
            nbr.setdefault(a, []).append(b)
            nbr.setdefault(b, []).append(a)
        seen = set()
        loops = []
        for start in sorted(nbr, key=lambda v: -v.co.z):
            if start in seen:
                continue
            walk = [start]
            seen.add(start)
            cur = start
            while True:
                nxt = [v for v in nbr[cur] if v not in seen]
                if not nxt:
                    break
                cur = min(nxt, key=lambda v: (v.co - cur.co).length)
                seen.add(cur)
                walk.append(cur)
            if len(walk) >= 3:
                loops.append(walk)
        print("hole %+d: %d edges, loops %s" % (side, len(edges), [len(w) for w in loops]))
        for w in loops:
            if len(w) < 12:
                print("  sliver", [tuple(round(x, 2) for x in v.co) for v in w])
        for loop in loops:
            fill_hole(bm, loop, lay, uv_layer, onto, c0)
    bm.verts.ensure_lookup_table()
    new_part = np.array([v[lay] for v in bm.verts], dtype=np.int64)
    bm.to_mesh(me)
    bm.free()
    return new_part


# --- The new ears ---------------------------------------------------------------------------------

def ear_basis(side):
    """The ear's frame (source units): across (outward), back (out of its convex back) and
    up, turned by EAR_YAW, EAR_ROLL and EAR_PITCH."""
    across = np.array([side, 0.0, 0.0])
    back = np.array([0.0, -1.0, 0.0])
    up = np.array([0.0, 0.0, 1.0])

    def rot(v, axis, a):
        axis = axis / np.linalg.norm(axis)
        return v * math.cos(a) + np.cross(axis, v) * math.sin(a) + axis * np.dot(axis, v) * (1 - math.cos(a))
    # The hollow turned a little toward the outside (about up), the tip out (about the
    # forward axis) and back (about the across axis).
    for axis, a in ((up, -EAR_YAW * side), (np.array([0.0, 1.0, 0.0]), EAR_ROLL * side), (np.array([1.0, 0.0, 0.0]), EAR_PITCH)):
        across, back, up = rot(across, axis, a), rot(back, axis, a), rot(up, axis, a)
    return across, back, up


def ear_point(side, u, v, face):
    """A point of the ear (source units): u up it (-0.2 sunk in the skull .. 1 the tip), v
    across it (-1 .. 1), on its front (hollow) face (0) or its back (1)."""
    across, back, up = ear_basis(side)
    root = EAR_ROOT * np.array([side, 1.0, 1.0])
    uu = max(u, 0.0)
    # Half-width: full at the root, the sides a little convex, to a point at the tip.
    w = EAR_W * (1.0 - uu) ** 0.8 * (1.0 + 0.3 * uu) + 0.015
    # The hollow: deepest in the middle, low down; the back follows it a thickness behind,
    # the two meeting at the rim.
    cup = EAR_CUP * (1.0 - v * v) * (1.0 - 0.6 * uu)
    thick = EAR_THICK * (1.0 - 0.7 * uu) * math.sqrt(max(1.0 - v * v, 0.0)) + 0.025
    depth = cup + (thick if face == 1 else 0.0)
    # The rim curls a little forward.
    depth -= 0.12 * v * v * (1.0 - uu)
    return root + across * (v * w) + up * (u * EAR_H) + back * depth


def add_ears(obj, part):
    """Appends the two new ears to the body mesh: a front and a back grid each, joined at
    the rim; the root left open inside the skull. Returns the parts per vertex and each
    new vertex's (u, v, face)."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv_layer = bm.loops.layers.uv.active
    n0 = len(bm.verts)
    us = [-0.2] + [i / (EAR_NU - 1) for i in range(EAR_NU)]
    vs = [-1.0 + 2.0 * j / (EAR_NV - 1) for j in range(EAR_NV)]
    info = []
    new_part = list(part)

    def uv_of(face, u, v):
        r = EAR_UV_FRONT if face == 0 else EAR_UV_BACK
        return (r[0] + (v * 0.5 + 0.5) * (r[2] - r[0]), r[1] + (u + 0.2) / 1.2 * (r[3] - r[1]))
    for side, pid in ((-1.0, EAR_L), (1.0, EAR_R)):
        grid = {}
        for face in (0, 1):
            for i, u in enumerate(us):
                for j, v in enumerate(vs):
                    grid[(face, i, j)] = bm.verts.new(ear_point(side, u, v, face))
                    info.append((u, v, face))
                    new_part.append(pid)
        bm.verts.ensure_lookup_table()

        def quad(a, b, c, d, uvs):
            # Wound so the face looks out of the ear (front faces forward, back backward):
            # the order is flipped for the left ear, which mirrors the right.
            vv = [a, b, c, d] if side > 0 else [d, c, b, a]
            uu = uvs if side > 0 else uvs[::-1]
            f = bm.faces.new(vv)
            f.smooth = True
            for loop, t in zip(f.loops, uu):
                loop[uv_layer].uv = t
        for face in (0, 1):
            for i in range(len(us) - 1):
                for j in range(len(vs) - 1):
                    a, b = grid[(face, i, j)], grid[(face, i, j + 1)]
                    c, d = grid[(face, i + 1, j + 1)], grid[(face, i + 1, j)]
                    uvs = [uv_of(face, us[i], vs[j]), uv_of(face, us[i], vs[j + 1]),
                           uv_of(face, us[i + 1], vs[j + 1]), uv_of(face, us[i + 1], vs[j])]
                    if face == 0:
                        quad(a, b, c, d, uvs)
                    else:
                        quad(d, c, b, a, uvs[::-1])
        # The rim: front edge to back edge at v = -1 and v = 1 (on the back's texture).
        for j, sgn in ((0, -1.0), (len(vs) - 1, 1.0)):
            for i in range(len(us) - 1):
                f0, f1 = grid[(0, i, j)], grid[(0, i + 1, j)]
                b0, b1 = grid[(1, i, j)], grid[(1, i + 1, j)]
                uvs = [uv_of(1, us[i], vs[j]), uv_of(1, us[i + 1], vs[j]), uv_of(1, us[i + 1], vs[j]), uv_of(1, us[i], vs[j])]
                if sgn > 0:
                    quad(f0, f1, b1, b0, uvs)
                else:
                    quad(b0, b1, f1, f0, uvs)
    bm.to_mesh(me)
    bm.free()
    print("ears: %d verts" % (len(me.vertices) - n0))
    return np.array(new_part, dtype=np.int64), info


# --- Eyes -------------------------------------------------------------------------------------------

def find_eyes(obj, part):
    """Where the dog's painted eyes are (source units): the middle of the vertices whose
    texture is the dark of an eye, each side; and their outward normal."""
    me = obj.data
    src = D.image_pixels("Image_0")[..., :3]
    size = src.shape[0]
    L = src @ np.array([0.299, 0.587, 0.114])
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    lv = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", lv)
    px = np.clip((uv * size).astype(int), 0, size - 1)
    dark = np.zeros(len(me.vertices))
    np.maximum.at(dark, lv, (L[px[:, 1], px[:, 0]] < 0.16).astype(float))
    co = D.vertices(obj)
    nrm = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", nrm)
    nrm = nrm.reshape(-1, 3)
    out = []
    for side in (-1.0, 1.0):
        m = (dark > 0.5) & (part == 0) & (co[:, 1] > 13.0) & (co[:, 1] < 17.6) & (co[:, 2] > 19.0) & (co[:, 2] < 22.5) \
            & (co[:, 0] * side > 0.5)
        c = co[m].mean(0)
        n = nrm[m].mean(0)
        n /= np.linalg.norm(n)
        print("eye %+d: %d verts at %s, normal %s, spread %s" % (side, m.sum(), c.round(2), n.round(2), np.ptp(co[m], 0).round(2)))
        out.append((c, n))
    return out


def build_eyes(obj, part, eyes):
    """The eyes: the head's faces over each painted eye (an oval about its middle) taken
    as a mesh of their own a hair's breadth out (source units). UV is the head's; UV2 the
    spot in the eye's oval (-1 .. 1 along the head and up), which the eye shader paints."""
    me = obj.data
    co = D.vertices(obj)
    nrm = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", nrm)
    nrm = nrm.reshape(-1, 3)
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    bm = bmesh.new()
    uv1 = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("EyeUV")
    for c, n in eyes:
        h = np.array([0.0, 1.0, 0.0]) - n * n[1]
        h /= np.linalg.norm(h)
        v = np.cross(n, h)
        if v[2] < 0:
            v = -v
        vmap = {}
        for p in me.polygons:
            vs = list(p.vertices)
            if any(part[i] != 0 for i in vs):
                continue
            m = co[vs].mean(0)
            d = m - c
            if abs(np.dot(d, n)) > 0.6:
                continue
            if (np.dot(d, h) / EYE_A) ** 2 + (np.dot(d, v) / EYE_B) ** 2 > 1.0:
                continue
            bv = []
            for i in vs:
                if i not in vmap:
                    vmap[i] = bm.verts.new(co[i] + nrm[i] * EYE_OUT)
                bv.append(vmap[i])
            try:
                f = bm.faces.new(bv)
            except ValueError:
                continue
            f.smooth = True
            for loop, li, i in zip(f.loops, p.loop_indices, vs):
                loop[uv1].uv = tuple(uv[li])
                d = co[i] - c
                loop[uv2].uv = (float(np.dot(d, h) / EYE_A), float(np.dot(d, v) / EYE_B))
        print("eye: %d faces" % len(vmap))
    eme = bpy.data.meshes.new("Eyes")
    bm.to_mesh(eme)
    bm.free()
    eobj = bpy.data.objects.new("Eyes", eme)
    bpy.context.scene.collection.objects.link(eobj)
    mat = bpy.data.materials.new("wolf_eye")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.32, 0.06, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.1
    eme.materials.append(mat)
    return eobj


# --- Shape -------------------------------------------------------------------------------------

def grow(P, part=None):
    """The puppy made a wolf (source units, facing +Y)."""
    P = np.array(P, dtype=np.float64).reshape(-1, 3)
    n = len(P)
    part = np.zeros(n, dtype=np.int64) if part is None else np.asarray(part)
    body = part == 0
    Q = P.copy()
    # Lower legs slimmer: drawn in toward their bones below the elbows and stifles.
    for side in (-1.0, 1.0):
        for chain, top in ((FORE_CHAIN, 6.8), (HIND_CHAIN, 7.6)):
            pts = [np.array(c) * np.array([side, 1.0, 1.0]) for c in chain]
            m = body & (Q[:, 0] * side > 0.9) & (Q[:, 2] < top + 1.0)
            if chain is FORE_CHAIN:
                m &= Q[:, 1] > 3.0
            else:
                m &= Q[:, 1] < -5.0
            idx = np.nonzero(m)[0]
            if len(idx) == 0:
                continue
            V = Q[idx]
            best = np.full(len(V), 1e9)
            near = V.copy()
            for a, b in zip(pts[:-1], pts[1:]):
                ab = b - a
                t = np.clip(((V - a) @ ab) / (ab @ ab), 0.0, 1.0)
                c = a + t[:, None] * ab
                d = np.linalg.norm(V - c, axis=1)
                closer = d < best
                best = np.where(closer, d, best)
                near[closer] = c[closer]
            k = 1.0 - (1.0 - LEG_SLIM) * smoothstep(top, top - 1.4, V[:, 2]) * smoothstep(0.9, 1.9, V[:, 2])
            k = np.where(best < 2.4, k, 1.0)
            Q[idx] = near + (V - near) * k[:, None]
    # Paws: bigger about the middle of each (below the pastern).
    for fx, fy in ((-1, 6.9), (1, 6.9), (-1, -10.0), (1, -10.0)):
        c = np.array([fx * (2.55 if fy > 0 else 1.9), fy + (0.6 if fy > 0 else 1.0), 0.0])
        near = body & (Q[:, 0] * fx > 0.6) & (np.abs(Q[:, 1] - c[1]) < 3.2)
        w = smoothstep(2.6, 1.2, Q[:, 2]) * near
        Q[:, 0] = Q[:, 0] + (Q[:, 0] - c[0]) * (PAW_GROW - 1.0) * w
        Q[:, 1] = Q[:, 1] + (Q[:, 1] - c[1]) * (PAW_GROW - 1.0) * w
        Q[:, 2] = Q[:, 2] + Q[:, 2] * (PAW_GROW - 1.0) * 0.5 * w
    # Tail: carried out along its axis.
    d, length = D.tail_frame()
    rel = Q - D.TAIL_BASE
    t = rel @ d
    radial = np.linalg.norm(rel - t[:, None] * d, axis=1)
    near = (t > -0.3) & (radial < 2.4) & body & (Q[:, 1] < -10.4)
    w = smoothstep(0.0, 1.2, t) * near
    Q = Q + (d[None, :] * (np.maximum(t, 0.0) * (TAIL_GROW - 1.0) * w)[:, None])
    # The head a little bigger about the top of the neck (the new ears with it).
    hw_ = smoothstep(HEAD_BLEND[0], HEAD_BLEND[1], Q[:, 1]) * body + (part >= EAR_L)
    hs = 1.0 + (HEAD_SCALE - 1.0) * np.clip(hw_, 0.0, 1.0)
    Q = HEAD_PIVOT + (Q - HEAD_PIVOT) * hs[:, None]
    # The forehead's step eased: the bridge of the nose raised just ahead of the eyes.
    x, y, z = Q[:, 0], Q[:, 1], Q[:, 2]
    bridge = smoothstep(14.0, 15.3, y) * smoothstep(18.5, 16.5, y) * smoothstep(20.5, 22.5, z) * body
    Q[:, 2] = z + 0.45 * bridge
    # Muzzle: drawn out ahead of the stop, narrower, and the lips taken up.
    x, y, z = Q[:, 0], Q[:, 1], Q[:, 2]
    hw = smoothstep(STOP_Y - 1.2, STOP_Y + 0.8, y) * smoothstep(14.5, 16.5, z) * body
    ahead = np.maximum(y - (STOP_Y - 1.2), 0.0)
    Q[:, 1] = y + ahead * MUZZLE_GROW * hw
    taper = smoothstep(STOP_Y, 20.0, Q[:, 1]) * hw
    Q[:, 0] = x * (1.0 - 0.16 * taper)
    lips = smoothstep(19.5, 17.8, z) * smoothstep(14.5, 16.5, y) * body
    Q[:, 2] = Q[:, 2] + (20.0 - Q[:, 2]) * (0.1 * taper + 0.12 * lips * smoothstep(16.2, 17.0, z))
    # The nose a little smaller (a Labrador's is big).
    nose = smoothstep(18.6, 19.6, P[:, 1]) * smoothstep(19.0, 19.8, P[:, 2]) * body
    nc = np.array([0.0, Q[:, 1].max() if len(Q) > 50 else 0.0, 20.35])
    tip_y = 20.05 + (20.05 - (STOP_Y - 1.2)) * MUZZLE_GROW
    Q[:, 0] = Q[:, 0] * (1.0 - 0.18 * nose)
    Q[:, 2] = Q[:, 2] + (20.35 - Q[:, 2]) * 0.15 * nose
    Q[:, 1] = Q[:, 1] + (tip_y - Q[:, 1]) * 0.1 * nose
    # The skull a little narrower (and the new ears with it).
    skull = smoothstep(9.5, 11.5, Q[:, 1]) * smoothstep(15.0, 18.0, Q[:, 2]) * ((part == 0) | (part >= EAR_L))
    Q[:, 0] = Q[:, 0] * (1.0 - 0.05 * skull)
    # The neck drawn out: the head and the top of the neck forward of the shoulders.
    y, z = Q[:, 1], Q[:, 2]
    up = smoothstep(13.0, 16.0, z) * ((part == 0) | (part >= EAR_L))
    Q[:, 1] = y + NECK_GROW * np.clip(y - NECK_SPAN[0], 0.0, NECK_SPAN[1] - NECK_SPAN[0]) * up
    # Belly tucked up behind the ribs.
    y, z = Q[:, 1], Q[:, 2]
    tuck = TUCK * smoothstep(-7.8, -4.5, y) * smoothstep(2.0, -1.0, y) * smoothstep(12.5, 7.5, z) * (z > 5.5) * body
    Q[:, 2] = z + tuck
    # Body lengthened between the shoulders and the loins (the front half moves forward).
    y = Q[:, 1]
    Q[:, 1] = y + BODY_GROW * np.clip(y - BODY_SPAN[0], 0.0, BODY_SPAN[1] - BODY_SPAN[0])
    # Narrower all over (a narrow chest, the legs in under it); the ears keep their width.
    ears = part >= EAR_L
    Q[:, 0] = np.where(ears, Q[:, 0] - np.sign(Q[:, 0]) * 0.0, Q[:, 0] * NARROW)
    if ears.any():
        # The ears' roots move in with the skull, the ears themselves keep their size.
        for pid, side in ((EAR_L, -1.0), (EAR_R, 1.0)):
            m = part == pid
            Q[m, 0] = Q[m, 0] - side * EAR_ROOT[0] * (1.0 - NARROW * 0.95)
    # Legs: the span between the paws and the elbows/stifles stretched.
    z = Q[:, 2]
    Q[:, 2] = z + LEG_GROW * np.clip(z - LEG_SPAN[0], 0.0, LEG_SPAN[1] - LEG_SPAN[0])
    return Q


## The finished wolf: metres, on z = 0, centred between its feet.
SCALE = WITHERS / (SRC_WITHERS + LEG_GROW * (LEG_SPAN[1] - LEG_SPAN[0]))
CENTRE = None


def centre():
    paws = grow(np.array([[0.0, 6.9, 0.85], [0.0, -10.0, 0.95]]))
    return np.array([0.0, (paws[0, 1] + paws[1, 1]) * 0.5, -0.12])


def to_metres(P):
    return (np.asarray(P, dtype=np.float64) - CENTRE) * SCALE


def shape(P, part=None):
    return to_metres(grow(P, part))


# --- Skeleton and skin ----------------------------------------------------------------------------

def bone_specs(co, part):
    """The dog's bones (source units) with the ears' moved onto the new ears: (name,
    head, tail, parent, part the points belong to)."""
    out = []
    # (The dog's ear linings are gone: stand-in points for its ear chains, replaced below.)
    dummy = np.array([[-2.5, 13.0, 22.0], [-2.6, 13.0, 20.0], [-2.7, 13.0, 18.0],
                      [2.5, 13.0, 22.0], [2.6, 13.0, 20.0], [2.7, 13.0, 18.0]])
    co = np.vstack([co, dummy])
    part = np.concatenate([part, [1, 1, 1, 2, 2, 2]])
    for name, head, tail, parent in D.bone_specs(co, part):
        which = 0
        if name.startswith("ear_"):
            side = -1.0 if name[4] == "l" else 1.0
            which = EAR_L if side < 0 else EAR_R
            if name.endswith("2"):
                head, tail = ear_point(side, 0.45, 0.0, 0), ear_point(side, 1.0, 0.0, 0)
            else:
                head, tail = ear_point(side, 0.0, 0.0, 0), ear_point(side, 0.45, 0.0, 0)
            # (The ear bones sit in the ear's middle, between its faces.)
            _, back, _ = ear_basis(side)
            head = np.asarray(head) + back * EAR_THICK * 0.5
            tail = np.asarray(tail) + back * EAR_THICK * 0.3
        out.append((name, tuple(head), tuple(tail), parent, which))
    return out


def build_armature(specs):
    arm_data = bpy.data.armatures.new("Skeleton")
    arm = bpy.data.objects.new("Skeleton", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for name, head, tail, parent, which in specs:
        b = eb.new(name)
        part = np.array([which])
        b.head = tuple(shape(head, part)[0])
        b.tail = tuple(shape(tail, part)[0])
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin(co, part, specs, adjacency, info):
    """The dog's weights for the body (the flaps on the head, the sunk linings wholly on
    it), the new ears on the head at the root and their two bones up them."""
    names = [s[0] for s in specs]
    n_old = int(np.count_nonzero(part < EAR_L))
    W = np.zeros((len(part), len(names)))
    adj = adjacency[(adjacency < n_old).all(1)]
    W[:n_old] = D.skin_weights(co[:n_old], part[:n_old], [s[:4] for s in specs], adj)
    head = names.index("head")
    W[(part == 1) | (part == 2)] = 0.0
    W[(part == 1) | (part == 2), head] = 1.0
    for k, (u, v, face) in enumerate(info):
        i = n_old + k
        side = "l" if part[i] == EAR_L else "r"
        i1, i2 = names.index("ear_" + side), names.index("ear_%s2" % side)
        W[i] = 0.0
        hb = float(smoothstep(0.1, -0.05, u))
        t2 = float(smoothstep(0.3, 0.6, u))
        W[i, head] = hb
        W[i, i1] = (1 - hb) * (1 - t2)
        W[i, i2] = (1 - hb) * t2
    return W


def flip_faces(obj, mask):
    """Faces whose vertices are all in `mask` turned the other way."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    faces = [f for f in bm.faces if all(mask[v.index] for v in f.verts)]
    bmesh.ops.reverse_faces(bm, faces=faces)
    bm.to_mesh(me)
    bm.free()


# --- Coat ------------------------------------------------------------------------------------------

C = D.C


def mix(col, target, w):
    w = np.asarray(w)[..., None]
    return col * (1 - w) + target * w


def value_noise(P, scale, seed):
    """Smooth 3D value noise (0..1) at points P (..., 3)."""
    rng = np.random.default_rng(seed)
    g = rng.random((32, 32, 32))
    q = P * scale
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * (f[..., 2] if dz else 1 - f[..., 2])
                out = out + w * g[(i[..., 0] + dx) % 32, (i[..., 1] + dy) % 32, (i[..., 2] + dz) % 32]
    return out


def coat_colour(P):
    """The grey wolf's coat by where a texel is on the body (source units, facing +Y,
    before reshaping; sRGB): a grizzled grey with a dark saddle, countershaded cream
    below, tawny legs, the face's pattern."""
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    ax = np.abs(x)
    # Flanks: grizzled grey with a little buff.
    col = np.broadcast_to(C(0.45, 0.42, 0.375), P.shape).copy()
    # Legs: tawny outside, paling to cream at the paws.
    legs = smoothstep(9.0, 6.0, z)
    col = mix(col, C(0.6, 0.5, 0.38), legs)
    col = mix(col, C(0.74, 0.68, 0.58), smoothstep(4.0, 1.5, z))
    # The saddle: dark, black-tipped hair from the top of the neck over the shoulders,
    # the back and the rump to the tail; it shades off down the sides.
    saddle = smoothstep(11.5, 16.0, z) * smoothstep(3.2, 1.2, ax) * smoothstep(11.0, 8.5, y) * (y > -12.0)
    saddle = np.maximum(saddle, smoothstep(13.5, 17.0, z) * smoothstep(11.0, 8.5, y) * (y > -12.0) * 0.7)
    col = mix(col, C(0.2, 0.185, 0.17), 0.85 * saddle)
    neck_top = smoothstep(15.5, 19.5, z) * smoothstep(5.0, 7.0, y) * smoothstep(11.5, 10.0, y) * smoothstep(2.8, 1.0, ax)
    col = mix(col, C(0.26, 0.24, 0.22), 0.7 * neck_top)
    # Underside, countershaded: chest, belly, the inside of the legs, the throat; cream.
    under = smoothstep(10.0, 7.8, z) * smoothstep(-9.5, -6.5, y) * smoothstep(3.0, 1.7, ax)
    chest = smoothstep(5.5, 8.0, y) * smoothstep(15.0, 12.0, z) * smoothstep(3.0, 1.6, ax)
    throat = smoothstep(7.0, 9.5, y) * smoothstep(17.5, 15.0, z)
    inner = smoothstep(9.5, 4.0, z) * smoothstep(1.9, 1.3, ax) * 0.8
    ttail = smoothstep(-11.0, -13.0, y) * smoothstep(0.2, -0.6, z - (17.0 + (-11.0 - y) * 0.9))
    cream = np.clip(np.maximum.reduce([under, chest, throat, inner, ttail * 0.7]), 0, 1)
    col = mix(col, C(0.82, 0.78, 0.7), cream)
    # The dark line down the front of the forelegs (elbow to wrist).
    fore = smoothstep(9.0, 7.0, z) * smoothstep(2.5, 3.5, z) * smoothstep(4.5, 6.0, y) * smoothstep(1.4, 2.2, ax)
    front = smoothstep(6.4, 7.4, y)
    col = mix(col, C(0.24, 0.2, 0.17), 0.75 * fore * front)
    # Head: a grizzled grey crown, a tawny bridge and forehead, a dark spot over each eye
    # with a pale brow above it, black rims round the eyes; the whole lower face (lips,
    # chin, cheeks back to the ruff) white-cream.
    head = smoothstep(10.0, 12.0, y) * smoothstep(17.0, 19.0, z)
    col = mix(col, C(0.46, 0.42, 0.36), head)
    crown = smoothstep(11.0, 12.5, y) * smoothstep(22.0, 23.6, z)
    col = mix(col, C(0.3, 0.28, 0.25), 0.6 * crown)
    bridge = smoothstep(15.5, 17.5, y) * smoothstep(20.6, 21.6, z)
    col = mix(col, C(0.55, 0.46, 0.35), 0.75 * bridge)
    lower = smoothstep(11.0, 13.0, y) * smoothstep(20.8, 19.6, z)
    col = mix(col, C(0.86, 0.83, 0.77), np.clip(lower, 0, 1))
    eye = np.array([1.67, 17.02, 21.71])
    de = np.sqrt(((ax - eye[0]) * 1.4) ** 2 + (y - eye[1]) ** 2 + ((z - eye[2]) * 1.3) ** 2)
    brow = smoothstep(0.9, 0.4, np.sqrt(((ax - 1.6) * 1.4) ** 2 + (y - 16.4) ** 2 + ((z - 22.7) * 1.6) ** 2))
    col = mix(col, C(0.8, 0.76, 0.68), 0.8 * brow)
    col = mix(col, C(0.1, 0.09, 0.085), smoothstep(1.0, 0.55, de) * 0.85)
    # Tail: dark grey on top, paler beneath, the last part black.
    d, length = D.tail_frame()
    t = (P - D.TAIL_BASE) @ d
    tail = smoothstep(-0.3, 0.6, t) * (y < -10.4)
    col = mix(col, C(0.3, 0.28, 0.26), 0.6 * tail)
    col = mix(col, C(0.06, 0.055, 0.05), tail * smoothstep(length * 0.72, length * 0.9, t))
    return col


def ear_colour(face, u, v):
    """The new ears' coat (sRGB) by where a texel is on them: the hollow pale with long
    light hair over a darker skin low down, the back tawny with dark rims and tip."""
    if face == 0:
        col = C(0.66, 0.62, 0.55) * (0.65 + 0.35 * smoothstep(0.0, 0.5, u))[..., None]
        rim = smoothstep(0.78, 0.98, np.abs(v))
        return col * (1 - rim)[..., None] + C(0.16, 0.14, 0.13) * rim[..., None]
    col = np.broadcast_to(C(0.45, 0.36, 0.27), u.shape + (3,))
    rim = np.maximum(smoothstep(0.7, 0.95, np.abs(v)), smoothstep(0.7, 0.95, u))
    col = col * (1 - rim)[..., None] + C(0.08, 0.07, 0.065) * rim[..., None]
    root = smoothstep(0.25, -0.1, u)
    return col * (1 - root)[..., None] + C(0.3, 0.27, 0.24) * root[..., None]


def coat_maps(obj, part):
    """Albedo, normal and roughness maps: the dog's painted hair recoloured to a grey wolf,
    the new ears painted in their own corner (the hair detail borrowed from the flank)."""
    src = D.image_pixels("Image_0")[..., :3]
    size = src.shape[0]
    pos = D.bake_position(obj, size)
    has = ~np.isnan(pos[..., 0])
    island = src.max(-1) > 0.02
    L = src @ np.array([0.299, 0.587, 0.114])
    Lb = D.masked_blur(L, island, 6)
    detail = np.clip(L / np.maximum(Lb, 0.05), 0.55, 1.6)
    detail = np.where(island, detail, 1.0)
    Lbb = D.masked_blur(L, island, 24)
    broad = np.clip(Lbb / np.mean(Lbb[island & has]), 0.75, 1.2)
    # The ears' corner: hair detail from a patch of the flank (rows/cols in pixels).
    def rect_px(r):
        return int(r[1] * size), int(r[3] * size), int(r[0] * size), int(r[2] * size)
    patch_r0, patch_c0 = 457, 450
    # (The head's patches too: a flank patch turned to lie along them.)
    for face, r in ((0, EAR_UV_FRONT), (1, EAR_UV_BACK), (2, PATCH_UV)):
        r0, r1, c0, c1 = rect_px(r)
        h, w = r1 - r0, c1 - c0
        src_patch = detail[patch_r0:patch_r0 + max(h, w), patch_c0:patch_c0 + max(h, w)]
        if face == 2:
            src_patch = src_patch.T[::-1]
        detail[r0:r1, c0:c1] = src_patch[:h, :w]
        island[r0:r1, c0:c1] = True
        broad[r0:r1, c0:c1] = 1.0
    P = np.where(has[..., None], pos, 0.0)
    # Grizzle: blotches of darker and lighter hair at a few scales (agouti banding).
    blot = value_noise(P, 0.9, 7) * 0.6 + value_noise(P, 2.3, 11) * 0.4
    col = coat_colour(P)
    col = col * (0.82 + 0.36 * blot)[..., None]
    col = col * (detail ** 1.25)[..., None] * (0.8 + 0.2 * broad)[..., None] * 0.9
    # Features kept from the source: the black nose, lips and pads (not in the corners
    # painted here, where the source has nothing).
    y, z, ax = P[..., 1], P[..., 2], np.abs(P[..., 0])
    face = smoothstep(14.5, 15.5, y)
    feet = smoothstep(1.6, 0.9, z)
    painted = src.max(-1) > 0.02
    dark = smoothstep(0.26, 0.12, L) * np.maximum(face, feet) * painted
    lipline = face * smoothstep(0.35, 0.18, L) * smoothstep(19.6, 18.6, z) * painted
    keep = np.clip(np.maximum(dark, lipline * 0.85), 0, 1)
    col = col * (1 - keep[..., None]) + (src * 0.6) * keep[..., None]
    # Paint the ears' corner.
    for face_id, r in ((0, EAR_UV_FRONT), (1, EAR_UV_BACK)):
        r0, r1, c0, c1 = rect_px(r)
        rows = (np.arange(r0, r1) + 0.5) / size
        cols = (np.arange(c0, c1) + 0.5) / size
        vv = ((cols - r[0]) / (r[2] - r[0]) - 0.5) * 2.0
        uu = (rows - r[1]) / (r[3] - r[1]) * 1.2 - 0.2
        U, V = np.meshgrid(uu, vv, indexing="ij")
        ec = ear_colour(face_id, U, V)
        col[r0:r1, c0:c1] = ec * (detail[r0:r1, c0:c1] ** 1.1)[..., None]
        has[r0:r1, c0:c1] = True
    col = np.clip(col, 0, 1)
    col[~has] = C(0.34, 0.31, 0.27)
    # Normal map: the hair strokes as a height field.
    hgt = D.blur(np.where(island, np.log(np.maximum(detail, 0.05)), 0.0), 1)
    gy, gx = np.gradient(hgt)
    strength = 2.6
    nx, ny = -gx * strength, -gy * strength
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)
    # Roughness: hair, a wet nose, glossy lips.
    nose = dark * smoothstep(18.6, 19.4, y) * smoothstep(19.4, 20.0, z)
    rough = 0.8 + 0.12 * (1.0 - np.clip(detail - 0.6, 0, 1))
    rough = rough * (1 - nose) + 0.38 * nose
    rough = rough * (1 - lipline) + 0.5 * lipline
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], axis=-1)
    os.makedirs(TEX_DIR, exist_ok=True)
    a = D.save_png(col, os.path.join(TEX_DIR, "wolf_albedo.png"))
    nm = D.save_png(nrm, os.path.join(TEX_DIR, "wolf_normal.png"), non_color=True)
    r = D.save_png(orm, os.path.join(TEX_DIR, "wolf_orm.png"), non_color=True)
    return a, nm, r, dark


def material(albedo, normal, orm, name):
    m = D.material(albedo, normal, orm)
    m.name = name
    return m


# --- Shell fur ---------------------------------------------------------------------------------------

def fur_length(P, part):
    """Fur length (m) by where a vertex is (source units, before reshaping): a thick winter
    coat over the body, a heavy ruff round the neck, cheeks and shoulders, breeches on
    the thighs, a bushy tail; short on the face and legs, none on the muzzle, nose, paws
    and round the eyes."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    L = np.full(len(P), 0.034)
    # The back and the shoulders heavier.
    back = smoothstep(12.0, 16.0, z) * smoothstep(-11.0, -8.0, y)
    L = np.maximum(L, 0.044 * back)
    # The ruff: the neck all round, the cheeks behind the eyes, the shoulders.
    ruff = smoothstep(4.0, 7.0, y) * smoothstep(12.8, 10.8, y) * smoothstep(8.5, 11.5, z)
    ruff = ruff * (1.0 - smoothstep(10.0, 11.5, y) * smoothstep(17.5, 15.5, z))
    L = np.maximum(L, 0.062 * ruff)
    cheek = smoothstep(10.0, 11.5, y) * smoothstep(14.8, 13.4, y) * smoothstep(21.0, 19.0, z) * smoothstep(1.4, 2.5, ax)
    L = np.maximum(L, 0.04 * cheek)
    # Head short, the muzzle bare.
    head = smoothstep(11.8, 13.2, y) * smoothstep(16.0, 18.0, z)
    jaw = smoothstep(11.0, 12.5, y) * smoothstep(15.0, 16.5, z)
    head = np.maximum(head, jaw)
    L = L * (1 - head) + 0.009 * head
    muzzle = smoothstep(14.8, 15.8, y)
    L = L * (1 - muzzle) + 0.003 * muzzle
    L = L * (1 - smoothstep(18.0, 19.0, y) * smoothstep(19.0, 20.0, z))
    # Belly and chest a little shorter, the legs close, the paws bare.
    belly = smoothstep(9.5, 7.5, z) * smoothstep(-8.0, -6.0, y) * smoothstep(5.0, 3.0, y)
    L = L * (1 - belly) + 0.024 * belly
    legs = smoothstep(7.0, 4.0, z)
    L = L * (1 - legs) + 0.008 * legs
    paws = smoothstep(1.8, 0.9, z)
    L = L * (1 - paws)
    # Breeches on the backs of the thighs, feathering behind the forelegs.
    breeches = smoothstep(-8.5, -11.0, y) * smoothstep(5.0, 8.0, z) * smoothstep(14.5, 11.0, z)
    L = np.maximum(L, 0.048 * breeches)
    fore_back = smoothstep(4.0, 6.5, z) * smoothstep(8.5, 7.0, z) * smoothstep(5.8, 4.8, y) * smoothstep(3.2, 6.0, y)
    L = np.maximum(L, 0.02 * fore_back)
    # Tail: bushy, thickest along its middle.
    d, length = D.tail_frame()
    t = (P - D.TAIL_BASE) @ d
    tail = smoothstep(-0.5, 0.5, t) * (y < -10.4)
    L = L * (1 - tail) + 0.066 * tail * (0.7 + 0.3 * np.sin(np.clip(t / length, 0, 1) * math.pi))
    # None over the eyes and close round them (the eyes' own mesh shows there).
    for side in (-1.0, 1.0):
        e = EYE_CENTRE * np.array([side, 1.0, 1.0])
        d = np.sqrt(((x - e[0]) * 1.2) ** 2 + (y - e[1]) ** 2 + ((z - e[2]) * 1.2) ** 2)
        L = L * smoothstep(0.75, 1.3, d)
    L[(part == 1) | (part == 2)] = 0.0
    return L


def build_fur(body, part, dark_v, ear_face):
    """FUR_LAYERS copies of a lighter body; UV2 = (layer / FUR_LAYERS, length / FUR_MAX).
    The source position rides along through the decimation for the fur's length."""
    src = body.copy()
    src.data = body.data.copy()
    src.modifiers.clear()
    bpy.context.scene.collection.objects.link(src)
    me = src.data
    a = me.attributes.new("fur_info", "FLOAT_COLOR", "POINT")
    info = np.zeros((len(me.vertices), 4))
    info[:, 0] = part / 4.0
    info[:, 1] = dark_v
    info[:, 2] = ear_face
    a.data.foreach_set("color", info.astype(np.float32).ravel())
    sp = me.attributes.new("src_pos", "FLOAT_COLOR", "POINT")
    spos = np.zeros((len(me.vertices), 4))
    spos[:, :3] = SRC_CO
    sp.data.foreach_set("color", spos.astype(np.float32).ravel())
    d = src.modifiers.new("decimate", "DECIMATE")
    d.ratio = min(1.0, FUR_TRIS / max(len(me.polygons), 1))
    d.use_collapse_triangulate = True
    D.apply_modifiers(src)
    me = src.data
    me.calc_loop_triangles()
    nv = len(me.vertices)
    co = D.vertices(src)
    col = np.empty(nv * 4)
    me.attributes["fur_info"].data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    sp = np.empty(nv * 4)
    me.attributes["src_pos"].data.foreach_get("color", sp)
    sp = sp.reshape(-1, 4)[:, :3]
    vpart = np.round(col[:, 0] * 4.0).astype(np.int64)
    L = fur_length(sp, vpart) * (1.0 - smoothstep(0.2, 0.6, col[:, 1]))
    # The new ears: a short coat on the back (face 1) only.
    ears = vpart >= EAR_L
    L[ears] = np.where(col[ears, 2] > 0.5, 0.006, 0.0)
    Wsrc = np.zeros((nv, len(BONE_NAMES)))
    for v in me.vertices:
        for g in v.groups:
            nm = src.vertex_groups[g.group].name
            if nm in BONE_NAMES:
                Wsrc[v.index, BONE_NAMES.index(nm)] = g.weight
    # None on the lower jaw: the mouth opens (a snarl, a howl, a bite) and fur across it
    # would stretch into streaks.
    on_jaw = Wsrc[:, BONE_NAMES.index("jaw")] > 0.02
    L[on_jaw] = 0.0
    tris = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tris)
    tris = tris.reshape(-1, 3)
    tl = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("loops", tl)
    uv_loops = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv_loops)
    uv_loops = uv_loops.reshape(-1, 2)
    keys = {}
    vmap, vuv, corner_v = [], [], []
    for t in range(len(tris)):
        for c in range(3):
            vi = int(tris[t, c])
            uv = uv_loops[tl[t * 3 + c]]
            k = (vi, round(float(uv[0]), 6), round(float(uv[1]), 6))
            if k not in keys:
                keys[k] = len(vmap)
                vmap.append(vi)
                vuv.append(uv)
            corner_v.append(keys[k])
    vmap = np.array(vmap)
    vuv = np.array(vuv)
    faces = np.array(corner_v).reshape(-1, 3)
    fl = L[vmap]
    faces = faces[(fl[faces].max(1) > 0.0015) & ~on_jaw[vmap][faces].any(1)]
    n1 = len(vmap)
    allv = np.tile(co[vmap], (FUR_LAYERS, 1))
    allf = np.concatenate([faces + n1 * k for k in range(FUR_LAYERS)])
    fur = bpy.data.meshes.new("Fur")
    fur.vertices.add(len(allv))
    fur.vertices.foreach_set("co", allv.ravel())
    fur.loops.add(allf.size)
    fur.loops.foreach_set("vertex_index", allf.ravel())
    fur.polygons.add(len(allf))
    fur.polygons.foreach_set("loop_start", np.arange(0, allf.size, 3))
    fur.polygons.foreach_set("loop_total", np.full(len(allf), 3))
    fur.update()
    loop_v = allf.ravel()
    uv1 = fur.uv_layers.new(name="UVMap")
    uv1.data.foreach_set("uv", np.tile(vuv, (FUR_LAYERS, 1))[loop_v].ravel())
    layer = np.repeat(np.arange(1, FUR_LAYERS + 1) / FUR_LAYERS, n1)
    length = np.tile(np.clip(fl / FUR_MAX, 0, 1), FUR_LAYERS)
    uv2 = fur.uv_layers.new(name="Fur")
    uv2.data.foreach_set("uv", np.stack([layer, length], axis=1)[loop_v].ravel())
    for p in fur.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("Fur", fur)
    bpy.context.scene.collection.objects.link(obj)
    D.set_weights(obj, np.tile(Wsrc[vmap], (FUR_LAYERS, 1)), BONE_NAMES)
    bpy.data.objects.remove(src)
    print("fur: %d verts per layer, %d tris per layer, %d layers" % (n1, len(faces), FUR_LAYERS))
    return obj


# --- The pelt (an item) -------------------------------------------------------------------------------

def build_pelt(albedo, normal, orm):
    """A folded wolf pelt about 40 cm across: three folds of hide stacked a little askew,
    their edges ragged, the grizzled saddle of the back on top, the bushy, black-tipped
    tail hanging off one side. Textured from the wolf's coat, with its shell fur."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    fur_layer = bm.faces.layers.float.new("fur")
    rng = np.random.default_rng(5)
    # The fur's length (m) on the faces made next.
    fur_now = [0.0]

    def face(vs, uvs):
        f = bm.faces.new(vs)
        f.smooth = True
        f[fur_layer] = fur_now[0]
        for loop, t in zip(f.loops, uvs):
            loop[uv_layer].uv = t

    def lerp_uv(r, a, b):
        return (r[0] + (r[2] - r[0]) * a, r[1] + (r[3] - r[1]) * b)

    def fold(cx, cy, cz, sx, sy, sz, yaw, uv_top, uv_side, bulge):
        """One fold: a soft slab, its top domed, its outline ragged, its edges rounded."""
        nx, ny = 12, 9
        ca, sa = math.cos(yaw), math.sin(yaw)
        wob = rng.uniform(-1.0, 1.0, 64)
        top, bot = {}, {}
        for i in range(nx + 1):
            for j in range(ny + 1):
                fx, fy = i / nx * 2 - 1, j / ny * 2 - 1
                edge = max(abs(fx), abs(fy))
                ang = math.atan2(fy, fx)
                rag = 1.0 + 0.05 * edge ** 4 * (math.sin(ang * 5 + wob[0] * 3) + 0.6 * math.sin(ang * 11 + wob[1] * 3))
                px, py = fx * sx * rag, fy * sy * rag
                lift = bulge * (1 - fx * fx) * (1 - fy * fy) + 0.004 * math.sin(fx * 7 + wob[2]) * math.sin(fy * 5)
                fall = sz * 0.55 * edge ** 5
                rx, ry = px * ca - py * sa, px * sa + py * ca
                top[(i, j)] = bm.verts.new((cx + rx, cy + ry, cz + sz + lift - fall))
                bot[(i, j)] = bm.verts.new((cx + rx * 0.96, cy + ry * 0.96, cz))
        for i in range(nx):
            for j in range(ny):
                q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                fur_now[0] = 0.03
                face([top[k] for k in q], [lerp_uv(uv_top, k[0] / nx, k[1] / ny) for k in q])
                fur_now[0] = 0.0
                face([bot[k] for k in q[::-1]], [lerp_uv(uv_side, k[0] / nx, k[1] / ny) for k in q[::-1]])
        ring = [(i, 0) for i in range(nx)] + [(nx, j) for j in range(ny)] + \
            [(i, ny) for i in range(nx, 0, -1)] + [(0, j) for j in range(ny, 0, -1)]
        fur_now[0] = 0.018
        for k in range(len(ring)):
            a, b = ring[k], ring[(k + 1) % len(ring)]
            s0, s1 = k / len(ring), (k + 1) / len(ring)
            face([top[b], top[a], bot[a], bot[b]],
                 [lerp_uv(uv_side, s1, 1.0), lerp_uv(uv_side, s0, 1.0), lerp_uv(uv_side, s0, 0.0), lerp_uv(uv_side, s1, 0.0)])

    def roll(pts, radii, uv):
        """A tapering roll of fur along `pts` (the tail, a leg's flap)."""
        segs = 10
        prev = None
        n = len(pts) - 1
        for r, c in enumerate(pts):
            tang = (pts[min(r + 1, n)] - pts[max(r - 1, 0)]).normalized()
            side = tang.cross(mathutils.Vector((0, 0, 1)))
            if side.length < 1e-4:
                side = mathutils.Vector((0, 1, 0))
            side.normalize()
            upv = side.cross(tang).normalized()
            ring = [bm.verts.new(c + (side * math.cos(2 * math.pi * s / segs) + upv * math.sin(2 * math.pi * s / segs) * 0.75)
                                 * radii[r]) for s in range(segs)]
            if prev:
                for s in range(segs):
                    q = [(s, r - 1), (s + 1, r - 1), (s + 1, r), (s, r)]
                    face([prev[s], prev[(s + 1) % segs], ring[(s + 1) % segs], ring[s]],
                         [lerp_uv(uv, a / segs, b / n) for a, b in q])
            prev = ring
    # Texture regions (atlas UV; the dog's half-body island has the back along its lower
    # edge): the saddle seen from above, the flank, the tail.
    saddle = (0.42, 0.47, 0.74, 0.56)
    flank = (0.32, 0.57, 0.66, 0.7)
    fold(0.0, 0.0, 0.0, 0.19, 0.14, 0.024, 0.0, saddle, flank, 0.012)
    fold(0.012, -0.006, 0.046, 0.18, 0.13, 0.022, 0.06, saddle, flank, 0.014)
    fold(-0.006, 0.006, 0.088, 0.17, 0.125, 0.024, -0.05, (0.44, 0.46, 0.72, 0.55), flank, 0.018)
    # The tail out of the middle fold, over the edge and down.
    tail_uv = (0.06, 0.375, 0.2, 0.47)
    pts, radii = [], []
    for r in range(13):
        t = r / 12
        ang = t * 2.0
        pts.append(mathutils.Vector((0.1 + 0.12 * math.sin(ang), 0.03 - 0.05 * t, 0.085 + 0.05 * math.cos(ang) - 0.07 * t)))
        radii.append(0.03 * (1 - 0.55 * t) + 0.005)
    fur_now[0] = 0.04
    roll(pts, radii, tail_uv)
    me = bpy.data.meshes.new("Pelt")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("Pelt", me)
    bpy.context.scene.collection.objects.link(obj)
    me.materials.append(material(albedo, normal, orm, "wolf_pelt"))
    # Its shell fur (as the wolf's: UV2 = layer, length over FUR_MAX), over every face
    # with fur, the length at a vertex the longest of its faces'.
    furs = np.empty(len(me.polygons))
    me.attributes["fur"].data.foreach_get("value", furs)
    vlen = np.zeros(len(me.vertices))
    for p in me.polygons:
        for v in p.vertices:
            vlen[v] = max(vlen[v], furs[p.index])
    me.calc_loop_triangles()
    tris = np.array([t.vertices[:] for t in me.loop_triangles])
    tloops = np.array([t.loops[:] for t in me.loop_triangles])
    tfur = np.array([furs[t.polygon_index] for t in me.loop_triangles])
    keep = tfur > 0.0
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    co = D.vertices(obj)
    keys, vmap, vuv, corner = {}, [], [], []
    for t, l in zip(tris[keep], tloops[keep]):
        for vi, li in zip(t, l):
            k = (int(vi), round(float(uv[li, 0]), 6), round(float(uv[li, 1]), 6))
            if k not in keys:
                keys[k] = len(vmap)
                vmap.append(int(vi))
                vuv.append(uv[li])
            corner.append(keys[k])
    vmap = np.array(vmap)
    vuv = np.array(vuv)
    faces = np.array(corner).reshape(-1, 3)
    n1 = len(vmap)
    allv = np.tile(co[vmap], (FUR_LAYERS, 1))
    allf = np.concatenate([faces + n1 * k for k in range(FUR_LAYERS)])
    fm = bpy.data.meshes.new("PeltFur")
    fm.vertices.add(len(allv))
    fm.vertices.foreach_set("co", allv.ravel())
    fm.loops.add(allf.size)
    fm.loops.foreach_set("vertex_index", allf.ravel())
    fm.polygons.add(len(allf))
    fm.polygons.foreach_set("loop_start", np.arange(0, allf.size, 3))
    fm.polygons.foreach_set("loop_total", np.full(len(allf), 3))
    fm.update()
    loop_v = allf.ravel()
    fm.uv_layers.new(name="UVMap").data.foreach_set("uv", np.tile(vuv, (FUR_LAYERS, 1))[loop_v].ravel())
    layer = np.repeat(np.arange(1, FUR_LAYERS + 1) / FUR_LAYERS, n1)
    length = np.tile(np.clip(vlen[vmap] / FUR_MAX, 0, 1), FUR_LAYERS)
    fm.uv_layers.new(name="Fur").data.foreach_set("uv", np.stack([layer, length], axis=1)[loop_v].ravel())
    for p in fm.polygons:
        p.use_smooth = True
    fobj = bpy.data.objects.new("PeltFur", fm)
    bpy.context.scene.collection.objects.link(fobj)
    fm.materials.append(material(albedo, normal, orm, "wolf_pelt_fur"))
    return obj, fobj


# --- Previews ------------------------------------------------------------------------------------

def previews(d, textured, arm=None, prefix="wolf"):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE" if textured else "OBJECT"
    sc.display.shading.show_xray = not textured and arm is not None
    sc.display.shading.xray_alpha = 0.35
    sc.render.resolution_x, sc.render.resolution_y = 1000, 760
    marks = D.mark_joints(arm) if arm is not None and not textured else []
    t = (0, 0.0, 0.42)
    views = {"side": (2.6, 0.0, 0.45), "front3q": (1.5, 2.0, 0.7), "back3q": (-1.3, -2.0, 0.9),
             "front": (0.0, 2.6, 0.5), "top": (0.001, 0.0, 2.8)}
    for k, p in views.items():
        sc.camera = D.cam(k, p, t, lens=50)
        sc.render.filepath = os.path.join(d, "%s_%s%s.png" % (prefix, k, "" if textured else "_shape"))
        bpy.ops.render.render(write_still=True)
    for m in marks:
        bpy.data.objects.remove(m)


def head_previews(d, textured, prefix="wolf"):
    """Close views of the head, to judge the ears, eyes and muzzle."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.show_xray = False
    sc.display.shading.color_type = "TEXTURE" if textured else "OBJECT"
    sc.render.resolution_x, sc.render.resolution_y = 800, 800
    arm = bpy.data.objects["Skeleton"]
    hp = arm.matrix_world @ arm.data.bones["head"].head_local
    t = (0.0, hp.y + 0.12, hp.z + 0.02)
    views = {"hside": (0.75, t[1], t[2] + 0.05), "hfront": (0.0, t[1] + 0.75, t[2] + 0.12),
             "h3q": (0.5, t[1] + 0.55, t[2] + 0.25), "hback": (-0.35, t[1] - 0.6, t[2] + 0.3)}
    for k, p in views.items():
        sc.camera = D.cam(k, p, t, lens=60)
        sc.render.filepath = os.path.join(d, "%s_%s%s.png" % (prefix, k, "" if textured else "_shape"))
        bpy.ops.render.render(write_still=True)


BONE_NAMES = []
SRC_CO = None


def main():
    global CENTRE, SRC_CO
    CENTRE = centre()
    a = D.args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body, part = D.load_source()
    part = weld(body, part)
    co = D.vertices(body)
    eyes = find_eyes(body, part)
    # The dog's ears put away, the wolf's added.
    flap = find_flaps(body, co, part)
    part = patch_holes(body, part, flap)
    part, ear_info = add_ears(body, part)
    co = D.vertices(body)
    SRC_CO = co.copy()
    specs = bone_specs(co, part)
    BONE_NAMES[:] = [s[0] for s in specs]
    adjacency = D.edges(body)
    W = skin(co, part, specs, adjacency, ear_info)
    maps = None
    if not a.get("shape"):
        body.data.materials.clear()
        maps = coat_maps(body, part)
    eye_obj = build_eyes(body, part, eyes)
    D.set_vertices(body, shape(co, part))
    D.set_vertices(eye_obj, shape(D.vertices(eye_obj)))
    arm = build_armature(specs)
    D.set_weights(body, W, BONE_NAMES)
    for o in (body, eye_obj):
        o.parent = arm
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    eye_obj.vertex_groups.new(name="head").add(list(range(len(eye_obj.data.vertices))), 1.0, "REPLACE")
    V = D.vertices(body)
    print("wolf: %d verts, %d faces; %.3f m long, %.3f m tall" % (len(body.data.vertices), len(body.data.polygons),
          np.ptp(V[:, 1]), V[:, 2].max()))
    if a.get("shape"):
        if "preview" in a:
            previews(a["preview"], False, arm)
            head_previews(a["preview"], False)
        return
    albedo, normal, orm, dark = maps
    body.data.materials.append(material(albedo, normal, orm, "wolf_coat"))
    me = body.data
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    lv = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", lv)
    size = dark.shape[0]
    px = np.clip((uv * size).astype(int), 0, size - 1)
    dv = np.zeros(len(me.vertices))
    np.maximum.at(dv, lv, dark[px[:, 1], px[:, 0]])
    ear_face = np.zeros(len(me.vertices))
    n_old = len(me.vertices) - len(ear_info)
    ear_face[n_old:] = [f for (_u, _v, f) in ear_info]
    fur = build_fur(body, part, dv, ear_face)
    fur.parent = arm
    fm = fur.modifiers.new("Armature", "ARMATURE")
    fm.object = arm
    D.strand_texture(os.path.join(TEX_DIR, "wolf_strands.png"))
    fmat = material(albedo, normal, orm, "wolf_fur")
    fur.data.materials.append(fmat)
    print("UV: %.4f m per UV unit" % D.uv_metres(body))
    if "preview" in a:
        fur.hide_render = True
        previews(a["preview"], True)
        head_previews(a["preview"], True)
        fur.hide_render = False
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, "wolf.gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="textures",
            export_animations=False, export_skins=True, export_yup=True, export_vertex_color="NONE",
            export_tangents=True, export_image_format="AUTO", use_selection=False)
    D.stamp_gltf(path)
    print("WOLF EXPORTED", path)
    # The pelt, on its own.
    for o in list(bpy.context.scene.objects):
        o.select_set(False)
    pelt, pelt_fur = build_pelt(albedo, normal, orm)
    pelt.select_set(True)
    pelt_fur.select_set(True)
    ppath = os.path.join(OUT_DIR, "wolf_pelt.gltf")
    bpy.ops.export_scene.gltf(filepath=ppath, export_format="GLTF_SEPARATE", export_texture_dir="textures",
            export_animations=False, export_skins=False, export_yup=True, export_vertex_color="NONE",
            export_tangents=True, export_image_format="AUTO", use_selection=True)
    D.stamp_gltf(ppath)
    if "preview" in a:
        sc = bpy.context.scene
        for o in bpy.context.scene.objects:
            o.hide_render = o != pelt
        sc.camera = D.cam("pelt", (0.45, -0.5, 0.45), (0, 0, 0.05), lens=50)
        sc.render.filepath = os.path.join(a["preview"], "pelt.png")
        bpy.ops.render.render(write_still=True)
    print("PELT EXPORTED", ppath)


if __name__ == "__main__":
    main()
