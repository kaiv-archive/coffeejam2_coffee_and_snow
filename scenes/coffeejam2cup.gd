extends Heldable




func hints():
	return [
		["use_coffee", "F", "Пить"],
	]

var since_last = 2.7
const cd = 2.7
func _process(delta: float) -> void:
	since_last += delta

func use(_point, _dir, _body, _normal):
	if !_body: return
	if _body.is_in_group("eraser") || _body.name == "Eraser":
		for hint in hints():
			var key = hint[0]
			GLOBAL.hints.rm_hint(key)
		cleanup()
		GLOBAL.player.held_item = null
		self.queue_free()
		return
	if since_last < cd: return
	since_last = 0.0
	$SlurpSrc.play()
	GLOBAL.player.ANIMATION.set("parameters/drink/request", 1)
	

func on_pickup():
	since_last = 2.7

func cleanup():
	GLOBAL.player.ANIMATION.set("parameters/drink/request", 2)
	
