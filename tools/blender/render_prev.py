"""Workbench preview renders for the animal build scripts (rest pose, +X up, -Y forward)."""
import bpy
import mathutils


def cam(name, pos, target, up=(1, 0, 0), lens=50):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.clip_start = 0.001
    c = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(c)
    pos = mathutils.Vector(pos)
    fwd = (mathutils.Vector(target) - pos).normalized()
    right = fwd.cross(mathutils.Vector(up)).normalized()
    m = mathutils.Matrix((right, right.cross(fwd), -fwd)).transposed()
    c.matrix_world = mathutils.Matrix.Translation(pos) @ m.to_4x4()
    return c


def render(c, path, res=(900, 700)):
    sc = bpy.context.scene
    sc.camera = c
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def shots(d, center=(0.3, 0.08, 0.27), dist=1.4):
    x, y, z = center
    render(cam("side", (x, y, z + dist), center), d + "/side.png")
    render(cam("front3q", (x + 0.25, y - dist * 0.7, z + dist * 0.7), center), d + "/front3q.png")
    render(cam("back3q", (x + 0.35, y + dist * 0.8, z - dist * 0.6), center), d + "/back3q.png")
