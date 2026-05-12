extends AnimationPlayer


func _ready():
	interpolation_change() # run the function in question

func interpolation_change():
	for animation in get_animation_list():
		var anim_track_1: Animation = get_animation(animation)
		# get number of tracks (bones in your case)
		var count: int = anim_track_1.get_track_count()
		for i in count:
			# change interpolation mode for every track
			anim_track_1.track_set_interpolation_type(i, Animation.INTERPOLATION_NEAREST)