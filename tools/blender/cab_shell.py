"""The body shell a cab interior has to fit inside, measured on the exterior model itself.

`Shell(path)` loads a vehicle's exterior (the downloaded glTF), keeps its skin, frames
and glass as ray-cast trees and its window panes' outlines, and takes the model out of
the scene again. A cab builder (tools/blender/build_pickup_interior.py) asks it where
the roof skin is over a point, where a pane's edge runs and which way the pane faces
there, how far a point is from the skin, and has its trim pulled in until it clears the
skin (`fit`); `report` lists what of a set of parts still stands outside. Blender axes: front +X, left +Y, up +Z.
"""
import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

_S = math.sqrt(0.5)
# Below these heights nothing is looked at from behind (the load bed's floor) or from
# the side (the door sills): the chassis under the floor is open here and there.
BACK_FROM = 0.67
SIDE_FROM = 0.6
HIGH_FROM = 1.2


def looks(p):
    """The directions a point of the cab could be seen from outside in: from above
    always, from behind and from its side above the floor, and from between those up
    in the greenhouse."""
    out = [Vector((0, 0, 1))]
    sides = [1.0, -1.0] if abs(p.y) < 0.05 else [math.copysign(1.0, p.y)]
    if p.z >= BACK_FROM:
        out.append(Vector((-1, 0, 0)))
    if p.z >= SIDE_FROM:
        out += [Vector((0, s, 0)) for s in sides]
    if p.z >= HIGH_FROM:
        out += [Vector((-_S, 0, _S)), Vector((_S, 0, _S))] + [Vector((0, s * _S, _S)) for s in sides]
    return out


