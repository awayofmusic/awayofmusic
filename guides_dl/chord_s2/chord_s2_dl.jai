#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";

#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op chords2
	*/
	op_space_name : string = "chords2";
	op_space, found_op_space := FindOpSpacePointerOpenOrClosed(op_space_name, 
		sld.all_open_op_spaces, sld.all_closed_op_spaces.*);
	if !found_op_space {
		cosd : CreateOpSpaceData;
		cosd.op_space_name = op_space_name;
		cosd.op_space_external_type = OpSpaceExternalType.space_2d;
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
	op_spec_data : *OpSpaceSpecData;
	for * sld.all_op_space_spec_data.* if it.op_space_id == op_space.id {
		op_spec_data = it;
		break;
	}

	create_cs2 : CreateChordS2Data;
	create_cs2.world_pos = Vector2F.{0,0};
	create_cs2.point_dim = Vector2F.{0.7,0.7};
	create_cs2.scale_world_unit = 2.0;
	//Separate linear point count since we can have multiple tuning systems with the same number of points
	create_cs2.lp_count = 12;
	create_cs2.tuning_system_id = 0; //index 0 is "et12" by default
	create_cs2.vl_order_text = true;
	create_cs2.vl_order_color = true;
	create_cs2.is_sound_float = false;
	create_cs2.osc_wave_type = OscWaveType.SAW;
	//This is set by default in CreateChordS2Data but I am leaving here for clarity
	// create_cs2.new_cs_filters = .[.{filter_type=.ALL}];
	chord_s2 : *ChordSpace2 = CreateChordSpace2(create_cs2, op_spec_data);

	//We only need to use the alloc for filtered points since the chord space points will be permanently stored in memory.
	cs2_points : *ChordS2Points2D = GetOrCreateCS2Points(create_cs2.lp_count, sld.all_cs2_points_2D);
	FilterCS2D(chord_s2.*, cs2_points.*, *op_spec_data.ass, 
		chord_s2.cs_filters, chord_s2.cs_filter_aggregate,,op_spec_data.spec_2D_alloc);

	AddChordS2ToOpSpace(op_space.id, chord_s2, *op_spec_data.all_op_collision_entities);


	start_chord := float64.[6,9];
	vl_events := VLEvent.[
		.{.[-4,-3]},
		.{.[+2,+2]},
		.{.[+2,+2]}
	];
	vl_end_points, vl_points_no_dim := ProcessVoiceLeadingEventsNDim(chord_s2.dspace_id,
		start_chord, vl_events, chord_s2.music_pt_count, chord_s2.next_group_order,,temp);
	CreateVoiceLeadingShapes2D(op_space.id, chord_s2,
		vl_end_points, vl_points_no_dim, *op_spec_data.ass,,op_spec_data.spec_2D_alloc);
}