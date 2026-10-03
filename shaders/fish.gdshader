// A fish that bends: the tail beats side to side (a wave running from the head to the
// tail, strongest at the tail) and the body can arch into a C, as a fish flopping on the
// ground or thrashing on the line does. The fish lies along +X (head forward) with its
// sides facing +-Z; the bend moves vertices along Z and turns their normals with it.
// Otherwise the model's own look: albedo and normal textures, roughness, a wet clear
// coat. FishModels.flop_material copies these from the imported material.
// The body, eyes and barbels: opaque, their back faces culled (the thin fins, drawn from
// both sides, use fish_fin.gdshader).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/fish.gdshaderinc"
