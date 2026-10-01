class_name ComicFx
extends RefCounted
## The "Komik hayvanlar" setting (Settings.comic_animals, on by default): a light cartoon
## touch over the realistic animals, all of it in ComicEyes. The poultry rigs and the fish
## models are handed in here as they are made (dress_rig, dress_fish); the setting puts
## the eyes on every one of them or takes them all off again, leaving the animals exactly
## as they were. Also the stars that go round a fainted rooster's head and a startled
## hen's feathers.

## Rigs and fish models that may wear the eyes (whether or not they do now).
const HOSTS := &"comic_hosts"
## The stars round a head out cold: how many, their size, the circle's radius and height
## above the head (metres at full size) and how fast they go round (radians/s).
const STARS := 3
const STAR_SIZE := 0.04
const STAR_ORBIT := 0.1
const STAR_RISE := 0.11
const STAR_SPEED := 4.2

static var _hooked := false
static var _shown := true
static var _star_mesh: ArrayMesh
static var _star_mat: StandardMaterial3D


static func enabled() -> bool:
	return not Engine.is_editor_hint() and Settings.comic_animals


## A poultry rig just made (AnimalModels.create_rig): its eyes when the setting is on.
static func dress_rig(rig: AnimalRig) -> void:
	if Engine.is_editor_hint() or not ComicEyes.BIRDS.has(rig.species):
		return
	_hook()
	rig.add_to_group(HOSTS)
	if enabled():
		var e := ComicEyes.for_rig(rig)
		if e:
			rig.add_child(e)


## A fish model (`mi` showing item or species `id`): its eyes when the setting is on and
## it is a raw fish, otherwise none (any it had are taken off). `mood` as ComicEyes.Mood.
static func dress_fish(mi: MeshInstance3D, id: StringName, mood := ComicEyes.Mood.NORMAL) -> void:
	if Engine.is_editor_hint():
		return
	_hook()
	_undress(mi)
	mi.add_to_group(HOSTS)
	mi.set_meta(&"comic_fish", [id, mood])
	if not enabled() or String(id).contains("cooked") or not FishTable.is_fish(FishTable.species_of(id)):
		return
	var e := ComicEyes.for_fish(mi, FishModels.real_mesh(FishTable.species_of(id)), mood)
	if e:
		mi.add_child(e)


## The eyes on `host`, if it wears them.
static func eyes_of(host: Node) -> ComicEyes:
	if host == null:
		return null
	for c in host.get_children():
		if c is ComicEyes and not c.is_queued_for_deletion():
			return c
	return null


static func _undress(host: Node) -> void:
	var e := eyes_of(host)
	if e:
		host.remove_child(e)
		e.queue_free()


static func _hook() -> void:
	if _hooked:
		return
	_hooked = true
	_shown = Settings.comic_animals
	Settings.changed.connect(_on_settings)


## The setting switched: every host puts its eyes on or takes them off.
static func _on_settings() -> void:
	if Settings.comic_animals == _shown:
		return
	_shown = Settings.comic_animals
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for host in tree.get_nodes_in_group(HOSTS):
		_undress(host)
		if not _shown:
			continue
		var fish: Variant = host.get_meta(&"comic_fish") if host.has_meta(&"comic_fish") else null
		if fish is Array:
			dress_fish(host as MeshInstance3D, (fish as Array)[0], (fish as Array)[1])
		elif host is AnimalRig:
			var e := ComicEyes.for_rig(host as AnimalRig)
			if e:
				host.add_child(e)


# --- Stars and feathers ---------------------------------------------------------------------

## Three little stars to go round a head (spin_stars places them).
static func make_stars() -> Node3D:
	if _star_mesh == null:
		_star_mesh = _build_star()
		_star_mat = StandardMaterial3D.new()
		_star_mat.albedo_color = Color(1.0, 0.86, 0.25)
		_star_mat.emission_enabled = true
		_star_mat.emission = Color(1.0, 0.78, 0.2)
		_star_mat.emission_energy_multiplier = 1.2
		_star_mat.roughness = 0.4
		_star_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var root := Node3D.new()
	root.name = "ComicStars"
	root.top_level = true
	for i in STARS:
		var mi := MeshInstance3D.new()
		mi.mesh = _star_mesh
		mi.material_override = _star_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.layers = 2
		mi.visibility_range_end = ComicEyes.DRAW_FAR
		root.add_child(mi)
	return root


## The stars going round above `head` (`t` seconds on, `size` the animal's scale), each
## turned to the camera at `cam` and twirling.
static func spin_stars(stars: Node3D, head: Vector3, t: float, size: float, cam: Vector3) -> void:
	stars.global_transform = Transform3D(Basis.IDENTITY, head + Vector3(0.0, STAR_RISE * size, 0.0))
	var n := stars.get_child_count()
	for i in n:
		var star := stars.get_child(i) as Node3D
		var a := t * STAR_SPEED + TAU * float(i) / float(n)
		var bob := sin(t * 5.0 + float(i) * 2.1) * 0.012 * size
		star.position = Vector3(cos(a) * STAR_ORBIT * size, bob, sin(a) * STAR_ORBIT * size)
		var to := cam - star.global_position
		var facing := Basis.looking_at(to, Vector3.UP) if to.length_squared() > 1e-4 and absf(to.normalized().y) < 0.999 else Basis.IDENTITY
		star.basis = (facing * Basis(Vector3.BACK, t * 3.0 + float(i))).scaled(Vector3.ONE * STAR_SIZE * size)


## A plump five-pointed star, radius 1, facing +Z.
static func _build_star() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for k in 10:
		var a := PI * 0.5 + TAU * float(k) / 10.0
		var r := 1.0 if k % 2 == 0 else 0.45
		rim.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for face: float in [1.0, -1.0]:
		var tip := Vector3(0.0, 0.0, 0.32 * face)
		for k in 10:
			var p0 := rim[k]
			var p1 := rim[(k + 1) % 10]
			if face > 0.0:
				st.add_vertex(tip)
				st.add_vertex(p1)
				st.add_vertex(p0)
			else:
				st.add_vertex(tip)
				st.add_vertex(p0)
				st.add_vertex(p1)
	st.generate_normals()
	return st.commit()


## Two or three feathers of `coat` flying off a startled hen.
static func feather_puff(at: Vector3, coat: Color) -> void:
	Fx._burst(at, coat, 3, Vector3(0.08, 0.06, 0.08), 1.3, 2.2, 70.0, 0.04, Vector3.UP, 1.1, 2.5, 1.8, false, 0.4)
