extends CharacterBody2D

const SPEED = 300.0
const OPTION_OFFSET_X = 36.0
const OPTION_OFFSET_Y = 32.0
const DELAY_FRAMES = 15
const MAX_HISTORY = 120

# 左右それぞれの角度テーブル (0から最大120度まで15度刻み)
const OPT_ANGLES_R = [0.0, 15.0, 30.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0,135.0, 150.0, 165.0, 180.0]
const OPT_ANGLES_L = [0.0, -15.0, -30.0, -45.0, -60.0, -75.0, -90.0, -105.0, -120.0, -135.0, -150.0, -165.0, -180.0]

@export var bullet_scene: PackedScene

# オプションのプリロード
const OPTION_SCENE = preload("res://OptionTurret/option_turret.tscn")

var option_left: Node2D
var option_right: Node2D

# 座標履歴バッファ
var position_history: Array[Vector2] = []
var opt_ang_pos: float = 0.0 # 角度テーブルのインデックス値（スムーズに補間するためfloat）

func _ready() -> void:
	# 左右のオプションを生成
	option_left = OPTION_SCENE.instantiate()
	option_right = OPTION_SCENE.instantiate()
	
	# 親の移動（相対座標）に影響されないよう top_level = true に設定
	option_left.top_level = true
	option_right.top_level = true
	
	# 自機の子として追加（top_level=true なので描画ツリー上は独立して動く）
	add_child(option_left)
	add_child(option_right)
	
	# 座標履歴を初期位置で満たす
	for i in range(MAX_HISTORY):
		position_history.append(global_position)

func _physics_process(delta: float) -> void:
	# 8方向移動の取得（斜め移動の正規化は get_vector が自動で行う）
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if direction != Vector2.ZERO:
		velocity = direction * SPEED
	else:
		# 減速処理（滑らかに止まる）
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * delta * 10.0)		

	move_and_slide()

	# 画面外クランプ処理 (ビューポートの端から16pxのマージン)
	var viewport_size = get_viewport_rect().size
	var margin = 16.0
	global_position.x = clamp(global_position.x, margin, viewport_size.x - margin)
	global_position.y = clamp(global_position.y, margin, viewport_size.y - margin)

	# 座標履歴の更新 (最新座標を先頭に挿入し、上限を超えたら末尾を削除)
	position_history.push_front(global_position)
	if position_history.size() > MAX_HISTORY:
		position_history.pop_back()

	# オプションの角度変更ロジック (上入力で外側に開き、それ以外は正面に戻る)
	var max_idx = OPT_ANGLES_R.size() - 1
	var target_ang_pos = 0.0
	if direction.y < 0:
		target_ang_pos = float(max_idx) # テーブルの最大値まで開く

	# デルタ時間に応じて滑らかにインデックスを遷移させる (約0.5秒で最大まで変化)
	var speed = max_idx * 2.0
	opt_ang_pos = move_toward(opt_ang_pos, target_ang_pos, delta * speed)
	var ang_idx = clampi(int(round(opt_ang_pos)), 0, max_idx)

	# オプションの追従処理 (15フレーム前の位置を基準にオフセットを加える)
	var target_idx = clampi(DELAY_FRAMES, 0, position_history.size() - 1)
	var base_pos = position_history[target_idx]
	
	option_left.global_position = base_pos + Vector2(-OPTION_OFFSET_X, OPTION_OFFSET_Y)
	option_right.global_position = base_pos + Vector2(OPTION_OFFSET_X, OPTION_OFFSET_Y)

	# オプションの回転を適用
	option_left.rotation_degrees = OPT_ANGLES_L[ang_idx]
	option_right.rotation_degrees = OPT_ANGLES_R[ang_idx]

	# レーザー線の描画を更新
	queue_redraw()

	# 弾の発射処理
	if Input.is_action_just_pressed("ui_select") or Input.is_action_just_pressed("shoot"):
		shoot()

func _draw() -> void:
	# 自機の中心 (Vector2.ZERO) から左右のオプションへの赤いラインを描画
	# option_left と option_right の global_position を自機のローカル座標に変換して描画する
	if is_instance_valid(option_left):
		var local_left = to_local(option_left.global_position)
		draw_line(Vector2.ZERO, local_left, Color.RED, 1.0)
	if is_instance_valid(option_right):
		var local_right = to_local(option_right.global_position)
		draw_line(Vector2.ZERO, local_right, Color.RED, 1.0)

func shoot() -> void:
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		# 弾はメインのシーン（親ノード）に追加する
		get_parent().add_child(bullet)
		bullet.global_position = global_position + Vector2(0, -8)
