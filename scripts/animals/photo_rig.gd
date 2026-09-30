@tool
class_name PhotoRig
extends AnimalRig
## A downloaded photo-textured animal (glTF, see art/models/animals/source/CREDITS.md).
## It is scaled to the game's size, stood on the ground facing -Z, its materials are
## swapped for the photo animal shaders (coat variants, wetness, shorn fleece), and
## it is animated by its own clips where it has one for the mode, otherwise by
## AnimalRig's procedural gait through a map from the canonical bone names to the
## model's bones. Switching between clips and procedural motion cross-fades the pose.

const SOURCE_DIR := "res://art/models/animals/source/"
const BLEND_TIME := 0.35

## Per species:
##   height     height of the `body` bone above the hooves, metres
##   bones      canonical bone -> model bone (root, body, neck1, neck2, head, ear_l/r,
##              tail1..3, {f,r}{l,r}_{up,lo,ft}; wing_l/r for birds)
##   clips      AnimalRig.Mode name -> clip name, or a list to pick from (IDLE)
##   gallop     clip used for fast walking / running and the speed from which it takes over
##   clip_speed clip name -> ground speed of the clip at full size, m/s
##   pin        bones whose horizontal position is held (clips with root motion)
##   split      [lo, hi, dark_mean, light_mean] luminance split of the coat texture
##   variants   per coat variant: {material name or "*": {dark, light, recolor}}
##   fleece     {center, radii, depth} in the animal frame (sheep)
##   adult_only mesh names hidden on young animals
##   age_scale  [age from, age to, scale then, scale by then]: the model's own growth (young
##              poultry change bodies: the chick model, then the hen's as a pullet)
##   no_shadow  mesh names too small to cast a visible shadow (horseshoes)
##   materials  material name -> {roughness, specular} overrides
const MODELS := {
	&"cow": {
		"height": 1.02,
		"bones": {
			"root": "Cow_ROOTSHJnt_49", "body": "Cow_Spine_01SHJnt_28",
			"neck1": "Cow_Neck_01SHJnt_23", "neck2": "Cow_Neck_02SHJnt_20", "head": "Cow_Head_TopSHJnt_18",
			"ear_l": "Cow_l_Ear_01_01SHJnt_15", "ear_r": "Cow_r_Ear_01_01SHJnt_17",
			"tail1": "Cow_Tail_01_01SHJnt_46", "tail2": "Cow_Tail_01_02SHJnt_45", "tail3": "Cow_Tail_01_04SHJnt_44",
			"fl_up": "Cow_l_FrontLeg_HipSHJnt_5", "fl_lo": "Cow_l_FrontLeg_Knee1SHJnt_4", "fl_ft": "Cow_l_FrontLeg_Knee2SHJnt_3",
			"fr_up": "Cow_r_FrontLeg_HipSHJnt_12", "fr_lo": "Cow_r_FrontLeg_Knee1SHJnt_11", "fr_ft": "Cow_r_FrontLeg_Knee2SHJnt_10",
			"rl_up": "Cow_l_HindLeg_HipSHJnt_34", "rl_lo": "Cow_l_HindLeg_Knee1SHJnt_33", "rl_ft": "Cow_l_HindLeg_Knee2SHJnt_32",
			"rr_up": "Cow_r_HindLeg_HipSHJnt_40", "rr_lo": "Cow_r_HindLeg_Knee1SHJnt_39", "rr_ft": "Cow_r_HindLeg_Knee2SHJnt_38",
		},
		"clips": {"IDLE": "Animation"},
		"params": {"fold_front": [1.25, -2.65, 0.3], "fold_rear": [-0.55, 2.05, -0.3], "lie_drop": 0.62},
		"split": [0.16, 0.27, 0.07, 0.66],
		"materials": {"material_0": {"keep_u_edge": 0.12}},
		"variants": [
			{},
			{"*": {"dark": Color(0.36, 0.14, 0.06), "light": Color(0.9, 0.87, 0.82), "recolor": 1.0}},
			{"*": {"dark": Color(0.36, 0.22, 0.12), "light": Color(0.66, 0.46, 0.28), "recolor": 1.0}},
		],
	},
	&"horse": {
		"height": 1.55,
		"bones": {
			"root": "BN_Root_01_01", "body": "BN_Spine_03_05_05",
			"neck1": "BN_Neck_00_06_06", "neck2": "BN_Neck_02_011_011", "head": "BN_Head_00_016_015",
			"ear_l": "BN_L_Ear_00_023_022", "ear_r": "BN_R_Ear_00_025_024",
			"tail1": "BN_Tail_00_061_067", "tail2": "BN_Tail_01_062_068", "tail3": "BN_Tail_02_063_069",
			"fl_up": "BN_L_UpperArm_039_040", "fl_lo": "BN_L_Hand_041_042", "fl_ft": "BN_L_Toe_042_043",
			"fr_up": "BN_R_UpperArm_044_046", "fr_lo": "BN_R_Hand_046_048", "fr_ft": "BN_R_Toe_047_049",
			"rl_up": "BN_L_Thing_051_054", "rl_lo": "BN_L_HorseLink_053_056", "rl_ft": "BN_L_Foot_054_057",
			"rr_up": "BN_R_Thing_056_060", "rr_lo": "BN_R_HorseLink_058_062", "rr_ft": "BN_R_Foot_00_063",
		},
		"clips": {"IDLE": ["Skeleton|1 Ilde", "Skeleton|2 Ilde", "Skeleton|3 Ilde"], "WALK": "Skeleton|Walk",
			"RUN": "Skeleton|Gallop", "GRAZE": "Skeleton|6 Eat", "EAT": "Skeleton|6 Eat", "SLEEP": "Skeleton|Sleep"},
		"gallop": ["Skeleton|Gallop", 2.6],
		"clip_speed": {"Skeleton|Walk": 1.6, "Skeleton|Gallop": 8.5},
		"pin": ["BN_Root_01_01"],
		"split": [0.34, 0.5, 0.22, 0.66],
		"variants": [
			{},
			{"Horse": {"dark": Color(0.3, 0.15, 0.07), "light": Color(0.36, 0.19, 0.09), "recolor": 1.0},
				"Hair": {"dark": Color(0.05, 0.04, 0.035), "light": Color(0.09, 0.075, 0.065), "recolor": 1.0}},
			{"Horse": {"dark": Color(0.46, 0.22, 0.09), "light": Color(0.54, 0.27, 0.11), "recolor": 1.0},
				"Hair": {"dark": Color(0.5, 0.36, 0.2), "light": Color(0.82, 0.68, 0.46), "recolor": 1.0}},
			{"Horse": {"dark": Color(0.07, 0.065, 0.06), "light": Color(0.1, 0.09, 0.085), "recolor": 1.0},
				"Hair": {"dark": Color(0.04, 0.035, 0.03), "light": Color(0.07, 0.06, 0.055), "recolor": 1.0}},
			{"Horse": {"dark": Color(0.52, 0.51, 0.5), "light": Color(0.8, 0.79, 0.77), "recolor": 1.0},
				"Hair": {"dark": Color(0.45, 0.44, 0.43), "light": Color(0.85, 0.84, 0.82), "recolor": 1.0}},
		],
		"adult_only": ["Object_12", "Object_115"],
		"no_shadow": ["Object_113"],
		"materials": {"Cornea": {"roughness": 0.04, "specular": 0.8},
			"Hair": {"alpha_from_luma": true, "hair_base": Color(0.74, 0.72, 0.68)}},
	},
	&"sheep": {
		"height": 0.68,
		"bones": {
			"root": "Body_28", "body": "Torso_22",
			"neck1": "Neck1_19", "neck2": "Neck2_18", "head": "Head_16",
			"tail1": "Tail1_9", "tail2": "Tail2_8",
			"fl_up": "FrontUpperLeg.L_11", "fl_lo": "FrontLowerLeg.L_10",
			"fr_up": "FrontUpperLeg.R_14", "fr_lo": "FrontLowerLeg.R_13",
			"rl_up": "BackLeg.L_2", "rl_lo": "BackLowerLeg.L_0",
			"rr_up": "BackLeg.R_6", "rr_lo": "BackLowerLeg.R_4",
		},
		"clips": {"IDLE": "Animation"},
		"params": {"fold_front": [1.25, -2.65, 0.0], "fold_rear": [-0.55, 2.05, 0.0], "lie_drop": 0.3},
		"split": [0.3, 0.5, 0.2, 0.7],
		"variants": [
			{},
			{"*": {"dark": Color(0.3, 0.22, 0.15), "light": Color(0.62, 0.5, 0.38), "recolor": 1.0}},
			{"*": {"dark": Color(0.08, 0.07, 0.065), "light": Color(0.26, 0.22, 0.19), "recolor": 1.0}},
		],
		"fleece": {"center": Vector3(0, 0.62, 0.0), "radii": Vector3(0.42, 0.4, 0.72), "depth": 0.1},
	},
	&"chicken": {
		"height": 0.27,
		"bones": {
			"root": "CHICKEN_-Pelvis_00", "body": "CHICKEN_-Spine_01",
			"neck1": "CHICKEN_-Neck_02", "head": "CHICKEN_-Head_05", "tail1": "CHICKEN_-Tail_015",
			"wing_l": "CHICKEN_-L-UpperArm_012", "wing_r": "CHICKEN_-R-UpperArm_08",
			"fl_up": "CHICKEN_-L-Thigh_028", "fl_lo": "CHICKEN_-L-HorseLink_030", "fl_ft": "CHICKEN_-L-Foot_031",
			"fr_up": "CHICKEN_-R-Thigh_016", "fr_lo": "CHICKEN_-R-HorseLink_018", "fr_ft": "CHICKEN_-R-Foot_019",
		},
		"clips": {"IDLE": "Take 001"},
		"split": [0.12, 0.3, 0.08, 0.55],
		"variants": [
			{},
			{"*": {"dark": Color(0.55, 0.53, 0.5), "light": Color(0.96, 0.95, 0.92), "recolor": 1.0}},
			{"*": {"dark": Color(0.03, 0.03, 0.035), "light": Color(0.12, 0.12, 0.13), "recolor": 1.0}},
			{"*": {"dark": Color(0.45, 0.28, 0.1), "light": Color(0.86, 0.62, 0.3), "recolor": 1.0}},
		],
		# Chicks: pale yellow down (only when the chick model is missing).
		"baby_variant": {"*": {"dark": Color(0.78, 0.64, 0.3), "light": Color(0.98, 0.9, 0.56), "recolor": 1.0}},
		# Pullets (the chick model covers the first half of growing up).
		"age_scale": [0.5, 1.0, 0.5, 1.0],
	},
	# The hen repainted and restyled by tools/blender/build_rooster.py: same skeleton and clip.
	&"rooster": {
		"height": 0.28,
		"bones": {
			"root": "CHICKEN_-Pelvis_00", "body": "CHICKEN_-Spine_01",
			"neck1": "CHICKEN_-Neck_02", "head": "CHICKEN_-Head_05", "tail1": "CHICKEN_-Tail_015",
			"wing_l": "CHICKEN_-L-UpperArm_012", "wing_r": "CHICKEN_-R-UpperArm_08",
			"fl_up": "CHICKEN_-L-Thigh_028", "fl_lo": "CHICKEN_-L-HorseLink_030", "fl_ft": "CHICKEN_-L-Foot_031",
			"fr_up": "CHICKEN_-R-Thigh_016", "fr_lo": "CHICKEN_-R-HorseLink_018", "fr_ft": "CHICKEN_-R-Foot_019",
		},
		"clips": {"IDLE": "Take 001"},
		"split": [0.04, 0.22, 0.05, 0.42],
		"variants": [
			{},
			{"*": {"dark": Color(0.6, 0.58, 0.55), "light": Color(0.97, 0.96, 0.93), "recolor": 1.0}},
		],
		"materials": {"rooster_feather": {"roughness": 0.45, "specular": 0.6}},
		# His comb and sickles reach well past his bones (tools/animal_portraits.gd).
		"portrait_margin": 0.3,
	},
	# A day-old chick, modelled by tools/blender/build_chick.py (Z up, ~10 cm): grows from
	# its modelled size to 1.7 times it before it becomes a pullet (AnimalModels.CHICK_UNTIL).
	&"chick": {
		"height": 0.039,
		"bones": {
			"root": "root", "body": "body", "neck1": "neck", "head": "head", "tail1": "tail",
			"wing_l": "wing_l", "wing_r": "wing_r",
			"fl_up": "thigh_l", "fl_lo": "shank_l", "fl_ft": "foot_l",
			"fr_up": "thigh_r", "fr_lo": "shank_r", "fr_ft": "foot_r",
		},
		"split": [0.45, 0.85, 0.55, 0.88],
		# By the mother's coat (AnimalModels.VARIANTS["chicken"]): buff, yellow, dark, pale.
		"variants": [
			{"*": {"dark": Color(0.58, 0.42, 0.22), "light": Color(0.93, 0.76, 0.48), "recolor": 1.0}},
			{},
			{"*": {"dark": Color(0.07, 0.065, 0.06), "light": Color(0.34, 0.3, 0.24), "recolor": 1.0}},
			{"*": {"dark": Color(0.85, 0.72, 0.4), "light": Color(1.0, 0.93, 0.66), "recolor": 1.0}},
		],
		"age_scale": [0.0, 0.5, 1.0, 1.7],
		"portrait_margin": 0.55,
	},
}

