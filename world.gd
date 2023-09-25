extends Node2D

var Sheep = preload("res://sheep.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(25):
		var sheep = Sheep.instantiate()
		sheep.global_position = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		sheep.rotation = randf_range(-PI, PI)
		add_child(sheep)

	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
