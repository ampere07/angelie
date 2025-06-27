extends Node2D

const BASE_SCROLL_SPEED = 150.0
const SPEED_INCREASE = 20.0
var current_scroll_speed = BASE_SCROLL_SPEED

# Original walls
var left_wall
var right_wall

# Additional wall segments for infinite scrolling
var extra_left_segments = []
var extra_right_segments = []
const WALL_SEGMENT_HEIGHT = 400
const WALL_WIDTH = 40
var next_wall_y = -800

# Obstacle system - using scene files
var left_obstacle_scene = preload("res://Scenes/LeftObstacle.tscn")
var right_obstacle_scene = preload("res://Scenes/RightObstacle.tscn")
var obstacles = []
var obstacle_spawn_timer = 0.0
var base_obstacle_spawn_time = 2.0
var current_obstacle_spawn_time = 2.0
const MIN_OBSTACLE_SPAWN_TIME = 0.5

# Game state
var score_label
var start_label
var game_over_label
var player
var score = 0
var score_timer = 0.0
var game_started = false
var game_over_state = false  # NEW: Track if game is over
var last_speed_update = 0
var game_over_timer = 0.0    # NEW: Timer for game over delay

func _ready():
	# Get references to existing walls
	left_wall = $LeftWall
	right_wall = $RightWall
	
	# Find the player node
	player = find_child("CharacterBody2D", true, false)
	if not player:
		player = find_child("Player", true, false)
	if not player:
		for child in get_children():
			if child is CharacterBody2D:
				player = child
				break
	
	# Store original positions
	if left_wall:
		left_wall.set_meta("original_y", left_wall.position.y)
	if right_wall:
		right_wall.set_meta("original_y", right_wall.position.y)
	
	# Connect player signal
	if player and player.has_signal("game_started_signal"):
		player.game_started_signal.connect(_on_game_started)
		print("Player signal connected successfully!")
	else:
		print("Warning: Could not find player or signal!")
	
	# Generate additional wall segments for infinite scrolling
	generate_extra_walls()
	
	# Create UI
	create_ui()

func generate_extra_walls():
	# Generate extra wall segments above and below the original walls
	for i in range(20):
		create_extra_wall_segment(next_wall_y - (i * WALL_SEGMENT_HEIGHT))

func create_extra_wall_segment(y_position):
	# Create left wall segment - 40px width
	var left_segment = StaticBody2D.new()
	left_segment.name = "ExtraLeftWall_" + str(extra_left_segments.size())
	
	var left_rect = ColorRect.new()
	left_rect.size = Vector2(WALL_WIDTH, WALL_SEGMENT_HEIGHT)
	left_rect.color = Color.CYAN
	left_rect.position = Vector2(0, 0)
	
	var left_collision = CollisionShape2D.new()
	var left_shape = RectangleShape2D.new()
	left_shape.size = Vector2(WALL_WIDTH, WALL_SEGMENT_HEIGHT)
	left_collision.shape = left_shape
	left_collision.position = Vector2(WALL_WIDTH/2, WALL_SEGMENT_HEIGHT/2)
	
	left_segment.add_child(left_rect)
	left_segment.add_child(left_collision)
	left_segment.position = Vector2(0, y_position)
	
	add_child(left_segment)
	extra_left_segments.append(left_segment)
	
	# Create right wall segment - 40px width
	var right_segment = StaticBody2D.new()
	right_segment.name = "ExtraRightWall_" + str(extra_right_segments.size())
	
	var right_rect = ColorRect.new()
	right_rect.size = Vector2(WALL_WIDTH, WALL_SEGMENT_HEIGHT)
	right_rect.color = Color.CYAN
	right_rect.position = Vector2(0, 0)
	
	var right_collision = CollisionShape2D.new()
	var right_shape = RectangleShape2D.new()
	right_shape.size = Vector2(WALL_WIDTH, WALL_SEGMENT_HEIGHT)
	right_collision.shape = right_shape
	right_collision.position = Vector2(WALL_WIDTH/2, WALL_SEGMENT_HEIGHT/2)
	
	right_segment.add_child(right_rect)
	right_segment.add_child(right_collision)
	right_segment.position = Vector2(460, y_position)
	
	add_child(right_segment)
	extra_right_segments.append(right_segment)

