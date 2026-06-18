extends Node

func load_scene(path:String):
	get_tree().change_scene_to_file(path)
