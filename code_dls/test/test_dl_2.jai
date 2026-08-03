#import "thegame_shared_library";

#program_export
ExternalUpdate :: (shared_lib : *SharedLibraryData) {
	CreateManyMusicPtsInMemory(float64.[0,3,7], 0, 2, 4, *shared_lib.all_mspace_data.*[0].all_music_pts);	
}