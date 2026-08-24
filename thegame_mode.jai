/*TODO what should we call this file?
	***this file should be thegame_base.jai and other files should be
	thegame_play_mode and thegame_test_mode and etc...***
*/

#import "Basic";
#import "Math";
#import "Process";
#import "Clipboard";
#import "Flat_Pool";
// #import "Pool";

//TODO Could put this anywhere and import relatively here
// #import,dir "jai-midi";

//TODO Could place these in a dir with all module to import eventually
#import "thegame_math";
#import "thegame_audio";
#import "thegame_shared_library";
#import "thegame_renderer_out_data";
#import "thegame_common_data";
#import "thegame_array_poly";
#import "thegame_input";

#import "shared_names";

#load "thegame_base.jai";
#load "thegame_test.jai";
#load "thegame_unit_tests.jai";

#load "thegame_platform_data.jai";
#load "thegame_random.jai";
#load "thegame_strings.jai";
#load "thegame_data.jai";
#load "thegame_op_space.jai";
#load "thegame_profiler.jai";
#load "thegame_serializer.jai";
#load "thegame_code.jai"; //TODO Should this just go in data for now?
#load "thegame_settings.jai";

//TODO leaving this name for now to have access to old files
//can update later when we no longer need other files in "thegame.jai"
// UpdateAndRender :: inline (game_memory : *GameMemory,
UpdateAndRender :: (game_memory : *GameMemory,
						  renderer_data : *RendererData,
                    audio_data : *AudioData,
                    game_input : *GameInput) 
{	
	//TODO FROM HERE put is_initialized code here and make sure that's working to remove bugs with uninitalized data like
	//input mappings or anything else that might be used here or in the test function
	game_state := cast(*GameState) game_memory.PermanentStorage;
	perm := *game_state.persist;	
	keyboard := game_input.Controllers[0];
	if IsInputMapPress(.DEV_TEST_MODE, .DOWN_THIS_FRAME, game_input) {
		if perm.game_mode == {
		case .TEST; perm.game_mode = .PLAY;
		case .PLAY; perm.game_mode = .TEST;
		}
		print("mode=%\n", perm.game_mode);
	}

	/*TODO IMPORANT Eventually we should swap out all_data just for the test and have separate data allocators
	  for game and test so that then we don't have to worry about overlap.
	*/
	/*TODO This can be done at compile time as a build option to have a test build since the player
	build will likely not want this. Although maybe they would want access to the test framework
	when writing their own code... hmmmm...
	*/
	//TODO this could be a separate file for testing
	if GameMode.PLAY == perm.game_mode {
	    UpdateAndRenderBase(game_memory, renderer_data, audio_data, game_input);
	} else if GameMode.TEST == perm.game_mode {
		//Does this still need to be separate? We run the test and then call UpdateAndRenderBase anyways.
		//Will keep it separate for now as this is more flexible in case we want to do more with testing.
		UpdateAndRenderTest(game_memory, renderer_data, audio_data, game_input);
	}
}