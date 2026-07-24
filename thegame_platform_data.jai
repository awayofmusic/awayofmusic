//Colors
BLUE    : u32 : 0xFF0000FF;
LIGHT_BLUE : u32 : 0x00B0FF;
RED     : u32 : 0xFFFF0000;
GREEN   : u32 : 0xFF00FF00;
DARK_GREEN : u32 : 0xFF004B00;
YELLOW  : u32 : GREEN | RED;
MAGENTA : u32 : 0xFFFF00FF;
BLACK   : u32 : 0xFF000000;
WHITE   : u32 : 0xFFFFFFFF;

//TODO try to use these in function creation in macros or something
Type_GameUpdateAndRender :: #type (memory : *GameMemory, audio_data : *AudioData, input : *GameInput) -> ();
Stub_GameUpdateAndRender :: (memory : *GameMemory, audio_data : *AudioData, input : *GameInput) {
    log("We are running Stub_GameUpdateAndRender\n");    
}
Type_DrawLine :: #type (x0 : int, y0 : int, x1 : int, y1 : int, color : u32);
Stub_DrawLine :: (x0 : int, y0 : int, x1 : int, y1 : int, color : u32) {
    log("We are running Stube_DrawLine\n");    
}

Kilobyte :: (bytes : s64) -> s64 #expand {
    return 1024 * bytes;
}

Megabyte :: (bytes : s64) -> s64 #expand {
    return 1024 * Kilobyte(bytes);
}

Gigabyte :: (bytes : s64) -> s64 #expand {
    return 1024 * Megabyte(bytes);
}

#import "Simp";
#import "Math";

WriteFileType :: #type (*void);
ReadFileType :: #type (Filename : string) -> DebugReadFileResult;
GameMemory :: struct {
	IsInitialized : bool;

	//TODO can replace these with jai allocators
	PermanentStorageSize : s64;
	PermanentStorage : *void;

	//TODO Can likely remove this if we just use jai temp storage and other allocators instead now
	TransientStorageSize : s64;
	TransientStorage : *void;

	SetCursorPosition : (x : s32, y : s32);

	//TODO Should likely put this in data because we can have multiple
	//and their pointers so it does not matter if their platform dependent.
	//TODO Should we put this in-game? It is platform dependent...
	midi_output : *MIDI_Output;
	//TODO To be used for midi clock sync
	midi_input  : *MIDI_Input;

	//TODO put this in RendererState/RendererData
	//TODO leaving name for now since Dynamic_Font and Font_Effects are SIMP specific
	SIMPPrepareText : (font: *Dynamic_Font, text: string, effect_flags: Font_Effects = 0) -> (width: s64);
	// Font : *Dynamic_Font;
}

DebugReadFileResult :: struct {
    ContentsSize : u32; //assume <= 4gb file...
    Contents : *void;
}

ButtonClickCount :: struct {
	click_count : u32;
	click_timer : float;
	first_click_x : float;
	first_click_y : float;
}

ButtonState :: struct {
    EndedDown : bool; //This is used for smooth movement since we don't reset it, so maybe should call it SmoothEndedDown
    // HalfTransitionCount : int;
    is_down_with_pause : bool;
    down_this_frame : bool;
    up_this_frame : bool;
}

