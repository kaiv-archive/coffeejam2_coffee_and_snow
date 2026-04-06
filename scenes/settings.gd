extends CanvasLayer

# ----------------------- ENUMS -----------------------
enum AAMode {
	DISABLED,
	X2,
	X4,
	X8,
	MAX
}

enum ANISOTROPYMode {
	DISABLED,
	X2,
	X4,
	X8,
	MAX
}

# ----------------------- VARIABLES -----------------------
var show_progress = 0.0
var show_target = 1.0
var speed = 10.0
var suppress_change = false

func modulate(v):
	return Color.from_rgba8(255, 255, 255, v * 255)

# ----------------------- UI NODES -----------------------
@onready var preset = $Control/MarginContainer/ScrollContainer/VBoxContainer/preset/OptionButton
@onready var vsync = $Control/MarginContainer/ScrollContainer/VBoxContainer/AntiAliasing/VBoxContainer/Vsync/CheckBox
@onready var aa = $Control/MarginContainer/ScrollContainer/VBoxContainer/AntiAliasing/VBoxContainer/AA/OptionButton
@onready var anisotrophy = $Control/MarginContainer/ScrollContainer/VBoxContainer/AntiAliasing/VBoxContainer/Anistrophy/OptionButton
@onready var global_light = $Control/MarginContainer/ScrollContainer/VBoxContainer/Shadows/VBoxContainer/GlobalLight/OptionButton
@onready var fog_type = $Control/MarginContainer/ScrollContainer/VBoxContainer/Environment/VBoxContainer/FogType/OptionButton
@onready var snow = $Control/MarginContainer/ScrollContainer/VBoxContainer/Environment/VBoxContainer/Snow/OptionButton
@onready var ssao = $Control/MarginContainer/ScrollContainer/VBoxContainer/Environment/VBoxContainer/SSAO/CheckBox
@onready var ssil = $Control/MarginContainer/ScrollContainer/VBoxContainer/Environment/VBoxContainer/SSIL/CheckBox
@onready var sdfgi = $Control/MarginContainer/ScrollContainer/VBoxContainer/Environment/VBoxContainer/SDFGI/CheckBox

# ----------------------- PRESETS -----------------------
const PRESETS = {
	0: { # Ракета
		"vsync": true, "aa": AAMode.MAX, "anisotrophy": ANISOTROPYMode.MAX, "global_light": 2,
		"fog_type": 1, "snow": 4, "ssao": true, "ssil": true, "sdfgi": true
	},
	1: { # Машина
		"vsync": true, "aa": AAMode.X4, "anisotrophy": ANISOTROPYMode.X4, "global_light": 1,
		"fog_type": 1, "snow": 3, "ssao": true, "ssil": true, "sdfgi": true
	},
	2: { # Печка
		"vsync": true, "aa": AAMode.X2, "anisotrophy": ANISOTROPYMode.X2, "global_light": 0,
		"fog_type": 1, "snow": 2, "ssao": true, "ssil": false, "sdfgi": false
	},
	3: { # Картошка
		"vsync": false, "aa": AAMode.DISABLED, "anisotrophy": ANISOTROPYMode.DISABLED,"global_light": 0,
		"fog_type": 0, "snow": 0, "ssao": false, "ssil": false, "sdfgi": false
	}
}

# ----------------------- LIFECYCLE -----------------------
func _ready():
	$Control.modulate = modulate(0.0)
	$Control.hide()
	GLOBAL.settings = self
	

	# сигналы
	preset.item_selected.connect(_on_preset_selected)
	vsync.toggled.connect(_on_vsync_change)
	vsync.toggled.connect(_on_change)
	snow.item_selected.connect(_on_snow_change)
	snow.item_selected.connect(_on_change)
	aa.item_selected.connect(_on_aa_change)
	aa.item_selected.connect(_on_change)
	anisotrophy.item_selected.connect(_on_anisotropy_change)
	anisotrophy.item_selected.connect(_on_change)
	global_light.item_selected.connect(_on_global_light_change)
	global_light.item_selected.connect(_on_change)
	fog_type.item_selected.connect(_on_fog_type_change)
	fog_type.item_selected.connect(_on_change)
	ssao.toggled.connect(_on_ssao_env_change)
	ssao.toggled.connect(_on_change)
	ssil.toggled.connect(_on_ssil_change)
	ssil.toggled.connect(_on_change)
	sdfgi.toggled.connect(_on_sdfgi_change)
	sdfgi.toggled.connect(_on_change)

	_read_current_settings()
	preset.select(1)
	

