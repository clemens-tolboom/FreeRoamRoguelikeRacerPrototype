@tool
extends "connect_intersections.gd"

# prime candidate for rewriting in something speedier, along with triangulation itself (2dtests/Delaunay2D.gd)

# class member variables go here, for example:
var intersects
var mult

var edges = []
var samples = []

var real_edges = []
#var tris = []

var garage
var recharge
var dealership

var AI = preload("res://car/kinematics/kinematic_car_AI_traffic.tscn")

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	# need to do it explicitly in Godot 4 for some reason
	super._ready()
	get_tree().paused = true

	mult = get_node(^"triangulate/poisson").mult

	intersects = preload("res://roads/intersection4way.tscn")
	garage = preload("res://objects/garage_road.tscn")
	recharge = preload("res://objects/recharge_station.tscn")
	dealership = preload("res://objects/dealer_city.tscn")

	samples = get_node(^"triangulate/poisson").samples
	print("Number of intersections: " + str(samples.size()-1))
	for i in range(0, get_node(^"triangulate/poisson").samples.size()-1):
		var p = get_node(^"triangulate/poisson").samples[i]
		var intersection = intersects.instantiate()
		intersection.set_position(Vector3(p[0]*mult, 0, p[1]*mult))
		#print("Placing intersection at " + str(p[0]*mult) + ", " + str(p[1]*mult))
		intersection.set_name("intersection" + str(i))
		add_child(intersection)

	# get the triangulation
	var tris = get_node("triangulate").tris

	for t in tris:
		#var poly = []
		#print("Edges: " + str(t.get_edges()))
		for e in t.get_edges():
			#print(str(e))
			if edges.has(Vector2(e[0], e[1])):
				pass
				#print("Already has edge: " + str(e[0]) + " " + str(e[1]))
			elif edges.has(Vector2(e[1], e[0])):
				pass
				#print("Already has edge: " + str(e[1]) + " " + str(e[0]))
			else:
				edges.append(e)

	# create the map
	# for storing roads that actually got created
	real_edges = []
	var sorted = sort_intersections_distance()

#	var initial_int = sorted[0][1]
#	print("Initial int: " + str(initial_int))

	# automate it!
	for i in range(sorted.size()-1):
		auto_connect(sorted[i][1], real_edges)
	
#	auto_connect(sorted[0][1], real_edges)
#	auto_connect(sorted[1][1], real_edges)
#	auto_connect(sorted[2][1], real_edges)
#	auto_connect(sorted[3][1], real_edges)
#	auto_connect(sorted[4][1], real_edges)
#	auto_connect(sorted[5][1], real_edges)
#	auto_connect(sorted[6][1], real_edges)
#	auto_connect(sorted[7][1], real_edges)

	#print("Real edges: ", real_edges)

	# road around
	var out_edges = get_node(^"triangulate/poisson").out_edges
	print("Outer edges: " + str(out_edges))
	
	# paranoia
	if out_edges[0][0] != out_edges[out_edges.size()-1][1]:
		print("Start and end edge are different!")
	else:

		# remove any edges that we already connected
		var to_remove = []
		for e in real_edges:
			#print("Check real edge: " + str(e))
			#out_edges.remove(out_edges.find(e))
			for i in range(0, out_edges.size()):
				var e_o = out_edges[i]
				#print("Outer edge: " + str(e_o))
				if e[0] == e_o[0] and e[1] == e_o[1]:
					to_remove.append(e_o)
				# check the other way round, too
				if e[1] == e_o[0] and e[0] == e_o[1]:
					to_remove.append(e_o)
					
		for e in to_remove:
			#print("To remove: " + str(e))
			# works because e is taken directly from out_edges (see line 87)
			out_edges.remove_at(out_edges.find(e))
			
		print("Outer edges post filter: " + str(out_edges))

		for e in out_edges:
			# +3 because of helper nodes which come first
			var ret = connect_intersections(e[0]+3, e[1]+3, false)
			if ret != false:
				#if verbose:
				#	Logger.mapgen_print("We did create a connection... " + str(initial_int) + " to " + str(p[0]))
				real_edges.append(Vector2(e[0], e[1]))

	# map setup is done, let's continue....
	# map navigation, markers...
	get_node(^"nav").setup(mult, samples, real_edges)

	# debug
