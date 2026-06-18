extends Control

func _on_start_buttton_pressed():
	get_tree().change_scene_to_file(
		"res://scenes/gameplay/gameplay.tscn"
	)

func _on_quit_button_pressed():
	get_tree().quit()
