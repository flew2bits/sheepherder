extends CharacterBody2D


@export_range(90, 360) var field_of_view: float = 320.0
@export_range(0, 500, 0.01, "or_greater") var sight_distance: float = 200.0
@export var looking: bool = false

@export var max_speed: float = 45
@export var acceleration: float = 30
@export var deceleration: float = 60
@export var turningSpeed: float = deg_to_rad(30)
@export var panicTurningSpeed: float = deg_to_rad(90)

var can_see_dot_product: float

var fear: float = 0.0

const MIN_FEAR: float = 0.0
const MAX_FEAR: float = 5.0
const FEAR_SCALE: float = 200.0
const FEAR_DECAY: float = 1.25

const HALF_PI = PI / 2


var check_rate = 2
var check_timer = 0
var speed = 0

var tween: Tween

var in_corner_flag = false
var corner_turn: float

# add in exhaustion...

@onready var vision: Area2D = $Vision
@onready var vision_region = $Vision/VisionRegion
@onready var label_container = $LabelContainer
@onready var label = $LabelContainer/Label

@onready var right_ray_cast: RayCast2D = $RightRayCast
@onready var left_ray_cast: RayCast2D = $LeftRayCast


@onready var separation_line = $LabelContainer/Separation
@onready var alignment_line = $LabelContainer/Alignment
@onready var cohesion_line = $LabelContainer/Cohesion
@onready var flocking_line = $LabelContainer/Flocking

var flee_fear: float
var fleeing: bool

# Called when the node enters the scene tree for the first time.
func _ready():
	can_see_dot_product = cos(deg_to_rad(field_of_view / 2))
	var shape : CircleShape2D = vision_region.shape
	shape.radius = sight_distance
	right_ray_cast.target_position.y = sight_distance
	left_ray_cast.target_position.y = sight_distance
	
	var dog = get_tree().get_first_node_in_group("dog")
	if dog:
		dog.bark.connect(heard_dog_bark)
	
	pass # Replace with function body.

func heard_dog_bark(location: Vector2):
	if fleeing: return
	
	print("heard dog: ", location)
	var distance = global_position.distance_squared_to(location)
	var panic_intensity = 25000/distance
	print(panic_intensity)
	if panic_intensity < 1: return
	
	
	var tween = create_tween()
	flee_fear = MAX_FEAR
	tween.tween_property(self, "flee_fear", MAX_FEAR, 2.5)
	tween.tween_property(self, "flee_fear", 0, 2.5)
	fleeing = true
	await tween.finished
	fleeing = false
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var in_vision_collider = vision.get_overlapping_bodies()
	var can_see = in_vision_collider.filter(in_field_of_view)

	var direction_away_from_dog = Vector2.ZERO
	
	var forward = Vector2.from_angle(rotation)
	var right = Vector2(forward.y, -forward.x)
	
	# separation: avoid collisions
	# cohesion: move towards center of cluster
	# alignment: move towards common direction
	
	
	# desired speed
	# fear = 0:
	#	no neighbors ahead -> 0
	# 	any neighbors ahead -> try to catch up to neighbors (i.e. forward . gp-oth.gp < 0)
	# fear > 0 -> max_speed
	
	# implement states
	#	PANIC / ESCAPE
	#	IDLE -> SCARE SELF / BOREDOM
	#	WANDER
	# DOG BARK
	
	var desired_speed = 0
	
	var separation = Vector2.ZERO
	var cohesion_target = global_position
	var cohesion_count = 1
	var alignment = Vector2.from_angle(rotation)
	
	var can_see_dog = false

	for see in can_see:
		if see.is_in_group("dog"):
			fear = clampf(fear + FEAR_SCALE / see.global_position.distance_squared_to(global_position), MIN_FEAR, MAX_FEAR)
			direction_away_from_dog = see.global_position.direction_to(global_position)
			can_see_dog = true
		elif see.is_in_group("sheep"):
			var direction_away_from_other = see.global_position.direction_to(global_position)
			
			cohesion_target += see.global_position
			cohesion_count += 1
			alignment += Vector2.from_angle(see.rotation)
			separation += 1000 / see.global_position.distance_squared_to(global_position) * direction_away_from_other
			
			var other_dot_product = forward.dot(-direction_away_from_other)
			if other_dot_product > 0.707:
				desired_speed = max(desired_speed, max_speed * see.fear / 5)
				#desired_speed = max_speed
			elif other_dot_product <= 0.707 and other_dot_product > -0.4:
				desired_speed = max(desired_speed, see.speed - 2)