#	get_node(^"nav").debug_lane_lists()

	# test: replace longest road with a bridge
#	# done after nav setup to avoid having to mess with navigation
#	var straight = get_node("Road 6-5/Spatial0/Road_instance 0")
#	var str_tr = get_node("Road 6-5/Spatial0/Road_instance 0").get_position()
#	var str_len = straight.relative_end
#	var slope = set_straight_slope(str_tr, get_node(^"Road 6-5/Spatial0/Road_instance 0").get_rotation(), get_node(^"Road 6-5/Spatial0"), 1)
#	# position the other end correctly
#	var end_p_gl = straight.global_transform * (str_len)
#	var end_p = get_node(^"Road 6-5/Spatial0").to_local(end_p_gl)
#	var slope2 = set_straight_slope(end_p, get_node(^"Road 6-5/Spatial0/Road_instance 0").get_rotation()+Vector3(0,deg2rad(180),0), get_node(^"Road 6-5/Spatial0"), 2)
#	# regenerate the straight
#	straight.translate_object_local(Vector3(0, 5, 40))
#	straight.relative_end = Vector3(0,0,str_len.z-80) # because both slopes are 40 m long
#	straight.get_node(^"plane").queue_free()
#	straight.get_node(^"sidewalk").queue_free()
#	# regenerate all the decor
#	for c in straight.get_node(^"Node3D").get_children():
#		c.queue_free()
#	#straight.get_node(^"Node3D").queue_free()
#	straight.generateRoad()


	# place cars on parking lots
	var lots = get_spawn_lots()
	
	#for i in range(2, samples.size()-1):
	for i in range(lots.size()):
		place_AI(i, lots)

	# place garage road
	var garage_opts = []
	for i in range(3, samples.size()-1):
		var inters = get_child(i)
		#Logger.mapgen_print(inters.get_name() + " exits: " + str(inters.open_exits))
		if inters.open_exits.size() > 1:
			# is it in the edges that actually were connected?
			for e in real_edges:
				if e.x == i or e.y == i:
					Logger.mapgen_print(String(inters.get_name()) + " is an option for garage road")
					garage_opts.append(inters)
					break #the first find should be enough
			
			if garage_opts.find(inters) == -1:
				pass
				#Logger.mapgen_print(inters.get_name() + " is not in the actual connected map")
				
	var sel = null
	if garage_opts.is_empty():
		print("No garage options found")
		return

#	if garage_opts.size() > 1:
#		sel = garage_opts[randi() % garage_opts.size()]
#	else:
#		sel = garage_opts[0]

	var rots = { Vector3(10,0,0): Vector3(0,-90,0), Vector3(0,0,10): Vector3(0, 180, 0), Vector3(-10,0,0) : Vector3(0, 90, 0) }

	#TODO: procedural choice for garage road (pointing away from center to make sure we have space for the road)
	# force for testing
	var wanted = get_child(3) # intersection 0
	sel = wanted

	if sel.open_exits.size() > 0:
		print(String(sel.get_name()) + str(sel.open_exits[0]))
		var garage_rd = garage.instantiate()
		# test placement
		garage_rd.set_position(sel.get_position() + sel.open_exits[0])
		#print(str(garage_rd.get_translation()))
		#print(str(sel.open_exits[1]))
		
		# assign correct rotation
		if rots.has(sel.open_exits[0]):
			var rot = rots[sel.open_exits[0]]
			garage_rd.set_rotation(Vector3(rot.x, deg2rad(rot.y), rot.z))
		else:
			# prevent weirdness
			print("Couldn't find correct rotation for " + str(sel.open_exits[0]))
			return
		
		add_child(garage_rd)
	
	# TODO: procedural POI placement system
	# place recharging station
	wanted = get_child(6) # intersection 3
	sel = wanted
	if sel.open_exits.size() > 2:
		print(sel.get_name() + str(sel.open_exits[1]))
		var station = recharge.instantiate()
		# place including offset that accounts for the size
		station.set_position(sel.get_position() + sel.open_exits[1] + Vector3(4,0,4))
	
		# assign correct rotation
		if rots.has(sel.open_exits[1]):
			var rot = rots[sel.open_exits[1]]
			station.set_rotation(Vector3(rot.x, deg2rad(rot.y), rot.z))
	
		station.set_name("station")
		add_child(station)

	# place vehicle dealership
	sel = get_child(8) # intersection 5
	if sel.open_exits.size() > 1:
		print(String(sel.get_name()) + str(sel.open_exits[0]))
		var dealer = dealership.instantiate()
		# place
		dealer.set_position(sel.get_position() + sel.open_exits[0])
		
		# assign correct rotation
		if rots.has(sel.open_exits[0]):
			var rot = rots[sel.open_exits[0]]
			dealer.set_rotation(Vector3(rot.x, deg2rad(rot.y), rot.z))
		
		dealer.set_name("dealership")
		add_child(dealer)
		
	# test
	#Logger.save_to_file()
	
	get_tree().paused = false
	EventBus.emit_signal("mapgen_done")

