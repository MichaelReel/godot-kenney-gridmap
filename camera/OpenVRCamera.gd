extends ARVROrigin

func _ready():
	var vr := ARVRServer.find_interface("OpenVR")
	if vr and vr.initialize():
		get_viewport().arvr = true
		get_viewport().hdr = false
	else:
		print ("Open VR interface expected, but not available!")
		
