#import "Remap_Context"(VERBOSE=false);
// #import "Basic";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_array_poly";

#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	ROWS :: CreateRowData.[
	.{row_section_data=.[.{x_length=2,tuning_system_id=0},.{x_length=4,tuning_system_id=1}], row_system_type=.internal_pitch},
	.{row_section_data=.[.{x_length=2,tuning_system_id=0},.{x_length=4,tuning_system_id=1}], row_system_type=.internal_pitch},
	];
	for ROWS {
		CreateMusicRow(it,
			sld.all_mspace_data.*,
			sld.global_rules,
			sld.all_tuning_systems.*,
			sld.all_tuning_pitches.*,
			sld.all_linear_to_tuning_system,
			sld.all_linear_pitch_spaces,
			sld.all_space_points); 
	}

	gcmd : GetOrCreateMSpaceData;
	gcmd.gc_type = .GET_BY_INDEX;
	gcmd.mspace_index = 0;
	mspace_0 : *MusicSpaceData = 
		GetOrCreateMusicSpace(gcmd, sld.runtime_settings, sld.all_mspace_data, sld.free_mspace_data_pool);
	// row_0 : *MusicLaneRow = *mspace_0.all_music_lane_rows[0];
	// row_0.external_hover_row = false;
	// row_0.row_system_type = RowSystemType.midi_pitch;
	// row_0.row_midi_data.midi_port = 0;
	// row_0.row_midi_data.midi_channel = 0;
	// row_0.row_midi_data.midi_velocity = 100;
	// row_0.row_midi_data.midi_zero_note = 12*4;

	ClearMusicSpace(.{mspace_0.mspace_id}, sld.all_mspace_data);


	mp_9 : MusicPoint = MakeMusicPoint(2,1,3,6);
	mp_10 : MusicPoint = MakeMusicPoint(10,1,3,6);
	mp_0 : MusicPoint = MakeMusicPoint(0,0,0,3);
	CreateMusicPtInMemory(mp_0, *mspace_0.all_music_pts);
	mp_1 : MusicPoint = MakeMusicPoint(6,0,0,3);
	CreateMusicPtInMemory(mp_1, *mspace_0.all_music_pts);
	mp_2 : MusicPoint = MakeMusicPoint(1,0,3,6);
	CreateMusicPtInMemory(mp_2, *mspace_0.all_music_pts);
	mp_3 : MusicPoint = MakeMusicPoint(9,0,3,6);
	CreateMusicPtInMemory(mp_3, *mspace_0.all_music_pts);

	mp_4 : MusicPoint = MakeMusicPoint(2,1,0,1);
	CreateMusicPtInMemory(mp_4, *mspace_0.all_music_pts);
	mp_5 : MusicPoint = MakeMusicPoint(6,1,0,1);
	CreateMusicPtInMemory(mp_5, *mspace_0.all_music_pts);
	mp_6 : MusicPoint = MakeMusicPoint(8,1,0,1);
	CreateMusicPtInMemory(mp_6, *mspace_0.all_music_pts);
	mp_7 : MusicPoint = MakeMusicPoint(4,1,1,3);
	CreateMusicPtInMemory(mp_7, *mspace_0.all_music_pts);
	mp_8 : MusicPoint = MakeMusicPoint(6,1,1,3);
	CreateMusicPtInMemory(mp_8, *mspace_0.all_music_pts);
	CreateMusicPtInMemory(mp_9, *mspace_0.all_music_pts);
	CreateMusicPtInMemory(mp_10, *mspace_0.all_music_pts);

	//See guides_dl/circle/circle_dl.jai for an important note on creating op space and allocating data from a dl
	/*To open this op space from the internal terminal run :
	open_op op_r
	*/
	op_space_name : string = "op_r";
	op_space, found_op_space := FindOpSpacePointerOpenOrClosed(op_space_name,
		sld.all_open_op_spaces, sld.all_closed_op_spaces.*);
	if !found_op_space {
		cosd : CreateOpSpaceData;
		cosd.op_space_external_type = OpSpaceExternalType.space_2d;
		cosd.op_space_name = op_space_name;
		op_space = CreateClosedOpSpace(cosd,
			sld.all_closed_op_spaces, 
			sld.all_op_space_spec_data, 
			sld.all_op_spec_data_3D);
	}

	op_rows : [2] CreateRowData;
	op_rows[0] = ROWS[0];
	op_rows[0].x_point_width = 1.5;
	op_rows[0].op_world_pos = Vector2F.{0,5};
	op_rows[0].op_ref_row_id = mspace_0.all_music_lane_rows[0].id;
	op_rows[0].op_row_type = .COPY_MUSIC_ROW;

	op_rows[1] = ROWS[1];
	op_rows[1].op_world_pos = Vector2F.{1,-10};
	op_rows[1].x_point_width = 1.75;
	op_rows[1].op_row_type = OpRowType.MULTI_SECTION;
	op_rows[1].op_ref_mspace_id = 0;
	op_rows[1].op_ref_start_x = 1;
	op_rows[1].op_ref_row_id = mspace_0.all_music_lane_rows[1].id;
	op_rows[1].row_section_data = .[.{x_length=1,tuning_system_id=0},.{x_length=3,tuning_system_id=1}];

	op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(sld.all_op_space_spec_data.*,
		op_space.id, "op_space_id");
	for op_rows {
		CreateOpRow(it, op_spec_data,
			sld.all_mspace_data.*,
			sld.all_tuning_systems.*,
			sld.all_tuning_pitches.*,
			sld.all_linear_to_tuning_system,
			sld.all_linear_pitch_spaces,
			sld.all_space_points);
	}
}