# -----------------
# returns a list of [dist, index] lists, operates on child ids
func sort_intersections_distance(tg = Vector3(0,0,0), debug=true):
	var dists = []
	var tmp = []
	var closest = []
	# exclude helper nodes
	for i in range(3, 3+samples.size()-1):
		var e = get_child(i)
		var dist = e.position.distance_to(tg)
		#print("Distance: exit: " + str(e.get_name()) + " dist: " + str(dist))
		tmp.append([dist, i])
		dists.append(dist)

	dists.sort()

	#print("tmp" + str(tmp))
	# while causes a lockup, whichever way we do it
	#while tmp.size() > 0:
	#	print("Tmp size > 0")
	var max_s = tmp.size()
	#while max_s > 0:
	for i in range(0, max_s):
		#print("Running add, attempt " + str(i))
		#print("tmp: " + str(tmp))
		for t in tmp:
			#print("Check t " + str(t))
			if t[0] == dists[0]:
				closest.append(t)
				tmp.remove_at(tmp.find(t))
				# key line
				dists.remove_at(0)
				#print("Adding " + str(t))
	# if it's not empty by now, we have an issue
	#print(tmp)

	if debug:
		print("Sorted inters: " + str(closest))

	return closest

func auto_connect(initial_int, real_edges, verbose=false):
	var next_ints = []
	var res = []
	var sorted_n = []
	# to remove properly
	var to_remove = []

	if verbose:
		if initial_int+3 < get_child_count():
			# +3 because of helper nodes that come first
			Logger.mapgen_print("Auto connecting... " + String(get_child(initial_int+3).get_name()) + " @ " + str(get_child(initial_int+3).get_global_transform().origin))

	for e in edges:
		if e.x == initial_int:
			#Logger.mapgen_print("Edge with initial int" + str(e) + " other end " + str(e.y))
			var data = [e.y, get_child(e.y).get_global_transform().origin]
			next_ints.append(data)
			#print(data[1].x)
			#TODO: use relative angles?? it has to be robust!
			sorted_n.append(atan2(data[1].z, data[1].x))
			#sorted_n.append(data[1].x)
			# remove from edge list so that we can use the list in other iterations
			to_remove.append(edges.find(e))
		if e.y == initial_int:
			#Logger.mapgen_print("Edge with initial int" + str(e) + " other end " + str(e.x))
			var data = [e.x, get_child(e.x).get_global_transform().origin]
			next_ints.append(data)
			#print(data[1].x)
			#sorted_n.append(data[1].x)
			sorted_n.append(atan2(data[1].z, data[1].x))
			# remove from edge list so that we can use the list in other iterations
			to_remove.append(edges.find(e))

	# remove ids to remove
	#print("Before: " + str(to_remove))
	to_remove.sort()
	#print("Sorted: " + str(to_remove))
	# By removing highest index first, we avoid errors
	to_remove.reverse()
	#print("Inverted: " + str(to_remove))
	for i in to_remove:
		edges.remove_at(i)

	#print(sorted_n)

	# this sorts by natural order (lower value first)
	sorted_n.sort()
	# but we want higher?
	#sorted_n.reverse()

	if verbose:
		Logger.mapgen_print("Sorted: " + str(sorted_n))

	for i in range(0, next_ints.size()):
		#print("Attempt " + str(i))
		for d in next_ints:
			#print(str(d) + " " + str(sorted_n[0]))
			# the first part of this needs to match what was used for sorting
			if atan2(d[1].z, d[1].x) == sorted_n[0]:
				next_ints.remove_at(next_ints.find(d))
				res.append(d)
				sorted_n.remove_at(0)

	#print("Res " + str(res) + " lower y: " + str(res[0]))
	#print("next ints: " + str(next_ints))
	var last_int = 1+get_node(^"triangulate/poisson").samples.size()-1
	for i in range(0, res.size()):
		var p = res[i]
		#if verbose:
		#	Logger.mapgen_print("Intersection " + str(p))
		#Logger.mapgen_print("Target id " + str(p[0]+2) + "last intersection " + str(1+get_node(^"triangulate/poisson").samples.size()-1))
		# prevent trying to connect to unsuitable things
		if p[0]+3 > last_int:
			return
		# +3 because of helper nodes that come first
		var ret = connect_intersections(initial_int+3, p[0]+3, verbose)
		if ret != false:
			if verbose:
				Logger.mapgen_print("We did create a connection... " + str(initial_int) + " to " + str(p[0]))
			real_edges.append(Vector2(initial_int, p[0]))
			

