# makes the actual decisions
extends "boid.gd"

# Declare member variables here. Examples:

# FSM
onready var state = DrivingState.new(self)
var prev_state

#const STATE_PATHING = 0
const STATE_DRIVING  = 1
const STATE_CHASE = 2
const STATE_OBSTACLE = 3

signal state_changed

signal lane_change_done

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# fsm
func set_state(new_state, param=null):
	# if we need to clean up
	#state.exit()
	prev_state = get_state()
	
#	if new_state == STATE_PATHING:
#		state = PathingState.new(self)
#	el
	if new_state == STATE_DRIVING:
		state = DrivingState.new(self)
	if new_state == STATE_CHASE:
		state = ChaseState.new(self)
	if new_state == STATE_OBSTACLE:
		state = ObstacleState.new(self, param)
	
	emit_signal("state_changed", self)

func get_state():
	if state is DrivingState:
		return STATE_DRIVING
	if state is ChaseState:
		return STATE_CHASE
	if state is ObstacleState:
		return STATE_OBSTACLE

# just call the state
func _physics_process(delta):
	state.update(delta)
	
# states ----------------------------------------------------
class DrivingState:
	var car
	
	func _init(car):
		self.car = car

	func update(delta):
		# behavior
		# steering behaviors operate in local space
		# the target passed is already local unless something went very wrong
		# keeps enough speed to move while staying on track
		var spd_steer = car.match_velocity_length(car.max_speed) #10
		#print("Spd steer" + str(spd_steer))
		
		# we're a 3D node, so unfortunately we can only convert Vec3
		var to_loc = car.get_global_transform().xform_inv(car.target)
		
		var arr = null
		# special case for target behind us
		if car.get_parent().dot < 0:
			spd_steer = car.match_velocity_length(2) # keep going forward but very slowly...
			# hack
			car.get_parent().STEER_LIMIT = 0.5
			arr = car.align(Vector2(to_loc.x, to_loc.z))
			
			car.steer = Vector2(arr.x, spd_steer.y)
		else:
			car.get_parent().STEER_LIMIT = 0.4
			# align if angle is big and speed is slow
			if abs(car.get_parent().angle) > 1.1 and car.get_parent().speed < 10:
				arr = car.align(Vector2(to_loc.x, to_loc.z))
				# hack
				arr.y = car.match_velocity_length(2).y
			else:
				# the value here should probably be speed dependent
				arr = car.arrive(Vector2(to_loc.x, to_loc.z), 10)
				#var seek = car.seek(Vector2(to_loc.x, to_loc.z))
	
			car.get_parent().debug = false
	
			#print("Arr" + str(arr))
			#car.steer = arr;
			#car.steer = spd_steer + arr;
			#car.steer = Vector2(0, car.steer.y);
			if 'race' in car.get_parent().get_parent():
				car.steer = Vector2(arr.x, spd_steer.y);
			else:
				car.steer = Vector2(arr.x, min(arr.y, spd_steer.y));
		#print("Post: " + str(car.steer))
		# arrives exactly
	#	steer = arrive(to_local(target), 30*30)
	
		# our actual velocity
		# The x parameter doesn't seem to reflect wheel angle?
		# -z means we're moving forward
		# doesn't work if the AI is going the other way
		#car.velocity = Vector2(car.get_parent().get_angular_velocity().y, -car.get_parent().get_linear_velocity().z)
		
		
		# forward vector scaled by our speed
		var gl_tg = car.get_parent().get_global_transform().xform(Vector3(0, 0, 4))
		var rel = car.get_parent().get_global_transform().xform_inv(gl_tg)
		var vel = rel * car.get_parent().get_linear_velocity().length()
		
		#var vel = car.get_parent().forward_vec * car.get_parent().get_linear_velocity().length()
		#car.velocity = Vector2(vel.x, vel.z)
		car.velocity = Vector2(car.get_parent().get_angular_velocity().y, vel.z)
		
		# debug speed difference between old & new approach
		#var old = -car.get_parent().get_linear_velocity().z
		#if old != 0:
		#	print("old: " + str(old) + " new: " + str(vel.z) + " factor: " + str(vel.z/old))
		
		#if 'race' in car.get_parent().get_parent():
		#	print(str(car.velocity.y))
		#print("Vel: " + str(car.velocity))
		
		# if we detected an obstacle, switch to obstacle state
		var obstacle = car.obstacle_detected(car.get_parent())
		if obstacle:
			car.set_state(car.STATE_OBSTACLE, obstacle)

	
