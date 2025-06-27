extends Node2D

const BASE_SCROLL_SPEED = 250.0
const SPEED_INCREASE = 20.0
var current_scroll_speed = BASE_SCROLL_SPEED

var left_wall
var right_wall

var left_obstacle_scene = preload("res://Scenes/LeftObstacle.tscn")
var right_obstacle_scene = preload("res://Scenes/RightObstacle.tscn")
var obstacles = []
var obstacle_spawn_timer = 0.0
var base_obstacle_spawn_time = 2.0
var current_obstacle_spawn_time = 2.0
const MIN_OBSTACLE_SPAWN_TIME = 0.5

var obstacle_animations = ["obstacle1", "obstacle2", "obstacle3"]

var score_label
var start_label
var game_over_label
var player
var score = 0
var score_timer = 0.0
var game_started = false
var game_over_state = false
var last_speed_update = 0
var game_over_timer = 0.0

var score_fx_audio
var jump_fx_audio
var bg_music_audio
var gameover_fx_audio

func _ready():
	left_wall = $LeftWall
	right_wall = $RightWall
	
	score_fx_audio = $"100ScoreFx"
	if not score_fx_audio:
		print("Warning: Could not find 100ScoreFx audio node!")
	
	jump_fx_audio = $"JumpFx"
	if not jump_fx_audio:
		print("Warning: Could not find JumpFx audio node!")
	
	bg_music_audio = $"BgMusic"
	if not bg_music_audio:
		print("Warning: Could not find BgMusic audio node!")
	
	gameover_fx_audio = $"Gameover"
	if not gameover_fx_audio:
		print("Warning: Could not find Gameover audio node!")
	else:
		print("Game over sound effect found successfully!")
	
	player = find_child("CharacterBody2D", true, false)
	if not player:
		player = find_child("Player", true, false)
	if not player:
		for child in get_children():
			if child is CharacterBody2D:
				player = child
				break
	
	if player and player.has_signal("game_started_signal"):
		player.game_started_signal.connect(_on_game_started)
		print("Player signal connected successfully!")
	else:
		print("Warning: Could not find player or signal!")
	
	create_ui()
	
	print("Game initialized with animated obstacles!")

func create_obstacle(from_left_wall: bool):
	var obstacle
	if from_left_wall:
		obstacle = left_obstacle_scene.instantiate()
		obstacle.position = Vector2(70, -100)
	else:
		obstacle = right_obstacle_scene.instantiate()
		obstacle.position = Vector2(419, -100) 
	
	set_random_obstacle_animation(obstacle)
	
	obstacle.add_to_group("obstacles")
	
	add_child(obstacle)
	obstacles.append(obstacle)
	
	print("Animated obstacle spawned on ", "left" if from_left_wall else "right", " side")

func set_random_obstacle_animation(obstacle):
	var animated_sprite = obstacle.get_node("AnimatedSprite2D")
	if not animated_sprite:
		animated_sprite = obstacle.find_child("AnimatedSprite2D", true, false)
	
	if animated_sprite and animated_sprite is AnimatedSprite2D:
		var random_index = randi() % obstacle_animations.size()
		var chosen_animation = obstacle_animations[random_index]
		
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(chosen_animation):
			animated_sprite.animation = chosen_animation
			animated_sprite.play()
			print("Set obstacle animation to: ", chosen_animation)
		else:
			print("Warning: Animation '", chosen_animation, "' not found in obstacle!")
			if animated_sprite.sprite_frames and animated_sprite.sprite_frames.get_animation_names().size() > 0:
				var fallback_anim = animated_sprite.sprite_frames.get_animation_names()[0]
				animated_sprite.animation = fallback_anim
				animated_sprite.play()
				print("Using fallback animation: ", fallback_anim)
	else:
		print("Warning: Could not find AnimatedSprite2D in obstacle!")
		print("Obstacle children: ")
		for child in obstacle.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")

func trigger_game_over():
	game_over_state = true
	
	stop_all_sounds()
	
	play_gameover_sound()
	
	if player and player.has_method("start_falling"):
		player.start_falling()
	
	show_game_over_ui()
	
	print("Final Score: ", score)

func stop_all_sounds():
	print("Stopping all sound effects...")
	
	if score_fx_audio and score_fx_audio.is_playing():
		score_fx_audio.stop()
		print("Stopped score milestone sound")
	
	if jump_fx_audio and jump_fx_audio.is_playing():
		jump_fx_audio.stop()
		print("Stopped jump sound")
	
	if bg_music_audio and bg_music_audio.is_playing():
		bg_music_audio.stop()
		print("Stopped background music")
	
	stop_all_audio_children(self)

func stop_all_audio_children(node):
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			if child.is_playing():
				child.stop()
				print("Stopped audio node: ", child.name)
		
		if child.get_child_count() > 0:
			stop_all_audio_children(child)