# ---------------------------------------
func find_lot(road):
	for c in road.get_node(^"Spatial0/Road_instance 0/Node3D").get_children():
		if c.is_in_group("parking"):
			return c
			
func get_spawn_lots():
	var lots = []

	var roads_start_id = 3+samples.size()-1 # 3 helper nodes + intersections for samples
	#for e in real_edges:
	for i in range(roads_start_id, roads_start_id+ real_edges.size()):
		var road = get_child(i)
		if not road.get_node(^"Spatial0/Road_instance 0").tunnel:
			var lot = find_lot(road)
			if lot:
				lots.append([lot, lot.get_global_transform().origin])
	
	return lots

		

func place_player_random():
	var player = get_tree().get_nodes_in_group("player")[0]

	var id = randi() % samples.size()-1
	var p = samples[id]

	var pos = Vector3(p[0]*mult, 0, p[1]*mult)

	# because player is child of root which is at 0,0,0
	player.set_position(to_global(pos))

func place_player(id):
	var player = get_tree().get_nodes_in_group("player")[0]
	var p = samples[id]
	var pos = Vector3(p[0]*mult, 0, p[1]*mult)

	# because player is child of root which is at 0,0,0
	player.set_position(to_global(pos))

func place_AI(id, lots):
	var AI_g = get_parent().get_node(^"AI")
	#var car = get_tree().get_nodes_in_group("AI")[3] #.get_parent()
	
	var car = AI.instantiate()
	if AI_g == null:
		return
		
	AI_g.add_child(car)
	
	# this is global!
	var pos = lots[id][1]
	
	# this was local
	#var p = samples[id]
	#var pos = Vector3(p[0]*mult, 0, p[1]*mult)
	
	# to place on intersection exit (related to point_one/two/three in intersection.gd)
#	if exit == 1:
#		pos = pos + Vector3(0,0,5)
#	elif exit == 2:
#		pos = pos + Vector3(5,0,0)
#	elif exit == 3:
#		pos = pos + Vector3(0,0,-5)

	# because car is child of AI group node which is not at 0,0,0
	car.set_position(AI_g.to_local(pos))
	
	# small offset
	car.translate_object_local(Vector3(0,0,-4))
	

	print("placed AI on a lot #", var2str(id))

func get_marker(_name):
	for c in get_children():
		if String(c.get_name()).find(_name) != -1:
			return c

# markers are spawned in map_nav.gd because they use BFS/distance map

