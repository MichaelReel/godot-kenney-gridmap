extends KinematicBody

const norm_grav = -24.8         # Strength of gravity while walking
var vel = Vector3()             # Velocity
const MAX_SPEED = 10            # Fastest player can reach
const JUMP_SPEED = 7            # Affects how high we can jump
const ACCEL = 3.5               # How fast we get to top speed

const DEACCEL = 16              # How fast we come to a complete stop
const MAX_SLOPE_ANGLE = 40      # Steepest angle we can climb

var camera                      # Camera node - the first person view
var camera_holder               # Spatial node holding all we want to rotate on the X (vert) axis

const MAX_SPRINT_SPEED = 30     # Fastest player can reach while sprinting
const SPRINT_ACCEL = 18         # How fast we get to top sprint speed
var is_sprinting = false        # If we're spring or not

# May need to adjust depending on mouse sensitivity
const MOUSE_SENSITIVITY = 0.10

func _ready():
	camera = $CameraMount/Camera
	camera_holder = $CameraMount

	set_physics_process(true)

	# Keep the mouse in the current window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_input(true)

func _physics_process(delta):
	# Intended direction of movement
	var dir = Vector3()
	# Global camera transform
	var cam_xform = camera.get_global_transform()

	# Check the directional input and
	# get the direction orientated to the camera in the global coords
	# NB: The camera's Z axis faces backwards to the player
	if Input.is_action_pressed("forward"):
		dir += -cam_xform.basis.z.normalized()
	if Input.is_action_pressed("backward"):
		dir += cam_xform.basis.z.normalized()
	if Input.is_action_pressed("left"):
		dir += -cam_xform.basis.x.normalized()
	if Input.is_action_pressed("right"):
		dir += cam_xform.basis.x.normalized()

	# Check we're on the floor before we can jump
	if is_on_floor():
		if Input.is_action_just_pressed("up"):
			vel.y = JUMP_SPEED

	# Check if the sprint key is pressed or not
	if Input.is_action_pressed("sprint"):
		is_sprinting = true
	else:
		is_sprinting = false

	# Remove any extra vertical movement from the direction
	dir.y = 0
	dir = dir.normalized()

	# Accelerate by normal gravity downwards
	var grav = norm_grav
	vel.y += delta * grav

	# Get the current horizontal only movement
	var hvel = vel
	hvel.y = 0

	# Get how far we can move horizontally
	var target = dir
	if is_sprinting:
		target *= MAX_SPRINT_SPEED
	else:
		target *= MAX_SPEED

	# Set ac(de)celeration depending on input direction
	var accel
	if dir.dot(hvel) > 0:
		if is_sprinting:
			accel = SPRINT_ACCEL
		else:
			accel = ACCEL
	else:
		accel = DEACCEL

	# Interpolate between the current (horizontal) velocity and the intended velocity
	hvel = hvel.linear_interpolate(target, accel*delta)
	vel.x = hvel.x
	vel.z = hvel.z
	# Use the KinematicBody to control physics movement
	vel = move_and_slide(vel,Vector3(0,1,0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

	# (optional, but highly useful) Capturing/Freeing the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		# Toggle mouse between captured and visible on ui_cancel
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate camera holder on the X plane given changes to the Y mouse position (Vertical)
		camera_holder.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * -1))
		# Rotate camera on the Y plane given changes to the X mouse position (Horizontal)
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))

		# Clamp the vertical look to +- 70 because we don't do back flips or tumbles
		var camera_rot = camera_holder.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		camera_holder.rotation_degrees = camera_rot