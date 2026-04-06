extends Node3D


func _ready() -> void:
	$AnimationPlayer.play("idle_2")
	$AudioStreamPlayer3D2.play()
