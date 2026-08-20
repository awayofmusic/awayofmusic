#import "Remap_Context"(VERBOSE=false);
// #import "Basic";

#import "thegame_shared_library";
#import "thegame_input";

/*Copy this file to startup/startup_dl.jai and then that will get automatically compiled, loaded and running on startup.
Currently this only works with a startup setting load_startup_dl=true BUT once jai is publically available, then
this will be the only way of updating input mappings and runtime settings and anything else that is added later.
Below are some examples of setting up input mapping and runtime settings and loading other dls for startup setup.
This can also be used to setup anything else as it is just like any other dl but runs automatically once the first frame.
ExternalRunOnce will run once before ExternalPerFrame if the functions are added here.
*/
#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	//This line is necessary at the beggining of each dl to pass in the context from the main program 
	//which contains IDs and other information.
	Remap_Context();

	/*This is a much simpler way to update input mappings and settings overall.
	TODO Once jai is public, then this will be the only way so we can remove all the old code
	and just keep the startup_settings file
	*/
	im : [] InputMapping = sld.game_input.game_input_mappings;
	im[InputMapType.TEXT_DEBUG_TOGGLE].keyboard_maps[0] = .{xx #char "D", .{alt_pressed=true}}; 


	//This is how we would update the settings
	sld.update_runtime_settings_from_dl = true;
	sld.to_update_runtime_settings.save_file_on_focus_lost = false;

	//We can also compile, load and run other dls like this
	//We can check if things were loaded by just running once multiple times after loading each thing
	//When updating this software, it is recommended to recompile manually or create your own local system script
	//to do that so that compiler errors can be corrected before loading dls here.
	//Generally best to compile externally and just load valid dls here. This command is left here for convenience.
	// array_add(sld.all_terminal_events, MakeTerminalEvent(.jai, JAI_NAME));
	// array_add(sld.all_terminal_events, MakeTerminalEvent(.load_dl, DL_NAME));
	// array_add(sld.all_terminal_events, MakeTerminalEvent(.run_dl_once, DL_NAME));
	// array_add(sld.all_terminal_events, MakeTerminalEvent(.start_dl_per_frame, DL_NAME));
}

#program_export
ExternalPerFrame :: (sld : *SharedLibraryData) {
	//This line is necessary at the beggining of each dl to pass in the context from the main program 
	//which contains IDs and other information.
	Remap_Context();
}