ControllerInput :: struct {
    IsConnected : bool;
    //TODO maybe we don't want to separate analog
    IsAnalog : bool;

    //TODO Can likely move this out so we only have 1 input buffer.
    //Or just remove everything else from here and have this be TextInput once we do all key presses with new
    //events key mapping shortcut system.
    text_input : ButtonState;
    text_buffer_count : int;
    //TODO Does this really need to be 16, probably 8 is enough since this is a per_frame buffer
    //based on how fast the typed text comes in and fastest typer in the world is 256 wpm.
    //Which is 256/60 = 4.3 words per second -> 4.3 / 60 = 0.071 words per 60 fps frame
    //and even assuming 10 chars per word thats 0.7 words which is 7 characters.
    //However with holding down keys, this could be a bit faster, so we leave it for now.
    //So we store 128 bits but usually we will only have 1-4 chars per frame. So could reduce
    //to eight if we run some tests. (Got 1-4 when i randomly mash all the keys but maybe other 
    //keyboard are different as well).
    //TODO If we store this as a string, then we can remove text_buffer_count and use SIMD to analyze it.
    //Could have a DynamicString or something to store the max and increase if needed like 1kb and if
    //for some reason people can type more than 1000 chars per frame then itll increase.
    text_input_buffer : [16] u8;

    //TODO Can likely remove these if we don't use the gamepad sticks
    StickX : float;
    StickY : float;

    //TODO This can be packed into 3 bits, maybe even 2 bits
    //Then we check all of them just anding with the 3 bits.
    //OR we could have separate arrays for each but that seems less efficient.
    //Than just doing the bit/bool check with an inline function.
    only_alt_down : bool;
    only_ctrl_down : bool;
    only_ctrl_alt_down : bool;
    //TODO Add shift here with options. Then we can move into bits still
    //and it would be alt,ctrl,shift,alt+ctrl,alt+shift,shift+ctrl,shift+alt+ctrl
    //so 7 bits only which would be 1 logical OR to check if all off

    //1 is pause and 0 is not paused
    //TODO Technically this can be packed into 1 bit
    PauseGame : u8;

    /*Eventually it may be best to use the Jai Input more directly and to have the
      input system be based on the Jai input system so we can allow ppl to react
      to any buttons they want in any way they want. Right now we are limited
      to buttons we are using here. Another option is to simply also pass the Jai input
      through to the dll and still use this here in the game if that is more efficient.

      TODO Could have this in an array with an enum converting to numerical values.
      We could even copy the Key_Code enum for Jai input and just convert directly
      from one enum to another and have an array with all approximately 150 values.
      Since each button state is 4 bools, we can actually back it into a u8.
      So that would be 150 bytes. If we do it this way and can store them all in one array.
      We would just need some functions to check the bits separately.
      If we leave it as 4 u8s then its 32 bits so 150 * 4 = 600 bytes. 

      ALSO with an array, we could do a reset with memset to 0 I think OR Even just memcpy a constant reset state
      which would be faster than the current compile-time version.
    */
    back_space : ButtonState;
    return_enter : ButtonState;
    delete : ButtonState;

    Up : ButtonState; //w_button
    Down : ButtonState; //s_button
    Left : ButtonState; //d_button
    Right : ButtonState; //a_button

    arrow_up : ButtonState;
    arrow_down : ButtonState;
    arrow_left : ButtonState;
    arrow_right : ButtonState;

    ActionUp : ButtonState; //i_button
    ActionDown : ButtonState; //k_button
    ActionLeft : ButtonState; //j_button
    ActionRight : ButtonState; //l_button

    //TODO Should we replace this with being able to access with string or char constant?
    one : ButtonState;
    two : ButtonState;
    three : ButtonState;
    four : ButtonState;
    five : ButtonState;
    six : ButtonState;
    seven : ButtonState;
    eight : ButtonState;
    nine : ButtonState;
    zero : ButtonState;

    //TODO This really makes we want to have an array here to KeyCode instead of this.
    f9 : ButtonState;

    p_button : ButtonState;
    t_button : ButtonState;
    o_button : ButtonState;
    c_button : ButtonState;
    v_button : ButtonState;
    n_button : ButtonState;
    m_button : ButtonState;
    u_button : ButtonState;
    r_button : ButtonState;
    e_button : ButtonState;
    x_button : ButtonState;
    y_button : ButtonState;
    g_button : ButtonState;
}

