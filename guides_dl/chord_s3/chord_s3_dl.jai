#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";

#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op chords3
	*/
	op_space_name : string = "chords3";
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

	create_cs3 : CreateChordS3Data;
	create_cs3.op_space_id = op_space.id;
	create_cs3.higher_dim = 3;
	create_cs3.lp_count = 12;
	create_cs3.tuning_system_id = 0; //index 0 is "et12" by default
	// create_cs3.cs_filter_aggregate = ChordSpaceFilterAggregate.INTERSECTION;
	create_cs3.new_cs_filters = CSFilter.[
		CSFilter.{0,0,.{},.CHROMATIC},
		// CSFilter.{0,0,.{},.ALL},
		// CSFilter.{3,0,.{},.SUM}
		// CSFilter.{0,0,value_set,.IN_VALUE_SET},
		// CSFilter.{0,0,.{},.NO_DUPLICATE_PITCHES},
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

	chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, sld.all_chord_space_points);
	FilterCS3D(chord_space_points, *op_3D.all_op_space_points_3D, op_3D.op_space_3D.new_cs_filters, create_cs3.cs_filter_aggregate);
	//This needs to be set after in case we set the camera based on filtered points
	op_3D.op_space_3D.cam_trans = Space3DStartCamTrans(create_cs3.s3_cam_start_type, create_cs3.cam_focus_fun_region_pos, create_cs3.cam_trans, op_3D);

	//TODO FROM HERE add generalized voice leadings for 3d
}