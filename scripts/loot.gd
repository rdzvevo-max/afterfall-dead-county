class_name WorldLoot
extends StaticBody3D

var item: Dictionary

func setup(data: Dictionary, color: Color) -> void:
	item = data
	add_to_group("loot")
	collision_layer = 8
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = Vector3(0.45, 0.3, 0.45)
	mesh_instance.mesh = mesh; mesh_instance.position.y = 0.2
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.emission_enabled = true; mat.emission = color * 0.18
	mesh_instance.material_override = mat; add_child(mesh_instance)
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(0.45,0.3,0.45)
	collision.shape = shape; collision.position.y = 0.2; add_child(collision)