/*NOTE : If we put all buttons in an array with KeyCode then we could
just pass in KeyCode. But also we could have an array for each one
that we check on every frame, although maybe this seems better if we
have a bit for each case. I think bits work better also in this case for ctrl/alt/shift
cause it would just be 1 logical OR to check if not any.
TODO Also add shift here eventually.
*/
IsOnlyInput :: inline (press : bool, input : ControllerInput) -> bool {
	only_press : bool = press && !input.only_ctrl_down &&
		!input.only_alt_down && !input.only_ctrl_alt_down;
	return only_press;
}
/*DOC : ONLY is_down should be used here. 
started_this_frame and is_up_this_frame are just here to be able to get a down and up this frame on the same
frame if that occurs. UpdateInputStatesFromEvents deals with that case below since both started and up will be true
but is_down will also stay true and then the next frame the input state will get cleared in ResetGameInput.

Implementing this myself instead of using input_button_states allows me to do the same frame checking and
ALSO allows us to use UpdateInputStatesFromEvents and derive my_input_states from events only, so all input
is from events then and this simplifies input processing in game and in tests so we only have 1 source of truth
which is the events. This is also ONLY Used to check for held down input and should not be used for start and end.
*/
MyInputState :: struct {
	started_this_frame : bool;
	is_down : bool;
	is_up_this_frame : bool;
}
/*DOC : We set started_this_Frame and is_up_this_frame here so we can see held down keys clearly.
If we get both down and up events on 1 frame, is_down = false but started_this_frame = true and is_up_this_frame = true
so then we check if is down if is_down || started_this_frame and so we still get the press and then we reset next frame
*/
UpdateInputStatesFromEvents :: inline (game_input : *GameInput) {
	for * game_input.all_mouse_click_counts {
		same_pos : bool = IsSamePositionMouseClick(it.*, game_input.*);
		if it.click_count > 0 && !same_pos {
			//Reset the mouse clicks if we moved the mouse after a click
			it.click_count = 0;
			it.click_timer = 0;
		} else if it.click_timer > 0 {
			it.click_timer -= game_input.last_frame_delta_time;
			if it.click_timer <= 0 {
				it.click_count = 0;
			}
		}
	}

	//TODO Should we also check internal event_type here or can just do that later with other events?
   for event : game_input.frame_input_events {
   	if event.type == .KEYBOARD {
	   	if IsKeyPressByType(.DOWN_THIS_FRAME, event) {
		   	game_input.my_input_states[event.key_code].started_this_frame = true;
		   	game_input.my_input_states[event.key_code].is_down = true;
		   } else if IsKeyPressByType(.UP_THIS_FRAME, event) {
		   	if !game_input.my_input_states[event.key_code].started_this_frame {
			   	game_input.my_input_states[event.key_code].is_down = false;
			   }
		   	game_input.my_input_states[event.key_code].is_up_this_frame = true;
		   }

		   /*DOC: Mouse double-click code
		   We can remove this if we don't end up using it since maybe it's not that useful.
		   I have to say that im not a fan of the feel of the double click in general.
			*/
		   if event.key_code == .MOUSE_BUTTON_LEFT ||
		   	event.key_code == .MOUSE_BUTTON_RIGHT ||
		   	event.key_code == .MOUSE_BUTTON_MIDDLE
		   {
		   	mb_index : int;
			   if event.key_code == {
			   case .MOUSE_BUTTON_LEFT; mb_index = 0;
		   	case .MOUSE_BUTTON_RIGHT; mb_index = 1;
		   	case .MOUSE_BUTTON_MIDDLE; mb_index = 2;
		   	}

		   	is_down := cast(bool) event.key_pressed;
				if is_down {
					bcc : *ButtonClickCount = *game_input.all_mouse_click_counts[mb_index];
	 				if bcc.click_timer <= 0 {
	 					bcc.click_timer = 0.5; //0.5s = 500ms
	 					bcc.click_count = 1;
	 					bcc.first_click_x = game_input.mouse_cam.x;
	 					bcc.first_click_y = game_input.mouse_cam.y;
	 				} else {
	 					bcc.click_count += 1;	
	 				}
 					if bcc.click_count > 1 {
 						same_pos : bool = IsSamePositionMouseClick(bcc, game_input);
 						if !same_pos {
 							bcc.click_count = 1;
 							bcc.click_timer = 0.5;
 							bcc.first_click_x = game_input.mouse_cam.x;
	 						bcc.first_click_y = game_input.mouse_cam.y;
 						}
 					}
 					// print("click_count=%\n", bcc.click_count);
	 			}
	 		}
		}
   }
}
IsMouseClickCount :: inline (
	click_count : int,
	bcc : ButtonClickCount,
	game_input : GameInput)
-> bool
{
	same_pos : bool = IsSamePositionMouseClick(bcc, game_input);
	same_count : bool = click_count == bcc.click_count;
	same_click_count : bool = same_pos && same_count;
	return same_click_count;
}
IsSamePositionMouseClick :: inline (
	bcc : ButtonClickCount,
	game_input : GameInput)