#			fear = clampf(fear + 0.05 * see.fear, MIN_FEAR, MAX_FEAR)

			
	var cohesion = global_position.direction_to(cohesion_target / cohesion_count)
	
	separation_line.visible = separation != Vector2.ZERO
	separation_line.rotation = separation.angle()
	
	alignment_line.rotation = alignment.angle()
	
	cohesion_line.visible = cohesion_count > 1
	cohesion_line.rotation = cohesion.angle()
			
	var flocking_direction = ( alignment + cohesion + separation).normalized()
	
		
	var total_fear = clampf(fear + flee_fear, MIN_FEAR, MAX_FEAR)
			
	var desired_direction = (flocking_direction + total_fear * direction_away_from_dog).normalized()
	
	
	
	var desired_rotation = desired_direction.angle() if desired_direction != Vector2.ZERO else rotation

	var is_panicked = false
	
	if not can_see_dog:
		var left_ray = left_ray_cast.is_colliding()
		var right_ray = right_ray_cast.is_colliding()
		
		if left_ray and right_ray: 
			if in_corner_flag:
				desired_rotation += corner_turn
				is_panicked = true
			else :
				var in_corner = left_ray_cast.get_collider() != right_ray_cast.get_collider()

				
					# we're in a corner
				var left_distance_squared = global_position.distance_squared_to(left_ray_cast.get_collision_point())
				var right_distance_squared = global_position.distance_squared_to(right_ray_cast.get_collision_point())
				
				if in_corner:
					in_corner_flag = true
					corner_turn = HALF_PI
				
				var distance_diff = right_distance_squared - left_distance_squared
				if in_corner: distance_diff = -distance_diff
				
				if distance_diff > 0:
					right_ray = false
				else:
					left_ray = false
				
				is_panicked = right_distance_squared < 125 or left_distance_squared < 125
		else:
			in_corner_flag = false
			
		if right_ray: desired_rotation -= HALF_PI
		elif left_ray: desired_rotation += HALF_PI
	
	flocking_line.rotation = desired_rotation
	desired_direction = Vector2.from_angle(desired_rotation)
	
	var turn_left = right.dot(desired_direction) >= 0
	
	fear = clampf(fear - FEAR_DECAY * delta, MIN_FEAR, MAX_FEAR)

	
	desired_speed = max_speed if total_fear > 0 or is_panicked else desired_speed
	
	if fear > 0:
		speed = clampf(speed + acceleration * delta,0,desired_speed)
		velocity = speed * forward
	else:
		desired_speed -= 5 * delta
		if desired_speed < 5: desired_speed = 0
		speed = clampf(speed - deceleration * delta, desired_speed - delta * deceleration, max_speed)
		speed = max(0, speed)

		velocity = speed * forward


	var turn_speed = panicTurningSpeed if fear > 3 or is_panicked else turningSpeed

	if abs(desired_rotation - rotation) > deg_to_rad(1):
		if turn_left:
			rotation -= turn_speed * delta
		else:
			rotation += turn_speed * delta
			

	
	label.text = "%1.1f" %  total_fear
	label_container.rotation = -rotation
		
		
func _physics_process(delta):
	move_and_slide()

func in_field_of_view(other: Node2D) -> bool:
	if other == self: return false
	var direction_to_other = global_position.direction_to(other.global_position)
	var pointing = Vector2.from_angle(rotation)
	var dot_product = direction_to_other.dot(pointing)
	return dot_product >= can_see_dot_product
