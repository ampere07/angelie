extends Node2D

func _on_start_game_pressed() -> void:
	print("Starting game...")
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

func _on_quit_button_pressed() -> void:
	print("Quitting game...")
	get_tree().quit()
