#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";
#import "shared_names";
#import "thegame_array_poly";

#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op customs3
	*/
	op_space_name : string = "customs3";
	op_space, found_op_space := FindOpSpacePointerOpenOrClosed(op_space_name, 
		sld.all_open_op_spaces, sld.all_closed_op_spaces.*);
	if !found_op_space {
		cosd : CreateOpSpaceData;
		cosd.op_space_name = op_space_name;
		cosd.op_space_external_type = OpSpaceExternalType.space_3d;
		op_space = CreateClosedOpSpace(cosd, 
			sld.all_closed_op_spaces, 
			sld.all_op_space_spec_data, 
			sld.all_op_spec_data_3D);
	}

	clear_data : ClearOpSpaceData;
	clear_data.op_space_id = op_space.id;
	ClearOpSpace(clear_data,
		sld.all_open_op_spaces,
		sld.all_closed_op_spaces.*,
		sld.all_op_space_spec_data.*,
		sld.all_op_spec_data_3D.*);

	//Can check for missing spec data here if needed.
	op_3D : *OpSpecData3D;
	for * sld.all_op_spec_data_3D.* if it.op_space_id == op_space.id {
		op_3D = it;
		break;
	}

	tuning : TuningSystem;
	for sld.all_tuning_systems.* if it.short_name == "et24" {
		tuning = it;
		break;
	}

	create_cs3 : CreateChordS3Data;
	create_cs3.op_space_id = op_space.id;
	create_cs3.higher_dim = 3;
	create_cs3.lp_count = 12;
	//This tuning system id is for group_id 0 which is what the chord space points use if they are generated.
	create_cs3.tuning_system_id = 0; //index 0 is "et12" by default
	// create_cs3.cs_filter_aggregate = ChordSpaceFilterAggregate.INTERSECTION;
	create_cs3.new_cs_filters = CSFilter.[
		CSFilter.{0,0,.{},.NONE},
		// CSFilter.{0,0,.{},.CHROMATIC},
	];
	create_cs3.s3_cam_start_type = S3CamStartType.USER_SET;
	UpdateTranslation(*create_cs3.cam_trans, Vector3F.{0,0,0});
	create_cs3.mouse_rotate = DEFAULT_CHORD_S3_ROTATION;
	// create_cs3.mouse_rotate = DEFAULT_CHORD_S4_ROTATION;
	//These values can be adjusted to change the 3d perspective
	// create_cs3.depth = DEFAULT_3D_DEPTH;
	// create_cs3.n = DEFAULT_3D_N;
	// create_cs3.f = DEFAULT_3D_F;
	CreateSpace3D(op_space.world_size, create_cs3, op_3D);

	//For custom 3d geometries, chord space point generation/filtering is optional
	// chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, sld.all_chord_space_points);
	// FilterCS3D(chord_space_points, *op_3D.all_op_space_points_3D, op_3D.op_space_3D.new_cs_filters, create_cs3.cs_filter_aggregate);
	//This needs to be set after in case we set the camera based on filtered points
	op_3D.op_space_3D.cam_trans = Space3DStartCamTrans(create_cs3.s3_cam_start_type, create_cs3.cam_focus_fun_region_pos, create_cs3.cam_trans, op_3D);

	//group_id 0 is the default 3d group id. 
	//Associating shapes to group_id 0 will have the same properties as the chord_s3 geometry if created.
	//Therefore all custom 3d geometries should have group_id >= 1.
	custom_3D : *CustomGeom3D = array_add(*op_3D.all_custom_geom_3D);
	custom_3D.group_id = 1;
	custom_3D.tuning_system_id = tuning.id;
	custom_3D.custom_audio_type = CustomAudioType.TUNING_SYSTEM;
	custom_3D.osc_wave_type = OscWaveType.SAW;

	sp_3D : *SpacePoint3D = array_add(*op_3D.all_op_space_points_3D);
	sp_3D.id = context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID;
	context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID += 1;
	sp_3D.do_not_remove_with_filter = true;
	sp_3D.rel_pos = Vector3F.{0,20,30};
	sp_3D.group_id = custom_3D.group_id;
	sp_3D.scale_value = 0.8;
	//Not setting this will use the default multi-color
	sp_3D.color = Vector4F.{0,1,0,1};
	//pitch_set will be played on mouse hover based on the geometry tuning system
	sp_3D.pitch_set = array_copy(float64.[0,8,14],, op_3D.spec_3D_alloc);
	//shape_text will appear on mouse hover based on the geometry tuning system
	sp_3D.shape_text = copy_string("24-[0,8,14]",, op_3D.spec_3D_alloc);
	//fun_region is optional and can be generally used to store extra data if needed
	// sp_3D.fun_region = OrderedPitchSetToFundamentalRegion(sp_3D.pitch_set, cast(float64) tuning.music_pt_count,, op_3D.spec_3D_alloc);
	// sp_3D.draw_wire_mesh = false;
	// sp_3D.is_selectable = true;

	space_text : *SpaceText3D = array_add(*op_3D.all_op_text_3D);
	space_text.group_id = custom_3D.group_id;
	space_text.op_pos = Vector3F.{0,23,30};
	SetSpaceText3D("24eq", space_text);
}