func _process(delta: float) -> void:
	show_progress = clampf(move_toward(show_progress, show_target, delta * speed), 0.0, 1.0)
	if show_progress == 0.0:
		$Control.hide()
	$Control.modulate = modulate(show_progress)
	

func ease_show():
	$Control.show()
	show_target = 1.0

func ease_hide():
	show_target = 0.0

# ----------------------- READ CURRENT -----------------------
func _read_current_settings():
	vsync.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED

	var env = get_tree().get_nodes_in_group("environment")[0].environment
	fog_type.select(int(env.volumetric_fog_enabled))
	ssao.button_pressed = env.ssao_enabled
	ssil.button_pressed = env.ssil_enabled
	sdfgi.button_pressed = env.sdfgi_enabled

# ----------------------- PRESET -----------------------
func _on_preset_selected(idx):
	if idx == 4: return
	apply_preset(PRESETS[idx])

func apply_preset(p):
	suppress_change = true
	for key in p.keys():
		_apply_setting(key, p[key])
	suppress_change = false
	preset.select(preset.get_selected())

func _apply_setting(key, val):
	match key:
		"vsync": _on_vsync_change(val)
		"aa": _on_aa_change(val)
		"snow": _on_snow_change(val)
		"fog_type": _on_fog_type_change(val)
		"ssao": _on_ssao_env_change(val)
		"ssil": _on_ssil_change(val)
		"sdfgi": _on_sdfgi_change(val)
		"global_light": _on_global_light_change(val)
		"anisotropy": _on_anisotropy_change(val)
		_:
			print("Unimplemented preset key: ", key)

func _on_change(_value = null):
	if suppress_change: return
	preset.select(4)

# ----------------------- VSYNC -----------------------
func _on_vsync_change(value):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
	vsync.button_pressed = value

# ----------------------- SNOW -----------------------
func _on_snow_change(idx):
	var amount
	match idx:
		0: amount = 100
		1: amount = 10000
		2: amount = 20000
		3: amount = 30000
		4: amount = 40000
	for p in get_tree().get_nodes_in_group("snow_particles"):	
		p.amount = amount
	snow.select(idx)

# ----------------------- AA -----------------------
func _on_aa_change(idx):
	get_viewport().msaa_3d = idx

# ----------------------- ANISOTROPY -----------------------
func _on_anisotropy_change(idx):
	get_viewport().anisotropic_filtering_level = idx

# ----------------------- ENVIRONMENT -----------------------
func _on_fog_type_change(idx):
	var env = get_tree().get_nodes_in_group("environment")[0].environment
	env.volumetric_fog_enabled = (idx == 1)
	env.fog_enabled = (idx == 0)

func _on_ssao_env_change(value):
	get_tree().get_nodes_in_group("environment")[0].environment.ssao_enabled = value

func _on_ssil_change(value):
	get_tree().get_nodes_in_group("environment")[0].environment.ssil_enabled = value

func _on_sdfgi_change(value):
	get_tree().get_nodes_in_group("environment")[0].environment.sdfgi_enabled = value

# ----------------------- GLOBAL LIGHT -----------------------
func _on_global_light_change(idx):
	var light : DirectionalLight3D = get_tree().get_nodes_in_group("global_light")[0]
	light.directional_shadow_mode = idx
	_on_change()
