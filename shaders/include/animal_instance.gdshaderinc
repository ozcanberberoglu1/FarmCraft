// Per-animal instance uniforms shared by every animal material. The order must be
// identical in all animal shaders so the instance indices line up.
instance uniform vec3 coat_tint : source_color = vec3(1.0);
instance uniform vec3 points_tint : source_color = vec3(0.12, 0.1, 0.09);
instance uniform vec3 patch_color : source_color = vec3(0.05, 0.045, 0.04);
instance uniform vec3 hair_tint : source_color = vec3(0.1, 0.08, 0.07);
instance uniform float patches = 0.0;
instance uniform float pattern_seed = 0.0;
instance uniform float wet = 0.0;
instance uniform float wool_amount = 1.0;
instance uniform float baby = 0.0;
instance uniform vec3 baby_tint : source_color = vec3(1.0, 0.86, 0.4);
