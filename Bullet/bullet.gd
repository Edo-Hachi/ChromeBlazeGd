extends Area2D

@export var speed: float = 600.0
@export var direction: Vector2 = Vector2.UP

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	
	# 画面外(y < -32)に出たらオブジェクト破棄
	if global_position.y < -32.0:
		queue_free()
