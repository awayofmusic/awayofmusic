#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_audio";
#import "thegame_input";

#program_export
ExternalRunOnce :: (shared_lib : *SharedLibraryData) {
	//This line is necessary at the beggining of each dl to pass in the context from the main program 
	//which contains IDs and other information.
	Remap_Context();

	if shared_lib.my_per_dl_data == null {
		shared_lib.my_per_dl_data = New(MyATData);
	}

	//This will clear all the data in this mspace which allows 
	//us to recreate everything every time we run this code.
	ClearMusicSpace(*shared_lib.all_mspace_data.*[0]);

	//Library structs and functions are in c_load/Library.
	//This can be opened in an external text editor for convenience.
	gocss : GetOrCreateSimpleSynthData;
	gocss.synth_name = "s0";
	synth : *SimpleSynth = GetOrCreateSimpleSynth(gocss, shared_lib.all_simple_synths, shared_lib.free_simple_synth_pool);
	update_synth : UpdateSimpleSynthData;
	update_synth.synth_id = synth.synth_id;
	update_synth.update_wave_type = true;
	update_synth.wave_type = OscWaveType.SAW;
	//Volume is between 0-1 and is set for each neume
	//so 0.1 for 3 values will be 0.3 overall
	//anything above 1 will be clipped and likely cause audible distortion
	update_synth.update_volume = true;
	update_synth.volume = 0.1;
	UpdateSimpleSynth(synth, update_synth);

	tuning : TuningSystem;
	for shared_lib.all_tuning_systems.* if it.short_name == "et12" {
		tuning = it;
		break;
	}
	crd : CreateRowData;
	crd.octave_height = 12;
	crd.row_height = 12;
	crd.row_system_type = RowSystemType.internal_pitch;
	crd.row_system_id = synth.synth_id;
	row_sections : [1] RowSectionData;
	row_sections[0].tuning_system_id = tuning.id;
	row_sections[0].x_length = 24;
	crd.row_section_data = row_sections;
	// crd.row_system_type = RowSystemType.midi_pitch;
	// crd.row_midi_data.midi_channel = cast(u8) row_midi_data.midi_channel;
	// crd.row_midi_data.midi_velocity = cast(u8) row_midi_data.midi_velocity;
	// crd.row_midi_data.midi_control_change = cast(u8) row_midi_data.midi_control_change;
	CreateMusicRow(crd,
		shared_lib.all_mspace_data.*,
		shared_lib.global_rules,
		shared_lib.all_tuning_systems.*,
		shared_lib.all_tuning_pitches.*,
		shared_lib.all_linear_to_tuning_system,
		shared_lib.all_linear_pitch_spaces,
		shared_lib.all_space_points);
}

MyATData :: struct {
	last_x : int;
}
#program_export
ExternalPerFrame :: (sld : *SharedLibraryData) {
	Remap_Context();
	
	my_data := cast(*MyATData) sld.my_per_dl_data;
	gap : GameAudioPlay = sld.game_audio_play;
 	if gap.play_state == AudioPlayState.PLAY {
 		//float_x_memory can be used for in between values and rel_play_time can be used for time from start
 		if my_data.last_x == gap.current_x_memory {
 			//This will get printed on each start_x in sync with the system audio clock.
 			print("current_x_memory=%\n", gap.current_x_memory);
 			//This needs to be the next x so we can hear it since we load music pts on the start of the x value.
			CreateMusicPtInMemory(gap.current_x_memory, 0, gap.current_x_memory+1, gap.current_x_memory+2, *sld.all_mspace_data.*[0].all_music_pts);
			my_data.last_x += 1;
		}
 	}
 	else if gap.play_state == AudioPlayState.STOP {
 		my_data.last_x = 0;
 		array_reset_keeping_memory(*sld.all_mspace_data.*[0].all_music_pts);
 	}
}