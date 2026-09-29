// Crown of a felled tree's stump or falling trunk (ChoppableTree): the leaf cards
// clipped at the cut (tree_cut.gdshaderinc).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#define TREE_CUT
#include "res://shaders/include/tree_leaves.gdshaderinc"
