#import "Basic";
#import "thegame_shared_library";
#import "thegame_input";

#program_export
ExternalRunOnce :: (shared : *SharedLibraryData) {
	//TODO Need a dynamic library that runs every frame in order for this to work.
	if IsKeyboardPress(#char "W", .{alt_pressed=true}, .DOWN_THIS_FRAME, shared.game_input) {
		print("pressed alt+w\n");
	}	

	//Can also set input mapping from here directly so we don't need input mappings file
	shared.game_input.game_input_mappings[InputMapType.TERMINAL_TOGGLE].keyboard_maps[0] = 
		.{xx #char "T", .{alt_pressed=true}};;
}