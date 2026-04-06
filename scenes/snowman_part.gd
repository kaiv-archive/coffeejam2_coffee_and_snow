extends Heldable

var preview
@export var preview_material : StandardMaterial3D

var size = 1.0
var size_min = 0.1
var size_max = 10.0
var size_gain = 0.1


func _ready():
	if preview_material == null:
		preview_material = StandardMaterial3D.new()
		preview_material.albedo_color = Color(0.2, 1, 0.4, 0.4)
		preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	$CollisionShape3D.shape = $CollisionShape3D.shape.duplicate(true)
	$MeshInstance3D.mesh = $MeshInstance3D.mesh.duplicate(true)
	preview = Node3D.new()
	var m = $MeshInstance3D.duplicate(true)
	preview.add_child(m)
	get_tree().root.add_child.call_deferred(preview)
	preview.hide()
	m.material_override = preview_material


func tick_ray(point: Vector3, _dir, body, _normal: Vector3):
	if can_use(body):
		preview.global_position = point # - _normal * size * 0.06
		var up := _normal.normalized()
		var ref_forward := Vector3.FORWARD
		if abs(up.dot(ref_forward)) > 0.99:
			ref_forward = Vector3.RIGHT
		var right := up.cross(ref_forward).normalized()
		var forward := right.cross(up).normalized()
		preview.global_basis = Basis(right, up, -forward)
		preview.show()
		preview.scale = -Vector3.ONE * size
	else:
		preview.hide()
	# todo: non-linear
	size *= exp(d * size_gain)
	size = clampf(size, size_min, size_max)
	d = 0


func cleanup():
	preview.hide()
	GLOBAL.hints.rm_hint("snowball")
	GLOBAL.hints.rm_hint("mousewheel")
	


func ray_hints(_body):
	if !can_use(_body):
		GLOBAL.hints.rm_hint("snowball")
		return []
	return [
		["snowball", "F", "Прикрепить"],
	]


var d = 0
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			d = 1 
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			d = -1


func use(_point: Vector3, _dir, _body, _normal):
	if !can_use(_body): return
	var body = StaticBody3D.new()
	get_tree().root.add_child(body)
	var up = _normal.normalized()
	var ref_forward := Vector3.FORWARD
	
	if abs(up.dot(ref_forward)) > 0.99:
		ref_forward = Vector3.RIGHT
	var right = up.cross(ref_forward).normalized()
	var forward = right.cross(up).normalized()
	body.global_position = _point # - _normal * size * 0.06
	
	
	body.global_basis = Basis(right, up, -forward)
	body.scale = -Vector3.ONE * size
	var c = $CollisionShape3D.duplicate()
	c.disabled = false
	body.add_child(c)
	body.add_child($MeshInstance3D.duplicate())
	body.add_to_group("pasted")
	print(body)

	#cleanup()
	#preview.queue_free()
	#self.queue_free()
	#get_tree().create_timer(0.001).timeout.connect(func (): GLOBAL.hints.rm_hint("snowball"))


func on_state_enter(_state):
	self.disabled = true
	cleanup()


func on_state_exit(_state):
	self.disabled = false


func on_pickup():
	GLOBAL.hints.hint("mousewheel", "Колесико", "Изменить размер")
	d = 0
	size = 1

func can_use(_body):
	if self.disabled: return false
	if !_body: return false
	if _body.is_in_group("campfire"): return false
	return true
