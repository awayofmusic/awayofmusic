#import "Basic";
#import "thegame_shared_library";

found_new_points : bool = false;

/*TODO FROM HERE pass in CreateMusicRow and then also make a module out of thegame_audio
and then we should have AudioData available for adding to the audio buffer

WE COULD ALSO allow rendering to an op_space once we add op spaces since the render group is in there
*/

//TODO Interesting here that if the function input is wrong, it will still work
//as long as we can compile it which implies that the inputs we use are in the function call.
//TODO should pass in audio somehow for synth and audio creation levels
#program_export
ExternalUpdate :: (shared_lib : *SharedLibraryData) {
	// print("run external update\n");
	// found_new_points = !found_new_points;
	// print("found_new_points=%\n", found_new_points);
	crd : CreateRowData;
	crd.octave_height = 12;
	crd.row_height = 12;
	crd.row_system_type = RowSystemType.internal_pitch;
	//TODO Add a synth at set it here like this
	crd.row_system_id = 0;
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

	test : int = ALL_NEXT_IDS.NEXT_MSPACE_ID;
	CreateManyMusicPtsInMemory(float64.[0,4,7], 0, 0, 2, *shared_lib.all_mspace_data.*[0].all_music_pts);	


	//This works! so we can use this method for custom synths for example and set function pointers back to call
	//We could have to check them. The other method is using more dll functions but that seems like something
	//more for if we want to call functions in different places within the main code base.
	shared_lib.test_foo = TestFooPtr;

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

TestFooPtr :: (t : int) -> int {
	return t + 1;
}