-> bool
{
	delta_x : float = abs(bcc.first_click_x - game_input.mouse_cam.x);
	delta_y : float = abs(bcc.first_click_y - game_input.mouse_cam.y);
	//If the delta is out of 7 pixels, then we reset click to 1 on current mouse position
	//TODO We could use pixels_per_square here if thats better
	if delta_y > 0.1 || delta_x > 0.1 {
		return false;
	}
	return true;
}
GameInput :: struct {
	//TODO Should try using frame_input_events for mouse events.
	//Maybe we want to allow key maps for mouse clicks or extra mouse buttons for example.
	//TODO Can likely use new input system instead of this now
	MouseButtons : [5] ButtonState;
	//TODO We can reuse this for all button presses
	//and put one in each MyInputState if we want to register
	//double clicks for everything but I am not sure that is useful
	//and also would be less efficient so let's see.
	all_mouse_click_counts : [5] ButtonClickCount;

	MouseX, MouseY, MouseZ : int;
	mouse_wheel : s32;
	
	last_frame_mouse_cam : Vector2F;
	mouse_cam : Vector2F;

	//TODO Remove these other controller inputs since we only use the keybaord
	//And also separate keybaord from controllers and likely use Jai Xinput
	//instead of my own
	//TODO I can replace this with just the word keyboard now but I will leave in case we add controllers.
	// Ultimately, we can remove most of this and just use this for text input or alternative musical input.
	//TODO Can remove this once we know the new input system is working
	Controllers : [1] ControllerInput;

	//TODO Use this by copying the events over each frame. This way we can also pass in events
	//for testing without relying on the events_this_frame from jai input module
	//Or also we could make our own object if we want to add stuff to it
	//InputEvent with an event inside it and then we can add other stuff later
	frame_input_events : [..] FrameInputEvent;
	// my_input_states : [] Input.Key_Current_State;
	/*DOC : This is ONLY Used for holding input down without pause.
	down_this_frame, up_this_frame and down_with_paush should all checked with frame_input_events above.
	We store start and up in these input states because then if we get a down and up on the same frame
	we still register the down here. ONLY THE is_down should be used here, so that is fine.
	start and up should not be used in the game, just left here for allowing multiple states on the same frame
	which may be useful for people typing fast and also if anyones lowers the refresh < 60 hz like 30 or 24 hz 
	We use this instead of input_button_states so we can use it more easily for testing and also so that
	we can control more precisely what is_down means and when we have it down. input_button_states is still down
	on an up_this_frame event whereas we don't do that.
	*/
	//TODO Rename this to my_input_states
	my_input_states : [Input.NUM_BUTTON_STATES] MyInputState;
	//DOC : This allows us to reset my_input_button_states whenever we are out of focus to avoid holding buttons without focus.
	out_of_focus_reset_input : bool;
	/*DOC : This is used for when we just want a start and down
	input key_code and for it to be cleared next frame. For events
	we should use the events array and to keep it down for longer
	but should just set it to start and end manually for clarity.
	TODO We could put this in TestData if that is more convenient
	Putting it here prevented having to pass test_data everywhere.
	*/
	//TODO Can remove this array since we are using events now and it seems to work well.
	// test_input_states_to_end : [..] Input.Key_Code;

	//DOC : We don't set a default here since this array should be updateable so we only want the default
	//input mappings during tests so we leave this empty to avoid any weird issues with constant array data
	//and instead verify that in the functions with assertions.
	//TODO Should this be in here or in all data? I think here is better so we can clear AllData but this stays
	//in tact since it is somewhat separate. We could separate it entirely but we only check input mappings
	//when checking input anyways so I think it makes sense to leave it here.
	game_input_mappings : [] InputMapping;
	// game_input_mappings : [] InputMapping = DEFAULT_INPUT_MAPPINGS;

	//TODO Should this be somewhere else?
	dtPerFrame : float;
	last_frame_delta_time : float;
}
EndInputStates :: inline (game_input : *GameInput) {
	//TODO Do this with input_states_to_end
   for * game_input.my_input_states {
   	if it.is_up_this_frame {
   		it.* = .{};
   	}
   }
}

//TODO Putting this just in case we want to add our own data to Event later.
//Likely will add something like MidiInput to be Keymappable for example so then we can
//put a union in here so the event can be in the same place and we can process it later.
FrameInputEvent :: struct {
	#as using ev : Input.Event;
	event_type : InputEventType;
	//TODO We could just have this string in 1 place
	text_block : string;
}
InputEventType :: enum u8 {
	//TODO Replace this with JAI_INPUT since we use all event types now
	KEYBOARD;
	TEXT_BLOCK;
	// MIDI;
}

