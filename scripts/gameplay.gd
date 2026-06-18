extends Node2D

enum State {
	SAILING,
	CASTING,
	SINKING,
	RETRIEVE,
	STRIKE,
	RESULT
}

#var current_stateaeda = State.SAILING
#
#@onready var lure = $Lure
#
## Variable Casting Joran Pancing
#var cast_power := 0.0
#var max_cast_power := 600.0
#var charging := false
#
## Hold Space Untuk Mulai Casting
#func _process(delta):
	#if current_state != State.SAILING:
		#return
	#
	#if Input.is_action_just_pressed("cast"):
		#charging = true
		#cast_power = 0
	#
	#if Input.is_action_just_pressed("cast") and charging:
		#cast_power += 500 * delta
		#cast_power =  min(cast_power, max_cast_power)
	#
	#if Input.is_action_just_released("cast") and charging:
		#charging = false
		#start_cast()
#
## Mulai Casting
#func start_cast():
	#current_state = State.CASTING
	#
	#lure.global_position = $Boat.global_position
	#
	#lure.velocity = Vector2(
		#cast_power,
		#-200
	#)
	#
	#await get_tree().create_timer(0.5).timeout
	#
	#current_state = State.SINKING
	#
	#lure.velocity = Vector2.ZERO
	#lure.is_sinking = true
