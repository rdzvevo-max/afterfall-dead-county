extends Node3D

const SAVE_PATH := "user://afterfall_save.json"
var player: Survivor
var hud: CanvasLayer
var stats_label: Label
var ammo_label: Label
var inventory_panel: PanelContainer
var inventory_text: Label
var prompt: Label
var death_panel: ColorRect
var sun: DirectionalLight3D
var world_time := 9.0

func _ready() -> void:
	build_environment()
	build_world()
	spawn_player()
	spawn_content()
	build_ui()
	player.stats_changed.connect(update_hud)
	player.inventory_changed.connect(update_inventory)
	player.died.connect(show_death)
	update_hud(); update_inventory()

func material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = roughness
	if color.a < 1.0: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func make_box(parent: Node, pos: Vector3, size: Vector3, color: Color, collision := true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	mesh_instance.mesh = mesh; mesh_instance.position = pos; mesh_instance.material_override = material(color); parent.add_child(mesh_instance)
	if collision:
		var body := StaticBody3D.new(); body.collision_layer = 1; body.position = pos; parent.add_child(body)
		var shape_node := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; shape_node.shape = shape; body.add_child(shape_node)
	return mesh_instance

func build_environment() -> void:
	var env := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR; environment.background_color = Color("101817")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color = Color("6f7c75"); environment.ambient_light_energy = 0.58
	environment.fog_enabled = true; environment.fog_light_color = Color("53605b"); environment.fog_density = 0.008
	env.environment = environment; add_child(env)
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-42,-30,0); sun.light_color = Color("d5c29e"); sun.light_energy = 1.15; sun.shadow_enabled = true; add_child(sun)

func build_world() -> void:
	make_box(self, Vector3(0,-0.3,0), Vector3(70,0.6,70), Color("253128"))
	make_box(self, Vector3(0,0.02,0), Vector3(9,0.08,70), Color("242627"), false)
	for z in range(-30,31,6): make_box(self, Vector3(0,0.08,z), Vector3(0.18,0.03,2.5), Color("b8a76b"), false)
	build_house(Vector3(-12,0,-8), Color("4a433c"), false)
	build_house(Vector3(13,0,-10), Color("394349"), true)
	build_house(Vector3(-14,0,14), Color("4b3b37"), false)
	build_house(Vector3(14,0,15), Color("3d443a"), true)
	for i in 24:
		var x := (-28.0 if i % 2 == 0 else 28.0) + randf_range(-2,2); var z := -30.0 + (i/2)*5.2
		make_tree(Vector3(x,0,z))

func build_house(origin: Vector3, color: Color, shop: bool) -> void:
	var width := 10.0 if shop else 8.0; var depth := 7.0
	make_box(self, origin+Vector3(0,0.1,0), Vector3(width,0.2,depth), Color("38332e"))
	make_box(self, origin+Vector3(-width/2,1.7,0), Vector3(0.25,3.4,depth), color)
	make_box(self, origin+Vector3(width/2,1.7,0), Vector3(0.25,3.4,depth), color)
	make_box(self, origin+Vector3(0,1.7,-depth/2), Vector3(width,3.4,0.25), color)
	make_box(self, origin+Vector3(-width*.32,1.7,depth/2), Vector3(width*.36,3.4,0.25), color)
	make_box(self, origin+Vector3(width*.32,1.7,depth/2), Vector3(width*.36,3.4,0.25), color)
	make_box(self, origin+Vector3(0,3.55,0), Vector3(width+.4,0.25,depth+.4), Color(color,0.55), false)
	if shop:
		for x in [-2.6,0.0,2.6]: make_box(self, origin+Vector3(x,0.65,0), Vector3(0.6,1.3,4.4), Color("332d25"))

func make_tree(pos: Vector3) -> void:
	make_box(self,pos+Vector3(0,1.5,0),Vector3(.45,3,.45),Color("40372a"))
	var crown := MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=1.3;mesh.height=2.6;crown.mesh=mesh;crown.position=pos+Vector3(0,3.5,0);crown.material_override=material(Color("1d3525"));add_child(crown)

func spawn_player() -> void:
	player = Survivor.new(); player.position = Vector3(0,1,5); add_child(player)