var meshes: Array[MeshInstance3D] = []
var player: AnimationPlayer
var model_cfg: Dictionary = {}

var _frame := Quaternion.IDENTITY  # animal frame -> skeleton space
var _unit := 1.0  # skeleton units per metre
var _conv := {}  # bone -> [A, C, parent rest basis inverse]
var _neutral := {}  # bone -> rotation (animal frame) that squares up the rest pose
var _clip := ""  # clip currently driving the pose ("" = procedural)
var _snap := {}  # bone -> [rotation, position] captured when the pose source changed
var _nodes := {}  # plain node a clip moves -> its transform as set up
var _node_snap := {}  # plain node -> transform captured when the pose source changed
var _blend := 1.0
var _age_scales := {}
var _pins: Array[int] = []
var _baby := false

static var _sources := {}
static var _mode_names: Array = Mode.keys()


## The species' glTF file ("" when there is none); the folder is scanned once.
static func source_file(species_id: StringName) -> String:
	if not _sources.has(species_id):
		_sources[species_id] = _find_source(species_id)
	return _sources[species_id]


static func _find_source(species_id: StringName) -> String:
	var dir := SOURCE_DIR + String(species_id)
	if not DirAccess.dir_exists_absolute(dir):
		return ""
	for f in DirAccess.get_files_at(dir):
		# An exported game packs only the imported scene: the folder lists
		# "scene.gltf.import" (or ".remap"), and the resource still loads by its own name.
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		if file.get_extension() in ["gltf", "glb"]:
			return dir.path_join(file)
	return ""