func create_obstacle(from_left_wall: bool):
	# Instance the appropriate obstacle scene
	var obstacle
	if from_left_wall:
		obstacle = left_obstacle_scene.instantiate()
		obstacle.position = Vector2(70, -100)  # Better left side position
	else:
		obstacle = right_obstacle_scene.instantiate()
		obstacle.position = Vector2(419, -100)  # Better right side position
	
	# Add to obstacles group for easy detection
	obstacle.add_to_group("obstacles")
	
	add_child(obstacle)
	obstacles.append(obstacle)
	
	print("Obstacle spawned on ", "left" if from_left_wall else "right", " side at position: ", obstacle.position)

# Remove the old collision function since we're not using Area2D signals
# func _on_obstacle_hit_player(obstacle, body):

func trigger_game_over():
	game_over_state = true
	
	# Tell player to start falling
	if player and player.has_method("start_falling"):
		player.start_falling()
	
	# Show game over UI
	show_game_over_ui()
	
	print("Final Score: ", score)

func show_game_over_ui():
	# Create game over panel
	var game_over_panel = Panel.new()
	game_over_panel.size = Vector2(400, 400)
	game_over_panel.position = Vector2(50, 250)
	game_over_panel.add_theme_color_override("bg_color", Color(0, 0, 0, 0.8))  # Semi-transparent black
	$UI.add_child(game_over_panel)
	
	# Create vertical container for layout
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(360, 260)
	game_over_panel.add_child(vbox)
	
	# Game Over title
	var title_label = Label.new()
	title_label.text = "GAME OVER"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color.RED)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Add spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)
	
	# Score label
	var score_label_go = Label.new()
	score_label_go.text = "Final Score: " + str(score)
	score_label_go.add_theme_font_size_override("font_size", 32)
	score_label_go.add_theme_color_override("font_color", Color.WHITE)
	score_label_go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label_go)
	
	# Add spacing
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer2)
	
	# Restart button
	var restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.add_theme_font_size_override("font_size", 24)
	restart_button.custom_minimum_size = Vector2(200, 50)
	restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_button)
	
	# Add spacing
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer3)
	
	# Main Menu button
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
	# You can change this to load your main menu scene
	# get_tree().change_scene_to_file("res://MainMenu.tscn")
	get_tree().reload_current_scene()  # For now, just restart

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
	# Don't process game input during game over, but still allow falling
	if game_over_state:
		return  # Game over - don't process walls/obstacles/score
	
	if not game_started and player and player.has_method("get") and player.get("game_started"):
		_on_game_started()
	
	if not game_started:
		return
	
	# Check for player-obstacle collisions
	check_obstacle_collisions()
	
	# Move original walls (only if game not over)
	if left_wall:
		left_wall.position.y += current_scroll_speed * delta
		if left_wall.get_node("ColorRect"):
			var wall_height = left_wall.get_node("ColorRect").size.y
			if left_wall.position.y > 800 + wall_height:
				left_wall.position.y = left_wall.get_meta("original_y") - wall_height
	
	if right_wall:
		right_wall.position.y += current_scroll_speed * delta
		if right_wall.get_node("ColorRect"):
			var wall_height = right_wall.get_node("ColorRect").size.y
			if right_wall.position.y > 800 + wall_height:
				right_wall.position.y = right_wall.get_meta("original_y") - wall_height
	
	# Move extra wall segments
	for segment in extra_left_segments:
		if segment and is_instance_valid(segment):
			segment.position.y += current_scroll_speed * delta
	
	for segment in extra_right_segments:
		if segment and is_instance_valid(segment):
			segment.position.y += current_scroll_speed * delta
	
	# Move obstacles (only if game not over)
	move_obstacles(delta)
	
	# Spawn obstacles (only if game not over)
	spawn_obstacles(delta)
	
	# Manage extra segments
	manage_extra_segments()
	
	# Update score
	score_timer += delta
	if score_timer >= 0.1:
		score += 1
		score_label.text = "Score: " + str(score)
		score_timer = 0.0
		
		var current_level = score / 100
		if current_level > last_speed_update:
			increase_speed()
			last_speed_update = current_level

