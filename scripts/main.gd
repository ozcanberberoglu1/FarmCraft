extends Node3D
## Game scene root: world, player and HUD.

@onready var player: Player = $Player


func _ready() -> void:
	player.global_position = WorldLayout.PLAYER_SPAWN
	player.look_at_yaw_pitch(deg_to_rad(-70.0), deg_to_rad(-6.0))
	# Compiles the particle shaders now instead of on the first hoe or watering can.
	Fx.warm_up(player.global_position - player.global_basis.z * 2.0 + Vector3.UP)
	# A loaded game puts back what lives in the scene once everything is built.
	SaveGame.on_world_ready.call_deferred()
