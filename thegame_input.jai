#import "Basic";
Jai_Input :: #import "Input";

#import "thegame_math";

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
but is_down will also stay true and then the next frame the input state will get cleared in ResetGameJai_Input.

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
		   TODO If input module adds double click from the actual platform api then remove this altogether.
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
	// my_input_states : [] Jai_Input.Key_Current_State;
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
	my_input_states : [Jai_Input.NUM_BUTTON_STATES] MyInputState;
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
	// test_input_states_to_end : [..] Jai_Input.Key_Code;

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
	#as using ev : Jai_Input.Event;
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
the my_input_states with Jai_Input.events_this_frame instead of mine.
*/ 
/*OLD DOC : We need to use Jai_Input.events_this_frame here for examples where we get input during the frame
which will get cleared on Jai_Input.update_window_events. For example with opening file explorer, we will
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
	// for Jai_Input.events_this_frame {
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

//TODO Should this array be in GameInput or global or in Persist?
//OR we could just put it in GameInput and have a general
//input memory allocator
//AND we are already passing in GameInput anyways.
// ALL_INPUT_MAPPINGS : [] InputMapping;
//TODO Could have a function that just takes in key_code and modifier flags
//and checks those directly and then this could just call that general function
//so that then we could just use the events array.
//Would just have to process text input before every frame maybe
//but that would similar to what we do now.
//TODO Could call this IsShortcut
IsInputMapPress :: inline (
	im_type : InputMapType, 
	press_type : KeyPressType, 
	game_input : GameInput) 
-> bool 
{
	//TODO If we allowed multiple keymappings, then we would just
	//have to loop through each possibility somewhere down this function chain.
	// input_map : InputMapping = game_input.game_input_mappings[im_type];
	for game_input.frame_input_events if it.event_type == {
	case .KEYBOARD; {
		result : bool = IsInputMapEvent(im_type, press_type, it, game_input.game_input_mappings);
		if result return true;
	}
	}
	return false;
}
IsInputMapEvent :: inline (
	im_type : InputMapType, 
	press_type : KeyPressType, 
	event : FrameInputEvent,
	input_mappings : [] InputMapping) 
-> bool 
{
	//TODO If we allowed multiple keymappings, then we would just
	//have to loop through each possibility somewhere down this function chain.
	input_map : InputMapping = input_mappings[im_type];
	for map : input_map.keyboard_maps if IsKeyboardEvent(map.key_code, map.modifier_flags, press_type, event) {
		return true;
	}
	return false;
}
//TODO Rename to IsKeyPress or IsInputPress since we also do mouse input now.
IsKeyboardPress :: inline (
	key_code : Jai_Input.Key_Code, 
	press_type : KeyPressType, 
	//TODO Could just pass in FrameInputEvents
	game_input : GameInput) 
-> bool 
{
	return IsKeyboardPress(key_code, .{}, press_type, game_input);
}
/*TODO REMINDER : 
COULD MAKE A FUNCTION IsFirstKeyboardPress that only checks that first (or last)
press to avoid multiple key presses for some actions where we don't want overlap.
Then we can pull out the key check here and just check frame_input_events[0].
*/
//TODO Could generalize this to TEXT_INPUT and mouse but might be better to just have separate functions for that.
//TODO Rename to IsKeyboardEvent
IsKeyboardPress :: inline (
	key_code : Jai_Input.Key_Code, 
	mod_flags : Jai_Input.Event.Modifier_Flags,
	press_type : KeyPressType, 
	//TODO Could just pass in FrameInputEvents
	game_input : GameInput)
