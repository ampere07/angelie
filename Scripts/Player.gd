extends CharacterBody2D

const JUMP_FORCE = 400.0
const BASE_JUMP_TIME = 0.8
const MIN_JUMP_TIME = 0.2
const JUMP_TIME_DECREASE = 0.1
const FALL_GRAVITY = 980.0

var current_jump_time = BASE_JUMP_TIME
var is_jumping = false
var on_left_wall = true
var jump_timer = 0.0
var game_started = false
var first_jump = true
var is_falling = false

var left_wall_x = 55.0
var right_wall_x = 415.0
var bottom_y = 700

var animated_sprite
var current_animation = ""
var is_upside_down = false

var jump_fx_audio

signal game_started_signal

func _ready():
	animated_sprite = $AnimatedSprite2D
	
	jump_fx_audio = get_parent().get_node("JumpFx")
	if not jump_fx_audio:
		jump_fx_audio = get_parent().find_child("JumpFx", true, false)
	if not jump_fx_audio:
		print("Warning: Could not find JumpFx audio node!")
	else:
		print("Jump sound effect found successfully!")
	
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		var event = InputEventKey.new()
		event.keycode = KEY_SPACE
		InputMap.action_add_event("jump", event)
	
	position.x = left_wall_x
	position.y = bottom_y
	
	change_animation("idle")
	if animated_sprite:
		animated_sprite.flip_h = false
		animated_sprite.rotation = 0
		is_upside_down = false
	
	print("Press SPACEBAR to start!")

func _physics_process(delta):
	update_animation()
	
	if is_falling:
		velocity.y += FALL_GRAVITY * delta
		velocity.x = 0
		move_and_slide()
		return
	
	if Input.is_action_just_pressed("jump"):
		if not is_jumping:
			if not game_started:
				start_first_jump()
			else:
				jump_to_other_wall()
	
	if is_jumping:
		jump_timer += delta
		var progress = jump_timer / current_jump_time
		
		if progress >= 1.0:
			is_jumping = false
			jump_timer = 0.0
			
			if animated_sprite:
				animated_sprite.rotation = 0
				is_upside_down = false
			
			if first_jump:
				first_jump = false
				game_started = true
				on_left_wall = false
				position.x = right_wall_x
				position.y = bottom_y
			else:
				if on_left_wall:
					position.x = left_wall_x
				else:
					position.x = right_wall_x
				position.y = bottom_y
		else:
			if first_jump:
				position.x = lerp(left_wall_x, right_wall_x, progress)
				position.y = bottom_y
			else:
				var start_x = right_wall_x if on_left_wall else left_wall_x
				var end_x = left_wall_x if on_left_wall else right_wall_x
				position.x = lerp(start_x, end_x, progress)
				position.y = bottom_y
	else:
		if not game_started:
			position.x = left_wall_x
			position.y = bottom_y
		else:
			if on_left_wall:
				position.x = left_wall_x
			else:
				position.x = right_wall_x
			position.y = bottom_y
	
	move_and_slide()

func update_animation():
	var new_animation = ""
	
	if is_falling:
		new_animation = "jumping"
	elif is_jumping:
		new_animation = "jumping"
	elif not game_started:
		new_animation = "idle"
	else:
		new_animation = "running"
	
	change_animation(new_animation)

func change_animation(animation_name: String):
	if current_animation != animation_name and animated_sprite:
		current_animation = animation_name
		animated_sprite.play(animation_name)
		print("Animation changed to: ", animation_name)

func play_jump_sound():
	if jump_fx_audio and jump_fx_audio is AudioStreamPlayer2D:
		jump_fx_audio.play()
		print("Playing jump sound effect!")
	elif jump_fx_audio and jump_fx_audio is AudioStreamPlayer:
		jump_fx_audio.play()
		print("Playing jump sound effect!")
	else:
		print("Warning: Jump sound effect not found or wrong type!")

func start_first_jump():
	is_jumping = true
	jump_timer = 0.0
	first_jump = true
	
	play_jump_sound()
	
	set_facing_direction(false)
	
	do_upside_down_rotation()
	
	emit_signal("game_started_signal")
	print("Starting first jump!")

func jump_to_other_wall():
	on_left_wall = !on_left_wall
	is_jumping = true
	jump_timer = 0.0
	
	play_jump_sound()
	
	if on_left_wall:
		set_facing_direction(true)
	else:
		set_facing_direction(false)
	
	do_upside_down_rotation()
	
	print("Jumping to ", "left" if on_left_wall else "right", " wall")

func set_facing_direction(face_left: bool):
	if animated_sprite:
		if face_left:
			animated_sprite.rotation = -PI/2
			animated_sprite.flip_h = true
			print("Set for left wall jump: -90° rotation, flipped")
		else:
			animated_sprite.rotation = PI/2
			animated_sprite.flip_h = false 
			print("Set for right wall jump: 90° rotation, not flipped")

func do_upside_down_rotation():
	if animated_sprite:
		await get_tree().create_timer(0.1).timeout
		
		if is_upside_down:
			if animated_sprite.flip_h:
				animated_sprite.rotation = -PI/2
			else:
				animated_sprite.rotation = PI/2 
			is_upside_down = false
			print("Rotated back to wall-facing position")
		else:
			animated_sprite.rotation += PI
			is_upside_down = true
			print("Added 180° for upside-down effect, new rotation: ", animated_sprite.rotation)

func update_jump_speed():
	current_jump_time = max(MIN_JUMP_TIME, current_jump_time - JUMP_TIME_DECREASE)
	print("Jump time updated to: ", current_jump_time, " seconds")

func start_falling():
	is_falling = true
	is_jumping = false
	velocity.y = 0
	print("Player started falling - Game Over!")
