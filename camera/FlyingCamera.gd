extends Spatial

var camera
var camera_holder
var camera_control

var cam_ref

const MOUSE_SENSITIVITY = 0.10

var vel = Vector3()

const MAX_SPEED = 20            # Fastest camera can reach
const ACCEL = 3.5               # How fast we get to top speed
const DEACCEL = 16              # How fast we come to a complete stop
const MAX_SLOPE_ANGLE = 89      # Steepest angle we can slide up

func _ready():
	camera_control = self
	camera_holder = $CameraMount
	camera        = $CameraMount/Camera

	cam_ref = weakref(camera)

	# Keep the mouse in the current window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_input(true)

func _physics_process(delta):

	var status = "vel      : " + str(vel) + "\n"

	# Intended direction of movement
	var dir = Vector3()

	# Check camera hasn't been freed
	# May not be necessary witout threading
	if not cam_ref.get_ref():
		camera  = $CameraMount/Camera
		cam_ref = weakref(camera)
		return

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
	if Input.is_action_pressed("up"):
		dir += cam_xform.basis.y.normalized()
	if Input.is_action_pressed("down"):
		dir += -cam_xform.basis.y.normalized()

	# Remove any extra vertical movement from the direction
	# dir.y = 0
	dir = dir.normalized()

	# Get the current horizontal only movement
	var hvel = vel
	# hvel.y = 0

	# Get how far we can move horizontally
	var target = dir
	target *= MAX_SPEED

	# Set ac(de)celeration depending on input direction 
	var accel
	if dir.dot(hvel) > 0:
		accel = ACCEL
	else:
		accel = DEACCEL

	# Interpolate between the current (horizontal) velocity and the intended velocity
	hvel = hvel.linear_interpolate(target, accel*delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel.y = hvel.y

	# Use the KinematicBody to control physics movement
	# Slide the first body (kinematic) then move the other bodies to match the movement
	vel = camera_control.move_and_slide(vel, Vector3(0,1,0), 5.0, 4, deg2rad(MAX_SLOPE_ANGLE))
	
	# (optional, but highly useful) Capturing/Freeing the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		# Toggle mouse between captured and visible on ui_cancel
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate camera holder on the X plane given changes to the Y mouse position (Vertical)
		camera_holder.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * -1))
		
		# Rotate cameras on the Y plane given changes to the X mouse position (Horizontal)
		camera_control.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
	
		# Clamp the vertical look to +- 70 because we don't do back flips or tumbles
		var camera_rot = camera_holder.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		camera_holder.rotation_degrees = camera_rot
