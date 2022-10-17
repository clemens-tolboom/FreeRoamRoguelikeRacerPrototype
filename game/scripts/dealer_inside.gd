extends Node3D

# class member variables go here, for example:
var player
var entrance
var garage_hud
var env

func _ready():
	
	# fix issues with fog
	get_node(^"Camera3D").set_current(true)
	get_node(^"Camera3D").set_environment(env)
	
	##GUI
	var h = preload("res://hud/dealer_hud.tscn")
	garage_hud = h.instantiate()
	garage_hud.player = player
	add_child(garage_hud)
	
func go_back():
	if (player != null and entrance != null):
		# remove ourselves
		queue_free()
		
		var root = entrance.get_parent().get_parent() #.get_parent().get_parent()
		
		# change vehicle if needed
		if garage_hud.changed:
			player = player.swap_to_bike()
			# note that we have a bike and that we are not in car
			root.vehicles["bike"] = true
			root.vehicles["car"] = false
		
		player.hud.update_money(player.money)
		
		
		# set player cam as current
		player.get_node(^"cambase").get_node(^"Camera3D").make_current()
		
		# move the player out of the garage
		print("Moving the player")
		#print(str(entrance.get_parent().get_node(^"Position3D").get_translation()))
		var gl = entrance.get_node(^"Position3D").get_global_transform().origin
		#print(gl)
		# because player is child of 0,0,0 node
		player.get_parent().position = gl
		# actual player physics body relative to parent
		player.position = Vector3(0,0,0)
		#print(player.get_parent().get_translation())
		
		# rotate & bring to a stop (kinematic)
		player.set_velocity(Vector3(0,0,0))
		player.vel = Vector3(0,0,0)
		player.rotate_y(deg_to_rad(180))
		
		# unhide player
		player.show()
		# unhide gui
		var hud = player.get_node(^"root")
		var map = player.get_node(^"Viewport_root") #/SubViewport/minimap")
		hud.show()
		map.show()
		
		#unhide entrance
		entrance.show()
	
		#restore car input
		player.set_physics_process(true)
			
		# restore time passage
		var world = root.get_node(^"scene")
		world.set_process(true)
		# show the sun
		world.get_node(^"DirectionalLight3D").set_visible(true)
		

		