class ChaseState:
	var car
	
	func _init(car):
		self.car = car

	func update(delta):
		#print("Chase state on!")
		# behavior
		# steering behaviors operate in local space
		# the target passed is already local unless something went very wrong
		# keeps enough speed to move while staying on track
		var spd_steer = car.match_velocity_length(car.max_speed) #10
		#print("Spd steer" + str(spd_steer))
		
		# we're a 3D node, so unfortunately we can only convert Vec3
		var to_loc = car.get_global_transform().xform_inv(car.target)
		
		var seek = car.seek(Vector2(to_loc.x, to_loc.z))
		
		car.steer = Vector2(seek.x, seek.y);
		#car.steer = Vector2(seek.x, min(seek.y, spd_steer.y));
		
		# our actual velocity
		# forward vector scaled by our speed
		var gl_tg = car.get_parent().get_global_transform().xform(Vector3(0, 0, 4))
		var rel = car.get_parent().get_global_transform().xform_inv(gl_tg)
		var vel = rel * car.get_parent().get_linear_velocity().length()
		
		car.velocity = Vector2(car.get_parent().get_angular_velocity().y, vel.z)

class ObstacleState:
	var car
	var obstacle
	
	func _init(car, obst):
		self.car = car
		self.obstacle = obst

	func update(delta):
		# behavior
		var max_range = 10 # same as cast_to of the rays
		
		var gl = obstacle.get_global_transform().origin
		var loc = car.get_parent().get_global_transform().xform_inv(gl)
		var rel_pos = Vector2(loc.x, loc.z)
		print(car.get_parent().get_parent().get_name() + " rel to obstacle: ", rel_pos)
		# loc.z is always positive
		var x = abs(loc.x)+1
		var ster = (max_range-loc.z)+(max_range-abs(loc.x))
		var sig = 1
		# loc.x needs a buffer related to the size of the obstacle?
		if rel_pos.x+1 < 0:
			sig = -1
		# steer < 0 is left, > 0 is right
		car.steer = Vector2(sig*ster, 0.1)
		print("Str:", car.steer)
		
#		if car.get_parent().has_node("RayRightFront") and car.get_parent().get_node("RayRightFront").is_colliding() and (car.get_parent().get_node("RayRightFront").get_collider() != null):
#			var gl = car.get_parent().get_node("RayRightFront").get_collider().get_global_transform().origin
#			var loc = car.get_parent().get_global_transform().xform_inv(gl)
#			var rel_pos = Vector2(loc.x, loc.z)
#			print(car.get_parent().get_parent().get_name() + " rel to obstacle right: ", rel_pos)
#			# steer < 0 is left, > 0 is right
#			car.steer = Vector2(-1*(max_range-loc.z)-(abs(max_range-loc.x)), 0.1)
#
#		if car.get_parent().has_node("RayLeftFront") and car.get_parent().get_node("RayLeftFront").is_colliding() and (car.get_parent().get_node("RayLeftFront").get_collider() != null):
#			var gl = car.get_parent().get_node("RayLeftFront").get_collider().get_global_transform().origin
#			var loc = car.get_parent().get_global_transform().xform_inv(gl)
#			var rel_pos = Vector2(loc.x, loc.z)
#			print(car.get_parent().get_parent().get_name() + " rel to obstacle left: ", rel_pos)
#			car.steer = Vector2(1*(max_range-loc.z)+(abs(max_range-loc.x)), 0.1)	
			
		# our actual velocity
		# forward vector scaled by our speed
		var gl_tg = car.get_parent().get_global_transform().xform(Vector3(0, 0, 4))
		var rel = car.get_parent().get_global_transform().xform_inv(gl_tg)
		var vel = rel * car.get_parent().get_linear_velocity().length()
		
		car.velocity = Vector2(car.get_parent().get_angular_velocity().y, vel.z)
		
		# go back to normal driving
		if not car.obstacle_detected(car.get_parent()):
			car.set_state(car.STATE_DRIVING)
		
