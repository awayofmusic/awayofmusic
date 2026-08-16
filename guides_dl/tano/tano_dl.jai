//TODO FROM HERE tano/music_pts guide with loops instead of internal tano syntax
#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_audio";
#import "thegame_input";

//TODO FROM HERE write notes here and maybe do a separate commit for the history select offset bug fix
#program_export
ExternalRunOnce :: (shared_lib : *SharedLibraryData) {
	//This line is necessary at the beggining of each dl to pass in the context from the main program 
	//which contains IDs and other information.
	Remap_Context();

	//This will clear all the data in this mspace which allows 
	//us to recreate everything every time we run this code.
	ClearMusicSpace(*shared_lib.all_mspace_data.*[0]);

	//Library structs and functions are in c_load/Library.
	//This can be opened in an external text editor for convenience.
	gocss : GetOrCreateSimpleSynthData;
	gocss.synth_name = "s0";
	synth_0 : *SimpleSynth = GetOrCreateSimpleSynth(gocss, shared_lib.all_simple_synths, shared_lib.free_simple_synth_pool);
	update_synth : UpdateSimpleSynthData;
	update_synth.synth_id = synth_0.synth_id;
	update_synth.update_wave_type = true;
	update_synth.wave_type = OscWaveType.SINE;
	//Volume is between 0-1 and is set for each neume
	//so 0.1 for 3 values will be 0.3 overall
	//anything above 1 will be clipped and likely cause audible distortion
	update_synth.update_volume = true;
	update_synth.volume = 0.1;
	UpdateSimpleSynth(synth_0, update_synth);

	gocss_1 : GetOrCreateSimpleSynthData;
	gocss_1.synth_name = "s1";
	synth_1 : *SimpleSynth = GetOrCreateSimpleSynth(gocss_1, shared_lib.all_simple_synths, shared_lib.free_simple_synth_pool);
	update_1 : UpdateSimpleSynthData;
	update_1.synth_id = synth_1.synth_id;
	update_1.update_wave_type = true;
	update_1.wave_type = OscWaveType.SINE;
	update_1.update_volume = true;
	update_1.volume = 0.1;
	UpdateSimpleSynth(synth_1, update_1);

	tuning : TuningSystem;
	for shared_lib.all_tuning_systems.* if it.short_name == "et12" {
		tuning = it;
		break;
	}
	crd : CreateRowData;
	crd.octave_height = cast(float) tuning.music_pt_count;
	crd.row_height = 1.5*tuning.music_pt_count;
	crd.row_system_type = RowSystemType.internal_pitch;
	row_sections : [1] RowSectionData;
	row_sections[0].tuning_system_id = tuning.id;
	row_sections[0].x_length = 24;
	crd.row_section_data = row_sections;
	crd.row_system_id = synth_0.synth_id;
	CreateMusicRow(crd,
		shared_lib.all_mspace_data.*,
		shared_lib.global_rules,
		shared_lib.all_tuning_systems.*,
		shared_lib.all_tuning_pitches.*,
		shared_lib.all_linear_to_tuning_system,
		shared_lib.all_linear_pitch_spaces,
		shared_lib.all_space_points);

	crd.row_base_pt = -3;
	crd.row_system_id = synth_1.synth_id;
	CreateMusicRow(crd,
		shared_lib.all_mspace_data.*,
		shared_lib.global_rules,
		shared_lib.all_tuning_systems.*,
		shared_lib.all_tuning_pitches.*,
		shared_lib.all_linear_to_tuning_system,
		shared_lib.all_linear_pitch_spaces,
		shared_lib.all_space_points);

	mps_0 : *[..] MusicPoint = *shared_lib.all_mspace_data.*[0].all_music_pts;
	#if 1 {
	CreateMusicPtInMemory(9,0,0,1,mps_0);
	CreateMusicPtInMemory(5,0,1,2,mps_0);
	CreateMusicPtInMemory(7,0,2,3,mps_0);
	CreateMusicPtInMemory(0,0,3,4,mps_0);

	from_tano_rev : tano = MakeTano(0,0,4,2);
	to_tano_rev : tano = MakeTano(0,0,5,7);
	for mp : TanoLoop.{from_tano_rev, mps_0.*} {
		new_mp : MusicPoint = TMovMusicPt(mp, from_tano_rev, to_tano_rev);
		CreateMusicPtInMemory(new_mp, mps_0);
	}
	from_tano : tano = MakeTano(0,0,0,2);
	to_tano : tano = MakeTano(0,0,7,9);
	for mp : TanoLoop.{from_tano, mps_0.*} {
		new_mp : MusicPoint = TMovMusicPt(mp, from_tano, to_tano);
		CreateMusicPtInMemory(new_mp, mps_0);
	}


	from_tano = MakeTano(0,0,9,0);
	to_tano = MakeTano(1,1,0,9);
	for mp : TanoLoop.{from_tano, mps_0.*} {
		new_mp : MusicPoint = TMovMusicPt(mp, from_tano, to_tano);
		//This would be inversion/reflection
		new_mp.music_pt_float = 12 - new_mp.music_pt_float;
		//This would be transposition.
		new_mp.music_pt_float -= 5;
		//Any other mathematical operation can be applied here directly.
		CreateMusicPtInMemory(new_mp, mps_0);
	}
	} else {
	// tano(0,0..2) ~= int.[0,4];
	CreateManyMusicPtsInMemory(float64.[0,4], 0, 0, 1, mps_0);	
	// tano(0,2..4) ~= int.[0,3];
	CreateManyMusicPtsInMemory(float64.[0,2], 0, 1, 2, mps_0);

	from_tano : tano = MakeTano(0,0,0,2);
	to_tano : tano = MakeTano(1,1,0,2);
	for mp : TanoLoop.{from_tano, mps_0.*} {
		new_mp : MusicPoint = TMovMusicPt(mp, from_tano, to_tano);
		//This would be inversion/reflection
		new_mp.music_pt_float = 12 - new_mp.music_pt_float;
		//This would be transposition.
		new_mp.music_pt_float -= 1;
		//Any other mathematical operation can be applied here directly.
		CreateMusicPtInMemory(new_mp, mps_0);
	}

	//This is the reverse/retrograde of the original chords by reversing the x order.
	from_tano_rev : tano = MakeTano(0,0,2,0);
	to_tano_rev : tano = MakeTano(1,1,2,4);
	for mp : TanoLoop.{from_tano_rev, mps_0.*} {
		new_mp : MusicPoint = TMovMusicPt(mp, from_tano_rev, to_tano_rev);
		CreateMusicPtInMemory(new_mp, mps_0);

		new_mp.music_pt_float += 5;
		CreateMusicPtInMemory(new_mp, mps_0);
	}

	//Reverse the rows and copy them over again
	from_tano_row_rev : tano = MakeTano(1,0,0,4);
	to_tano_row_rev : tano = MakeTano(0,1,4,8);
	for mp : TanoLoop.{from_tano_row_rev, mps_0.*} {
		new_mp : MusicPoint = TMovMusicPt(mp, from_tano_row_rev, to_tano_row_rev);
		CreateMusicPtInMemory(new_mp, mps_0);
	}
	}

	//Examples of rhythmic transformations can be found with tshr/tshl and tror/trol in thegame_code

	//Can use this to filter tano notes directly
	// to_tano_norm : tano = NormalizeTano(to_tano);
	// if InTanoAssumeNorm(new_mp, to_t_norm); {
		// CreateMusicPtInMemory(new_mp, to_neumes);
	// }

	//Created a third row to adjust synth parameters
	#if 0 {
	crd.row_base_pt = 0;
	crd.row_system_type = RowSystemType.internal_message;
	crd.row_system_id = synth_1.synth_id;
	crd.row_sub_system_id = cast(int) SimpleSynthMessageType.WAVE_TYPE;
	CreateMusicRow(crd,
		shared_lib.all_mspace_data.*,
		shared_lib.global_rules,
		shared_lib.all_tuning_systems.*,
		shared_lib.all_tuning_pitches.*,
		shared_lib.all_linear_to_tuning_system,
		shared_lib.all_linear_pitch_spaces,
		shared_lib.all_space_points);
	from_tano = MakeTano(0,0,0,9);
	to_tano = MakeTano(2,2,0,9);
	for mp : TanoLoop.{from_tano, mps_0.*} {
		new_mp : MusicPoint = TMovMusicPt(mp, from_tano, to_tano);
		new_mp.music_pt_float += 1;
		CreateMusicPtInMemory(new_mp, mps_0);
	}
	}
}