func show_game_over_ui():
	var game_over_panel = Panel.new()
	game_over_panel.size = Vector2(400, 400)
	game_over_panel.position = Vector2(50, 250)
	game_over_panel.add_theme_color_override("bg_color", Color(0, 0, 0, 0.8))
	$UI.add_child(game_over_panel)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(360, 260)
	game_over_panel.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = "GAME OVER"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color.RED)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)
	
	var score_label_go = Label.new()
	score_label_go.text = "Final Score: " + str(score)
	score_label_go.add_theme_font_size_override("font_size", 32)
	score_label_go.add_theme_color_override("font_color", Color.WHITE)
	score_label_go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label_go)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer2)
	
	var restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.add_theme_font_size_override("font_size", 24)
	restart_button.custom_minimum_size = Vector2(200, 50)
	restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_button)
	
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer3)
	
	var main_menu_button = Button.new()
	main_menu_button.text = "MAIN MENU"
	main_menu_button.add_theme_font_size_override("font_size", 24)
	main_menu_button.custom_minimum_size = Vector2(200, 50)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(main_menu_button)

func _on_restart_pressed():
	print("Restarting game...")
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	print("Going to main menu...")
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func create_ui():
	var ui_control = Control.new()
	ui_control.name = "UI"
	add_child(ui_control)
	
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.position = Vector2(330, 20)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.visible = false
	ui_control.add_child(score_label)
	
	start_label = Label.new()
	start_label.text = "Press SPACEBAR to Start!"
	start_label.position = Vector2(80, 350)
	start_label.add_theme_font_size_override("font_size", 28)
	start_label.add_theme_color_override("font_color", Color.BLACK)
	ui_control.add_child(start_label)

func _process(delta):
	if game_over_state:
		return
	
	if not game_started and player and player.has_method("get") and player.get("game_started"):
		_on_game_started()
	
	if not game_started:
		return
	
	check_obstacle_collisions()
	
	
	move_obstacles(delta)
	
	spawn_obstacles(delta)
	
	score_timer += delta
	if score_timer >= 0.1:
		var old_score = score
		score += 1
		score_label.text = "Score: " + str(score)
		score_timer = 0.0
		
		var old_milestone = old_score / 100
		var new_milestone = score / 100
		
		if new_milestone > old_milestone and score > 0:
			play_score_milestone_sound()
			print("Score milestone reached: ", score, " points!")
		
		var current_level = score / 100
		if current_level > last_speed_update:
			increase_speed()
			last_speed_update = current_level

func check_obstacle_collisions():
	if not player or game_over_state:
		return
		
	var player_pos = player.global_position
	var player_size = 24
	
	for obstacle in obstacles:
		if obstacle and is_instance_valid(obstacle):
			var obstacle_pos = obstacle.global_position
			var obstacle_size = 30
			
			var distance = player_pos.distance_to(obstacle_pos)
			var collision_distance = (player_size + obstacle_size) / 2
			
			if distance < collision_distance:
				print("COLLISION! Player hit animated obstacle at: ", obstacle_pos)
				trigger_game_over()
				return

func move_obstacles(delta):
	if game_over_state:
		return
		
	for i in range(obstacles.size() - 1, -1, -1):
		var obstacle = obstacles[i]
		if obstacle and is_instance_valid(obstacle):
			obstacle.position.y += current_scroll_speed * delta
			
			var animated_sprite = obstacle.get_node_or_null("AnimatedSprite2D")
			if not animated_sprite:
				animated_sprite = obstacle.find_child("AnimatedSprite2D", true, false)
			
			if animated_sprite and animated_sprite is AnimatedSprite2D:
				if not animated_sprite.is_playing():
					animated_sprite.play()
			
			if obstacle.position.y > 900:
				obstacle.queue_free()
				obstacles.remove_at(i)
				print("Obstacle removed from screen")

func spawn_obstacles(delta):
	if game_over_state:
		return
		
	obstacle_spawn_timer += delta
	
	if obstacle_spawn_timer >= current_obstacle_spawn_time:
		var from_left = randf() < 0.5
		create_obstacle(from_left)
		obstacle_spawn_timer = 0.0

func increase_speed():
	current_scroll_speed += SPEED_INCREASE
	
	current_obstacle_spawn_time = max(MIN_OBSTACLE_SPAWN_TIME, current_obstacle_spawn_time - 0.1)
	
	if player and player.has_method("update_jump_speed"):
		player.update_jump_speed()
	
	print("Speed increased! Level: ", last_speed_update + 1, " - Obstacle Speed: ", current_scroll_speed, " - Obstacle Spawn: ", current_obstacle_spawn_time)

func play_score_milestone_sound():
	if score_fx_audio and score_fx_audio is AudioStreamPlayer2D:
		score_fx_audio.play()
		print("Playing score milestone sound effect!")
	elif score_fx_audio and score_fx_audio is AudioStreamPlayer:
		score_fx_audio.play()
		print("Playing score milestone sound effect!")
	else:
		print("Warning: Score sound effect not found or wrong type!")

func play_gameover_sound():
	if gameover_fx_audio and gameover_fx_audio is AudioStreamPlayer2D:
		gameover_fx_audio.play()
		print("Playing game over sound effect!")
	elif gameover_fx_audio and gameover_fx_audio is AudioStreamPlayer:
		gameover_fx_audio.play()
		print("Playing game over sound effect!")
	else:
		print("Warning: Game over sound effect not found or wrong type!")

func _on_game_started():
	game_started = true
	start_label.visible = false
	score_label.visible = true
	print("Main scene: Game started with animated obstacles!")
