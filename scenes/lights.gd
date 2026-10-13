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
var rope_col : Area3D = null
var preview_end : Vector3

var lanterns_root : Node3D = null


func _ready():
	# Предзагрузка/дублирование для кэширования шейдеров и ресурсов
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

	# Кэширование (прогрев) первой веревки и лампочек на -100 по Y,
	# чтобы убрать микрофриз при первом реальном использовании игроком.
	call_deferred("_warmup_rope_and_lanterns")


func _warmup_rope_and_lanterns():
	var dummy_start = Vector3(0, -100, 0)
	var dummy_end = dummy_start + Vector3(0, 0, 2.0) # длина 2 метра, как раз поместится 3 лампочки
	
	# 1. Создаем временную веревку с Area3D в качестве корня
	var warmup_rope = _create_rope_node(dummy_start, dummy_end, final_material)
	
	# 2. Спавним 3 лампочки для прогрева материалов и сцен
	var warmup_lanterns = _spawn_lanterns_internal(null, dummy_start, dummy_end)
	
	# Очищаем кэш-объекты в следующем кадре или сразу
	if warmup_rope:
		warmup_rope.queue_free()
	if warmup_lanterns:
		warmup_lanterns.queue_free()


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
		
		_spawn_lanterns(rope_col, start_point, point)
		has_start = false
		rope_col = null
		rope_mesh = null


func _create_rope():
	rope_col = Area3D.new()
	
	var s := CollisionShape3D.new()
	s.shape = CylinderShape3D.new()
	s.shape.height = 0.01
	s.shape.radius = rope_radius * 7.0
	s.name = "shape"
	rope_col.add_child(s)
	
	rope_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rope_radius
	cyl.bottom_radius = rope_radius
	cyl.height = 0.01
	cyl.radial_segments = 6
	cyl.rings = 0
	rope_mesh.mesh = cyl
	rope_mesh.material_override = preview_material
	rope_mesh.name = "mesh"
	
	rope_col.add_child(rope_mesh)
	rope_col.add_to_group("pasted")
	get_tree().root.add_child(rope_col)


# Вспомогательная функция для создания полноценной веревки (Area3D теперь отец)
func _create_rope_node(a: Vector3, b: Vector3, mat: Material) -> Area3D:
	var area = Area3D.new()
	
	var s := CollisionShape3D.new()
	s.shape = CylinderShape3D.new()
	s.name = "shape"
	area.add_child(s)
	
	var mesh_inst = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rope_radius
	cyl.bottom_radius = rope_radius
	
	var dir = b - a
	var length = dir.length()
	cyl.height = length
	cyl.radial_segments = 6
	cyl.rings = 0
	
	mesh_inst.mesh = cyl
	mesh_inst.material_override = mat
	mesh_inst.name = "mesh"
	area.add_child(mesh_inst)
	
	s.shape.height = length
	
	get_tree().root.add_child(area)
	area.add_to_group("pasted")
	
	area.global_position = a + dir * 0.5
	if length > 0.001:
		area.global_transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
		area.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	
	return area


func _update_rope(a: Vector3, b: Vector3, is_preview: bool):
	if rope_col == null or rope_mesh == null:
		return

	var dir = b - a
	var length = dir.length()
	if length < 0.01:
		return

	var cyl := rope_mesh.mesh as CylinderMesh
	cyl.height = length
	var s := rope_col.get_node("shape").shape as CylinderShape3D
	s.height = length

	rope_col.global_position = a + dir * 0.5
	rope_col.global_transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	rope_col.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	rope_mesh.material_override = preview_material if is_preview else final_material


func _spawn_lanterns(node, a: Vector3, b: Vector3):
	lanterns_root = _spawn_lanterns_internal(node, a, b)


func _spawn_lanterns_internal(node, a: Vector3, b: Vector3) -> Node3D:
	var dir = b - a
	var length = dir.length()
	if length <= lantern_spacing:
		return null
	
	var count := int(length / lantern_spacing)
	var root = Node3D.new()
	if node:
		node.add_child(root)
	else:
		get_tree().root.add_child(root)
	
	root.global_position = a
	if length > 0.001:
		root.global_transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	
	var local_forward := Vector3.FORWARD
	var step = length / float(count + 1)
	
	for i in range(count):
		var lantern = LanternScene.duplicate()
		root.add_child(lantern)
		
		lantern.position = local_forward * step * (i + 1)
		
		var col = COLORS[i % COLORS.size()]
		var mat := _get_material_for_color(col)
		var tmat := _get_tmaterial_for_color(col)
		
		lantern.set_light_color(col)
		lantern.set_material(mat, tmat)
		lantern.randomize_rotation()
		
	return root


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
	tmaterial_cache[col] = mat
	return mat


func cleanup():
	if rope_col:
		rope_col.queue_free()
	rope_col = null
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
