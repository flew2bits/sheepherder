extends CharacterBody2D

var speed = 50
var hi_speed = 200

var running = false

var running_timer = 0
var max_running_time = 5

var recovery_time = 2
var recovery_timer = 0

signal bark(location: Vector2)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _input(event: InputEvent):
	if event.is_action_pressed("run"):
		running = true
		running_timer = 0
	elif event.is_action_released("run"):
		running = false
		
	if event.is_action_pressed("emote"):
		bark.emit(global_position)
		
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_speed = hi_speed if running and running_timer < max_running_time else speed
	
	velocity = direction * move_speed
	
	running_timer = 0
	
	if running:
		running_timer = clampf(running_timer + delta, 0, max_running_time)
	else:
		running_timer = clampf(running_timer - delta, 0, max_running_time)
	
	move_and_slide()