/*OLD DOC : In case we go out of focus with a button press and therefore don't get the up this frame event,
we reset my_input_states when we are out of focus to prevent any unwanted input presses or in case 
we miss the release. Apparently dialog boxes still have focus, so we deal with that below by resetting
the my_input_states with Input.events_this_frame instead of mine.
*/ 
/*OLD DOC : We need to use Input.events_this_frame here for examples where we get input during the frame
which will get cleared on Input.update_window_events. For example with opening file explorer, we will
not get the up this frame if we open it with a mouse click or button press for example. We will only get
it when it happens and then lose it next frame so we do this for safety here and consistency.
*/
/*TODO this is for convenience in code atm
	but it is more efficient to set to false after done using if used on any particular frame
	maybe it would be good to let the compiler reset everything
	or maybe this will not matter once we use jai input module?
*/
//NOTE This does not include the input_button_state and application focus resetting in platform layer.
//TODO Should I rename this ResetGameInput per frame
ResetGameInput :: inline (game_input : *GameInput) {
	//TODO Can reuse this way if we have issues using only events
   // EndInputStates(game_input);
	// for Input.events_this_frame {
	/*DOC : Generally this seems to work and definitely does for tests but for user input
	we have a few more things when this is called in platform layer.
	*/
	for game_input.frame_input_events {
		/*DOC : If we have a down this frame event on resetting the next frame, 
		then we no longer are down this frame after pressing it.
		IMPORANT : Up this frame needs to be kept after checking down because if we have
		down this frame and up this frame on the same frame, then up should clear the input on the next frame
		*/
		// my_event := FrameInputEvent.{it, .KEYBOARD, .{}};
	   if IsKeyPressByType(.DOWN_THIS_FRAME, it) {
			game_input.my_input_states[it.key_code].started_this_frame = false;
	   }
	   if IsKeyPressByType(.UP_THIS_FRAME, it) {
			game_input.my_input_states[it.key_code] = .{};
		}
	}

	array_reset_keeping_memory(*game_input.frame_input_events);
	game_input.mouse_wheel = 0;

	// ResetControllerInput(*game_input.keyboard);
	for *controller : game_input.Controllers {
		ResetControllerInput(controller);
	}
	for *button : game_input.MouseButtons {
		ResetButtonState(button);
	}
}

ResetButtonState :: inline (button : *ButtonState) {
	button.down_this_frame = false;
	button.up_this_frame = false;
}

ResetControllerInput :: inline (controller : *ControllerInput) {
	controller.text_buffer_count = 0;
	controller.only_alt_down = false;
	controller.only_ctrl_down = false;
	controller.only_ctrl_alt_down = false;

	//Gotta say this compile-time metaprogramming is pretty cool!
	reset_members :: () -> string {
		all_reset_buttons_type_info := cast(*Type_Info_Struct) type_info(ControllerInput);
		button_state_type_info := cast(*Type_Info_Struct) type_info(ButtonState);

		sb : String_Builder;
		for member : all_reset_buttons_type_info.members
		{
			if member.type.type == Type_Info_Tag.STRUCT 
			{
				//Note : Here we can check the type of the struct member by the Type_Info_Struct.name
				//where we cast to the Type_Info_Struct since we know the tag is a STRUCT
				//also very cool
				member_type_info := cast(*Type_Info_Struct) member.type;
				if member_type_info.name == button_state_type_info.name 
				{
				//Note : leaving here as an example of get_field reflection usage, very cool
				// has_down_with_pause := get_field(t_info_member_struct, "is_down_with_pause");
				// has_down_this_frame := get_field(t_info_member_struct, "down_this_frame");
				// has_up_this_frame := get_field(t_info_member_struct, "up_this_frame");
				// if has_down_with_pause != null && has_down_this_frame != null && has_up_this_frame != null 
				// {
					print_to_builder(*sb, 
					#string DONE
controller.%1.is_down_with_pause = false;
controller.%1.down_this_frame = false;
controller.%1.up_this_frame = false;
					DONE, member.name);
				// }
				}
			}
		}
		return builder_to_string(*sb);
	}

	#insert #run reset_members();
}