static func available(species_id: StringName) -> bool:
	if not MODELS.has(species_id):
		return false
	var f := source_file(species_id)
	return f != "" and ResourceLoader.exists(f)


static func assemble_photo(species_id: StringName) -> PhotoRig:
	var rig := PhotoRig.new()
	rig.species = species_id
	rig.model_cfg = MODELS.get(species_id, {})
	rig.cfg = (PARAMS.get(species_id, PARAMS[&"cow"]) as Dictionary).merged(rig.model_cfg.get("params", {}), true)
	rig._seed = randf() * 100.0
	var model: Node3D = _scene(species_id, source_file(species_id)).instantiate()
	model.name = "Model"
	rig.add_child(model)
	rig._setup(model)
	return rig


# --- Setup ---------------------------------------------------------------------------------

func _setup(model: Node3D) -> void:
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var no_shadow: Array = model_cfg.get("no_shadow", [])
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		meshes.append(mi)
		if mi.name in no_shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		player = players[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: String in player.get_animation_list():
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		# Clips also move plain nodes (the chicken's armature parent), and Animal advances
		# them every rendered frame: show those moves as they are, not per physics tick.
		model.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for bone_name: String in model_cfg.get("pin", []):
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			_pins.append(idx)
	var canon := {}
	for key: String in model_cfg.get("bones", {}):
		var idx := skeleton.find_bone(model_cfg["bones"][key])
		if idx >= 0:
			canon[key] = idx
		else:
			push_warning("PhotoRig %s: no bone %s" % [species, model_cfg["bones"][key]])
	_normalize(model, canon)
	# Clips also move plain nodes (the chicken's armature parent): procedural motion puts
	# them back where _normalize stood the model, or it would inherit the clip's last frame
	# (a crowing rooster on his back).
	if player:
		var root := player.get_node(player.root_node)
		for clip: String in player.get_animation_list():
			var anim := player.get_animation(clip)
			for t in anim.get_track_count():
				var path := anim.track_get_path(t)
				if path.get_subname_count() > 0 or not anim.track_get_type(t) in [Animation.TYPE_POSITION_3D,
						Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
					continue
				var n := root.get_node_or_null(path)
				if n is Node3D:
					_nodes[n] = (n as Node3D).transform
	_b = canon
	_collect_legs()
	for key: String in canon:
		_prepare_bone(canon[key])
	_square_up(canon)
	_swap_materials()


## Scales the model so its `body` bone stands `height` above the hooves, puts it on
## y = 0 centred between its legs and turns it to face -Z (from the head and root
## bones). Uses the skeleton rather than mesh bounds: skinned vertices live in bind
## space, which need not match the node transforms.
func _normalize(model: Node3D, canon: Dictionary) -> void:
	model.transform = Transform3D.IDENTITY
	var to_rig := _rel(skeleton, self)
	var pts: Array[Vector3] = []
	for i in skeleton.get_bone_count():
		pts.append(to_rig * skeleton.get_bone_global_rest(i).origin)
	var head: Vector3 = pts[canon.get("head", 0)]
	var root: Vector3 = pts[canon.get("root", 0)]
	var yaw := PI - atan2(head.x - root.x, head.z - root.z)
	var y_min := INF
	for p in pts:
		y_min = minf(y_min, p.y)
	var body_y: float = pts[canon.get("body", canon.get("root", 0))].y
	var s := float(model_cfg.get("height", 1.0)) / maxf(body_y - y_min, 0.0001)
	var centre := Vector3.ZERO
	var n := 0
	for key in ["fl_up", "fr_up", "rl_up", "rr_up"]:
		if canon.has(key):
			centre += pts[canon[key]]
			n += 1
	centre = centre / n if n > 0 else root
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
	var moved := basis * Vector3(centre.x, y_min, centre.z)
	model.transform = Transform3D(basis, -moved)
	var sk := _rel(skeleton, self)
	_frame = sk.basis.get_rotation_quaternion().inverse()
	_unit = 1.0 / sk.basis.get_scale().x


## Transform of `node` relative to `ancestor`, without needing the scene tree.
static func _rel(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _prepare_bone(idx: int) -> void:
	var br := skeleton.get_bone_global_rest(idx).basis.get_rotation_quaternion()
	var parent := skeleton.get_bone_parent(idx)
	var pr := Quaternion.IDENTITY
	var pbasis := Basis.IDENTITY
	if parent >= 0:
		pbasis = skeleton.get_bone_global_rest(parent).basis
		pr = pbasis.get_rotation_quaternion()
	_conv[idx] = [pr.inverse() * _frame, _frame.inverse() * br, pbasis.inverse()]


## Rest poses of downloaded models are often a frame of some clip: a leg stepped
## back, the head turned. For procedural motion the legs of each pair are brought
## to their average stance and the neck and head turned straight ahead.
func _square_up(canon: Dictionary) -> void:
	var to_rig := _rel(skeleton, self)
	var pos := func(idx: int) -> Vector3: return to_rig * skeleton.get_bone_global_rest(idx).origin
	var tip := func(idx: int) -> Vector3:
		var kids := skeleton.get_bone_children(idx)
		return pos.call(kids[0]) if not kids.is_empty() else pos.call(idx)
	# Legs: sagittal angle of each segment (0 = straight down, + = forward).
	for pair: Array in [["fl", "fr"], ["rl", "rr"]]:
		var angles := []
		for side: String in pair:
			var chain: Array = []
			for part: String in ["_up", "_lo", "_ft"]:
				if canon.has(side + part):
					chain.append(canon[side + part])
			var a := []
			for i in chain.size():
				var from: Vector3 = pos.call(chain[i])
				var to: Vector3 = pos.call(chain[i + 1]) if i + 1 < chain.size() else tip.call(chain[i])
				var d := to - from
				# An end bone without a child has no direction: leave it as it is.
				a.append(atan2(-d.z, -d.y) if d.length() > 1e-4 else 0.0)
			angles.append([chain, a])
		if angles.size() < 2 or (angles[0][0] as Array).size() != (angles[1][0] as Array).size():
			continue
		for k in 2:
			var chain: Array = angles[k][0]
			var prev := 0.0
			for i in chain.size():
				var target := (float(angles[0][1][i]) + float(angles[1][1][i])) * 0.5
				var c := target - float(angles[k][1][i])
				_neutral[chain[i]] = Quaternion(Vector3.RIGHT, c - prev)
				prev = c
	# Neck and head: yaw of each segment, the head's from its ears.
	var neck: Array = []
	for key: String in ["neck1", "neck2", "head"]:
		if canon.has(key):
			neck.append(canon[key])
	var prev_yaw := 0.0
	for i in neck.size():
		var yaw := 0.0
		if neck[i] == canon.get("head", -1) and canon.has("ear_l") and canon.has("ear_r"):
			var lateral: Vector3 = pos.call(canon["ear_r"]) - pos.call(canon["ear_l"])
			yaw = atan2(lateral.z, lateral.x)
		else:
			var from: Vector3 = pos.call(neck[i])
			var to: Vector3 = pos.call(neck[i + 1]) if i + 1 < neck.size() else tip.call(neck[i])
			var d := Vector2(to.x - from.x, to.z - from.z)
			# Vertical or zero-length segments have no heading (atan2(0, -0) is PI).
			yaw = atan2(d.x, -d.y) if d.length() > 1e-4 else prev_yaw
		_neutral[neck[i]] = Quaternion(Vector3.UP, yaw - prev_yaw)
		prev_yaw = yaw


## Rotation in the animal frame -> the bone's pose rotation (relative to its parent),
## as if the parent were at rest; chains of mapped bones compose like the sculpted rig.
func _pose_rot(idx: int, q: Quaternion) -> void:
	var c: Array = _conv.get(idx, [])
	if c.is_empty() or _clip != "":
		return
	var total := q * (_neutral.get(idx, Quaternion.IDENTITY) as Quaternion)
	skeleton.set_bone_pose_rotation(idx, (c[0] as Quaternion) * total * (c[1] as Quaternion))


func _pose_offset(idx: int, offset: Vector3) -> void:
	var c: Array = _conv.get(idx, [])
	if c.is_empty() or _clip != "":
		return
	var d := (c[2] as Basis) * (_frame * offset * _unit)
	skeleton.set_bone_pose_position(idx, skeleton.get_bone_rest(idx).origin + d)


## Babies: a bone is lengthened along its own length axis (the direction to its
## first child); uniform scales stay uniform.
func _pose_scale(idx: int, s: Vector3) -> void:
	var v := s
	if not is_equal_approx(s.x, s.y):
		var along := Vector3.UP
		for child in skeleton.get_bone_children(idx):
			along = skeleton.get_bone_rest(child).origin.normalized()
			break
		var ax := along.abs()
		var k := s.y
		v = Vector3(k if ax.x >= ax.y and ax.x >= ax.z else 1.0, k if ax.y > ax.x and ax.y >= ax.z else 1.0,
				k if ax.z > ax.x and ax.z > ax.y else 1.0)
	_age_scales[idx] = v
	skeleton.set_bone_pose_scale(idx, v)


# --- Materials -----------------------------------------------------------------------------

static var _materials := {}


func _swap_materials() -> void:
	var split: Array = model_cfg.get("split", [0.22, 0.42, 0.08, 0.62])
	var fleece: Dictionary = model_cfg.get("fleece", {})
	for mi in meshes:
		for si in mi.mesh.get_surface_count():
			var key := "%s/%s/%d" % [species, mi.name, si]
			if not _materials.has(key):
				_materials[key] = _convert(mi.get_active_material(si), split, fleece, mi)
			mi.set_surface_override_material(si, _materials[key])


func _convert(src: Material, split: Array, fleece: Dictionary, mi: MeshInstance3D) -> Material:
	var m := ShaderMaterial.new()
	var sm := src as StandardMaterial3D
	var over: Dictionary = (model_cfg.get("materials", {}) as Dictionary).get(sm.resource_name if sm else "", {})
	var alpha: bool = sm != null and (sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or bool(over.get("alpha_from_luma", false)))
	var two_sided := sm != null and sm.cull_mode == BaseMaterial3D.CULL_DISABLED
	var shader := "res://shaders/animal_photo.gdshader"
	if alpha:
		shader = "res://shaders/animal_photo_hair.gdshader"
	elif two_sided:
		shader = "res://shaders/animal_photo_2s.gdshader"
	m.shader = load(shader)
	if sm:
		m.set_shader_parameter("albedo_tex", sm.albedo_texture)
		m.set_shader_parameter("albedo_color", sm.albedo_color)
		if sm.normal_enabled and sm.normal_texture:
			m.set_shader_parameter("has_normal", true)
			m.set_shader_parameter("normal_tex", sm.normal_texture)
			m.set_shader_parameter("normal_strength", sm.normal_scale)
		if sm.roughness_texture:
			m.set_shader_parameter("has_orm", true)
			m.set_shader_parameter("orm_tex", sm.roughness_texture)
		if sm.ao_enabled and sm.ao_texture:
			m.set_shader_parameter("has_ao", true)
			m.set_shader_parameter("ao_tex", sm.ao_texture)
		m.set_shader_parameter("roughness", sm.roughness)
		m.set_shader_parameter("metallic", sm.metallic)
		if alpha:
			m.set_shader_parameter("alpha_cut", 0.3)
		for key: String in over:
			m.set_shader_parameter(key, over[key])
	m.set_shader_parameter("split_lo", split[0])
	m.set_shader_parameter("split_hi", split[1])
	m.set_shader_parameter("dark_mean", split[2])
	m.set_shader_parameter("light_mean", split[3])
	if not fleece.is_empty():
		# Animal-frame ellipsoid -> this mesh's space -> unit sphere. Skinned vertices
		# are posed in skeleton space before vertex(), so the mesh frame is the skeleton's.
		var to_mesh := _rel(mi, self).affine_inverse()
		var ell := Transform3D(Basis.from_scale(fleece["radii"]), fleece["center"])
		var xf := (to_mesh * ell).affine_inverse()
		m.set_shader_parameter("has_fleece", true)
		m.set_shader_parameter("fleece_xform", Projection(xf))
		m.set_shader_parameter("fleece_depth", float(fleece.get("depth", 0.05)) / _rel(mi, self).basis.get_scale().x)
	return m


func _material_name(mi: MeshInstance3D) -> String:
	var src := mi.mesh.surface_get_material(0)
	return src.resource_name if src else ""


# --- Appearance ------------------------------------------------------------------------------

func set_variant(variant: int, baby: bool) -> void:
	_baby = baby
	var list: Array = model_cfg.get("variants", [{}])
	var v: Dictionary = list[clampi(variant, 0, list.size() - 1)] if not list.is_empty() else {}
	if baby and model_cfg.has("baby_variant") and not available(&"chick"):
		v = model_cfg["baby_variant"]
	for mi in meshes:
		var t: Dictionary = v.get(_material_name(mi), v.get("*", {}))
		mi.set_instance_shader_parameter(&"dark_tint", t.get("dark", Color(0.05, 0.05, 0.05)))
		mi.set_instance_shader_parameter(&"light_tint", t.get("light", Color(0.95, 0.95, 0.95)))
		mi.set_instance_shader_parameter(&"recolor", float(t.get("recolor", 0.0)))
		mi.visible = not (baby and mi.name in model_cfg.get("adult_only", []))


## Growing up: models with their own growth (age_scale) scale as a whole; others as
## AnimalRig does (bigger head, longer legs).
func set_age(t: float) -> void:
	var span: Array = model_cfg.get("age_scale", [])
	if span.is_empty():
		super.set_age(t)
		return
	_age = clampf(t, 0.0, 1.0)
	_leg_extra = 0.0
	var u := clampf(inverse_lerp(float(span[0]), float(span[1]), _age), 0.0, 1.0)
	scale = Vector3.ONE * lerpf(float(span[2]), float(span[3]), u)


func set_wet(amount: float) -> void:
	for mi in meshes:
		mi.set_instance_shader_parameter(&"wet", amount)


func set_wool(amount: float) -> void:
	for mi in meshes:
		mi.set_instance_shader_parameter(&"wool_amount", clampf(amount, 0.0, 1.0))


# --- Animation ----------------------------------------------------------------------------

## The clip for this mode and speed, "" for procedural motion.
func _clip_for(mode: int, speed: float) -> String:
	if player == null:
		return ""
	var clips: Dictionary = model_cfg.get("clips", {})
	var gallop: Array = model_cfg.get("gallop", [])
	if not gallop.is_empty() and (mode == Mode.RUN or (mode == Mode.WALK and speed / scale.x >= float(gallop[1]))):
		return gallop[0]
	var entry: Variant = clips.get(_mode_names[mode], "")
	if entry is Array:
		# Keep the current idle while it is one of the choices.
		if _clip in entry:
			return _clip
		return (entry as Array).pick_random()
	return String(entry)


func animate(delta: float, speed: float, mode: int) -> void:
	var clip := _clip_for(mode, speed)
	if clip != _clip:
		_snapshot()
		_clip = clip
		if clip != "":
			player.play(clip)
	if _clip != "":
		var natural := float((model_cfg.get("clip_speed", {}) as Dictionary).get(_clip, 0.0)) * scale.x
		player.speed_scale = clampf(speed / natural, 0.55, 1.6) if natural > 0.0 and speed > 0.05 else 1.0
		player.advance(delta)
		for idx in _pins:
			var p := skeleton.get_bone_pose_position(idx)
			var r := skeleton.get_bone_rest(idx).origin
			skeleton.set_bone_pose_position(idx, Vector3(r.x, p.y, r.z))
	else:
		skeleton.reset_bone_poses()
		for n: Node3D in _nodes:
			if n.transform != _nodes[n]:
				n.transform = _nodes[n]
	# The procedural state always advances; it only poses bones without a clip.
	super.animate(delta, speed, mode)
	if _blend < 1.0:
		_blend = minf(_blend + delta / BLEND_TIME, 1.0)
		var w := smoothstep(0.0, 1.0, _blend)
		for idx: int in _snap:
			var s: Array = _snap[idx]
			skeleton.set_bone_pose_rotation(idx, (s[0] as Quaternion).slerp(skeleton.get_bone_pose_rotation(idx), w))
			skeleton.set_bone_pose_position(idx, (s[1] as Vector3).lerp(skeleton.get_bone_pose_position(idx), w))
		for n: Node3D in _node_snap:
			n.transform = (_node_snap[n] as Transform3D).interpolate_with(n.transform, w)
	for idx: int in _age_scales:
		skeleton.set_bone_pose_scale(idx, _age_scales[idx])


func _snapshot() -> void:
	_snap.clear()
	for i in skeleton.get_bone_count():
		_snap[i] = [skeleton.get_bone_pose_rotation(i), skeleton.get_bone_pose_position(i)]
	for n: Node3D in _nodes:
		_node_snap[n] = n.transform
	_blend = 0.0