-> bool 
{
	//TODO Could put a bool in GameInput that prevents values from being
	//pressed here so we can not have it be pressed in certain cases.
	//Like when we are testing or when certain things are running.
	//Could also do it with a flag if that makes more sense.

	// key_map : InputMapping = game_input.game_input_mappings[ks];
	//TODO Since we have an array of frame_events, we can do 2 note clicks for example here.
	//Like ctrl+c,ctrl+k or any sequential key presses. Or maybe not
	//I guess we would need an extra array that would store the input frame_events for a certain
	//amount of time so that then we could check them.
	for game_input.frame_input_events if IsKeyboardEvent(key_code, mod_flags, press_type, it) {
		return true;
	}

	//TODO I think we can check input_button_states here
	//to see if something is down
	return false;
}
IsKeyboardPressAnyFlag :: inline (
	key_code : Jai_Input.Key_Code, 
	press_type : KeyPressType, 
	//TODO Could just pass in FrameInputEvents
	game_input : GameInput)
-> bool 
{
	for game_input.frame_input_events if IsKeyboardEventAnyFlag(key_code, press_type, it) {
		return true;
	}

	return false;
}
IsKeyboardEvent :: inline (key_code : Jai_Input.Key_Code, press_type : KeyPressType, event : FrameInputEvent) -> bool {
	return IsKeyboardEvent(key_code, .{}, press_type, event);
}
IsKeyboardEvent :: inline (
	key_code : Jai_Input.Key_Code, 
	mod_flags : Jai_Input.Event.Modifier_Flags,
	press_type : KeyPressType, 
	event : FrameInputEvent,
	input_event_type := Jai_Input.Event_Type.KEYBOARD)
-> bool 
{
	if key_code == event.key_code && mod_flags.packed == event.packed && event.type == input_event_type {
		result : bool = IsKeyPressByType(press_type, event);
		return result;
	}
	return false;	
}
IsKeyboardEventAnyFlag :: inline (
	key_code : Jai_Input.Key_Code, 
	press_type : KeyPressType, 
	event : FrameInputEvent,
	input_event_type := Jai_Input.Event_Type.KEYBOARD)
-> bool 
{
	if key_code == event.key_code && event.type == input_event_type {
		result : bool = IsKeyPressByType(press_type, event);
		return result;
	}
	return false;	
}
IsKeyPressByType :: inline (press_type : KeyPressType, event : FrameInputEvent) -> bool {
	//TODO Should we use utf32 here instead of key_code
	is_down := cast(bool) event.key_pressed;
	is_repeat := cast(bool) event.repeat;
	result : bool;
	if #complete press_type == {
	//NOTE : Need to check this first to make sure !is_repeat
	case .DOWN_THIS_FRAME;
		result = is_down && !is_repeat;
	case .IS_DOWN_WITH_PAUSE; //Could rename IS_STILL_DOWN or ENDED_DOWN or something else if that's clearer
	//NOTE : This is equivalent to (DOWN_THIS_FRAME || (is_down && is_repeat))
		result = is_down;
	case .UP_THIS_FRAME;
		result = !is_down;
	}
	return result;
}
IsTextInputEvent :: inline (press_type : KeyPressType, event : FrameInputEvent) -> bool {
	if event.type == .TEXT_INPUT
		&& event.utf32 >= 0 && event.utf32 <= 255
	{
		result : bool = false;
		is_down : bool = event.utf32 > 0;
		if #complete press_type == {
		case .DOWN_THIS_FRAME;
			assert(false, "no down_this_frame for text input only use is_down_with_pause or up_this_frame");
			result = false;
		case .IS_DOWN_WITH_PAUSE; //Could rename IS_STILL_DOWN or ENDED_DOWN or something else if that's clearer
		//NOTE : This is equivalent to (DOWN_THIS_FRAME || (is_down && is_repeat))
			result = is_down;
		case .UP_THIS_FRAME;
			result = !is_down;
		}
		return result;
	}
	return false;
}
//TODO Can pass the input_button_states through game_input so that
//we can INJECT the code for tests with whatever state we want
IsInputDown :: inline (
	key_code : Jai_Input.Key_Code,
	game_input : GameInput) 
