class_name Infected
extends CharacterBody3D

var target: Survivor
var health := 70.0
var speed := 1.75
var attack_timer := 0.0
var alert_position := Vector3.ZERO
var alerted := false
var body: MeshInstance3D

func setup(player: Survivor, variant: int) -> void:
	target = player
	health = [65.0, 48.0, 105.0][variant]
	speed = [1.55, 2.65, 1.15][variant]
	add_to_group("zombies")
	collision_layer = 4
	collision_mask = 1 | 2
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.42; capsule.height = 1.8
	collision.shape = capsule; collision.position.y = 0.9; add_child(collision)
	body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new(); mesh.radius = 0.42; mesh.height = 1.8
	body.mesh = mesh; body.position.y = 0.9
	var mat := StandardMaterial3D.new(); mat.albedo_color = [Color("536251"),Color("78604c"),Color("3d4c59")][variant]; mat.roughness = 0.95
	body.material_override = mat; add_child(body)
	var head := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = 0.38; sphere.height = 0.76
	head.mesh = sphere; head.position.y = 1.92; head.material_override = mat; add_child(head)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead: return
	attack_timer -= delta
	var distance := global_position.distance_to(target.global_position)
	var can_see := distance < 11.0 and not vision_blocked()
	if can_see: alerted = true; alert_position = target.global_position
	if alerted:
		var delta_pos := alert_position - global_position; delta_pos.y = 0
		if can_see: delta_pos = target.global_position - global_position; delta_pos.y = 0; alert_position = target.global_position
		if distance < 1.35 and can_see:
			velocity.x = 0; velocity.z = 0
			if attack_timer <= 0.0: target.take_damage(9.0); attack_timer = 1.15
		else:
			var dir := delta_pos.normalized(); velocity.x = dir.x * speed; velocity.z = dir.z * speed
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 7.0)
			if global_position.distance_to(alert_position) < 1.0 and not can_see: alerted = false
	else: velocity.x = 0; velocity.z = 0
	velocity.y -= 25.0 * delta
	move_and_slide()

func vision_blocked() -> bool:
	var from := global_position + Vector3.UP * 1.4
	var to := target.global_position + Vector3.UP
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func hear_noise(origin: Vector3, radius: float) -> void:
	if global_position.distance_to(origin) <= radius: alerted = true; alert_position = origin

func take_damage(amount: float) -> void:
	health -= amount
	body.material_override.albedo_color = Color("b52f2f")
	alerted = true; alert_position = target.global_position
	if health <= 0.0:
		collision_layer = 0; collision_mask = 0
		var tween := create_tween(); tween.tween_property(self, "rotation:z", PI * 0.48, 0.28); tween.tween_interval(1.2); tween.tween_callback(queue_free)