func check_obstacle_collisions():
	# Check collision between player and obstacles using distance
	if not player or game_over_state:
		return
		
	var player_pos = player.global_position
	var player_size = 24  # Player size
	
	for obstacle in obstacles:
		if obstacle and is_instance_valid(obstacle):
			var obstacle_pos = obstacle.global_position
			var obstacle_size = 30  # Obstacle size
			
			# Calculate distance between centers
			var distance = player_pos.distance_to(obstacle_pos)
			var collision_distance = (player_size + obstacle_size) / 2
			
			# Check if they're overlapping
			if distance < collision_distance:
				print("COLLISION! Player at: ", player_pos, " Obstacle at: ", obstacle_pos, " Distance: ", distance)
				trigger_game_over()
				return

func move_obstacles(delta):
	# Move all obstacles downward only (stop if game over)
	if game_over_state:
		return
		
	for i in range(obstacles.size() - 1, -1, -1):
		var obstacle = obstacles[i]
		if obstacle and is_instance_valid(obstacle):
			# Move obstacle down with the same speed as walls
			obstacle.position.y += current_scroll_speed * delta
			
			# Remove obstacle if it goes off screen
			if obstacle.position.y > 900:
				obstacle.queue_free()
				obstacles.remove_at(i)

func spawn_obstacles(delta):
	# Don't spawn obstacles if game is over
	if game_over_state:
		return
		
	# Countdown to next obstacle spawn
	obstacle_spawn_timer += delta
	
	if obstacle_spawn_timer >= current_obstacle_spawn_time:
		# Spawn new obstacle from random wall
		var from_left = randf() < 0.5  # 50% chance from each wall
		create_obstacle(from_left)
		obstacle_spawn_timer = 0.0

func manage_extra_segments():
	# Remove segments that are too far down
	for i in range(extra_left_segments.size() - 1, -1, -1):
		var segment = extra_left_segments[i]
		if segment and is_instance_valid(segment) and segment.position.y > 1200:
			segment.queue_free()
			extra_left_segments.remove_at(i)
	
	for i in range(extra_right_segments.size() - 1, -1, -1):
		var segment = extra_right_segments[i]
		if segment and is_instance_valid(segment) and segment.position.y > 1200:
			segment.queue_free()
			extra_right_segments.remove_at(i)
	
	# Add new segments at the top if needed (only if game not over)
	if not game_over_state:
		while extra_left_segments.size() < 25:
			next_wall_y -= WALL_SEGMENT_HEIGHT
			create_extra_wall_segment(next_wall_y)

func increase_speed():
	current_scroll_speed += SPEED_INCREASE
	
	# Make obstacles spawn faster (more frequent)
	current_obstacle_spawn_time = max(MIN_OBSTACLE_SPAWN_TIME, current_obstacle_spawn_time - 0.1)
	
	if player and player.has_method("update_jump_speed"):
		player.update_jump_speed()
	
	print("Speed increased! Level: ", last_speed_update + 1, " - Scroll Speed: ", current_scroll_speed, " - Obstacle Spawn: ", current_obstacle_spawn_time)

func _on_game_started():
	game_started = true
	start_label.visible = false
	score_label.visible = true
	print("Main scene: Game started!")
