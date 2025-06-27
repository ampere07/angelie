extends CharacterBody2D

const JUMP_FORCE = 400.0
const BASE_JUMP_TIME = 0.8  # Starting jump time
const MIN_JUMP_TIME = 0.2   # Fastest jump time
const JUMP_TIME_DECREASE = 0.1  # How much faster each level
const FALL_GRAVITY = 980.0  # Gravity when falling after game over

var current_jump_time = BASE_JUMP_TIME
var is_jumping = false
var on_left_wall = true  # Start on left wall
var jump_timer = 0.0
var game_started = false
var first_jump = true  # Track if this is the very first jump
var is_falling = false  # NEW: Track if player is falling (game over)

# Positions
var left_wall_x = 55.0      # Left wall X position
var right_wall_x = 415.0    # Right wall X position
var bottom_y = 700          # Bottom Y position

# Signal to tell main scene that game started
signal game_started_signal

func _ready():
	# Set up input action if not already done
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		var event = InputEventKey.new()
		event.keycode = KEY_SPACE
		InputMap.action_add_event("jump", event)
	
	# Start at LEFT SIDE, BOTTOM
	position.x = left_wall_x
	position.y = bottom_y
	
	print("Press SPACEBAR to start!")

func _physics_process(delta):
	# If falling (game over), just apply gravity and don't reset position
	if is_falling:
		velocity.y += FALL_GRAVITY * delta
		velocity.x = 0  # No horizontal movement while falling
		move_and_slide()
		return  # Don't do anything else, let player fall
	
	# Handle jumping - ONLY if not already jumping (ignore spam)
	if Input.is_action_just_pressed("jump"):
		if not is_jumping:  # Only jump if not already jumping
			if not game_started:
				# FIRST JUMP - START THE GAME!
				start_first_jump()
			else:
				# Regular jump between walls
				jump_to_other_wall()
		# If already jumping, ignore the input (no glitching)
	
	# Handle jump animation
	if is_jumping:
		jump_timer += delta
		
		# Calculate jump progress (0 to 1)
		var progress = jump_timer / current_jump_time
		
		if progress >= 1.0:
			# Jump finished
			is_jumping = false
			jump_timer = 0.0
			
			if first_jump:
				# First jump complete - now at right wall
				first_jump = false
				game_started = true
				on_left_wall = false  # Now on right wall
				position.x = right_wall_x
				position.y = bottom_y
			else:
				# Regular jump complete - snap to correct wall
				if on_left_wall:
					position.x = left_wall_x
				else:
					position.x = right_wall_x
				position.y = bottom_y
		else:
			# During jump animation
			if first_jump:
				# First jump: from left to right
				position.x = lerp(left_wall_x, right_wall_x, progress)
				position.y = bottom_y
			else:
				# Regular jump: between current walls
				var start_x = right_wall_x if on_left_wall else left_wall_x
				var end_x = left_wall_x if on_left_wall else right_wall_x
				position.x = lerp(start_x, end_x, progress)
				position.y = bottom_y
	else:
		# Not jumping - stay on current wall (ONLY if not falling)
		if not game_started:
			# Before game starts - stay at left
			position.x = left_wall_x
			position.y = bottom_y
		else:
			# During game - stay on current wall
			if on_left_wall:
				position.x = left_wall_x
			else:
				position.x = right_wall_x
			position.y = bottom_y
	
	# Apply physics movement
	move_and_slide()

func start_first_jump():
	# Start the first jump animation (left to right)
	is_jumping = true
	jump_timer = 0.0
	first_jump = true
	
	# Tell main scene to start the game
	emit_signal("game_started_signal")
	print("Starting first jump to right wall!")

func jump_to_other_wall():
	# Switch to opposite wall
	on_left_wall = !on_left_wall
	is_jumping = true
	jump_timer = 0.0
	
	print("Jumping to ", "left" if on_left_wall else "right", " wall")

# Called by main scene to update jump speed
func update_jump_speed():
	# Decrease jump time (make it faster) but don't go below minimum
	current_jump_time = max(MIN_JUMP_TIME, current_jump_time - JUMP_TIME_DECREASE)
	print("Jump time updated to: ", current_jump_time, " seconds")

# Add this function to PLAYER.GD - Better collision detection
func check_obstacle_collision():
	if is_falling or not game_started:
		return
		
	# Get all obstacles in the scene
	var obstacles = get_tree().get_nodes_in_group("obstacles")
	
	for obstacle in obstacles:
		if obstacle and is_instance_valid(obstacle):
			var player_pos = global_position
			var obstacle_pos = obstacle.global_position
			
			# Check if obstacle is near player vertically (within collision range)
			var vertical_distance = abs(player_pos.y - obstacle_pos.y)
			var horizontal_distance = abs(player_pos.x - obstacle_pos.x)
			
			# Collision detection with more generous bounds
			if vertical_distance < 40 and horizontal_distance < 40:
				print("COLLISION DETECTED! Player: ", player_pos, " Obstacle: ", obstacle_pos)
				print("Vertical distance: ", vertical_distance, " Horizontal distance: ", horizontal_distance)
				# Signal main scene
				get_parent().trigger_game_over()
				return

# NEW: Called by main scene when game over
func start_falling():
	is_falling = true
	is_jumping = false  # Stop any current jump
	velocity.y = 0  # Reset vertical velocity
	print("Player started falling - Game Over!")
