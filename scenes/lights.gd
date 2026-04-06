extends Heldable

@export var preview_material : StandardMaterial3D
@export var final_material   : StandardMaterial3D
@export var rope_radius := 0.01

@export var lantern_spacing := 0.6

var LanternScene = preload("res://scenes/lightblob.tscn").instantiate()


const COLORS := [
	Color.RED,
	Color.BLUE,
	Color.GREEN
]

var material_cache := {}
var tmaterial_cache := {}

var start_point : Vector3
var has_start := false

var rope_mesh : MeshInstance3D = null
var preview_end : Vector3

var lanterns_root : Node3D = null


func _ready():
	var s = LanternScene.duplicate()
	get_tree().root.add_child.call_deferred(s)
	s.position = Vector3.DOWN * 1024.0

	if preview_material == null:
		preview_material = StandardMaterial3D.new()
		preview_material.albedo_color = Color(0.2, 1, 0.4, 0.4)
		preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if final_material == null:
		final_material = StandardMaterial3D.new()
		final_material.albedo_color = Color(0.2, 0.2, 0.2, 1)


func ray_hints(_body):
	if self.disabled:
		GLOBAL.hints.rm_hint("use_lights")
		return []
	return [
		["use_lights", "F", "Повесить"],
	]


func tick_ray(point: Vector3, _dir, body, _normal):
	if not has_start:
		return
	if body:
		preview_end = point
	else:
		preview_end = GLOBAL.camera.global_position - GLOBAL.camera.global_basis.z * 2.0
	_update_rope(start_point, preview_end, true)


func use(point: Vector3, _dir, body, _normal):
	if self.disabled: return
	if !body: return
	if not has_start:
		if not body:
			return
		has_start = true
		start_point = point
		_create_rope()
	else:
		if not body:
			return
		_update_rope(start_point, point, false)
		_spawn_lanterns(start_point, point)
		has_start = false
		rope_mesh = null


func _create_rope():
	rope_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rope_radius
	cyl.bottom_radius = rope_radius
	cyl.height = 0.01
	cyl.radial_segments = 6
	cyl.rings = 0
	rope_mesh.mesh = cyl
	rope_mesh.material_override = preview_material
	get_tree().root.add_child(rope_mesh)


func _update_rope(a: Vector3, b: Vector3, is_preview: bool):
	if rope_mesh == null:
		return

	var dir = b - a
	var length = dir.length()
	if length < 0.01:
		return

	var cyl := rope_mesh.mesh as CylinderMesh
	cyl.height = length

	rope_mesh.global_position = a + dir * 0.5
	rope_mesh.global_transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	rope_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	rope_mesh.material_override = preview_material if is_preview else final_material

func _spawn_lanterns(a: Vector3, b: Vector3):
	var dir = b - a
	var length = dir.length()
	if length <= lantern_spacing:
		return
	
	var count := int(length / lantern_spacing)
	
	lanterns_root = Node3D.new()
	get_tree().root.add_child(lanterns_root)
	
	lanterns_root.global_position = a
	lanterns_root.global_transform.basis = \
		Basis.looking_at(dir.normalized(), Vector3.UP)
	
	var local_forward := Vector3.FORWARD
	var step = length / float(count + 1)
	
	for i in range(count):
		var lantern = LanternScene.duplicate()
		lanterns_root.add_child(lantern)
		
		lantern.position = local_forward * step * (i + 1)
		
		var col = COLORS[i % COLORS.size()]
		var mat := _get_material_for_color(col)
		var tmat := _get_tmaterial_for_color(col)
		
		lantern.set_light_color(col)
		lantern.set_material(mat, tmat)
		
		lantern.randomize_rotation()

func _get_material_for_color(col: Color) -> StandardMaterial3D:
	if material_cache.has(col):
		return material_cache[col]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy = 1.5

	material_cache[col] = mat
	return mat

func _get_tmaterial_for_color(col: Color) -> StandardMaterial3D:
	if tmaterial_cache.has(col):
		return tmaterial_cache[col]
	var mat := StandardMaterial3D.new()
	col.a = 0.4
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy = 1.5
	material_cache[col] = mat
	return mat

func cleanup():
	if rope_mesh:
		rope_mesh.queue_free()
	rope_mesh = null
	lanterns_root = null
	has_start = false

func on_state_enter(_state):
	self.disabled = true
	cleanup()

func on_state_exit(_state):
	self.disabled = false
	

func can_use(_body):
	if self.disabled: return false
	if !_body: return false
	if _body.is_in_group("campfire"): return false
	if _body.is_in_group("pickable"): return false

	return true
