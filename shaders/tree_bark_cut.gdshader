// Trunk and limbs of a felled tree's stump or falling trunk (ChoppableTree): the bark
// clipped at the cut, the cut face drawn inside it (tree_cut.gdshaderinc).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#define TREE_CUT
#include "res://shaders/include/tree_bark.gdshaderinc"
