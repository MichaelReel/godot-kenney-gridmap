extends Spatial

func _ready():
	var vr := ARVRServer.find_interface("OpenVR")
	if vr:
		var OpenVR := load("res://camera/OpenVRCamera.tscn")
		var camVR = OpenVR.instance()
		add_child(camVR)
	
