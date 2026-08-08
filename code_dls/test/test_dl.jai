#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_audio";
#import "thegame_input";

found_new_points : bool = false;

/*TODO FROM HERE pass in CreateMusicRow and then also make a module out of thegame_audio
and then we should have AudioData available for adding to the audio buffer

WE COULD ALSO allow rendering to an op_space once we add op spaces since the render group is in there
*/

//TODO Interesting here that if the function input is wrong, it will still work
//as long as we can compile it which implies that the inputs we use are in the function call.
//TODO should pass in audio somehow for synth and audio creation levels
#program_export
ExternalRunOnce :: (shared_lib : *SharedLibraryData) {
	Remap_Context();

	//TODO We could set ids from context everywhere so its the same everywhere and then we don't need it here.
	// ALL_NEXT_IDS = context.ALL_NEXT_IDS.;
	// print("run external update\n");
	// found_new_points = !found_new_points;
	// print("found_new_points=%\n", found_new_points);

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


	crd : CreateRowData;
	crd.octave_height = 12;
	crd.row_height = 12;
	crd.row_system_type = RowSystemType.internal_pitch;
	//TODO Add a synth at set it here like this
	crd.row_system_id = synth.synth_id;
	row_sections : [1] RowSectionData;
	row_sections[0].tuning_system_id = shared_lib.all_tuning_systems.*[0].id;
	row_sections[0].x_length = 12;
	crd.row_section_data = row_sections;
	// crd.row_system_type = RowSystemType.midi_pitch;
	// crd.row_midi_data.midi_channel = cast(u8) asm_data.row_midi_data.midi_channel;
	// crd.row_midi_data.midi_velocity = cast(u8) asm_data.row_midi_data.midi_velocity;
	// crd.row_midi_data.midi_control_change = cast(u8) asm_data.row_midi_data.midi_control_change;
	CreateMusicRow(crd,
		shared_lib.all_mspace_data.*,
		shared_lib.global_rules,
		shared_lib.all_tuning_systems.*,
		shared_lib.all_tuning_pitches.*,
		shared_lib.all_linear_to_tuning_system,
		shared_lib.all_linear_pitch_spaces,
		shared_lib.all_space_points);
	
	// test : int = context.ALL_NEXT_IDS.NEXT_MSPACE_ID;
	CreateManyMusicPtsInMemory(float64.[0,4,7], 0, 0, 2, *shared_lib.all_mspace_data.*[0].all_music_pts);	

	// for ts : shared_lib.all_tuning_systems.* {
	// 	print("%\n", ts.short_name);
	// }

	//TODO FROM HERE write a test that tests this dll and have it set music points
	//eventually we can also create anything from here like an op space
	//OR maybe wait since that won't work on mac
	// SetupMusicAndRows(all_data, TWO_ROWS);
	// CreateMusicPtInMemory(0, 0, 0, 1, *all_data.all_mspace_data[0].all_music_pts);
	// CreateManyMusicPtsInMemory(int.[0,3,7,10], 0, 2, 4, *shared_lib.all_mspace_data[0].all_music_pts);
}

/*NOTE : Global variables work but if you want the data to remain the same after a reload, then 
the data needs to be stored in either my_shared_data or my_per_dl_data.

TODO We can also pass in an allocator if that helps in some way.
*/
mp_value : int = 0;
MyExternData :: struct {
	my_mp : int = 0;
}

//TODO FROM HERE Do a similar test but with midi input
//Also add guides for dl and then maybe an example with generalized audio/synth and also generalized rendering
#program_export
ExternalPerFrame :: (sld : *SharedLibraryData) {
	if sld.my_per_dl_data == null {
		sld.my_per_dl_data = New(MyExternData);
	}
	my_data := cast(*MyExternData) sld.my_per_dl_data;
 	if IsKeyboardPress(#char "Q", .{ctrl_pressed=true}, .DOWN_THIS_FRAME, sld.game_input) {
		CreateMusicPtInMemory(my_data.my_mp, 0, my_data.my_mp+5, my_data.my_mp+6, *sld.all_mspace_data.*[0].all_music_pts);
		my_data.my_mp += 1;
 	}
}