//TODO Add GameInput here to allow for testing
-> bool
{
	/*DOC : Checking this way allows us to trigger a button press even if we got a down_this_frame and
	up_this_frame event on the same frame. If we did, then is_down = false up both up_this_frame and down_this_frame = true
	and so we still get the button press with this function.
	NOTE WE DO NOT DO THE ABOVE ANYMORE
	ALSO FOR down_this_frame and up_this_frame we use events. This is ONLY for holding input down without pause.
	*/
	//NOTE : We keep is_down now if we started_this_frame and up_this_frame on the same frame for consistency and clarity.
	//We still reset the input on the next frame, but this way is_down = true whenever we are down this frame
	//and we can still have a down and up on the same frame and we will register the down correctly.
	is_down : bool = game_input.my_input_states[key_code].is_down;
	//No longer do this way in favor of checking started_this_frame in UpdateInputStatesFromEvents and keeping is_down=true
	//even if we have a started_this_frame and an up_this_frame
	// is_down : bool = game_input.my_input_states[key_code].is_down || 
	// 	game_input.my_input_states[key_code].started_this_frame;
	return is_down;
}
IsMouseWheelWithoutModifiers :: inline (game_input : GameInput) -> bool {
	only_mouse_wheel : bool = game_input.mouse_wheel != 0 &&
		!IsInputDown(.CTRL, game_input) && 
		!IsInputDown(.SHIFT, game_input) &&
		!IsInputDown(.ALT, game_input);
	return only_mouse_wheel;
}

//TODO Should we put this in thegame_platform_data
//Or maybe a separate thegame_input or thegame_keymapping module
INPUT_MAP_TYPE_NAMES :: #run enum_names(InputMapType);
INPUT_MAP_TYPE_ENUMS :: #run enum_values_as_enum(InputMapType);
//TODO Could rename InputMapType or KeymapShortcut or KeyAction
//something else
InputMapType :: enum {
	//Terminal Shortcuts
	TERMINAL_TOGGLE;

	//Text Space Shortcuts
	//Debug control
	TEXT_DEBUG_TOGGLE;
	TEXT_CONSOLE_TOGGLE;
	TEXT_DISASM_TOGGLE;
	TEXT_COMPILE;
	TEXT_SET_FIXED_MAIN_COMPILE;
	TEXT_RUN_CONTINUE;
	//TODO These are only used for debug but eventually can be
	//used while running as well so should we change name to 
	//DEBUG_STOP and DEBUG_RESTART or leave as is?
	TEXT_STOP;
	TEXT_RESTART;
	//Pane switching
	TEXT_PANE;
	TEXT_WATCH_PANE;
	TEXT_BOTTOM_LEFT_PANE;
	TEXT_BOTTOM_RIGHT_PANE;

	TEXT_CALL_STACK;

	TEXT_SPACE_REFRESH;

	//File shortcuts
	TEXT_FILE_TAB_RIGHT;
	TEXT_FILE_TAB_LEFT;
	TEXT_FILE_TAB_BAR;
	TEXT_FILE_TAB_CLOSE;
	TEXT_FILE_TAB_OPEN;
	TEXT_FILE_TAB_SWAP_LEFT;
	TEXT_FILE_TAB_SWAP_RIGHT;
	TEXT_FILE_RIGHT_CHAR_BOUND;
	TEXT_FILE_LEFT_CHAR_BOUND;
	TEXT_FILE_FIND_TEXT_BAR;
	TEXT_FILE_BACK_FIND;
	TEXT_FILE_REPLACE_TEXT_BAR;
	TEXT_FILE_GOTO_LINE_BAR;
	TEXT_FILE_SINGLE_REPLACE;
	TEXT_FILE_REPLACE_ALL;
	TEXT_FILE_SAVE;
	TEXT_FILE_UPDATE_DATA;

	TEXT_SELECT_ALL;
	TEXT_COPY;
	TEXT_SHOW_STATUS_BAR;

	//TODO Should this be separate from text?
	//I guess for debug specific things like breakpoint and watch window maybe.
	//NOTE : These happen in text space but only in debug mode
	//so they were TEXT_STEP_OVER... before and we can reuse that if
	//those names seem better eventually.
	//We could also remove DEBUG if that helps.
	//Debug Space Shortcuts
	DEBUG_SET_BREAKPOINT;
	DEBUG_STEP_OVER;
	DEBUG_STEP_INTO;
	DEBUG_STEP_OUT;

	DEBUG_WATCH_EDIT;


	NEXT_MUSIC_SPACE;
	PREVIOUS_MUSIC_SPACE;

	//This is ctrl+shift+zoom buttons
	//TODO SHOULD THIS BE ctrl+zoom buttons instead by default?
	//OR even shift+zoom I think?
	//This avoids overlapping ctrl+scroll with ctrl+shift+scroll
	GLOBAL_ZOOM_IN;
	GLOBAL_ZOOM_OUT;
	GLOBAL_ZOOM_RESET;
	GLOBAL_MOVE_INSTANTLY;

	//This is alt+zoom buttons
	OP_SPACE_MOVE_INSTANTLY;
	OP_SPACE_ZOOM_IN;
	OP_SPACE_ZOOM_OUT;
	OP_SPACE_ZOOM_RESET;

	PLAY_PAUSE_MUSIC;
	STOP_MUSIC;

	RUN_EXTERNAL_UPDATE;

	DEV_TEST_MODE;
}