# -----------------------------	
# this checks the three long front-facing rays that are supposed to detect big obstacles (roadblock, other cars)
func obstacle_detected(body):
	var ret = false
	if body.has_node("RayFront") and body.get_node("RayFront").is_colliding() and body.get_node("RayFront").get_collider_hit() != null:
		if body.get_node("RayFront").get_collider_hit().get_parent().is_in_group("obstacle"):
			ret = body.get_node("RayFront").get_collider_hit()		
	if body.has_node("RayFrontRight") and body.get_node("RayFrontRight").is_colliding() and (body.get_node("RayFrontRight").get_collider() != null):
		if body.get_node("RayFrontRight").get_collider_hit().get_parent().is_in_group("obstacle"):
			ret = body.get_node("RayFrontRight").get_collider_hit()
	if body.has_node("RayFrontLeft") and body.get_node("RayFrontLeft").is_colliding() and (body.get_node("RayFrontLeft").get_collider() != null):
		if body.get_node("RayFrontLeft").get_collider_hit().get_parent().is_in_group("obstacle"):
			ret = body.get_node("RayFrontLeft").get_collider_hit() # true
		
	return ret
	
#func collision_avoidance():
#	if has_node("RayFront") and get_node("RayFront").get_collider_hit() != null:
#		# if all rays hit
#		if has_node("RayRightFront") and has_node("RayLeftFront") \
#		and get_node("RayRightFront").get_collider_hit() != null and get_node("RayLeftFront").get_collider_hit() != null:
#			#print(get_parent().get_name() + " all three rays hit")
#			flag = "AVOID - REVERSE"
#			braking = true
#			# pick direction to go to
#			if get_parent().left:
#				left = true
#			else:
#				right = true
#
#		else:
#
#			# if one of the other rays collides
#			if has_node("RayRightFront") and get_node("RayRightFront").get_collider_hit() != null:
#				right = true
#				flag = "AVOID - REVERSE"
#				braking = true
#			elif has_node("RayLeftFront") and get_node("RayLeftFront").get_collider_hit() != null:
#				left = true
#				flag = "AVOID - REVERSE"
#				braking = true
#			else:
#				if (not reverse and speed > 10):
#					flag = "AVOID - BRAKE"
#					braking = true
#				else:
#					flag = "AVOID"
#					gas = true
#
#	elif has_node("RayRightFront") and get_node("RayRightFront").is_colliding() and (get_node("RayRightFront").get_collider() != null):
#			#print("Detected obstacle " + (get_node("RayRightFront").get_collider().get_parent().get_name()))
#			if has_node("RayLeftFront"):
#				if not (get_node("RayLeftFront").is_colliding() and (get_node("RayLeftFront").get_collider() != null)):
#					#print(get_parent().get_name() + " rays cancelling out")
#				#else:
#					flag = "AVOID - LEFT TURN"
#					left = true
#
#			if (not reverse and speed > 10):	
#				#flag = "AVOID"
#				braking = true
#			else:
#				gas = true
#
#	elif has_node("RayLeftFront"):
#		if get_node("RayLeftFront").is_colliding() and (get_node("RayLeftFront").get_collider() != null):
#			#print(get_parent().get_name() + " detected left obstacle " + (get_node("RayLeftFront").get_collider().get_parent().get_name()))
#			flag = "AVOID - RIGHT TURN"
#			right = true
#
#			if (not reverse and speed > 10):
#				#flag = "AVOID"
#				braking = true
#			else:
#				gas = true
