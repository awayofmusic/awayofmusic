#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_audio";
#import "thegame_input";

/*
This is a dynamic library (dl) that gets loaded at runtime.
All code in the above libraries is accessible through dls.
It is recommended to copy this file so that git updates will not conflict locally.

To build this dl, run this command from the root directory :
jai build_dl_thegame.jai -import_dir "." - guides_dl/intro/intro_dl 

To load the dl from the internal command line run :
load_dl guides_dl/intro/intro_dl.dll

To run ExternalRunOnce 1 time from the internal command line run :
run_dl guides_dl/intro/intro_dl.dll

If re-compiled, this dl will automatically reload with a message in the system terminal.
*/
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

	// tano(0,0..2) ~= int.[0,4,7];
	CreateManyMusicPtsInMemory(float64.[0,4,7], 0, 0, 2, 
		*shared_lib.all_mspace_data.*[0].all_music_pts);	
	// tano(0,2..4) ~= int.[0,3,7];
	CreateManyMusicPtsInMemory(float64.[0,3,7], 0, 2, 4, 
		*shared_lib.all_mspace_data.*[0].all_music_pts);	
	
	//Opening other op spaces can be found in guides_dl/circle.

	/*
	rd.row_system_id = synth.ret_synth_id;
	rd.row_sub_system_id = cast(int) SimpleSynthMessageType.VOLUME;
	//Can use right click knob and press link controller in fl studio 
	//to set midi channel and cc messages.
	//cc messages may not map directly to the neume values
	//rd.row_system_type = RowSystemType.midi_control_change;
	//rd.row_midi_data.midi_channel = 0;
	//rd.row_midi_data.midi_control_change = 0;
	#asm{ create_row rd; }

	for x : 0..11 {
		tano(1,x) ~= 0.15 * cast(float) x;
		//For midi cc message
		// tano(1,x) ~= 10*x;
	}
	*/
}

/*
The ExternalPerFrame function below will run every frame.
An example of creating some music with keyboard input is given.

Global variables work but if you want the data to remain the same after a reload, then 
the data needs to be stored in either my_shared_data or my_per_dl_data.

TODO We can also pass in an allocator if that helps in some way.
*/
mp_value : int = 0;
MyExternData :: struct {
	my_mp : int = 0;
}
#program_export
ExternalPerFrame :: (sld : *SharedLibraryData) {
	Remap_Context();
	
	if sld.my_per_dl_data == null {
		sld.my_per_dl_data = New(MyExternData);
	}
	my_data := cast(*MyExternData) sld.my_per_dl_data;
 	if IsKeyboardPress(#char "Q", .{ctrl_pressed=true}, .DOWN_THIS_FRAME, sld.game_input) {
		CreateMusicPtInMemory(my_data.my_mp, 0, my_data.my_mp+5, my_data.my_mp+6, *sld.all_mspace_data.*[0].all_music_pts);
		my_data.my_mp += 1;
 	}
}