KeyPressType :: enum u8 {
	IS_DOWN_WITH_PAUSE;
	DOWN_THIS_FRAME;
	UP_THIS_FRAME;
}
/*TODO If we want to allow multiple mappings
then we can have an array for keyboard and midi inputs in here
*/
InputMapping :: struct {
	/*DOC : This is unecessary because we index by the enum but we store it in here 
	for debugging convenience so we can see which input map we are updating.
	*/
	input_map_type : InputMapType;
	//TODO Should this be utf32 : u32 instead for text input?
	//Maybe utf32 is more general than this for other inputs.
	//Maybe we include Event_Type so we can differentiate.
	//and then have a function which takes this and does a cast.
	//TODO Could make this an array for multiple mappings
	//So pull this out into a keyboard mapping object and then
	//we coudl check those if the event is KEYBOARD and then have
	//other event types
	keyboard_maps : [] KeyboardMap;
	// midi_keymaps : [] MIDIKeymap;
	// key_code : Jai_Input.Key_Code;
	// modifier_flags: Jai_Input.Event.Modifier_Flags;
	//TODO Can have some extra info for other inputs like midi or gamepad or alt

	//TODO We could allow a custom mapping which calls a function implemented by them here.
	//This is tricky because when would we call these. Probably at the beginning by default so
	//they can do whatever they want or maybe right after all the internal input and then we 
	//can have a slightly different system for that. I like that idea but if it's
	//general then we could just make a CUSTOM InputMapType and then check all the custom ones
	//by string here so they can name it whatever they want, but it still won't run whenever they want.
	//ALSO SINCE THEY CAN write their own code, likely better to just stick to that for custom input
	//and just have it happen at a specific place or even several with several functions like an engine.
	// cmd_string : string;
	// custom_proc : *void;

	//TODO Can remove leaving here from jai but I don't think I need to use them at all.
	// respect_ignore_modifier_keys := true;  // controls whether the mapping respects the keymap's ignore_modifier_keys option or ignores it and does the opposite
	// toggled_on := false;  // state variable to prevent redundant notifications for "toggle" callbacks

	// Any mapping entry can either be a proc
	// or a command string (but not both!)

	// command_string: string;
	// proc_index: s32 = -1;  // To make copying mappings easy.
}

all_key_code_names : [] string : #run enum_names(Jai_Input.Key_Code);
all_key_code_enums : [] Jai_Input.Key_Code : #run enum_values_as_enum(Jai_Input.Key_Code);
KeyboardMap :: struct {
	key_code : Jai_Input.Key_Code;
	modifier_flags: Jai_Input.Event.Modifier_Flags;
	//TODO Can set this or in a separate array so that
	// description : string;
}

CopyDefaultInputMappings :: inline () -> [] InputMapping {
	copy_im : [] InputMapping = array_copy(DEFAULT_INPUT_MAPPINGS);
	for DEFAULT_INPUT_MAPPINGS {
		copy_im[it_index].keyboard_maps = array_copy(it.keyboard_maps);
	}	
	return copy_im;
}