class Shell:
    def __init__(self, path, skip=("Interior", "Steering_Wheel", "WheelStock"), glass=("Glass_Rear", "Glass_Driver", "Glass_Passenger", "Windshield"),
                 paint="Bodymat"):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        made = [o for o in bpy.data.objects if o not in before]
        verts, polys = [], []
        outer_v, outer_p = [], []
        self.outlines = {}
        self.panes = {}
        for o in made:
            if o.type != "MESH" or any(k in o.name for k in skip):
                continue
            base = len(verts)
            mw = o.matrix_world
            verts += [mw @ v.co for v in o.data.vertices]
            polys += [tuple(base + i for i in p.vertices) for p in o.data.polygons]
            pane = next((k for k in glass if k in o.name), None)
            if pane or any(paint in m.name for m in o.data.materials if m):
                # The painted skin and the panes: what a cab part must never touch.
                base = len(outer_v)
                outer_v += [mw @ v.co for v in o.data.vertices]
                outer_p += [tuple(base + i for i in p.vertices) for p in o.data.polygons]
            if pane:
                key = o.name.split("UTLTRUCK90_")[-1].split("_UCB")[0]
                self.outlines[key] = _outline(o)
                self.panes[key] = BVHTree.FromPolygons([mw @ v.co for v in o.data.vertices], [tuple(p.vertices) for p in o.data.polygons])
        self.tree = BVHTree.FromPolygons(verts, polys)
        self.outer = BVHTree.FromPolygons(outer_v, outer_p)
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)
        for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.textures):
            for d in [d for d in block if d.users == 0]:
                block.remove(d)

    def cast(self, origin, direction, dist=6.0):
        """The first skin, frame or pane along a ray: its point, or None."""
        loc, _n, _i, _d = self.tree.ray_cast(Vector(origin), Vector(direction).normalized(), dist)
        return loc

    def roof(self, x, y, z0=1.4):
        """The height of the roof skin (or whatever closes the cab) over (x, y)."""
        hit = self.cast((x, y, z0), (0, 0, 1))
        return hit.z if hit else None

    def near(self, p):
        """The distance from p to the nearest skin, frame or pane."""
        _loc, _n, _i, d = self.tree.find_nearest(Vector(p))
        return d

    def edge(self, pane, side, pick):
        """The points of a pane's outline on `side` (1 left, -1 right, 0 both) that
        `pick(point)` takes, in the outline's order."""
        return [p.copy() for p in self.outlines[pane] if (side == 0 or p.y * side > 0.0) and pick(p)]

    def enclosed(self, p):
        """True when p cannot be seen from outside: something of the shell stands in
        every direction a look could come from."""
        p = Vector(p)
        return all(self.tree.ray_cast(p, d, 8.0)[0] is not None for d in looks(p))

    def into_cab(self, p, mid=(0.75, 0.0, 1.25)):
        """The normal of the pane nearest p, at its point nearest p, turned into the cab."""
        p = Vector(p)
        n = min((tree.find_nearest(p) for tree in self.panes.values()), key=lambda hit: hit[3])[1].normalized()
        return n if n.dot(Vector(mid) - p) > 0.0 else -n

    def near_outer(self, p):
        """The distance from p to the nearest painted skin or pane."""
        return self.outer.find_nearest(Vector(p))[3]

    def inside(self, p, clearance=0.0, outer_only=False):
        """True when p is out of sight from outside and `clearance` from the skin, the
        frames and the panes (`outer_only`: from the painted skin and the panes; the
        chassis under the floor and behind the dash may be nearer)."""
        return self.enclosed(p) and (self.near_outer(p) if outer_only else self.near(p)) >= clearance

    def fit(self, p, clearance, toward=None, step=0.003, outer_only=False):
        """p, moved towards the cab's middle until it is inside the shell with `clearance`."""
        p = Vector(p)
        for _ in range(200):
            if self.inside(p, clearance, outer_only):
                return p
            t = Vector(toward) if toward is not None else Vector((min(max(p.x, 0.55), 0.95), 0.0, min(max(p.z, 0.95), 1.3)))
            d = t - p
            if d.length < step:
                return p
            p = p + d.normalized() * step
        return p

    def fit_object(self, ob, clearance, outer_only=False):
        """Pulls every vertex of a part inside (see fit); returns how many moved and the
        longest move."""
        moved, far = 0, 0.0
        mw = ob.matrix_world
        inv = mw.inverted()
        for v in ob.data.vertices:
            w = mw @ v.co
            q = self.fit(w, clearance, outer_only=outer_only)
            if (q - w).length > 1e-6:
                moved += 1
                far = max(far, (q - w).length)
                v.co = inv @ q
        return moved, far

    def report(self, obs, clearance=0.0, title="fit"):
        """Prints, part by part, how many vertices stand outside the shell (or nearer
        than `clearance` to its painted skin and panes) and how far from those at most;
        returns that distance, or how far short of the clearance the nearest is."""
        worst = 0.0
        print("--- %s (clearance %.1f cm)" % (title, clearance * 100.0))
        for ob in obs:
            mw = ob.matrix_world
            out, close, far, n = 0, 0, 0.0, 0
            for v in ob.data.vertices:
                p = mw @ v.co
                n += 1
                d = self.near_outer(p)
                if not self.enclosed(p):
                    out += 1
                    far = max(far, d)
                elif d < clearance:
                    close += 1
                    worst = max(worst, clearance - d)
            if out or close:
                print("  %-22s %5d verts: %4d outside (up to %.1f cm), %4d nearer than the clearance" % (ob.name, n, out, far * 100.0, close))
            worst = max(worst, far)
        print("--- worst: %.1f cm outside" % (worst * 100.0))
        return worst


def _outline(o):
    """A pane's rim as a loop of points."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    left = {e for e in bm.edges if e.is_boundary}
    e = left.pop()
    loop = [e.verts[0], e.verts[1]]
    while True:
        nxt = [x for x in loop[-1].link_edges if x in left]
        if not nxt:
            break
        left.discard(nxt[0])
        loop.append(nxt[0].other_vert(loop[-1]))
    pts = [v.co.copy() for v in loop[:-1]] if loop[0] == loop[-1] else [v.co.copy() for v in loop]
    bm.free()
    return pts
