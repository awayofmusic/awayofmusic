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
	test : int = ALL_NEXT_IDS.NEXT_MSPACE_ID;
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