func spawn_content() -> void:
	for i in 14:
		var z := Infected.new(); z.position = Vector3(randf_range(-24,24),1,randf_range(-28,28)); add_child(z); z.setup(player,i%3)
	var items := [
		{"id":"pistol","name":"9 mm-es pisztoly","quantity":1,"weight":1.1},
		{"id":"ammo","name":"9 mm-es lőszer","quantity":16,"weight":0.015},
		{"id":"food","name":"Babkonzerv","quantity":1,"weight":0.5},
		{"id":"water","name":"Palackozott víz","quantity":1,"weight":0.8},
		{"id":"bandage","name":"Tiszta kötés","quantity":2,"weight":0.1}
	]
	for i in 18:
		var loot := WorldLoot.new(); loot.position=Vector3(randf_range(-20,20),.1,randf_range(-24,24)); add_child(loot);loot.setup(items[i%items.size()].duplicate(),[Color("7b3333"),Color("b28b42"),Color("8b9a72"),Color("5982a0"),Color("ded7bf")][i%5])

func build_ui() -> void:
	hud=CanvasLayer.new();add_child(hud)
	var top:=ColorRect.new();top.color=Color(0.01,0.015,0.012,.86);top.position=Vector2(18,18);top.size=Vector2(530,94);hud.add_child(top)
	stats_label=Label.new();stats_label.position=Vector2(34,30);stats_label.add_theme_font_size_override("font_size",18);hud.add_child(stats_label)
	ammo_label=Label.new();ammo_label.position=Vector2(34,63);ammo_label.add_theme_color_override("font_color",Color("d5b77a"));hud.add_child(ammo_label)
	prompt=Label.new();prompt.text="WASD: mozgás   SHIFT: futás   E: felvétel   BAL KATT: támadás   I/TAB: hátizsák\nF5: mentés   F9: betöltés   Görgő: zoom   Középső egér: kamera";prompt.position=Vector2(34,92);prompt.add_theme_font_size_override("font_size",13);hud.add_child(prompt)
	inventory_panel=PanelContainer.new();inventory_panel.position=Vector2(900,25);inventory_panel.size=Vector2(345,430);inventory_panel.visible=false;hud.add_child(inventory_panel)
	inventory_text=Label.new();inventory_text.custom_minimum_size=Vector2(315,400);inventory_text.add_theme_font_size_override("font_size",17);inventory_panel.add_child(inventory_text)
	death_panel=ColorRect.new();death_panel.color=Color(0.08,0,0,.88);death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);death_panel.visible=false;hud.add_child(death_panel)
	var death:=Label.new();death.text="MEGHALTÁL\n\nNyomj ENTERT az újrakezdéshez";death.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;death.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;death.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);death.add_theme_font_size_override("font_size",32);death_panel.add_child(death)

func _process(delta: float) -> void:
	world_time=fmod(world_time+delta*.035,24.0);sun.rotation_degrees.x=world_time/24.0*360.0-90.0
	if Input.is_action_just_pressed("inventory"):inventory_panel.visible=not inventory_panel.visible
	if Input.is_action_just_pressed("save_game"):save_game()
	if Input.is_action_just_pressed("load_game"):load_game()
	if player.dead and Input.is_key_pressed(KEY_ENTER):get_tree().reload_current_scene()

func update_hud() -> void:
	stats_label.text="ÉLET  %03d    ÉHSÉG  %03d    SZOMJ  %03d    ENERGIA  %03d"%[player.health,player.hunger,player.thirst,player.energy]
	ammo_label.text=("PISZTOLY  %d / %d"%[player.ammo,player.reserve_ammo])if player.pistol else "FEGYVER: PUSZTA KÉZ"

func update_inventory() -> void:
	var text:="FELSZERELÉS ÉS HÁTIZSÁK\n%.1f / %.0f kg\n\n"%[player.current_weight(),player.max_weight]
	if player.pistol:text+="• 9 mm-es pisztoly\n"
	if player.reserve_ammo:text+="• Lőszer × %d\n"%player.reserve_ammo
	for item in player.inventory:text+="• %s × %d\n"%[item.name,item.quantity]
	if player.inventory.is_empty()and not player.pistol:text+="A hátizsák üres."
	inventory_text.text=text

func save_game() -> void:
	var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"version":1,"world_time":world_time,"player":player.serialize()}));prompt.text="JÁTÉK ELMENTVE";get_tree().create_timer(1.5).timeout.connect(reset_prompt)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):prompt.text="NINCS MENTÉS";return
	var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:world_time=data.get("world_time",9.0);player.restore(data.player);prompt.text="MENTÉS BETÖLTVE";get_tree().create_timer(1.5).timeout.connect(reset_prompt)

func reset_prompt()->void:prompt.text="WASD: mozgás   SHIFT: futás   E: felvétel   BAL KATT: támadás   I/TAB: hátizsák\nF5: mentés   F9: betöltés   Görgő: zoom   Középső egér: kamera"
func show_death()->void:death_panel.visible=true
