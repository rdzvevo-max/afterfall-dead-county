class_name Survivor
extends CharacterBody3D

signal stats_changed
signal inventory_changed
signal died

var health := 100.0
var hunger := 0.0
var thirst := 0.0
var energy := 100.0
var inventory: Array[Dictionary] = []
var max_weight := 18.0
var pistol := false
var ammo := 8
var reserve_ammo := 0
var attack_cooldown := 0.0
var camera_yaw := -45.0
var zoom := 12.0
var camera: Camera3D
var pivot: Node3D
var body: MeshInstance3D
var dead := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.42
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	body.material_override = material(Color("6d8173"), 0.78)
	add_child(body)
	var backpack := MeshInstance3D.new()
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.65, 0.85, 0.3)
	backpack.mesh = pack_mesh
	backpack.position = Vector3(0, 1.05, 0.38)
	backpack.material_override = material(Color("443b2d"), 0.9)
	add_child(backpack)
	pivot = Node3D.new()
	pivot.position.y = 1.0
	add_child(pivot)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 48.0
	pivot.add_child(camera)
	update_camera()

func material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _physics_process(delta: float) -> void:
	if dead: return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0, input.y).normalized()
	var speed := 5.8 if Input.is_action_pressed("sprint") and energy > 1.0 else 3.5
	if speed > 5.0 and direction.length() > 0:
		energy = maxf(0.0, energy - delta * 4.0)
	else:
		energy = minf(100.0, energy + delta * 2.2)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if direction.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 10.0)
	velocity.y -= 25.0 * delta
	move_and_slide()
	hunger = minf(100.0, hunger + delta * 0.075)
	thirst = minf(100.0, thirst + delta * 0.13)
	if hunger >= 100.0 or thirst >= 100.0: take_damage(delta * 2.0)
	stats_changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if dead: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = maxf(7.0, zoom - 1.0); update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = minf(17.0, zoom + 1.0); update_camera()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * 0.25
		update_camera()
	if event.is_action_pressed("attack"): attack()
	if event.is_action_pressed("interact"): interact()
	if event.is_action_pressed("reload"): reload()

func update_camera() -> void:
	if not camera: return
	pivot.rotation_degrees.y = camera_yaw
	camera.position = Vector3(0, zoom * 0.78, zoom)
	camera.rotation_degrees.x = -38.0

func attack() -> void:
	if attack_cooldown > 0.0: return
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 1.1
	var target: Vector3
	var damage: float
	if pistol and ammo > 0:
		var mouse := get_viewport().get_mouse_position()
		var ray_origin := camera.project_ray_origin(mouse)
		var ray_end := ray_origin + camera.project_ray_normal(mouse) * 100.0
		var ground_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)
		var ground_hit := space.intersect_ray(ground_query)
		target = ground_hit.get("position", origin - camera.global_basis.z * 30.0)
		damage = 42.0
		ammo -= 1
		attack_cooldown = 0.28
		get_tree().call_group("zombies", "hear_noise", global_position, 28.0)
	else:
		target = origin + global_basis.z * 2.2
		damage = 28.0
		attack_cooldown = 0.55
	var query := PhysicsRayQueryParameters3D.create(origin, target, 4)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(damage)
	stats_changed.emit()

func interact() -> void:
	var nearest: Node3D
	var distance := 2.2
	for loot in get_tree().get_nodes_in_group("loot"):
		var d := global_position.distance_to(loot.global_position)
		if d < distance: nearest = loot; distance = d
	if nearest:
		var data: Dictionary = nearest.item.duplicate()
		if current_weight() + float(data.weight) <= max_weight:
			if data.id == "pistol": pistol = true
			elif data.id == "ammo": reserve_ammo += int(data.quantity)
			else: inventory.append(data)
			nearest.queue_free()
			inventory_changed.emit()

func reload() -> void:
	if not pistol or reserve_ammo <= 0 or ammo >= 8: return
	var needed := 8 - ammo
	var loaded := mini(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	stats_changed.emit()

func current_weight() -> float:
	var total := 1.1 if pistol else 0.0
	for item in inventory: total += float(item.weight) * int(item.quantity)
	return total + reserve_ammo * 0.015

func take_damage(amount: float) -> void:
	if dead: return
	health = maxf(0.0, health - amount)
	body.material_override.albedo_color = Color("8a3434")
	get_tree().create_timer(0.12).timeout.connect(func(): if is_instance_valid(body): body.material_override.albedo_color = Color("6d8173"))
	if health <= 0.0:
		dead = true
		died.emit()
	stats_changed.emit()

func serialize() -> Dictionary:
	return {"position":[position.x,position.y,position.z],"health":health,"hunger":hunger,"thirst":thirst,"energy":energy,"inventory":inventory,"pistol":pistol,"ammo":ammo,"reserve_ammo":reserve_ammo}

func restore(data: Dictionary) -> void:
	var p: Array = data.get("position", [0,1,0])
	position = Vector3(p[0], p[1], p[2])
	health = data.get("health", 100.0); hunger = data.get("hunger", 0.0); thirst = data.get("thirst", 0.0); energy = data.get("energy", 100.0)
	inventory.assign(data.get("inventory", [])); pistol = data.get("pistol", false); ammo = data.get("ammo", 8); reserve_ammo = data.get("reserve_ammo", 0)
	stats_changed.emit(); inventory_changed.emit()