//TODO Can add default midi keymaps as well later based on an 88-key piano
//Text input would be grabbed externally by just loading the buffer and we
//could have default midi values for that but then also use keymaps there.
//TODO Could allow multiple midi notes to be assocaited to 1 input map
//so then a chord could have an alternate siginificance for example.
MIDIKeyMap :: struct {
	// midi_message : MIDI_Message;
}
DEFAULT_INPUT_MAPPINGS, IM_DESCRIPTIONS :: #run () -> 
[] InputMapping,        [] string 
{
 	imd := NewArray(INPUT_MAP_TYPE_ENUMS.count, string);	
 	d := NewArray(INPUT_MAP_TYPE_ENUMS.count, InputMapping);
	for INPUT_MAP_TYPE_ENUMS if #complete it == {
	case .TERMINAL_TOGGLE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "T", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
		imd[it] = "Open/close terminal op space";
	} 
	case .TEXT_DEBUG_TOGGLE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "D", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_CONSOLE_TOGGLE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "O", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_DISASM_TOGGLE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "I", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_COMPILE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "C", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_SET_FIXED_MAIN_COMPILE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "M", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_RUN_CONTINUE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F5, .{}};
		d[it] = .{it, k_maps};
	} 
	case .DEBUG_STEP_OVER; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F10, .{}};
		d[it] = .{it, k_maps};
	} 
	case .DEBUG_STEP_INTO; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F11, .{}};
		d[it] = .{it, k_maps};
	} 
	case .DEBUG_STEP_OUT; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F11, .{shift_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_STOP; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F5, .{shift_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_RESTART; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F5, .{shift_pressed=true,ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_PANE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "1", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .TEXT_WATCH_PANE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "2", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_BOTTOM_LEFT_PANE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "3", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_BOTTOM_RIGHT_PANE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "4", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_CALL_STACK; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "S", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_SPACE_REFRESH; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F12, .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	} 
	case .TEXT_FILE_TAB_RIGHT; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "L", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_TAB_LEFT; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "J", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_TAB_BAR; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F8, .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_TAB_CLOSE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "W", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_TAB_OPEN; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "O", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_TAB_SWAP_LEFT; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "J", .{ctrl_pressed=true,alt_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_TAB_SWAP_RIGHT; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "L", .{ctrl_pressed=true,alt_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_RIGHT_CHAR_BOUND; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "8", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_LEFT_CHAR_BOUND; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "7", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_FIND_TEXT_BAR; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "F", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_REPLACE_TEXT_BAR; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "H", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_GOTO_LINE_BAR; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "G", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_BACK_FIND; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.BACKSPACE, .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_SINGLE_REPLACE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "H", .{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_REPLACE_ALL; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.ENTER, .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_SAVE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "S", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_FILE_UPDATE_DATA; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "U", .{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_SELECT_ALL; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "A", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_COPY; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "C", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .TEXT_SHOW_STATUS_BAR; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F7, .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};
	}
	case .DEBUG_SET_BREAKPOINT; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.F9, .{}};
		d[it] = .{it, k_maps};
	}
	case .DEBUG_WATCH_EDIT; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "E", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .NEXT_MUSIC_SPACE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char ".", .{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .PREVIOUS_MUSIC_SPACE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char ",", .{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	//TODO Could set these back if we want alternative custom zoom
	case .GLOBAL_ZOOM_IN; {
		k_maps := NewArray(1, KeyboardMap);
		//This does not work on jai since jai interprets "=" as "+" char
		//ALSO this might get confused for other zooms which is no bueno
		// k_maps[0] = .{xx #char "=",.{ctrl_pressed=true,shift_pressed=true}};
		k_maps[0] = .{xx #char "]",.{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .GLOBAL_ZOOM_OUT; {
		k_maps := NewArray(1, KeyboardMap);
		// k_maps[0] = .{xx #char "-", .{ctrl_pressed=true,shift_pressed=true}};
		k_maps[0] = .{xx #char "[", .{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .GLOBAL_ZOOM_RESET; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "R", .{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .GLOBAL_MOVE_INSTANTLY; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.MOUSE_BUTTON_RIGHT, .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};	
	}
	case .OP_SPACE_MOVE_INSTANTLY; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{.MOUSE_BUTTON_RIGHT, .{alt_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .OP_SPACE_ZOOM_IN; {
		k_maps := NewArray(1, KeyboardMap);
		//This does not work on jai since jai interprets "=" as "+" char
		//ALSO this might get confused for other zooms which is no bueno
		// k_maps[0] = .{xx #char "=",.{alt_pressed=true}};
		k_maps[0] = .{xx #char "]",.{alt_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .OP_SPACE_ZOOM_OUT; {
		k_maps := NewArray(1, KeyboardMap);
		// k_maps[0] = .{xx #char "-", .{alt_pressed=true}};
		k_maps[0] = .{xx #char "[", .{alt_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .OP_SPACE_ZOOM_RESET; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "R", .{alt_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .PLAY_PAUSE_MUSIC; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "P", .{ctrl_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .STOP_MUSIC; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "P", .{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .RUN_EXTERNAL_UPDATE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "E", .{ctrl_pressed=true,alt_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	case .DEV_TEST_MODE; {
		k_maps := NewArray(1, KeyboardMap);
		k_maps[0] = .{xx #char "T", .{ctrl_pressed=true,shift_pressed=true}};
		d[it] = .{it, k_maps};		
	}
	}
	return d, imd;
}();

/*DOC : Code to add inputs programatically.
We could move this into tests if we only use it there but maybe we will
use it in game sometimes to run something? Or not since we can just run the code?
Hmmm I'll leave it here for now and see.
*/
//TODO Maybe we should rename this AddAction? Is that word clear?
AddPressInputMap :: inline (
	im_type : InputMapType,
	press_type : KeyPressType,
	game_input : *GameInput)
{
	//Safety check
	assert(game_input.game_input_mappings[im_type].keyboard_maps.count > 0);
	km : KeyboardMap = game_input.game_input_mappings[im_type].keyboard_maps[0];
	AddPressKeyboard(km.key_code, km.modifier_flags, press_type, game_input);
}
DownUpInputMap :: inline (
	im_type : InputMapType,
	game_input : *GameInput)
{
	//Safety check
	assert(game_input.game_input_mappings[im_type].keyboard_maps.count > 0);
	km : KeyboardMap = game_input.game_input_mappings[im_type].keyboard_maps[0];
	AddPressKeyboard(km.key_code, km.modifier_flags, .DOWN_THIS_FRAME, game_input);
	AddPressKeyboard(km.key_code, km.modifier_flags, .UP_THIS_FRAME, game_input);
}
//TODO We could add a function that takes an array but I think we only want down and up as an exception
//so we can call 1 function for keyboard input and make sure that it still works if the down and up are done on the same frame.
DownUpThisFrame :: inline (
	key_code : Jai_Input.Key_Code, 
	mod_flags : Jai_Input.Event.Modifier_Flags,
	game_input : *GameInput)
{
	AddPressKeyboard(key_code, mod_flags, .DOWN_THIS_FRAME, game_input);
	AddPressKeyboard(key_code, mod_flags, .UP_THIS_FRAME, game_input);
}
DownUpThisFrame :: inline (
	key_code : Jai_Input.Key_Code,
	game_input : *GameInput)
{
	AddPressKeyboard(key_code, .{}, .DOWN_THIS_FRAME, game_input);
	AddPressKeyboard(key_code, .{}, .UP_THIS_FRAME, game_input);
}
//TODO Should rename to AddDownUpKeyboard and then have AddPressKeyboard for specific ones without upt
AddPressKeyboard :: inline (key_code : Jai_Input.Key_Code, press_type : KeyPressType, game_input : *GameInput) {
	AddPressKeyboard(key_code, .{}, press_type, game_input);
}
//TODO We could add ctrl, shift and alt for convenience here or do it manually for each keyboard press
//Although I don't really check for shift and alt alone ever, so maybe it does not matter 
//since we set the down checks and mouse double clicks in UpdateInputStatesFromEvents
//TODO Should this just be for tests?
//TODO Will likely need a different function for different inputs
//since the info from the event or midi will be different.
//NOTE : This will be cleared on the next frame.
AddPressKeyboard :: (
	key_code : Jai_Input.Key_Code, 
	mod_flags : Jai_Input.Event.Modifier_Flags,
	press_type : KeyPressType, 
	game_input : *GameInput)
{
	e : *FrameInputEvent = array_add(*game_input.frame_input_events);
	SetFrameInputEvent(key_code, mod_flags, press_type, e);
}
CreateFrameInputEvent :: inline (
	key_code : Jai_Input.Key_Code, 
	mod_flags : Jai_Input.Event.Modifier_Flags,
	press_type : KeyPressType) 
-> FrameInputEvent
{
	e : FrameInputEvent;
	SetFrameInputEvent(key_code, mod_flags, press_type, *e);
	return e;
}
SetFrameInputEvent :: inline (
	key_code : Jai_Input.Key_Code, 
	mod_flags : Jai_Input.Event.Modifier_Flags,
	press_type : KeyPressType,
	e : *FrameInputEvent)
{
	e.type = .KEYBOARD;
	e.key_code = key_code;
	e.modifier_flags = mod_flags;
	if #complete press_type == {
	case .DOWN_THIS_FRAME;
		e.key_pressed = cast(u32) true;
		e.repeat = false;
	case .IS_DOWN_WITH_PAUSE;
		e.key_pressed = cast(u32) true;
		e.repeat = true;
	case .UP_THIS_FRAME;
		e.key_pressed = cast(u32) false;
	}
}

/*DOC : This is used for when we just want a start and down
input key_code and for it to be cleared next frame. For events
we should use the events array and to keep it down for longer
but should just set it to start and end manually for clarity.
*/
//TODO We can remove this now if we don't use it since we set
//everything from the events like in the platform layer
#if 0 {
AddTestKeyStartEnd :: inline (
	key_code : Jai_Input.Key_Code,
	game_input : *GameInput)
{
	game_input.my_input_states[key_code].started_this_frame = true;
	game_input.my_input_states[key_code].is_down = true;
	//NOTE : This ensures that we reset this key next frame
	game_input.my_input_states[key_code].is_up_this_frame = true;
}
}

//TODO FROM HERE Make this pass in separate text_input events now
//for the text editor and should be set.
//ALSO update the text selection code and cleanup the undo
//before testing (maybe add copy and text ctrl+arrow movement first)
//TODO We should just add multiple events here instead of text block and have a separate creation for text blocks.
//TODO This should be updated once text buffer in game_input is a string.
AddTextBlock :: inline (input : string, game_input : *GameInput) {
	event : *FrameInputEvent = array_add(*game_input.frame_input_events);
	SetTextBlock(input, event);
}
SetTextBlock :: inline (input : string, e : *FrameInputEvent) {
	e.event_type = .TEXT_BLOCK;
	e.text_block = input;
}

AddTextInput :: inline (input : string, game_input : *GameInput) {
	#if 0 {
	kb := *game_input.Controllers[0];
	assert(input.count <= kb.text_input_buffer.count);
	kb.text_buffer_count = input.count;
	memcpy(kb.text_input_buffer.data, input.data, kb.text_buffer_count);
	kb.text_input.is_down_with_pause = true;
	}
	/*DOC : We are adding 1 char at a time now since this will keep
	the chars in the right order if other events if we press multiple keys
	in 1 frame. This matters for the text editor because it is possible
	to type in 2-3 chars at once when typing very quickly or do something like
	text,arrow,text in the same frame. Especially if the frame rate is < 60hz.
	*/
	for 0..input.count-1 {
		e : *FrameInputEvent = array_add(*game_input.frame_input_events);
		e.type = .TEXT_INPUT;
		e.utf32 = input[it];
	}
}