//Note : commented out but convenient for testing if needed
//can do the same with GetRect as well
// SimpBase :: #import "Simp";

//Inling this was causing stack overflow with enable_bytecode_inliner in Build_Options.
// UpdateAndRenderBase :: inline (game_memory : *GameMemory,
UpdateAndRenderBase :: (game_memory : *GameMemory,
								renderer_data : *RendererData,
								audio_data : *AudioData,
								game_input : *GameInput)
{

game_state := cast(*GameState) game_memory.PermanentStorage;
// controller_1 := game_input.Controllers[0];
keyboard := game_input.Controllers[0];
perm := *game_state.persist;

#if 0 {
if !renderer_data.is_initialized
{
	//Note : currently this is done in SetupRendererData()
    renderer_data.is_initialized = true;
}
}
//TODO this can be more efficiently called in the platform layer before starting
//YES I think it likely is better to put this in the platform layer so then we also don't have
//any discrepencies if we did not run this yet as we'll run it before hopping into the game loop
//and then we can also remove the renderer initialized and the transient data intialized since that
//is also done in the platform layer and with temp storage instead
if !game_state.is_initialized {
// ProfileProcedure();
assert(game_memory.PermanentStorageSize >= size_of(GameState) &&
        game_memory.IsInitialized);
	//TODO can do this in thegame_update_mode
    // game_state.memory.base = (cast(*u8) game_memory.PermanentStorage) + size_of(GameState);
    // game_state.memory.size = game_memory.PermanentStorageSize - size_of(GameState);

	//Level setup
	//TODO Could have an initial setup function which is not done per level 
	//to initialize things like terminal and also command string and anything 
	//else that does not change per level
	//TODO Use this for non in-game commands now
	//TODO WHY NOT JUST DO THIS AT THE SYSTEM LEVEL BEFORE THE MAIN LOOP?
	perm.text_command_string.total_allocated_bytes = 500;
	perm.text_command_string.text_string = alloc_string(perm.text_command_string.total_allocated_bytes);
	perm.text_command_string.text_string.count = 0;

	SetupTerminalData(*perm.terminal_data);
	//TODO I think we can set this up in win_thegame so we don't need Dynamic_Font in here
	SetupTextEditorData(*perm.text_editor_data, renderer_data);


	ResetAllRendererData(renderer_data);
	perm.all_data = InitAllData();
	/*DOC : Load files here after initializing data. We can make this it's own function if needed.
	This way this does not interefere with tests but always runs on startup so that we start with the input mappings
	and runtimesettings loaded up.
	NOTE : WE COULD ALSO remove the text files afterwards although we would have to free the string data for names and such
	in that case so maybe can think of a way to allocate that data like reusing strings or with an allocator maybe.
	IF we use dynamic libraries then none of this is a an issues since we could remove this and just use dls instead.
	*/
	SetupGameInputMappings(game_input, *perm.all_data.all_text_files, INPUT_MAPPINGS_REL_PATH);
	//DOC : If this is invalid on startup then we just keep the default settings and do nothing since nothing is open yet.
	rsr : RuntimeSettingsReturn = ParseRuntimeSettingsFile(*perm.all_data.all_text_files, RUNTIME_SETTINGS_REL_PATH);
	if rsr.success {
		UpdateRuntimeSettings(rsr.new_settings, perm, renderer_data);
	}
	//This will set the default created mspace with id = 0 to the runtime_settings
	UpdateMusicSpace(.{}, perm.all_data.runtime_settings, *perm.all_data.all_mspace_data);
	//TODO Can make an UpdateAllDataWithRuntimeSettings here or just set each thing, since maybe we only set mspace for now.

	// BuildCodeLevelsTable(perm);
	ASM_INSTRUCTION_MANUAL = GenerateAsmInstructionManual();

	//TODO Could set this from a file when we allow updating input mappings.
	//Then we just need to pull in 1 file since that will be updated and initially set to defaults.
	//Could keep an internal default in case people want to reset safely.
	// ALL_INPUT_MAPPINGS = DEFAULT_INPUT_MAPPINGS;
	//TODO Make this a terminal command so people can generate it when needed to do the new added input mappings
	// GenerateInputMappingsFile(DEFAULT_INPUT_MAPPINGS);

	game_state.is_initialized = true;
}

//TODO add this to context and add memory to transient instead of jai temp
trans := cast(*TransientState) game_memory.TransientStorage;
if !trans.is_initialized {
	//TODO can do this in thegame_update_mode
    // trans.memory.base = (cast(*u8) game_memory.TransientStorage) + size_of(TransientState);
    // trans.memory.size = game_memory.TransientStorageSize - size_of(TransientState);

	trans.is_initialized = true;
}

//TODO Set these here for convenience when we pass in perm.all_data but maybe best to remove it
//We use audio_data in ExecMInstr for example for the sample_rate since we already passed in all_data
perm.all_data.renderer_data = renderer_data;
perm.all_data.audio_data = audio_data;
perm.all_data.game_input = game_input;

/*TODO should we do this for every renderer_data.all_render_groups?

	Should we make a separate function that sets this up every frame
	since we are doing everything at the beginning of each fram now?
*/
//TODO could we call this more often or better yet, separate thread and stream whenever we are ready
//Setup render buffers, audio buffers and shaders
//REMINDER : There are weird issues with this and opengl. Sometimes if we switch it to a higher value like below
//things magically render. I think opengl stores some state between runs and only reset if we feed it something different
//or change something else entirely. I'm not sure but it'll randomly work at some point and is very inconsistent.
// PushClear(Vector4F.{}, renderer_data.base_render_group, -9999999);
PushClear(Vector4F.{}, renderer_data.base_render_group, S64_MIN);
PushShaderEntries(renderer_data.base_render_group, 0, 2, S64_MAX);
PushSetShaderColor(renderer_data.base_render_group, 4);
PushTextAndCursorShaderOrder(renderer_data.base_render_group);
PushTextAndCursorShaderOrder(renderer_data.terminal_render_group);
PushTextAndCursorShaderOrder(renderer_data.overlay_render_group);

//TODO Probably only need to do this if audio is playing
// #if DSOUND_AUDIO {
ClearAudioBuffer(audio_data);
// }
//TODO Can likely remove this too since this will be updated in the audio thread
//Or we could just update the play cursor in the audio thread and then the rest here.
UpdateAudioTiming(*perm.all_data.audio_timing, <<audio_data);

//TODO This should probably be done later in case we add new op_spaces this frame.
//Although we should probably just do that when we create them.
for op_space : perm.all_data.all_open_op_spaces {
	PushShaderEntries(op_space.render_groups.scissor_group, 0, 2, 9999999);
	PushShaderEntries(op_space.render_groups.post_render_group, 0, 2, 9999999);
	PushTextAndCursorShaderOrder(op_space.render_groups.scissor_group);
}

//TODO where should we put this and his HoverEntity a good name?
//TODO temp data
//TODO need a an array for each op_space
frame_hover_entities : [..] HoverEntity;
frame_hover_entities.allocator = temp;

#if 0 {
if keyboard.only_alt_down && keyboard.Down.down_this_frame {
	//TODO pass in an array that gets the variable name from perm.all_data and stores it
	serializer : Serializer;
	write(*serializer, perm.all_data);

	file_write_success : bool =
		game_memory.DEBUGPlatformWriteEntireFile("level_save_test", cast(u32) serializer.buffer.count, serializer.buffer.data);
	assert(file_write_success);
}
else if keyboard.only_alt_down && keyboard.ActionRight.down_this_frame {
	read_file_result := game_memory.DEBUGPlatformReadEntireFile("level_save_test");

	deserializer : Deserializer;
	deserializer.buffer.data = read_file_result.Contents;
	deserializer.buffer.count = read_file_result.ContentsSize;
	read(*deserializer, perm.all_data);
}
}

//TODO WRITE COMMENT SOMEHWERE THAT WE CANT USE "=" OR "+" for input mappings
//JAI DOESNT PROCESS THIS, maybe ask on discord and get an incorrect response
// if IsKeyboardPress(xx #char "=", .DOWN_THIS_FRAME, game_input) {
// 	print("pressed =\n");
// }
//COULD USE EITHER MOUSE WHEEL OR ZOOM INT OR ZOOM OUT as + and - for now by default
// if game_input.mouse_wheel != 0 {
// if IsMouseWheelWithoutModifiers(game_input) {
// 	print("mouse_wheel = %\n", game_input.mouse_wheel);
// }
/*DOC : We zoom in first so that the mouse world position is correct on the same frame as when we zoom in.
This could be left to be off by 1 frame if needed but if we can keep it this way then I think everything will
feel smooth and snappy with mouse movement for example.

TODO We can add + and - here hardcoded as well if needed but thats usually used for external zooms so maybe best not too
*/
//TODO Could hardcode ctrl++ and ctrl+- here as well since those don't work
// is_global_zooming : bool;
global_zoom_scale : int; 
if IsInputMapPress(.GLOBAL_ZOOM_OUT, .IS_DOWN_WITH_PAUSE, game_input) {
	// is_global_zooming = true;
	global_zoom_scale = -1;
} else if IsInputMapPress(.GLOBAL_ZOOM_IN, .IS_DOWN_WITH_PAUSE, game_input) {
	// is_global_zooming = true;
	global_zoom_scale = 1;
} else if IsInputDown(.CTRL, game_input) && game_input.mouse_wheel != 0 {
	//TODO SHOULD GLOBAL BE JUST CTRL or CTRL+SHIFT? Could ask this on discord eventually
	//Maybe ctrl+shift reduces error? Could also have 1 be CTRL and 1 be SHIFT OR 1 ALT and SHIFT?
	// is_global_zooming = true;
	global_zoom_scale = game_input.mouse_wheel;
} else if IsInputMapPress(.GLOBAL_ZOOM_RESET, .DOWN_THIS_FRAME, game_input) {
	// is_global_zooming = true;
	global_zoom_scale = 0;
	UpdatePixelsPerSquareEverywhere(renderer_data.default_pixels_per_square, renderer_data, perm);
	// print("zoom=%\n", renderer_data.base_render_group.pixels_per_square);
}
if global_zoom_scale != 0 {
	new_pixels_per_square : float = renderer_data.base_render_group.pixels_per_square + global_zoom_speed * global_zoom_scale;
	new_pixels_per_square = Clamp(global_zoom_pixel_min, new_pixels_per_square, global_zoom_pixel_max);
	UpdatePixelsPerSquareEverywhere(new_pixels_per_square, renderer_data, perm);
	// print("zoom=%\n", renderer_data.base_render_group.pixels_per_square);
}


/*DOC : Updating the mspace here first ensures that we only have 1 mspace selected for the whole frame.
If we update the mspace through the terminal, then there will be delay as we wait for the mspace to change
so that does not require speed change like with the shortcut which can happen very quickly eventually.

IMPORTANT NOTE We don't have to switch the mspace cam here because this happens before we grab the default_base_cam
BUT WE DO HAVE TO DO IT WHEN WE CHANGE IN THE TERMINAL to avoid having everything be off for 1 frame

NOTE if we only have 1 mspace then we cannot change mspaces anyways
*/
if perm.all_data.all_mspace_data.count > 1 &&
	(IsInputMapPress(.NEXT_MUSIC_SPACE, .DOWN_THIS_FRAME, game_input) ||
	 IsInputMapPress(.PREVIOUS_MUSIC_SPACE, .DOWN_THIS_FRAME, game_input))
{
	last_mspace_index, found_last_mspace := ArrayFindFirstIndexByNameId(perm.all_data.all_mspace_data,
		perm.all_data.render_mspace_id, "mspace_id");
	assert(found_last_mspace);
	change_mspace_index : int;
	if IsInputMapPress(.NEXT_MUSIC_SPACE, .DOWN_THIS_FRAME, game_input) {
		change_mspace_index = PosMod(last_mspace_index + 1, perm.all_data.all_mspace_data.count);
	}
	else if IsInputMapPress(.PREVIOUS_MUSIC_SPACE, .DOWN_THIS_FRAME, game_input) {
		change_mspace_index = PosMod(last_mspace_index - 1, perm.all_data.all_mspace_data.count);
	}

	change_mspace_id : int = perm.all_data.all_mspace_data[change_mspace_index].mspace_id;
	ChangeRenderMusicSpace(change_mspace_id, perm.all_data);
}

mspace_for_input := GetRenderMSpace(perm.all_data);
//Mouse Input
//TODO should this be in a separate function to calculate everything?
//MusicPt : mouse precision declines when objects are verysmall (probably due to floating point precision)
//TODO maybe check if the mouse is in a dspace before checking all dspace positions
//TODO should we check mouse directly with viewport?
//TODO We should move this above so we can do camera movement this frame with the mouse.
// mouse_cam : Vector2F = MouseScreenToCam(game_input.MouseX, game_input.MouseY, renderer_data.base_render_group);

mouse_cam : Vector2F = game_input.mouse_cam;
//TODO could do the same for world_mouse if needed
mouse_delta : Vector2F = mouse_cam - game_input.last_frame_mouse_cam;
/*DOC : We move the camera here based on mouse position. SO we compute the current mouse world pos for that movement
and THEN we grab the defaulte_base_cam and update the world mouse so that we can reuse that everywhere.
This means that we should be moving the camera AND still having all the correct positions on the same frame.
Also we change mspaces above so that should also be correct.
In some sense this doesnt really matter cause the mouse will be in a different position when we move it BUT
it should be registered as on top of whatever it is after moving on the same frame as moving here.

REMINDER : The pixels_per_square in global zooming needs to be updated before this so that any movement below that considers
pixels per square will still be correct.
*/
// if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true,shift_pressed=true}, .DOWN_THIS_FRAME, game_input) {
if IsInputMapPress(.GLOBAL_MOVE_INSTANTLY, .DOWN_THIS_FRAME, game_input) {
	new_world_cam_pos : Vector2F = CameraSpaceToWorldSpace(mouse_cam, mspace_for_input.mspace_cam);
	MoveFixedCameraOpSpaces(new_world_cam_pos, mspace_for_input.mspace_cam.world_pos, perm.all_data);
	mspace_for_input.mspace_cam.world_pos = new_world_cam_pos;
}
/*DOC : We do this after hover selection so that we only move either op space cam or mspace cam
since moving the mspace cam happens in the chosen entities below.
HAVING THE MOVEMENTS closer together here makes it clearer that we only will move 1 per frame which is expected behavior.

WE HAVE TO DO THIS BEFOREHAND THE HOVERING CHECK OTHERWISE THE HOVERING IS OFF for the op space hovering highlighting
*/
else if perm.all_data.all_chosen_entities.count == 0 {
	move_vec, moved_this_frame := DefaultInputMove2D(game_input, renderer_data.base_render_group.pixels_per_square);
	if moved_this_frame {
		new_cam_pos : Vector2F = mspace_for_input.mspace_cam.world_pos + move_vec;
		MoveFixedCameraOpSpaces(new_cam_pos, mspace_for_input.mspace_cam.world_pos, perm.all_data);
		mspace_for_input.mspace_cam.world_pos = new_cam_pos;
	}
}

//TODO Need to update this whenever we change mspace
//TODO Instead fo using default_base_cam, why not just use mspace_For_input.mspace_Cam?
default_base_cam : Camera2D = mspace_for_input.mspace_cam;
world_mouse : Vector2F = CameraSpaceToWorldSpace(mouse_cam, mspace_for_input.mspace_cam);
#if 0 {
//Note : for mouse debugging
// if game_input.MouseButtons[0].down_this_frame {
if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
	print("world mouse is %, cam_mouse is %\n", world_mouse, mouse_cam);
	print("MouseX = %, MouseY = %\n", game_input.MouseX, game_input.MouseY);

	//Op Space cam test to WorldSpace
	#if 1 {
	if perm.all_data.all_open_op_spaces.count > 0 {
		op_space := perm.all_data.all_open_op_spaces[0];
		zoom : float = op_space.render_groups.scissor_group.zoom_factor;
		op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);
		new_world : Vector2F = OpSpaceToWorldSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);
		// op_mouse : Vector2F = ((world_mouse + op_space.op_2D_cam.world_pos) / zoom) - op_space.world_offset;
		// new_world : Vector2F = ((op_mouse + op_space.world_offset) * zoom) - op_space.op_2D_cam.world_pos;
		print("op_mouse = %, new_world = %\n", op_mouse, new_world);
	}
	}
}
}

/* Not sure exactly where to put this but here seems good since well be able to add things this frame
DOC : 
IF the terminal is open but not chosen, then we choose it. 
If it is open and chosen then we close it.
If it is closed, then we open it at the center fixed to the camera.
This cycle prevents us from losing the terminal space and the idea is that with the terminal
we can get to any other op space with terminal commands.

REMINDER THIS NEEDS TO BE BEFORE the hover op space check in case we close the terminal which would close the op space
and then we would have an invalid hovered op space.
*/
if IsInputMapPress(.TERMINAL_TOGGLE, .DOWN_THIS_FRAME, game_input) {
	//TODO Can create a function out of this if we allow opening the terminal from somewhere else but
	//maybe it's best to just have 1 place by default with the shortcut which can be set in SETTINGS
	#if 1 {
	open_op_space, found_open_op_space := ArrayFindFirstByNameId(perm.all_data.all_open_op_spaces,
		OpSpaceExternalType.terminal, "op_space_external_type");
	if found_open_op_space {
		terminal_is_chosen : bool =
			ArrayFindFirstByAndOpCheck(perm.all_data.all_chosen_entities, 
				EntityType.OP_SPACE, "entity_type", open_op_space.id, "id");
		if terminal_is_chosen {
			CloseOpSpace(open_op_space.op_space_name, perm.all_data, renderer_data);
		} else {
			ChooseOpSpace(open_op_space.*, perm.all_data, renderer_data);
		}
	} 
	else if !found_open_op_space {
		closed_op_space, found_closed_op_space := ArrayFindFirstByNameId(perm.all_data.all_closed_op_spaces, 
			OpSpaceExternalType.terminal, "op_space_external_type");
		if found_closed_op_space {
			OpenOpSpace(closed_op_space.op_space_name, renderer_data, perm.all_data);
		}
		else if !found_closed_op_space {
			//TODO Can make a function CreateTerminalOpSpace here so we can reuse it if we allow creating terminals
			//in other ways OR we have a specific command that creates a new terminal window.
			//BUT we only have 1 terminal data right now, might stay that way though because otherwise we would have to consider multithreading
			//TODO IF we find an op space with OP_TERMINAL_NAME here then we could delete it.
			//OR JUST prevent an closed_op_space with that name from being created
			//OR just create in InitAllData. right now that makes tests fail but that is likely the best option.
			//We could also have a specific setting that does not create the terminal to avoid test issues
			//or create the terminal as well and adapt the tests to having the terminal op space as default

			TERMINAL_NAME_CHECK :: "term%";
			terminal_name_number : int = 0;
			terminal_name : string = tprint(TERMINAL_NAME_CHECK, terminal_name_number);
			osp, found_op_space_with_same_name := FindOpSpacePointerOpenOrClosed(terminal_name, perm.all_data);
			while found_op_space_with_same_name {
				osp, found_op_space_with_same_name = FindOpSpacePointerOpenOrClosed(terminal_name, perm.all_data);
				terminal_name_number += 1;
				terminal_name = tprint(TERMINAL_NAME_CHECK, terminal_name_number);
			}

			//TODO SETTING pass in default terminal settings here for size and position
			create_terminal : CreateOpSpaceData;
			create_terminal.world_size = perm.all_data.runtime_settings.terminal_size;
			create_terminal.op_space_external_type = OpSpaceExternalType.terminal;
			//TODO FROM HERE Maybe we should copy this name in CreateClosedOpSpace for consistency
			//ALSO then update the lines when updating the terminal events
			//Then allow resizing from the terminal sides
			//DONT FORGET TO CHECK dynamic library and either update it to be simpler or allow system file functions to run
			create_terminal.op_space_name = copy_string(terminal_name);
			closed_op_space = CreateClosedOpSpace(perm.all_data, create_terminal);
			//TODO Set is_fixed_to_camera here once we add the settings for placement

			term_op : *TerminalOpSpaceData = array_add(*perm.all_data.all_terminal_op_space_data);
			term_op.op_space_id = closed_op_space.id;
			ResizeTerminalOpSpace(term_op, closed_op_space.world_size, renderer_data.base_render_group.pixels_per_square, 
				perm.text_editor_data, perm.terminal_data);
			//REMINDER Need to add the first split string here so we always have a terminal cmd split line
			//We do this in resizing now since we have to recompute the line char count
			// AddSplitStringByLines(perm.terminal_data.cmd_string_with_start, term_op.terminal_tsl.line_char_count, *term_op.terminal_tsl.split_lines);
			//TODO set to fixed by default AND likely pass in some settings here so we can set default position and size	
			OpenOpSpace(closed_op_space.op_space_name, renderer_data, perm.all_data);
		} 
	}
	//TODO WE COULD BRING THE TERMINAL HERE to the current render mspace cam BY DEFAULT always when we hit this shortcut
	//since right now it only happens if it's closed COULD ALSO PUT A NO_MOVE SWITCH
	//We choose the op space in open op space so we can remove from here now I think
	// ChooseOpSpace(op_space, perm.all_data, renderer_data);
	} else {
	//TODO I am leaving this here just to remember how we set the chosen entities and to reset to unselected state
	//but we can remove it eventually once we don't need it anymore
	chosen_terminal, terminal_is_chosen :=
		ArrayFindFirstConstByNameId(perm.all_data.all_chosen_entities,
			EntityType.TERMINAL, "entity_type");

	if terminal_is_chosen {
		ArrayRemoveFirstByNameId(*perm.all_data.all_chosen_entities,
			EntityType.TERMINAL, "entity_type");
		perm.terminal_open = false;
		perm.all_data.reset_to_unselected_state = true;
	}
	else {
		ArrayRemoveAllByNameId(*perm.all_data.all_chosen_entities, 
			EntityType.OP_SPACE, "entity_type");

		chosen_op_space : ChosenEntity;
		chosen_op_space.entity_type = EntityType.TERMINAL;
		array_add(*perm.all_data.all_chosen_entities, chosen_op_space);
		perm.terminal_open = true;
	}
	}
}

//TODO could put camera and grid offsets here (transforms applied to each grid type)

//TODO if the mouse is over the highest render_group op_space, then we don't need to check anything
//this would be more easily fixed if we just had streamed colliders only with type
//ie check if we are colliding with the op_spaces first (maybe order those first)
//and if so, only check the colliders in the op_space, otherwise check everything else
top_render_group_index : int = -1;
top_op_space : OperationSpace = ---;
hovering_top_op_space : bool = false;
//TODO Eventually we would just cycle over the viewable_op_spaces instead
//TODO We could store all the op_spaces we are hovering over in an array if we want to overlay op_spaces
//so we can have audio played or interaction on multiple spaces at once. Visual already works if we make background transparent.
for * op_space : perm.all_data.all_open_op_spaces {
if IsFixedViewableOpSpace(op_space.*, perm.all_data.render_mspace_id) {
	//Note : choose highest op_space based on render group order and re-order render_group if we
	//end up selecting a lower op_space
	//TODO Should we just store this rect in OperationSpace? Depends on how we move and resize it.
	op_space_rect : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size);
	cam_op_rect := WorldRectToCamRect(op_space_rect, default_base_cam);
	//TODO Could compute the whole title bar data for consistency but this is enough here for now.
 	title_bar_world_rect : Rectangle2 = OpSpaceTitleBarRect(op_space.*, perm.text_editor_data);
	title_bar_cam_rect : Rectangle2 = WorldRectToCamRect(title_bar_world_rect, default_base_cam);
	mouse_is_colliding : bool = IsInRectangle(mouse_cam, cam_op_rect) || IsInRectangle(mouse_cam, title_bar_cam_rect);
	if mouse_is_colliding {
		#if USE_OLD_ALL_RENDER_GROUPS {
		found_scissor_group, scissor_group_index := array_find(renderer_data.all_render_groups, op_space.render_groups.scissor_group);
		} else {
		found_scissor_group, scissor_group_index := FindOpSpaceRenderGroupsByIndex(op_space, renderer_data.open_op_space_render_groups);
		}
		if found_scissor_group && scissor_group_index > top_render_group_index {
			top_render_group_index = scissor_group_index;
			top_op_space = op_space.*;
			//TODO I think we should rename this to hovering_op_space since its not necessarily the top
			hovering_top_op_space = true;
		}
	}
}
}

#if 0 {
//TODO Should do this using camera movement events, so we can move to any world pos
//TODO Should we do this only when nothing is chosen instead of having an active cam?
//We could put op_space movement in op space chosen code.
//TODO Camera2D should be fixable so it can't move
//TODO FROM HERE If default base cam then we can move here but otherwise we should put movement in space 2d to prevent any unwanted movement
//And then also remove this input_check since it feels quite hacky imo and this is the only place we use it
// if ValidateInputPress(!active_cam.is_fixed, perm.all_data.input_check)
if active_cam != null {
	move_this_frame : Vector2F;
	if keyboard.Right.EndedDown {
		move_this_frame += MakeV2F(1.0, 0);
	}
	if keyboard.Left.EndedDown {
		move_this_frame += MakeV2F(-1.0, 0);
	}
	if keyboard.Up.EndedDown {
		move_this_frame += MakeV2F(0, 1.0);
	}
	if keyboard.Down.EndedDown {
		move_this_frame += MakeV2F(0, -1.0);
	}

 	if move_this_frame.x != 0 && move_this_frame.y != 0 {
    	move_this_frame *= 2.0*(1.0 / renderer_data.base_render_group.pixels_per_square);
    	// move_this_frame *= 1.0*(1.0 / pixels_per_square);
 	} else {
    	move_this_frame *= 2.0*(1.5 / renderer_data.base_render_group.pixels_per_square);
    	// move_this_frame *= 1.0*(1.5 / pixels_per_square);
	}
	active_cam.move_this_frame = move_this_frame;
	active_cam.world_pos += move_this_frame;
}
}

// if keyboard.p_button.down_this_frame && (keyboard.only_ctrl_down || keyboard.only_alt_down)
   // ValidateInputPress(keyboard.p_button.down_this_frame, perm.all_data.input_check)
// {
// 	//TODO We do the sort here whenever we play audio for convenience for now.
// 	// quick_sort(perm.all_data.all_mspace_data[0].all_music_pts, (m1,m2) => m1.x_start_float - m2.x_start_float);
// 	DefaultSortNeumes(perm.all_data.all_mspace_data[0].all_music_pts);

// 	if keyboard.only_ctrl_down {
// 		array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.STOP_ALL_MUSIC_PTS));
// 		array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.RESET_AUDIO_TO_MEMORY_UNIT, 0));
// 		perm.all_data.game_audio_play.play_state = AudioPlayState.STOP;
// 	}

// 	if keyboard.only_alt_down {
// 		if perm.all_data.game_audio_play.play_state == {
// 		case AudioPlayState.STOP; {
// 			perm.all_data.game_audio_play.play_state = AudioPlayState.PLAY;
// 			array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.RESET_AUDIO_TO_MEMORY_UNIT, perm.all_data.game_audio_play.current_x_memory));
// 		}
// 		case AudioPlayState.PLAY; {
// 			perm.all_data.game_audio_play.play_state = AudioPlayState.PAUSE;
// 			array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.STOP_ALL_MUSIC_PTS));
// 		}
// 		case AudioPlayState.PAUSE; {
// 			perm.all_data.game_audio_play.play_state = AudioPlayState.PLAY;
// 			array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.PLAY_NOTES_AT_CURRENT_MEMORY));
// 		}
// 		}
// 	}

// 	print("audio_state : %\n", perm.all_data.game_audio_play.play_state);
// }
//TODO Set these as input mappings that can be pressed anywhere
// if IsKeyboardPress(#char "P", .{alt_pressed=true}, .DOWN_THIS_FRAME, game_input) {
if IsInputMapPress(.PLAY_PAUSE_MUSIC, .DOWN_THIS_FRAME, game_input) {
	//TODO We do the sort here whenever we play audio for convenience for now.
	// quick_sort(perm.all_data.all_mspace_data[0].all_music_pts, (m1,m2) => m1.x_start_float - m2.x_start_float);
	DefaultSortNeumes(perm.all_data.all_mspace_data[0].all_music_pts);

	if perm.all_data.game_audio_play.play_state == {
	case AudioPlayState.STOP; {
		perm.all_data.game_audio_play.play_state = AudioPlayState.PLAY;
		array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.RESET_AUDIO_TO_MEMORY_UNIT, perm.all_data.game_audio_play.current_x_memory));
	}
	case AudioPlayState.PLAY; {
		perm.all_data.game_audio_play.play_state = AudioPlayState.PAUSE;
		array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.STOP_ALL_MUSIC_PTS));
	}
	case AudioPlayState.PAUSE; {
		perm.all_data.game_audio_play.play_state = AudioPlayState.PLAY;
		array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.PLAY_NOTES_AT_CURRENT_MEMORY));
	}
	}

	print("audio_state : %\n", perm.all_data.game_audio_play.play_state);
}
// else if IsKeyboardPress(#char "P", .{ctrl_pressed=true}, .DOWN_THIS_FRAME, game_input) {
else if IsInputMapPress(.STOP_MUSIC, .DOWN_THIS_FRAME, game_input) {
	//TODO We do the sort here whenever we play audio for convenience for now.
	// quick_sort(perm.all_data.all_mspace_data[0].all_music_pts, (m1,m2) => m1.x_start_float - m2.x_start_float);
	DefaultSortNeumes(perm.all_data.all_mspace_data[0].all_music_pts);

	array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.STOP_ALL_MUSIC_PTS));
	array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.RESET_AUDIO_TO_MEMORY_UNIT, 0));
	perm.all_data.game_audio_play.play_state = AudioPlayState.STOP;

	print("audio_state : %\n", perm.all_data.game_audio_play.play_state);
}

//TODO For now we prevent any hovering while moving an op_space as the title bar of another op space 
//was showing if we moved an op space quickly enough and the mouse would go over the other op_space.
//Maybe there is a better way of doing this but this seems ok since we do all hovering checks per frame here.
found_moving_op_space : bool = perm.all_data.all_moving_op_spaces.count > 0;
if hovering_top_op_space && !found_moving_op_space {
	hover_op_space : HoverEntity;
	hover_op_space.id = top_op_space.id;
	hover_op_space.entity_type = EntityType.OP_SPACE;
	array_add(*frame_hover_entities, hover_op_space);

	//TODO We could store the op_space_id in the hover_entity from the all_op_collision_entities
	//if we want to be able to hover over multiple op_spaces at once and have the input (eg audio) heard.
	if top_op_space.op_space_external_type == OpSpaceExternalType.space_2d {
		for ce : perm.all_data.all_op_collision_entities if ce.op_space_id == top_op_space.id {
			if ce.shape == {
			case CollisionShape.RECTANGLE;
				cam_rect := OpRectToCamRect(ce.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
				if IsInRectangle(mouse_cam, cam_rect) {
					// PushRectangleOutline(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, order = 10);
					hover_linear : *HoverEntity = array_add(*frame_hover_entities);
					hover_linear.id = ce.entity_id;
					hover_linear.entity_type = ce.entity_type;
				}
			case CollisionShape.CIRCLE;
				cam_circle := OpCircleToCamCircle(ce.circle, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
				if IsInCircle(mouse_cam, cam_circle) {
					// PushCircleOutline(cam_circle, LBLUE_V, top_op_space.render_groups.scissor_group, order=9);
					// PushCircle(cam_pos, ce.circle.radius, LBLUE_V, top_op_space.render_groups.scissor_group, order=9);
					hover_linear : *HoverEntity = array_add(*frame_hover_entities);
					hover_linear.id = ce.entity_id;
					hover_linear.entity_type = ce.entity_type;
				}			
			case CollisionShape.QUAD;
				//TODO This quad is 2x size of rect. Makes me want to have separate quad, rect and circle collision arrays
				//The reason I keep it is because maybe contiguous memory is faster than separate... would need to test i guess.
				//Could we replace this with 2 triangles. Would there possibly be a non-collided pixel sized gap between the triangles?
				cam_quad := OpQuadToCamQuad(ce.quad, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
				if PointInQuad(mouse_cam, cam_quad) {
					// PushQuadViewport(cam_quad, LBLUE_V, top_op_space.render_groups.scissor_group, order = 10);
					hover_linear : *HoverEntity = array_add(*frame_hover_entities);
					hover_linear.id = ce.entity_id;
					hover_linear.entity_type = ce.entity_type;
				}
			}
			//TODO Could add triangle collision as well. Maybe that could replace QUAD collision for efficiency...
			//Or we just have separate collision arrays instead.
		}

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(perm.all_data.all_op_space_spec_data,
			top_op_space.id, "op_space_id");
		assert(found_op_spec_data);
		//TODO Can remove the same loop above once we only use this for collisions in each op space instead
		for ce : op_spec_data.all_op_collision_entities {
			if ce.shape == {
			case CollisionShape.RECTANGLE;
				cam_rect := OpRectToCamRect(ce.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
				if IsInRectangle(mouse_cam, cam_rect) {
					// PushRectangleOutline(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, order = 10);
					hover_linear : *HoverEntity = array_add(*frame_hover_entities);
					hover_linear.id = ce.entity_id;
					hover_linear.entity_type = ce.entity_type;
				}
			case CollisionShape.CIRCLE;
				cam_circle := OpCircleToCamCircle(ce.circle, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
				if IsInCircle(mouse_cam, cam_circle) {
					// PushCircleOutline(cam_circle, LBLUE_V, top_op_space.render_groups.scissor_group, order=9);
					// PushCircle(cam_pos, ce.circle.radius, LBLUE_V, top_op_space.render_groups.scissor_group, order=9);
					hover_linear : *HoverEntity = array_add(*frame_hover_entities);
					hover_linear.id = ce.entity_id;
					hover_linear.entity_type = ce.entity_type;
				}			
			case CollisionShape.QUAD;
				//TODO This quad is 2x size of rect. Makes me want to have separate quad, rect and circle collision arrays
				//The reason I keep it is because maybe contiguous memory is faster than separate... would need to test i guess.
				//Could we replace this with 2 triangles. Would there possibly be a non-collided pixel sized gap between the triangles?
				cam_quad := OpQuadToCamQuad(ce.quad, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
				if PointInQuad(mouse_cam, cam_quad) {
					// PushQuadViewport(cam_quad, LBLUE_V, top_op_space.render_groups.scissor_group, order = 10);
					hover_linear : *HoverEntity = array_add(*frame_hover_entities);
					hover_linear.id = ce.entity_id;
					hover_linear.entity_type = ce.entity_type;
				}
			}
			//TODO Could add triangle collision as well. Maybe that could replace QUAD collision for efficiency...
			//Or we just have separate collision arrays instead.
		}
	} 
	//TODO I think we can remove this now that we removed the chord_s3 type altogether
	else if top_op_space.op_space_external_type == OpSpaceExternalType.chord_s3 {
		#if 0 {
		chord_s3, found_chord_s3 :=
			ArrayFindFirstByNameId(perm.all_data.all_chord_spaces_3, top_op_space.id, "op_space_id");
		assert(found_chord_s3);

		hover_chord_s3 : HoverEntity;
		hover_chord_s3.id = chord_s3.dspace_id;
		hover_chord_s3.entity_type = EntityType.CHORD_S3;
		array_add(*frame_hover_entities, hover_chord_s3);
		}
	}
} else {
	// ***TODO could just check all rectangles eventually and then select from there, that would be
	// the most efficient and eventually SIMDable and parallelizable***
	for ce : mspace_for_input.all_base_collision_entities {
		if ce.shape == {
		case CollisionShape.RECTANGLE;
			cam_rect := WorldRectToCamRect(ce.rect, default_base_cam);
			if IsInRectangle(mouse_cam, cam_rect) {
				hover_row : *HoverEntity = array_add(*frame_hover_entities);
				hover_row.id = ce.entity_id;
				hover_row.entity_type = ce.entity_type;
			}
		}
	}
}

//TODO FROM HERE We want chosing and hovering to be both in here and check each chosen thing separately
//and then update above to simplify to just check hover and chosen with colliders
if frame_hover_entities.count > 0 {

	top_op_space_is_chosen : bool =
		ArrayFindFirstByAndOpCheck(perm.all_data.all_chosen_entities, 
			EntityType.OP_SPACE, "entity_type", top_op_space.id, "id");

	//TODO We could store the op_space_id in the hover_entity from the all_op_collision_entities
	//if we want to be able to hover over multiple op_spaces at once and have the input (eg audio) heard.
	for hover_entity : frame_hover_entities {
		if hover_entity.entity_type == EntityType.CUSTOM_GEOMETRY && top_op_space_is_chosen {
			/*DOC : After careful consideration, we could put all shapes into a custom geometry BUT
			the problem then is that we would have to check collision for each shape and then for sound float
			we would need a separate method since we have to check the whole geometry.
			ALSO we likely have slightly separate hovering code for each one based on what we want to play
			such as vls on top of points we want to play the vl likely. Can consider later based on usage as well.
			This way is better and later people can make their own geometries with dynamic libraries as well.
			Then they can draw more elaborate geometries which can overlap in any way they want
			and even include their own sound floats when we add a hover external function option.
			Currently if points overlap, then we would process both and hear both.

			RIGHT NOW if we have multiple hovered entities, it will still go over both of them anyways.
			Maybe we can set render order a bit more systematically later so that people can set how they want that to happen.
			*/
			op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(perm.all_data.all_op_space_spec_data,
				top_op_space.id, "op_space_id");
			assert(found_op_spec_data);

			custom_g, found_custom_g := ArrayFindFirstByNameId(op_spec_data.ass.all_custom_geometries, 
				hover_entity.id, "dspace_id");
			assert(found_custom_g);

			//DOC : This can help the player see where the boundaries of the custom geometry is.
			if custom_g.show_collision {
				cam_rect := OpRectToCamRect(custom_g.collision_rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
				PushRectangleOutline(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, order = 10);
			}

			//If we are hovering over multiple shapes, then we process all of them so we can have overlapping shapes playing.
			all_hover_shapes : [..] SpaceShape;
			all_hover_shapes.allocator = temp;
			all_hover_cam_pos : [..] Vector2F;
			all_hover_cam_pos.allocator = temp;
			for op_spec_data.ass.all_space_rects if it.dspace_id == custom_g.dspace_id && !it.not_selectable { 
				cam_rect : Rectangle2 = OpRectToCamRect(it.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
				if IsInRectangle(mouse_cam, cam_rect) {
					array_add(*all_hover_shapes, it.shape);
					array_add(*all_hover_cam_pos, GetCenter(cam_rect));
					PushRectangle(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, it.render_order+3);
				}
			}
			//TODO This way allows us to hover over other shapes later if needed
			for hover_shape, hover_index : all_hover_shapes {
				if hover_shape.pitch_set.count > 0 {
					if custom_g.synth.simple_waves.count != hover_shape.pitch_set.count {
						array_reset_keeping_memory(*custom_g.synth.simple_waves);
						for 0..hover_shape.pitch_set.count-1 {
							AddSimpleWaveFromFrequency(0, *custom_g.synth, audio_data);
						}
					}
					if custom_g.custom_audio_type == CustomAudioType.TUNING_SYSTEM {
						tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, custom_g.tuning_system_id, "id");
						tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
						assert(tuning_system.music_pt_count == tuning_pitches.count);					
						for hover_shape.pitch_set {
							frequency : float = MusicPtToFrequency(it, tuning_system, tuning_pitches);
							UpdateWaveFrequency(frequency, *custom_g.synth.simple_waves[it_index], audio_data.*);
						}
					}
					else if custom_g.custom_audio_type == CustomAudioType.PITCH_SET_AS_FREQUENCY {
						for frequency : hover_shape.pitch_set {
							UpdateWaveFrequency(cast(float) frequency, *custom_g.synth.simple_waves[it_index], audio_data.*);
						}
					}
					GenerateSimpleSynthSamples(*custom_g.synth, audio_data.float_buffer, audio_data);
				}	

				if hover_shape.shape_text.data != null && hover_shape.shape_text.count > 0 {
					cam_pos : Vector2F = all_hover_cam_pos[hover_index];
					//TODO Do we want to center this or just offset it a bit?
					// cam_pos.x -= 0.5*hover_shape.shape_text.count*perm.text_editor_data.code_font_1_char_width_world;
					cam_pos.x -= perm.text_editor_data.code_font_1_char_width_world;
					PushText(cam_pos, hover_shape.shape_text, WHITE_V, top_op_space.render_groups.scissor_group, 10003);
				}
			}
		} 
		else if hover_entity.entity_type == EntityType.CHORD_S2 {
			if top_op_space_is_chosen {
				op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(perm.all_data.all_op_space_spec_data,
					top_op_space.id, "op_space_id");
				assert(found_op_spec_data);

				chord_s2, found_chord_s2 := ArrayFindFirstByNameId(op_spec_data.all_op_chord_s2, 
					hover_entity.id, "dspace_id");
				assert(found_chord_s2);

				//TODO This should be fetched by index more efficienlty and everywhere else as well.
				//TODO We could fetch this only if we found_audio_to_play, unless we have sound_float.
				tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, chord_s2.tuning_system_id, "id");
				tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
				assert(tuning_system.music_pt_count == tuning_pitches.count);

				mouse_hovering_point : bool = false;
				found_audio_to_play : bool = false;
				audio_fun_region_pos : [2] float64;

				#if 0 {
				//TODO Eventually this should be optimized by the fact that all_space_rects are only the ones we can see
				//AND that it should be indexed/sorted by dspace_id/op_space_id/render_order
				//ACTUALLY If we us space_shapes with op_space_id together then we can just get that specific
				//array and then would just need to sort by dspace_id and/or render_order
				//IF WE associated dspace_shape_group to a memory_range/memory_unit then we could highlight here
				//if we select it or something like that to see what vls are associated to what memory.
				max_render_order : int = S64_MIN;
				hover_rect : SpaceRect;
				for op_spec_data.ass.all_space_rects {
					if it.dspace_id == chord_s2.dspace_id && 
						//TODO Is this better to check with dspace_shape_group or these?
					  (it.render_order == chord_s2.music_pt_render_order ||
					   it.render_order == chord_s2.space_pt_render_order) &&
						it.render_order > max_render_order
					{
						cam_rect : Rectangle2 = OpRectToCamRect(it.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
						if IsInRectangle(mouse_cam, cam_rect) {
							hover_rect = it;
							mouse_hovering_point = true;
							// PushRectangle(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, it.render_order+1);
							// hover_point_world_pos = GetCenter(it.rect);
						}
					}
				}
				} else {
				max_render_order : int = S64_MIN;
				hover_rect : SpaceRect;
				for op_spec_data.ass.all_space_rects {
					if it.dspace_id == chord_s2.dspace_id && !it.not_selectable	&&
						//TODO Could use this if needed later
					   // (it.render_order == chord_s2.music_pt_render_order ||
					   //  it.render_order == chord_s2.space_pt_render_order) &&
						 it.render_order > max_render_order
					{
						cam_rect : Rectangle2 = OpRectToCamRect(it.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
						if IsInRectangle(mouse_cam, cam_rect) {
							hover_rect = it;
							mouse_hovering_point = true;
							max_render_order = it.render_order;
							// break;
							// PushRectangle(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, it.render_order+1);
							// hover_point_world_pos = GetCenter(it.rect);
						}
					}
				}					
				}

				if mouse_hovering_point {
					cam_rect : Rectangle2 = OpRectToCamRect(hover_rect.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
					PushRectangle(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, hover_rect.render_order+1);

					hover_point_world_pos : Vector2F = GetCenter(hover_rect.rect);

					found_audio_to_play = true;
					// audio_fun_region_pos = WorldPosToFunRegionPosMatrix(hover_point_world_pos, chord_s2.*);
					audio_fun_region_pos[0] = hover_rect.pitch_set[0];
					audio_fun_region_pos[1] = hover_rect.pitch_set[1];

					// pitches : [2] float = FunRegionPosToPitchSet(audio_fun_region_pos.component, chord_s2.music_pt_count);
					// text : string = tprint("%,%", pitches[0], pitches[1]);
					text_pos := hover_point_world_pos;
					text_pos.x -= perm.text_editor_data.code_font_1_char_width_pixel / renderer_data.base_render_group.pixels_per_square;
					cam_pos : Vector2F = OpSpaceToCameraSpace(text_pos, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
					PushText(cam_pos, hover_rect.shape_text, WHITE_V, top_op_space.render_groups.scissor_group, 10003);
				}

				//TODO This does not actually work with the zoom factor but it works without it so should we leave it?
				//It's also kind of nauseating. It works without the zoom factor so I cant put it back in without zoom
				//factor if someone wants it for some reason.
				//IMPORTANT THIS DOES NOT WORK ANYMORE IF WE ZOOM IN AND OUT SO I WILL WRITE THAT SOMEWHERE BUT I THINK
				//ITS INTERESTING FOR PEOPLE TO SEE AND PLAY WITH ANYWAYS
				#if 1 {
				if chord_s2.is_sound_float {
					//TODO Can we do this CamPosToFunRegionPosMatrix? I think so if we just subtract cam from other ones
					//but then what's the difference since we still need to compare to world_pos...
					found_audio_to_play = true;
					//THIS DOES NOT ACTUALLY CHANGE THE AUDIO WITH THE ZOOM FACTOR PROPERLY
					// UpdateChordS2Matrices(top_op_space.render_groups.scissor_group.zoom_factor, chord_s2);
					op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, top_op_space, top_op_space.op_2D_cam.world_pos);
					audio_fun_vector : Vector2F = WorldPosToFunRegionPosMatrix(op_mouse, chord_s2.*);
					audio_fun_region_pos[0] = cast(float64) audio_fun_vector.component[0];
					audio_fun_region_pos[1] = cast(float64) audio_fun_vector.component[1];
				}
				}

				//TODO Could put a full mute here if needed.
				if found_audio_to_play {
					#if 1 {
					//TODO Likely will have the synth be separate eventually so then we can just init from the code
					//This is just to make sure things works for now.
					if chord_s2.synth.simple_waves.count == 0 {
						AddSimpleWaveFromFrequency(0, *chord_s2.synth, audio_data);
						AddSimpleWaveFromFrequency(0, *chord_s2.synth, audio_data);
					}
					for * wave, w_index : chord_s2.synth.simple_waves {
						//TODO Set the base frequency in setup music and then pass that in as a setting to adjust base frequencies
						frequency : float = MusicPtToFrequency(audio_fun_region_pos[w_index], tuning_system, tuning_pitches, C3);
						// frequency : float = MusicPtToFrequency(audio_fun_region_pos[w_index], tuning_system, tuning_pitches);
						UpdateWaveFrequency(frequency, wave, audio_data.*);
					}
					GenerateSimpleSynthSamples(*chord_s2.synth, audio_data.float_buffer, audio_data);

					} else {
					for * wave, w_index : chord_s2.osc_waves {
						wave.type = OscWaveType.SINE;
						frequency : float = MusicPtToFrequency(cast(float64) audio_fun_region_pos.component[w_index], tuning_system, tuning_pitches);
						UpdateWaveFrequency(frequency, wave, <<audio_data);
	 					AddToAudioBuffer(wave, audio_data);
					}
					}
				}
			}
		}
		else if hover_entity.entity_type == EntityType.PITCH_S2 {
			//Note : This space is very confusing after 1 octave. Not sure if I want it for anything more than
			//explanatory/comparison purposes to compare with 1D space. 
			//TODO Could we somehow scroll through this space like we do in 2D to simplify it?
			//We would just increment all the fun_region_float by += 1 on a scroll and everything else would
			//remain the same. We could try that. ALSO we could color the points like a piano in 12 eq for clarity
			//to see what that looks like.
			//TODO FROM HERE Try the above and then also do a simple PITCH_S3 the same way and update SpacePoint3D so
			//we don't use the render_cube flag and can easily do PITCH_S3 with the same code no changes for both
			//rendering and also mouse hovering. Cleanup cube from SpacePoint3D as well probably.
			//START SPIRAL AGAIN THEN
			//TODO Do we really need this space or can we collapse it with ChordSpace2 which is just a filtered
			//and transformed version of this space. I guess if the input is different enough then maybe yes.
			if top_op_space_is_chosen {
				pitch_s2, found_pitch_s2 := ArrayFindFirstByNameId(perm.all_data.all_pitch_space_2D,
					hover_entity.id, "dspace_id");
				assert(found_pitch_s2);

				// if game_input.mouse_wheel != 0 {
				if IsMouseWheelWithoutModifiers(game_input) {
					//TODO This makes me want to put the points in a separate array but can do it later if we keep pitch_s2 anyways.
					for * point : perm.all_data.all_space_points if point.dspace_id == pitch_s2.dspace_id {
						if point.fun_region_float[0] + game_input.mouse_wheel < 0 ||
							point.fun_region_float[1] + game_input.mouse_wheel < 0 
						{
							break;
						}
						point.fun_region_float[0] += game_input.mouse_wheel;
						point.fun_region_float[1] += game_input.mouse_wheel;
						if IsOnAxis(float64.[1.0,3.0,6.0,8.0,10.0], point.fun_region_float, cast(float64) pitch_s2.base_point_count) {
							point.color = GREY_BLACK_V;
						} else {
							point.color = GREY_DARKER_V;
						}
					}
				}

				for point : perm.all_data.all_space_points if point.dspace_id == pitch_s2.dspace_id {
					cam_rect : Rectangle2 = OpRectToCamRect(point.rect_mesh, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
					if IsInRectangle(mouse_cam, cam_rect) {
						PushRectangle(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, order = 10);

						shifted_pos := GetCenter(cam_rect);
						shifted_pos.x -= perm.text_editor_data.code_font_1_char_width_pixel / renderer_data.base_render_group.pixels_per_square;
						shifted_pos.y -= 0.5 * perm.text_editor_data.char_height / renderer_data.base_render_group.pixels_per_square;
						text : string = tprint("%,%", point.fun_region_float[0], point.fun_region_float[1]);
						PushText(shifted_pos, text, WHITE_V, top_op_space.render_groups.scissor_group, 10003);

						for * wave, w_index : pitch_s2.osc_waves {
							wave.type = OscWaveType.SINE;
							frequency := cast(float) PitchWithOctaveToFrequency(point.fun_region_float[w_index], pitch_s2.base_point_count, 2, ref_freq = C3);
							UpdateWaveFrequency(frequency, wave, <<audio_data);
	    					AddToAudioBuffer(wave, audio_data);
	    				}

	    				break;
					}
				}
			}
		}
		//TODO We can remove this once we remove the old chord s3 code
		else if hover_entity.entity_type == EntityType.CHORD_S3 {
			chord_s3_already_chosen : bool =
				ArrayFindFirstByAndOpCheck(perm.all_data.all_chosen_entities, 
					EntityType.CHORD_S3, "entity_type", hover_entity.id, "id");
			if !chord_s3_already_chosen {
				if game_input.MouseButtons[0].down_this_frame {
					chosen_chord_s3 : ChosenEntity;
					chosen_chord_s3.id = hover_entity.id;
					chosen_chord_s3.entity_type = EntityType.CHORD_S3;
					array_add(*perm.all_data.all_chosen_entities, chosen_chord_s3);
				}
			}
		}
		else if hover_entity.entity_type == EntityType.SPIRAL {
			if top_op_space_is_chosen {
				op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(perm.all_data.all_op_space_spec_data,
					top_op_space.id, "op_space_id");
				assert(found_op_spec_data);
				
				// sp := ArrayFindFirstByNameId(perm.all_data.all_spiral_spaces, hover_entity.id, "dspace_id");
				sp, found_spiral := ArrayFindFirstByNameId(op_spec_data.all_op_spirals, hover_entity.id, "dspace_id");
				assert(found_spiral);

				is_playing_chord : bool = false;
				audio_pitches : [] float64;
				NEW_AUDIO_PITCH :: true;
				//TODO Eventually we can pull this out with all_space_points and have the same behavior for all 
				//space_points that are hoverable and do collision directly and do the same for memory positions
				//and then we only need the separate code for audio if the audio is on.
				//Then if we have audio for specific points, we would come in here and play the audio
				//just for that specific point, unless it's float audio and then we would just do float audio instead.
				#if 0 {
				for perm.all_data.all_space_rects if it.dspace_id == sp.dspace_id {
					cam_rect := OpRectToCamRect(it.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
					if IsInRectangle(mouse_cam, cam_rect) {
						PushRectangle(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, order = sp.base_render_order + 3);

						//TODO Can draw the text above or below to not overlap with number on spiral diagram.
						//CAN ALSO only draw this if we don't draw the text the rest of the time. 
						s_values := ArrayFindAllVarName(perm.all_data.all_space_shape_values, it.shape_id, "shape_id");
						assert(s_values.count == sp.chord_count);
						chord_pitches := NewArray(s_values.count, float64, false,, temp);
						for s_values chord_pitches[it_index] = it.float_value;
						quick_sort(chord_pitches, (cp1,cp2) => cp1 - cp2);

						PushText(GetCenter(cam_rect), tprint("%",chord_pitches), WHITE_V, top_op_space.render_groups.scissor_group, 10003);

						//TODO This should be passed to the audio stream instead of done directly here.
						//Doing this way for convenience right now. CHANGE SOON THOUGH SO WE CAN ALSO
						//DO IT WITH MIDI. This can be the start of how we do it as an instrument.
						//Instrument is tricky because how do we deal with different inversions and different octaves.
						//One way is octaves can be a button and inversions can be based on last selected note
						//with the respective chordal and scalar transpositions.
						// lock(*perm.locked_sound_data.audio_mutex);
						#if NEW_AUDIO_PITCH {
						//TODO Maybe can just use audio_pitches instead of chord_pitches here
						audio_pitches = chord_pitches;
						} else {
						for pitch, pitch_index : chord_pitches {
							// frequency : float = PitchToFrequency(0, pitch, sp.tuning_count, 2, ref_freq = C3);
							frequency : float = PitchWithOctaveToFrequency(pitch, sp.tuning_count, 2, ref_freq = C3);
							// frequency : float = EqTempPitchToFrequency(0, pitch, ref_freq = C4);
							UpdateWaveFrequency(frequency, *sp.osc_waves[pitch_index], <<audio_data);
							AddToAudioBuffer(*sp.osc_waves[pitch_index], audio_data);
						}
						}
						// unlock(*perm.locked_sound_data.audio_mutex);

						is_playing_chord = true;
						// perm.locked_sound_data.hover_waves = sp.osc_waves;
						break;
					}
				}
				} else {
				for op_spec_data.ass.all_space_rects if it.dspace_id == sp.dspace_id {
					cam_rect := OpRectToCamRect(it.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
					if IsInRectangle(mouse_cam, cam_rect) {
						PushRectangle(cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, order = sp.base_render_order + 3);

						//TODO Can draw the text above or below to not overlap with number on spiral diagram.
						//CAN ALSO only draw this if we don't draw the text the rest of the time. 
						// s_values := ArrayFindAllVarName(perm.all_data.all_space_shape_values, it.shape_id, "shape_id");
						// assert(s_values.count == sp.chord_count);
						// chord_pitches := NewArray(s_values.count, float64, false,, temp);
						// for s_values chord_pitches[it_index] = it.float_value;
						// quick_sort(chord_pitches, (cp1,cp2) => cp1 - cp2);

						PushText(GetCenter(cam_rect), it.shape_text, WHITE_V, top_op_space.render_groups.scissor_group, 10003);

						//TODO This should be passed to the audio stream instead of done directly here.
						//Doing this way for convenience right now. CHANGE SOON THOUGH SO WE CAN ALSO
						//DO IT WITH MIDI. This can be the start of how we do it as an instrument.
						//Instrument is tricky because how do we deal with different inversions and different octaves.
						//One way is octaves can be a button and inversions can be based on last selected note
						//with the respective chordal and scalar transpositions.
						// lock(*perm.locked_sound_data.audio_mutex);
						#if NEW_AUDIO_PITCH {
						//TODO Maybe can just use audio_pitches instead of chord_pitches here
						audio_pitches = it.pitch_set;
						} else {
						for pitch, pitch_index : chord_pitches {
							// frequency : float = PitchToFrequency(0, pitch, sp.tuning_count, 2, ref_freq = C3);
							frequency : float = PitchWithOctaveToFrequency(pitch, sp.tuning_count, 2, ref_freq = C3);
							// frequency : float = EqTempPitchToFrequency(0, pitch, ref_freq = C4);
							UpdateWaveFrequency(frequency, *sp.osc_waves[pitch_index], <<audio_data);
							AddToAudioBuffer(*sp.osc_waves[pitch_index], audio_data);
						}
						}
						// unlock(*perm.locked_sound_data.audio_mutex);

						is_playing_chord = true;
						// perm.locked_sound_data.hover_waves = sp.osc_waves;
						break;
					}
				}
				}

				/*TODO We could have a version of float spiral where we don't increment all values but only 1 value at a time.
				If sound_float we could just use this. But then if the player puts other points this will override that, hmmmm...
				We could allow more options like that here if needed later.

				TODO IMPORANT If we have a sound_point type for example, then we can just output the sound with
				this same code but only if the mouse is within the point!
				Can also pull this out as SpacePosToSpiralIndex and/or SpacePosToSpiralChord and then
				just do that and if we have sound_point, just take the position of that point in the world OR
				in that specific case we can cache it
				*/
				if sp.sound_float && sp.base_chord.count > 0 && !is_playing_chord &&
				  (sp.spiral_type == SpiralType.PROPER || sp.spiral_type == SpiralType.CONCENTRIC_CIRCLE) 
				{
					//TODO The right side of the spiral still plays the extra octave but it seems weird to remove
					//since the spiral does not line up perfectly with the circle.
					circle_cam : Vector2F = OpSpaceToCameraSpace(sp.world_center_pos, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
					//TODO Can make a SpiralPointToChord function here for the opposite direction from ChordToSpiralPoint
					mouse_polar : Vector2F = VectorToPolarZeroTo2PI(mouse_cam - circle_cam, sp.rotate, sp.is_clockwise);
					// print("new_theta : %\n", mouse_polar.theta);
					//TODO I think this line might causing the frequency drop on the left side of circle...
					mouse_diff : float = sp.tuning_count * mouse_polar.theta / TAU;
					// print("mouse_diff : %\n", mouse_diff);
					mouse_diff_int : int = cast(int) mouse_diff;
					mouse_diff /= cast(float) sp.chord_count;
					radius_diff : float;
					//TODO Could just divide mouse_polar.radius here here
					// mouse_zoom : float = mouse_polar.radius / top_op_space.render_groups.scissor_group.zoom_factor;
					//NOTE : To account for zooming in the op_space for float instrument
					mouse_polar.radius /= top_op_space.render_groups.scissor_group.zoom_factor;
					//TODO Can remove this if if we only do PROPER spirals eventually.
					if sp.spiral_type == SpiralType.PROPER {
						//TODO Can put this in SpiralDiagram so we don't have to recompute. Maybe we can do a few constants.
						// spiral_delta : float = sp.radius_size / sp.tuning_count;
						//NOTE : we have to multiple all the radius variables here to account for the zoom but since we are dividing
						//then it is more convenient to just divide the value that we don't have to multiply here.
						//It is unclear though but it does what we need it to do. Also maybe just have float instrument for PROPER spiral
						//and maybe just remove everything other than PROPER spiral.
						radius_diff = round((mouse_polar.radius - sp.start_radius - mouse_diff_int * sp.spiral_delta) / sp.radius_size);
					} else if sp.spiral_type == SpiralType.CONCENTRIC_CIRCLE {
						radius_diff = round((mouse_polar.radius - sp.start_radius) / sp.radius_size);
					}
					// print("radius : %\n", mouse_polar.radius);
					// if radius_diff >= 0 {
					// if mouse_polar.radius > 0.5*sp.start_radius {
					radius_diff *= sp.tuning_count / cast(float) sp.chord_count;
					//We use factor here instead (-1 for out_in and +1 for in_out) 
					// mouse_diff += sp.in_out_factor * radius_diff;
					/*This base_index offset needs to be divided by chord_count since 
					  each + 1 base_index increments by (1 / chord_count) with sound
					  We can just rotate the spiral if needed to play rotated.
					  TODO To set multiple base points we just create more and then just need to update the
					  base_space_point_id and base_index to whatever we want.
					  NOTE : We then just need to grab the space_point that has this dspace_id and int_pos.x == base_index
					  and then set base_space_point_id to that and update the base_index
					*/
					base_index_offset : float = sp.base_index / cast(float)sp.chord_count;
					mouse_diff += sp.in_out_factor * radius_diff - base_index_offset;
					//I am leaving the branching commented out here for clarity now
					// if sp.is_in_out mouse_diff += radius_diff;
					// else mouse_diff -= radius_diff;
					// base_chord := ArrayFindAllVarName(perm.all_data.all_space_point_to_value, 
					// 	sp.base_space_point_id, "space_point_id", temp);
					// base_chord := sp.base_chord;
					// assert(base_chord.count == sp.chord_count);
					mouse_chord := NewArray(sp.base_chord.count, float64,, temp);
					for sp.base_chord mouse_chord[it_index] = it + mouse_diff;
					// print("mouse_chord : %", mouse_chord);
					//This blocks out the center and the section before the sp.base_chord where there is no spiral.
					//TODO Could allow this to be more or less with an option in SpiralSpace if we want to 
					//alow this to be played more as an instrument with more octaves.
					if mouse_chord[0] >= cast(float64) sp.base_chord[0] && 
						mouse_chord[0] <= cast(float64) sp.base_chord[0] + sp.tuning_count 
					{
						is_playing_chord = true;
						// lock(*perm.locked_sound_data.audio_mutex);
						#if NEW_AUDIO_PITCH {
						audio_pitches = mouse_chord;
						} else {
						for pitch, pitch_index : mouse_chord {
							// frequency : float = PitchToFrequency(0, pitch, sp.tuning_count, 2, ref_freq = C3);
							frequency : float = PitchWithOctaveToFrequency(pitch, sp.tuning_count, 2, ref_freq = C3);
							UpdateWaveFrequency(frequency, *sp.osc_waves[pitch_index], audio_data.*);
							AddToAudioBuffer(*sp.osc_waves[pitch_index], audio_data);
						}
						}
						// unlock(*perm.locked_sound_data.audio_mutex);
						// perm.locked_sound_data.hover_waves = sp.osc_waves;
					}
				}
				//TODO FROM HERE set synth to be in an array and set here and then envelope to turn off when we
				//dont have audio playing so we can set a bool outside for that. (can force envelope off)
				//Then the waves will be removed when they end automatically and we can just reset here
				//whenever they are playing and then we wont remove
				//Then we can set an audio_was_playing and audio_is_playing to check if we need to reset
				#if NEW_AUDIO_PITCH {
				if audio_pitches.count > 0 {
					tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, sp.tuning_system_id, "id");
					tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
					assert(tuning_system.music_pt_count == tuning_pitches.count);
					if sp.synth.simple_waves.count != audio_pitches.count {
						//TODO Can remove this once we grab the synth externally but can still set the waves here for convenience.
						// sp.synth.wave_type = OscWaveType.SAW;
						sp.synth.envelope = MakeVolumeEnvelope();

						array_reset_keeping_memory(*sp.synth.simple_waves);
						for 0..audio_pitches.count-1 {
							AddSimpleWaveFromFrequency(0, *sp.synth, audio_data);
						}
					}
					for pitch, pitch_index : audio_pitches {
						// frequency : float = PitchWithOctaveToFrequency(pitch, sp.tuning_count, 2, ref_freq = C3);
						frequency : float = MusicPtToFrequency(pitch, tuning_system, tuning_pitches, cast(float) sp.pitch_zero_freq);
						UpdateWaveFrequency(frequency, *sp.synth.simple_waves[pitch_index], audio_data.*);
					}
					GenerateSimpleSynthSamples(*sp.synth, audio_data.float_buffer, audio_data);
				}
				}
			}
		}
		else if hover_entity.entity_type == EntityType.OP_CIRCLE_DSPACE {
			if top_op_space_is_chosen {
				op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(perm.all_data.all_op_space_spec_data,
					top_op_space.id, "op_space_id");
				assert(found_op_spec_data);

				circle : *CircleSpace = ArrayFindFirstByNameId(op_spec_data.all_op_circle_spaces, 
					hover_entity.id, "dspace_id");

				//TODO This should be fetched by index more efficienlty and everywhere else as well.
				tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, circle.tuning_system_id, "id");
				tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
				assert(tuning_system.music_pt_count == tuning_pitches.count);

				NEW_AUDIO :: true;
				assert(circle.synth.simple_waves.count > 0);
				add_audio : bool = false;

				/*DOC TODO : Eventually we might just be able to have space rects and values and we can
				just dspace to op_space index maybe or directly just play the values.
				- This way would require having colliders for each space rect but I think that would be ok.
					Would be a reason to optimize the colliders (maybe remove quad out).
				- Then we would just have to go over space rects and play the values with 1 synth depending on the amount.
				- This could be done for circle, spiral and chord_s2.
				Let's wait until maybe we do chord_s3 and then likely can do this.
				*/
				//TODO Likely need to grab this by op space once we have it per op space
				//This technically acts as an extra filter BUT dspace_id is unique right now
				//and will likely be unique per op_space afterwards... or maybe we keep them unique anyways after
				// if it.op_space_id == external_data_to_op_space.external_id &&
				//TODO Can remove these 2 if we no longer use hovering other than for float
				// use_hovering_point : bool;
				// hover_cam_pos : Vector2F;

				max_render_order : int = S64_MIN;
				found_hover_rect : bool;
				hover_rect : SpaceRect;
				hover_cam_rect : Rectangle2;
				for op_spec_data.ass.all_space_rects if it.dspace_id == circle.dspace_id {
					// world_pos : Vector2F = circle.transform * point.dspace_pos + circle.world_center;
					// world_rect : Rectangle2 = RectCenterDim(world_pos, circle.point_dim);
					cam_rect := OpRectToCamRect(it.rect, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
					if IsInRectangle(mouse_cam, cam_rect) && it.render_order > max_render_order {
						max_render_order = it.render_order;
						found_hover_rect = true;
						hover_rect = it;
						hover_cam_rect = cam_rect;
					}
				}
				if found_hover_rect {
					if hover_rect.shape_text.count > 0 {
						text_pos : Vector2F = GetCenter(hover_cam_rect);
						text_pos.x -= 0.5 * hover_rect.shape_text.count * perm.text_editor_data.code_font_1_char_width_world; 
						text_pos.y += perm.text_editor_data.char_height / top_op_space.render_groups.scissor_group.pixels_per_square; 
						PushText(text_pos, hover_rect.shape_text, WHITE_V, top_op_space.render_groups.scissor_group, 10003);
					}
					/*DOC 2 methods
					1) Use float directly from space rect position (this is very cool and mathematically holistic)
						- disadvantage is that theoretically we can have slightly different frequencies on each frame
						due to floating point error (maybe with very large circles or minute point differences)
						- disadvantage we have to compute the frequency every frame
						- advantage is theoretical mathematical holisticness
						- advantage using inverse operation from space to sound is very cool!
						- these all apply to sound float no matter what which we leave as optional flag
					2) Store the frequency on creation and play thtat directly
						- disadvantage is that we have to fetch the shape value
						- advantage is we don't have to compute frequency
						- advantage is the frequency is always the same for that point no matter what
						- advantage as to which notes play sound and which dont
						- advantage can set more/other values if needed
					*/
					#if 0 {
					use_hovering_point = true;
					hover_cam_pos = GetCenter(cam_rect);
					//TODO We could store the pitches based on shape_id and then grab them precisely there
					} else {
					PushRectangle(hover_cam_rect, LBLUE_V, top_op_space.render_groups.scissor_group, order = hover_rect.render_order+2);
					if hover_rect.pitch_set.count > 0 {
						frequency : float = MusicPtToFrequency(hover_rect.pitch_set[0], tuning_system, tuning_pitches);
						// frequency := cast(float) shape_value.float_value;
						#if NEW_AUDIO {
						UpdateWaveFrequency(frequency, *circle.synth.simple_waves[0], audio_data.*);
						} else {
						UpdateWaveFrequency(frequency, *circle.osc_wave, audio_data.*);
						}
						add_audio = true;
					}
					}
					// break;
				}

				/*DOC We leave both float and discrete value here and wrote some docs above where we set them for both cases.
				TODO We can pull this out and then use it to play a position even if we have a specific point and not sound_float.
				Then we would just pass the specific point that we are on as an inverse function without the float.

				We dont add audio if we are already adding audio from the hover rect
				REMINDER in general we need to ensure that audio is only coming from 1 source in this dspace so we don't have
				overlapping audio although we can have overlapping audio from other dspaces
				*/
				if circle.is_sound_float && !add_audio {
					// use_hovering_point = true;
					// hover_cam_pos = mouse_cam;

					cam_circle : Vector2F = OpSpaceToCameraSpace(circle.world_center, top_op_space, top_op_space.op_2D_cam.world_pos, default_base_cam);
					c_diff : Vector2F = mouse_cam - cam_circle;
					if Length(c_diff) > circle.inner_circle_mute * circle.radius {
						//TODO We need to divide by the radius so maybe we should not put the radius in the transform?
						//Then we would have to multiply the radius as well as the transform everywhere for rendering
						//but I think conceptually that makes more sense since the radius is just a trick in the transform.
						// c_diff_norm : Vector2F = c_diff / circle.radius;
						c_trans : Vector2F = circle.transform * c_diff;
						polar : Vector2F = VectorToPolarZeroTo2PI(c_trans,clockwise=false);
						polar.radius /= top_op_space.render_groups.scissor_group.zoom_factor;
						// polar.theta = fmod_cycling(polar.theta, TAU);
						//TODO Should we put num_of_points in CircleSpace? This can differ from tuning_system for non-repeating circles.
						music_pt_float := cast(float64) circle.inter_points.count * polar.theta / TAU;
						music_pt_float += circle.start_note;

						//TODO Technically we could force this to be equal equal_temperament since it will be the same
						//over the same span realtive to some compass interval on the circle.
						frequency : float = MusicPtToFrequency(music_pt_float, tuning_system, tuning_pitches);
						#if NEW_AUDIO {
						UpdateWaveFrequency(frequency, *circle.synth.simple_waves[0], audio_data.*);
						} else {
						UpdateWaveFrequency(frequency, *circle.osc_wave, audio_data.*);
						}
						// AddToAudioBuffer(*circle.osc_wave, audio_data);
						add_audio = true;
					}
					// add_audio = true;					
				}
				// if use_hovering_point {
				// } 
				//TODO We only add this once here for now but we can change it once we pull everything out since
				//this will happen at the collision code and not the rendering code.
				if add_audio {
					//TODO Use SimpleSynth here
					#if NEW_AUDIO {
					GenerateSimpleSynthSamples(*circle.synth, audio_data.float_buffer, audio_data);
					} else {
					AddToAudioBuffer(*circle.osc_wave, audio_data);
					}
				}
			}
		}
		else if hover_entity.entity_type == EntityType.LANE_ROW_WITH_SECTIONS {
			// if game_input.mouse_wheel != 0 {
			row, found_row := ArrayFindFirstByNameId(mspace_for_input.all_music_lane_rows,
				hover_entity.id, "id");
			assert(found_row);
			if IsMouseWheelWithoutModifiers(game_input) {
				//TODO Can adjust this rate of movement by a multiple if needed. Can store it in the row if needed.
				//Could make it adjustable by user and then also default to smallest rect height.
				rate : float = 0.5;
				row.row_cam.y += rate * game_input.mouse_wheel;
				//TODO How should we max the top out? Should it be based on frequencies or just allow the user to place it?
				// row.row_cam.y = Clamp(0.0, row.row_cam.y, 9 * row.octave_height);
				row.row_cam.y = Clamp(-9 * row.octave_height, row.row_cam.y, 9 * row.octave_height);
			} 
			//TODO Should this just be mouse button left? OR should we make it an input mapping?
			//The ctrl makes it feel more intentional overall but having an input map with this as default could be ok i think
			else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true}, .DOWN_THIS_FRAME, game_input) {
				// DefaultSortNeumes(mspace_for_input.all_music_pts);
				// top_row : MusicLaneRow = mspace_for_input.all_music_lane_rows[0];
				//TODO REMINDER the world_base_start.x is at the center of the min value so we need to adjust by 0.5 the memory unit width
				//whenever we are using it. MAYBE I SHOULD MAKE A FUNCTION FOR THAT
				row_x_start : float = GetRowXStart(row, perm.all_data.global_rules.memory_unit_width);
				// mouse_play_x_float : float = world_mouse.x - row.row_world_base_start.x + 0.5*perm.all_data.global_rules.memory_unit_width;
				mouse_play_x_float : float = world_mouse.x - row_x_start;
				mouse_play_x_float /= perm.all_data.global_rules.memory_unit_width;
				mouse_memory_unit := cast(int) mouse_play_x_float;
				if mouse_memory_unit > mspace_for_input.mspace_audio_row_size {
					mouse_memory_unit = mspace_for_input.mspace_audio_row_size;
				}

				perm.all_data.set_audio_position_data.is_set = true;
				perm.all_data.set_audio_position_data.set_audio_mspace_id = perm.all_data.render_mspace_id;
				//TODO We could set this to SET_MEMORY_X_FLOAT if it is playing so we go to the precise position if needed
				perm.all_data.set_audio_position_data.set_audio_type = .SET_MEMORY_UNIT;
				perm.all_data.set_audio_position_data.memory_unit = mouse_memory_unit;

				//TODO WE COULD MAKE THIS A FUNCTION PLAY AUDIO AT X_FLOAT OR X UNITS so we can reuse
				//THIS IS SIMILAR TO set_audio_to_memory_unit BUT we can essentially just ONLY ALLOW 1 reset audio to memory unit
				//and then only add this if we dont already have a reset in the array.
				//THIS SEEMS TO be working now that we update the music pt play index with play notes at current memory
				#if 0 {
				perm.all_data.audio_mspace_id = perm.all_data.render_mspace_id;
				array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.STOP_ALL_MUSIC_PTS));
				if perm.all_data.game_audio_play.play_state == AudioPlayState.PLAY {
					array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.RESET_AUDIO_TO_MEMORY_UNIT, mouse_memory_unit));	
					//TODO Maybe we just do reset to memory unit here as well but lets try this out for a bit to see how it goes.
					// array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.SET_AUDIO_TO_X_FLOAT, x_float=mouse_play_x_float));
					array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.PLAY_NOTES_AT_CURRENT_MEMORY));
				} else {
					perm.all_data.game_audio_play.play_state = AudioPlayState.PAUSE;
					array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.RESET_AUDIO_TO_MEMORY_UNIT, mouse_memory_unit));	
				}
				}
			}
		}
		else if hover_entity.entity_type == EntityType.OP_LINEAR_ROW {
			if !top_op_space_is_chosen continue;

			row, found_row := ArrayFindFirstByNameId(perm.all_data.all_op_linear_rows,
				hover_entity.id, "id");
			assert(found_row);

			// if game_input.mouse_wheel != 0 {
			if IsMouseWheelWithoutModifiers(game_input) {
				//TODO Can adjust this rate of movement by a multiple if needed. Can store it in the row if needed.
				//Could make it adjustable by user and then also default to smallest rect height.
				rate : float = 0.5;
				row.row_cam.y += rate * game_input.mouse_wheel;
				//TODO How should we max the top out? Should it be based on frequencies or just allow the user to place it?
				row.row_cam.y = Clamp(0.0, row.row_cam.y, 9 * row.octave_height);
			}	
		}
		else if hover_entity.entity_type == EntityType.OP_SPACE {
			if top_op_space_is_chosen continue;

			op_space, found_op_space :=
				ArrayFindFirstByNameId(perm.all_data.all_open_op_spaces, hover_entity.id, "id");
			assert(found_op_space);

			op_rect_world : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size);
			op_rect_cam : Rectangle2 = WorldRectToCamRect(op_rect_world, default_base_cam);
			PushRectangleOutline(op_rect_cam, LBLUE_V, op_space.render_groups.post_render_group, order = 9, r = 2.0);

			tb_data : TitleBarData = ComputeTitleBar(op_space, default_base_cam, perm.text_editor_data);
			PushRectangle(tb_data.title_bar_cam_rect, BLACK_V, op_space.render_groups.post_render_group, order = -10000);
			PushRectangleOutline(tb_data.title_bar_cam_rect, LBLUE_V, op_space.render_groups.post_render_group, order = 15, r = 2.0);
    		PushText(tb_data.name_cam_pos, op_space.op_space_name, LBLUE_V, op_space.render_groups.post_render_group, order = 15);
    		//TODO Let's see if I prefer this to just the small rects for hovering.
    		//I think putting an x and a cross and another symbol is better and then adjusting these under them when hovered.
	    	// if IsInRectangle(mouse_cam, tb_data.title_bar_cam_rect) {
    		//TODO Update this to be an x and see the other ones as well.
		   // PushCross(GetCenter(tb_data.close_op_space_cam_rect), 0.4*GetWidth(tb_data.close_op_space_cam_rect), 0.75*GetHeight(tb_data.close_op_space_cam_rect),
		   //  	LIGHT_BROWN, op_space.render_groups.post_render_group, R=0.06, order = 15);
		   // PushCross(GetCenter(tb_data.fix_to_mspace_cam_rect), 0.4*GetWidth(tb_data.fix_to_mspace_cam_rect), 0.75*GetHeight(tb_data.close_op_space_cam_rect),
		   //  	LIGHT_BROWN, op_space.render_groups.post_render_group, R=0.06, order = 15);

   	   PushRenderX(tb_data.close_op_space_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, 
   	   	render_order = 15, width_factor=0.5);
		   small_fix_rect : Rectangle2 = RectCenterDim(GetCenter(tb_data.fix_to_mspace_cam_rect), 0.5*GetDim(tb_data.fix_to_mspace_cam_rect));
			PushRectangle(small_fix_rect, GREY_DARKERM_V, op_space.render_groups.post_render_group, order = 15);
			// PushRectangle(tb_data.close_op_space_cam_rect, 0.6*LRED_V, op_space.render_groups.post_render_group, order = 13);
			// PushRectangle(tb_data.fix_to_mspace_cam_rect, 0.6*FGREEN_V, op_space.render_groups.post_render_group, order = 13);
		   // PushCross(GetCenter(tb_data.fix_op_space_cam_rect), 0.4*GetWidth(tb_data.fix_op_space_cam_rect), 0.75*GetHeight(tb_data.close_op_space_cam_rect),
		   //  	LIGHT_BROWN, op_space.render_groups.post_render_group, R=0.06, order = 15);
	    	if IsInRectangle(mouse_cam, tb_data.close_op_space_cam_rect) {
				PushRectangle(tb_data.close_op_space_cam_rect, LRED_V, op_space.render_groups.post_render_group, order = 14);
			} else if IsInRectangle(mouse_cam, tb_data.fix_to_mspace_cam_rect) { 
				PushRectangle(tb_data.fix_to_mspace_cam_rect, GREY_DARKER_V, op_space.render_groups.post_render_group, order = 14);
			}
			// else if IsInRectangle(mouse_cam, tb_data.fix_op_space_cam_rect) { 
			// 	PushRectangle(tb_data.fix_op_space_cam_rect, LBLUE_V, op_space.render_groups.post_render_group, order = 14);
			// }
			if OpSpaceFixedToMSpace(op_space.*, perm.all_data.render_mspace_id) {
				PushRectangle(tb_data.fix_to_mspace_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 16);
			}

			// if game_input.MouseButtons[0].down_this_frame {
			if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
				//Note : we are reordering the render_groups on selection in case the selected one is not on top
				//TODO this could probably be done directly with op_space ordering eventually but for now
				//this is clearer and more direct
				//TODO Should we move this into ChooseOpSpace?
				#if USE_OLD_ALL_RENDER_GROUPS {
				found_pre_scissor_group, pre_scissor_group_index := array_find(renderer_data.all_render_groups, op_space.render_groups.pre_scissor_group);
				assert(found_pre_scissor_group);

				if pre_scissor_group_index <= renderer_data.all_render_groups.count-4
				{
					//TODO Need to pull this out when we create a new op_spae
					scissor_group_3D_index : int = pre_scissor_group_index+1;
					scissor_group_index : int = pre_scissor_group_index+2;
					post_render_group_index : int = pre_scissor_group_index+3;

					op_pre_scissor_group : *RenderGroup = renderer_data.all_render_groups[pre_scissor_group_index];
					op_scissor_group_3D : *RenderGroup = renderer_data.all_render_groups[scissor_group_3D_index];
					op_scissor_group : *RenderGroup = renderer_data.all_render_groups[scissor_group_index];
					op_post_render_group : *RenderGroup = renderer_data.all_render_groups[post_render_group_index];

					//TODO If we put this in an array then we can just go through the array and have different render_groups
					//depending on the specific op_space type.
					//TODO this can be done with 1 move once we update data models/tables when optimizing
					array_insert_at(*renderer_data.all_render_groups, op_pre_scissor_group, renderer_data.all_render_groups.count);
					array_insert_at(*renderer_data.all_render_groups, op_scissor_group_3D, renderer_data.all_render_groups.count);
					array_insert_at(*renderer_data.all_render_groups, op_scissor_group, renderer_data.all_render_groups.count);
					array_insert_at(*renderer_data.all_render_groups, op_post_render_group, renderer_data.all_render_groups.count);

					array_ordered_remove_by_index(*renderer_data.all_render_groups, post_render_group_index);
					array_ordered_remove_by_index(*renderer_data.all_render_groups, scissor_group_index);
					array_ordered_remove_by_index(*renderer_data.all_render_groups, scissor_group_3D_index);
					array_ordered_remove_by_index(*renderer_data.all_render_groups, pre_scissor_group_index);
				}
				} else {
				//TODO Put this in ChooseOpSpace once it works
				// found_osrg, osrg_index := FindOpSpaceRenderGroupsByIndex(op_space, renderer_data.open_op_space_render_groups);
				// assert(found_osrg);
				// osrg : OpSpaceRenderGroups = renderer_data.open_op_space_render_groups[osrg_index];
				// array_add(*renderer_data.open_op_space_render_groups, osrg);
				// array_ordered_remove_by_index(*renderer_data.open_op_space_render_groups, osrg_index);
				}

				ChooseOpSpace(op_space, perm.all_data, renderer_data);
			}
		}
	}
} else {
	//TODO FROM HERE maybe we just set hover_waves and then set those depending on the space we set the count
	//and add more if needed. (Can default to 10 or 100 for simplicity)
	//Then just set the cound and need to set an hover_audio_playing and if not then we set to count = 0 down here
	//Coudl do that with a compare and swap for safety but it seems fine.
	//I think worst case is that some sounds might be 10ms off change from other sounds... maybe less on mac
	//will anyone care
	//Then do updating internal control values (start with volume for osc wave) and then do synth
	#if 0 {
	#if !DSOUND_AUDIO {
	lock(*perm.locked_sound_data.audio_mutex);
	perm.locked_sound_data.hover_waves.count = 0;
	unlock(*perm.locked_sound_data.audio_mutex);
	}
	}
}

//TODO could we put this even after chosen entities? maybe not since it clears it
//TODO make this check more structured and persistent once we understand more of the generalized cases
clicked_empty_space : bool = IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) &&
   frame_hover_entities.count == 0 &&
   perm.all_data.all_chosen_entities.count > 0;
   // ArrayFindAllVarName(perm.all_data.ui_edit_linear_spaces, true, "is_connecting").count == 0;

if clicked_empty_space {
	perm.all_data.reset_to_unselected_state = true;
}
if perm.all_data.reset_to_unselected_state {
	//TODO If we were selecting a text op space then we can save the unsaved files here
	ResetToUnselectedState(perm.all_data);
}

NEW_3D :: false;
/*TODO for now we only have one chosen entity, so we loop through anyways as this deals
with the case of having no chosen enities
this will continue working later if we have multiple chosen entities

could also split all chosen entities into their own arrays by type if we are
able to select many chosen entities that may make the most sense
but not sure yet about that

how should chosen_entities interact with ui entities, do we need all the play code here
or only some of it to create music_pts (could make a music_pt adding mode when in ui mode)
*/
if perm.all_data.all_chosen_entities.count > 0 {
	quick_sort(perm.all_data.all_chosen_entities, (c1,c2) => c1.order - c2.order);
}

for chosen_entity : perm.all_data.all_chosen_entities {
if chosen_entity.entity_type == EntityType.OP_SPACE {
op_space, found_op_space :=
	ArrayFindFirstByNameId(perm.all_data.all_open_op_spaces, chosen_entity.id, "id");
assert(found_op_space);

//TODO Could do bottom and right side and maybe top right corner as well if needed.
resize_rect_world : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size);
op_bottom_right : Vector2F = GetBottomRight(resize_rect_world);
rect_bottom_right : Rectangle2 = RectBottomRightDim(op_bottom_right, Vector2F.{0.75,0.75});
cam_rect_bottom_right : Rectangle2 = WorldRectToCamRect(rect_bottom_right, default_base_cam);
if IsInRectangle(mouse_cam, cam_rect_bottom_right) {
	PushRectangle(cam_rect_bottom_right, LBLUE_V, op_space.render_groups.post_render_group, order = 15);
	if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
		resize_op_space : ResizeOpSpace = ---;
		resize_op_space.op_space_id = op_space.id;
		resize_op_space.resize_type = ResizeType.BOTTOM_RIGHT;
		array_add(*perm.all_data.all_resizing_op_space, resize_op_space);
	}
}

//TODO Should we just put this in the op_space? I guess this let's use resize multiple things at once...
//but we can still do that by just adjusting each op_space
resize_op_space, is_resizing_op_space := ArrayFindFirstByNameId(perm.all_data.all_resizing_op_space, 
	op_space.id, "op_space_id");
if is_resizing_op_space {
	if resize_op_space.resize_type == {
	case ResizeType.BOTTOM_RIGHT;
		resize_rect_world.max.x += mouse_delta.x;
		resize_rect_world.min.y += mouse_delta.y;
	}

	//TODO We could have a different criteria eventually if needed.
	check_size : Vector2F = GetDim(resize_rect_world);
	if check_size.x >= OP_SPACE_MIN_SIZE.x && check_size.y >= OP_SPACE_MIN_SIZE.y {
		//TODO Could pull this out and reuse a function for both tests and terminal resize op space events later.
		op_space.world_offset = GetCenter(resize_rect_world);
		op_space.world_size = GetDim(resize_rect_world);
	}

	//TODO We update specific op_spaces below but maybe we coudl do it here.
	//eg text_op_space requires updating lines bounds.
	//Then we would have to fetch the data updated twice so we do it down there for now.

	// if game_input.MouseButtons[0].up_this_frame {
	if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) {
		removed := ArrayRemoveFirstByNameId(*perm.all_data.all_resizing_op_space, op_space.id, "op_space_id");
		assert(removed); //sanity check
	}
}

if op_space.op_space_external_type == OpSpaceExternalType.txt {
	text_op, found_text_op := ArrayFindFirstByNameId(perm.all_data.all_text_op_space_data, 
		op_space.id, "op_space_id");
	assert(found_text_op);

	//TODO Should rename this to edit_text_file and pull a const in case we add a new file
	/*DOC : This is now a const but we need to remember that if we update the tab file
	then if we need to use this again, we have to update the text_file. This is not happening
	and should not happen in the futrue since changing tab should happen once in a frame.
	Otherwise we would need to update this everytime change a tab so we would have to make a
	function for that and then fetch the new text file and set this
	*/
 	text_file, found_text_file := ArrayFindFirstByNameId(perm.all_data.all_text_files,
		text_op.file_tabs[text_op.ftab_i].text_file_id, "id");
	assert(found_text_file);

	//TODO I think this should be else with resizing so that we don't have accidental mouse input while resizing
	//TODO FROM HERE We could generalize this into AllData so if we are holding anywhere then we set this so we can't somehow
	//do something else while the mouse is holding and then we can also set that in IsMouseSpecificHolding
	//every frame and then reset it at the top every frame so we have a generalized mouse holding block
	//We could also have both
	is_text_op_mouse_input : bool = false;
	//TODO We could do resizing above but we do here instead so we don't have to fetch data again.
	if is_resizing_op_space {
		//TODO Should we just us base_render_group? We update pixels_per_square everywhere on zoom anyways...
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);
		// text_file.file_string.file_loc.count, text_op.text_comp_data.disassembly_loc.count);
		is_text_op_mouse_input = true;
	}

	//TODO Should we just recompute this when changing font size anyways?
	// top : TextOpPositions = ComputeTextOpPositions(text_op.ator, op_space, text_op, perm.text_editor_data);
	// top : TextOpPositions = text_op.ator.top;
	//TODO We could compute cam rect here and then check mouse cam
	op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);
	tab_cursor : *TextCursor = *text_op.file_tabs[text_op.ftab_i].tab_cursor;


	//TODO could somehow generalize these so we don't have so much duplicate code but maybe not since it's different enough
	/*DOC : Min and max proportions here to reuse everywhere we do a split.
	This is the code for adjusting the proportios of the split rects in the text op space.
	There is some repetition but it is different enough that I will just leave it like this.
	In general, the mouse_pressing check afterwards should be occuring regardless of where the mouse is
	since we don't check if we are in a rectangle and should undo on an mouse up_this_frame even
	in cases i did not think about where the mouse_pressing is still true for some reason.
	mouse_hovering, is always set to false so we only register it for rendering when we are actualy in the rect.
	*/
	//NOTE : Put this in global scope on top of TextOpSpaceData
	// TEXT_SPLIT_MIN : float : 0.05;
	// TEXT_SPLIT_MAX : float : 1.0 - TEXT_SPLIT_MIN;
	text_op.mouse_hovering_split_rect = false;
	if IsInRectangle(op_mouse, text_op.ator.split_rect) 
		&& text_op.exec_info.exec_mode == ExecutionMode.DEBUG
		&& !is_text_op_mouse_input 
	{
		//TODO Use this to prevent highlighting or not. Does not really affect functionality anyways but maybe makes more sense one way or another
		if !IsInputDown(.MOUSE_BUTTON_LEFT, game_input) {
			text_op.mouse_hovering_split_rect = true;
		}
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
			text_op.mouse_pressing_split_rect = true;
		}
	}
	if text_op.mouse_pressing_split_rect {
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) {
			text_op.mouse_pressing_split_rect = false;
		} else {
			is_text_op_mouse_input = true;
			left_proportion : float = (op_mouse.x - text_op.ator.op_rect.min.x) / op_space.world_size.x;
			left_proportion = Clamp(TEXT_SPLIT_MIN, left_proportion, TEXT_SPLIT_MAX);
			// if left_proportion >= TEXT_SPLIT_MIN && left_proportion <= TEXT_SPLIT_MAX {
				// text_op.left_proportion = left_proportion;
				text_op.set_left_proportion = left_proportion;
				// text_op.l_bottom_left_proportion = left_proportion;
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			// }
		}
	}

	text_op.mouse_hovering_l_bottom_split_rect = false;
	if IsInRectangle(op_mouse, text_op.ator.l_bottom_split_rect) 
		&& text_op.l_bottom_pane_type != .NONE
		&& !is_text_op_mouse_input 
	{
		if !IsInputDown(.MOUSE_BUTTON_LEFT, game_input) {
			text_op.mouse_hovering_l_bottom_split_rect = true;
		}
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
			text_op.mouse_pressing_l_bottom_split_rect = true;
		}	
	}
	if text_op.mouse_pressing_l_bottom_split_rect {
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) {
			text_op.mouse_pressing_l_bottom_split_rect = false;
		} else {
			is_text_op_mouse_input = true;
			bottom_proportion : float = (op_mouse.y - text_op.ator.op_rect.min.y) / op_space.world_size.y;
			bottom_proportion = Clamp(TEXT_SPLIT_MIN, bottom_proportion, TEXT_SPLIT_MAX);
			// if bottom_proportion >= TEXT_SPLIT_MIN && bottom_proportion <= TEXT_SPLIT_MAX {
				text_op.set_bottom_proportion = bottom_proportion;
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			// }
		}
	}

	text_op.mouse_hovering_r_bottom_split_rect = false;
	if IsInRectangle(op_mouse, text_op.ator.r_bottom_split_rect) 
		&& text_op.r_bottom_pane_type != .NONE
		&& !is_text_op_mouse_input 
	{
		if !IsInputDown(.MOUSE_BUTTON_LEFT, game_input) {
			text_op.mouse_hovering_r_bottom_split_rect = true;
		}
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
			text_op.mouse_pressing_r_bottom_split_rect = true;
		}	
	}
	if text_op.mouse_pressing_r_bottom_split_rect {
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) {
			text_op.mouse_pressing_r_bottom_split_rect = false;
		} else {
			is_text_op_mouse_input = true;
			r_bottom_height_proportion : float = (op_mouse.y - text_op.ator.op_rect.min.y) / op_space.world_size.y;
			r_bottom_height_proportion = Clamp(TEXT_SPLIT_MIN, r_bottom_height_proportion, TEXT_SPLIT_MAX);
			// if r_bottom_height_proportion >= TEXT_SPLIT_MIN && r_bottom_height_proportion <= TEXT_SPLIT_MAX {
				text_op.set_r_bottom_height_proportion = r_bottom_height_proportion;
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			// }
		}
	}

	text_op.mouse_hovering_name_value_split_rect = false;
	if IsInRectangle(op_mouse, text_op.ator.name_value_split_rect) 
		&& text_op.exec_info.exec_mode == ExecutionMode.DEBUG
		&& !is_text_op_mouse_input 
	{
		if !IsInputDown(.MOUSE_BUTTON_LEFT, game_input) {
			text_op.mouse_hovering_name_value_split_rect = true;
		}
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
			text_op.mouse_pressing_name_value_split_rect = true;
		}	
	}
	if text_op.mouse_pressing_name_value_split_rect {
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) {
			text_op.mouse_pressing_name_value_split_rect = false;
		} else {
			is_text_op_mouse_input = true;
			right_rect_width : float = GetWidth(text_op.ator.right_rect);
			new_proportion : float = (op_mouse.x - text_op.ator.right_rect.min.x) / right_rect_width;
			new_proportion = Clamp(TEXT_SPLIT_MIN, new_proportion, 1.0 - text_op.type_proportion - TEXT_SPLIT_MIN);
			// if new_proportion >= TEXT_SPLIT_MIN && new_proportion <= 1.0 - text_op.type_proportion - TEXT_SPLIT_MIN {
				text_op.name_proportion = new_proportion;
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			// }
		}
	}

	text_op.mouse_hovering_value_type_split_rect = false;
	if IsInRectangle(op_mouse, text_op.ator.value_type_split_rect) 
		&& text_op.exec_info.exec_mode == ExecutionMode.DEBUG
		&& !is_text_op_mouse_input 
	{
		if !IsInputDown(.MOUSE_BUTTON_LEFT, game_input) {
			text_op.mouse_hovering_value_type_split_rect = true;
		}
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
			text_op.mouse_pressing_value_type_split_rect = true;
		}	
	}
	if text_op.mouse_pressing_value_type_split_rect {
		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) {
			text_op.mouse_pressing_value_type_split_rect = false;
		} else {
			is_text_op_mouse_input = true;
			right_rect_width : float = GetWidth(text_op.ator.right_rect);
			new_proportion : float = (op_mouse.x - text_op.ator.watch_name_rect.max.x) / right_rect_width;
			new_proportion = Clamp(TEXT_SPLIT_MIN, new_proportion, 1.0 - text_op.name_proportion - TEXT_SPLIT_MIN);
			// if new_proportion >= TEXT_SPLIT_MIN && new_proportion <= 1.0 - text_op.name_proportion - TEXT_SPLIT_MIN {
				text_op.type_proportion = 1.0 - text_op.name_proportion - new_proportion;
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			// }
		}
	}

	//TODO Reusing the new functions, but I'll leave the old code on the bottom in case we want to change it at some point
	//since this is text editor and could eventually be different from the text split line mouse code
	#if 1 {
	mouse_y_diff : float = MouseYDiff(text_op.ator.LOC_START_Y, op_mouse.y, text_op.ator.cursor_height);
	mouse_line_number : int = MouseLineNumber(mouse_y_diff, text_op.ator.TEXT_LINE_HEIGHT, 
		tab_cursor.start_file_line_index, text_file.file_loc.count);
	} else {
	// mouse_y_diff : float = text_op.ator.LOC_START_Y - op_mouse.y - text_op.ator.y_cursor_adjust;
	mouse_y_diff : float = text_op.ator.LOC_START_Y - op_mouse.y - YAdjustCursorHeight(text_op.ator.cursor_height);
	mouse_line_diff_float : float = mouse_y_diff / text_op.ator.TEXT_LINE_HEIGHT;
	mouse_line_diff_int : int = round_to_int(mouse_line_diff_float);
	mouse_line_number : int = mouse_line_diff_int + tab_cursor.start_file_line_index;
	if mouse_line_number < 0 {
		mouse_line_number = 0;
	} else if mouse_line_number >= text_file.file_loc.count {
		mouse_line_number = text_file.file_loc.count-1;
	}
	}
	//TODO Should this be in here or should this be separate and not affect the text editing rect
	mouse_line_string : string;
	if text_file.file_loc.count > 0 {
		mouse_line_string = text_file.file_loc[mouse_line_number];
	}
	// if IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) {
	// 	print("test\n");
	// }
	// print("op_mouse=%, LOC_START_X=%\n", op_mouse, LOC_START_X);
	//TODO FROM HERE implement tab first or pull out common functionality for mouse and make sure 
	//that input cannot be sequentially wrong. Better to miss an input than to have invalid state
	//TODO ACTUALLY THIS NEEDS TO BE CHECKED BASED ON CHARS IN INCLUDE TABS WITH DIFFERENT CHAR COUNT

	//TODO FROM HERE get this working with tabs
	//ALSO FOR mouse HOLDING selecting WE HAVE TO CHECK THAT IT IS DOWN THIS FRAME BUT NOT DOWN THIS FRAME
	//since if we have click and then click right after it counts that as a selection
	// mouse_char_float_x_diff : float = op_mouse_x_diff / perm.text_editor_data.code_font_1_char_width_world;
	/*DOC : Eventually if we reuse this, then we can pull it out in separate functional chunks and test each one separately
	*/
	//NOTE : that x_diff refers to the op/world x size
	op_mouse_x_diff : float = (op_mouse.x - text_op.ator.LOC_START_X);
	#if 1 {
	// tab_char_count_world : float = TAB_CHAR_COUNT * perm.text_editor_data.code_font_1_char_width_world;
	// char_count_with_tab : int = CharCountUntilCursorWithTab(tab_cursor.left_char_bound, mouse_line_number, text_file.file_string);
	// print("left_char_bound=%\n", tab_cursor.left_char_bound);
	// before_mouse_x_diff : float = tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;
	// op_mouse_x_diff += before_mouse_x_diff;
	char_check : int = 0;
	mouse_line_char : int = 0;
	left_char : int = 0;
	//TODO FROM HERE need to add case where op_mouse_x_diff < 0 so we can highlight on other side bounded
	//shoudl we check to make sure that the left_char_bound is always in line with an actual char?
	//TODO Can optimize this with find_index_from_left for tab and just add + 1 for each character till then and then add tab
	//Note that if left_char = left_char_bound eg left_char = 0 then this won't compute at all
	while left_char < tab_cursor.left_char_bound && char_check < mouse_line_string.count {
		left_char += GetCharCount(mouse_line_string[char_check]);
		char_check += 1;
	}
	before_mouse_x_diff : float = 0;
	if left_char > tab_cursor.left_char_bound {
		//DOC : We adjust in case we are in a multi-char character to account for the offset on the left hand side.
		//eg if we have a tab on left hand side, we could be in the middle ie left_char=15 and left_char_bound = 14
		//so this would adjust for that so the mouse clicks are correct when the left_char_bound > 0
		left_char_offset : int = left_char - tab_cursor.left_char_bound;
		left_char_x_diff : float = left_char_offset * perm.text_editor_data.code_font_1_char_width_world;
		before_mouse_x_diff += left_char_x_diff;
	}
	// if mouse_line_string.count > 0 && char_check > 0 && char_check < mouse_line_string.count {
	// 	c := string.{1, *mouse_line_string[char_check]};
	// 	print("char=%\n", c);
	// }
	// print("left_char=%\n, left_char_bound=%\n", left_char, tab_cursor.left_char_bound);
	// if mouse_line_string.count > 0 && char_check < mouse_line_string.count {
	// 	left_char_length : int = GetCharCount(mouse_line_string[char_check]);
		// if left_char_length != 1 && char_check > 0 {
		// 	char_check -= 2;
		// }
		// x_diff_remainder : float = op_mouse_x_diff - before_mouse_x_diff;
		// if x_diff_remainder < 0.5 * left_char_length {
		// 	mouse_line_char = char_check;
		// } else {
		// 	mouse_line_char = char_check + 1;
		// }
	// }
	if op_mouse_x_diff < 0 {
		/*DOC : Keeping these cases separate since they're different enough and may be confusing later to 
		update if I pull things out and just adjust values. So will leave as separate.
		Single line should be different since single line does not allow tabs at all
		NOTE We check <= mouse_line_string.count so even if we are at the end of the line, then the char_check-1 
		so we always get the previous char even if we are at the end of the line
		*/
		// if tab_cursor.left_char_bound > 0 {
		// after_mouse_x_diff : float = 0;
		while char_check > 0 && char_check <= mouse_line_string.count {
			char_op_length : float = GetCharCount(mouse_line_string[char_check-1]) * perm.text_editor_data.code_font_1_char_width_world;
			next_char_x_diff : float = before_mouse_x_diff - char_op_length;
			if next_char_x_diff < op_mouse_x_diff {
				break;
			}
			before_mouse_x_diff -= char_op_length;
			char_check -= 1;
		}
		if char_check > 0 && char_check < mouse_line_string.count {
			//DOC : We check the previous char since the before_mouse_x_diff is at char_check and op_mouse_x_diff < before_mouse_x_diff
			//so we want the different before the current char check which is the opposite of the positive case
			char_op_length : float = GetCharCount(mouse_line_string[char_check-1]) * perm.text_editor_data.code_font_1_char_width_world;
			x_diff_remainder : float = before_mouse_x_diff - op_mouse_x_diff;
			//DOC : before_mouse_x_diff > op_mouse_x_diff so if < 0.5, then we are closer to the before_mouse_x_diff == char_check char
			//and if >= 0.5 then we are closer to the char_check - 1 which is the oppposite direction of the bottom
			/*   op   after_mouse(before_mouse)
			     |    |
				(char0)(char1)

				so after_mouse(before_mouse) > op and so after_mouse(before_mouse) - op > 0

				whereas on the bottom case we have so op - before_mouse > 0 because op > before_mouse
				before_mouse    op
				|                |
				(char0)       (cahr1)
			*/
			if x_diff_remainder < 0.5 * char_op_length {
				// print("< 0.5\n");
				mouse_line_char = char_check;
			} else {
				// print("< 0.5\n");
				mouse_line_char = char_check - 1;
			}
			// if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) print("x_diff_remainder=%\n", x_diff_remainder);
		} else {
			mouse_line_char = Clamp(0, char_check, mouse_line_string.count);
		}
		// mouse_line_char += tab_cursor.left_char_bound;
		// mouse_line_char = Clamp(0, mouse_line_char, mouse_line_string.count);
		// print("mouse_line_char=%\n", mouse_line_char);
		// print("before_mouse_x_diff=%\n, op_mouse_x_diff=%\n", before_mouse_x_diff, op_mouse_x_diff);
		// }
	} else {
		//We compute which char we are at since tabs can have different char lengths than regular chars
		//TODO Could make this a function OpPosToCharPoint
		//TODO Can optimize this with find_index_from_left to search for tabs
		while char_check >= 0 && char_check < mouse_line_string.count {
			char_op_length : float = GetCharCount(mouse_line_string[char_check]) * perm.text_editor_data.code_font_1_char_width_world;
			next_char_x_diff : float = before_mouse_x_diff + char_op_length;
			if next_char_x_diff > op_mouse_x_diff {
				break;
			}
			before_mouse_x_diff += char_op_length;
			char_check += 1;
		}
		if char_check >= 0 && char_check < mouse_line_string.count {
			char_op_length : float = GetCharCount(mouse_line_string[char_check]) * perm.text_editor_data.code_font_1_char_width_world;
			x_diff_remainder : float = op_mouse_x_diff - before_mouse_x_diff;
			if x_diff_remainder < 0.5 * char_op_length {
				mouse_line_char = char_check;
			} else {
				mouse_line_char = char_check + 1;
			}
			// if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) print("x_diff_remainder=%\n", x_diff_remainder);
		} else {
			mouse_line_char = Clamp(0, char_check, mouse_line_string.count);
		}
		// mouse_line_char += tab_cursor.left_char_bound;
		// mouse_line_char = Clamp(0, mouse_line_char, mouse_line_string.count);
		// if mouse_line_string.count > 0 && mouse_line_char < mouse_line_string.count {
		// 	c := string.{1, *mouse_line_string[mouse_line_char]};
		// 	print("char=%\n", c);
		// }
	}
	// if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
		// print("mouse_line_char=%\n", mouse_line_char);
	// }
	//TODO mouse line char for testing if it is correct out of bounds, we can remove this if it gets in the way
	//ALSO If ever we pull out the mouse line char code then this would not be necessary
	//BUT since this is the only place that we use mouse line char with tabs for now, then I won't pull it out
	perm.test_data.test_mouse_line_char = mouse_line_char;
	} else {
	before_mouse_x_diff : float = op_mouse_x_diff / perm.text_editor_data.code_font_1_char_width_world;
	mouse_line_char : int = round_to_int(before_mouse_x_diff);
	// mouse_line_char : int = round_to_int(before_mouse_x_diff / perm.text_editor_data.code_font_1_char_width_world);
	if mouse_line_char < 0 {
		mouse_line_char = 0;
	} else if mouse_line_char > mouse_line_string.count {
		mouse_line_char = mouse_line_string.count;
	}
	}
	mouse_line_start_char_point : int = StartCharPointOfLineNumber(mouse_line_number, text_file.file_string);
	mouse_char_point : int = mouse_line_start_char_point + mouse_line_char;


	first_bar_mouse_char_point : int; 
	if text_op.text_first_bar_type != .NONE {
		first_bar_mouse_char_point = MouseSingleLineCharPoint(op_mouse, 
			text_op.ator.first_bar_input_text_pos.x, text_op.first_bar_input_text.text_string,
			text_op.first_bar_cursor, perm.text_editor_data.code_font_1_char_width_world);
	}
	second_bar_mouse_char_point : int;
	if text_op.text_second_bar_type != .NONE {
		second_bar_mouse_char_point = MouseSingleLineCharPoint(op_mouse, 
			text_op.ator.second_bar_input_text_pos.x, text_op.second_bar_input_text.text_string,
			text_op.second_bar_cursor, perm.text_editor_data.code_font_1_char_width_world);
	}
	file_tab_op_rects : [] Rectangle2;
	if text_op.text_top_bar_type == TextTopBarType.TEXT_FILE_TABS {
		file_tab_op_rects = CreateFileTabOpRects(text_op);
	}
	//Always want to reset these so we only set them when they are actually hovering.
	text_op.mouse_hovering_top_bar = false;
	text_op.mouse_hovering_tab_i = -1;
	if IsInRectangle(op_mouse, text_op.ator.l_top_rect) && !is_text_op_mouse_input {
		/*DOC : The margin is only available in debug mode.
		If we are not in debug mode, then the text editor is the whole l_top_rect so I think this
		way is good because if we are not in the margin and in debug mode we are still only in the text rect
		but if we are not in debug mode, then the we are still in the text rect in the second case.

		THE RENDER ORDER Of the top bar left_top_bar_order > left_bottom_bar_order so we need to check that first for
		input in case they are overlapping.
		*/
		if text_op.text_top_bar_type == TextTopBarType.TEXT_FILE_TABS &&
			IsInRectangle(op_mouse, text_op.ator.top_bar_rect)
		{
			//TODO FROM HERE test the file tabs with shortcuts and mouse input
			//Should we do move file tabs with mouse first or just leave it as a shortcut which I think I prefer?
			//DONT FORGET to test that the bars overlap probably on rendering and input in the edge case that
			//we bring the text rect all the way up to the top.

			text_op.mouse_hovering_top_bar = true;

			cam_add_tab_rect := OpRectToCamRect(text_op.ator.add_file_tab_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			if IsInRectangle(mouse_cam, cam_add_tab_rect) {
				//TODO We could do hovering add_tab_rect in here if that helps. We just check if in rectangle right
				//now for changing the rendering color.
				if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
					ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
					open_text_file, found_open_file := 
						OpenFileTabWithExplorer(text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
					if found_open_file {
						//We set the text file here since we opened a new text_file and that could have changed the array memory pointer
						text_file = open_text_file;
					}
					is_text_op_mouse_input = true;
				}
			} 
			else {
				for tab, tab_index : file_tab_op_rects {
					tab_rect : Rectangle2 = file_tab_op_rects[tab_index];
					if IsInRectangle(mouse_cam, tab_rect) {
						text_op.mouse_hovering_tab_i = tab_index;
						close_tab_rect : Rectangle2 = GetFileTabXRect(tab_rect, perm.text_editor_data.code_font_1_char_width_world);
						//DOC : We only allow file tabs to be closed if we have more than 1 of them. We do this here and to render the tab x rect.
						if text_op.file_tabs.count > 1 &&
							IsInRectangle(mouse_cam, close_tab_rect) && 
							IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input)
						{
							is_text_op_mouse_input = true;
							CloseFileTab(tab_index, text_op, perm.all_data);
							if tab_index <= text_op.ftab_i {
								//We don't need to clamp here because file_tabs.count > 0 so if we are at 0 then we won't come in here
								new_tab : int = Clamp(0, text_op.ftab_i - 1, text_op.file_tabs.count-1);
								text_file = ChangeTextTab(new_tab, text_op, perm.all_data.all_text_files);
								#if 0 {
								text_op.ftab_i -= 1;
								//Update the text_file here since we changed it
								text_file = GetTabTextFile(text_op, perm.all_data.all_text_files);
								}
							}
						}
						else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
							if tab_index != text_op.ftab_i {
								ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
								//Update the text_file here since we changed it
								text_file = ChangeTextTab(tab_index, text_op, perm.all_data.all_text_files);
								// text_op.ftab_i = tab_index;
								// text_file = GetTabTextFile(text_op, perm.all_data.all_text_files);
							}

							text_op.mouse_holding_ftab = true;
							is_text_op_mouse_input = true;
						}
						break;
					}
				}
			}
		}
		else if text_op.text_first_bar_type != .NONE &&
			IsInRectangle(op_mouse, text_op.ator.first_bar_text_rect) &&
			IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input)
		{
			text_op.selected_text_bar = SelectedTextBarType.SELECTED_FIRST_BAR;
			text_op.first_bar_cursor.cursor_is_selecting = false;
			text_op.first_bar_cursor.char_point = first_bar_mouse_char_point;
			// text_op.first_bar_cursor.cursor_line_char = first_bar_mouse_char_point;
			text_op.first_bar_cursor.cursor_left_mouse_holding = true;
			is_text_op_mouse_input = true;
			//TODO Do we need this here in case for edge cases where we might move the right and left char bound?
			UpdateCursorLineCharAndBounds(*text_op.first_bar_cursor, text_op.first_bar_input_text, single_line=true);
		}
		else if text_op.text_second_bar_type != .NONE &&
			IsInRectangle(op_mouse, text_op.ator.second_bar_text_rect) &&
			IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input)
		{
			text_op.selected_text_bar = SelectedTextBarType.SELECTED_SECOND_BAR;
			text_op.second_bar_cursor.cursor_is_selecting = false;
			text_op.second_bar_cursor.char_point = second_bar_mouse_char_point;
			// text_op.second_bar_cursor.cursor_line_char = second_bar_mouse_char_point;
			text_op.second_bar_cursor.cursor_left_mouse_holding = true;
			is_text_op_mouse_input = true;
			//TODO Do we need this here in case for edge cases where we might move the right and left char bound?
			UpdateCursorLineCharAndBounds(*text_op.second_bar_cursor, text_op.second_bar_input_text, single_line=true);
		}
		//DOC : I separated margin rect from text rect. I think it makes more sense this way, but let's see
		//how it feels as we go along. This way the behavior of the margin can be specifically coded in here
		//AND also then text rect is not confused as to whether it contains the margin or not.
		//The only downside is that we have this duplicate code, but this way we can also adjust that specifically if needed.
		else if text_op.exec_info.exec_mode == ExecutionMode.DEBUG &&
			IsInRectangle(op_mouse, text_op.ator.left_margin_rect)
		{
			// if game_input.mouse_wheel != 0 {
			if IsMouseWheelWithoutModifiers(game_input) {
				is_text_op_mouse_input = true;
				MouseScrollTextBounds(*tab_cursor.start_file_line_index, *tab_cursor.end_file_line_index,
					text_file.file_loc.count, game_input.mouse_wheel);
			}
			else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
				is_text_op_mouse_input = true;
				ChangeTextPane(.TEXT, text_op, perm.all_data);
				PressCodeBreakpoint(mouse_line_number, text_op, text_op.text_comp_data);
			} 
		}
		else if IsInRectangle(op_mouse, text_op.ator.l_text_rect) {
			// if game_input.mouse_wheel != 0 {
			if IsMouseWheelWithoutModifiers(game_input) {
				is_text_op_mouse_input = true;
				MouseScrollTextBounds(*tab_cursor.start_file_line_index, *tab_cursor.end_file_line_index,
					text_file.file_loc.count, game_input.mouse_wheel);
			}
			//we are in the text rect since we are not in the margin and not scrolling
			else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
				is_text_op_mouse_input = true;
				//TODO Need to make a function ChangeTextPane
				ChangeTextPane(.TEXT, text_op, perm.all_data);
				// print("mouse_y_diff=%, mouse_line_diff_float=%, mouse_y_int=%, mouse_line_number=%\n", 
				// 	mouse_y_diff, mouse_line_diff_float, mouse_line_diff_int, mouse_line_number);
				// print("char=\"%\",char_pos=%\n", loc[char_pos_int], char_pos);
				tab_cursor.cursor_is_selecting = false;
				tab_cursor.char_point = mouse_char_point;
				tab_cursor.cursor_line_number = mouse_line_number;
				//TODO Leaving here for testing can remove once were done
				// print("tab_cursor.char_point=%\n", tab_cursor.char_point);
				// print("mouse_line_number=%\n", mouse_line_number);
				//TODO If we move this into UpdateFileStringAtCursor then we can compute it there OR NOT if we dont.
				// tab_cursor.cursor_line_char = mouse_line_char;
				tab_cursor.cursor_left_mouse_holding = true;

				//DOC : In case we press on a tab char at the beginning or end of a line OR a half line on top or bottom
				//then we will adjust the bounds so we can see it.
				//TODO We could update cursor_line_char in here based on char point if that helps keep things consistent.
				UpdateCursorLineCharAndBounds(tab_cursor, text_file.file_string);
			}
		}
	}
	//TODO Do we actually want to block input here or not because 
	//if we do block then it prevents accidental keyboard clicks while mouse holding
	//if we dont block then we can press a button while holding and it will undo the hold and we'd have to set 
	//		cursor_left_mouse_holding to false with the keyboard input as well.
	//TODO We should reset cursor_lefT_mouse_holding if we click off the text op space to make sure we still get the update
	//TODO MAYBE We should do this with events instead since we will also likelye have to scroll
	//ACTUALLY maybe not since it wont move around if we click off the text op space
	//NOTE : REMEMBER this needs to be set here outside the rectangle bounds since we need to check it even if the mouse is 
	//out but also to properly reset it once we come back in on an up_this_frame mouse click
	is_holding_mouse_on_text : bool = CheckCursorMouseHolding(mouse_char_point, mouse_line_number, tab_cursor, text_file.file_string, game_input);
	if is_holding_mouse_on_text is_text_op_mouse_input = true;

	//Check the mouse bars holding here if they are open
	//TODO Can remove these ifs since we check it in CheckCursorMouseHolding anyways
	//and this way allows us to press of if ever the mouse hold gets stuck for some unknown reason
	// if text_op.first_bar_cursor.cursor_left_mouse_holding {
		CheckCursorMouseHolding(first_bar_mouse_char_point, 0, *text_op.first_bar_cursor, text_op.first_bar_input_text, game_input, single_line=true);
		//Need to check if this is true because otherwise we will set is_text_op_mouse_input to false and then run the code below here anyways
		if text_op.first_bar_cursor.cursor_left_mouse_holding is_text_op_mouse_input = true;
	// }
	// if text_op.second_bar_cursor.cursor_left_mouse_holding {
		CheckCursorMouseHolding(second_bar_mouse_char_point, 0, *text_op.second_bar_cursor, text_op.second_bar_input_text, game_input, single_line=true);
		//Need to check if this is true because otherwise we will set is_text_op_mouse_input to false and then run the code below here anyways
		if text_op.second_bar_cursor.cursor_left_mouse_holding is_text_op_mouse_input = true;
	// }
	//TODO FROM HERE Remove this commented code once we test everything
	// print("is_text_op_mouse_input=%\n", is_text_op_mouse_input);
	//Actually not having this is better since we well unclick the mouse 
	// if text_op.mouse_holding_ftab {
	//TODO We can make this into a function to check if its down for mouse holding
	//because we want to make sure it's down but not just pressed
	//Something like MouseIsHoldingAndPressedLastFrame for these three things
	//and then maybe another function
	// if text_op.mouse_holding_ftab &&
	// 	IsInputDown(.MOUSE_BUTTON_LEFT, game_input) &&
	// 	!IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input)
	/*DOC : We could make this a function but I think just having this if with the mouse holding code
	and then the 2 ifs on the bottom is ok to copy over since generally we 
	*/
	if IsMouseSpecificHolding(text_op.mouse_holding_ftab, game_input) {
		op_ftab_center : Vector2F = GetCenter(file_tab_op_rects[text_op.ftab_i]);
		tab_width : float = GetWidth(file_tab_op_rects[text_op.ftab_i]);
		//NOTE : op_mouse_delta and op_mouse_tab_diff will be positive for right tab move and negative for left tab move
		op_mouse_delta : float = op_mouse.x - op_ftab_center.x;
		op_mouse_tab_diff := cast(int) (op_mouse_delta / tab_width);
		if op_mouse_tab_diff != 0 {
			swap_tab_i : int = text_op.ftab_i + op_mouse_tab_diff;
			if swap_tab_i >= 0 && swap_tab_i < text_op.file_tabs.count {
				move_tab : TextTab = text_op.file_tabs[text_op.ftab_i];
				array_ordered_remove_by_index(*text_op.file_tabs, text_op.ftab_i);
				array_insert_at(*text_op.file_tabs, move_tab, swap_tab_i);
				text_op.ftab_i = swap_tab_i;
			}
		}
	}
	//TODO Could also check !IsInputDown here i guess if we miss the event but
	//this way catches if we have a down and up on the same frame
	//Could make a function IsMouseSpecificHoldingOff
	// if text_op.mouse_holding_ftab && IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) {
	MouseOffSpecificHold(*text_op.mouse_holding_ftab, game_input);
	// }
	if text_op.mouse_holding_ftab is_text_op_mouse_input = true;

	//TODO Not sure if checking !is_text_op_mouse_input here is necessary but just in case we already clicked above
	//Since we can't have 2 different mouse clicks on the same frame anyways
	if text_op.exec_info.exec_mode == ExecutionMode.DEBUG {
		watch_mouse_char_point : int = MouseSingleLineCharPoint(op_mouse, 
			text_op.ator.right_rect.min.x, text_op.edit_watch_name.text_string,
			text_op.watch_cursor, perm.text_editor_data.code_font_1_char_width_world);
		if IsInRectangle(op_mouse, text_op.ator.r_top_rect) && !is_text_op_mouse_input {
			// print("click_count=%\n", game_input.all_mouse_click_counts[0]);
			// print("mouse_float_y_diff=%, mouse_int_y_diff=%, mouse_watch_index=%\n", 
			// 	mouse_float_y_diff_from_row_center, mouse_int_y_diff, mouse_watch_index);
			mouse_float_y_diff_from_row_center : float = ((text_op.ator.LOC_START_Y - op_mouse.y) / text_op.ator.TEXT_LINE_HEIGHT);
			mouse_int_y_diff : int = round_to_int(mouse_float_y_diff_from_row_center);
			mouse_watch_index : int = mouse_int_y_diff + text_op.start_watch_index;
			watch_data : WatchData = text_op.watch_data_rows[text_op.highlighted_name_index];
			//TODO Could use an else if for mouse_wheel so we avoid moving and then clicking on the wrong thing on same frame
			// if game_input.mouse_wheel != 0 {
			if IsMouseWheelWithoutModifiers(game_input) {
				is_text_op_mouse_input = true;
				MouseScrollTextBounds(*text_op.start_watch_index, *text_op.end_watch_index,
					text_op.watch_data_rows.count, game_input.mouse_wheel);
			}
			else if text_op.highlighted_name_index == mouse_watch_index && text_op.is_watch_editing &&
				IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input)
			{
				text_op.watch_cursor.cursor_is_selecting = false;
				text_op.watch_cursor.char_point = watch_mouse_char_point;
				// text_op.watch_cursor.cursor_line_char = watch_mouse_char_point;
				text_op.watch_cursor.cursor_left_mouse_holding = true;
				is_text_op_mouse_input = true;
				//TODO Do we need this here in case for edge cases where we might move the right and left char bound?
				UpdateCursorLineCharAndBounds(*text_op.watch_cursor, text_op.edit_watch_name, single_line=true);
			}
			//TODO Use this case to dropdown when we click on value if its a dropdown which we can do after moving above
			else if text_op.exec_info.exec_state == ExecutionState.IS_DEBUG_STOP &&
				IsInRectangle(op_mouse, text_op.ator.watch_value_rect) &&
				mouse_watch_index >= 0 && mouse_watch_index < text_op.watch_data_rows.count &&
				IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input)
			{
				ChangeTextPane(.WATCH, text_op, perm.all_data);
				text_op.highlighted_name_index = mouse_watch_index;
				DropWatchRow(text_op.highlighted_name_index, text_op, perm.all_data);
			}
			//TODO Maybe we remove the double click here in favor a shortcut for editing watch row
			//As i dont really like the feel of double clicking in general
			//TODO I can make this work with ctrl+click if needed but I found the double click annoying to test and use
			//maybe we can use it better if we add platform specific double click input data to input module
			// else if IsInRectangle(op_mouse, text_op.ator.watch_name_rect) &&
			// 	IsMouseClickCount(2, game_input.all_mouse_click_counts[0], game_input) &&
			// 	mouse_watch_index == text_op.highlighted_name_index &&
			// 	watch_data.watch_indent == 0
			// {
			// 	DebugWatchEditNameMode(watch_data, text_op);
			// 	is_text_op_mouse_input = true;
			// }
			//NOTE : This needs to be on the bottom so we only hit it as default if we doing the above actions like text editing
			/*DOC : This gets clicked always before double click so we always highlight and change text pane first
			and also check if we have watch edit to set that and reset the crusor in both SetHighlightedWatchToWatchEditAndEvaluate
			and ChangeTextPane.
			*/
			else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
				// SetHighlightedWatchToWatchEditAndEvaluate(text_op, perm.all_data); 
				//NOTE : We reset watch editing when we set watch edit in ChangeTextPnae now
				ChangeTextPane(.WATCH, text_op, perm.all_data);
				// assert(text_op.watch_data_rows.count > 0);
				text_op.highlighted_name_index = Clamp(0, mouse_watch_index, text_op.watch_data_rows.count-1);

				is_text_op_mouse_input = true;
			}
		}
		//NOTE : We run this even if we already have is_text_op_mouse_input to make sure we register the up_this_frame
		//DOC : This reset cursor_left_mouse_holding on up_this_frame if we were holding it down anytime
		// if we press cursor_left_mouse_holding and click off the text op_space on the same frame
		// it wont move since we are off it and not in this case 
		// and then itll get reset anyways when we click back on the op space
		// since itll get an up_this_frame and then reset it anyways in any case
		//NOTE : REMEMBER this needs to be set here outside the rectangle bounds since we need to check it even if the mouse is 
		//out but also to properly reset it once we come back in on an up_this_frame mouse click
		is_holding_mouse_on_watch : bool = CheckCursorMouseHolding(watch_mouse_char_point, 0, *text_op.watch_cursor, text_op.edit_watch_name, game_input, single_line=true);
		//Need to check if this is true because otherwise we will set is_text_op_mouse_input to false and then run the code below here anyways
		if is_holding_mouse_on_watch is_text_op_mouse_input = true;

		if text_op.exec_info.exec_state == .IS_DEBUG_STOP && !is_text_op_mouse_input {
			//TODO Remember that this is in IS_DEBUG_STOP along with other ones as well.
			if IsInRectangle(op_mouse, text_op.ator.r_bottom_rect) {
				mouse_call_stack_y_float_diff : float = (text_op.ator.R_BOTTOM_LOC_CALL_STACK_Y - op_mouse.y) / text_op.ator.TEXT_LINE_HEIGHT;
				mouse_call_stack_y_diff : int = round_to_int(mouse_call_stack_y_float_diff);
				mouse_call_stack_index : int = text_op.start_call_stack_index + mouse_call_stack_y_diff;
				// if game_input.mouse_wheel != 0 {
				if IsMouseWheelWithoutModifiers(game_input) {
					is_text_op_mouse_input = true;
					MouseScrollTextBounds(*text_op.start_call_stack_index, *text_op.end_call_stack_index,
						text_op.exec_info.debug_info.debug_call_stack.count, game_input.mouse_wheel);
				}
				else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
					is_text_op_mouse_input = true;
					// print("call_stack_index_diff=%,call_stack_index=%\n", mouse_call_stack_y_diff, mouse_call_stack_index);
					if text_op.selected_pane != SelectedTextPane.CALL_STACK {
						ChangeTextPane(SelectedTextPane.CALL_STACK, text_op, perm.all_data);
					}
					text_op.highlighted_call_stack_index = Clamp(0, mouse_call_stack_index, text_op.exec_info.debug_info.debug_call_stack.count-1);
					SelectHighlightedCallFrame(text_op, perm.all_data);
				}
				//TODO Can add a double click here to choose that call stack OR set it when we move up there
				//and see if they overlap. ALSO need to adjust code pointer so we can see where we are in the code
				//when we choose the other call stack
				//WE ARE DOING it on click for now, we can make it ctrl+click if that is better.
				//I am not a huge fan of the double click.
			}
		}
	}

	//TODO Can we make this function for other text split line since we reuse it
	console_mouse_y_diff : float = MouseYDiff(text_op.console_tsl.y_start_top, op_mouse.y, text_op.ator.cursor_height);
	console_mouse_line_number : int = MouseLineNumber(console_mouse_y_diff, text_op.console_tsl.line_height, 
		text_op.console_tsl.start_file_line_index, text_op.console_tsl.split_lines.count);
	console_mouse_line_string : string;
	if text_op.console_tsl.split_lines.count > 0 {
		console_mouse_line_string = text_op.console_tsl.split_lines[console_mouse_line_number].split_string;
	}
	console_mouse_line_char : int = MouseLineChar(op_mouse.x, text_op.console_tsl.x_start_left, 
		perm.text_editor_data.code_font_1_char_width_world, console_mouse_line_string.count);
	if IsInRectangle(op_mouse, text_op.ator.l_bottom_rect) && !is_text_op_mouse_input {
		if text_op.l_bottom_pane_type == {
		case TextPaneType.DISASSEMBLY; {
		//TODO Should eventually allow input here so we can easily input text from a text_op and do things everywhere.
		//We use LOC_START_Y instead of ASM_DEBUG_Y here because we want to click within the text line
		//and the asm debug is for setting the breakpoints in the correct visual position.
		mouse_asm_y_float_diff : float = (text_op.ator.L_BOTTOM_LOC_ASM_Y - op_mouse.y) / text_op.ator.TEXT_LINE_HEIGHT;
		mouse_asm_y_diff : int = round_to_int(mouse_asm_y_float_diff);
		mouse_asm_index : int = text_op.start_disasm_index + mouse_asm_y_diff;
		// if game_input.mouse_wheel != 0 {
		if IsMouseWheelWithoutModifiers(game_input) {
			is_text_op_mouse_input = true;
			if text_op.text_comp_data != null && text_op.text_comp_data.disassembly_loc.data != null {
				MouseScrollTextBounds(*text_op.start_disasm_index, *text_op.end_disasm_index,
					text_op.text_comp_data.disassembly_loc.count, game_input.mouse_wheel);
			}
		}
		else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
			is_text_op_mouse_input = true;
			// print("start_disasm_index=%,end_disasm_index=%\n", text_op.start_disasm_index, text_op.end_disasm_index);
			// print("asm_index_diff=%,asm_index=%\n", mouse_asm_y_diff, mouse_asm_index);
			if text_op.selected_pane != SelectedTextPane.DISASSEMBLY {
				ChangeTextPane(SelectedTextPane.DISASSEMBLY, text_op, perm.all_data);
			}
			if text_op.text_comp_data != null && text_op.text_comp_data.disassembly_loc.count > 0 {
				text_op.highlighted_disasm_index = Clamp(0, mouse_asm_index, text_op.text_comp_data.disassembly_loc.count-1);
			}
		}
		//DOC : We set highlighted_disasm_index above on the same frame and then set the breakpoint if we are in the margin
		//so when we set a breakpoint we also highlight the line and then use that line to set the correct breakpoint.
		//This means l_bottom_rect && left_margin_rect so its left_bottom_margin_rect because of the outer if
		if IsInRectangle(op_mouse, text_op.ator.left_margin_rect) &&
			IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input)
		{
			is_text_op_mouse_input = true;
			PressAsmBreakpoint(text_op.highlighted_disasm_index, text_op);
		}
		}
		//TODO FROM HERE test compile console by adding my own input (could make a function)
		//and we could also rename to TEXT_OP_CONSOLE since we can use it for other things as well
		//when we need to output more info than just the compiler errors
		//then test mouse scrolling and highlighting and copying to make sure it works like the terminal
		//CAN WE reuse any more text split line stuff or is this good enough for now?
		case TextPaneType.COMPILER_CONSOLE; {
		// if game_input.mouse_wheel != 0 {
		if IsMouseWheelWithoutModifiers(game_input) {
			is_text_op_mouse_input = true;
			//Dummy variable to keep the mouse text scrolling consistent
			end_line_index : int = text_op.console_tsl.start_file_line_index + text_op.console_tsl.viewable_lines_from_zero;
			MouseScrollTextBounds(*text_op.console_tsl.start_file_line_index, *end_line_index, 
				text_op.console_tsl.split_lines.count, game_input.mouse_wheel);
		}
		else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
			is_text_op_mouse_input = true;
			//TODO We could change pane on mouse scrolling above as well if that feels better
			if text_op.selected_pane != SelectedTextPane.COMPILER_CONSOLE {
				ChangeTextPane(SelectedTextPane.COMPILER_CONSOLE, text_op, perm.all_data);
			}
			text_op.console_tsl.cursor_is_selecting = false;
			if console_mouse_line_number < text_op.console_tsl.split_lines.count {
				// print("console_mouse_y_diff=%, console_mouse_line_number=%, console_mouse_line_char=%\n", 
				// 	console_mouse_y_diff, console_mouse_line_number, console_mouse_line_char);
				// print("char=\"%\",char_pos=%\n", loc[char_pos_int], char_pos);
				//NOTE : We don't use char_point here since we just use line number and line char
				// text_op.console_tsl.char_point = mouse_char_point;
				text_op.console_tsl.cursor_line_number = console_mouse_line_number;
				//TODO Leaving here for testing can remove once were done
				// print("text_op.console_tsl.char_point=%\n", text_op.console_tsl.char_point);
				// print("console_mouse_line_number=%\n", console_mouse_line_number);
				text_op.console_tsl.cursor_line_char = console_mouse_line_char;
				text_op.console_tsl.cursor_left_mouse_holding = true;
			}
			//DOC : In case we press on a tab char at the beginning or end of a line OR a half line on top or bottom
			//then we will adjust the bounds so we can see it.
			//TODO We could update cursor_line_char in here based on char point if that helps keep things consistent.
			// UpdateCursorLineCharAndBounds(tab_cursor, text_file.file_string);
		}
		}
		}
	}
	TextSplitLineMouseHolding(console_mouse_line_char, console_mouse_line_number, *text_op.console_tsl, game_input);
	//Need to check if this is true because otherwise we will set is_text_op_mouse_input to false and then run the code below here anyways
	if text_op.console_tsl.cursor_left_mouse_holding is_text_op_mouse_input = true;

	//TODO FROM HERE move other 2 pane selections and then see how code overlaps while implementing scrolling
	//and any other overlapping functionality. then cleanup down below with new rects/positions as well

 	//TODO By default we currently set the op_cam to the active_cam. Eventually we should have separate
 	//code for windows and then run whatever code is needed for that window.
 	//Likely use a function pointer so we can run anything we want but also the user can
 	//create a window and put whatever they want in it with that function pointer. 
 	// perm.all_data.active_cam_id = default_base_cam.id;
	//TODO I think we can bring this up and remove it altogether if we do input properly everywhere so we are
	//not selecting 2 things at once for now at least.
 	// perm.all_data.input_check.is_writing_code = true;

 	if !is_text_op_mouse_input {
    	//TODO For mouse input we would need to check if the mouse is in the left or right rect here.
    	//So we would have to pull that out from rendering to compute the mouse collision here.
		if IsInputMapPress(.TEXT_PANE, .DOWN_THIS_FRAME, game_input) {
			ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
			// text_op.selected_pane = SelectedTextPane.TEXT;
		// } else if keyboard.only_alt_down && keyboard.two.down_this_frame {
		} else if IsInputMapPress(.TEXT_WATCH_PANE, .DOWN_THIS_FRAME, game_input) && text_op.exec_info.exec_mode == .DEBUG {
			ChangeTextPane(SelectedTextPane.WATCH, text_op, perm.all_data);
			// text_op.selected_pane = SelectedTextPane.WATCH;
		} else if IsInputMapPress(.TEXT_BOTTOM_LEFT_PANE, .DOWN_THIS_FRAME, game_input) && text_op.exec_info.exec_mode == .DEBUG {
			// if text_op.text_comp_data != null && text_op.text_comp_data.disassembly_loc.count > 0 {
			ChangeTextPane(SelectedTextPane.DISASSEMBLY, text_op, perm.all_data);
				// text_op.selected_pane = SelectedTextPane.DISASSEMBLY;
			// }
		//TODO 4 and 5 can be call stack and breakpoints
		} else if IsInputMapPress(.TEXT_BOTTOM_RIGHT_PANE, .DOWN_THIS_FRAME, game_input) && text_op.exec_info.exec_mode == .DEBUG {
			ChangeTextPane(SelectedTextPane.CALL_STACK, text_op, perm.all_data);
			// text_op.selected_pane = SelectedTextPane.CALL_STACK;
		} else if keyboard.only_alt_down && keyboard.six.down_this_frame && text_op.exec_info.exec_mode == .DEBUG {
			//TODO I like this method of just being able to switch modes with one variable set. KEEP THIS!
			//This way we can make this pop up when compilation is done or when we have another message to show.
			ChangeTextPane(SelectedTextPane.COMPILER_CONSOLE, text_op, perm.all_data);
			// text_op.selected_pane = SelectedTextPane.COMPILER_CONSOLE;
		}
		else if IsInputMapPress(.TEXT_COMPILE, .DOWN_THIS_FRAME, game_input) {			
			//TODO Make this event be doable by text_file or by string
			//Should probably generate a command eventually and have the output go to compiler_console
			text_op_is_executing : bool = TextOpIsExecuting(text_op.op_space_id, perm.all_data.all_process_instruction_events);
			if !text_op_is_executing {
				c_event : CompileCodeEvent;
				c_event.compile_code_type = CompileCodeType.TEXT_FILE;
				c_event.op_space_id = text_op.op_space_id;
				found_text_file : bool = false;
				if text_op.set_fixed_main_compile {
				 	main_text_file, found_main_file := ArrayFindFirstByNameId(perm.all_data.all_text_files,
						text_op.main_compile_text_file_id, "id");
				 	if found_main_file {
				 		//TODO We actually don't need to set this since it is grabbed when we compile BUT
				 		//will just leave here for now to check. I think we can just use the text op for compilation
				 		//and external compilation can just be done with the compile code function from a dll directly
						c_event.code_string = main_text_file.text_string;
						c_event.text_file_id = text_op.main_compile_text_file_id;
						found_text_file = true;
					} else {
						msg : string = tprint("set main file id % not found", text_op.main_compile_text_file_id);
						SetTextOpConsoleMessage(msg, text_op);
						SetTextStatus(msg, text_op);
					}
				} else {
					//We grab the current text file if we dont have a fixed main file to compile set
					c_event.text_file_id = text_file.id;
					found_text_file = true;
				}
				if found_text_file {
					// TODO We could open the compiler console whenever we compile here
					//or maybe only if theres errors later
					array_add(*perm.all_data.all_compile_code_events, c_event);
				}
			}
		}
		else if IsInputMapPress(.TEXT_SET_FIXED_MAIN_COMPILE, .DOWN_THIS_FRAME, game_input) {
			msg : string;
			if text_op.set_fixed_main_compile {
				text_op.set_fixed_main_compile = false;
				msg = "unset fixed main compile";
			} else {
				text_op.set_fixed_main_compile = true;
				text_op.main_compile_text_file_id = text_file.id;
				msg = tprint("% set to main compile", text_file.file_short_name);
			}
			SetTextOpConsoleMessage(msg, text_op);
			SetTextStatus(msg, text_op);
		}
   	else if 
   		IsInputMapPress(.TEXT_DISASM_TOGGLE, .DOWN_THIS_FRAME, game_input) ||
	   	IsInputMapPress(.TEXT_CONSOLE_TOGGLE, .DOWN_THIS_FRAME, game_input) ||
	   	IsInputMapPress(.TEXT_DEBUG_TOGGLE, .DOWN_THIS_FRAME, game_input) ||
	   	IsInputMapPress(.TEXT_CALL_STACK, .DOWN_THIS_FRAME, game_input)
	   {
			//TODO We are setting this here now but this should be fixed and settable beforehand somewhere
			//so it stays the same unless we adjust it in the other place.
	   	// if IsInputMapPress(.TEXT_CONSOLE_TOGGLE, .DOWN_THIS_FRAME, game_input) && text_op.exec_info.exec_mode == .DEBUG {
	   	if IsInputMapPress(.TEXT_CONSOLE_TOGGLE, .DOWN_THIS_FRAME, game_input) {
	   		if text_op.l_bottom_pane_type == TextPaneType.COMPILER_CONSOLE {
	   			text_op.l_bottom_pane_type = TextPaneType.NONE;
					if text_op.selected_pane == SelectedTextPane.COMPILER_CONSOLE {
						ChangeTextPane(SelectedTextPane.COMPILER_CONSOLE, text_op, perm.all_data);
					}
	   		} else {
					text_op.l_bottom_pane_type = TextPaneType.COMPILER_CONSOLE;
					ChangeTextPane(SelectedTextPane.COMPILER_CONSOLE, text_op, perm.all_data);
				}
			} 
			// else if IsInputMapPress(.TEXT_DISASM_TOGGLE, .DOWN_THIS_FRAME, game_input) && text_op.exec_info.exec_mode == .DEBUG {
			else if IsInputMapPress(.TEXT_DISASM_TOGGLE, .DOWN_THIS_FRAME, game_input) {
	   		if text_op.l_bottom_pane_type == TextPaneType.DISASSEMBLY {
					text_op.l_bottom_pane_type = TextPaneType.NONE;
					if text_op.selected_pane == SelectedTextPane.DISASSEMBLY {
						ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
					}
				} else {
					text_op.l_bottom_pane_type = TextPaneType.DISASSEMBLY;
					ChangeTextPane(SelectedTextPane.DISASSEMBLY, text_op, perm.all_data);
				}
			} 
			else if IsInputMapPress(.TEXT_CALL_STACK, .DOWN_THIS_FRAME, game_input) && text_op.exec_info.exec_mode == .DEBUG {
	   		if text_op.r_bottom_pane_type == TextPaneType.CALL_STACK {
					text_op.r_bottom_pane_type = TextPaneType.NONE;
					if text_op.selected_pane == SelectedTextPane.CALL_STACK {
						ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
					}
				} else {
					text_op.r_bottom_pane_type = TextPaneType.CALL_STACK;
					ChangeTextPane(SelectedTextPane.CALL_STACK, text_op, perm.all_data);
				}
			} 
			else if IsInputMapPress(.TEXT_DEBUG_TOGGLE, .DOWN_THIS_FRAME, game_input) && 
				text_op.exec_info.exec_state == .NOT_RUNNING 
		 	{
				//Only allow this if we are not running code
				//TODO The proportions and margin should be done through ui and maybe command line later.
				//They should be set beforehand so we just grab it from there consistently.
				if text_op.exec_info.exec_mode == ExecutionMode.RUN {
					text_op.exec_info.exec_mode = ExecutionMode.DEBUG;
					//TODO Store these values as debug_left_proportion and debug_left_margin_char_width for reuse
					//TODO Should store these as settable defaults in settings file once we add that
					//so we can reopen debug text op the same way each time.
					// text_op.left_proportion = 0.6;
					text_op.set_left_proportion = 0.6;
					text_op.left_margin_char_width = 3;
					text_op.l_bottom_left_proportion = text_op.left_proportion;
					if text_op.l_bottom_pane_type == TextPaneType.NONE {
						text_op.l_bottom_pane_type = TextPaneType.DISASSEMBLY;
					}
					if text_op.r_bottom_pane_type == TextPaneType.NONE {
						text_op.r_bottom_pane_type = TextPaneType.CALL_STACK;
					}
				} else if text_op.exec_info.exec_mode == ExecutionMode.DEBUG {
					ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
					// text_op.selected_pane = SelectedTextPane.TEXT;
					text_op.exec_info.exec_mode = ExecutionMode.RUN;
					//TODO Store these values as text/default_left_proportion and text/default_left_margin_char_width for reuse
					//NOTE that the proportion here remove the right side visually no matter what 
					// text_op.left_proportion = 1.0;
					text_op.set_left_proportion = 1.0;
					text_op.left_margin_char_width = 0;
					text_op.l_bottom_left_proportion = text_op.left_proportion;
					//TODO We can turn this off by default here
					text_op.l_bottom_pane_type = TextPaneType.NONE;
					text_op.r_bottom_pane_type = TextPaneType.NONE;
				}
			}

			//TODO I think we should just call this whenever we do a keyboard action and not just here.
			ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
				perm.text_editor_data);
			//TODO SETTINGS DEFINETELY Make this a setting although I think false should be the default
			//TODO We can just remove this if everything works fine. Having this does not work now
			//if we have a selection it unselects it and moves the cursor which is definitely wrong and unexpected behavior.
			#if 0 {
			if tab_cursor.cursor_line_number > tab_cursor.end_file_line_index {
				MoveToLine(tab_cursor.cursor_line_number, text_file.file_string, tab_cursor, center_line=false);
			}
			}
		}
		//Default run or step over from anywhere.
		/*DOC : This cluster prevents other keystrokes from happening. This is useful but likely can add else
		if for the whole thing and then an else on the bottom for specific keystrokes to avoid any weird issues.
		*/
		//TODO Could make this automatically go to text editor unless we are in disassembly.
		//Maybe it feels better to be able to do it from the watch window as well so let's try it out and see.
		else if IsInputMapPress(.TEXT_RUN_CONTINUE, .DOWN_THIS_FRAME, game_input) && text_op.exec_info.exec_mode == .DEBUG &&
	  		AllOrEquals(text_op.exec_info.exec_state, .[.NOT_RUNNING, .IS_DEBUG_STOP])
		{
			//TODO This could be START_DEBUGGING if that makes more sense but right now it's the same as just starting execution.
			msg : string;
			//TODO Should we just replace this with an is_already_executing boolean?
			// if perm.all_data.all_process_instruction_events.count == 0 {
			if text_op.text_comp_data == null || text_op.text_comp_data.all_music_instructions.count == 0 {
				msg = "No instructions to run";
			} else if OneOpIsExecuting(perm.all_data.all_process_instruction_events) {
				msg = "Already Executing";
			} else {
				text_op.exec_info.debug_info.debug_control = DebugControl.CONTINUE;
				array_add(*perm.all_data.all_process_instruction_events, .{text_op.op_space_id});
				msg = tprint("% Executing...", text_file.file_short_name);
			}
			SetTextOpConsoleMessage(msg, text_op);
			SetTextStatus(msg, text_op);
		} 
		else if text_op.exec_info.exec_state == .IS_DEBUG_STOP && text_op.exec_info.exec_mode == .DEBUG &&
				  IsInputMapPress(.DEBUG_STEP_OVER, .DOWN_THIS_FRAME, game_input)
		{
			if text_op.selected_pane == .DISASSEMBLY {
				text_op.exec_info.debug_info.debug_control = DebugControl.ASM_STEP_OVER;
			} else {
				text_op.exec_info.debug_info.debug_control = DebugControl.STEP_OVER;
			}
			array_add(*perm.all_data.all_process_instruction_events, .{text_op.op_space_id});
		} 
		else if text_op.exec_info.exec_state == .IS_DEBUG_STOP && text_op.exec_info.exec_mode == .DEBUG &&
				  IsInputMapPress(.DEBUG_STEP_INTO, .DOWN_THIS_FRAME, game_input)
		{
			if text_op.selected_pane == .DISASSEMBLY {
				text_op.exec_info.debug_info.debug_control = DebugControl.ASM_STEP_INTO;
			} else {
				text_op.exec_info.debug_info.debug_control = DebugControl.STEP_INTO;
			}
			array_add(*perm.all_data.all_process_instruction_events, .{text_op.op_space_id});
		} 
		else if text_op.exec_info.exec_state == .IS_DEBUG_STOP && text_op.exec_info.exec_mode == .DEBUG &&
				  IsInputMapPress(.DEBUG_STEP_OUT, .DOWN_THIS_FRAME, game_input)
		{
			text_op.exec_info.debug_info.debug_control = DebugControl.STEP_OUT;
			array_add(*perm.all_data.all_process_instruction_events, .{text_op.op_space_id});
		}
		else if text_op.exec_info.exec_mode == .DEBUG &&
				  AllOrEquals(text_op.exec_info.exec_state, .[.IS_DEBUG_STOP, .IS_EXEC_RUNNING]) &&
				  IsInputMapPress(.TEXT_STOP, .DOWN_THIS_FRAME, game_input)
		{
			//TODO Eventually we can do this while running as well if we run a certain number of instructions
			//every frame, then we can do this also when not DEBUG_STOP
			text_op.exec_info.exec_state = ExecutionState.NOT_RUNNING;
			array_reset_keeping_memory(*perm.all_data.all_process_instruction_events);
			array_reset_keeping_memory(*perm.all_data.all_music_instructions);
			msg := tprint("% Stopped", text_file.file_short_name);
			SetTextOpConsoleMessage(msg, text_op);
			SetTextStatus(msg, text_op);
		}
		else if text_op.exec_info.exec_state == .IS_DEBUG_STOP && text_op.exec_info.exec_mode == .DEBUG &&
					//TODO Should we allow this on execution or only on debug stop?
				  // AllOrEquals(text_op.exec_info.exec_state, .[.IS_DEBUG_STOP, .IS_EXEC_RUNNING]) &&
				  IsInputMapPress(.TEXT_RESTART, .DOWN_THIS_FRAME, game_input)
	   {
			text_op.exec_info.exec_state = ExecutionState.NOT_RUNNING;
			array_add(*perm.all_data.all_process_instruction_events, .{text_op.op_space_id});
	   }
	   else if IsInputMapPress(.TEXT_SHOW_STATUS_BAR, .DOWN_THIS_FRAME, game_input) {
	   	text_op.show_text_status_bar = !text_op.show_text_status_bar;
			ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
				perm.text_editor_data);
	   }
	   /*DOC : This shortcut allows a refresh of the text op space and all the file tab cursors.
	   This way if there are any strange issues with the cursor in the wrong place, then hard reset should fix it.
	   Maybe it's not good for debugging though, hopefully people can still report the issues.
	   Maybe best to ask them to report and then also do the refresh in the shortcut description message.
	   I can just allow this in the text editor but we resize the whole op space and reset all the cursors
	   So maybe better to allow it from anywhere in the text op space.

	   TODO I won't test this for now but may be I can later if there are issues with it when using it.
	   */
	   else if IsInputMapPress(.TEXT_SPACE_REFRESH, .DOWN_THIS_FRAME, game_input) {
			ChangeTextPane(.TEXT, text_op, perm.all_data);	
			for * tab : text_op.file_tabs	{
				ResetTextCursor(*tab.tab_cursor);
				UpdateCursorLineCharAndBounds(*tab.tab_cursor, text_file.file_string);
			}
			ResetTextCursor(*text_op.first_bar_cursor);
			ResetTextCursor(*text_op.second_bar_cursor);
			//DOC : We do this after resetting the cursor so that if the end line and right char bounds change
			//then we will start from the reset to 0 cursor.
			ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
				perm.text_editor_data);
			//TODO We coudl reset the cursor and update the line char bounds again here for good measure if needed
	   }
	   /*TODO We could prevent this from happening if we hit any of the above hotkeys to avoid unknown overlapping
	   key stroke issues. We could also make some actions event based and do them later like we do with compilation.
	   This allows us to order or not process certain events if they conflict with others.
	   MIGHT HAVE TO update some tests where we hit multiple keys on 1 frame if we do that.

	   OVERALL We want to consider that we should have both events and then also prevention here. The events
	   avoid doubling actions to remove the possibility of inconsistent state BUT then we can also avoid 
	   invalid multiple different key presses here altoghether.

	   DOC : Note that if everything above here only deals with changing text panes or changing execution state
	   then it is fine because we can do both of those on the same frame. So this might require some testing
	   but it also depends on the specific, so better to be safe here and not process some key presses than to 
	   try processing everything and end up with and invalid state.
	   */
		else if text_op.selected_pane == SelectedTextPane.TEXT {
			// if text_op.exec_info.exec_mode == ExecutionMode.DEBUG && keyboard.f9.down_this_frame {
			if text_op.exec_info.exec_mode == ExecutionMode.DEBUG && 
				IsInputMapPress(.DEBUG_SET_BREAKPOINT, .DOWN_THIS_FRAME, game_input)
			{
				#if 1 {
				PressCodeBreakpoint(text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number, 
					text_op, text_op.text_comp_data);
				} else {
				//TODO We could pull this out as function and test it for convenience and also
				//then we can use it to set break_points from other places like tests or somewhere else in the code

				/*NOTE : It's ok to set a BP_CODE even if we have a BP_ASM because the BP_CODE is a range
				so it can stop anywhere in that range like with for array start loop code.
				BP_ASM is at a specific asm index so it does not interfere in any case.
				For convenience we render the BP_CODE for both asm and code panes but ultimately
				seeing code from asm to code or code to asm can have a separate action so we can see the ranges as well.
				*/
				found_breakpoint : bool = false;
				for text_op.exec_info.debug_info.break_points {
					if it.bp_type == .BP_CODE && it.line_number == text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number {
						//TODO Do a memcpy remove here once we implement it in general.
						array_ordered_remove_by_index(*text_op.exec_info.debug_info.break_points, it_index);
						found_breakpoint = true;
						break;
					}
				}

				if !found_breakpoint {
					//NOTE : We set a breakpoint in the editor no matter what. If we don't have asm_index
					//then this is set to -1 and should never get hit since we check asm_index in execution. 
					//NEED TO TEST THIS.
					//IF we have a line that has no asm_index (no debug_line), then we wont find it in all_debug_lines
					//and so it will still be -1.
					//TODO We can render this with the "?" or a different color like in remedy
					//Probably different color like grey is best, like a disabled breakpoint or maybe different color.
					//TODO We want to associate this to op_space data once we have that. for now it's just the default allocator.
					break_point : *DebugBreakpoint = array_add(*text_op.exec_info.debug_info.break_points);
					break_point.bp_type = BreakpointType.BP_CODE;
					break_point.line_number = text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number;
					break_point.asm_index = -1;
					break_point.end_asm_index = -1;
					//TODO Grab this instead once we have multiple compilation data possible
					if text_op.text_comp_data != null && text_op.text_comp_data.all_debug_lines.count > 0 {
						for text_op.text_comp_data.all_debug_lines {
							//TODO Could set this to >= so we take the next line that is available for debugging
							if it.line_number == break_point.line_number {
								break_point.asm_index = it.start_asm_index;
								break_point.end_asm_index = it.end_asm_index;
								break;
							}
						}
					}
				}
				}
			}
			//REMINDER : IF we just have settings later and everything else is dynamic libraries, then we can just do this on save
			//I am leaving here for now in case people have autosave and did not want to update right away
			else if IsInputMapPress(.TEXT_FILE_UPDATE_DATA, .DOWN_THIS_FRAME, game_input) {
				/*DOC : Certain files like input mappings or default settings or nd chord files, 
				we want to update some corresponding data for convenience.
				This allows quick changes to be made with a hotkey instead of using the terminal.
				Then the output can go to the text console or the text status bar for convenience.
				*/

				//TODO SHOULD WE HAVE THIS HAPPEN ON SAVE EVENTUALLY
				//The reason against is that auto save or invalid files might save and then
				//you have an invalid settings file. We could check update before saving in that case
				//for settings files but then that behavior is inconsistent since save does not always save. 
				//Keeping them separate for now allows a choice

				save_file : bool = false;
				//TODO Eventualy we could allow setting an input mappings file that can
				//be updated automatically, but having only this one is clear for now.
				//TODO We could set it in settings or through the terminal
				abs_im_path : string = get_absolute_path(perm.all_data.input_mappings_file_path);
				abs_settings_path : string = get_absolute_path(perm.all_data.runtime_settings_file_path);
				if text_file.absolute_path_name == abs_im_path {
					pimr : ParsedInputMappingReturn = ParseInputMappingsFile(*perm.all_data.all_text_files, abs_im_path);
					console_msg : string;
					if pimr.success {
						valid, error_msg := UpdateGameInputMappings(pimr.parsed_input_mappings, game_input);
						if !valid {
							console_msg = error_msg;
						} else {
							save_file = true;
							console_msg = tprint("Loaded input mappings %\n", perm.all_data.runtime_settings_file_path);
						}
					} else {
						console_msg = pimr.error_msg;
					} 
					SetTextOpConsoleMessage(console_msg, text_op);
				}
				else if text_file.absolute_path_name == get_absolute_path(abs_settings_path) {
					rsr : RuntimeSettingsReturn = ParseRuntimeSettingsFile(*perm.all_data.all_text_files, abs_settings_path);
					console_msg : string;
					if rsr.success {
						save_file = true;
						UpdateRuntimeSettings(rsr.new_settings, perm, renderer_data);
						console_msg = tprint("Loaded runtime settings %\n", perm.all_data.runtime_settings_file_path);
					} else {
						console_msg = rsr.error_msg;
					}
					SetTextOpConsoleMessage(console_msg, text_op);
				}

				//If we updated the data, then we save the text file to keep the data consistent with the file
				//TODO MAybe then we should just do the updates on save so it stays consistent anyways
				//then auto save can be turned on and off
				//TODO Maybe we can add this as a setting later and then bring it on top and only update
				//if we successfully saved the file 
				//Ultimately it does not matter too much since we might remove settings overall and then just
				//have simple runtime settings with file name and we can just update that on save as an exception
				#if 1 {
				if save_file {
					success, msg := SaveTextFile(text_file);
					SetTextStatus(msg, text_op);
				}
				}
			}
			else if IsInputMapPress(.TEXT_FILE_SAVE, .DOWN_THIS_FRAME, game_input) {
				//TODO We could turn this into 1 function so that we can set it for automatic save wherever we want to.
				//Maybe better to have save text file and update separate for now since we only use it in 2 places
				//and we don't update the file we are saving from here but if we do it automatically in
				//settings then maybe we should

				//TODO SETTING to auto save unsaved tabs probably (we might have to set the manually in each place)
				//unless we create an action/save system but then still only certain actions will auto-save
				//So we might just add it manually if autosave and we do certain things then 
				//If we save in ChangeTextPane if not saved I think that deals with most changes for the text op space
				//and then un-choosing this text op space or closing the program can also save for safety
			 	text_file, found_text_file := ArrayFindFirstByNameId(perm.all_data.all_text_files,
					text_op.file_tabs[text_op.ftab_i].text_file_id, "id");
				assert(found_text_file);
				//TODO We now update the cursors when changing tabs or choosing a text op space so just saving should be enough now.
				// success, msg := SaveTextFileAndUpdateAllTextOpTabs(text_file, perm.all_data, perm.text_editor_data, text_op.op_space_id);
				success, msg := SaveTextFile(text_file);
				SetTextStatus(msg, text_op);
			}
			//TODO FROM HERE adjust Test_TextWatch and then cycle text files and also prevent misclicks
			//here with else over this and combine else ifs on top and adjust tests
			//then write test for this and moving around with debugging before making a test
			//with the mini-game file and add more tests for that or just use that for tests for now
			//Can add both files right away since we don't have open file functionality yet.
			else if IsInputMapPress(.TEXT_FILE_TAB_RIGHT, .DOWN_THIS_FRAME, game_input) ||
					  IsInputMapPress(.TEXT_FILE_TAB_LEFT, .DOWN_THIS_FRAME, game_input)
			{
				//TODO Should likely make this to check FIRST map press
				ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);

				//TODO Likely make this an event so we only change move around to 1 file to avoid inconsistent data
				new_tab : int;
				if IsInputMapPress(.TEXT_FILE_TAB_RIGHT, .DOWN_THIS_FRAME, game_input) {
					new_tab = text_op.ftab_i + 1;
					if new_tab >= text_op.file_tabs.count {
						new_tab = 0;
					}
				}
				else if IsInputMapPress(.TEXT_FILE_TAB_LEFT, .DOWN_THIS_FRAME, game_input) {
					new_tab = text_op.ftab_i - 1;
					if new_tab < 0 {
						new_tab = text_op.file_tabs.count-1;
					}
				}
				text_file = ChangeTextTab(new_tab, text_op, perm.all_data.all_text_files);
				// text_file = GetTabTextFile(text_op, perm.all_data.all_text_files);
				//TODO We grab the new text file BUT we could make this an event so we don't have to worry about this
		    	// text_file, found_text_file = ArrayFindFirstConstByNameId(perm.all_data.all_text_files,
	    		// 	text_op.file_tabs[text_op.ftab_i].text_file_id, "id");
		    	// //TODO Leave this as an assertion for now to make sure we don't have invalid text tabs
	    		// assert(found_text_file);

	    		//TODO FROM HERE should we update else ifs here or is it ok for now?
	    		//and update some of the variables names maybe TextOpFileTab is better
	    		//and then write extensive tests with char_bounds and line_index, make sure those change
	    		//properly in many cases and also switching between tabs and also writing text Test_TextWrite
	    		//Then start on a small file that writes a melody with 1 library and gradually add and test things to that.
	    		//TODO FROM HERE MAYBE can implement IsFirstKeyboardPress just so we can put it somewhere so we can see
	    		//if it works over time for key presses that we don't want to overlap, that will be a sure fire way to prevent 
	    		//multiple presses on the same frame.

				#if 0 {
				//TODO Should store a text cursor for each text file tab
				// ResetTextCursor(*text_op.file_tabs[text_op.ftab_i].tab_cursor);
				//NOTE : Resizing here since this reset the start and end line_index and also the text cursor right char bounds
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);

				MoveToLine(text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number, text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor);
				}
				#if 0 {
				if (stop_d_line.line_number < text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index ||
					stop_d_line.line_number > text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index)
				{
					//TODO Maybe we just move line but not cursor and store cursor and leave it as is
					MoveToLine(stop_d_line.line_number, edit_text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor);
				}
				}
			}
			else if IsInputMapPress(.TEXT_FILE_TAB_BAR, .DOWN_THIS_FRAME, game_input) {
				//TODO this is overkill since we just want to unselect the bottom bar but in case we pull it out
				//or something later this is likely more resilient overall.
				ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
				if text_op.text_top_bar_type == TextTopBarType.TEXT_FILE_TABS {
					text_op.text_top_bar_type = TextTopBarType.NONE;
				} else {
					text_op.text_top_bar_type = TextTopBarType.TEXT_FILE_TABS;
				}
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			}
			else if IsInputMapPress(.TEXT_FILE_TAB_CLOSE, .DOWN_THIS_FRAME, game_input) {
				ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
				CloseFileTab(text_op.ftab_i, text_op, perm.all_data);
				if text_op.ftab_i > 0 {
					new_tab : int = text_op.ftab_i - 1;
					text_file = ChangeTextTab(new_tab, text_op, perm.all_data.all_text_files);
					// text_op.ftab_i -= 1;
					// //Not sure we actually need this here but just in case
					// text_file = GetTabTextFile(text_op, perm.all_data.all_text_files);
				}
			}
			else if IsInputMapPress(.TEXT_FILE_TAB_OPEN, .DOWN_THIS_FRAME, game_input) {
				//TODO FROM HERE need to update the text file pointer with a function UpdateTextFilePointer
				//whenever we update the ftab_i or here when we add a text file since that can make the pointer incorrect
				//Just a GetTabTextFile to update the pointer we use here.
				//THEN also add the code for saving in ChangeTextPane with the passed in text file
				//Or we can grab it but I think it's ok since if it doesn't save by mistake it will still show unsaved.
				//TODO FROM HERE test saving files checking the bool and also that the cursor is properly updated in other text op space tabs

				ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
				open_text_file, found_open_file := 
					OpenFileTabWithExplorer(text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
				if found_open_file {
					//We set the text file here since we opened a new text_file and that could have changed the array memory pointer
					text_file = open_text_file;
				}
			}
			//NOTE : We don't need to call ChangeTextTab here because we are not changing the text tab and only swapping them
			//DOC : The swap works here because we only moving over 1 at a time. If we were moving over > 1 at a time then
			//we would have to do ordered remove and insert like with the mouse.
			else if IsInputMapPress(.TEXT_FILE_TAB_SWAP_LEFT, .DOWN_THIS_FRAME, game_input) {
				ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
				if text_op.ftab_i > 0 {
					previous_tab_i : int = text_op.ftab_i - 1;
					swap(*text_op.file_tabs[text_op.ftab_i], *text_op.file_tabs[previous_tab_i]);
					text_op.ftab_i = previous_tab_i;
				}
			}
			else if IsInputMapPress(.TEXT_FILE_TAB_SWAP_RIGHT, .DOWN_THIS_FRAME, game_input) {
				ChangeTextPane(SelectedTextPane.TEXT, text_op, perm.all_data);
				if text_op.ftab_i < text_op.file_tabs.count-1 {
					next_tab_i : int = text_op.ftab_i + 1;
					swap(*text_op.file_tabs[text_op.ftab_i], *text_op.file_tabs[next_tab_i]);
					text_op.ftab_i = next_tab_i;
				}
			}
			//TODO We could allow these to be pressed anywhere and pull it out and that would be ok since they woudl
			//be before the selection ones. Leaving in here so we can use commands in other panes as well but maybe
			//that is more convenient outside and then we also would switch the pane to text pane in here too.
			else if IsInputMapPress(.TEXT_FILE_GOTO_LINE_BAR, .DOWN_THIS_FRAME, game_input) {
				//TODO Should we make this happen even if we are not selecting the text pane?
				if text_op.text_first_bar_type == TextFirstBarType.GOTO_LINE &&
					text_op.selected_text_bar == SelectedTextBarType.SELECTED_FIRST_BAR
				{
					text_op.text_first_bar_type = TextFirstBarType.NONE;
					text_op.selected_text_bar = SelectedTextBarType.NONE;
				} else {
					text_op.text_first_bar_type = TextFirstBarType.GOTO_LINE;
					text_op.selected_text_bar = SelectedTextBarType.SELECTED_FIRST_BAR;
					//We always reset with goto line so itll reset from the find and also if we close and re-open.
					//This is the same behavior as sublime text
					text_op.first_bar_input_text.text_string.count = 0;
					ResetTextCursor(*text_op.first_bar_cursor);
					//TODO We could highlight the text if we go back to it if that is more convenient
				}
				text_op.text_second_bar_type = TextSecondBarType.NONE;
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			}
			else if IsInputMapPress(.TEXT_FILE_FIND_TEXT_BAR, .DOWN_THIS_FRAME, game_input) {
				//TODO Should we make this happen even if we are not selecting the text pane?
				if text_op.text_first_bar_type == TextFirstBarType.FIND_TEXT &&
					text_op.text_second_bar_type == TextSecondBarType.NONE &&
					text_op.selected_text_bar == SelectedTextBarType.SELECTED_FIRST_BAR
				{
					text_op.text_first_bar_type = TextFirstBarType.NONE;
					text_op.selected_text_bar = SelectedTextBarType.NONE;
				} else {
					text_op.text_first_bar_type = TextFirstBarType.FIND_TEXT;
					text_op.selected_text_bar = SelectedTextBarType.SELECTED_FIRST_BAR;
					if tab_cursor.cursor_is_selecting {
						CopySelectedTextToFindBar(text_op, tab_cursor.*, text_file.file_string, perm.text_editor_data, game_input); 
					}
				}
				text_op.text_second_bar_type = TextSecondBarType.NONE;
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			}
			else if IsInputMapPress(.TEXT_FILE_REPLACE_TEXT_BAR, .DOWN_THIS_FRAME, game_input) {
				//TODO Should we make this happen even if we are not selecting the text pane?
				if text_op.text_second_bar_type == TextSecondBarType.REPLACE_TEXT &&
					(text_op.selected_text_bar == SelectedTextBarType.SELECTED_FIRST_BAR ||
					 text_op.selected_text_bar == SelectedTextBarType.SELECTED_SECOND_BAR)
				{
					text_op.text_first_bar_type = TextFirstBarType.NONE;
					text_op.text_second_bar_type = TextSecondBarType.NONE;
					text_op.selected_text_bar = SelectedTextBarType.NONE;
				} else {
					text_op.text_first_bar_type = TextFirstBarType.FIND_TEXT;
					text_op.text_second_bar_type = TextSecondBarType.REPLACE_TEXT;
					text_op.selected_text_bar = SelectedTextBarType.SELECTED_FIRST_BAR;
					if tab_cursor.cursor_is_selecting {
						CopySelectedTextToFindBar(text_op, tab_cursor.*, text_file.file_string, perm.text_editor_data, game_input);
					}
				}
				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);
			}
			/*DOC : We need to put the bar input text after the goto line and find text and replace shortcuts
			so that if we press those shortcuts, then we don't do any input to the bar input instead.
			*/
			else if text_op.selected_text_bar != SelectedTextBarType.NONE {
				if IsKeyboardPress(.ESCAPE, .DOWN_THIS_FRAME, game_input) {
					CloseTextBars(text_op, op_space, perm.text_editor_data);
				}
				else if IsKeyboardPress(.TAB, .DOWN_THIS_FRAME, game_input) &&
					text_op.text_second_bar_type != TextSecondBarType.NONE
				{
					if text_op.selected_text_bar == SelectedTextBarType.SELECTED_SECOND_BAR {
						text_op.selected_text_bar = SelectedTextBarType.SELECTED_FIRST_BAR;
					} else if text_op.selected_text_bar == SelectedTextBarType.SELECTED_FIRST_BAR {
						text_op.selected_text_bar = SelectedTextBarType.SELECTED_SECOND_BAR;
					}
				} 
				else if text_op.text_first_bar_type == TextFirstBarType.GOTO_LINE &&
					IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) 
				{
					line_number, is_integer := string_to_int(text_op.first_bar_input_text.text_string);
					if is_integer {
						/*DOC : We reset the tab cursor here so we remove any highlighting or any other settings
						This is how sublime and notepad does it and seems like the expected behavior.
						BUT we could also just leave it although that's not how other text editors work. 
						We reset the cursor in MoveToLine now explicitly in this case to remember here.
						*/
						// ResetTextCursor(tab_cursor);
						MoveToLine(line_number, text_file.file_string, tab_cursor, center_line=true);
						CloseTextBars(text_op, op_space, perm.text_editor_data);
					} else {
						//TODO We could write an error to the text data bar here somehow saying that is not a line number
						//It would need a timer for a few seconds so it goes away like in sublime text
						SetTextStatus("Invalid goto line number.", text_op);
					}
				}
				else if (IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) ||
						IsInputMapPress(.TEXT_FILE_SINGLE_REPLACE, .DOWN_THIS_FRAME, game_input))
					&&
					(text_op.text_first_bar_type == TextFirstBarType.FIND_TEXT ||
					 text_op.text_second_bar_type == TextSecondBarType.REPLACE_TEXT)
				{
					if IsInputMapPress(.TEXT_FILE_SINGLE_REPLACE, .DOWN_THIS_FRAME, game_input) &&
						text_op.text_second_bar_type == TextSecondBarType.REPLACE_TEXT &&
						tab_cursor.cursor_is_selecting
					{
						selected_text : string = GetSelectedText(tab_cursor.*, text_file.file_string);
						if selected_text == text_op.first_bar_input_text.text_string {
							replace_fie : [1] FrameInputEvent;
							SetTextBlock(text_op.second_bar_input_text.text_string, *replace_fie[0]);
					    	updated_text, updated_input := 
								UpdateFileStringAtCursor(*text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor,
									replace_fie, game_input, perm.text_editor_data);
							assert(updated_text); //sanity check to make sure we did the replace since we know we have selected text
						}
					} 

					/*DOC : We always do a find so even if we do a replace we still search for the next one
					*/
					//TODO Can likely make this a lot more efficient with SIMD from onelivesleft string library
					find_index : int = String.find_index_from_left(text_file.file_string.text_string, 
						text_op.first_bar_input_text.text_string, tab_cursor.char_point);
					if find_index == -1 {
						//If we don't find it then we try from the beggining again
						//TODO THIS IS VERY INEFFICIENT so we we should use onelivesleft library to do search eventually
						find_index = String.find_index_from_left(text_file.file_string.text_string, 
							text_op.first_bar_input_text.text_string, 0);
					} 
					if find_index == -1 {
						SetTextStatus(tprint("Unable to find \"%\"", text_op.first_bar_input_text.text_string), text_op);
					} else {
						SelectText(find_index, find_index + text_op.first_bar_input_text.text_string.count,
							tab_cursor, text_file.file_string);
					}
				}
				else if IsInputMapPress(.TEXT_FILE_REPLACE_ALL, .DOWN_THIS_FRAME, game_input) &&
					text_op.text_second_bar_type == TextSecondBarType.REPLACE_TEXT
				{
					/*DOC : Currently the undo happens for replace in 2 undos since we remove all the text and then set
					the new one. I think it's fine, just maybe put a note somewhere so people know this behavior.
					This is because the undo system only works off of add and remove text actions. If we add a replace action
					eventually, then we can do this and other replaces in 1 shot later.

					//TODO use onelivesleft string library here for efficiency once we use that
					//Maybe we can do it in place with that library OR maybe its better to leave it whole
					//so that the undo undoes all the replacements with one action
					*/
					text_with_replacements, occurences := String.replace(text_file.file_string.text_string,
						text_op.first_bar_input_text.text_string,
						text_op.second_bar_input_text.text_string);
					SetTextStatus(tprint("Made % replacements", occurences), text_op);
					//TODO We could set the cursor to somewhere else if we want but I think setting it to the end of the file is fine for now.
					// cursor_copy := tab_cursor.*;
					// cursor_copy.cursor_is_selecting = false;
					SelectText(0, text_file.file_string.text_string.count, tab_cursor, text_file.file_string);

					replace_all : [1] FrameInputEvent;
					SetTextBlock(text_with_replacements, *replace_all[0]);
			    	updated_text, updated_input := 
						UpdateFileStringAtCursor(*text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor,
							replace_all, game_input, perm.text_editor_data);
					assert(updated_text); //sanity check to make sure we did the replace since we know we have selected text

					//TODO we set replace all to go to end of file for now since we use replace without knowing exactly where
					//If we know where when we use onelivesleft, then we can set it to the last occurence for example
					// tab_cursor.* = cursor_copy;
				}
				else if IsInputMapPress(.TEXT_FILE_BACK_FIND, .DOWN_THIS_FRAME, game_input) &&
					(text_op.text_first_bar_type == TextFirstBarType.FIND_TEXT ||
					 text_op.text_second_bar_type == TextSecondBarType.REPLACE_TEXT)
				{
					//TODO Can likely make this a lot more efficient with SIMD from onelivesleft string library
					if tab_cursor.cursor_is_selecting &&
						tab_cursor.fixed_select_char_point < tab_cursor.char_point
					{
						tab_cursor.cursor_is_selecting = false;
						tab_cursor.char_point = tab_cursor.fixed_select_char_point;
						tab_cursor.cursor_line_char = tab_cursor.fixed_select_line_char;
						tab_cursor.cursor_line_number = tab_cursor.fixed_select_line_number;
					}

					find_index : int = FindIndexFromRight(text_file.file_string.text_string, 
						text_op.first_bar_input_text.text_string, tab_cursor.char_point-1);
					if find_index == -1 {
						//If we don't find it from cursor then we try from the end again
						//TODO THIS IS VERY INEFFICIENT so we we should use onelivesleft library to do search eventually
						find_index = FindIndexFromRight(text_file.file_string.text_string, 
							text_op.first_bar_input_text.text_string, text_file.file_string.text_string.count-1);
					}

					if find_index == -1 {
						SetTextStatus(tprint("Unable to find \"%\"", text_op.first_bar_input_text.text_string), text_op);
					} else {
						SelectText(find_index, find_index + text_op.first_bar_input_text.text_string.count,
							tab_cursor, text_file.file_string);
					}
				}
				else if text_op.selected_text_bar == SelectedTextBarType.SELECTED_FIRST_BAR {
					updated_text, updated_input := 
						UpdateFileStringAtCursor(*text_op.first_bar_input_text, *text_op.first_bar_cursor, 
							game_input.frame_input_events, game_input, perm.text_editor_data, single_line=true);
					//Don't need this, just leaving here to maybe reuse for replace but we can remove it once thats implemented and tested
					// if updated_text && text_op.first_bar_input_text.text_string.count > 0 {
					// 	ci : int = 0;
					// 	//NOTE : This will likely only happen once since 1 char per frame so no need to optimize over many chars
					// 	//Going till count-1 ensures we dont do a memcpy of data passed count and then we check the last char after.
					// 	while ci < text_op.first_bar_input_text.text_string.count-1 {
					// 		if !is_digit(text_op.first_bar_input_text.text_string[ci]) {
					// 			current_data : *u8 = text_op.first_bar_input_text.text_string.data + ci;
					// 			next_ci : int = ci + 1;
					// 			next_data : *u8 = text_op.first_bar_input_text.text_string.data + next_ci;
					// 			mov_size : int = text_op.first_bar_input_text.text_string.count - next_ci;
					// 			memcpy(current_data, next_data, mov_size);
					// 			text_op.first_bar_input_text.text_string.count -= 1;
					// 		}
					// 		ci += 1;
					// 	}
					// 	//We check last char separately since we only have to lower count by 1 without any memcpy
					// 	if text_op.first_bar_input_text.text_string.count > 0 &&
					// 		!is_digit(text_op.first_bar_input_text.text_string[text_op.first_bar_input_text.text_string.count-1]) 
					// 	{
					// 		text_op.first_bar_input_text.text_string.count -= 1;
					// 	}
					// }
				}
				else if text_op.selected_text_bar == SelectedTextBarType.SELECTED_SECOND_BAR {
					updated_text, updated_input := 
						UpdateFileStringAtCursor(*text_op.second_bar_input_text, *text_op.second_bar_cursor, 
							game_input.frame_input_events, game_input, perm.text_editor_data, single_line=true);
				}
			} 
			else {
				/*DOC : We only want to set input if we did not hit a hotkey. Should likely also check other hotkeys
			before here as well to prevent any weird behavior like changing files or something else and updating
			the text of the wrong file or something else.
			*/
			// else {
				/*TODO
		    		We could pass in all_lines_of_code here if all_lines_of_code would be LineOfCode with
		    		the starting index of the line in the file. Then things like up and down arrow movement
		    		would be faster because we would not need to search the new line indices every time.

		    		Can do this if we need to pass back the start index of the line anyways for things like
		    		error.

		    		TODO We could prevent this from updating if we hit a hotkey to avoid weird issues.
		    		TODO Prevent this from updating while in debug mode to avoid inconsistent data issues.

		    		TODO WE COULD ALSO ONLY UPDATE TEXT IF we don't have other button presses.
		    		So we could check the events for that. Currently we separate text input at the system level
		    		so we could see other ways of doing that so we only update text here if that is the only thing we have.
		    		ALSO to make sure the "\n" is still added to text input with enter somewhere.
		    	*/
		    	updated_text, updated_input := 
					UpdateFileStringAtCursor(*text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor, 
						game_input.frame_input_events, game_input, perm.text_editor_data);

				//TODO Leaving here in case we want convenient x_movement without adjusting the bounds to eh char_point
				//There is no max right bound. Could add that later if needed based on size of text pane.
				//Can put this in UpdateFileStringAtCursor but then we need to not auto_adjust_x_bound on the bottom input_date.
				//Leaving here for now for convenience. Do we really need for single line input?
				#if 1 {
				if !(updated_text || updated_input) {
					// if keyboard.only_ctrl_down && keyboard.o_button.is_down_with_pause {
					if IsInputMapPress(.TEXT_FILE_RIGHT_CHAR_BOUND, .IS_DOWN_WITH_PAUSE, game_input) {
						text_op.file_tabs[text_op.ftab_i].tab_cursor.right_char_bound += 1;
						text_op.file_tabs[text_op.ftab_i].tab_cursor.left_char_bound += 1;
					} 
					// else if keyboard.only_ctrl_down && keyboard.u_button.is_down_with_pause 
					else if IsInputMapPress(.TEXT_FILE_LEFT_CHAR_BOUND, .IS_DOWN_WITH_PAUSE, game_input)
						&& text_op.file_tabs[text_op.ftab_i].tab_cursor.left_char_bound > 0
					{
						text_op.file_tabs[text_op.ftab_i].tab_cursor.right_char_bound -= 1;
						text_op.file_tabs[text_op.ftab_i].tab_cursor.left_char_bound -= 1;
					}
				}
				}
			// }
			}
		} 
		else if text_op.selected_pane == SelectedTextPane.WATCH {
			selected_wd : WatchData = text_op.watch_data_rows[text_op.highlighted_name_index];
			updated_text : bool = false;
			updated_input : bool = false;
			if selected_wd.watch_indent == 0 {
				is_text_input : bool = false;
				//TODO FROM HERE update text block and input and use events instead and check here for
				//for text input maybe more systematically with a function.
				//Also only start watch editing if we have text_input and if we are already watch editing
				//then we can accept any editing.
				//ALSO test_input_states_to_end should be in test data instead
				//We need to do this here for clarity. Right now it only does not work because the
				//edit_watch_name string count == 0 which is not clear at all
				// for game_input.frame_input_events if it.type == .TEXT_INPUT || it.event_type == .TEXT_BLOCK {
				// 	is_text_input = true;
				// 	break;
				// }
				// if is_text_input {
				updated_text, updated_input = 
					UpdateFileStringAtCursor(*text_op.edit_watch_name, *text_op.watch_cursor, 
						game_input.frame_input_events, game_input, perm.text_editor_data, single_line=true);
				if updated_text {
					text_op.is_watch_editing = true;
				}
				// }
			}

			//TODO FROM HERE set debugging and pane switching hotkeys to only work if we are in debug mode
			//ALSO maybe clamp watch data rows and update tests if needed
			//maybe we don't allow code running if not in debug mode for now.
			//THEN START TESTING WITH MOUSE INPUT OR DO TABS FIRST
			//also remove old code on bottom and around here on cleanup AFTER TESTING
			//ALSO DOC the cursor_left_mouse_holding since we cant if we click off (DID THIS ON FUNCTION)
			//Then pull out watch data editing to reuse for mouse setting and also watch data dropdown
			//and then do call stack and assembly and then mouse wheel scrolling
			//TODO FROM HERE Could generalize mouse scrolling since they are all the same and just pass in the bounds check
			//then we only need to test 1 to makes sure its working
			//Should we double check tests to make sure all final cases are running?

			//TODO If code is running then we want return_enter to drop the data down for enter
			//TODO I don't think we need to check this here since if we are watch editing then we don't
			//do anything unless we press these buttons and if we are not then we also don't have 
			//updated text from above anyways.
			// if !(updated_text || updated_input) {
			if text_op.is_watch_editing {
				if IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) ||
					IsKeyboardPress(.ARROW_DOWN, .DOWN_THIS_FRAME, game_input) ||
					IsKeyboardPress(.ARROW_UP, .DOWN_THIS_FRAME, game_input)
				{
					//TODO We could make the enter go down always if that feels more natural and then we don't
					//need the return value from this function and can remove it altoegher
					added_watch_data : bool = SetHighlightedWatchToWatchEditAndEvaluate(text_op, perm.all_data); 
					// if IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) {
					if added_watch_data && IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) {
						//NOTE : We only make enter move down if we add watch data BUT we could just always 
						//make it move down and then we don't need the added_watch_data return value
						text_op.highlighted_name_index += 1;
					}
					else if IsKeyboardPress(.ARROW_UP, .IS_DOWN_WITH_PAUSE, game_input) {
						text_op.highlighted_name_index -= 1;
					} 
					else if IsKeyboardPress(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, game_input) {
						text_op.highlighted_name_index += 1;
					}
					text_op.highlighted_name_index = Clamp(0, text_op.highlighted_name_index, text_op.watch_data_rows.count-1);
					AdjustTextBoundsToIndex(text_op.highlighted_name_index,
						*text_op.start_watch_index, *text_op.end_watch_index);
				}
			} else {
				if IsKeyboardPress(.DELETE, .DOWN_THIS_FRAME, game_input) && text_op.watch_data_rows.count > 0 
					//This prevents us from deleting the last one. Can still create a new one by typing and going down.
					&& text_op.highlighted_name_index < text_op.watch_data_rows.count-1
					&& selected_wd.watch_indent == 0
				{
					//DOC : We remove row and sub rows in 1 shot here. Just need to optimize remove row range later.
					#if 1 {
					count : int = 1 + GetSubRowCount(text_op.highlighted_name_index, text_op, 0);
					RemoveWatchRowRange(text_op.highlighted_name_index, count, text_op);
					//TODO Could just do this if we have issues but above is more efficient
					// RemoveWatchSubRows(text_op.highlighted_name_index, text_op, 0);
					// RemoveWatchData(text_op.highlighted_name_index, text_op);
					} else {
					RemoveWatchData(text_op.highlighted_name_index, text_op);
					//TODO could do this with 2 memcpys moving them to pool and then moving the ones after over
					//and have a function that removes by range and reuse it for editing text as well
					//and also later when we change function stack if the var is different type or other changes
					while text_op.highlighted_name_index < text_op.watch_data_rows.count-1
						&& text_op.watch_data_rows[text_op.highlighted_name_index].watch_indent > 0
					{
						RemoveWatchData(text_op.highlighted_name_index, text_op);
					}
					}

					AdjustTextBoundsToIndex(text_op.highlighted_name_index,
						*text_op.start_watch_index, *text_op.end_watch_index);
				}		
				else if IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) && 
					text_op.exec_info.exec_state == .IS_DEBUG_STOP 
				{
					DropWatchRow(text_op.highlighted_name_index, text_op, perm.all_data);
				}
				else if IsInputMapPress(.DEBUG_WATCH_EDIT, .DOWN_THIS_FRAME, game_input) && 
					selected_wd.watch_indent == 0
				{
					//TODO This is the same as double-click so we can make a function from there but maybe
					//I remove the double click eventually if that is too annoying.
					//PART of me wants to remove the double click since it is annoying to test and use relative to ctrl+e
					//If we do remove it then I can just move this code in here directly.
					//We did comment out double click I will leave like this fro now, but we can move it back in here if we don't use it
					DebugWatchEditNameMode(selected_wd, text_op);
				}
				//TODO We move this whether we are editing or not
				else if IsKeyboardPress(.ARROW_UP, .IS_DOWN_WITH_PAUSE, game_input) && text_op.watch_data_rows.count > 0 {
					text_op.highlighted_name_index -= 1;
					if text_op.highlighted_name_index < 0 {
						text_op.highlighted_name_index = 0;
					}
					AdjustTextBoundsToIndex(text_op.highlighted_name_index,
							*text_op.start_watch_index, *text_op.end_watch_index);
				} else if IsKeyboardPress(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, game_input) && text_op.watch_data_rows.count > 0 {
					text_op.highlighted_name_index += 1;
					if text_op.highlighted_name_index >= text_op.watch_data_rows.count {
						text_op.highlighted_name_index = text_op.watch_data_rows.count - 1;
					}
					AdjustTextBoundsToIndex(text_op.highlighted_name_index,
							*text_op.start_watch_index, *text_op.end_watch_index);
				}
			}
			// }
			//TODO Do we want PosMod or just limit it between 0 and watch_data_rows.count?
			//Since we use down_with_pause it can be a bit confusing to have PosMod cycle back on the bottom.
			//But PosMod feels more fluid in some ways... We could make this a settable option somewhere.
			//TODO We can remove this once we know the above is working.
			#if 0 {
			#if 1 {
			text_op.highlighted_name_index = 
				PosMod(text_op.highlighted_name_index, text_op.watch_data_rows.count);
			} else {
			text_op.highlighted_name_index = 
				Clamp(0, text_op.highlighted_name_index, text_op.watch_data_rows.count-1);
			}
			}

			#if 0 {
			if text_op.highlighted_name_index < text_op.start_watch_index {
				index_diff : int = text_op.start_watch_index - text_op.highlighted_name_index;
				text_op.start_watch_index -= index_diff;
				text_op.end_watch_index -= index_diff;
			} else if text_op.highlighted_name_index > text_op.end_watch_index {
				index_diff : int = text_op.highlighted_name_index - text_op.end_watch_index;
				text_op.start_watch_index += index_diff;
				text_op.end_watch_index += index_diff;
			}
			}
		} 
		else if text_op.selected_pane == SelectedTextPane.DISASSEMBLY {
			if IsKeyboardPress(.ARROW_UP, .IS_DOWN_WITH_PAUSE, game_input) {
				text_op.highlighted_disasm_index -= 1;
				if text_op.highlighted_disasm_index < 0 {
					text_op.highlighted_disasm_index = 0;
				}
				AdjustTextBoundsToIndex(text_op.highlighted_disasm_index,
					*text_op.start_disasm_index, *text_op.end_disasm_index);
			} 
			else if IsKeyboardPress(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, game_input) {
				//TODO Eventually we can grab this and change this check once we have > 1 comp_data
				if text_op.text_comp_data != null && text_op.text_comp_data.disassembly_loc.count > 0 {
					text_op.highlighted_disasm_index += 1;
					if text_op.highlighted_disasm_index >= text_op.text_comp_data.disassembly_loc.count {
						text_op.highlighted_disasm_index = text_op.text_comp_data.disassembly_loc.count-1;
					}
					AdjustTextBoundsToIndex(text_op.highlighted_disasm_index, 
						*text_op.start_disasm_index, *text_op.end_disasm_index);
				}
			}
			// if text_op.exec_info.exec_mode == ExecutionMode.DEBUG && keyboard.f9.down_this_frame {
			else if text_op.exec_info.exec_mode == ExecutionMode.DEBUG && 
				IsInputMapPress(.DEBUG_SET_BREAKPOINT, .DOWN_THIS_FRAME, game_input)
			{
				//TODO We could pull this out as function and test it for convenience and also
				//then we can use it to set break_points from other places like tests or somewhere else in the code
				//DO THAT ONCE WE KNOW THIS IS HOW IT WILL WORK AND IT WORKS IN ALL CASES
				//Pulling it out solidifies the functionality which we only want to do once most things work

				#if 1 {
				//TODO Maybe we can remove this functon and just leave this here instead if the mouse functionality
				//will be in the same place but lets see once we move that up here.
				PressAsmBreakpoint(text_op.highlighted_disasm_index, text_op);

				} else {
				found_breakpoint : bool = false;
				for text_op.exec_info.debug_info.break_points {
					if it.asm_index == text_op.highlighted_disasm_index {
						//TODO Do a memcpy remove here once we implement it in general.
						array_ordered_remove_by_index(*text_op.exec_info.debug_info.break_points, it_index);
						found_breakpoint = true;
						break;
					}
				}

				if !found_breakpoint {
					//TODO We could make this CreateAsmBreakpoint to keep it consistent everywhere
					//and then also PressAsmBreakpoint so we remove it if there is already one there.
					//Then we could unit test that function as well.
					break_point : *DebugBreakpoint = array_add(*text_op.exec_info.debug_info.break_points);
					break_point.bp_type = BreakpointType.BP_ASM;
					break_point.asm_index = text_op.highlighted_disasm_index;
					break_point.end_asm_index = text_op.highlighted_disasm_index;
					//TODO We don't need to set line_number for BP_ASM anymore
					//TODO Choose the comp_data instead once we have multiple compilation data possible
					// if text_op.text_comp_data != null && text_op.text_comp_data.all_debug_lines.count > 0 {
					// 	debug_line := GetDebugLineAsm(text_op.highlighted_disasm_index, text_op.text_comp_data);
					// 	break_point.line_number = debug_line.line_number;
					// }
				}
				}
			}

			//TODO Can remove this if AdjustTextBoundsToIndex works above
			#if 0 {
			if IsKeyboardPress(.ARROW_UP, .IS_DOWN_WITH_PAUSE, game_input) ||
				IsKeyboardPress(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, game_input)
			{
				//TODO Would have to change this if we allowed for mouse scrolling movement eventually.
				if text_op.highlighted_disasm_index < text_op.start_disasm_index {
					index_diff : int = text_op.start_disasm_index - text_op.highlighted_disasm_index;
					text_op.start_disasm_index -= index_diff;
					text_op.end_disasm_index -= index_diff;
				} else if text_op.highlighted_disasm_index > text_op.end_disasm_index {
					index_diff : int = text_op.highlighted_disasm_index - text_op.end_disasm_index;
					text_op.start_disasm_index += index_diff;
					text_op.end_disasm_index += index_diff;
				}
			}
			}
		} 
		else if text_op.selected_pane == SelectedTextPane.COMPILER_CONSOLE {
			//TODO This should also have text_input since then we can use it very generally
			//to move around the space and other space with just text. Can also allow highlighting
			//words and then copy/pasting thme in the compiler console to move there or even have so
			//hotkeys that do something directly / bring you somewhere directly when you have text highlighted.
			// if keyboard.arrow_up.is_down_with_pause {
			if IsKeyboardPress(.ARROW_UP, .IS_DOWN_WITH_PAUSE, game_input) &&
				text_op.console_tsl.start_file_line_index > 0
			{
				text_op.console_tsl.start_file_line_index -= 1;
				// text_op.comp_cam.world_pos.y += 1;
				// if text_op.comp_cam.world_pos.y > 0 {
				// 	text_op.comp_cam.world_pos.y = 0;
				// }
			} 
			// else if keyboard.arrow_down.is_down_with_pause {
			else if IsKeyboardPress(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, game_input) &&
				//NOTE the start+viewable_lines here == end_index and not count so we need to subtract 1.
				//We could allow the bottom lines as well if needed
				(text_op.console_tsl.start_file_line_index + text_op.console_tsl.viewable_lines_from_zero <
				 text_op.console_tsl.split_lines.count-1)
			{
				text_op.console_tsl.start_file_line_index += 1;
				// if text_op.text_comp_data != null && text_op.text_comp_data.all_compiler_errors.count > 0 {
				// 	text_op.comp_cam.world_pos.y -= 1;
				// 	//TODO Can put a cap here but will leave open for now since we would have to compute
				// 	//the number of lines with wraparound. Can put that in a function if needed.
				// }
			}	
			else if IsInputMapPress(.TEXT_COPY, .DOWN_THIS_FRAME, game_input) {
				CopyTSLToClipboard(text_op.console_tsl);
			}
		} else if text_op.selected_pane == SelectedTextPane.CALL_STACK && 
			text_op.exec_info.exec_state == .IS_DEBUG_STOP 
		{
			if IsKeyboardPress(.ARROW_UP, .IS_DOWN_WITH_PAUSE, game_input) {
				text_op.highlighted_call_stack_index -= 1;
				if text_op.highlighted_call_stack_index < 0 {
					text_op.highlighted_call_stack_index = 0;
				}
				//Note : Having this here instead of the bottom is much clearer overall
				AdjustTextBoundsToIndex(text_op.highlighted_call_stack_index, 
					*text_op.start_call_stack_index, *text_op.end_call_stack_index);
			} 
			else if IsKeyboardPress(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, game_input) {
				text_op.highlighted_call_stack_index += 1;
				if text_op.highlighted_call_stack_index >= text_op.exec_info.debug_info.debug_call_stack.count {
					text_op.highlighted_call_stack_index = text_op.exec_info.debug_info.debug_call_stack.count-1;
				}
				AdjustTextBoundsToIndex(text_op.highlighted_call_stack_index, 
					*text_op.start_call_stack_index, *text_op.end_call_stack_index);
			} 
			else if IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) {
				SelectHighlightedCallFrame(text_op, perm.all_data);
			}

			//TODO If we store the rectangle then we can move the camera if we are outside the rectangle
			//which might be simpler than this.
			//TODO Remove this if AdjustTextBoundsToIndex works above
			#if 0 {
			if text_op.highlighted_call_stack_index < text_op.start_call_stack_index {
				index_diff : int = text_op.start_call_stack_index - text_op.highlighted_call_stack_index;
				text_op.start_call_stack_index -= index_diff;
				text_op.end_call_stack_index -= index_diff;
			} else if text_op.highlighted_call_stack_index > text_op.end_call_stack_index {
				index_diff : int = text_op.highlighted_call_stack_index - text_op.end_call_stack_index;
				text_op.start_call_stack_index += index_diff;
				text_op.end_call_stack_index += index_diff;
			}
			}
		}
	}
}
else if op_space.op_space_external_type == OpSpaceExternalType.terminal {
	//TODO Should pull this out of AllData
	//TODO I think we can remove this altogether now since we have text input for specific op spaces and single lines now
	//TODO This is sort of a hack it prevents the op and world cam from moving but we should just use this op space cam
	//or something and not have it move
 	// perm.all_data.active_cam_id = default_base_cam.id;
	// perm.all_data.input_check.is_writing_code = true;

	term_op : *TerminalOpSpaceData = ArrayFindFirstByNameId(perm.all_data.all_terminal_op_space_data,
		op_space.id, "op_space_id");

	term_data : *TerminalData = *perm.terminal_data;

	is_terminal_mouse_input : bool = false;
	if is_resizing_op_space {
		//TODO Should we just us base_render_group? We update pixels_per_square everywhere on zoom anyways...
		ResizeTerminalOpSpace(term_op, op_space.world_size, renderer_data.base_render_group.pixels_per_square, 
			perm.text_editor_data, perm.terminal_data);
		is_terminal_mouse_input = true;
	}

	op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);

	mouse_y_diff : float = MouseYDiff(term_op.terminal_tsl.y_start_top, op_mouse.y, term_op.terminal_tsl.cursor_height);
	mouse_line_number : int = MouseLineNumber(mouse_y_diff, term_op.terminal_tsl.line_height, 
		term_op.terminal_tsl.start_file_line_index, term_op.terminal_tsl.split_lines.count);
	mouse_line_string : string;
	if term_op.terminal_tsl.split_lines.count > 0 {
		mouse_line_string = term_op.terminal_tsl.split_lines[mouse_line_number].split_string;
	}
	mouse_line_char : int = MouseLineChar(op_mouse.x, term_op.terminal_tsl.x_start_left, 
		perm.text_editor_data.code_font_1_char_width_world, mouse_line_string.count);	
	// if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
	// 	print("mouse_line_char=%, mouse_line_number=%\n", mouse_line_char, mouse_line_number);
	// }
	// mouse_line_start_char_point : int = StartCharPointOfLineNumber(mouse_line_number, text_file.file_string);
	// mouse_char_point : int = mouse_line_start_char_point + mouse_line_char;

	terminal_cursor : *TextCursor = *perm.terminal_data.terminal_cursor;
	if IsInRectangle(op_mouse, term_op.op_rect) && !is_terminal_mouse_input {
		// if game_input.mouse_wheel != 0 {
		if IsMouseWheelWithoutModifiers(game_input) {
			is_terminal_mouse_input = true;
			//TODO We can pull this out if we need to use it somewhere else here, can remove if not needed then
			// cmd_line_count : int = TerminalCmdLineCount(perm.terminal_data.terminal_command_string.text_string.count, term_op.terminal_tsl.line_char_count);
			cmd_start_line : int = TerminalCmdStartLine(perm.terminal_data, term_op.*);
			//We +1 here because it is the count needed and not the actual index
			max_scrollable_line : int = cmd_start_line+1 + term_op.terminal_tsl.viewable_lines_from_zero;
			//Dummy variable to keep the mouse text scrolling consistent
			end_line_index : int = term_op.terminal_tsl.start_file_line_index + term_op.terminal_tsl.viewable_lines_from_zero;
			MouseScrollTextBounds(*term_op.terminal_tsl.start_file_line_index, *end_line_index, max_scrollable_line, game_input.mouse_wheel);
		}
		else if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
			//TODO We can check which lines were on and then do mouse for highlight cursor or terminal cursor
			is_terminal_mouse_input = true;
			term_op.terminal_tsl.cursor_is_selecting = false;
			terminal_cursor.cursor_is_selecting = false;
			if mouse_line_number < term_op.terminal_tsl.split_lines.count {
				// print("mouse_y_diff=%, mouse_line_diff_float=%, mouse_y_int=%, mouse_line_number=%\n", 
				// 	mouse_y_diff, mouse_line_diff_float, mouse_line_diff_int, mouse_line_number);
				// print("char=\"%\",char_pos=%\n", loc[char_pos_int], char_pos);
				//NOTE : We don't use char_point here since we just use line number and line char
				// term_op.terminal_tsl.char_point = mouse_char_point;
				term_op.terminal_tsl.cursor_line_number = mouse_line_number;
				//TODO Leaving here for testing can remove once were done
				// print("term_op.terminal_tsl.char_point=%\n", term_op.terminal_tsl.char_point);
				// print("mouse_line_number=%\n", mouse_line_number);
				//TODO If we move this into UpdateFileStringAtCursor then we can compute it there OR NOT if we dont.
				term_op.terminal_tsl.cursor_line_char = mouse_line_char;
				term_op.terminal_tsl.cursor_left_mouse_holding = true;
			}
			//DOC : In case we press on a tab char at the beginning or end of a line OR a half line on top or bottom
			//then we will adjust the bounds so we can see it.
			//TODO We could update cursor_line_char in here based on char point if that helps keep things consistent.
			// UpdateCursorLineCharAndBounds(tab_cursor, text_file.file_string);
		}
	}
	TextSplitLineMouseHolding(mouse_line_char, mouse_line_number, *term_op.terminal_tsl, game_input);
	if term_op.terminal_tsl.cursor_left_mouse_holding is_terminal_mouse_input = true;


	if !is_terminal_mouse_input {
		is_highlight_select_copying : bool = term_op.terminal_tsl.cursor_is_selecting &&
			IsInputMapPress(.TEXT_COPY, .DOWN_THIS_FRAME, game_input);

		updated_text : bool = false;
		updated_input : bool = false;
		if !is_highlight_select_copying {
			updated_text, updated_input = UpdateFileStringAtCursor(*term_data.terminal_command_string, *term_data.terminal_cursor,
				game_input.frame_input_events, game_input, perm.text_editor_data, single_line = true);
		}

		cmd_start_line : int = TerminalCmdStartLine(perm.terminal_data, term_op.*);
		if updated_text {
			term_op.terminal_tsl.cursor_is_selecting = false;
			//DOC : we need to remove split lines here before updating cmd with start since we want to remove
			//whatever was there before since we have not update the cmd_with_start_string yet so that will
			//be the same size as it used to be since we only update the terminal_command_string.
			//then we don't remove anything
			RemoveSplitCmdLines(perm.all_data.all_terminal_op_space_data, perm.terminal_data);
			//NEED TO UPDATE cmd string with start since we updated the command string
			UpdateCmdStringWithStart(*perm.terminal_data);
			AddBackCmdSplitLine(perm.all_data.all_terminal_op_space_data, perm.terminal_data);

			CopyToCurrentCmdHistory(term_data.terminal_command_string.text_string, term_data);
		}
		else if updated_input {
			term_op.terminal_tsl.cursor_is_selecting = false;
			SetTerminalCmdLineDiffInBounds(term_op);
		}
		else if IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) {
			term_op.terminal_tsl.cursor_is_selecting = false;

			/*DOC : The UpdateCmdStringWithStart is run before the terminal events and so is the
			RemoveSplitCmdLines and then we add it back and set the diff after the terminal events.
			This keeps it consistent with adding terminal events separately and here at the same time.
			*/
			terminal_event : TerminalEvent;
			terminal_event.command_string = copy_temporary_string(perm.terminal_command_string.text_string);
			array_add(*perm.all_data.all_terminal_events, terminal_event);
			perm.terminal_command_string.text_string.count = 0;
		
			ResetTextCursor(*perm.terminal_cursor);
		}
		else if IsKeyboardPress(.ARROW_UP, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, game_input) &&
	  	   term_op.terminal_tsl.start_file_line_index > 0
		{
			term_op.terminal_tsl.start_file_line_index -= 1;
			// perm.terminal_cam.world_pos.y += term_op.terminal_tsl.line_height;
			// op_2D_cam.world_pos.y += term_op.terminal_tsl.line_height;
		} 
		else if IsKeyboardPress(.ARROW_DOWN, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, game_input) &&
	   	// term_op.terminal_tsl.start_file_line_index < term_op.terminal_tsl.split_lines.count
	   	term_op.terminal_tsl.start_file_line_index < cmd_start_line
		{
			term_op.terminal_tsl.start_file_line_index += 1;
			// perm.terminal_cam.world_pos.y -= term_op.terminal_tsl.line_height;
			// op_2D_cam.world_pos.y -= term_op.terminal_tsl.line_height;
		}
		else if is_highlight_select_copying {
			CopyTSLToClipboard(term_op.terminal_tsl);
		}
		else if term_data.cmd_history_count > 0 &&
			(IsKeyboardPress(.ARROW_UP, .IS_DOWN_WITH_PAUSE, game_input) ||
			 IsKeyboardPress(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, game_input))
		{
			previous_history_offset : int = term_data.history_select_offset;
			if IsKeyboardPress(.ARROW_UP, .IS_DOWN_WITH_PAUSE, game_input) {
				term_data.history_select_offset = min(term_data.history_select_offset+1, term_data.cmd_history_count-1);
			} else if IsKeyboardPress(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, game_input) {
				term_data.history_select_offset = max(term_data.history_select_offset-1, 0);
			}

			//We only need to update if we actualy changed the history offset. I noticed this because the cursor
			//would move to the end if it was at the history limit but we still kept going which it should not do
			if previous_history_offset != term_data.history_select_offset {
				history_select_index : int =
					PosMod(term_data.next_cmd_history_index-term_data.history_select_offset, 
						term_data.terminal_cmd_history.count);

				history_cmd : string = term_data.terminal_cmd_history[history_select_index];
				memcpy(term_data.terminal_command_string.text_string.data,
					history_cmd.data, history_cmd.count);
				term_data.terminal_command_string.text_string.count = history_cmd.count;

				ResetTextCursor(*term_data.terminal_cursor);
				term_data.terminal_cursor.char_point = history_cmd.count;
				term_data.terminal_cursor.cursor_line_char = history_cmd.count;

				RemoveSplitCmdLines(perm.all_data.all_terminal_op_space_data, term_data.*);
				//NEED TO UPDATE cmd string with start since we updated the command string
				UpdateCmdStringWithStart(term_data);
				AddBackCmdSplitLine(perm.all_data.all_terminal_op_space_data, term_data.*);
			}
		}
	}
}
else if op_space.op_space_external_type == OpSpaceExternalType.space_3d {
op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
	op_space.id, "op_space_id");
assert(found_op_3D);

//TODO I think we can remove this now once we but the is moving op space on top and then don't register input 
//for any op space if the op space is moving
#if 0 {
moving_op_space, is_moving_op_space := ArrayFindFirstByNameId(perm.all_data.all_moving_op_spaces,
	op_space.id, "op_space_id");
	//TODO We could do this here instead of in the 3D rendering and then we would not have to do it every frame
	//but the other way seems more consistent since we keep track with the op_space.
if is_moving_op_space {
	op_3D.op_space_3D.chord_s3_world_pos = op_space.world_offset;
 	op_3D.op_space_3D.viewport.cam_offset = WorldSpaceToCameraSpace(op_3D.op_space_3D.chord_s3_world_pos, default_base_cam);
}
}
//TODO Should we also prevent input on moving 3d op space here? We could moving above so we don't have to fetch it
//in an array but maybe that's fine as well and put moving above so we can move multiple op spaces at once eventually.
if is_resizing_op_space {
	ResizeOpSpace3D(op_space.world_size, *op_3D.op_space_3D);
} else {
	//TODO WE COULD PREVENT 3d input if needed given another input
	//TODO can we move this code later right before the rendering and then only compute mvp matrices once per cube and edge
	//TODO also look to see if new multiplication operators can be used with rendering and transform matrices
	//TODO Prevent this and other mouse buttons below while resizing 3d spaces too.
	// if !is_moving_op_space {
		//TODO This should be ctrl click and maybe this should be right click and the one below should be left click
		// if game_input.MouseButtons[0].EndedDown {
	if IsInputDown(.MOUSE_BUTTON_LEFT, game_input) && IsInputDown(.CTRL, game_input) {
		//TODO could do mouse position every frame with previous frame to store cube transform for efficiency
    	if op_3D.op_space_3D.mouse_start == MOUSE_DEFAULT op_3D.op_space_3D.mouse_start = mouse_cam;
    	delta_mouse_cam : Vector2F = mouse_cam - op_3D.op_space_3D.mouse_start;
    	norm_delta_mouse_cam : Vector2F = UnitVector(delta_mouse_cam);
    	// rotated_norm : Vector3F = op_3D.op_space_3D.mouse_rotate * MakeV3F(norm_delta_mouse_cam, 0);
		/**
			Following 3 lines are the crux of the rotation maths.
			We convert the screen/camera space to world space using the camera transform.
			Then we convert from world space to grid space by using the inverse of the grid space transform
			which is the mouse_rotate transform.
			screen/camera space -> world space -> grid space
		**/
    	perp_norm : Vector2F = PerpendicularClockwise(norm_delta_mouse_cam);
		perp : Vector3F = UnitVector(Inverse(op_3D.op_space_3D.mouse_rotate) * GetTransform(op_3D.op_space_3D.cam_trans) * MakeV3F(perp_norm, 0));
		//TODO should we do this directly every frame were moving? would that introduce normalization errors in the matrix?
		//TODO should we only try to do it every frame with Quaternions?
	   op_3D.op_space_3D.temp_mouse_rotate = MakeRotation(Length(delta_mouse_cam) * PI/100, perp);
	   op_3D.op_space_3D.is_mouse_rotating = true;
	} 
	// else if game_input.MouseButtons[0].up_this_frame {
 	else if op_3D.op_space_3D.is_mouse_rotating {
		op_3D.op_space_3D.mouse_rotate *= op_3D.op_space_3D.temp_mouse_rotate;
		op_3D.op_space_3D.temp_mouse_rotate = Matrix3F_Identity;
		op_3D.op_space_3D.is_mouse_rotating = false;
		op_3D.op_space_3D.mouse_start = MOUSE_DEFAULT;
	}
	// }
	//TODO This should be ctrl/shift click
	// if game_input.MouseButtons[1].EndedDown {
	// if IsInputDown(.MOUSE_BUTTON_RIGHT, game_input) && IsInputDown(.CTRL, game_input) {
	else if IsInputDown(#char "C", game_input) && IsInputDown(.ALT, game_input) {
    	if op_3D.op_space_3D.mouse_start == MOUSE_DEFAULT op_3D.op_space_3D.mouse_start = mouse_cam;
    	delta_mouse_cam : Vector2F = mouse_cam - op_3D.op_space_3D.mouse_start;
    	norm_delta_mouse_cam : Vector2F = UnitVector(delta_mouse_cam);
    	/**
			Here we convert from screen/camera space -> world space.
    	**/
		perp : Vector3F = GetTransform(op_3D.op_space_3D.cam_trans) * MakeV3F(PerpendicularCounterClockwise(norm_delta_mouse_cam), 0);
		op_3D.op_space_3D.temp_cam_rotate = MakeRotation(Length(delta_mouse_cam) * PI/150, perp);
		op_3D.op_space_3D.mouse_cam_is_moving = true;
		// perp : Vector3F = MakeV3F(norm_delta_mouse_cam, 0);
		// op_3D.op_space_3D.temp_cam_rotate = MakeRotationAssumeDirNormal(Vector3F.{1, 0, 0}, Vector3F.{}, perp);
	} 
	// else if game_input.MouseButtons[1].up_this_frame {
	// else if IsKeyboardPress(.MOUSE_BUTTON_RIGHT, .UP_THIS_FRAME, game_input) {
	else if op_3D.op_space_3D.mouse_cam_is_moving {
		MultiplyTransform(op_3D.op_space_3D.temp_cam_rotate, *op_3D.op_space_3D.cam_trans);
		op_3D.op_space_3D.temp_cam_rotate = Matrix3F_Identity;
		op_3D.op_space_3D.mouse_start = MOUSE_DEFAULT;
		op_3D.op_space_3D.mouse_cam_is_moving = false;
	}
	//TODO Could put an else here if we want to prevent movement while rotating or camera moving for 3d transform safety

	//TODO we could pass these in if we want to allow the speed to be adjustable
	DEFAULT_RIGHT_ROTATION_3D :: #run MakeRotationY(PI/150);
	DEFAULT_LEFT_ROTATION_3D :: #run MakeRotationY(-PI/150);
	// if keyboard.ActionRight.EndedDown {
	if IsInputDown(#char "L", game_input) {
		MultiplyTransform(DEFAULT_RIGHT_ROTATION_3D, *op_3D.op_space_3D.cam_trans);
		// MultiplyTransform(MakeRotationY(PI/150), *op_3D.op_space_3D.cam_trans);
		// op_3D.op_space_3D.cam_transform *= MakeRotationY(PI/150);
	}
	// if keyboard.ActionLeft.EndedDown {
	if IsInputDown(#char "J", game_input) {
		MultiplyTransform(DEFAULT_LEFT_ROTATION_3D, *op_3D.op_space_3D.cam_trans);
		// MultiplyTransform(MakeRotationY(-PI/150), *op_3D.op_space_3D.cam_trans);
		// op_3D.op_space_3D.cam_transform *= MakeRotationY(-PI/150);
	}

	//TODO Could compute these only if we have 1 of the inputs down
	//TODO Could also allow the speed to be adjustable in settings maybe once we add them to dynamic libraries
	dir_camera_x := op_3D.op_space_3D.temp_cam_rotate * GetTransform(op_3D.op_space_3D.cam_trans) * Vector3F.{1,0,0};
	delta_cam : Vector3F;
	// if keyboard.Right.EndedDown {
	if IsInputDown(#char "D", game_input) {
		delta_cam += dir_camera_x;
	}
	// if keyboard.Left.EndedDown {
	if IsInputDown(#char "A", game_input) {
		delta_cam -= dir_camera_x;
	}

	dir_camera_y := op_3D.op_space_3D.temp_cam_rotate * GetTransform(op_3D.op_space_3D.cam_trans) * Vector3F.{0,1,0};
	// if keyboard.Up.EndedDown {
	if IsInputDown(#char "W", game_input) {
		delta_cam += dir_camera_y;
	}
	// if keyboard.Down.EndedDown {
	if IsInputDown(#char "S", game_input) {
		delta_cam -= dir_camera_y;
	}

	dir_camera_z := op_3D.op_space_3D.temp_cam_rotate * GetTransform(op_3D.op_space_3D.cam_trans) * Vector3F.{0,0,1};
	// dir_camera_z := op_3D.op_space_3D.cam_transform * MakeV3F(0,0,1);
	// if keyboard.ActionUp.EndedDown {
	if IsInputDown(#char "I", game_input) {
		delta_cam += dir_camera_z;
	}
	// if keyboard.ActionDown.EndedDown {
	if IsInputDown(#char "K", game_input) {
		delta_cam -= dir_camera_z;
	}
	// if keyboard.nine.down_this_frame {
	if IsKeyboardPress(#char "0", .{ctrl_pressed=true}, .DOWN_THIS_FRAME, game_input) {
		//TODO readjust to closest 90 degree
		//TODO Could have a separate shortcut for resetting the 3D camera
		// UpdateTransform(*op_3D.op_space_3D.cam_trans, Matrix3F_Identity);
		//TODO This could also be a terminal command on a specific op_space chord_space
		if op_3D.op_space_3D.higher_dim == {
		case 3; op_3D.op_space_3D.mouse_rotate = DEFAULT_CHORD_S3_ROTATION;
		case 4; op_3D.op_space_3D.mouse_rotate = DEFAULT_CHORD_S4_ROTATION;
		case; op_3D.op_space_3D.mouse_rotate = Matrix3F_Identity;
		}
	}
	//TODO SETTING We can pass this in through a setting to change 3d movement speed.
   move_dist_3D := 0.1;
	AddToTranslation(*op_3D.op_space_3D.cam_trans, move_dist_3D * UnitVector(delta_cam));


 	if (IsKeyboardPress(#char "O", .IS_DOWN_WITH_PAUSE, game_input) || 
 		 IsKeyboardPress(#char "U", .IS_DOWN_WITH_PAUSE, game_input))
 		&&
 		op_3D.op_space_3D.new_cs_filters.count > 0
 	{
 		csp, found_csp := FindChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, perm.all_data.all_chord_space_points);
		if found_csp {
	 		// if keyboard.o_button.is_down_with_pause {
	 		if IsKeyboardPress(#char "O", .IS_DOWN_WITH_PAUSE, game_input) {
	 			for * op_3D.op_space_3D.new_cs_filters {
		    		it.filter_index += 1;
		    		//TODO Replace this with tuning system once we have alternate tuning_systems
		    		//for higher dimensional chord spaces
		    		if it.filter_index >= op_3D.op_space_3D.lp_count it.filter_index = 0;
		    	}
	    	} 
	    	// else if keyboard.u_button.is_down_with_pause {
	 		else if IsKeyboardPress(#char "U", .IS_DOWN_WITH_PAUSE, game_input) {
				//TODO Be able to switch between these depending on the chord_s3 type
				for * op_3D.op_space_3D.new_cs_filters {
		    		it.filter_index -= 1;
		    		if it.filter_index < 0 it.filter_index = op_3D.op_space_3D.lp_count-1;
		    	}
	    	}

			UpdateOpSpacePointsByFilter(csp, *op_3D.all_op_space_points_3D,
				op_3D.op_space_3D.new_cs_filters,
				op_3D.op_space_3D.cs_filter_aggregate);
		} else {
			print("Chord space with dim % and tuning count % not found.\n", op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count);
		}
	} 

	//Compare mouse coordinates with grid within viewport transform
	/**
	Multiply camera with Quaternions up till this point and then set the rotation matrix
	only once here before taking the inverse of the camera transform

	Would also multiply the set rotation matrix by the camera transform. Therefore,
	we would not store the camera rotation in the transform but only in the quaternion
	and pass it at the end here

	We run this AFTER input so that input gets registered on the same frame as new hovering if the 3d points moved
	**/
	rotate_with_temp : Matrix3F = op_3D.op_space_3D.temp_cam_rotate * GetTransform(op_3D.op_space_3D.cam_trans);
	rotate_camera := MakeMatrix4x3F(rotate_with_temp, GetTranslation(op_3D.op_space_3D.cam_trans));
	inv_camera := InverseLengyel(rotate_camera);
	frustum_inv_camera : Matrix4F = op_3D.op_space_3D.p_frustum * inv_camera;

	mouse_viewport : Vector2F = mouse_cam + renderer_data.base_render_group.half_monitor_squares;
	op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);
	op_rect : Rectangle2 = OpSpaceRect(op_space.world_size);
	//We reset this every frame so we are not hovering if we are not selecting
	op_3D.op_space_3D.chosen_cube = TriangleInGrid3F_DEFAULT;
	if IsInRectangle(op_mouse, op_rect) {
	   //TOOD Should we set is selectable here or just in rendering
	   //TODO We could also pull out these points into a separate array for faster checking
	   //although then we would not be able to set the sp_index directly
		for sp_3d, sp_index : op_3D.all_op_space_points_3D if sp_3d.is_selectable {
			// sp_3d : SpacePoint3D = points_in_grid[sp_index];
			//TODO if all cube transforms are the same, we can pull this out
			rotate_pos : Vector3F = RotatedGrid3DPosition(sp_3d.rel_pos, op_3D.op_space_3D);
	    	rotate_transform : Matrix4x3F = MakeMatrix4x3F(MakeScaleMatrix(sp_3d.scale_value), rotate_pos);
			mvp_cube := frustum_inv_camera * rotate_transform;
			order_by_length : int = -round_to_int(100 * Length(rotate_pos - GetTranslation(op_3D.op_space_3D.cam_trans)));
			mesh_to_view_triangles : [] Triangle3F = 
		 		TransformMeshToViewport(CUBE_TRI_FACE, mvp_cube, renderer_data.base_render_group, null, op_3D.op_space_3D.viewport, order_by_length);
		 	// TransformMeshToViewport(sp_3d.data.mesh, mvp_cube, renderer_data.base_render_group, null, op_3D.op_space_3D.viewport, order_by_length);
			for mesh_to_view_triangles if PointInTriangle(mouse_viewport, MakeTriangle2F(it)) {
				if order_by_length >= op_3D.op_space_3D.chosen_cube.order {
					//TODO Would have to set this to the specific shape eventually if we have different arrays
					op_3D.op_space_3D.chosen_cube = MakeTriangleInGrid3F(it, sp_index, order_by_length, GridTriangleType.VERTEX);
				}
			}
		}
	}

	//TODO If we add cube clicking functionality eventually then we can just use this
	#if 0 {
	if op_3D.op_space_3D.chosen_cube.type == GridTriangleType.VERTEX {
    	// if game_input.MouseButtons[0].down_this_frame {
    	if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
    		if op_3D.op_space_3D.click_cube.type == GridTriangleType.VERTEX && op_3D.op_space_3D.click_cube.point_index != -1 {
				edge : GridEdge3D;
				edge.vert_0 = *op_3D.all_op_space_points_3D[op_3D.op_space_3D.click_cube.point_index];
				edge.vert_1 = *op_3D.all_op_space_points_3D[op_3D.op_space_3D.chosen_cube.point_index];
				// edge.shape.mesh = CUBE_TRI_FACE;
				edge.shape.transform = Matrix4x3F_Identity;
				array_add(*perm.all_data.all_grid_edges_3D, edge);
	    		// Note : reset clicked cube
	    		op_3D.op_space_3D.click_cube = TriangleInGrid3F_DEFAULT;
			} else {
	    		op_3D.op_space_3D.click_cube = op_3D.op_space_3D.chosen_cube;
	    		// print("click_cube is %\n", op_3D.op_space_3D.click_cube);
	    		// print("point is %\n", op_3D.all_op_space_points_3D[op_3D.op_space_3D.click_cube.point_index].data.chord3.chord_pos);
	    		print("x.frequency is %\n", op_3D.all_op_space_points_3D[op_3D.op_space_3D.click_cube.point_index].data.chord3.waves[0].frequency);
	    	}
    	}			
	} else if op_3D.op_space_3D.chosen_cube.type == GridTriangleType.EDGE {
		// if game_input.MouseButtons[1].down_this_frame {
    	if IsKeyboardPress(.MOUSE_BUTTON_RIGHT, .DOWN_THIS_FRAME, game_input) {
			array_ordered_remove_by_index(*perm.all_data.all_grid_edges_3D, op_3D.op_space_3D.chosen_cube.point_index);
			op_3D.op_space_3D.chosen_cube = TriangleInGrid3F_DEFAULT;
    	}
	}
	}
 		
	//TODO add this to the normal audio_output with music_pts
	//We could store 1 of these per ChordSpace3 instead of per point since we can only have over 1
	//and then just compute the frequency here and use those OscWaves
	//Audio Output
	if op_3D.op_space_3D.chosen_cube.type == GridTriangleType.VERTEX {
		chosen_3d : *SpacePoint3D = *op_3D.all_op_space_points_3D[op_3D.op_space_3D.chosen_cube.point_index];
 		if chosen_3d.pitch_set.count > 0 {
 			custom_3D, found_custom_3D := ArrayFindFirstByNameId(op_3D.all_custom_geom_3D,
 				chosen_3d.group_id, "group_id");
			//use defaults to avoid any issues
			tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, op_3D.op_space_3D.tuning_system_id, "id");
			tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
			assert(tuning_system.music_pt_count == tuning_pitches.count);
			op_3D.op_space_3D.synth.wave_type = op_3D.op_space_3D.default_wave_type;
 			if found_custom_3D && custom_3D.custom_audio_type == CustomAudioType.TUNING_SYSTEM {
				tuning_system = ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, custom_3D.tuning_system_id, "id");
				tuning_pitches = ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
				assert(tuning_system.music_pt_count == tuning_pitches.count);
				op_3D.op_space_3D.synth.wave_type = custom_3D.osc_wave_type;
 			}

 			//DOC : We set this here so later if people set any amount of osc waves they want in 3d, then this will update automatically
			if op_3D.op_space_3D.synth.simple_waves.count != chosen_3d.pitch_set.count {
				//TODO Can remove this once we grab the synth externally but can still set the waves here for convenience.
				// op_3D.op_space_3D.synth.wave_type = OscWaveType.SAW;
				// op_3D.op_space_3D.synth.envelope = MakeVolumeEnvelope();
				array_reset_keeping_memory(*op_3D.op_space_3D.synth.simple_waves);
				for 0..chosen_3d.pitch_set.count-1 {
					AddSimpleWaveFromFrequency(0, *op_3D.op_space_3D.synth, audio_data);
				}
			}
			//TODO We could reset the envelope is chosen_cube != last_chosen_cube and then set last_chosen cube in here
			//although the envelope release wouldnt trigger that would remove the initial clicking
	 		//TODO Can grab this from a synth array and also can set this to to start and end on an envelope for no clipping
	 		//Would need code to check if we are no longer selecting specific op_spaces/dspaces and then release there AND
	 		//also probably release here if we go to a different wave OR we can also have an audio_added to synth bool
	 		//and if we added audio then we don't release and if we did not add audio, then we release it
	 		//TODO We could split this in two separate loops by frequency later if that is more efficient for something like SIMD for example.
			for * wave, w_index : op_3D.op_space_3D.synth.simple_waves {
				frequency : float;
		 		if found_custom_3D && custom_3D.custom_audio_type == CustomAudioType.PITCH_SET_AS_FREQUENCY {
		 			frequency = cast(float) chosen_3d.pitch_set[w_index];
		 		} else {
					frequency = MusicPtToFrequency(chosen_3d.pitch_set[w_index], tuning_system, tuning_pitches);
				}
				UpdateWaveFrequency(frequency, wave, audio_data);
			}
			GenerateSimpleSynthSamples(*op_3D.op_space_3D.synth, audio_data.float_buffer, audio_data);
		}
	}
}
}
else if op_space.op_space_external_type == OpSpaceExternalType.space_2d {
	// op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);
	//REMINDER Need to compute this from the world since the camera can change UNLIKE the text op space where
	//the camera does not change so this does not matter.
	op_world_rect : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size); 
	mouse_in_op_space : bool = IsInRectangle(world_mouse, op_world_rect);

	is_zooming : bool = false;
	//TODO Should we allow zooming if the mouse is not in this op space?
	if mouse_in_op_space {
		zoom_scale : int;
		if IsInputDown(.ALT, game_input) && game_input.mouse_wheel != 0 {
			is_zooming = true;
			zoom_scale = game_input.mouse_wheel;
		} else if IsInputMapPress(.OP_SPACE_ZOOM_IN, .IS_DOWN_WITH_PAUSE, game_input) {
			is_zooming = true;
			zoom_scale = 1;
		} else if IsInputMapPress(.OP_SPACE_ZOOM_OUT, .IS_DOWN_WITH_PAUSE, game_input) {
			is_zooming = true;
			zoom_scale = -1;
		} else if IsInputMapPress(.OP_SPACE_ZOOM_RESET, .IS_DOWN_WITH_PAUSE, game_input) {
			is_zooming = true;
			op_space.render_groups.scissor_group.zoom_factor = 1.0;
			zoom_scale = 0; //set this here just to add nothing below
		}
		if is_zooming && zoom_scale != 0 {
			new_zoom_factor : float = op_space.render_groups.scissor_group.zoom_factor + zoom_scale * op_zoom_speed;
			op_space.render_groups.scissor_group.zoom_factor = Clamp(op_zoom_min_factor, new_zoom_factor, op_zoom_max_factor);
			// print("zoom_factor=%\n", op_space.render_groups.scissor_group.zoom_factor);
			//REMINDER : This does not work I think because then it is inconsistent with everything else
			//TODO MAYBE WE SHOULD JUST HAVE 1 pixels_per_square then instead of having 1 for each render group
			// op_space.render_groups.scissor_group.pixels_per_square += zoom_scale * zoom_speed;
		}
	}

	/*DOC : We update the zoom_factor BEFORE here so that the op_mouse has the correct position based on the zoom factor.
	This way we don't miss any op space move instantly clicks and the camera position is still correct.
	*/
	//TODO We could prevent this while zooming if that causes issues.
	// if !is_zooming {
	move_vec, moved_this_frame := DefaultInputMove2D(game_input, op_space.render_groups.scissor_group.pixels_per_square);
	if moved_this_frame {
		op_space.op_2D_cam.world_pos += move_vec;
	} else if mouse_in_op_space && IsInputMapPress(.OP_SPACE_MOVE_INSTANTLY, .DOWN_THIS_FRAME, game_input) {
		op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);
		op_space.op_2D_cam.world_pos = op_mouse;
		// print("op_mouse=%\n", op_mouse);
	}
	// }
}
else {
 	//TODO Putting here for now so we always reset on selecting a new op_space.
	//But maybe we should have a system for text selection eventually if we are
	//going to be writing assembly regularly.
	// perm.all_data.input_check.is_writing_code = false;
}

//TODO I can bring this on top and prevent other input if we are moving or resizing the op_space
//TODO Maybe we should only set this if we don't have any other input... although it is for all op space types so...
moving_op_space, is_moving_op_space := ArrayFindFirstByNameId(perm.all_data.all_moving_op_spaces,
	op_space.id, "op_space_id");
is_closed_op_space : bool = false;
tb_data : TitleBarData = ComputeTitleBar(op_space, default_base_cam, perm.text_editor_data);
if !is_moving_op_space {
 	//TODO If the op_space is fixed then we would use Vector2F.{0,0} instead but
 	//I think we can make a function that takes in an op_space and checks that
 	//OR have a function that adjusts the camera whenever we do op spaces and then pass in that
 	//camera everywhere as the world cam and that would be the most efficient since it would be
 	//faster because the math would not change
 	mouse_in_title_bar : bool = IsInRectangle(mouse_cam, tb_data.title_bar_cam_rect);
	if mouse_in_title_bar {
    	if IsInRectangle(mouse_cam, tb_data.close_op_space_cam_rect) {
			PushRectangle(tb_data.close_op_space_cam_rect, LRED_V, op_space.render_groups.post_render_group, order = 14);
	    	if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
	    		op_space.op_close_selected = true;
	    	}
	   } 
	   // else if IsInRectangle(mouse_cam, tb_data.fix_op_space_cam_rect) {
    	// 	//TODO should have cross trigger even when not chosen
		// 	PushRectangle(tb_data.fix_op_space_cam_rect, LBLUE_V, op_space.render_groups.post_render_group, order = 14);
	   //  	// if game_input.MouseButtons[0].down_this_frame {
	   //  	if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
	   //  		// op_space.is_fixed_to_camera = !op_space.is_fixed_to_camera;
	   //  	}
	   // }
    	else if IsInRectangle(mouse_cam, tb_data.fix_to_mspace_cam_rect) {
    		//TODO Replace this with fixed_mspace_cam_rect
			PushRectangle(tb_data.fix_to_mspace_cam_rect, GREY_DARKER_V, op_space.render_groups.post_render_group, order = 14);
    		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
    			if op_space.fixed_op_type == {
    			case .FIXED_TO_CAMERA;
    				op_space.fixed_op_type = .FIXED_TO_MSPACE;
    				op_space.fixed_mspace_id = perm.all_data.render_mspace_id;
    			case .FIXED_TO_MSPACE;
    				op_space.fixed_op_type = .FIXED_TO_CAMERA;
    			}
    		}
    	} 
		//Note : leaving this at the bottom since it moves everything
    	else if !is_moving_op_space {
			// PushRectangle(tb_data.fix_to_mspace_cam_rect, FGREEN_V, op_space.render_groups.post_render_group, order = 14);
    		if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
    			array_add(*perm.all_data.all_moving_op_spaces, MovingOpSpace.{op_space.id});
    		}
    	}
	}
}

//Note : not else if in case we started to move the op_space this frame
//TODO could bring this up to the top
if is_moving_op_space {
	//TODO Should this just be a rect and we just move the rect? What about for resizing? Let's see when we do it.
	op_space.world_offset += mouse_delta;

	//TODO not is_down should be enough but if we have issues then we can check up this frame as well
	// if game_input.MouseButtons[0].up_this_frame {
	// || IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input)
	if !IsInputDown(.MOUSE_BUTTON_LEFT, game_input) {
		for perm.all_data.all_moving_op_spaces if it.op_space_id == op_space.id {
			remove it;
			break;
		}
	} else {
		//TODO We could put something here to show the op space is moving if that helps
		//DOC REMINDER IMPORTANT : this recomputes the title bar after moving so that
		//it stays with the rest of the op_space while moving. DONT REMOVE THIS and we need to compute this
		//before drawing the title bar below.
		tb_data = ComputeTitleBar(op_space, default_base_cam, perm.text_editor_data);
		// PushRectangle(tb_data.fix_to_mspace_cam_rect, FGREEN_V, op_space.render_groups.post_render_group, order = 15);
	}
}

/*We actually close the op space down here for safety to prevent false close op space clicks.
So we check that we actually selected it above but only close it on the mouse button up.
We also don't do it if op space is moving to hopefully prevent any weird behavior.
We use the is_closed_op_space to prevent border drawing or anything else we add later below if we closed it already.

TODO We could remove the close button altogether to avoid incorrect closes and just have terminal command and shortcut
*/
if op_space.op_close_selected && !is_moving_op_space && IsInRectangle(mouse_cam, tb_data.close_op_space_cam_rect) {
	PushRectangle(tb_data.close_op_space_cam_rect, LRED_V, op_space.render_groups.post_render_group, order = 14);
   // PushCross(GetCenter(tb_data.close_op_space_cam_rect), GetWidth(tb_data.close_op_space_cam_rect), GetHeight(tb_data.close_op_space_cam_rect),
   //  	LBLUE_V, op_space.render_groups.post_render_group, order = 15);
 	// if game_input.MouseButtons[0].up_this_frame {
 	if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) {
 		is_closed_op_space = CloseOpSpace(op_space.op_space_name, perm.all_data, renderer_data);
 		if !is_closed_op_space {
 			print("Failed to close op_space : % not found.\n", op_space.op_space_name);
 		}
 	}
} 
//In case we close the op space, we don't want to grab invalid rendering data below.
//We don't want to render the bar if it's chosen but not in the same mspace
if !is_closed_op_space && IsFixedViewableOpSpace(op_space.*, perm.all_data.render_mspace_id) {
	PushRectangle(tb_data.title_bar_cam_rect, BLACK_V, op_space.render_groups.post_render_group, order = -10000);
		PushText(tb_data.name_cam_pos, op_space.op_space_name, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 10);
	PushRectangleOutline(tb_data.title_bar_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 10, r = 2.0);
	// if op_space.is_fixed_to_camera {
	// 	PushRectangle(tb_data.fix_op_space_cam_rect, LBLUE_V, op_space.render_groups.post_render_group, order = 14);
	// }
	if OpSpaceFixedToMSpace(op_space.*, perm.all_data.render_mspace_id) {
		PushRectangle(tb_data.fix_to_mspace_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 16);
	}

 	if IsInRectangle(mouse_cam, tb_data.title_bar_cam_rect) {
 		//TODO FROM HERE DRAW an X and a small square instead of this for the top right buttons when un hovered
 		//THEN ALSO NEED TO MOVE OP SPACE ON HOVERING INSTEAD and think if we want to move hovering in here or we can do that later
 		//AND THEN do audio
 		//MAYBE write some small tests for zooming in and out to make sure pixels update and maybe the text op space update
 		//can check something in the op space data spec for each one although

	   // PushCross(GetCenter(tb_data.close_op_space_cam_rect), 0.4*GetWidth(tb_data.close_op_space_cam_rect), 0.75*GetHeight(tb_data.close_op_space_cam_rect),
	   //  	LIGHT_BROWN, op_space.render_groups.post_render_group, R=0.06, order = 15);
	   // PushCross(GetCenter(tb_data.fix_to_mspace_cam_rect), 0.4*GetWidth(tb_data.fix_to_mspace_cam_rect), 0.75*GetHeight(tb_data.close_op_space_cam_rect),
	   //  	LIGHT_BROWN, op_space.render_groups.post_render_group, R=0.06, order = 15);
	   // PushCross(GetCenter(tb_data.fix_op_space_cam_rect), 0.4*GetWidth(tb_data.fix_op_space_cam_rect), 0.75*GetHeight(tb_data.close_op_space_cam_rect),
	   //  	LIGHT_BROWN, op_space.render_groups.post_render_group, R=0.06, order = 15);
	   PushRenderX(tb_data.close_op_space_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, 
	   	render_order = 15, width_factor=0.5);
	   small_fix_rect : Rectangle2 = RectCenterDim(GetCenter(tb_data.fix_to_mspace_cam_rect), 0.5*GetDim(tb_data.fix_to_mspace_cam_rect));
		PushRectangle(small_fix_rect, GREY_DARKERM_V, op_space.render_groups.post_render_group, order = 15);
		// PushRectangle(tb_data.close_op_space_cam_rect, 0.6*LRED_V, op_space.render_groups.post_render_group, order = 13);
		// PushRectangle(tb_data.fix_to_mspace_cam_rect, 0.6*FGREEN_V, op_space.render_groups.post_render_group, order = 13);
	}
}
}
}

/*TODO Automatically reload files. If we wanted to, we could 
have a terminal command that sets this on/off.

Need to be careful with file names here and keep everything different.

I think this should happen automatically no matter what since we always want our file and cursors
to remain consistent with the system files.
*/
#if 1 {
for * text_file : perm.all_data.all_text_files {
	load_success : bool = ReloadTextFile(text_file);
	if load_success {
		print("Reloaded %.\n", text_file.file_name);
		UpdateAllTextOpTabsWithTextFile(text_file, perm.all_data, perm.text_editor_data);
		//TODO Remove this if the above works
		#if 0 {
		// if !text_file.was_internal_saved {
			//TODO FROM HERE Need to make a function that reset all the text op spaces
			//we also need to have a case where we don't reset a text op space if we are saving from that op_space
			for * text_op : perm.all_data.all_text_op_space_data if text_op.file_tabs[text_op.ftab_i].text_file_id == text_file.id {
				op_space, found_op_space := ArrayFindFirstByNameId(perm.all_data.all_open_op_spaces, 
					text_op.op_space_id, "id");
				assert(op_space.op_space_external_type == OpSpaceExternalType.txt);
				assert(found_op_space);

				ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
					perm.text_editor_data);

				//NOTE : Need to always move the line here in case we added text before the current line which
				//we can't know where the line was added externally.
				#if 0 {
				new_line_number : int = text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number;
				if new_line_number >= text_file.file_loc.count {
					new_line_number = text_file.file_loc.count-1;
				}
				}
				MoveToLine(text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number,
					text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor);
				// MoveToLine(text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number, text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor);
			}
		// }

		// text_file.was_internal_saved = false;
		}
	}
}

for * global_dynamic_libraries {
	reload_state, msg := ReloadDynamicLibrary(it);
	if reload_state == ReloadState.RELOADED {
		print(msg);
		// print("Reloaded %.\n", dl_file.abs_path_name);
	}
}
}

// We use an event_index here in case a terminal command wants to add more terminal events/commands.
/*TODO Another way to do this is to spawn thread for each command if there are many and then
run the the code for each command and print out on return with some return error message. We would still
need to wait for all commands but then all threads would only take as long as the longest command.
Also we could run terminal events immediately and then catch them all here.
*/
//TODO Can we remove this now I think we never used it?
for perm.all_data.next_frame_terminal_events {
	temp_event : TerminalEvent;
	temp_event.command_string = copy_temporary_string(it.command_string);
	array_add(*perm.all_data.all_terminal_events, temp_event);
	/*TODO We free this manually but this seems like a good case for having an
	extra temporary storage that we reset here quickly. Could even make our own
	simpler temporary storage which has a limit and simply reset with a .count = 0;
	*/
	free(it.command_string.data);
}
array_reset_keeping_memory(*perm.all_data.next_frame_terminal_events);

// terminal_event_index : int = 0;
// while terminal_event_index < perm.all_data.all_terminal_events.count
/*DOC : We always have to remove the split cmd line adn then add it back whenever we run some events.
So we do this either on some events OR if we press enter in the terminal.
So we don't need to update it anywhere else other than when we update text 

TODO REMINDER if we put all this in a function then we can simplify error handling by just printing and returning.
We can likely make a function that just processes 1 terminal event so that then that can be called from the dynamic library.
OR we can also just pass in terminal events and process them here but the function would still be useful for clearer error handling.
*/
if perm.all_data.all_terminal_events.count > 0 {
	//DOC : we need to remove split lines here before updating cmd with start since we want to remove
	//whatever was there before since we have not update the cmd_with_start_string yet so that will
	//be the same size as it used to be since we only update the terminal_command_string.
	//then we don't remove anything
	RemoveSplitCmdLines(perm.all_data.all_terminal_op_space_data, perm.terminal_data);
	UpdateCmdStringWithStart(*perm.terminal_data);
}
for terminal_event : perm.all_data.all_terminal_events
{
	term_data : *TerminalData = *perm.terminal_data;

	// defer terminal_event_index += 1;
	// terminal_event : TerminalEvent = perm.all_data.all_terminal_events[terminal_event_index];

	command_tokens : [..] StringToken;
	command_tokens.allocator = temp;

	sb : String_Builder;
	sb.allocator = temp;
	append(*sb, "-");
	append(*sb, terminal_event.command_string);
	append(*sb, "\n");

	//TODO Can pull this out with ParseTerminalToken eventually when we add the quotes to the check so we parse quotes fully
	//and never consider something in quotes as a switch like a negative number
	IsValidCmdSwitch :: inline (check_string : string) -> bool {
		valid_switch : bool = String.begins_with(check_string, "-") && 
			//This avoids parsing negative numbers BUT we can also do the string in quotes thing later to avoid that
			check_string.count > 2 && is_alpha(check_string[1]);
		return valid_switch;
	}
	cmd_switches : [..] string;
	cmd_switches.allocator = temp;
	//TODO Why not just use a split here on space? Should check if there is a space in file name
	//Actually this is better so that if we find a \" then we can parse in between the quote without skips or delimiters
	//TODO We need to check for "" quotes to deal with spaces but splitting by space and stopping at "" and having
	//skips is better here as it makes the command line more flexible and less prone to error.
	//TODO Maybe we make a ParseTerminalString and if we hit a " after skips, then we just parse until the next " or the end
	string_token : StringToken = ParseStringToken(terminal_event.command_string, 0, " ");
	while string_token.success {
		if IsValidCmdSwitch(string_token.token) {
			array_add(*cmd_switches, string_token.token);
		} else {
			array_add(*command_tokens, string_token);
		}
		string_token = ParseStringToken(terminal_event.command_string, string_token.next_char_index, " ");
	}

	if command_tokens.count > 0 
	{
		INVALID_CMD_MSG :: "Invalid usage.\n%";
		//TODO Could separate this out to an execute command instruction
		found_terminal_command, terminal_command_index :=
			ArrayFindByValue(terminal_command_type_names, command_tokens[0].token, StringEqual);
		if found_terminal_command 
		{
			terminal_command_type : TerminalCommandType = terminal_command_type_enums[terminal_command_index];
			if terminal_command_type == {
			//TODO implement -help switch for each instruction and also print that when we have an invalid terminal command
			//TODO We should set the help msgs in an array associated to the cmds at compile-time so we can print
			//them all out easily to print out all the instructions with their help msgs.
			//Then we could have a general check on top that if we have a -help we just print the help message for that command.
			//IF we don't want certain commands to be accessible, then we can just not print the messages for those in that loop.
			case TerminalCommandType.create_op; {
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, 
#string DONE
create_op op_space_name
Create a text op space with a new file.
DONE);
				} else if AllOrEquals(command_tokens.count, int.[2]) {
					/*DOC : We can't actually test this because we need to use the save file explorer.
					We can't pass in a file_name to avoid replacing existing files so for now we leave it untested.
					*/
					op_space_name : string = command_tokens[1].token;
					op_space_already_exists : bool = false;
					for perm.all_data.all_open_op_spaces if it.op_space_name == op_space_name {
						op_space_already_exists = true;
						//TODO We could move to this op_space if it's fixed.
						print_to_builder(*sb, "op_space \"%\" already open\n", op_space_name);
						break;
					}
					if !op_space_already_exists {
						for perm.all_data.all_closed_op_spaces if it.op_space_name == op_space_name {
							op_space_already_exists = true;
							//TODO Do we want to open here by default or just write a message
							// OpenOpSpace(op_space_name, renderer_data, perm.all_data);
							print_to_builder(*sb, "op_space \"%\" already exists\n", op_space_name);
							break;
						}
					}

					if !op_space_already_exists {
						fe_result := SaveFileWithExplorer();
						if fe_result.file_success {
							new_text_file, loaded_file := LoadTextFile(fe_result.file_name, *perm.all_data.all_text_files, for_writing=true);
							if loaded_file {
								print_to_builder(*sb, "File % created\n", new_text_file.file_name);

								text_op := CreateTextOpSpace(.[new_text_file.id], perm.text_editor_data,
									renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data, op_space_name);
								OpenOpSpace(op_space_name, renderer_data, perm.all_data);
								print_to_builder(*sb, "% created\n", op_space_name);
							}
						} else {
							print_to_builder(*sb, fe_result.error_msg);
						}
					}
				} else {
					//print -help switch
					print_to_builder(*sb, "Invalid : create_op file_name op_name\n");
				}
			}
			case TerminalCommandType.load_op; {
				help_msg := 
#string DONE
load_op op_space_name [path/file_name]
Load an existing file to a new text op space.
DONE;
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if AllOrEquals(command_tokens.count, int.[2,3]) {
					//TODO Do -help switch
					/*DOC : create_op op_space_name file_name
					if we only have create_op op_space_name then the op_space_name is used as the file_name

					TODO If we only have 2 commands then we can open empty text op space and then use file explorer to open file.
					For now we don't allow empty text op space but maybe we could without any files we don't do any cursor typing or rendering code.
					*/
					op_space_name : string = command_tokens[1].token;
					op_space_already_exists : bool = false;
					for perm.all_data.all_open_op_spaces if it.op_space_name == op_space_name {
						op_space_already_exists = true;
						//TODO We could move to this op_space if it's fixed.
						print_to_builder(*sb, "op_space \"%\" already open\n", op_space_name);
						break;
					}
					if !op_space_already_exists {
						for perm.all_data.all_closed_op_spaces if it.op_space_name == op_space_name {
							op_space_already_exists = true;
							OpenOpSpace(op_space_name, renderer_data, perm.all_data);
							print_to_builder(*sb, "op % already exists\n", op_space_name);
							print_to_builder(*sb, "% open\n", op_space_name);
							break;
						}
					}

					if !op_space_already_exists {
						#if 1 {
						text_file : TextFile;
						found_text_file : bool;
						file_name : string;
						if command_tokens.count == 2 {
							fe_result := OpenFileWithExplorer();
							file_name = fe_result.file_name;
							if !fe_result.file_success {
								print_to_builder(*sb, fe_result.error_msg);
							} else {
								text_file, found_text_file = GetOrLoadTextFileByAbsolutePath(file_name, *perm.all_data.all_text_files);
							}
						} else if command_tokens.count == 3 {
							file_name = command_tokens[2].token;
							//NOTE : We don't load_by_absolute_path because if we deleted the file externally
							//then we want to be able to open the file by name if needed here so we can save it again if needed.
							//I think this way is more explicit than below, but I will leave both cases in case I though of something
							//in the one below when I originally made it and maybe though about it more then.
							//TODO We can make a list text files command to see all the open files and theyre names just in case later
							loaded_file : bool = false;
							// text_file, found_text_file, loaded_file = GetOrLoadTextFileByFileName(file_name, *perm.all_data.all_text_files);
							text_file, found_text_file, loaded_file = GetOrLoadTextFileByAbsolutePath(file_name, *perm.all_data.all_text_files, check_absolute_path=true);
							if loaded_file print_to_builder(*sb, "Loaded file %.\n", file_name);
							else print_to_builder(*sb, "% not found\n", file_name);
						}
						if found_text_file {
							text_op := CreateTextOpSpace(.[text_file.id], perm.text_editor_data,
								renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data, op_space_name);
							//TODO Could make opening optional on creation but I think opening by default makes sense
							OpenOpSpace(op_space_name, renderer_data, perm.all_data);
							print_to_builder(*sb, "% created\n", op_space_name);
						}
						} else {
						file_name : string;
						file_check_success : bool = false; 
						if command_tokens.count == 2 {
							fe_result := OpenFileWithExplorer();
							file_name = fe_result.file_name;
							file_check_success = fe_result.file_success;
							if !fe_result.file_success {
								print_to_builder(*sb, fe_result.error_msg);
							}
						} else if command_tokens.count == 3 {
							file_check_success = true;
							file_name = command_tokens[2].token;
						}
						if file_check_success {
							//TODO Could make a FetchTextFile function where we check in here and if dont have it
							//then we try loading it and if we do have it, then we try reloading it.
							//We make sure that the file is not already in all_text_files, otherwise we don't want to load it again.
							text_file, found_text_file := ArrayFindFirstConstByNameId(perm.all_data.all_text_files,
								file_name, "file_name");
							if !found_text_file {
								file_does_exist := file_exists(file_name);
								if file_does_exist {
									text_file, found_text_file = LoadTextFile(file_name, *perm.all_data.all_text_files);
									if found_text_file {
										print_to_builder(*sb, "Loaded file %.\n", file_name);
									} else {
										//TODO Could add error here if we want it in the in-game terminal.
										print_to_builder(*sb, "Cannot load file %.\n", file_name);
									}
								}
							}
							if found_text_file {
								text_op := CreateTextOpSpace(.[text_file.id], perm.text_editor_data,
									renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data, op_space_name);
								//TODO Could make opening optional on creation but I think opening by default makes sense
								OpenOpSpace(op_space_name, renderer_data, perm.all_data);
								print_to_builder(*sb, "% created\n", op_space_name);
							} else {
								print_to_builder(*sb, "% not found\n", file_name);
							}
						}
						}
					}
				} else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			case TerminalCommandType.open_op; {
				help_msg ::
#string DONE
open_op op_space_name
Open an existing op space.
DONE;
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if command_tokens.count == 2 {
					op_space_name : string = command_tokens[1].token;
					open_op_space, open_op_space_success, msg := OpenOpSpace(op_space_name, renderer_data, perm.all_data);
					print_to_builder(*sb, msg);
					// if open_op_space_success {
					// 	print_to_builder(*sb, "% open\n", op_space_name);
					// } else {
					// 	print_to_builder(*sb, "% not found\n", op_space_name);
					// }
				}
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			case TerminalCommandType.close_op; {
				close_op_help_msg ::
#string DONE
close_op op_space_name
Close an existing op space.
DONE;
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, close_op_help_msg);
				} else if command_tokens.count == 2 {
					op_space_name : string = command_tokens[1].token;
					is_closed : bool = CloseOpSpace(op_space_name, perm.all_data, renderer_data);
					if is_closed {
						print_to_builder(*sb, "% closed\n", op_space_name);
					} else {
						print_to_builder(*sb, "% not found\n", op_space_name);
					}
				} else {
					print_to_builder(*sb, INVALID_CMD_MSG, close_op_help_msg);
				}
			}
			case TerminalCommandType.move_op; {
				move_op_help_msg ::
#string DONE
move_op op_space_name x y
Move an existing op space to x,y world coordinates.
DONE;
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, move_op_help_msg);
				} else if command_tokens.count == 4 {
					op_space, found_op_space := FindOpSpacePointerOpenOrClosed(command_tokens[1].token, perm.all_data);
					if found_op_space {
						x_float, x_success := string_to_float(command_tokens[2].token);
						if !x_success print_to_builder(*sb, "% invalid x\n", command_tokens[2].token);
						y_float, y_success := string_to_float(command_tokens[3].token);
						if !y_success print_to_builder(*sb, "% invalid y\n", command_tokens[3].token);

						if x_success && y_success {
							op_space.world_offset.x = x_float;
							op_space.world_offset.y = y_float;
							print_to_builder(*sb, "% moved to %,%\n", command_tokens[1].token, command_tokens[2].token, command_tokens[3].token);
						}
					} else {
						print_to_builder(*sb, "% not found\n", command_tokens[1].token);
					}
				} else {
					print_to_builder(*sb, INVALID_CMD_MSG, move_op_help_msg);
				}
			}
			case TerminalCommandType.ldl; { //load dynamic library
				if command_tokens.count == 2 && command_tokens[1].token == "-help" {
					print_to_builder(*sb, 
#string DONE
ldl file_name
Load a system dynamic library.
Reload if we've already loaded it.
DONE);
				} else {
					//TODO We could do this with an open file now
					file_name_with_type : string = command_tokens[1].token;
					success, msg := FetchDynamicLibrary(file_name_with_type);
					print_to_builder(*sb, msg);
				}
			}
			case TerminalCommandType.create_file; {
				help_msg :: 
#string DONE
create_file path/file_name
Create a new file.
DONE;
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if command_tokens.count == 2 {
					//TODO We could add a root directory here and allow that to be changed for easier file loading
					//and still print out the absolute paths. Could eventually put that in a settings file.
					// file_name : string = tprint("text_files/%", command_tokens[1].token);
					file_name : string = command_tokens[1].token;
					text_file, found_text_file := ArrayFindFirstConstByNameId(perm.all_data.all_text_files,
						file_name, "file_name");
					if !found_text_file {
						file_does_exist := file_exists(file_name);
						if file_does_exist {
							//Load text file from memory since it already exists
							text_file, found_text_file = LoadTextFile(file_name, *perm.all_data.all_text_files);
							if found_text_file {
								//TODO Maybe we should add this to all_text_files in LoadTextFile especially if
								//this is the only place taht we load the text file which is likely best to keep things clean.
								// array_add(*perm.all_data.all_text_files, text_file);
								print_to_builder(*sb, "Loaded file %.\n", file_name);
							} else {
								//TODO Could add error here if we want it in the in-game terminal.
								print_to_builder(*sb, "Cannot load file %.\n", file_name);
							}
						} else {
							//Load text file "for writing" which is creating a new one
							text_file, found_text_file = LoadTextFile(file_name, *perm.all_data.all_text_files, 
								for_writing=true);
							if found_text_file {
								//TODO Maybe we should add this to all_text_files in LoadTextFile especially if
								//this is the only place taht we load the text file which is likely best to keep things clean.
								// array_add(*perm.all_data.all_text_files, text_file);
								print_to_builder(*sb, "Created file %.\n", file_name);
							} else {
								//TODO Could add error here if we want it in the in-game terminal.
								print_to_builder(*sb, "Cannot load file %.\n", file_name);
							}
						}
					}
				} else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			//TODO Can implement a save_as to always save a new copy if needed.
			//I don't know if I want this command anymore. Just having it in the text op space is enough I think
			//and then also autosave is enough. I guess this allows commands to be run continuously eventually.
			case TerminalCommandType.save_file; {
				help_msg ::
#string DONE
save_file path/file_name
If a system file exists, we save directly.
If not, then we can choose where to save it.
DONE;
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if command_tokens.count == 2 {
					text_file, found_text_file := ArrayFindFirstByNameId(perm.all_data.all_text_files,
						command_tokens[1].token, "file_name");
					if found_text_file {
						success, msg := SaveTextFileAndUpdateAllTextOpTabs(text_file, perm.all_data, perm.text_editor_data);
						print_to_builder(*sb, msg);
					} else {
						print_to_builder(*sb, "% not found.\n", text_file.file_name);
					}
				} 
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}				
			}
			// case TerminalCommandType.delete_file; {
			// 	//TODO Could have an option where we just delete the file locally if that helps.
			// 	//TODO We can't do this because we would need to remove the text op space as well
			// 	//so let's leave it until we do that.
			// 	#if 0 {
			// 	if command_tokens.count == 2 {
			// 		absolute_path : string = get_absolute_path(command_tokens[1].token);
			// 		removed_file_locally : bool = ArrayRemoveFirstByNameId(*perm.all_data.all_text_files,
			// 			absolute_path, "absolute_path_name");
			// 		if !removed_file_locally {
			// 			print_to_builder(*sb, "local file % not found.\n", absolute_path);
			// 		}
			// 		file_is_deleted := file_delete(absolute_path);
			// 		if !file_is_deleted {
			// 			print_to_builder(*sb, "system file % not found.\n", absolute_path);
			// 		}
			// 	} 
			// 	else {
			// 		append(*sb, "Invalid delete_file command : delete_file file_name\n");
			// 	}
			// 	}						
			// }
			case TerminalCommandType.clear; {
				ClearTerminal(*perm.terminal_data, perm.all_data.all_terminal_op_space_data);
				reset(*sb);
			}
			//DOC : the set command here is just for testing and should not be user facing
			//Can likely remove it altogether if we use setting dynamic libraries eventually
			case TerminalCommandType.set_runtime_settings_file; #through;
			case TerminalCommandType.load_runtime_settings; {
				help_msg :: #run sprint(
#string DONE
load_runtime_settings
Load % for runtime settings.
Any missing settings will use the default values.
DONE,
RUNTIME_SETTINGS_REL_PATH);
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if (terminal_command_type == .load_runtime_settings && command_tokens.count == 1) || 
				          (terminal_command_type == .set_runtime_settings_file && command_tokens.count == 2)
				{
					//REMINDER : This is only used for internal use and testing right now and this command should not be shown to everyone
					if terminal_command_type == .set_runtime_settings_file {
						perm.all_data.runtime_settings_file_path = copy_string(command_tokens[1].token);
					}
					rsr : RuntimeSettingsReturn = ParseRuntimeSettingsFile(*perm.all_data.all_text_files, perm.all_data.runtime_settings_file_path);
					if rsr.success {
						UpdateRuntimeSettings(rsr.new_settings, perm, renderer_data);
						print_to_builder(*sb, "Loaded runtime settings %\n", perm.all_data.runtime_settings_file_path);
					} else {
						print_to_builder(*sb, "Invalid runtime settings %\n", perm.all_data.runtime_settings_file_path);
					}
				}
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			case TerminalCommandType.generate_runtime_settings; {
				help_msg :: #run sprint(
#string DONE
generate_runtime_settings -default file_path
Create file_path with current runtime settings.
Any missing settings will be added and use the default values.
If no file_path is given, then % is created by default.
-default switch uses the default settings instead of the current settings.
DONE,
GENERATED_RUNTIME_SETTINGS_REL_PATH);
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if InRange(1, command_tokens.count, 2) && InRange(0, cmd_switches.count, 1) {
					runtime_settings_to_generate : RuntimeSettingsData = perm.all_data.runtime_settings;
					if cmd_switches.count == 1 {
						runtime_settings_to_generate = RuntimeSettingsData.{};
					}

					file_path : string;
					if command_tokens.count == 1 {
						file_path = GENERATED_RUNTIME_SETTINGS_REL_PATH;
					} else if command_tokens.count == 2 {
						file_path = command_tokens[1].token;
					}

					success : bool = GenerateRuntimeSettingsFile(runtime_settings_to_generate, file_path);
					if success {
						print_to_builder(*sb, "Generated file %\n", file_path);
					} else {
						print_to_builder(*sb, "Unable to generate file %\n", file_path);
					}
				}
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			case TerminalCommandType.generate_startup_settings; {
				help_msg :: #run sprint(
#string DONE
generate_startup_settings -default file_path
Create file_path with current startup settings.
Any missing settings will be added and use the default values.
If no file_path is given, then % is created by default.
-default switch uses the default settings instead of the current settings.
DONE,
GENERATED_STARTUP_SETTINGS_REL_PATH);
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if InRange(1, command_tokens.count, 2) && InRange(0, cmd_switches.count, 1) {
					startup_settings_to_generate : StartupSettingsData = GLOBAL_STARTUP_SETTINGS;
					if cmd_switches.count == 1 {
						startup_settings_to_generate = StartupSettingsData.{};
					}

					file_path : string;
					if command_tokens.count == 1 {
						file_path = GENERATED_STARTUP_SETTINGS_REL_PATH;
					} else if command_tokens.count == 2 {
						file_path = command_tokens[1].token;
					}

					success : bool = GenerateStartupSettingsFile(startup_settings_to_generate, file_path);
					if success {
						print_to_builder(*sb, "Generated file %\n", file_path);
					} else {
						print_to_builder(*sb, "Unable to generate file %\n", file_path);
					}
				}
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			case TerminalCommandType.set_input_mappings_file; #through;
			case TerminalCommandType.load_input_mappings; {
//TODO Could load file_path in quotes "file_path" so we don't adjust the slashes or something like that if needed
				help_msg :: #run sprint(
#string DONE
load_input_mappings
Load % to the input mappings.
DONE,
INPUT_MAPPINGS_REL_PATH);
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if (terminal_command_type == .load_input_mappings && command_tokens.count == 1) || 
		         		 (terminal_command_type == .set_input_mappings_file && command_tokens.count == 2)
	         {
					if terminal_command_type == .set_input_mappings_file {
						perm.all_data.input_mappings_file_path = copy_string(command_tokens[1].token);
					}
					pimr : ParsedInputMappingReturn = ParseInputMappingsFile(*perm.all_data.all_text_files, perm.all_data.input_mappings_file_path);
					if pimr.success {
						valid, error_msg := UpdateGameInputMappings(pimr.parsed_input_mappings, game_input);
						if !valid {
							append(*sb, error_msg);
						} else {
							print_to_builder(*sb, "Loaded input mappings %\n", perm.all_data.input_mappings_file_path);		
						}
					} else {
						append(*sb, pimr.error_msg);
					} 
				}
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			case TerminalCommandType.generate_input_mappings; {
//TODO Could load file_path in quotes "file_path" so we don't adjust the slashes or something like that if needed
				help_msg :: #run sprint(
#string DONE
generate_input_mappings -default file_path
Create file_path with current input mappings.
Any missing mappings will be added and use the default values.
If no file_path is given, then % is created by default.
-default switch uses the default mappings instead of the current mappings.
DONE,
GENERATED_INPUT_MAPPINGS_REL_PATH);
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if InRange(1, command_tokens.count, 2) && InRange(0, cmd_switches.count, 1) {
					input_mappings_to_generate : [] InputMapping = game_input.game_input_mappings;
					if cmd_switches.count == 1 {
						input_mappings_to_generate = DEFAULT_INPUT_MAPPINGS;
					}

					file_path : string;
					if command_tokens.count == 1 {
						file_path = GENERATED_INPUT_MAPPINGS_REL_PATH;
					} else if command_tokens.count == 2 {
						file_path = command_tokens[1].token;
					}

					success : bool = GenerateInputMappingsFile(input_mappings_to_generate, file_path);
					if success {
						print_to_builder(*sb, "Generated file %\n", file_path);
					} else {
						print_to_builder(*sb, "Unable to generate file %\n", file_path);
					}
				}
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			case TerminalCommandType.sys; {
				command_strings : [..] string;
				command_strings.allocator = temp;
				for command_tokens array_add(*command_strings, it.token);
				run_command(.. command_strings);
			}
			//NOTE : This might be convenient to compile jai external files within the program since it uses the build file directly.
			case TerminalCommandType.jai; {
				if command_tokens.count == 2 {
					file_name_with_type : string = command_tokens[1].token;
					file_name_split : [] string = String.split(file_name_with_type, cast(u8) #char ".",, temp);

					command_strings := string.[jai_cmd, BUILD_DL_NAME, "-import_dir", "./", "-", file_name_split[0]];
					// command_strings[5] = file_name_split[0];
					success := run_command(.. command_strings);
					if success.type == Process_Result_Type.EXITED {
						print_to_builder(*sb, "% compiled.\n", command_strings[5]);
					} else {
						print_to_builder(*sb, "% compile FAIL.\n", command_strings[5]);
					}
				} else {
					append(*sb, "Invalid jai command : jai file_name.jai\n");
				}
			}
			case TerminalCommandType.midi;
			{
				if command_tokens.count == 4 || command_tokens.count == 5 {
					midi_status : string = command_tokens[1].token;
					if midi_status == "cc" {
						//TODO Could send next available undefined cc for convenience but also this is
						//tricky because it depends on the channel/port and which control_change data byte
						//is needed since some of them map to specific values like foot pedal = 4 or 36
						cc_params : [4] u8;
						cc_params[0] = cast(u8) MIDI_Status.Control_Change;

						i : int = 1;
						is_valid : bool = true;
						for i_token : 2..command_tokens.count-1 {
							defer i += 1;
							u8_value, is_u8_value := string_to_int(command_tokens[i_token].token, T = u8);
							if is_u8_value cc_params[i] = u8_value;
							is_valid &&= is_u8_value;
						}

						is_valid &&= cc_params[1] <= MIDI_DATA_BYTE_MAX && 
							cc_params[2] <= MIDI_DATA_BYTE_MAX &&
							cc_params[3] <= MIDI_CHANNEL_MAX;
						if is_valid {
							valid_msg, cc_msg := create_midi_message(cc_params);
							if valid_msg {
			        			sent_message : bool = send_midi_message(game_memory.midi_output, cc_msg);
			        			if sent_message append(*sb, "midi_msg success.\n");
			        			else append(*sb, "midi_msg failure.\n");
							} else {
								append(*sb, "Invalid midi data for 'cc'.\n");
			        		}
			        	} else {
							//TODO Could output valid command to terminal with examples
							append(*sb, "Invalid 'midi_msg cc' command.\n");
						}
					}
				}
				else {
					//TODO Could print out the options here for midi_status byte pseudonym
					append(*sb, "'midi_msg' requires 4 or 5 arguments.\n");
				}
			}
			case TerminalCommandType.mp;
			{
				//TODO Can remove this or change the name once we can set audio_pointer with mouse
				//TODO This should be a float for tano_x and also should be settable through 
				//terminal, mouse and code
				if command_tokens.count == 2 {
					x_memory_string : string = command_tokens[1].token;
					x_memory, is_int := string_to_int(command_tokens[1].token);
					if is_int {
						perm.all_data.set_audio_position_data.is_set = true;
						perm.all_data.set_audio_position_data.memory_unit = x_memory;

						// array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.SET_TO_MEMORY_UNIT, x_memory));
					} else {
						append(*sb, "'mp' requires 1 int argument.\n");
					}
				}
				else {
					append(*sb, "'mp' command takes 1 argument.\n");
				}	
			}
			//TODO Can use this as a generalized go_to method to go_to a specific mspace or world_pos or op_space for example
			//This also can make it clearer what we can go_to directly from the terminal
			case TerminalCommandType.goto; {
				help_msg :: #run sprint(
#string DONE
go_to place input
place : %
input : 
 - mspace : [int, string]
 - op_space : [string]
DONE,
goto_type_names);
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if command_tokens.count == 3 {
					//TODO We could pull this out as a function eventually to have shortcuts for going to different places
					found_goto_type : bool = false;
					goto_type : GoToTermType;
					for goto_type_names if command_tokens[1].token == it {
						goto_type = goto_type_values[it_index];
						found_goto_type = true;
						break;
					}
					if !found_goto_type {
						print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
					} else {
						if goto_type == {
						case GoToTermType.mspace; {
							//DOC : We have to update the default_base_cam here so that we render properly below and don't
							//have rendering be for a frame. We could make an UpdateRenderMSpace if needed to keep that
							//consistent eventually
							found_change_mspace : bool = false;
							change_mspace : MusicSpaceData;
							mspace_index, is_integer := string_to_int(command_tokens[2].token);
							if is_integer {
								if mspace_index >= 0 && mspace_index < perm.all_data.all_mspace_data.count {
									change_mspace = perm.all_data.all_mspace_data[mspace_index];
									found_change_mspace = true;
									print_to_builder(*sb, "moved to mspace_index % with mspace_id %\n", 
										command_tokens[2].token, perm.all_data.render_mspace_id);
								} else {
									print_to_builder(*sb, "mspace_index % not found\n", command_tokens[2].token);
								}
							} else {
								change_mspace, found_change_mspace = ArrayFindFirstByNameId(perm.all_data.all_mspace_data,
									command_tokens[2].token, "mspace_name");
								if found_change_mspace {
									print_to_builder(*sb, "moved to mspace_name % with mspace_id %\n", 
										command_tokens[2].token, perm.all_data.render_mspace_id);
								} else {
									print_to_builder(*sb, "mspace_name % not found\n", command_tokens[2].token);
								}
							}
							if found_change_mspace {
								ChangeRenderMusicSpace(change_mspace.mspace_id, perm.all_data);
								default_base_cam = perm.all_data.all_mspace_data[mspace_index].mspace_cam;
							}
						}
						case GoToTermType.op_space; {
							op_space, found_op_space := ArrayFindFirstByNameId(perm.all_data.all_open_op_spaces,
								command_tokens[2].token, "op_space_name");
							if found_op_space {
								if op_space.fixed_op_type == .FIXED_TO_MSPACE {
									perm.all_data.render_mspace_id = op_space.fixed_mspace_id;
								}
								render_mspace, found_mspace := ArrayFindFirstByNameId(perm.all_data.all_mspace_data,
									perm.all_data.render_mspace_id, "mspace_id");
								assert(found_mspace);
								last_cam_pos : Vector2F = render_mspace.mspace_cam.world_pos;
								render_mspace.mspace_cam.world_pos = op_space.world_offset;
								MoveFixedCameraOpSpaces(render_mspace.mspace_cam.world_pos, last_cam_pos, perm.all_data);
							} else {
								print_to_builder(*sb, "op_space % not found\n", command_tokens[2].token);
							}
						}
						}
					}
				}
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			//TODO This is kind of unnecessary once we put it in the shared library
			case TerminalCommandType.tuning_systems; {
				//TODO Could add a switch for ratio_From_start or ratio_to_next_music_pt or linear as well
				//although this will be available in the actual shared code eventually so we can also use a debugger...
				help_msg :: #run sprint(
#string DONE
tuning_systems short_name/id
no args - Print out all current tuning system info.
short_name/id - Print tuning system info with ratios from start.
DONE);
				if IsTerminalCmdHelp(cmd_switches) {
					print_to_builder(*sb, help_msg);
				} else if command_tokens.count == 1 {
					for perm.all_data.all_tuning_systems {
						print_to_builder(*sb, "% (%)\nid=%, compass=%, count=%\n\n", 
							it.name, it.short_name, it.id, it.compass_interval, it.music_pt_count);
					}
				} else if command_tokens.count == 2 {
					//We could check if it's an integer and then get the tuning_system by id here
					tuning_system_id, is_integer := string_to_int(command_tokens[0].token);
					tuning_system : TuningSystem;
					found_tuning_system : bool;
					if is_integer {
						tuning_system, found_tuning_system = ArrayFindFirstByNameId(perm.all_data.all_tuning_systems,
							tuning_system_id, "id");
					} else {
						tuning_system, found_tuning_system = ArrayFindFirstByNameId(perm.all_data.all_tuning_systems,
							command_tokens[0].token, "short_name");
					}
					if found_tuning_system {
						tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
						assert(tuning_system.music_pt_count == tuning_pitches.count);
						print_to_builder(*sb, "%\nid=%, short_name=%, compass=%, count=%\n", 
							tuning_system.name, tuning_system.id, tuning_system.short_name, tuning_system.compass_interval, tuning_system.music_pt_count);
						print_to_builder(*sb, "[");
						if tuning_pitches.count > 1 {
							for 0..tuning_pitches.count-2 {
								tp : TuningPitch = tuning_pitches[it];
								print_to_builder(*sb, "%=%, ", tp.music_pt_pos, tp.ratio_from_start); 
							}
						}
						if tuning_pitches.count > 0 {
							last_tp : TuningPitch = peek(tuning_pitches);
							print_to_builder(*sb, "%=%", last_tp.music_pt_pos, last_tp.ratio_from_start); 
						}
						print_to_builder(*sb, "]\n");
					} else {
						print_to_builder(*sb, "Tuning system % not found.\n", command_tokens[0].token);
					}
				}
				else {
					print_to_builder(*sb, INVALID_CMD_MSG, help_msg);
				}
			}
			}
		}
		else {
			//TODO Could separate this to check invalid_terminal_command
			//and then print out a longer message with possible commands
			append(*sb, "Invalid terminal command.\n");
		}
	}

	//TODO Need to put this at the bottom of the frame loop so we can add text to it anywhere in the frame
	//and it would all appear on the same frame and feel nice and snappy.
	//NOTE : We add an extra empty line here to put a gap between this output and the next command
	//We don't need this because the "\n" after each appedn creates a new line anyways on the split below
	// append(*sb, "\n");
	string_to_add : string = builder_to_string(*sb,, temp);
	new_text_length : int = perm.terminal_file_string.text_string.count + string_to_add.count;
	if new_text_length >= perm.terminal_file_string.total_allocated_bytes {
		//We clear the terminal if it's too big. We could just remove the specific amount added but 
		//that would involve some precise updates so I'll say people should clear their terminals or 
		//if they want more terminal lines, then they can update the size in the settings
		ClearTerminal(*perm.terminal_data, perm.all_data.all_terminal_op_space_data);
	}
	if string_to_add.count >= perm.terminal_file_string.total_allocated_bytes {
		string_to_add = "Output greater than terminal size.\n";
	}

	if string_to_add.count > 0 {
		//We update this here in case we reset text_string or string_to_add in one of the 
		//if statements above on clearing the terminal or on size too big.
		new_text_length = perm.terminal_file_string.text_string.count + string_to_add.count;
		start_index : int = perm.terminal_file_string.text_string.count;
		// old_char_point_data : *u8 = perm.terminal_file_string.text_string.data + cursor.char_point;
		// new_char_point_data : *u8 = old_char_point_data + input.text_buffer_count;
		// copy_string_length : s64 = file_string.text_string.count - cursor.char_point;
		memcpy(perm.terminal_file_string.text_string.data + start_index,
			string_to_add.data, string_to_add.count);
		perm.terminal_file_string.text_string.count = new_text_length;

		added_string : string =
			String.slice(perm.terminal_file_string.text_string, start_index, perm.terminal_file_string.text_string.count);
		//NOTE : split adds an empty line at the end when there is no string remainder
		new_lines : [] string = String.split(added_string, cast(u8) #char "\n",, temp);
		// perm.terminal_file_string.text_string.count -= 1;
		//TODO Try removing this and the not putting \n at the end of every line.
		// new_lines.count -= 1; //remove the extra line at the end since we always end with \n
		for line : new_lines {
			//TODO Make a command history where this can only be a certain number of lines
			//and then we can loop around the array.
			//TODO This should be an array_resize and then memcpy for efficiency
			//TODO Do we still need this now with the split lines?
			array_add(*perm.all_terminal_lines, line);
		}
		//TODO IF we only allow 1 terminal then we can change that here and remove the loop
		//HOWEVER we could also just compute this when rendering but this seems simpler overall.
		for * term_op : perm.all_data.all_terminal_op_space_data {
			for line : new_lines {
				AddSplitStringByLines(line, *term_op.terminal_tsl);
			}
		}

		//Sanity check here we should likely check this whenever adding terminal events
		assert(terminal_event.command_string.count < term_data.terminal_command_string.total_allocated_bytes);
		//TODO We could make a generalized circular array and generalize a history so we can reuse it for other
		//things like find text bar but for now this is a simple terminal history for convenience
		//Add to command history
		same_as_last_cmd : bool = false;
		if term_data.cmd_history_count > 0 {
			previous_history_index : int = PosMod(term_data.next_cmd_history_index-1, term_data.terminal_cmd_history.count);
			same_as_last_cmd = term_data.terminal_cmd_history[previous_history_index] == terminal_event.command_string; 
		}
		if !same_as_last_cmd && terminal_event.command_string.count > 0 {
			CopyToCurrentCmdHistory(terminal_event.command_string, term_data);
			//TODO Use a circular buffer here if we ever implement that
			//FOR EXAMPLE if we only add 1 command of each equal string to the entire history then better to make a circular buffer
			//with a remove element function which can be tested and used separately because removing requires a change in possible
			//count and other variables which would be better to make systematic if needed
			term_data.next_cmd_history_index =
				PosMod(term_data.next_cmd_history_index+1, term_data.terminal_cmd_history.count);
			term_data.cmd_history_count = min(term_data.cmd_history_count+1, term_data.terminal_cmd_history.count);
			term_data.history_select_offset = 0;
		}
		//Make the current command history empty
		//REMINDER This needs to be reset no matter what so that we don't keep the last command in last history if it's the same as the last one
		CopyToCurrentCmdHistory("", term_data);
	}
}
if perm.all_data.all_terminal_events.count > 0 {
	AddBackCmdSplitLine(perm.all_data.all_terminal_op_space_data, perm.terminal_data);
}
array_reset_keeping_memory(*perm.all_data.all_terminal_events);



/*TODO Should put instruction processing in a separate file and just process here when
we create a process_instructions_event. Would also need code to run like a debugger.

We would not normally want to run all the code at once. Maybe a 1 or a few instructions per frame,
since we would want the rendering to update a bit at a time.

TODO We could make the instructions run to the beat and then that could be adjusted to 1/4 beat, 1/8 beat...
And then we could play the notes bein added for that length of time if its > 1/2 a beat for example.
This seems a bit silly but could be interesting, since the CPU cycle does have a natural rhythm.
*/
//TODO We could grab the last selected TextOpSpaceData here and run that. OR the last run code...
#if 0 {
if keyboard.only_alt_down && keyboard.r_button.down_this_frame {
	//TODO This should depend on which file we are currently asking to be run.
	//Could do this from terminal and also with shortcut if we have selected a particular file op_space.
    if perm.all_data.input_check.is_writing_code
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});
}
}
//TODO We could set this and the text file beforehand and then just compile here?
//We set the settings here as a way to pass in the first main path name but we could also
//create a separate function or another way of doing this. This was just convenient for now
//so we don't have to change anything in other tests and still get the path name for debug tests
//since the test files are no system files but the compiler checks system files for everything except main.
//But maybe we should pass that in through settings to make sure its in the system in the compiler if we set it.
//TODO Should these be terminal commands? Should we only have them as terminal commands?
//We could have both for convenience since terminal commands would require converting back to string.
//We could have options to fetch from all compile_code_events but that seems unnecessary. Could just have
//a compile command for convenience but will anyone even use it compared to just alt+c and then alt+r?
//WE MAY NOT WANT TO CALL TERMINAL because we may want to output to somewhere in the debug space.
//This could make the debug output clearer such as errors. OR we only do terminal and we keep that open on compiling...
//TODO We could pull this out for testing but also we could test this with an integration test to see if
//the code here for debug breakpoint is updating properly.
/*DOC : If we try compiling a file in a text op while that same text op is executing some instructions,
then it should still compile fine because the instructions being executed were copied over
DO NOT COMPILE at the same time as executing in the same op space to avoid any issues such as with error output in the same text op space

I THINK we can just compile from text op spaces and any external compilation can just we done from a dll with the
compile code function directly since that just takes a string anyways.
*/
for compile_event : perm.all_data.all_compile_code_events {
	if compile_event.compile_code_type == {
	case .TEXT_FILE; {
		//DOC : If this op is executing, then we don't allow compilation. Technically we could since we copy the instructions
		//to a separate array for execution, but that could lead to unknown issues and also that would interfere with the text op messages.
		//WE DO ALLOW compiling from a separate text op however while another process is executing
		text_op_is_executing : bool = TextOpIsExecuting(compile_event.op_space_id, perm.all_data.all_process_instruction_events);
		if text_op_is_executing continue;

		text_op, found_text_op := ArrayFindFirstByNameId(perm.all_data.all_text_op_space_data, 
			compile_event.op_space_id, "op_space_id");
		if !found_text_op {
			log_error("Not found text op with id %.\n", compile_event.op_space_id);
			continue compile_event;
		}

		//TODO Need to put this in a CompileCodeFile function since we will have #load eventually.
		//Will pass in main_text_file_id and then other text_files and a way to load system text_files
		//in case we have not loaded them yet.
 		text_file, found_text_file := ArrayFindFirstByNameId(perm.all_data.all_text_files,
 			compile_event.text_file_id, "id");
 		if !found_text_file {
			log_error("Not found text file with id %.\n", compile_event.text_file_id);
			continue compile_event;
		}

		reset(*text_op.text_comp_pool);

		compile_settings_copy : CompileSettings = compile_event.compile_settings;
 		compile_settings_copy.main_file_absolute_path = text_file.absolute_path_name;
		text_op.text_comp_data = CompileCode(compile_settings_copy, text_file.file_string.text_string,,text_op.text_comp_alloc);

		if text_op.text_comp_data.comp_errors.all_compiler_errors.count == 0 {
			log("Compilation successful.\n");
			//TODO We could grab this from the all_function_declarations["main"] instead
			text_op.exec_info.main_instr_index = text_op.text_comp_data.main_function_instr_index;
			//We can update break_points even if we are not in DEBUG mode so it is ready once we switch.
			//We only update BP_CODE because BP_ASM is not dependent on line numbers
			for * break_pt : text_op.exec_info.debug_info.break_points {
				if break_pt.bp_type == .BP_CODE {
					//TODO Can likely index this or do binary search to speed this up.
					for debug_line : text_op.text_comp_data.all_debug_lines {
						if break_pt.line_number <= debug_line.line_number {
							break_pt.line_number = debug_line.line_number;
							break_pt.asm_index = debug_line.start_asm_index;
							break_pt.end_asm_index = debug_line.end_asm_index;
							break;
						}
					}
				}
				//TODO We could set the line_number here but we just grab it at runtime instead
				//so that we can ignore it completely with asm_index
				// else if break_pt.bp_type == .BP_ASM {
				// }
				//TODO Should we remove BP_ASM if it is out of bounds? We don't render it anyways
				//so I guess we can leave it but then we will never hit it.
			}

			//We reset this by default when writing a message thats not added now
			//so we only don't reset it if we know there will be highlights
			// array_reset_keeping_memory(*text_op.console_highlights);
			SetTextOpConsoleMessage("Compilation successful.", text_op);

			text_op.l_bottom_pane_type = TextPaneType.DISASSEMBLY;
		} 
		else if text_op.text_comp_data.comp_errors.all_compiler_errors.count > 0 {
			array_reset_keeping_memory(*text_op.console_highlights);
			for text_op.text_comp_data.comp_errors.all_compiler_errors {
				array_add(*text_op.console_highlights, it.err_highlight);
			}
			SetTextOpConsoleMessage(text_op.text_comp_data.comp_errors.compiler_errors_string.text_string, text_op, reset_console_highlights=false);
			text_op.l_bottom_pane_type = TextPaneType.COMPILER_CONSOLE;
			// sb : String_Builder;
			// sb.allocator = temp;
			// for text_op.text_comp_data.comp_errors.all_compiler_errors append(*sb, it.msg,,temp);
		}
 	}
 	case .DEFAULT; {
		reset(*perm.all_data.comp_pool);
		perm.all_data.comp_data = CompileCode(compile_event.compile_settings, compile_event.code_string,,perm.all_data.comp_alloc);
	}
	}
}	
array_reset_keeping_memory(*perm.all_data.all_compile_code_events);

//TODO If we do a step over, then we should only execute 1 instruction. We could have this as an option
//in the function or a separate case externally. Maybe create a new function since stepping over will be 
//inherently different. We could add a stop_index but I think it makes more sense to just run 1 instruction
//and update the data accordingly.
//TODO Sanity check to ensure we only ahve 1 but we could either use a struct or just log an error here instead
//We are going to try and log an error here instead of crashing out. I am not sure if that is good but it's worth a shot.
//TODO We could set a struct here with a bool instead of an array and checking the array count if that is clearer
//BUT I will leave the array for now in case we do have multiple processes running, then it will be easier to see the bug.
//HOWEVER if this work eventually we can just have 1 struct and then that is the only execution that is happening.
/*DOC : MAYBE we should only allow text op here and then if people want to execute their own instructions
they can just call the function themselves. 
HOWEVER why would we want to execute instructions from a dll when we just write code from there anyways.
I THINK MAYBE BEST TO ONLY ALLOW TEXT OP FROM HERE and just leave it like this for now so I can set tests
BUT likely better to remove it later and only allow text ops to execute once we know this more clearly.
*/
if perm.all_data.all_process_instruction_events.count > 1 {
	log_error("Found % process instruction event before execution.\n", perm.all_data.all_process_instruction_events.count);
	array_reset_keeping_memory(*perm.all_data.all_process_instruction_events);
}
// if perm.all_data.all_process_instruction_events.count == 1 {
if OneOpIsExecuting(perm.all_data.all_process_instruction_events) {
// for perm.all_data.all_process_instruction_events {
ev : ProcessInstructionEvent = perm.all_data.all_process_instruction_events[0];
//TODO Certain tests failing because we require an op_space here now.
//TODO Should be able to run this without op_space with default exec_info RUN and later just with command line.
text_op, found_text_op := ArrayFindFirstByNameId(perm.all_data.all_text_op_space_data, 
	ev.op_space_id, "op_space_id");

//TODO should we only use text op for execution? I guess this way allows others to compile and execute without a text op
//but maybe that should only be done with a function. I think we can just use text op here and cleanup this code eventually
//WE COULD then only set 1 struct for processing instruction events (although if we leave the array we might catch
//errors where we set it multiple times)
//TODO We set a default here since we just run from 0 but maybe there is a way to make this clearer.
//TODO If we don't have a text_op then we should make sure this is not debug
default_exec_info : ExecutionInfo;
exec_info : *ExecutionInfo = *default_exec_info;
// exec_info.main_instr_index = perm.all_data.comp_data.main_function_instr_index;
if found_text_op {
	//TODO Need to set music instructions in this text op or in the general all_music_instruction so that
	//we can run separate things. Right now we only run the last compiled thing
	exec_info = *text_op.exec_info;
	//TODO We either have to copy the instructions or take a pointer. Maybe copying is best and we only
	//copy 1 time when we start the execution to not affect the text op instructions during execution.
	if text_op.exec_info.exec_state == .NOT_RUNNING {
		//We copy the instructions here since we add a HALT instruction during execution each frame
		//so this avoids changing the data pointer of the original text_op comp data which would remove the
		//pointer from the text op compilation allocator. We only do this when going from not running to running.
		//NOTE THAT we cant pass it in through exec info only because currently we are using this
		//during execution to check instruction bounds for jmp instructions.
		array_reset_keeping_memory(*perm.all_data.all_music_instructions);
		array_copy(*perm.all_data.all_music_instructions, text_op.text_comp_data.all_music_instructions);
		perm.all_data.comp_data = text_op.text_comp_data;
	}
}
if perm.all_data.all_music_instructions.count > 0 {
	//If we are not running yet, then we want to setup all the watch data after running
	//If we are already running or debug_stop then we don't want to.
	//TODO We could have a START_DEBUGGING but right now that is the same as NOT_RUNNING and
	//then executing the first instructions until we either hit a breakpoint or finish executing.
	reset_watch_data : bool = exec_info.exec_state == ExecutionState.NOT_RUNNING;
	previous_state : ExecutionState = exec_info.exec_state;
	//TODO Check for errors here
	//TODO exec_info should specify here that we are compilation if text_op or default if not.
	//OR WE COULD set this instructions in exec_info and do text and compilation stuff externally
	//so that instruction execution is not dependent on anything so we can easily just run instructions
	//later for example through and action we can easily just run a few instructions.
	cpu_err : CPUError = ExecuteManyInstructions(exec_info, perm.all_data);

	//TODO This should be an input setting otherwise we just execute and don't do this.
	//Eventually this should likely be a command we run and then we direct to output somewhere
	//like terminal or compiler console.
	//I think we only have to compute this on Compilation and then we can have a separate evaluator
	//which evaluates only operations every time we run some code in the debugger.
	/*TODO We could put this in ExecuteManyInstructions with a text option where we update
	debug info if we are in debug mode from in the function. Then we could also update the 
	the cursor and things like that all from the same place if things move around.
	*/
	if found_text_op {
		if exec_info.exec_state == .IS_DEBUG_STOP {
			/*DOC : Reset the call stack whenever we run some instructions in case we selected another call frame.
			  We need to set this before evaluating the watch row nodes so we have the right registers.
			  
			  TODO Could make this into a function if we reuse it somewhere else.
			*/
			exec_info.debug_info.chose_other_call_frame = false;
			exec_info.debug_info.selected_call_frame_index = 0;
			exec_info.debug_info.debug_all_registers = perm.all_data.all_register_memory;
			call_stack_line_diff : int = text_op.end_call_stack_index - text_op.start_call_stack_index;
			text_op.start_call_stack_index = 0;
			text_op.end_call_stack_index = call_stack_line_diff;
			text_op.highlighted_call_stack_index = 0;

			//TODO We could set this in the if but is_debug_stop should only be set while in DEBUG_MODE
			//otherwise it should always be false.
			//ACTUALLY maybe technically you don't need to but you would not be able to see anything.
			//We could lock the text editor into debug mode while is_debug_stop.
			assert(text_op.exec_info.exec_mode == .DEBUG);//sanity check
			if text_op.watch_data_rows.count > 1 {
				//We don't want to process the last row since it is always empty.
				//We could also check if that watch_data.name.count == 0 if there are issues with this.
				//NOTE : this is also asserted in EvaluateWatchData for an extra resilience check.
				//DOC : Had to change this inc ase we remove rows when evaluating if we have an error or different types.
				// for 0..text_op.watch_data_rows.count-2 {
				e_index : int = 0;
				while e_index <= text_op.watch_data_rows.count-2 {
					//NOTE : We only want to reset_data here if we just started executing since we have note
					//created the expression tree yet. Otherwise we only want to visit/evaluate the nodes.
					//TODO I think we should pass in text_file_id or text_op in here.
					//Then we can grab the proper compilation data associated with that text_file.
					//So only 1 compilation per text file. If we allow more than one, then you'd
					//have to allow a different creation path (like in the terminal) to compile a text_file
					//with a separate compilation that can be run separately
					EvaluateWatchData(e_index, text_op, perm.all_data, reset_watch_data);
					e_index += 1;
				}
			}

			op_space, found_op_space := ArrayFindFirstByNameId(perm.all_data.all_open_op_spaces, 
				text_op.op_space_id, "id");
			assert(found_op_space);
			assert(op_space.op_space_external_type == OpSpaceExternalType.txt);

			//If we moved the stop_line while executing, then we want to adjust where we are in the editor here.
			//TODO Technically we can get this stop_line from .ip reg as well like disasm below.
			//That might be better for consistency overall
			stop_d_line := GetDebugLineAsm(perm.all_data.all_register_memory[RegDef.pc].int_value, text_op.text_comp_data);
	    	edit_text_file, found_edit_text_file := ArrayFindFirstConstByNameId(perm.all_data.all_text_files,
    			text_op.file_tabs[text_op.ftab_i].text_file_id, "id");
	    	assert(found_edit_text_file);
	    	//DOC : I prefer checking the path here first so if we are in the same file then we don't change anything
	    	//and just move to the new debug line below.
			if stop_d_line.absolute_path_name != edit_text_file.absolute_path_name {
				//TODO FROM HERE This seems to be working with Test_DirectiveLoad BUT should likely test this
				//more extensively later.
				//IF ITS WORKING then we can remove the compiled out part below to keep the open file tab functionality consistent
				#if 1 {
				edit_text_file, found_edit_text_file = 
					OpenFileTab(stop_d_line.absolute_path_name, text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
				} else {
				/*DOC : If the new line is in a new a file, then we have to switch files.
				*/
				//TODO Should probably rename text_file.file_name -> text_file.absolute_path_name

		    	d_line_text_file, found_d_line_text_file := ArrayFindFirstConstByNameId(perm.all_data.all_text_files,
	    			stop_d_line.absolute_path_name, "absolute_path_name");
	    		if !found_d_line_text_file {
					loaded_text_file, d_line_text_loaded := LoadTextFile(stop_d_line.absolute_path_name, *perm.all_data.all_text_files);
					if d_line_text_loaded {
						//TODO We could put this add in LoadTextFile if that makes more sense.
						// array_add(*perm.all_data.all_text_files, loaded_text_file);
						found_d_line_text_file = true;
						d_line_text_file = loaded_text_file;
					} else {
						//TODO Should probably display an error in the text editor console here once we can
		    			// print_to_builder(*sb, "Text file : % not found.\n", file_name);
		    			print("Cannot load file : % on line : %.\n", stop_d_line.absolute_path_name, stop_d_line.line_number);
					}
	    		}
	    		//TODO FROM HERE add a hotkey to cycle between open text files and then make sure we jump back
	    		//to the d_line when we move around here. Then can write test for current and also moving around
	    		//with simple cycling
	    		if found_d_line_text_file {
					found_edit_text_file = true;
					// text_op.file_tabs[text_op.ftab_i].text_file_id = d_line_text_file.id;
					edit_text_file = d_line_text_file;

					found_tab : bool = false;
					for text_op.file_tabs if it.text_file_id == edit_text_file.id {
						found_tab = true;
						text_op.ftab_i = it_index;
						break;
					}
					if !found_tab {
						new_tab : *TextTab = array_add(*text_op.file_tabs);
						new_tab.text_file_id = edit_text_file.id;

						text_op.ftab_i = text_op.file_tabs.count-1;


						// text_op.file_tabs[text_op.ftab_i].tab_cursor = text_op.file_tabs[text_op.ftab_i].file_tabs[text_op.ftab_i].tab_cursor;
						// ResetTextCursor(*text_op.file_tabs[text_op.ftab_i].tab_cursor);
						//NOTE : Resizing here since this reset the start and end line_index and also the text cursor right char bounds
						//TODO Technically we can just update text line bounds and char bounds but this may be more resilient and consistent.
						ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
							perm.text_editor_data);
						//TODO Should this be in ResizeTextOpSpace						
						// if text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number > text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index {
						// 	MoveToLine(text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number, text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor);
						// }

					}
	    		}
	    		}
	    	}
			if found_edit_text_file &&
			  (stop_d_line.line_number < text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index ||
				stop_d_line.line_number > text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index)
			{
				MoveToLine(stop_d_line.line_number, edit_text_file.file_string, *text_op.file_tabs[text_op.ftab_i].tab_cursor);
			}

			//DOCU : This moves the disassembly so we are in the right place in the disasm pane.
			//TODO Should we put this in the input so that is adjusts itself no matter what?
			//Maybe not since there are no other cases unless we want to specifically jump which would be a separate action.
			ip_reg : int = perm.all_data.all_register_memory[RegDef.pc].int_value;
			if ip_reg < text_op.start_disasm_index || ip_reg > text_op.end_disasm_index {
				viewable_disasm_count : int = text_op.end_disasm_index - text_op.start_disasm_index;
				top_count : int = viewable_disasm_count / 2;
				text_op.start_disasm_index = ip_reg - top_count;
				if text_op.start_disasm_index < 0 {
					text_op.start_disasm_index = 0;
				}
				text_op.end_disasm_index = text_op.start_disasm_index + viewable_disasm_count;
				assert(text_op.end_disasm_index - text_op.start_disasm_index == viewable_disasm_count); //sanity check

				text_op.highlighted_disasm_index = ip_reg;
			}

			if cpu_err.is_error {
				SetTextOpConsoleMessage(tprint("CPU Error asm_index % : %.", cpu_err.error_index, cpu_err.msg), text_op);
				SetTextStatus(tprint("CPU Error asm_index %.", cpu_err.error_index), text_op);
			}
		} 
		else if exec_info.exec_state == .NOT_RUNNING {
			//TODO Is there a better / more systematic way to do these state changes?
			// stopped_running : bool = exec_info.exec_state == ExecutionState.NOT_RUNNING;
			// stopped_debugging : bool = was_debugging && stopped_running;
			//NOTE : We were debugging and now were not running. I think this is good way to do it
			if previous_state == .IS_DEBUG_STOP {
				top_wi : int = 0;
				//NOTE : The last row is always kept since we want 1 row for input
				while top_wi < text_op.watch_data_rows.count-1 {
					//TODO Should we do this with RemoveManyWatch? Is it even worth it? probably yes
					#if 1 {
					RemoveWatchSubRows(top_wi, text_op, 0);
					} else {
					while text_op.watch_data_rows[top_wi+1].watch_indent != 0 {
						RemoveWatchData(top_wi+1, text_op);
					}
					}
					top_wi += 1;
				}
				//Put the highlighted_name_index in bounds if it is out of bounds after removing the rows when the debugger stops.
				if text_op.highlighted_name_index >= text_op.watch_data_rows.count {
					text_op.highlighted_name_index = text_op.watch_data_rows.count-1;
				}
			}
			//Reset this here so we don't have weird instruction leftover causing issues somewhere else
			array_reset_keeping_memory(*perm.all_data.all_music_instructions);

			msg := "Executed Successfully";
			SetTextOpConsoleMessage(msg, text_op);
			SetTextStatus(msg, text_op);
		}
	}
}
if !exec_info.continue_execution_next_frame {
	array_reset_keeping_memory(*perm.all_data.all_process_instruction_events);
}
}	


/*TODO Eventually this can be run directly in terminal so we can choose the order
*/
// if keyboard.only_alt_down && keyboard.e_button.down_this_frame 
   // perm.all_data.input_check.is_writing_code
if IsInputMapPress(.RUN_EXTERNAL_UPDATE, .DOWN_THIS_FRAME, game_input) {
	//TODO Can grab the currently selected op_space and see if it has a dll here once we connect
	//dlls to text files and put them here.
	//TODO Could allow specific dynamic libraries to be set from the terminal for example
	//TODO I think eventually we can allow some kind of script to run external updates on startup
	//and also we can split between running with a command or just having a dynamic library function
	//that can run every frame instead
	if global_dynamic_libraries.count > 0 {
		array_add(*perm.all_data.all_run_external_update_events, global_dynamic_libraries[0].abs_path_name);
	}
}
for abs_path_name : perm.all_data.all_run_external_update_events
{
	dl, found_euf := ArrayFindFirstByNameId(global_dynamic_libraries, abs_path_name, "abs_path_name");
	if !found_euf {
		print("% external update file not found.\n", dl.abs_path_name);
		continue;
	} else if dl.ExternalUpdate_proc_address == null {
		print("Null found for ExternalUpdate proc in file : %.\n", dl.abs_path_name);
		continue;
	}
	//TODO We happens if we have an invalid function pointer here, I guess we can't really know and crash.
	//So we should set ExternalUpdate to null whenever that is possible to avoid issues.

	// We could reload as a terminal command but we do in here for now so it is clearer.
	// Although we compile the file as a terminal command for now but we could also do it here.
	
	//TODO We can make this a function AllDataToSharedLibraryData if needed
	//We can also set values in here and then check them on return to do some in game updates for example
	shared_lib : SharedLibraryData;
	shared_lib.audio_data = audio_data;
	shared_lib.all_mspace_data = *perm.all_data.all_mspace_data;
	shared_lib.all_tuning_systems = *perm.all_data.all_tuning_systems;
	shared_lib.all_tuning_pitches = *perm.all_data.all_tuning_pitches;
	//TODO How should be actually pass this in? Should we just put it in shared library?
	//It can't be global anymore...
	// shared_lib.all_next_ids = *ALL_NEXT_IDS;

	//TODO We could cast this beforehand to reuse but I will leave it like this for now so we only
	//keep 1 pointer and dont have to reset it all the time.
	ExternalUpdate := cast(Type_ExternalUpdate) dl.ExternalUpdate_proc_address;
	ExternalUpdate(*shared_lib);
}
array_reset_keeping_memory(*perm.all_data.all_run_external_update_events);


/* AUDIO STARTS HERE
	Audio for music_pts
*/
//TODO Need a way to set the audio position from any memory_unit
//We do this before so that we don't have a skip on every loop
/*We run this before audio events in case we need to restart the audio
or in case we have .RESET_AUDIO_TO_MEMORY_UNIT and so that will override
the IncrementRelAudioTime here.

This may be different if we eventually process notes on a separate thread for efficiency. 
Although we would most likely only do that if we receive external clock timing (eg midi clock).
*/
if perm.all_data.game_audio_play.play_state == AudioPlayState.PLAY {
	/*Note : Calling this again won't make a difference since it will simply reset it
	  and also calling this function twice in the same frame does not matter because
	  audio_timing only gets updated once per frame. 

	  TODO NOTE this is no longer does not make a different. We only call IncremetRelAudioTime here
	  so maybe we should not even have function. We don't want to call it anywhere else unless 
	*/
	IncrementRelAudioTime(*perm.all_data.game_audio_play, perm.all_data.audio_timing);
	UpdateAudioMemoryUnitPos(*perm.all_data.game_audio_play, perm.all_data.audio_timing);

	/*DOC : The idea here is that we can loop on any mspace by muting all the other mspaces and then it will
	skip over all of them. This allows 1 method with lots of flexibility for what we loop over and then
	we can rearrange mspace or rows or music points individually to go over or loop over different areas.
	FOR EXAMPLE if we want to check a specific section, then we can just copy that over to a new mspace and
	then mute every other mspace and just have that 1 mspace loop naturally.
	*/
	check_mspace := GetAudioMSpace(perm.all_data);
	if perm.all_data.game_audio_play.current_x_memory >= check_mspace.mspace_audio_row_size
		//REMINDER : We only want to loop around if we haven't already set the audio somewhere else this frame
		&& !perm.all_data.set_audio_position_data.is_set
	{
		check_mspace_index, found_check_mspace := ArrayFindFirstIndexByNameId(perm.all_data.all_mspace_data,
			perm.all_data.audio_mspace_id, "mspace_id");
		//TODO We could set this to mspace_index 0 if we did not find it
		assert(found_check_mspace);

		//TODO Should we only do this if we have no events already?
		//DOC : This allows us to skip over all muted mspaces on this same frame
		//Otherwise we would have skiped over 1 mspace per frame and have a delay to the next mspace
		//which might not matter for 2-3 mspaces but for more it would become noticeable at +16ms per mspace.
		next_mspace_index, all_muted := GetNextNonMutedMSpace(check_mspace_index, perm.all_data.all_mspace_data);
		//This means we looped around all mspaces and everything is silent so we stop the audio
		if all_muted {
			perm.all_data.game_audio_play.play_state = AudioPlayState.STOP;
		}
		perm.all_data.audio_mspace_id = perm.all_data.all_mspace_data[next_mspace_index].mspace_id;
		//TODO we could not do this and let the notes release with the envelopes
		//ACTUALLY for midi this is necessary
		array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.STOP_ALL_MUSIC_PTS));
		array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.RESET_AUDIO_TO_MEMORY_UNIT, 0));
	} 	
}

/*DOC : This way ensures that we only have 1 repositioning per frame, so we can make sure we set that exactly
how we need without overriding or doing multiple audio repositions.
*/
sapd : *SetAudioPositionData = *perm.all_data.set_audio_position_data;
if sapd.is_set {
	perm.all_data.audio_mspace_id = sapd.set_audio_mspace_id;
	array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.STOP_ALL_MUSIC_PTS));
	if sapd.set_audio_type == {
	case .SET_MEMORY_UNIT;
		array_add(*perm.all_data.all_audio_events, 
			MakeAudioEvent(.RESET_AUDIO_TO_MEMORY_UNIT, sapd.memory_unit));
	case .SET_MEMORY_X_FLOAT;
		array_add(*perm.all_data.all_audio_events, 
			MakeAudioEvent(.SET_AUDIO_TO_X_FLOAT, x_float=sapd.memory_x_float));
	}

	if perm.all_data.game_audio_play.play_state == AudioPlayState.PLAY {
		array_add(*perm.all_data.all_audio_events, MakeAudioEvent(.PLAY_NOTES_AT_CURRENT_MEMORY));
	} else {
		perm.all_data.game_audio_play.play_state = AudioPlayState.PAUSE;
	}

	sapd.is_set = false;
}

//DOC : We adjust the audio_mspace on reset so we don't have to update it.
//We could set this again bellow or just regrab it again if we update this in the audio events below.
audio_mspace : MusicSpaceData = GetAudioMSpace(perm.all_data);

/*TODO 
  COULD ALSO MAKE AND SET BOOLS LIKE A SET AND THEN THE ORDER WOULD ALWAYS BE FIXED
  AND DUPLICATES WOULD BE DEALT WITH NATURALLY
  So we would only have the all_audio_actions as above and so the order and amount of events
  would be fixed. This is likely better overall. Leaving this for now for flexibility
  but seems unnecessary in the long term if things remain similar.
*/
for audio_event : perm.all_data.all_audio_events {
	if audio_event.audio_event_type == {
	case AudioEventType.SET_AUDIO_TO_X_FLOAT; #through;
	case AudioEventType.RESET_AUDIO_TO_MEMORY_UNIT; {
		x_check_float : float64;
		if audio_event.audio_event_type == {
		case AudioEventType.RESET_AUDIO_TO_MEMORY_UNIT; {
		x_check_float = cast(float64) audio_event.initial_x_memory;
		perm.all_data.game_audio_play.rel_play_time = 
			audio_event.initial_x_memory / perm.all_data.game_audio_play.memory_units_per_second;
		}
		case AudioEventType.SET_AUDIO_TO_X_FLOAT; {
		x_check_float = audio_event.x_float;
		perm.all_data.game_audio_play.rel_play_time = 
			audio_event.x_float / perm.all_data.game_audio_play.memory_units_per_second;
		}
		}

		perm.all_data.game_audio_play.last_memory_unit_played = audio_event.initial_x_memory - 1;

		//TODO Could do this based on a float value event now too
		perm.all_data.game_audio_play.music_pt_play_index = 0;
		while perm.all_data.game_audio_play.music_pt_play_index < audio_mspace.all_music_pts.count &&
				audio_mspace.all_music_pts[perm.all_data.game_audio_play.music_pt_play_index].x_start_float < x_check_float
		{
			perm.all_data.game_audio_play.music_pt_play_index += 1;
		}

		UpdateAudioMemoryUnitPos(*perm.all_data.game_audio_play, perm.all_data.audio_timing);
	}
	case AudioEventType.PLAY_NOTES_AT_CURRENT_MEMORY; {
		//Going backwards since its sorted by row_index and we want to trigger last row_index first
		//TODO Could sort backwards by row_index instead then and also by x_start
		//If we indexed by x_start as well then this would be very efficient
		#if 1 {
		//DOC : This assumes all music pts are sorted by x_start_float since we just take 
		//the music_pt_play_index as the next index of the last one found here.
		//We use the next index (it_index+1) so that we don't play the same note twice.
		for audio_mspace.all_music_pts if ValueInMusicPt(perm.all_data.game_audio_play.float_x_memory, it) {
			array_add(*perm.all_data.all_start_playing_music_pts, it);
			perm.all_data.game_audio_play.music_pt_play_index = it_index+1;
		}
		} else {
		//OLD Version can remove once we know float is working well.
		for < music_pt : audio_mspace.all_music_pts {
			in_between : bool = perm.all_data.game_audio_play.current_x_memory >= music_pt.x_start &&
			   perm.all_data.game_audio_play.current_x_memory < music_pt.x_end;
			if in_between array_add(*perm.all_data.all_start_playing_music_pts, music_pt);
		}
		}
	}
	case AudioEventType.STOP_ALL_MUSIC_PTS; {
		//Stop all midi points
		for perm.all_data.all_playing_midi {
			note := cast(u8) it.music_pt_pos;
			note_off : MIDI_Message = create_midi_message(.Note_Off, note, channel = it.midi_channel);
			send_midi_message(game_memory.midi_output, note_off);
		}
		array_reset_keeping_memory(*perm.all_data.all_playing_midi);

		//Set all internal music_pt/osc_waves to release
		//so the envelope still releases and we don't get a click
		// #if DSOUND_AUDIO {
		for * mp_ow : perm.all_data.all_playing_music_pt_and_waves {
			//Set to release now since we have stopped/paused the audio
			// SetEnvelopeRelease(mp_ow.osc_wave.seconds, *mp_ow.osc_wave.envelope);
			ForceEnvelopeRelease(mp_ow.osc_wave.seconds, mp_ow.osc_wave.seconds + 0.02, *mp_ow.osc_wave.envelope);
		}
		//TODO Could set some synths to not stop here for hovering for example (or maybe we do that a completely different way)
		//OR we could only stop the synths from rows
		for * synth : perm.all_data.all_simple_synths for * wave : synth.simple_waves {
			ForceWaveRelease(wave.seconds, wave.seconds + 0.02, wave);
		}
		// }
		#if 0 {
		//TODO For now we only pass this event to the audio thread but maybe we can do more later this way.
		//Otherwise using a compswap might be more efficient although if we write in both threads then that
		//could lead to a deadlock if we're not careful so this is likely safer in any case.
		lock(*perm.locked_sound_data.audio_mutex);
		array_add(*perm.locked_sound_data.locked_audio_events, audio_event);
		unlock(*perm.locked_sound_data.audio_mutex);
		array_reset_keeping_memory(*perm.all_data.all_playing_music_pt_and_waves);
		// perm.locked_sound_data.stop_neume_audio = true;
		}
	}
	}
}
array_reset_keeping_memory(*perm.all_data.all_audio_events);

/*We place this after all_audio_events processing so that we can reset the audio
and then also load this reset memory_units audio on the same frame. This also things
like smooth looping of the whole piece and also general resetting while still playing
for example for continuing to play on recompilation and any other reset needed.
*/
if perm.all_data.game_audio_play.play_state == AudioPlayState.PLAY {
	gap : *GameAudioPlay = *perm.all_data.game_audio_play;
	//DOC : This assumes the values are sorted by x_start_float which is necessary to avoid playing the same note twice
	//and also so that we can just grab all the next notes and don't have to go through all the music pts at once.
	while gap.music_pt_play_index < audio_mspace.all_music_pts.count &&
			audio_mspace.all_music_pts[gap.music_pt_play_index].x_start_float <= gap.float_x_memory 
	{
		array_add(*perm.all_data.all_start_playing_music_pts, audio_mspace.all_music_pts[gap.music_pt_play_index]);
		gap.music_pt_play_index += 1;
	}

	for perm.all_data.all_playing_midi if it.x_end_float <= gap.float_x_memory {
		note := cast(u8) it.music_pt_pos;
		note_off : MIDI_Message = create_midi_message(.Note_Off, note, channel = it.midi_channel);
		send_midi_message(game_memory.midi_output, note_off);
		remove it;
	}
}

/*TODO
  Eventually, we should we add to_play as a bool in the MusicPoint itself so we don't have to perform this extra check.
  Can also add the row_system_type to the MusicPoint on generation. This might be better once we have SoA but
  also may be worth adding directly anyways so that these extra checks are unnecessary.
  These can all be set on MusicPoint creation based on the row at run-time. For now we leave it like this
  so we access only 1 source of truth which reduces the change of error.

  TODO We should either place this right after adding them above if it is the only place we add them OR
  we should only do this while PLAY is on to avoid passing invalid notes to the audio thread now.

*/
if perm.all_data.all_start_playing_music_pts.count > 0 {
	//TODO music_lane_rows can be sorted by sound_on and row_index so therefored
	//indexed by row_index and sorted by not muted first so it would be direct fetch
	//TODO Change this to not_muted
	//TODO Should this be filtered here or beforehand?
	#if 0 {
	rows_sound_on : [] *MusicLaneRow = ArrayFindAllPointersByNameId(audio_mspace.all_music_lane_rows, 
		true, "sound_on", temp);
	}

	/*This assumes sorted by row_index, so we go backwards with the convention that
	  we process the data on the music_pts backwards with asm. This would be different with 
	  code since then the player can process the pts however they want and use this convention
	  if they want.

	  MORE EFFICIENTLY we could sort by x_start and then row_index and put the x_ends in a separate
	  smaller array which would be checked every new memory_unit. Then we could just fetch by x_start
	  and keep track of the next x_start starting point and then just have to scan from there since
	  we are already sorted by row_index as a second sorting value. Then we just store the x_ends
	  in the all_playing_midi, like we are now, and then they will end when they end.
	  This way, we would not have to scan all_music_pts every new_memory_unit but only get
	  all the next x_start every time. This would be very efficient for playing everything sequentially.
	*/
	// NOTE WE NEED TO CHECK RANGE IN CASE OF AUDIO CURSOR SKIP (audio/video latency)
	// After last beat here in case we had an audio skip, we don't want to miss
	// some notes so we check everything >= after_last_beat = last_beat + 1 
	// and < after_new_beat = new_beat + 1
	// ALSO need to check range in case memory_unit time is < 1 frame time
	for music_pt : perm.all_data.all_start_playing_music_pts
	{
    	music_lane_row_ptr : *MusicLaneRow = *audio_mspace.all_music_lane_rows[music_pt.row_index];
    	// has_sound_on : bool = false;
    	// for rows_sound_on if it.total_row_index == music_pt.row_index {
    	// 	has_sound_on = true;
    	// 	music_lane_row_ptr = it;
    	// 	break;
    	// }
    	// if music_lane_row_ptr.sound_on 
    	if !music_lane_row_ptr.is_muted_row {
    		//TODO This should be pulled per row OR not and just taken directly from music_pt_pos
			if music_lane_row_ptr.row_system_type == {
			case .internal_message; {
				if music_lane_row_ptr.row_internal_synth_type == {
				case .SIMPLE_SYNTH; {
					synth, found_synth := ArrayFindFirstByNameId(perm.all_data.all_simple_synths, 
						music_lane_row_ptr.system_id, "synth_id");
					//TODO Output an error in terminal or somewhere to say that this synth dne.
					assert(found_synth);

					//TODO Can call ControlChangeSimpleSynth here
					//TODO CAn make this a function if we want to reuse it elsewhere
					message_type := cast(SimpleSynthMessageType) music_lane_row_ptr.sub_system_id;
					if message_type == {
					case .VOLUME; {
						synth.volume = cast(float) (music_pt.music_pt_float / 10.0);
						synth.volume = Clamp(0.0, synth.volume, 1.0);
					}
					case .WAVE_TYPE; {
						music_pt_int := cast(int) music_pt.music_pt_float;
						wave_type_int : int = Clamp(0, music_pt_int, enum_names(OscWaveType).count-1);
						synth.wave_type = cast(OscWaveType) music_pt_int;
					}
					case .ATTACK_SECONDS; {
						//TODO We could clamp this on the upper end as well but i guess it's fine
						synth.envelope.attack_seconds = max(DEFAULT_ATTACK_SECONDS, cast(float) music_pt.music_pt_float);
					}
					case .RELEASE_SECONDS; {
						//TODO We could clamp this on the upper end as well but i guess it's fine
						synth.envelope.release_seconds = max(DEFAULT_RELEASE_SECONDS, cast(float) music_pt.music_pt_float);
					}
					case .ATTACK_CURVE; {
						//TODO Should this be clamped in some way?
						synth.envelope.n_attack = cast(float) music_pt.music_pt_float;
					}
					case .RELEASE_CURVE; {
						//TODO Should this be clamped in some way?
						synth.envelope.n_release = cast(float) music_pt.music_pt_float;
					}
					}
				}
				case .SUBTRACTIVE_SYNTH; {
					//TODO
				}
				}
			}
			//TODO Can replace this with internal_pitch once we swap it out OR just neume_pitch
			case .internal_pitch; {
		    	//TODO can we do this somewhere else where we do all MusicPoints at once
		    	//TODO get the frequencies working with all TuningSystems and then maybe implement some.
		    	//Or move to op_space first and then tuning_systems. Should maybe have an option to not draw vertical for cents.
	    		tuning_system : TuningSystem;
	    		found_tuning_system : bool = false;
		    	for section : audio_mspace.all_section_to_row {
	    			if section.row_id == music_lane_row_ptr.id &&
	    				MusicPtStartInRange(section.start_x, music_pt, section.end_x) 
    				{
						tuning_system, found_tuning_system =
							ArrayFindFirstConstByNameId(perm.all_data.all_tuning_systems, 
								section.tuning_system_id, "id");
						break;
    				}
		    	}
		    	assert(found_tuning_system);

				//TODO We don't need to cast this to float, we can keep it float64 until we actually add it to the audio buffer.
				//The only difference is speed here since this is run every frame especially the audio buffer, it could be a significant
				//speed decrease to use float64, since we do a computation per sample so that is 1000s of times per frame.

				//TODO Need to pull this out once its finished so we can use the tuning system everywhere
				//TODO Need to grab ref_freq/base_frequency from SectionToRow
				//TODO I think it is better to have an enum for different general types and not specific
				frequency : float = MusicPtToFrequency(music_pt.music_pt_float, tuning_system, perm.all_data.all_tuning_pitches);
				//TODO If we group per row, then we don't have to get this for each music_pt
				if music_lane_row_ptr.row_internal_synth_type == {
				case .SIMPLE_SYNTH; {
					synth, found_synth := ArrayFindFirstByNameId(perm.all_data.all_simple_synths, 
						music_lane_row_ptr.system_id, "synth_id");
					//TODO Output an error in terminal or somewhere to say that this synth dne.
					assert(found_synth);
					wave : *OscWave = AddSimpleWaveFromFrequency(frequency, synth, audio_data);

			    	delta_x : float64 = music_pt.x_end_float - perm.all_data.game_audio_play.float_x_memory;
					end_seconds : float64 = delta_x / perm.all_data.game_audio_play.memory_units_per_second;
					SetWaveRelease(cast(float) end_seconds, wave, synth.envelope);
				}
				case .SUBTRACTIVE_SYNTH; {
					//TODO 
				}
				}

				//TODO Can use this if we want
				// array_add(*perm.all_data.all_playing_music_pts, music_pt);
			}
			case .midi_velocity; {
				//TODO Eventually we need to allow this per note/music_pt probably only in code
				//So we can check first if the music_pt itself has a velocity associated
				//to it before using the row value here
				music_lane_row_ptr.row_midi_data.midi_velocity = cast(u8) music_pt.music_pt_pos;
			}
			case .midi_pitch; {
				// We assume 12 tone eq here and that music_pt_pos is < 127
        		channel : u8 = music_lane_row_ptr.row_midi_data.midi_channel;
        		//TODO How should we grab the audio octave here? Should grab from row.
				FIXED_OCTAVE : u8 : 12*4;
				note := cast(u8) music_pt.music_pt_pos + FIXED_OCTAVE;
				velocity : u8 = music_lane_row_ptr.row_midi_data.midi_velocity;
				note_on : MIDI_Message = create_midi_message(.Note_On, note, velocity, channel);
        		send_midi_message(game_memory.midi_output, note_on);

        		//TODO Make function
        		//TODO FROM HERE set note_offs beforehand here and then move back the internal_synth
        		//method which can likely use this
        		playing_music_pt : PlayingMidi = ---;
        		//TODO remove x_end once we only use float
        		playing_music_pt.x_end = music_pt.x_end;
        		playing_music_pt.x_end_float = music_pt.x_end_float;
        		// We set this to note to make sure its the same as note_on message but eventually
        		playing_music_pt.music_pt_pos = note;
        		playing_music_pt.midi_channel = channel;
        		array_add(*perm.all_data.all_playing_midi, playing_music_pt);
         }
         case .midi_control_change; {
        		channel : u8 = music_lane_row_ptr.row_midi_data.midi_channel;
        		control_change : u8 = music_lane_row_ptr.row_midi_data.midi_control_change;
				cc_msg : MIDI_Message = create_midi_message(.Control_Change, control_change, cast(u8) music_pt.music_pt_pos, channel);
        		send_midi_message(game_memory.midi_output, cc_msg);
         }
         }
		}
	}
	array_reset_keeping_memory(*perm.all_data.all_start_playing_music_pts);
}
/*This is for internal audio and synthesis.
*/
// #if 1 {
for * synth : perm.all_data.all_simple_synths if synth.simple_waves.count > 0 {
	//TODO FROM HERE add the sample buffer as float and then we can copy it all over to s16 buffer
	//by multiplying S16_MAX and clamping for clipping (can likely set miniaudio to not do clipping then for efficiency)
	//LATER when we remove direct sound, then we can just copy the float directly
	//Need to generate simple synth based on a channels as well. Probably put a loop for that.
	GenerateSimpleSynthSamples(synth, audio_data.float_buffer, audio_data);
}

//TODO FROM HERE can check that this is the same as old sound on headphones and the implement hover waves
//with this new simple synth model

//TODO Once we remove direct sound, we can remove this and just make the audio buffer a float buffer
//and pass that back to miniaudio directly.
f32_buffer : *float = audio_data.float_buffer;
s16_buffer : *s16 = audio_data.audio_buffer;
s_index : int;
for 0..audio_data.SamplesToFill*audio_data.number_of_channels-1 {
	// for 0..audio_data.number_of_channels-1 {
		//NOTE : noClip is set right now in miniaudio so we don't clip but we can add that later and remove
		//from miniaudio if we want to allow our own or the players own clipping algorithms.
		//TODO We could clamp to [-1.0,1.0] in float and then pass that into miniaudio as well.
		// clipped_sample : float = Clamp(-1.0, f32_buffer[s_index], 1.0);
		// f32_to_s16 : float = S16_MAX * f32_buffer[s_index];
		//TODO We could do this in miniaudio or just allow it here so it can be adjusted as desired
		//and then we could remove it so people and clip however they want.
		// f32_to_s16_clipped : float = Clamp(-32767, f32_to_s16, S16_MAX);
		// s16_buffer[s_index] = cast(s16) (S16_MAX * clipped_sample);
		s16_buffer[s_index] += cast(s16) (S16_MAX * f32_buffer[s_index]);
		s_index += 1;
	// }
}
//We don't subtract 1 because we would have added one at the end here.
assert(s_index == audio_data.SamplesToFill * audio_data.number_of_channels);
// } else {
//Play audio here with internal synth
// #if DSOUND_AUDIO {
// if perm.all_data.all_playing_music_pt_and_waves.count > 0 {
	// buffer := NewArray(audio_data.SamplesToFill, float, false,, temp);
	//TODO Simple way for now, later we can generate samples and balance them out
	//OR most likely just use 1 synth per each audio and then can have a simple synth
	//which is just waves or have a subtractive synth which allows lfo and filter for example.
	for * mp_ow : perm.all_data.all_playing_music_pt_and_waves {
		// GenerateSamples(*mp_ow.osc_wave, <<audio_data, buffer);
		// AddSignalToAudioBuffer(buffer, audio_data);
		AddToAudioBuffer(*mp_ow.osc_wave, audio_data);
	}
// }

//Remove all internal synth notes that are finished
for * perm.all_data.all_playing_music_pt_and_waves {
	if it.osc_wave.wave_state == OscWaveState.FINISHED {
		remove it;
	}
}
// }
// } 
#if 0 {
//NEW miniaudio locked copy of the playing neumes
//TODO Might be best to do this all in one shot above if we separate hovering audio with neume audio.
if perm.all_data.all_playing_music_pt_and_waves.count > 0 {
	lock(*perm.locked_sound_data.audio_mutex);
	//TODO if we just pass the osc_waves, then we can just memcpy here
	//Then we can reserve and do memcpy and then do atomic swap with the count.
	//Or probably not atomic swap since were already locking here.
	// array_reserve
	for perm.all_data.all_playing_music_pt_and_waves {
		array_add(*perm.locked_sound_data.locked_audio_queue, it.osc_wave);
		// AddToAudioBuffer(*mp_ow.osc_wave, audio_data);
	}
	unlock(*perm.locked_sound_data.audio_mutex);
	//We just reset since the audio thread will handle it from here
	array_reset_keeping_memory(*perm.all_data.all_playing_music_pt_and_waves);
}
}
/*AUDIO ENDS HERE
*/


/*RENDERING STARTS HERE
*/
//We no longer update the mspace after this since we process audio and rendering so we set the mspace here
//directly and use that after this point.
render_mspace : MusicSpaceData = GetRenderMSpace(perm.all_data);
//Rendering Music Play point here so we stay in rendering section and also stay close to previous audio section
//TODO Could make starting play_pointer_pos a function if we reuse it or we can set this on compilation
//or if all_music_lane_rows.count > 0 since its always going to be the same.
if perm.all_data.render_mspace_id == perm.all_data.audio_mspace_id && render_mspace.all_music_lane_rows.count > 0 {
	top_row : MusicLaneRow = render_mspace.all_music_lane_rows[0];

	//TODO FROM HERE create rows and add max row size UNLESS WE SET THE ROW SIZE then just use that
	//Then use that and also use settings for memory unit width and units per second
	//we can just set the values for now and then use the settings by default later
	//maybe can change for memory unit width
	//TODO Can clean this up as well

	//TODO CAN MAKE COLOR AND THICKNESS ADJUSTABLE
	play_color : Vector4F = LOWER_WHITE_V;
	// if perm.all_data.game_audio_play.play_state == AudioPlayState.PLAY {
	// 	play_color = YELLOW_V;
	// }
	//TODO Could make a function for GetPlayPosX so we can do a goto for this for example
	// play_pos_x : float = GetRowXStart(top_row, perm.all_data.global_rules.memory_unit_width);
	// play_pos_x += cast(float) (perm.all_data.game_audio_play.float_x_memory * perm.all_data.global_rules.memory_unit_width);
	play_pos_x : float = GetPlayPosWorldX(top_row, perm.all_data.game_audio_play.float_x_memory, 
		perm.all_data.global_rules.memory_unit_width);
	#if 1 {
	//TODO This way feels the most natural, but we can put a setting for the other ones if needed
	bottom_row : MusicLaneRow = peek(render_mspace.all_music_lane_rows);
	total_height : float = top_row.row_world_base_start.y + top_row.row_height - bottom_row.row_world_base_start.y;
	play_line_pos := Vector2F.{play_pos_x, bottom_row.row_world_base_start.y};
	//0.1 width seems smoother on this 4k 27inch screen than 0.07. maybe good to check on other screens/resolutions
	// play_line_dim := Vector2F.{0.07,total_height};
	play_line_dim := Vector2F.{0.1,total_height};
	play_line : Rectangle2 = RectMinCenterDim(play_line_pos, play_line_dim);
	play_line_cam : Rectangle2 = WorldRectToCamRect(play_line, default_base_cam);
	PushRectangle(play_line_cam, play_color, renderer_data.base_render_group, order = 10);
	} 
	else #if 0 {
	for row : render_mspace.all_music_lane_rows {
		play_pos : Vector2F;
		play_pos.y = row.row_world_base_start.y + row.row_height + 0.5;
		play_pos.x = play_pos_x;
		cam_pos : Vector2F = WorldSpaceToCameraSpace(play_pos, default_base_cam);
		PushRectangle(cam_pos, Vector2F.{0.15,0.5}, play_color, renderer_data.base_render_group, order = 10);
	}
	}
	else #if 0 {
	for row : render_mspace.all_music_lane_rows {
		play_line_pos := Vector2F.{play_pos_x, row.row_world_base_start.y};
		play_line_dim := Vector2F.{0.07, row.row_height};
		play_line : Rectangle2 = RectMinCenterDim(play_line_pos, play_line_dim);
		play_line_cam : Rectangle2 = WorldRectToCamRect(play_line, default_base_cam);
		PushRectangle(play_line_cam, play_color, renderer_data.base_render_group, order = 10);
	}
	}
}

if render_mspace.is_fixed_audio_row_size {
	top_row : MusicLaneRow = render_mspace.all_music_lane_rows[0];
	// play_pos_x : float = GetRowXStart(top_row, perm.all_data.global_rules.memory_unit_width);
	// play_pos_x += cast(float) (render_mspace.mspace_audio_row_size * perm.all_data.global_rules.memory_unit_width);
	play_pos_x : float = GetPlayPosWorldX(top_row, cast(float64) render_mspace.mspace_audio_row_size, 
		perm.all_data.global_rules.memory_unit_width);
	//TODO This way feels the most natural, but we can put a setting for the other ones if needed
	bottom_row : MusicLaneRow = peek(render_mspace.all_music_lane_rows);
	total_height : float = top_row.row_world_base_start.y + top_row.row_height - bottom_row.row_world_base_start.y;
	play_line_pos := Vector2F.{play_pos_x, bottom_row.row_world_base_start.y};
	//0.1 width seems smoother on this 4k 27inch screen than 0.07. maybe good to check on other screens/resolutions
	// play_line_dim := Vector2F.{0.07,total_height};
	//TODO SETTINGS can adjust the width and color of the audio row play size line
	play_line_dim := Vector2F.{0.3,total_height};
	play_line : Rectangle2 = RectMinCenterDim(play_line_pos, play_line_dim);
	play_line_cam : Rectangle2 = WorldRectToCamRect(play_line, default_base_cam);
	//REMINDER : This needs to be bellow the play line since we need to see if we set it here
	PushRectangle(play_line_cam, BLACK_V, renderer_data.base_render_group, order = 9);
}

/*TODO IF we can render this both in world and in op_space then we just have to pass in the corresponding
render group in the right place. I think everything else can be the same / settable beforehand this way then.
So we can just make this a function which takes all the data or just AllData and then also a specific render_group
so we know where to render to exactly with the special ordering.

NOTE : The ordering here is necessary because we are doing scissors in the same group so each scissor
needs to have its own ordering. We do S64_MIN and give each scissor 10 values. We can increment that later if needed.
*/
order_increment : int = 10;
//We make this very big since we can eventually have lots and lots of rows :)
//TODO Can't we just have 1 set of these since all rows will be the same and not be overlapping?
//They might be for op_spaces but we will render those separately with separate code anyways.
//This is 10 more than the frame clear PushClear which is at S64_MIN.
next_order : int = S64_MIN+order_increment;
//TODO Maybe add a text shader eventually so we can overlay some text if needed.
//We might need to add 1 value per row to get it to work correctly with the 1 render group.
//TODO We could use base_render_group here but row_group is clearer and we don't have to juggle order index outside of the group.
//It may be less efficient but also maybe not. Can add a post_row_group for things on top and even put music_pts
//in the post_row_group if we can have things under that later.
//Eventually if we don't use base_render_group for anything else, then we can just put row_group in base_render_group
//and then maybe even post_row_group in base_render_group for > 0 and rows < 0. Let's see I might want to do that.
PushSetShaderColor(renderer_data.base_render_group, next_order);
// PushShaderEntries(renderer_data.post_row_group, 10000, 0, S64_MAX);
// PushSetShaderColor(renderer_data.row_group, next_order);
for row, row_index : render_mspace.all_music_lane_rows {
	defer next_order += order_increment;
	//NOTE : We cap the order since everything > 0 will be drawn on top of rows.
	//We still have around 2^62 possible rows with 10 values in here. Could be 2^61 if we allow 100 render order indices per row.
	//If this is too limited then we can use the row_group and post_row_group.
	if next_order >= -30 {
		print("Too many rows!\n");
		next_order = -10;
		break;
	}

	coll := ArrayFindFirstByAndOp(render_mspace.all_base_collision_entities, 
		EntityType.LANE_ROW_WITH_SECTIONS, "entity_type",
		row.id, "entity_id");
	cam_rect := WorldRectToCamRect(coll.rect, default_base_cam);
	pixel_rect := CamRectToPixelRect(cam_rect, renderer_data.base_render_group);
	if !RectanglesIntersect(renderer_data.base_render_group.render_viewport, pixel_rect) &&
		!ContainsRectangle(renderer_data.base_render_group.render_viewport, pixel_rect) 
	{
		//If this rect is outside the base_render_group.render_viewport then we can just not draw anything.
		//TODO We could optimize this further per SectionToRow below if that is worth it later.
		continue;
	}

	PushSetScissor(pixel_rect, renderer_data.base_render_group, order = next_order+4);

	//TODO Should we do this fetch by index or row_id
	section_to_row : [] SectionToRow = 
		ArrayFindAllVarName(render_mspace.all_section_to_row, row.id, "row_id");
	for section : section_to_row {
		//TODO I think this can be efficiently fetched by id since it should remain the same for default tuning_systems.
		tuning_system, found_tuning_system :=
			ArrayFindFirstByNameId(perm.all_data.all_tuning_systems,
				section.tuning_system_id, "id");
		assert(found_tuning_system);

		//NOTE : We use this whenever we need to adjust a size to the octave. This adjusts size both to the row's
		//given octave_height AND also to the compass interval of the particular interval. So something
		//with compass_interval > 2.0 (like bohlen-pierce) should be large and something < 2.0 (like wendy carlos)
		//should be smaller (each space and music point should be proportional)
		//TODO Can store this in tuning_system so we don't have to recompute OR
		//we could store everything as cents and do all this with cents so we don't have to deal with ratios here.
		octave_mult : float = row.octave_height * LogRatioToLinear(tuning_system.compass_interval, 2.0);

		/*TODO I think it makes sense to split up equal linear and ratio cases into separate loops.
		The equal would not need SpacePoint only color (which we would likely want to change to differentiate)
		between tuning systems with the same size but different sounds. We could then make optimizations for equal
		since we don't have to store anything besides color potentially and then only store for ratio proportional.
		Right now we store both in dspace_pos but think of the optimizations for something like a cent scale
		or something with 100 values but equal. Would not need any storage but how would the colors work?
		*/
		//NOTE : We use these SpacePoints for position and color now. So if we want to switch to having
		//separate rendering cases for RATIO and EQUAL, remember we still need color for EQUAL stored somewhere.
		//WE COULD JUST USE TUNING_PITCH DIRECTLY
		section_points : [] SpacePoint = ArrayFindAllVarName(perm.all_data.all_space_points, 
			section.dspace_id, "dspace_id", temp);

		//row_cam is at the base so we draw from that octave to row/octave ratio above.
		//TODO This is not efficient for non-octave-repeating scales. However it does work.
		//Would need to do it based on point position but then we have to loop through it since we could have ratio proportional points.
		//TODO This would be a case for splitting up ratio proportional and not but maybe this is fine.
		//If it's non-octave repeating we could just print 1 octave or cap at max_octave anyways
		//TODO Should store allowed octaves in row data as well.
		current_octave : int = cast(int) (row.row_cam.y / octave_mult);
		//TODO This allows for rendering negative octaves. I am trying it out with mod_index for neumes below
		//but maybe it does not make sense. I think allowing negative neume values is interesting though.
		//I will check in the literature later to see if negative note values are ever used mathematically
		//AND also need to make sure it works with op linear rows and geometries.
		if row.row_cam.y < 0 current_octave -= 1;
		// print("row.row_cam.y=%, octave_mult=%\n", row.row_cam.y, octave_mult);
		octaves_in_row : int = round_to_int(ceil(row.row_height / octave_mult));
		if octaves_in_row < 1 octaves_in_row = 1;
		// start_octave : int = current_octave - octaves_in_row;
		// if start_octave < 0 start_octave = 0;
		end_octave : int = current_octave + octaves_in_row;
		for octave : current_octave..end_octave {
		// for octave : current_octave-1..end_octave+1 for point : section_points {
			//NOTE : To make negative octaves clearer we dim them a bit
			//TODO I think putting the octave number somewhere on the side would also be helpful eventually.
			alpha : float = 1.0;
			if octave < 0 alpha = 0.9;
			for point : section_points {
				//TODO The rect_mesh allows us to have unequal points. 
				// If we only have equal then we can use the position instead and make the rect here.
				//TODO We could set the x here so we can change the width if we wanted to.
				//Leaving like that for now but maybe just zooming is enough. This way we don't have recompute all the points
				//rect_mesh if we change the x for everything.
				// world_rect : Rectangle2 = RectMinCenterDim(point.world_pos, 
				/*This relative positioning is better overall. Eventually, once we have 64 bit world, we can compute everything
				with 32-bit relative position and 64-bit row_world_base_start until we get to camera. Then convert to 32-bit
				after computing the camera and then storing into the renderer.
				*/
				/*NOTE : We store the row-relative position in dspace_pos.x and the relative base size of each point 
				in dspace_pos.y. This allows the same system for both linear and proportional points where everything is
				stored and computed only once per system and also can be octave_height adjusted at runtime here without
				any recomputation of the points.

				TODO IMPORTANT
				TODO Right now we are using dspace_pos directly BUT we could just compute here without SpacePoint for
				equal sized linear space since we only need octave_height point count for equal sized linear space.
				This would make it easier to change between tuning systems to make them look linear or ratio
				without having to do anything extra.
				SO THEN we would make 2 loops one for equal size and one for proportional and only fetch the points
				for proportional size otherwise we just compute directly.
				*/
				world_rect : Rectangle2 = RectMinCenterDim(Vector2F.{0, point.dspace_pos.x * octave_mult}, 
					//TODO Could allow changing the x in op_space but not in world_space eventually. So we could set that
					//in the row or possibly as a multiple here for consistency.
					Vector2F.{perm.all_data.global_rules.memory_unit_width, point.dspace_pos.y * octave_mult});
				// world_rect : Rectangle2 = point.rect_mesh;
				//TODO We could offset this from the lane here and either accumulate the row or set the row
				//to a lane relative position and the lane to be a world position... let's see how we use it eventually.
				//LANE OFFSET here instead of row might be better for lane dropdowns to collapse lanes down to 1 row.
				rect_diff : Vector2F = row.row_world_base_start;
				rect_diff.x += section.start_x * perm.all_data.global_rules.memory_unit_width;
				rect_diff.y += octave * octave_mult;
				rect_diff -= row.row_cam;
				MoveRect(rect_diff, *world_rect);
				cam_rect : Rectangle2 = WorldRectToCamRect(world_rect, default_base_cam);
				//TODO Might be best to do this on the world_rect
				cam_rect.max.x += (section.end_x - section.start_x - 1) * perm.all_data.global_rules.memory_unit_width;
				PushRectangle(cam_rect, alpha*point.color, renderer_data.base_render_group, order = next_order+5);
				PushRectangleOutline(cam_rect, GREY_BLACKER_V, renderer_data.base_render_group, r = 1.0, order = next_order+6);
			}
		}	

		//TODO If we split equal and proportional this would also simplify to not needing the SpacePoint fetch.
		//TODO This can be more efficient once we sort by row_index and x_start
		for music_pt : render_mspace.all_music_pts {
			if music_pt.row_index == row_index && 
				MusicPtStartInRange(section.start_x, music_pt, section.end_x)
			{
				music_pt_int := cast(int) music_pt.music_pt_float;
				octave, point_index := ComputeQuotientAndRemainder2(music_pt_int, section_points.count);
				#if 1 {
				//TODO For now we allow negative values to see how this goes. Maybe we don' later,
				//I am not sure this fully works with rendering so if not we can just compile this out and change point to use point_index directly. 
				//Maybe there is a cleaner way if we keep it with compute quotient and remainder with negative values
				mod_index : int = PosMod(point_index, section_points.count);
				if point_index < 0 octave -= 1;
				}
				//TODO This is overkill for equal so maybe best to split it up.
				//TODO Don't need this for equal either so maybe we should split this with equal and proportional.
				point : SpacePoint = section_points[mod_index];
				next_point : SpacePoint = section_points[(mod_index+1) % section_points.count];
				next_rect_y_dim : float = next_point.dspace_pos.y * octave_mult;

				//TODO Could make this the diff between this point and the next point instead
				remainder := cast(float) (music_pt.music_pt_float - music_pt_int);

				//TODO Add the remainder here based on the distance to the next point? I think no matter what this
				//will be awkward in some cases with ratio proportional points.
				rect_dim := Vector2F.{perm.all_data.global_rules.memory_unit_width, point.dspace_pos.y * octave_mult};
				point_rect : Rectangle2 = RectMinCenterDim(
					Vector2F.{0,point.dspace_pos.x * octave_mult + remainder * 0.5 * (next_rect_y_dim + rect_dim.y)}, 
					rect_dim);
				world_rect : Rectangle2 = point_rect;
				//We are replacing the x diff with some shading
				// world_rect.min += 0.1 * rect_dim;
				// world_rect.max -= 0.1 * rect_dim;
				world_rect.min.y += 0.2 * rect_dim.y;
				world_rect.max.y -= 0.2 * rect_dim.y;

				//TODO World is float32 right now so this works. When world is float64, we want to only cast to 32 after converting to camera rect.
				world_rect.max.x += cast(float) (music_pt.x_end_float - music_pt.x_start_float - 1.0) * perm.all_data.global_rules.memory_unit_width;

				// world_rect : Rectangle2 = point.rect_mesh;
				rect_diff : Vector2F = row.row_world_base_start;
				rect_diff.x += cast(float) music_pt.x_start_float * perm.all_data.global_rules.memory_unit_width;
				rect_diff.y += octave * octave_mult;
				rect_diff -= row.row_cam;
				MoveRect(rect_diff, *world_rect);
				cam_rect : Rectangle2 = WorldRectToCamRect(world_rect, default_base_cam);
				//TODO Need to give the rectangle a bit of a shade so we can see where the edges/corners are
				//TODO Might be best to do this on the world_rect
				PushRectangle(cam_rect, FGREEN_V, renderer_data.base_render_group, order = next_order+7);
				PushRectangleOutline(cam_rect, GREY_BLACKER_V, renderer_data.base_render_group, r = 1.0, order = next_order+8);
			}
		}

		//TODO Technically we can pull this out and draw them all in one shot along the row since the x will always be the same
		/*TODO A GOOD IDEA HERE is to allow a more flexible drawing where we draw rectangles as a float multiple (or fraction)
		of a number of memory units. Then we could overlay rectangles so that we can change what the rhythm looks like for each row
		or even for each section. Then we could not put the base one or dim the color of the base memory rectangle
		and this allows the user to manage how they want to do rhythm while keeping the rendering aspect generalized.
		*/
		world_rect : Rectangle2 = RectMinCenterDim(row.row_world_base_start, 
			Vector2F.{perm.all_data.global_rules.memory_unit_width, row.row_height});
		// world_rect.max.y = world_rect.min.y + row.row_height;
		// MoveRect(row.row_world_base_start, *world_rect);
		vert_rect : Rectangle2 = WorldRectToCamRect(world_rect, default_base_cam);
		//TODO Can store bottom left point in MusicLaneRow instead or just grab from collider
		// vert_rect : Rectangle2 = WorldRectToCamRect(section_points[0].rect_mesh, default_base_cam);
		for section.start_x..section.end_x-1 {
			//TODO Could just accumulate the translation and not create a new rect each time.
			next_rect : Rectangle2 = vert_rect;
			MoveRect(Vector2F.{it * perm.all_data.global_rules.memory_unit_width,0}, *next_rect);
			PushRectangleOutline(next_rect, GREY_BLACKER_V, renderer_data.base_render_group, r = 1.0, order = next_order+6);
		}
	}
}
//TODO We would have to reset the scissor to full viewport if we use base_render_group instead of a separate row_group like we are now.
//TODO Should have post_scissor_order variable somewhere for everything that is not in scissor to draw on top
// PushSetScissor(renderer_data.base_render_group.render_viewport, renderer_data.all_render_groups[0], order = next_order);
PushSetScissor(renderer_data.base_render_group.render_viewport, renderer_data.base_render_group, order = next_order);
// PushSetScissor(renderer_data.base_render_group.render_viewport, renderer_data.row_group, order = next_order);


for * op_space : perm.all_data.all_open_op_spaces {
if IsFixedViewableOpSpace(op_space.*, perm.all_data.render_mspace_id) {
	//Draw Window Rect
	op_rect_world : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size);
	// op_rect_cam : Rectangle2 = WorldRectToCamRect(op_rect_world, default_base_cam);
	op_rect_cam : Rectangle2 = WorldRectToCamRect(op_rect_world, default_base_cam);
	pixel_rect : Rectangle2 = CamRectToPixelRect(op_rect_cam, 
		renderer_data.base_render_group.screen_half_dim, renderer_data.base_render_group.pixels_per_square);

	//TODO Should we not only update this when we move the window?
	op_space.render_groups.pre_scissor_group.render_viewport = pixel_rect;
	op_space.render_groups.scissor_group_3D.render_viewport = pixel_rect;
	op_space.render_groups.scissor_group.render_viewport = pixel_rect;

	PushRectangleOutline(op_rect_cam, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 7, r = 2.0);
	//TODO should make the op_space background a different color
	//TODO Does this need to be a pre_render_group so we don't change it with pixels_per_square
	//NOTE : I am leaving this here for referene in case we need to put the zoom_factor in the renderer instead
	//of just having in OpSpaceToWorldSpace
	#if 0 {
	op_zoom_world_rect : Rectangle2 = RectCenterDim(op_space.world_offset / op_space.render_groups.scissor_group.zoom_factor, op_space.world_size);
	//TODO Can use MoveRect here instead of copying
	op_zoom_cam_rect : Rectangle2 = op_zoom_world_rect;
	op_zoom_cam_rect.min -= default_base_cam.world_pos / op_space.render_groups.scissor_group.zoom_factor;
	op_zoom_cam_rect.max -= default_base_cam.world_pos / op_space.render_groups.scissor_group.zoom_factor;
	PushRectangle(op_zoom_cam_rect, BLACK_V, op_space.render_groups.scissor_group, order = -999999999);
	} else #if 1 {
	/*TODO For 2D spaces, we can just place this in scissor_group
	  TODO Should allow transparent op_spaces where we don't draw this background.
	  Then we can overlay one op_space over another for visual clarity and convenience.

	  IMPORTANT IF WE HAVE ISSUES WITH GEOMETRY OVERLAP WITH LINEAR THEN USE PRE_SCISSOR_GROUP
	  This seems to work now with S64_MIN+9 but maybe it wont later anymore...

	  I CHANGE IT TO PRE_SCISSOR_GROUP because the text is not working and I don't feel like dealing with this anymore.
	  The problem is sporadic and I don't know if it's something I am doing wrong or just an opengl thing.
	  In any case, I will use pre_scissor_group and just make that a very small group for permanent background stuff.
	*/
	// PushRectangle(op_rect_cam, BLACK_V, op_space.render_groups.scissor_group, order = S64_MIN);
	PushRectangle(op_rect_cam, BLACK_V, op_space.render_groups.pre_scissor_group, order = S64_MIN);
	}

	//NOTE : We only render this when selected or hovered now. Will leave here as a reminder for now.
	// tb_data : TitleBarData = ComputeTitleBar(op_space, default_base_cam);
	// PushRectangle(tb_data.title_bar_cam_rect, BLACK_V, op_space.render_groups.post_render_group, order = -10000);
	// PushRectangleOutline(tb_data.title_bar_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 9, r = 2.0);

	// PushRectangleOutline(tb_data.close_op_space_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 10);
	// PushRectangle(tb_data.close_op_space_cam_rect, LRED_V, op_space.render_groups.post_render_group, order = 10);
	// PushCross(GetCenter(tb_data.close_op_space_cam_rect), GetWidth(tb_data.close_op_space_cam_rect), GetHeight(tb_data.close_op_space_cam_rect),
	// 	LIGHT_BROWN, op_space.render_groups.post_render_group, order = 10);

	// PushRectangleOutline(tb_data.fix_to_mspace_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 10);
	// PushRectangle(tb_data.fix_to_mspace_cam_rect, LRED_V, op_space.render_groups.post_render_group, order = 10);

	// PushRectangleOutline(tb_data.fix_op_space_cam_rect, LIGHT_BROWN, op_space.render_groups.post_render_group, order = 10);

	/*This is the new op_space that we will be doing. We will keep the ones below for now working since we have
	several examples and gradually move them into being general 2d and 3d spaces since that is more generalized
	and flexible for both the player and the instruction model.

	TODO FROM HERE - I think do this now while cohesively implementing the geometric spaces
	IMPORTANT SOUND IDEA : We could render a green outline or something obvious when a specific memory unit is playing
	on a particular dspace. This way it is easy to see what a specific sound looks like and still be able
	to have a flexible and general geometric space without the linear sequence of sound.

	TODO NOTE: WE COULD EVENTUALLY COLLAPSE ALL 2D SPACES AND 2D POINTS into the same array so we only have 2 arrays
	and then we could easily increment over them and store as much info as possible which would decrease memory fetch
	time substantially.
	*/
	//TODO Should this be only for space_2d? We can leave it out for now. Do we want to draw this in text_editors or 3d as well?
	//Maybe it could be useful in general later for marking up various op_spaces for people.
	//TODO We could even have a scissor_rect asm instruction with render_order that could be set so we could simulate the
	//something like that linear rows, but I don't know how well that would go. We could limit that here
	//and then allow it in code for example. Could try it out and see later.
	//TODO Eventually we can SIMD this and transform multiple shapes at once from op to cam space.
	for perm.all_data.all_space_rects if it.op_space_id == op_space.id {
		//TODO Could only render if the rectangle is in the op space camera RectangleIntersect || ContainsRectangle
		cam_rect : Rectangle2 = OpRectToCamRect(it.rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
		PushRectangle(cam_rect, it.color, op_space.render_groups.scissor_group, it.render_order);
	}
	for perm.all_data.all_space_quads if it.op_space_id == op_space.id {
		cam_quad : Quad2F = OpQuadToCamQuad(it.quad, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
		PushQuadViewport(cam_quad, it.color, op_space.render_groups.scissor_group, order=it.render_order);
	}
	for perm.all_data.all_space_triangles if it.op_space_id == op_space.id {
		cam_tri : Triangle2F = OpTriangleToCamTriangle(it.triangle, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
		PushTriangle2D(cam_tri, it.color, op_space.render_groups.scissor_group, order=it.render_order);
	}
	for perm.all_data.all_space_text if it.op_space_id == op_space.id {
		cam_pos : Vector2F = OpSpaceToCameraSpace(it.op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
		//TODO Should we have render_order fixed here since this the same for all op_space text or pass this in for convenience?
		//It has to be after the text_shader anyways, unless we just push it everytime but I think that would possibly
		//make the renderer slightly slower long term if we want to use SIMD and maybe other optimizations. Something to consider...
		cam_pos.x -= 0.5*it.text.count*perm.text_editor_data.code_font_1_char_width_world;
		PushText(cam_pos, it.text, it.color, op_space.render_groups.scissor_group, 10003);
	}

	is_chosen_op_space : bool = ArrayFindFirstByAndOpCheck(perm.all_data.all_chosen_entities,
		op_space.id, "id", EntityType.OP_SPACE, "entity_type");

	if OpSpaceExternalType.space_2d == op_space.op_space_external_type ||
	   //TODO Can remove once we refactor. Leaving for now since we still have some old circle op_spaces in some examples.
	   //TODO Need to create space_2d now instead of circle and update those examples.
      OpSpaceExternalType.circle == op_space.op_space_external_type 
   {
		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(perm.all_data.all_op_space_spec_data,
			op_space.id, "op_space_id");
		assert(found_op_spec_data);
		for op_spec_data.ass.all_space_rects {
			//TODO Could only render if the rectangle is in the op space camera RectangleIntersect || ContainsRectangle
			cam_rect : Rectangle2 = OpRectToCamRect(it.rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushRectangle(cam_rect, it.color, op_space.render_groups.scissor_group, it.render_order);
		}
		for op_spec_data.ass.all_space_quads {
			cam_quad : Quad2F = OpQuadToCamQuad(it.quad, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushQuadViewport(cam_quad, it.color, op_space.render_groups.scissor_group, order=it.render_order);
		}
		for op_spec_data.ass.all_space_triangles {
			cam_tri : Triangle2F = OpTriangleToCamTriangle(it.triangle, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushTriangle2D(cam_tri, it.color, op_space.render_groups.scissor_group, order=it.render_order);
		}
		for op_spec_data.ass.all_space_text {
			cam_pos : Vector2F = OpSpaceToCameraSpace(it.op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			//TODO Should we have render_order fixed here since this the same for all op_space text or pass this in for convenience?
			//It has to be after the text_shader anyways, unless we just push it everytime but I think that would possibly
			//make the renderer slightly slower long term if we want to use SIMD and maybe other optimizations. Something to consider...
			//TODO We could center that text for y as well if that seems better
			cam_pos.x -= 0.5*it.text.count*perm.text_editor_data.code_font_1_char_width_world;
			PushText(cam_pos, string.{it.text.count, it.text_chars.data}, it.color, op_space.render_groups.scissor_group, 10003);
		}
		for circle : op_spec_data.all_op_circle_spaces {
			/*We draw the circle separately because if we want to filter points, then we can. ALSO if we want to draw
			music_pts as float then this would be clearer. Let's see how it goes but I like the 3 layer way. It is flexible and clear.

			COULD ALSO JUST STORE 40, 80 and 120 and then we can set that in the circle based on what the player wants
			and then draw the circle here like that
			TODO Should we just draw the lines always as maybe 2 times the amount of points instead?
			This way the circle looks like a circle and points are drawn on it. Then we could also draw
			all the circles at once if they are the same. Also music_pts
			TODO Move circle_roots somewhere better and possibly do the gradation jump with 120 roots of unity.
			*/
			previous_point_cam_pos : Vector2F = OpSpaceToCameraSpace(circle.radius*circle_roots[circle_roots.count - 1], op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			for circle_roots {
				op_pos : Vector2F = circle.radius*it + circle.world_center;
				cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				PushQuadLineViewport(previous_point_cam_pos, cam_pos, GREY_DARKER_V, 0.05, op_space.render_groups.scissor_group, order = 6);
				previous_point_cam_pos = cam_pos;
			}
		}
		for sp : op_spec_data.all_op_spirals {
			//TODO Could reuse this for a spiral that is circle_space but with octaves for each spiral.
			//We could then reuse the spiral drawing and just update the space and music point positioning code.
			// sp, found_spiral := ArrayFindFirstByNameId(perm.all_data.all_spiral_spaces,
			// 	dspace_to_op_space.dspace_id, "dspace_id");
			// assert(found_spiral);

			//We use roots_of_unity here because it is much faster to not have to recompute sine for each point.
			//TODO Eventually we should store maybe 1200 roots_of_unity and then we just have to fetch and not recompute
			//Or just between 0-120 for the whole array.
			roots_of_unity := RootsOfUnity(sp.tuning_count, sp.is_clockwise, sp.rotate,, temp);

			first_world_pos : Vector2F = IndexToSpiralPos(0, sp, roots_of_unity);

			start_index : int = 1;
			end_index : int = sp.chord_count * sp.tuning_count - 1;
			if sp.is_loop {
				// last_world_pos : Vector2F = IndexToSpiralPos((sp.chord_count*sp.tuning_count), sp.*, roots_of_unity);
				last_world_pos : Vector2F = IndexToSpiralPos(end_index, sp, roots_of_unity);
				//TODO Could optionally draw this or dim it even more if it's too distracting
				PushQuadLineViewport(OpSpaceToCameraSpace(last_world_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam), 
					OpSpaceToCameraSpace(first_world_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam), 
					0.6*LBLUE_V*0.65, 0.05, op_space.render_groups.scissor_group, order = 6);
			} else {
				end_index += 1;
			}

			previous_point_cam_pos : Vector2F = OpSpaceToCameraSpace(first_world_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			for start_index..end_index {
				world_pos : Vector2F = IndexToSpiralPos(it, sp, roots_of_unity);
				cam_pos : Vector2F = OpSpaceToCameraSpace(world_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				PushQuadLineViewport(previous_point_cam_pos, cam_pos, GREY_DARKER_V*0.6, 0.05, op_space.render_groups.scissor_group, order = 5);
				previous_point_cam_pos = cam_pos;
			}
		}
		//TODO I pulled this out from below to draw the axes but I'm not sure it's useful anymore.
		//I've compiled it out for now since the cs2 works without the object anyways for rendering and input
		//so we can just keep it for updating if we add/remove points and values later.
		#if 0 {
		for chord_s2 : op_spec_data.all_op_chord_s2 {
			//TODO Left the code here as a reminder but I find it feels weird and out of place now to have the axis.
			//We could pass it in as a setting if needed.
			#if 0 {
			//Draw chord_s2 current direction axes
			//TODO make these angled with the direction and color of the respective voices
			rect : Rectangle2 = RectCenterDim(chord_s2.dspace_world_center, chord_s2.dspace_dim);
			rect_top_left : Vector2F = MakeV2F(rect.min.x, rect.max.y);
			axis_pos : Vector2F = rect_top_left + Vector2F.{-2,2};
			axis_pos_cam : Vector2F = OpSpaceToCameraSpace(axis_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);

			// axis_up_cam : Vector2F = axis_pos + Vector2F.{1.25,1.25};
			axis_up_cam : Vector2F = axis_pos + Vector2F.{1.15,1.15};
			op_up_cam := OpSpaceToCameraSpace(axis_up_cam, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			// axis_down_cam : Vector2F = axis_pos + Vector2F.{1.25,-1.25};
			axis_down_cam : Vector2F = axis_pos + Vector2F.{1.15,-1.15};
			op_down_cam := OpSpaceToCameraSpace(axis_down_cam, op_space, op_space.op_2D_cam.world_pos, default_base_cam);

			//TODO Can we remove this and just store the arrow colors in ChordSpace2? Or is the invariant concept still good?
			// invariant_0_data : InvariantData = ArrayFindFirstByNameId(perm.all_data.all_invariants, chord_s2.invariant_ids[0], "id");
			// invariant_1_data : InvariantData = ArrayFindFirstByNameId(perm.all_data.all_invariants, chord_s2.invariant_ids[1], "id");
			// invariant_0_color : Vector4F = invariant_0_data.color;
			// invariant_1_color : Vector4F = invariant_1_data.color;
			invariant_0_color : Vector4F = chord_s2.random_color_0;
			invariant_1_color : Vector4F = chord_s2.random_color_1;
			if chord_s2.swapped_matrix_flag swap(*invariant_0_color, *invariant_1_color);
			PushQuadArrowViewport(axis_pos_cam, op_up_cam, invariant_0_color, 0.1, op_space.render_groups.scissor_group, order = 7);
			PushQuadArrowViewport(axis_pos_cam, op_down_cam, invariant_1_color, 0.1, op_space.render_groups.scissor_group, order = 7);
			}
		}
		}

		//TODO Turn this into a function pointer in ExternalDataToOpSpace along with all other 
		//rendering so we can generalize it and then also use it in external code.
		//TODO Can reuse DSpaceToOpSpaceIndex for other dspace types and then have
		//circle, linear, spiral and chord_s2 in the same op_space and allow player to put wherever.
		array_dspace_to_op_space_id : [] DSpaceToOpSpaceIndex =
	    	ArrayFindAllVarName(perm.all_data.all_dspace_to_op_space_id,
	    		op_space.id, "op_space_id", temp);

    	#if 0 {
		//TODO This way may be faster later to do each type at a time... but maybe we just sort the above
		//array by type and then the array below will work the same way anyways    		
		//TODO This is a secondary filter for each type so we can print by type... hmmm
		//Right now we are drawing by op_space so not sure about this.
		circles_in_op_space : [] Space2D = ArrayFindAllByBothNames(
			perm.all_data.all_old_circle_spaces, "dspace_id",
			array_dspace_to_op_space_id, AllOrEqualsVarName, "dspace_id", temp);
		}

		//TODO We could draw all the circles at once and store the *RenderGroup or *OpSpace in the Space2D
		//or something like that. That would be much faster since all circles are near each other and so
		//we would have memory locality and also code locality, although probably less clear code-wise which 
		//dspaces are in which op_space, so can leave like this for now until we optimize.
		/*NOTE : Could we potentially store everything as op_space specific and then just print all the
		points out, for example, space_points per op_space in 1 go through 1 array? 
		Maybe that would work for space_points but not for music_pts? 
		We could store an array of memory_unit_to_dspace music_pts with op_space and then just print those and then 
		update them only as code changes. I think it could be done for everything with some thought and optimization.
		Can likely do the same for 3D and store all 3d points with op_space_id stored with the data.
		EVENTUAL OPTIMIZATION : Only have space_points and lines and music_pts already associated to op_spaces
		and then a second array with current visible ones. Then just render out all the visible ones and 
		this would be highly SIMDable and even multi-threadable (1 thread for each op_space).
		This method would even be customizable by player for triangles since then we just need to associate the
		triangles with op_spaces and the player can do whatever they want with that. (Rectangles and lines can
		be optimized with the provided dspace arrays).
		*/
		// PushSetShaderColor(op_space.render_groups.scissor_group, order = -5);
		// PushSetScissor(op_space.render_groups.scissor_group.render_viewport, op_space.render_groups.scissor_group, order = -10);
		order_increment : int = 10; //TODO Can make this 20 or more later if needed.
		op_linear_order : int = S64_MIN+order_increment;
		for dspace_to_op_space : array_dspace_to_op_space_id {
			if OpDSpaceType.CIRCLE == dspace_to_op_space.op_dspace_type {
				circle : CircleSpace = ArrayFindFirstConstByNameId(perm.all_data.all_new_circle_spaces,
					dspace_to_op_space.dspace_id, "dspace_id");
				/*We draw the circle separately because if we want to filter points, then we can. ALSO if we want to draw
				music_pts as float then this would be clearer. Let's see how it goes but I like the 3 layer way. It is flexible and clear.

				COULD ALSO JUST STORE 40, 80 and 120 and then we can set that in the circle based on what the player wants
				and then draw the circle here like that
				*/
				//TODO Should we just draw the lines always as maybe 2 times the amount of points instead?
				//This way the circle looks like a circle and points are drawn on it. Then we could also draw
				//all the circles at once if they are the same. Also music_pts
				// previous_point_cam_pos : Vector2F = WorldSpaceToCameraSpace(circle.radius*circle_roots[circle_roots.count - 1] + circle.world_center, default_base_cam);	
				//TODO Move circle_roots somewhere better and possibly do the gradation jump with 120 roots of unity.
				previous_point_cam_pos : Vector2F = OpSpaceToCameraSpace(circle.radius*circle_roots[circle_roots.count - 1], op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				for circle_roots {
					op_pos : Vector2F = circle.radius*it + circle.world_center;
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushQuadLineViewport(previous_point_cam_pos, cam_pos, GREY_DARKER_V, 0.05, op_space.render_groups.scissor_group, order = 6);
					previous_point_cam_pos = cam_pos;
				}

				//We draw the points separately since then we can filter if needed and this is more efficient.
				/*TODO IF WE WANTED DYNAMIC POINTS. Then we could compute cos and sin at runtime and have a separate
				   dynamic circle which could change shape while things are running more efficiently for example.
				   Then we would NOT have SpacePoint and just compute cos and sin here based on tuning_pitches
				   and how many points we want to show. This would be the same code we use to create SpacePoint now
				   but we would compute it every frame. That would be interesting! Circles changing every frame 
				   between tuning_systems for example. I am not sure how useful it is, but is likely worth trying.
				*/
				#if 0 {
				circle_points : [] SpacePoint = ArrayFindAllVarName(perm.all_data.all_space_points,
					circle.point_dspace_id, "dspace_id", temp);
				for point, point_index : circle_points {
					world_pos : Vector2F = circle.transform * point.dspace_pos + circle.world_center;
					world_rect : Rectangle2 = RectCenterDim(world_pos, circle.point_dim);
					cam_rect := OpRectToCamRect(world_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushRectangle(cam_rect, point.color, op_space.render_groups.scissor_group, order = 7);
				}
				}
				//NOTE : We were using memory unit to dspace here before but now we don't since we
				//just set the values explicity for each geometry/shape and map_memory will allow use
				//to connect them if we want to use that connection for anything.
				//Also old dynamic memory mapping way is very inefficient.
				//It's in dead code now if ever we need to check it for anything.
			} else if OpDSpaceType.OLD_LINEAR == dspace_to_op_space.op_dspace_type {
				op_linear_data : OpLinearData = ArrayFindFirstConstByNameId(perm.all_data.all_op_linear_data,
					dspace_to_op_space.dspace_id, "dspace_id");

				//TODO We don't even need these points for EQUAL_TEMPERAMENT
				linear_space_points : [] SpacePoint = ArrayFindAllVarName(perm.all_data.all_space_points, 
					dspace_to_op_space.dspace_id, "dspace_id", temp);

				for linear_space_points {
					//TODO Ultimately this should be done with relative values to avoid floating point error
					//We can know world position from memory_index and then relative from there
					//and then ultimately take the relative position from the current chunk to avoid floating point error
					/*We are drawing each space point across the x BUT it would be more efficient to just draw the rectangle.
					Not sure exactly how to use this so we could wait because maybe we just have specific dspaces anyways.
					This way allows both in any case.
					*/
					//TODO MORE EFFICIENT HERE TO DRAW JUST 12 RECTANGLES and stretch them for each point
					//and then draw the y and x outline (could do y with rectangles and then x afterward) 
					for op_grid_x : 0..op_linear_data.grid_size_x-1 {
						// cam_rect : Rectangle2 = WorldRectToCamRect(point.rect_mesh, default_base_cam);
						//TODO We can pull this out since likely the SpacePoints (maybe change the data model if that's better)
						op_rect : Rectangle2 = it.rect_mesh;
						MoveRect(.{op_grid_x*it.rect_dim.x, 0}, *op_rect);
						cam_rect : Rectangle2 = OpRectToCamRect(op_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
						PushRectangle(cam_rect, it.color, op_space.render_groups.scissor_group, order = 8);

						//TODO STORE THESE LINES AS WELL SO WE DONT HAVE TO DO THIS AND THEN JUST PRINT THOSE OUT
						//CAN PROBABLY EVEN STORE THE R in there for convenience
						//TODO this doubles the line for each outline so we only want one so
						//we have to draw the grid some other way, this is simply very convenient for now
						//THIS MAKES THE MUSIC_PT LOOK LIKE ITS PUSHED TO THE LEFT BECAUSE OF MORE LINES ON ONE SIDE
						PushRectangleOutline(cam_rect, GREY_BLACKER_V, op_space.render_groups.scissor_group, r = 1.0, order = 9);
					}
				}

				//TODO Should we pull this out? I think we will only use it here for convenience
				LinearMusicPt :: struct {
					//We might only need the music_pt_float in here. Leaving the MusicPoint just in case for now.
					music_pt : MusicPoint;
					x_grid_pos : int; //TODO This could be a float... or maybe not...
					// y_grid_pos : int;
				}

				linear_music_pts : [..] LinearMusicPt;
				linear_music_pts.allocator = temp;
				for perm.all_data.all_memory_unit_to_dspace if it.dspace_id == dspace_to_op_space.dspace_id {
					memory_music_pts : [] MusicPoint =
						GetAllMusicPtPosByPosition(it.row_index, it.x_index,
							perm.all_data.all_mspace_data[0].all_music_pts, MusicPoint);
					//TODO Should likely have a y-based filter in GetAllMusicPtPosByPosition so we dont need to make
					//2 arrays and not go through it again although in general it won't be that much.
					viewable_music_pts : [] MusicPoint = 
						FilterMusicPtsInView(memory_music_pts, op_linear_data.base_note, linear_space_points.count);

					for mp : viewable_music_pts {
						//TODO For pitch class set option we would have to modulo within an octave
						array_add(*linear_music_pts, LinearMusicPt.{mp, it.x_grid_pos});
					}
				}

				//TODO Add extra linear pts so we can add specific points if we want
				//Although these would not be represented well in the audio as they would not be played...
				//We could make EXTRA LINEAR PTS A DIFFERENT COLOR and also allowed to have length

				//TODO For uneven rendering temperaments would need to put this in the loop and then interpolate
				//between space points for floating point values
				//TODO If all the values are equal, pretty sure this can just be linear_space_points[0]
				//I think this is only needed for uneven rendering
				mod_base_note : int = op_linear_data.base_note % linear_space_points.count;
				base_point : SpacePoint = linear_space_points[mod_base_note];
				base_rect : Rectangle2 = base_point.rect_mesh;
				rect_dim : Vector2F = GetDim(base_rect);
				base_rect.min += 0.1 * rect_dim;
				base_rect.max -= 0.1 * rect_dim;
				base_rect.min.y += 0.1 * rect_dim.y;
				base_rect.max.y -= 0.1 * rect_dim.y;
				for linear_music_pts {
					music_pt_rect : Rectangle2 = base_rect;
					y_pos := cast(float) (it.music_pt.music_pt_float - cast(float64) op_linear_data.base_note);
					x_pos : float = it.x_grid_pos * base_point.rect_dim.x;
					MoveRect(MakeV2F(x_pos,y_pos), *music_pt_rect);

					//TODO Could have an option in OpLinearData which carries over the music_pt_length
					//Leaving here in case these can have lengths as well eventually 
					//(maybe with the extra linear points, we can store MusicPoint with lengths as normal)
					// - 1 because the space_point is already of size 1
					// music_pt_length : float = (music_pt.x_end - music_pt.x_start - 1) * perm.all_data.global_rules.memory_unit_width;
					// music_pt_rect.max.x += music_pt_length;

					//TODO Can use a different color here for extra_music_pts (maybe can do it in a different loop?)
					//Or just have 2 cases in this loop for now
					cam_rect : Rectangle2 = OpRectToCamRect(music_pt_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushRectangle(cam_rect, FGREEN_V, op_space.render_groups.scissor_group, order = 10);
				}
			} else if OpDSpaceType.LINEAR == dspace_to_op_space.op_dspace_type {
				//NOTE : Keeping in scissor_group in case we want to allow any overlap for various geometries.
				//Can put in pre_scissor_group later if needed for some other reason.
				//SWITCH TO pre_scissor_group later if there are issues with the black rectangle or overlapping geometries...
				//TODO This is not necessary with pre_scissor_group. Leaving here just in case.
				op_linear_order += order_increment;
				if op_linear_order >= -30 {
					print("Too many rows!\n");
					op_linear_order = -10;
					break;
				}

				PushSetShaderColor(op_space.render_groups.scissor_group, op_linear_order);
				row : MusicLaneRow = ArrayFindFirstByNameId(perm.all_data.all_op_linear_rows,
					dspace_to_op_space.dspace_id, "id");

				coll := ArrayFindFirstByAndOp(perm.all_data.all_op_collision_entities, 
					EntityType.OP_LINEAR_ROW, "entity_type",
					row.id, "entity_id");
				cam_rect := OpRectToCamRect(coll.rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				pixel_rect := CamRectToPixelRect(cam_rect, op_space.render_groups.scissor_group);
				if RectanglesIntersect(pixel_rect, op_space.render_groups.scissor_group.render_viewport) {
					inter : Rectangle2 = ComputeRectIntersect(pixel_rect, op_space.render_groups.scissor_group.render_viewport);
					PushSetScissor(inter, op_space.render_groups.scissor_group, order = op_linear_order);
				} else if ContainsRectangle(op_space.render_groups.scissor_group.render_viewport, pixel_rect) {
					PushSetScissor(pixel_rect, op_space.render_groups.scissor_group, order = op_linear_order);
				} else { //if the row is outside the op_space rectangle then we don't need to draw it at all
					continue;
					// PushSetScissor(op_space.render_groups.scissor_group.render_viewport, op_space.render_groups.scissor_group, order = op_linear_order);
				}

				memory_to_row : [] MemoryUnitToDSpace = 
					ArrayFindAllByAndOp(perm.all_data.all_memory_unit_to_dspace, 
						OpDSpaceType.LINEAR, "op_dspace_type",
						row.id, "dspace_id", temp);

				row_check_id : int = row.id;
				current_section_to_row : [] SectionToRow = perm.all_data.all_op_section_to_row;
				//TODO Maybe we want this to be 2 separate cases from here and just pull out common code
				//I am not sure yet but that may be a clearer and more efficient option
				if row.op_row_type == OpRowType.COPY_MUSIC_ROW {
					//TODO Could also allow a specific sections to be copied between a given x_start and x_end
					row_check_id = row.copy_music_row_id;
					current_section_to_row = perm.all_data.all_mspace_data[0].all_section_to_row;
				} 
				for section : current_section_to_row if row_check_id == section.row_id {
					//TODO I think this can be efficiently fetched by id since it should remain the same for default tuning_systems.
					tuning_system, found_tuning_system :=
						ArrayFindFirstByNameId(perm.all_data.all_tuning_systems,
							section.tuning_system_id, "id");
					assert(found_tuning_system);

					//NOTE : We use this whenever we need to adjust a size to the octave. This adjusts size both to the row's
					//given octave_height AND also to the compass interval of the particular interval. So something
					//with compass_interval > 2.0 (like bohlen-pierce) should be large and something < 2.0 (like wendy carlos)
					//should be smaller (each space and music point should be proportional)
					//TODO Can store this in tuning_system so we don't have to recompute OR
					//we could store everything as cents and do all this with cents so we don't have to deal with ratios here.
					octave_mult : float = row.octave_height * LogRatioToLinear(tuning_system.compass_interval, 2.0);

					/*TODO I think it makes sense to split up equal linear and ratio cases into separate loops.
					The equal would not need SpacePoint only color (which we would likely want to change to differentiate)
					between tuning systems with the same size but different sounds. We could then make optimizations for equal
					since we don't have to store anything besides color potentially and then only store for ratio proportional.
					Right now we store both in dspace_pos but think of the optimizations for something like a cent scale
					or something with 100 values but equal. Would not need any storage but how would the colors work?
					*/
					//NOTE : We use these SpacePoints for position and color now. So if we want to switch to having
					//separate rendering cases for RATIO and EQUAL, remember we still need color for EQUAL stored somewhere.
					//WE COULD JUST USE TUNING_PITCH DIRECTLY
					//NOTE : We use the same SpacePoints here as with music_rows since they are the same.
					//That is associated to different sections though unless this is a copy in which case
					//we reuse the sections as well.
					section_points : [] SpacePoint = ArrayFindAllVarName(perm.all_data.all_space_points, 
						section.dspace_id, "dspace_id", temp);

					//row_cam is at the base so we draw from that octave to row/octave ratio above.
					//TODO This is not efficient for non-octave-repeating scales. However it does work.
					//Would need to do it based on point position but then we have to loop through it since we could have ratio proportional points.
					//TODO This would be a case for splitting up ratio proportional and not but maybe this is fine.
					//If it's non-octave repeating we could just print 1 octave or cap at max_octave anyways
					//TODO Should store allowed octaves in row data as well.
					current_octave : int = cast(int) (row.row_cam.y / octave_mult);
					octaves_in_row : int = round_to_int(ceil(row.row_height / octave_mult));
					if octaves_in_row < 1 octaves_in_row = 1;
					// start_octave : int = current_octave - octaves_in_row;
					// if start_octave < 0 start_octave = 0;
					end_octave : int = current_octave + octaves_in_row;
					for octave : current_octave..end_octave for point : section_points {
						/*This relative positioning is better overall. Eventually, once we have 64 bit world, we can compute everything
						with 32-bit relative position and 64-bit row_world_base_start until we get to camera. Then convert to 32-bit
						after computing the camera and then storing into the renderer.
						*/
						/*NOTE : We store the row-relative position in dspace_pos.x and the relative base size of each point 
						in dspace_pos.y. This allows the same system for both linear and proportional points where everything is
						stored and computed only once per system and also can be octave_height adjusted at runtime here without
						any recomputation of the points.

						TODO IMPORTANT
						TODO Right now we are using dspace_pos directly BUT we could just compute here without SpacePoint for
						equal sized linear space since we only need octave_height point count for equal sized linear space.
						This would make it easier to change between tuning systems to make them look linear or ratio
						without having to do anything extra.
						SO THEN we would make 2 loops one for equal size and one for proportional and only fetch the points
						for proportional size otherwise we just compute directly.
						*/
						//TODO Creating the poitns here is copied from world so maybe we can pul it out of function.
						//I just x_point_width can be different so maybe we will have more differences alter and not worth it then.
						world_rect : Rectangle2 = RectMinCenterDim(Vector2F.{0, point.dspace_pos.x * octave_mult}, 
							//TODO Could allow changing the x in op_space but not in world_space eventually. So we could set that
							//in the row or possibly as a multiple here for consistency.
							Vector2F.{row.x_point_width, point.dspace_pos.y * octave_mult});
						// world_rect : Rectangle2 = point.rect_mesh;
						//TODO We could offset this from the lane here and either accumulate the row or set the row
						//to a lane relative position and the lane to be a world position... let's see how we use it eventually.
						//LANE OFFSET here instead of row might be better for lane dropdowns to collapse lanes down to 1 row.
						rect_diff : Vector2F = row.row_world_base_start;
						rect_diff.x += section.start_x * row.x_point_width;
						rect_diff.y += octave * octave_mult;
						rect_diff -= row.row_cam;
						MoveRect(rect_diff, *world_rect);
						cam_rect : Rectangle2 = OpRectToCamRect(world_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
						//TODO Might be best to do this on the world_rect
						cam_rect.max.x += (section.end_x - section.start_x - 1) * row.x_point_width;
						PushRectangle(cam_rect, point.color, op_space.render_groups.scissor_group, order = op_linear_order+1);
						PushRectangleOutline(cam_rect, GREY_BLACKER_V, op_space.render_groups.scissor_group, r = 1.0, order = op_linear_order+2);
					}

					/*TODO THIS IS THE GENERAL CASE AND IS NOT EFFICIENT
					We could have 2 cases which are implemented more efficiently.
					Case 1) 
						copying an entire row or a range which could technically be a separate case altogether.
					Case 2) 
						IF we only have 1 section in the row, then we don't need any of the section portion
					
					IN GENERAL we want to consider how this will be used. So maybe we only allow the above 2 cases.
					Currently the benefit of op_linear_rows is to take some points and put them on a separate linear
					system and then be able to quickly see and hear. Also to be able to compare rows that are very far apart.
					Is there any other reason why? If this is the case, then we can have 2 op rows which optimize these
					cases specifically and allow them to be chosen from the asm and/or based on specifically chosen settings.
					This forces the player to have to have to manage the linear systems but I think that might make more sense
					from the op_linear perspective. So we could leave the general slow case and then have those 2 cases
					be the mostly used cases and reuse whatever code we need.

					We could then pull out the music_pt drawing and just have the filtering be separate for the different
					cases for example. Can do the same with the space_point rendering above if that helps too.
					ALSO NEED to consider how we will optimize the data in the long term as well.

					TODO If we allow a range here then we might have to pull this out since we could change
					sections across a range.

					WE COULD ALSO STORE the music_pts separately in some cases and then we just have to recompute
					them whenever we do an update, like in debugging or after some code runs.
					*/
					/*TODO I am reusing this here but we could put it back if we need to update. For example,
					if we deicde to use TuningPitch instead of SpacePoint and store the color somewhere or just
					have default colors we grab here for each point, then we should update this.
					I am leaving the copy separate for music rows for now.
					I guess we'll see how it goes. We can put it back here if this causes any issues.
					Would need to pass in x_point_width if we wanted to generalize for music rows.

					TODO We can pull this function out if we generate music_pts for op linear beforehand.
					*/
					MusicPtSectionRect :: inline (
						music_pt : MusicPoint,
						octave_mult : float,
						x_offset : float,
						//TODO Pass in row_size here so we can cut off music_pts if they're too long
						row : MusicLaneRow,
						section_points : [] SpacePoint) 
					-> Rectangle2 
					{
						music_pt_int := cast(int) music_pt.music_pt_float;
						octave, point_index := ComputeQuotientAndRemainder2(music_pt_int, section_points.count);

						//TODO This is overkill for equal so maybe best to split it up.
						//TODO Don't need this for equal either so maybe we should split this with equal and proportional.
						point : SpacePoint = section_points[point_index];
						next_point : SpacePoint = section_points[(point_index+1) % section_points.count];
						next_rect_y_dim : float = next_point.dspace_pos.y * octave_mult;

						//TODO Could make this the diff between this point and the next point instead
						remainder := cast(float) (music_pt.music_pt_float - music_pt_int);

						//TODO Add the remainder here based on the distance to the next point? I think no matter what this
						//will be awkward in some cases with ratio proportional points.
						rect_dim := Vector2F.{row.x_point_width, point.dspace_pos.y * octave_mult};
						point_rect : Rectangle2 = RectMinCenterDim(
							Vector2F.{0,point.dspace_pos.x * octave_mult + remainder * 0.5 * (next_rect_y_dim + rect_dim.y)}, 
								rect_dim);
						world_rect : Rectangle2 = point_rect;
						//We are replacing the x diff with some shading
						// world_rect.min += 0.1 * rect_dim;
						// world_rect.max -= 0.1 * rect_dim;
						world_rect.min.y += 0.2 * rect_dim.y;
						world_rect.max.y -= 0.2 * rect_dim.y;

						music_pt_end : float64 = music_pt.x_end_float;
						if music_pt.x_end_float >= cast(float64) row.row_size {
							music_pt_end = cast(float64) row.row_size;
						}
						//TODO World is float32 right now so this works. When world is float64, we want to only cast to 32 after converting to camera rect.
						world_rect.max.x += cast(float) (music_pt_end - music_pt.x_start_float - 1.0) * row.x_point_width;

						rect_diff : Vector2F = row.row_world_base_start;
						rect_diff.x += x_offset * row.x_point_width;
						// rect_diff.x += cast(float) music_pt.x_start_float * row.x_point_width;
						// rect_diff.x += cast(float) mem_to_dspace.x_grid_pos * row.x_point_width;
						rect_diff.y += octave * octave_mult;
						rect_diff -= row.row_cam;
						MoveRect(rect_diff, *world_rect);

						return world_rect;
					}
					if row.op_row_type == OpRowType.COPY_MUSIC_ROW {
						//TODO Could grab the sections and do this afterwards in 1 shot. Also in music rows.
						for music_pt : perm.all_data.all_mspace_data[0].all_music_pts {
							//TODO This can be more efficient once we sort by row_index and x_start
							if music_pt.row_index == row.total_row_index && 
								MusicPtStartInRange(section.start_x, music_pt, section.end_x)
							{
								//TODO Can bring MusicPtSectionRect code back in here if needed later if it's different or something.
								world_rect := MusicPtSectionRect(music_pt, octave_mult, cast(float) music_pt.x_start_float, row, section_points);
								cam_rect : Rectangle2 = OpRectToCamRect(world_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
								//TODO The order here can be > 0 actually
								PushRectangle(cam_rect, FGREEN_V, op_space.render_groups.scissor_group, order = op_linear_order+7);
								PushRectangleOutline(cam_rect, GREY_BLACKER_V, op_space.render_groups.scissor_group, r = 1.0, order = op_linear_order+3);
							}
						}
					} else {
						//TODO This would be much more efficient if we just pre-computed the rect for op linear spaces
						//and then just drew them here without recomputing and getting music_pts on every frame like this.
						for mem_to_dspace : memory_to_row {
							if mem_to_dspace.x_grid_pos >= section.start_x && mem_to_dspace.x_grid_pos < section.end_x {
								//TODO We could have an option here that does this by range for efficiency.
								//TODO Should do this with for_expansion here to avoid creating more memory
								mem_music_pts := GetAllMusicPtPosByPosition(mem_to_dspace.row_index, mem_to_dspace.x_index,
									perm.all_data.all_mspace_data[0].all_music_pts, MusicPoint,,temp);
								for music_pt : mem_music_pts {
									//TODO Can bring MusicPtSectionRect code back in here if needed later if it's different or something.
									world_rect := MusicPtSectionRect(music_pt, octave_mult, cast(float) mem_to_dspace.x_grid_pos, row, section_points);
									cam_rect : Rectangle2 = OpRectToCamRect(world_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
									//TODO The order here can be > 0 actually
									PushRectangle(cam_rect, FGREEN_V, op_space.render_groups.scissor_group, order = op_linear_order+7);
									PushRectangleOutline(cam_rect, GREY_BLACKER_V, op_space.render_groups.scissor_group, r = 1.0, order = op_linear_order+3);
								}
							}
						}

						//TODO Could pull this out so we dont have to fetch everytime like above.
						//Can be optimized later when we optimize memory_range_to_dspace (can likely sort/index by row_index)
						for mem_range : perm.all_data.all_memory_range_to_dspace {
							if mem_range.op_dspace_type == OpDSpaceType.LINEAR && mem_range.dspace_id == row.id {
								/*TODO We can have all this be copied with a command and then it can be copied
								or not on map and then we can also allow commands between commands during debugging
								so then everything can update automatically if the user wants OR even to allow
								writing commands so they can run those during debug time.
								*/
								//TODO It might be best to copy these points so we don't have to do this every frame.
								//What about if we play the op_row, then we would have to do this again every time we play
								//them for example, that way we just go through music_pts but then we can even
								//compute this and then render it directly instead of recomputing this every frame.
								section_start_float : float64 = cast(float64) section.start_x;
								section_end_float : float64 = cast(float64) section.end_x;
								start_in_section : bool = InEpsilonRangeLeft(mem_range.x_start, section_start_float, section_end_float);
								end_in_section : bool = InEpsilonRangeRight(mem_range.x_end, section_start_float, section_end_float);
								mp_x_start : float64;
								mp_x_end : float64;
								if start_in_section && end_in_section {
									mp_x_start = mem_range.x_start;
									mp_x_end = mem_range.x_end;
								} else if start_in_section && !end_in_section {
									mp_x_start = mem_range.x_start;
									mp_x_end = section_end_float;
								} else if !start_in_section && end_in_section {
									mp_x_start = section_start_float;
									mp_x_end = mem_range.x_end;
								} else if !start_in_section && !end_in_section {
									//This range is not in this section, so we continue.
									continue;
								}

								music_pts_in_range := GetAllMemoryMusicPtsInRange(mp_x_start, mp_x_end,
									mem_range.row_index, perm.all_data.all_mspace_data[0].all_music_pts,,test_alloc);
								for music_pt : music_pts_in_range {
									//TODO Can bring MusicPtSectionRect code back in here if needed later if it's different or something.
									x_offset := cast(float) (mem_range.x_dspace_start + music_pt.x_start_float - mem_range.x_start);
									world_rect := MusicPtSectionRect(music_pt, octave_mult, x_offset, row, section_points);
									cam_rect : Rectangle2 = OpRectToCamRect(world_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
									//TODO The order here can be > 0 actually
									PushRectangle(cam_rect, FGREEN_V, op_space.render_groups.scissor_group, order = op_linear_order+7);
									PushRectangleOutline(cam_rect, GREY_BLACKER_V, op_space.render_groups.scissor_group, r = 1.0, order = op_linear_order+3);
								}
							}
						}
					}

					//TODO Technically we can pull this out and draw them all in one shot along the row since the x will always be the same
					world_rect : Rectangle2 = RectMinCenterDim(row.row_world_base_start, 
						Vector2F.{row.x_point_width, row.row_height});
					// world_rect.max.y = world_rect.min.y + row.row_height;
					// MoveRect(row.row_world_base_start, *world_rect);
					vert_rect : Rectangle2 = OpRectToCamRect(world_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					//TODO Can store bottom left point in MusicLaneRow instead or just grab from collider
					// vert_rect : Rectangle2 = WorldRectToCamRect(section_points[0].rect_mesh, default_base_cam);
					for section.start_x..section.end_x-1 {
						//TODO Could just accumulate the translation and not create a new rect each time.
						next_rect : Rectangle2 = vert_rect;
						MoveRect(Vector2F.{it * row.x_point_width,0}, *next_rect);
						PushRectangleOutline(next_rect, GREY_BLACKER_V, op_space.render_groups.scissor_group, r = 1.0, order = op_linear_order+2);
					}
				}	
				last_order : int = op_linear_order + order_increment - 1;
				PushSetScissor(op_space.render_groups.scissor_group.render_viewport, op_space.render_groups.scissor_group, order = last_order);
			} else if OpDSpaceType.PITCH_S2 == dspace_to_op_space.op_dspace_type {
				//TODO Should we just merge this with CHORD_S2 and reuse the vl eventually as well or will it be substantially different?
				pitch_s2, found_pitch_s2 := ArrayFindFirstByNameId(perm.all_data.all_pitch_space_2D,
					dspace_to_op_space.dspace_id, "dspace_id");
				assert(found_pitch_s2);

				for perm.all_data.all_space_points if it.dspace_id == pitch_s2.dspace_id {
					cam_rect : Rectangle2 = OpRectToCamRect(it.rect_mesh, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushRectangle(cam_rect, it.color, op_space.render_groups.scissor_group, order = 6);
				}
			} else if OpDSpaceType.SPIRAL == dspace_to_op_space.op_dspace_type {
				//TODO Could reuse this for a spiral that is circle_space but with octaves for each spiral.
				//We could then reuse the spiral drawing and just update the space and music point positioning code.
				sp, found_spiral := ArrayFindFirstByNameId(perm.all_data.all_spiral_spaces,
					dspace_to_op_space.dspace_id, "dspace_id");
				assert(found_spiral);

				//We use roots_of_unity here because it is much faster to not have to recompute sine for each point.
				//TODO Eventually we should store maybe 1200 roots_of_unity and then we just have to fetch and not recompute
				//Or just between 0-120 for the whole array.
				roots_of_unity := RootsOfUnity(sp.tuning_count, sp.is_clockwise, sp.rotate,, temp);

				first_world_pos : Vector2F = IndexToSpiralPos(0, sp.*, roots_of_unity);

				start_index : int = 1;
				end_index : int = sp.chord_count * sp.tuning_count - 1;
				if sp.is_loop {
					// last_world_pos : Vector2F = IndexToSpiralPos((sp.chord_count*sp.tuning_count), sp.*, roots_of_unity);
					last_world_pos : Vector2F = IndexToSpiralPos(end_index, sp.*, roots_of_unity);
					//TODO Could optionally draw this or dim it even more if it's too distracting
					PushQuadLineViewport(OpSpaceToCameraSpace(last_world_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam), 
						OpSpaceToCameraSpace(first_world_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam), 
						0.6*LBLUE_V*0.65, 0.05, op_space.render_groups.scissor_group, order = 6);
				} else {
					end_index += 1;
				}

				previous_point_cam_pos : Vector2F = OpSpaceToCameraSpace(first_world_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				for start_index..end_index {
					world_pos : Vector2F = IndexToSpiralPos(it, sp.*, roots_of_unity);
					cam_pos : Vector2F = OpSpaceToCameraSpace(world_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushQuadLineViewport(previous_point_cam_pos, cam_pos, GREY_DARKER_V*0.6, 0.05, op_space.render_groups.scissor_group, order = 5);
					previous_point_cam_pos = cam_pos;
				}

				#if 0 {
				//TODO Just don't call SetSpiralBase if we don't want these points and want to put other ones.
				//TODO Should convert this to SpaceRect and SpaceText now or something like that.
				for point, point_index : perm.all_data.all_space_points if point.dspace_id == sp.dspace_id {
					cam_rect := OpRectToCamRect(point.rect_mesh, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushRectangle(cam_rect, point.color, op_space.render_groups.scissor_group, order = 7); //order = point.int_pos.x if needed to be different
					if sp.show_values {
						//TODO We can grab the whole array from all_space_point_to_value if we need all of them.
						//TODO can limit this to 2-3 decimal points for visual clarity
						PushText(GetCenter(cam_rect), tprint("%",formatFloat(point.fun_region_float[0],trailing_width=2)), 
							WHITE_V, op_space.render_groups.scissor_group, 10003);
					}
				}

				//TODO We could have a runtime music_pt that updates based on if music_pts are changing here if needed.
				//It would be slower but maybe some people would find it useful and then it could be an option.
				//Also people could make these things themselves both with a generalized asm rendering api and with external code directly.
				//TODO Eventually we can pull this out and do all the points in 1 shot and no need for this double loop.
				for mem_pos : perm.all_data.all_memory_pos_to_dspace if sp.dspace_id == mem_pos.dspace_id {
					for op_point : perm.all_data.all_memory_op_space_points if mem_pos.id == op_point.mem_to_dspace_id {
						//TODO We could store the rect directly and then just update if we update the spiral.
						//Could also store generalized info for all spaces like point_dim although different spaces have different things.
						op_rect : Rectangle2 = RectCenterDim(op_point.world_pos, sp.point_dim);
						cam_rect : Rectangle2 = OpRectToCamRect(op_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
						PushRectangle(cam_rect, op_point.color, op_space.render_groups.scissor_group, order = 8);
						//TODO Can grab the values here as text if needed. We could store 1 value in the Point for efficiency maybe.
					}
				}

				for perm.all_data.all_spiral_vls if it.dspace_id == sp.dspace_id {
					// start_pos : Vector2F = FloatIndexToSpiralPos(it.start_spiral_index, sp.*);
					// end_pos : Vector2F = FloatIndexToSpiralPos(it.end_spiral_index, sp.*);
					start_cam : Vector2F = OpSpaceToCameraSpace(it.start_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					end_cam : Vector2F = OpSpaceToCameraSpace(it.end_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushQuadArrowViewport(start_cam, end_cam, LBLUE_V, 0.1, op_space.render_groups.scissor_group, order = 9);
				}
				}
			}
		}
	}
	else if OpSpaceExternalType.txt == op_space.op_space_external_type {
		text_op, found_text_op := 
			ArrayFindFirstByNameId(perm.all_data.all_text_op_space_data, op_space.id, "op_space_id");
		assert(found_text_op);
		assert(text_op.ftab_i < text_op.file_tabs.count);
		text_file, found_text_file :=
			ArrayFindFirstConstByNameId(perm.all_data.all_text_files, text_op.file_tabs[text_op.ftab_i].text_file_id, "id");
		assert(found_text_file);

		/*DOC : We could do this somewhere else but since we're going through all the op spaces here anyways.
		I guess if it closes, then the message will still be there when we open it, but we could just clear this
		when opening a text op space.
		*/
		if text_op.text_status_timer > 0 {
			text_op.text_status_timer -= game_input.last_frame_delta_time;
			if text_op.text_status_timer < 0 {
				text_op.text_status_message.count = 0;
			}
		}

		//TODO Put this in text_op_space_data with other constants for alignment.
		//Can minimize the amount of constants we need then.
		// op_rect_min : Vector2F = WorldSpaceToOpSpace(op_rect_world.min, op_space, op_space.op_2D_cam.world_pos);
		// op_rect_max : Vector2F = WorldSpaceToOpSpace(op_rect_world.max, op_space, op_space.op_2D_cam.world_pos);
		NEW_TEXT_OP_RECTS :: true;
		//NOTE : The base camera here should never change. Maybe we should store it in TextOpSpaceData instead.
		//We should be changing the other cameras instead.
		//So op_2D_cam.world_pos is always equal to Vector2F.{0,0} unless we move it eventually which we should not for text op space.
		#if NEW_TEXT_OP_RECTS {
		op_rect : Rectangle2 = text_op.ator.op_rect;
		} else {
		op_rect : Rectangle2 = RectCenterDim(Vector2F.{0,0}, op_space.world_size);
		}
		// op_rect : Rectangle2 = RectCenterDim(op_2D_cam.world_pos, op_space.world_size);
		//TODO Can remove these and just use op_rect.min/max
		// op_rect_min : Vector2F = op_rect.min;
		// op_rect_max : Vector2F = op_rect.max;

		//TODO SHOULD WE PULL THIS OUT AND ONLY DO IT WHEN WE CREATE OR UPDATE THE WINDOW?
		//Although this is camera based so maybe we want to leave it here and just base everything around op_rect_cam for consistency.
		//TODO This order should be based on the 10000 we set for PushTextAndCursorShaderOrder
		//Can make this global constants I think since we reuse everywhere. OR We can pass them into here and set them in here
		//since we set them on every frame anyways. Can start a bit higher to avoid those for now and then
		//have everything contained in here startin from left_order which we can store or just keep constant...
		left_order : int = 9999;
		PushSetShaderColor(op_space.render_groups.scissor_group, left_order);
		left_text_order : int = left_order+41;
		PushSetShaderText(op_space.render_groups.scissor_group, left_text_order);
		left_proportion : float = text_op.left_proportion;
		// left_rect : Rectangle2 = op_rect_cam;
		// left_rect.max.x = (1.0-left_proportion)*op_space.world_size.x;
		#if NEW_TEXT_OP_RECTS {
		left_rect : Rectangle2 = text_op.ator.left_rect;
		} else {
		left_rect : Rectangle2 = op_rect;
		left_rect.max.x = op_rect.min.x + left_proportion*op_space.world_size.x;
		}
		cam_left_rect := OpRectToCamRect(left_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
		left_pixel_rect := CamRectToPixelRect(cam_left_rect, op_space.render_groups.scissor_group);
		PushSetScissor(left_pixel_rect, op_space.render_groups.scissor_group, left_order);
		//tODO Why dont we have color ahd text for left rect text? It seems to be working though hmmm...

		//TODO Putting everything here so shaders stay consistent and i can see all the text left pane orders in 1 place
		//TODO I think we can try just setting the color and text in the renderer directly so we don't have
		//to think about it here and have potential issues later
		left_margin_order : int = left_order+101;
		PushSetShaderColor(op_space.render_groups.scissor_group, left_margin_order-1);
		left_bottom_bar_order : int = left_margin_order+40;
		left_bottom_bar_text_order : int = left_bottom_bar_order+20;
		PushSetShaderColor(op_space.render_groups.scissor_group, left_bottom_bar_order-1);
		PushSetShaderText(op_space.render_groups.scissor_group, left_bottom_bar_text_order-1);
		left_top_bar_order : int = left_bottom_bar_order+40;
		left_top_bar_text_order : int = left_top_bar_order+20;
		PushSetShaderColor(op_space.render_groups.scissor_group, left_top_bar_order-1);
		PushSetShaderText(op_space.render_groups.scissor_group, left_top_bar_text_order-1);

		//TODO Convert char_bounds from the x size here. TODO Should we doing this when we update the window.
		// left_rect_dim : Vector2F = GetDim(left_rect);
		// text_op.file_tabs[text_op.ftab_i].tab_cursor.right_char_bound = cast(int)(left_rect_dim.x / perm.text_editor_data.code_font_1_char_width_world);

		//NOTE : This gives use cursor width of 0.1 for char_width of 0.66666 AND
		//it will scale proportionally if we increase the size of the font which is better than zoom_factor for text_editor i think.

		#if NEW_TEXT_OP_RECTS {
		//Replace this with top
		// text_op_positions : TextOpPositions = ComputeTextOpPositions(text_op.ator, op_space, text_op, perm.text_editor_data);
		// text_op_positions : TextOpPositions = text_op.ator.top;
		TEXT_LINE_HEIGHT : float = text_op.ator.TEXT_LINE_HEIGHT;
		//TODO I think these will always be the same but may change relative to font and stuff like that.
		//Would need to test with different fonts and different window sizes.
		// LOC_START_Y : float = 14.5 - text_op.top_margin_height;
		LOC_START_Y : float = text_op.ator.LOC_START_Y;
		// LOC_START_X : float = -19 + text_op.left_margin_char_width * perm.text_editor_data.code_font_1_char_width_world;
		MARGIN_END : float = text_op.ator.MARGIN_END;
		//TODO This should be stored in TextOpSpaceData or something like that. Maybe not so we don't have readjust on size changes.
		// DEBUG_START_X : float = -19;
		DEBUG_START_X : float = text_op.ator.DEBUG_START_X;
		//We adjust start_y for debugging so it is in line with the cursor and chars.
		cursor_height : float = text_op.ator.cursor_height;
		y_cursor_adjust : float = YAdjustCursorHeight(text_op.ator.cursor_height);
		DEBUG_START_Y : float = text_op.ator.DEBUG_START_Y;
		CURSOR_WIDTH : float = text_op.ator.CURSOR_WIDTH;
		X_GAP : float = text_op.ator.X_GAP;
		LOC_START_X : float = text_op.ator.LOC_START_X;
		} else {
		//TODO Make this a function so we can reuse.
		//TODO Likely will pull these all out as functions OR store them and then recompute on resize later for efficiency.
		// TEXT_LINE_HEIGHT : float = text_op.text_line_height_factor*perm.text_editor_data.char_height / op_space.render_groups.scissor_group.pixels_per_square;
		TEXT_LINE_HEIGHT : float = ComputeTextLineHeight(text_op.text_line_height_factor,
			perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);
		//TODO I think these will always be the same but may change relative to font and stuff like that.
		//Would need to test with different fonts and different window sizes.
		// LOC_START_Y : float = 14.5 - text_op.top_margin_height;
		LOC_START_Y : float = op_rect.max.y - 0.5*TEXT_LINE_HEIGHT - text_op.top_margin_height;
		// LOC_START_X : float = -19 + text_op.left_margin_char_width * perm.text_editor_data.code_font_1_char_width_world;
		MARGIN_END : float = op_rect.min.x + text_op.left_margin_char_width * perm.text_editor_data.code_font_1_char_width_world;
		//TODO This should be stored in TextOpSpaceData or something like that. Maybe not so we don't have readjust on size changes.
		// DEBUG_START_X : float = -19;
		DEBUG_START_X : float = op_rect.min.x + 0.5*(MARGIN_END-op_rect.min.x);

		//We adjust start_y for debugging so it is in line with the cursor and chars.
		cursor_height : float = ComputeCursorHeight(perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);
		y_cursor_adjust : float = YAdjustCursorHeight(cursor_height);
		DEBUG_START_Y : float = LOC_START_Y - y_cursor_adjust;

		CURSOR_WIDTH : float = 0.15*perm.text_editor_data.code_font_1_char_width_world;
		X_GAP : float = 2.3 * CURSOR_WIDTH * perm.text_editor_data.code_font_1_char_width_world;
		LOC_START_X : float = MARGIN_END + X_GAP;
		//TODO Can put this in between
		// LINE_NUMBER_START_X : float = 0;
		}

		//TODO We could test out 1 font cahnge by updating this on a button press and then resetting
		//all_my_fonts[1] and then calling SetupTextEditorData just so we can see if a font size change 
		//works properly with everythign else. Need to implement proper font changes later though.
		//Can test with a hotkey in watch/text window for now.
 		#if 0 {
		font_1 : *Dynamic_Font = Simp.get_font_at_size(RESOURCES_DIR_NAME, "JetBrainsMono-Light.ttf", font_height);
		array_add(*renderer_data.all_my_fonts, font_1);
		one_char_width : s64 = Simp.prepare_text(font_1, "1");
		array_add(*renderer_data.all_my_fonts_data, MakeFontData(font_1.character_height, one_char_width));
		}

		//TODO FROM HERE put this into PushTypeCursor so the selected fixed cursor also adjusts to tabs
		//and then also set the rendering so we can see where it's highlighted from in there once we pass in the cursor
		//Then also adjust text op proprtions and then compute the split rects single from there so we don't have
		//extra rendering on the rectangles
		//ALSO I think leaving the cursor showing in the text editor all the time is fine

		//TODO We can just print the lines that are visible now actually since we already have the indices.
		//Can add a few lines on top and bottom for camera overlap just in case.
		//Could probably even remove camera here and for cursor and debug points if that works.
		//Then we would have not have any float issues although float should work till > 100000 loc which
		//is likely going to be a cap for our text editor anyways.
		// for loc, line_number : text_file.file_loc {
		//TODO I think with this method we could even remove the camera altogether and maybe just add
		//a few lines above and below in case we can see some in between...
		//WE COULD EVEN DO tab_to_space and some syntax highlighting here now if needed since its just
		//the visible lines that can be done efficiently per line probably.
		/*Could use this string library eventually to do efficient string searching/replace_all and syntax highlighting
		searching with SIMD per line. Would that work on mac though?
		Syntax highlighting for comments would be very useful I think. Maybe also some keywords but I think that's it
		https://github.com/onelivesleft/jai-string/tree/main

		FOR TABS : We could just replace all tabs with spaces here. It would be more efficient with the external
		string library I think for SIMD, and that might also work on mac. Worth testing out.

		FOR COMMENTS : We could have a second loop that searches for "/" and then "/" or "*" and then add those
		lines with a different color on top so we don't have to update anything in this loop.
		OR maybe it would be fine in this loop since we dont have that any lines. Can check if it starts with "/"
		and if it's later then we just split the line. OR just split each loop and do that.
		*/

		//TODO Reuse this as a funtion since we use it in both places
		#if NEW_TEXT_OP_RECTS {
		left_margin_rect : Rectangle2 = text_op.ator.left_margin_rect;
		l_top_rect : Rectangle2 = text_op.ator.l_top_rect;
		} else {
		left_margin_rect : Rectangle2 = op_rect;
		left_margin_rect.max.x = left_margin_rect.min.x + 
			(text_op.left_margin_char_width) * perm.text_editor_data.code_font_1_char_width_world;
		//TODO We could make this start only from left_margin but it seems ok to move the cursor when we press breakpoint
		l_top_rect : Rectangle2 = op_rect;
		l_top_rect.max.x = op_rect.min.x + text_op.left_proportion*op_space.world_size.x;
		l_top_rect.min.y = op_rect.min.y + text_op.bottom_proportion*op_space.world_size.y;
		}

		//TODO FROM HERE do watch pane and scrolling and tabs and other panes
		op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);

		//TODO Make some common functionality that allows us to place both the text and cursor in the same place.
		//TODO We could compute cam rect here and then check mouse cam
		//TODO Bring this down above highlighting and only do the fixed_select data if we are highlighting
		tab_cursor : *TextCursor = *text_op.file_tabs[text_op.ftab_i].tab_cursor;
		current_tab_cam_pos := Vector2F.{tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world, 0};

		/*DOC : To add keywords, we can do what we did for text console and just search for the word on each line and then
		draw black text and color text over it just for the lines we are currently rendering. I think this would be very fast
		once we are using the onelivesleft string library.
		Can also do something similar for comments. Just do it after and just for the lines being rendered
		and then just need to split it proerly depend on if we have comments with / or *
		*/
		//TODO Could even do this with an array view and also maybe add 1-2 lines before and after with a clamp
		//We add the extra line but does that look better? I think it shows that theres a next line which
		//is a nice visual cue that there is more text after the current bounds.
		//We don't need a start_render_line because we are always start from the same top position.
		start_render_line : int = text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index;
		end_render_line : int = min(text_file.file_loc.count-1, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index+1);
		//NOTE : Leaving this here in case we don't want the extra line if it looks weird
		// end_render_line : int = min(text_file.file_loc.count-1, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);
		for line_number : start_render_line..end_render_line {
		// for line_number : text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index..text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index {
			loc : string = text_file.file_loc[line_number];
			loc_tab_split : [] string = String.split(loc, cast(u8) #char "\t",,temp);
			line_char_with_tab : int = 0;
			for loc_section : loc_tab_split {
				//TODO This LOC_START_X should be store in the op_space/text_file info. 
				//TextOpSpaceData and could also store debug info in there or maybe extra one so we separate that as well?
				//Or all text spaces are debugger but we can switch the ui on and off for convenience.
				// start_tabs_length : float = tab_start_count * TAB_CHAR_COUNT * perm.text_editor_data.code_font_1_char_width_world;
				line_x_diff_with_tab : float = line_char_with_tab * perm.text_editor_data.code_font_1_char_width_world;
				op_pos : Vector2F = MakeV2F(LOC_START_X + line_x_diff_with_tab, LOC_START_Y - (TEXT_LINE_HEIGHT*(line_number-start_render_line)));
				// cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, current_tab_cam_pos, default_base_cam);
				PushText(cam_pos, loc_section, GREY_DARK_V, op_space.render_groups.scissor_group, left_text_order);

				//We found a tab so we add 1 tab char count and the loc section string count
				line_char_with_tab += loc_section.count + TAB_CHAR_COUNT;
			}
		}

		// op_pos : Vector2F = MakeV2F(LOC_START_X, LOC_START_Y - (TEXT_LINE_HEIGHT*t_tab.tab_cursor.cursor_line_number));
		//TODO This camera can only be used for left and right so then we can keep text space as 32-bit float
		// cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
		// cursor_rect : Rectangle2;
		if is_chosen_op_space && text_op.selected_pane == SelectedTextPane.TEXT {
			// PushTypeCursor(cursor_cam_pos, tab_cursor.cursor_line_char * perm.text_editor_data.code_font_1_char_width_world, perm.text_editor_data.char_height,
			//TODO Should text cursor here should be underneath the text so we can always see the text?
			//its over the text in sublime but under the text in notepad
			cursor_op_pos : Vector2F = MakeV2F(LOC_START_X, LOC_START_Y - (TEXT_LINE_HEIGHT*(tab_cursor.cursor_line_number-tab_cursor.start_file_line_index)));
			cursor_cam_pos : Vector2F = OpSpaceToCameraSpace(cursor_op_pos, op_space, current_tab_cam_pos, default_base_cam);
			//TODO This fails with invalid line number BUT we can clamp it in here if we want to draw the cursor
			//when the op_space is unselected. I Will leave it failing for now since this catches some bugs sometimes with invalid line numbers.
			char_count_until_cursor_with_tab : int = CharCountUntilCursorWithTab(tab_cursor.cursor_line_char, 
				tab_cursor.cursor_line_number, text_file.file_string);
			cursor_line_op_x_diff : float = char_count_until_cursor_with_tab * perm.text_editor_data.code_font_1_char_width_world;
			//TODO Use this to push cursor and remove PushTypeCursor if we don't use it anymore
			// cursor_rect = TypeCursorRect(cursor_cam_pos, cursor_line_op_x_diff, perm.text_editor_data.char_height, 
			// 	op_space.render_groups.scissor_group.pixels_per_square, cursor_width=CURSOR_WIDTH);
			PushTypeCursor(cursor_cam_pos, cursor_line_op_x_diff, perm.text_editor_data.char_height,
				op_space.render_groups.scissor_group, order=left_order+10, color=ORANGE_V, cursor_width=CURSOR_WIDTH);
				// line_height_factor=TEXT_LINE_HEIGHT);
				// op_space.render_groups.scissor_group, order=left_margin_order+10, color=ORANGE_V);
			//TODO I think we can remove this once we have highlighting working and then move the fixed select pos down there
			//since we only need it for the highlighting rects
			#if 0 {
			//TODO SETTING we could allow this instead of the highlighting below OR also both if needed
			if tab_cursor.cursor_is_selecting {
				//TODO Could pull this out since we reuse it for both cursors
				fixed_select_op_pos : Vector2F = MakeV2F(LOC_START_X, LOC_START_Y - (TEXT_LINE_HEIGHT*(tab_cursor.fixed_select_line_number-tab_cursor.start_file_line_index)));
				fixed_select_cam_pos : Vector2F = OpSpaceToCameraSpace(fixed_select_op_pos, op_space, current_tab_cam_pos, default_base_cam);
				char_count_until_fixed_select_with_tab : int = CharCountUntilCursorWithTab(tab_cursor.fixed_select_line_char, 
					tab_cursor.fixed_select_line_number, text_file.file_string);
				fixed_select_line_op_x_diff : float = char_count_until_fixed_select_with_tab * perm.text_editor_data.code_font_1_char_width_world;
				PushTypeCursor(fixed_select_cam_pos, fixed_select_line_op_x_diff, perm.text_editor_data.char_height,
					op_space.render_groups.scissor_group, order=left_order+10, color=FGREEN_V, cursor_width=CURSOR_WIDTH);
					// line_height_factor=TEXT_LINE_HEIGHT);		
			}
			}
		}

		//TODO We could also only show this if op space is chosen and we are in text pane like above BUT
		//this allows us to highlight something and see it even if we are off which is maybe a nice thing to have
		//for demonstration and educational purposes for example.
		if tab_cursor.cursor_is_selecting {
			start_select_line : int;
			start_line_char : int;
			end_select_line : int;
			end_line_char : int;
			if tab_cursor.char_point > tab_cursor.fixed_select_char_point {
				start_select_line = tab_cursor.fixed_select_line_number;
				start_line_char = tab_cursor.fixed_select_line_char;
				end_select_line = tab_cursor.cursor_line_number;
				end_line_char = tab_cursor.cursor_line_char;
			} else if tab_cursor.char_point < tab_cursor.fixed_select_char_point {
				start_select_line = tab_cursor.cursor_line_number;
				start_line_char = tab_cursor.cursor_line_char;
				end_select_line = tab_cursor.fixed_select_line_number;
				end_line_char = tab_cursor.fixed_select_line_char;
			} else {
				//TODO Could assert false here sanity check but it should be checked elsewhere anyways...
				// assert(false, "char_point == fixed_select_char_point for cursor %", tab_cursor.*);
			}

			/*DOC : Because we may not have updated the lines and selection here, in order to continue rendering
			the highlighting even if we are not choosing the op_space we need keep it lower than the max file_loc.
			This is because we only update the cursor on choosing and changing tab, so this should avoid file_loc access
			issues in case we did update somewhere else.
			THIS MAY PREVENT US FROM SEEING BUGS THOUGH. I guess let's see how it goes overall.
			*/
			start_select_line = min(start_select_line, text_file.file_string.file_loc.count-1);
			end_select_line = min(end_select_line, text_file.file_string.file_loc.count-1);
			//TODO can replace these with ator since we have them in ator already
			// cursor_height : float = ComputeCursorHeight(perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);
			// y_adjust : float = YAdjustCursorHeight(cursor_height);
			if InRange(start_render_line, start_select_line, end_render_line) || 
				InRange(start_render_line, end_select_line, end_render_line) 
			{
				start_render_select_line : int = max(start_select_line, start_render_line);
				end_render_select_line : int = min(end_select_line, end_render_line);
				for select_line : start_render_select_line..end_render_select_line {
					loc : string = text_file.file_loc[select_line];
					start_render_line_char : int;
					end_render_line_char : int;
					if start_select_line == end_select_line {
						start_render_line_char = start_line_char;
						end_render_line_char = end_line_char;
					} else if select_line == start_select_line {
						start_render_line_char = start_line_char;
						end_render_line_char = loc.count;
					} else if select_line == end_select_line {
						start_render_line_char = 0;
						end_render_line_char = end_line_char;
					} else {
						start_render_line_char = 0;
						end_render_line_char = loc.count;
					}
					//Add this here to connect empty lines. I think this also makes everything that is highlighted clearer
					//THIS ALSO removes the need for a second fixed select cursor
					highlight_empty_line : bool = HighlightEmptyLine(tab_cursor.*, select_line, loc.count);

					//TODO Should test this function with 0 like this to make sure it returns 0
					non_select_char_count : int = CharCountWithTabInString(loc, 0, start_render_line_char);
					char_count : int = CharCountWithTabInString(loc, start_render_line_char, end_render_line_char);;
					if highlight_empty_line char_count = 1;

					cursor_min_op_pos : Vector2F = MakeV2F(LOC_START_X, LOC_START_Y - (TEXT_LINE_HEIGHT*(select_line-start_render_line)));
					TextToMinCursorPos(*cursor_min_op_pos, text_op.ator.cursor_height);
					// cursor_min_op_pos.y -= y_adjust + 0.5*cursor_height;
					cursor_min_op_pos.x += non_select_char_count * perm.text_editor_data.code_font_1_char_width_world;
					cursor_min_cam_pos : Vector2F = OpSpaceToCameraSpace(cursor_min_op_pos, op_space, current_tab_cam_pos, default_base_cam);

					highlighted_rect : Rectangle2 = HighlightedLineRect(char_count, text_op.ator.cursor_height, cursor_min_cam_pos, 
						perm.text_editor_data.code_font_1_char_width_world);
					//TODO We could have a slightly darker blue if the op space is not chosen
					//TODO Do i prefer LMBLUE_V or DBLUE_V. 
					//LMBLUE_V and DBLUE_V are very similar but the alpha of LMBLUE_V feels a bit less harsh but changes with other colors
					//SO these will be user settable since background and font color will be settable as well
					//TODO SETTINGS text_file_highlighting_color
					PushRectangle(highlighted_rect, LMBLUE_V, op_space.render_groups.scissor_group, order=left_order+9);
					// PushRectangle(highlighted_rect, DBLUE_V, op_space.render_groups.scissor_group, order=left_order+9);
				}			
			}
		}

		//TODO FROM HERE start on the input for find and replace
		//TODO SETTINGS, could have an option to show name and line number in text op title bar
		if text_op.show_text_status_bar {
			cam_status_bar_rect := OpRectToCamRect(text_op.ator.status_bar_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			//TODO SETTINGS allow color of data bar and find and replace bar to be changed
			PushRectangle(cam_status_bar_rect, BLACK_V, op_space.render_groups.scissor_group, left_bottom_bar_order);
			start_status_bar_cam_pos := OpSpaceToCameraSpace(text_op.ator.status_bar_text_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			//TODO Can add char here is as well if needed
			//TODO Can also add info here like Saved "file_name" and other info if needed like copied or pasted or something else similar to sublime text
			//TODO SETTINGS could have a formatting for how people want to put their data and also have data options
			status_bar_text : string;
			if text_op.text_status_timer > 0 {
				status_bar_text = tprint("%, Line %; %", text_file.file_short_name, tab_cursor.cursor_line_number, text_op.text_status_message);
			} else {
				status_bar_text = tprint("%, Line %", text_file.file_short_name, tab_cursor.cursor_line_number);
				//TODO Should we make this toggleable or just goto asm for a line or when we are in debug mode?
				// status_bar_text = tprint("%, Line %, asm %", text_file.file_short_name, tab_cursor.cursor_line_number, text_op.highlighted_disasm_index);
			}
			PushText(start_status_bar_cam_pos, status_bar_text, GREY_DARK_V, op_space.render_groups.scissor_group, left_bottom_bar_text_order);
		}

		//TODO Change text status to be bottom bar order
		if text_op.text_top_bar_type == TextTopBarType.TEXT_FILE_TABS {
			cam_top_bar_rect := OpRectToCamRect(text_op.ator.top_bar_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushRectangle(cam_top_bar_rect, BLACK_V, op_space.render_groups.scissor_group, left_top_bar_order);
			// PushRectangleOutline(cam_top_bar_rect, LIGHT_BROWN, op_space.render_groups.scissor_group, order=left_top_bar_order);

			cam_add_tab_rect := OpRectToCamRect(text_op.ator.add_file_tab_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			add_tab_color : Vector4F = GREY_DARKERM_V;
		   if text_op.mouse_hovering_top_bar && IsInRectangle(mouse_cam, cam_add_tab_rect) {
		   	add_tab_color = LBLUE_V;
		   }
		   PushCross(GetCenter(cam_add_tab_rect), 0.6*GetWidth(cam_add_tab_rect), 0.4*GetHeight(cam_add_tab_rect),
		    	add_tab_color, op_space.render_groups.scissor_group, R=0.11, order = left_top_bar_order+2);

			//TODO I think we can compute this in UpdateTextOpRects and reuse for mouse and then
			//implement closing a tab and also moving tabs with mouse and shortcut
			//TODO Having it computed like this means we only have 1 array which I kind of like... I don't think this is
			//expensive enought that we NEED to store the rects but I guess we can later if needed.
			//We only compute it here and for input above
			file_tab_op_rects : [] Rectangle2 = CreateFileTabOpRects(text_op);
			close_tab_char_count : int = 2;
			tab_rect_height : float = GetHeight(cam_top_bar_rect);
			for tab, tab_index : text_op.file_tabs {
				//TODO Could convert these to cam here so we keep file tabs as op_mouse for consistency
				op_tab_rect : Rectangle2 = file_tab_op_rects[tab_index];
				cam_tab_rect : Rectangle2 = OpRectToCamRect(op_tab_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);

				text_color : Vector4F = GREY_DARK_V;
				if text_op.mouse_hovering_top_bar && text_op.mouse_hovering_tab_i == tab_index {
					//Keep the same white if in rectangle
				} else if text_op.ftab_i != tab_index {
					text_color = GREY_DARKERM_V;
				}

				//I THINK it feels better without the dividor and just leave the Xs there instead
				//I don't usually leave the tabs open anyways
				//TODO We could store these but then we have to recompute it everytime we add or close tabs...
				//Let's try this way for now and see if it's ok longer term since it's not a terribly expensive function for a few tabs open
				//TODO Can just push the right outline rect maybe only if tabs.count > 0
				// PushRectangleOutline(cam_tab_rect, LIGHT_BROWN, op_space.render_groups.scissor_group, order=left_top_bar_order+1);
				// dividor_tab_rect := RectRenderLeftOutline(cam_tab_rect, 2.0, op_space.render_groups.scissor_group.pixels_per_square);
				//TODO We could put this in between each tab or just next to on the left of the currently selected tab
				// PushRectangle(dividor_tab_rect, text_color, op_space.render_groups.scissor_group, left_top_bar_order+1);

				text_file, found_text_file := ArrayFindFirstConstByNameId(perm.all_data.all_text_files, tab.text_file_id, "id");
				assert(found_text_file);

				tab_width : float = GetWidth(cam_tab_rect);
				tab_char_count := cast(int) (tab_width / perm.text_editor_data.code_font_1_char_width_world);
				tab_char_count -= close_tab_char_count;//this makes space for the cross could put 2 chars as well if needed
				if tab_char_count >= 0 {
					tab_string : string = String.slice(text_file.file_short_name, 0, tab_char_count);
					text_pos : Vector2F = cam_tab_rect.min + text_op.ator.top_bar_text_offset;
					//TODO SETTINGS, could make this TEXT_OP_UI_COLOR
					PushText(text_pos, tab_string, text_color, op_space.render_groups.scissor_group, left_top_bar_text_order);
					// PushText(text_pos, "TEST NAME", LIGHT_BROWN, op_space.render_groups.scissor_group, left_top_bar_text_order);
				}

			   // if text_op.file_tabs.count > 0 && text_op.mouse_hovering_top_bar {
				close_tab_rect : Rectangle2 = GetFileTabXRect(cam_tab_rect, perm.text_editor_data.code_font_1_char_width_world);
				cross_color : Vector4F = text_color;
				is_hovering_x : bool = false;
				//TODO We could check this in the input above so we don't have anything overlapping but these seems simpler
				//for now, if we do have issues then we can add a boolean and check in the input for no overlapping inputs
				if IsInRectangle(mouse_cam, close_tab_rect) {
					is_hovering_x = true;
					cross_color = LBLUE_V;
				}
			   if text_op.file_tabs.count > 1 && 
			   	(!text_file.file_string.not_saved_text_edit || is_hovering_x)
		   	{
				   PushRenderX(close_tab_rect, cross_color, op_space.render_groups.scissor_group, left_top_bar_order+2);
				}
				else if text_file.file_string.not_saved_text_edit {
					c_center : Vector2F = GetCenter(close_tab_rect);
					c_radius : float = 0.4*GetWidth(close_tab_rect);
					PushCircle(c_center, c_radius, text_color, op_space.render_groups.scissor_group, res=16, order=left_top_bar_order+3);
					// PushRectangle(close_tab_rect, text_color, op_space.render_groups.scissor_group, left_top_bar_order+3);
				}
			}
		}

		TEXT_BAR_CURSOR_FACTOR :: 0.9;
		if text_op.text_first_bar_type != TextFirstBarType.NONE {
			//TODO REMOVE this just for texting
			// PushRectangleOutline(text_op.ator.l_top_rect, YELLOW_V, op_space.render_groups.post_render_group, order = left_order+20, r = 2.0);
			// PushRectangleOutline(text_op.ator.l_text_rect, YELLOW_V, op_space.render_groups.post_render_group, order = left_order+20, r = 2.0);
			// PushRectangleOutline(text_op.ator.first_bar_text_rect, YELLOW_V, op_space.render_groups.post_render_group, order = left_order+20, r = 2.0);
			// PushRectangleOutline(text_op.ator.first_bar_rect, YELLOW_V, op_space.render_groups.post_render_group, order = left_order+20, r = 2.0);

			cam_first_bar_rect := OpRectToCamRect(text_op.ator.first_bar_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushRectangle(cam_first_bar_rect, GREY_DARKEST_V, op_space.render_groups.scissor_group, left_bottom_bar_order);

			start_first_bar_cam_pos := OpSpaceToCameraSpace(text_op.ator.first_bar_text_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushText(start_first_bar_cam_pos, text_op.first_bar_name_text, LOW_WHITE_V, op_space.render_groups.scissor_group, left_bottom_bar_text_order);
			left_type_text_width_world := text_op.first_bar_name_text.count*perm.text_editor_data.code_font_1_char_width_world;
			text_cam_pos : Vector2F = OpSpaceToCameraSpace(text_op.ator.first_bar_input_text_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			first_text_with_bounds : string = SingleLineTextInBounds(text_op.first_bar_input_text.text_string, text_op.first_bar_cursor);
			PushText(text_cam_pos, first_text_with_bounds, LOW_WHITE_V, op_space.render_groups.scissor_group, left_bottom_bar_text_order);

			cam_first_bar_text_rect := OpRectToCamRect(text_op.ator.first_bar_text_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushRectangle(cam_first_bar_text_rect, BLACK_V, op_space.render_groups.scissor_group, left_bottom_bar_order+1);
			//TODO FROM HERE can use this for watch rect and then continue on go to line and find and replace functionality
			//TODO SETTINGS have some of these be adjustable through the settings file
			bar_cursor_settings : SingleCursorSettings;
			bar_cursor_settings.input_cursor_width = CURSOR_WIDTH;
			bar_cursor_settings.cursor_color = ORANGE_V;
			//TODO We could remove the cursor and highlighting here if needed by just putting this condition as an if
			bar_cursor_settings.draw_cursor = text_op.selected_text_bar == SelectedTextBarType.SELECTED_FIRST_BAR;
			DrawSingleLineCursor(text_op.first_bar_cursor, text_cam_pos, cam_first_bar_text_rect.min.x,
				left_bottom_bar_order+2, op_space.render_groups.scissor_group, perm.text_editor_data, bar_cursor_settings);

			//DOC : replace bar can only show if we are showing the find bar
			if text_op.text_second_bar_type != TextSecondBarType.NONE {
				cam_second_bar_rect := OpRectToCamRect(text_op.ator.second_bar_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				PushRectangle(cam_second_bar_rect, GREY_DARKEST_V, op_space.render_groups.scissor_group, left_bottom_bar_order);

				start_second_bar_cam_pos := OpSpaceToCameraSpace(text_op.ator.second_bar_text_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				PushText(start_second_bar_cam_pos, text_op.second_bar_name_text, LOW_WHITE_V, op_space.render_groups.scissor_group, left_bottom_bar_text_order);
				left_second_text_width_world := text_op.second_bar_name_text.count*perm.text_editor_data.code_font_1_char_width_world;
				second_text_cam_pos : Vector2F = OpSpaceToCameraSpace(text_op.ator.second_bar_input_text_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				second_text_with_bounds : string = SingleLineTextInBounds(text_op.second_bar_input_text.text_string, text_op.second_bar_cursor);
				PushText(second_text_cam_pos, second_text_with_bounds, LOW_WHITE_V, op_space.render_groups.scissor_group, left_bottom_bar_text_order);

				cam_second_bar_text_rect := OpRectToCamRect(text_op.ator.second_bar_text_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				PushRectangle(cam_second_bar_text_rect, BLACK_V, op_space.render_groups.scissor_group, left_bottom_bar_order+1);
				//TODO We could remove the cursor and highlighting here if needed by just putting this condition as an if
				bar_cursor_settings.draw_cursor = text_op.selected_text_bar == SelectedTextBarType.SELECTED_SECOND_BAR;
				DrawSingleLineCursor(text_op.second_bar_cursor, second_text_cam_pos, cam_second_bar_text_rect.min.x,
					left_bottom_bar_order+2, op_space.render_groups.scissor_group, perm.text_editor_data, bar_cursor_settings);
			}
		}


		final_reset_scissor_order : int = 50000;
		PushSetScissor(op_space.render_groups.scissor_group.render_viewport, op_space.render_groups.scissor_group, final_reset_scissor_order);
		PushSetShaderColor(op_space.render_groups.scissor_group, final_reset_scissor_order+1);

		//TODO Need to have this in a table that is separate for each op_space.
		//Can do this based on a ui flag in TextOpSpaceData instead.
		//TODO This should also be based on which quadrant this pane is on and not be fixed eventually.
		if text_op.exec_info.exec_mode == ExecutionMode.DEBUG {
			//TODO IF we want to allow line number then we would adjust margin_char_width.
			//Can pull this out if want to allow left margin on text window as well.
			left_margin_rect : Rectangle2 = op_rect;
			left_margin_rect.max.x = left_margin_rect.min.x + 
				(text_op.left_margin_char_width) * perm.text_editor_data.code_font_1_char_width_world;
			cam_left_margin_rect := OpRectToCamRect(left_margin_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushRectangle(cam_left_margin_rect, GREY_DARKEST2_V, op_space.render_groups.scissor_group, left_margin_order);
			//TODO Need to push shaders for color and text here if we want line_numbers

			//TODO If we add line_numbers, then we would just have to add the total amount of max number chars
			//in the line number and put some spaces when rendering the string based on the difference between
			//that integer and the max integer. I don't use line numbers much though so I can do that later
			//and maybe just put file name and line number on the top or bottom of the editor. (PREFERABLY NOT IN MARGIN ACTUALLY)
			//Although maybe it is useful for a debugger. Use left_margin_char_width to increase size and then just
			//print the text outside of DEBUG since we can have lines withou debugging.
			for text_op.exec_info.debug_info.break_points if it.bp_type == .BP_CODE {
				if it.line_number >= text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index && it.line_number <= end_render_line { 
					//TODO This should be a function to get LineIndexToOpPos since we reuse it above as well.
					// op_pos : Vector2F = MakeV2F(DEBUG_START_X, LOC_START_Y - (TEXT_LINE_HEIGHT*it.line_number));
					rel_y : int = it.line_number-text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index;
					// op_pos := Vector2F.{op_rect_min.x+1.0, op_rect_max.y - TEXT_LINE_HEIGHT*(rel_y+0.5)};
					op_pos := Vector2F.{DEBUG_START_X, DEBUG_START_Y - TEXT_LINE_HEIGHT*rel_y};
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					//TODO This radius should be based on char_width so it changes if we increment
					PushCircle(cam_pos, 0.5, RED_V, op_space.render_groups.scissor_group, res=6, order=left_margin_order+1);
				}
			}

			if text_op.exec_info.exec_state == .IS_DEBUG_STOP {
				// hit_instr := text_op.exec_info.debug_info.break_points[text_op.exec_info.debug_info.current_break_point_index].line_number;
				//TODO Technically we can compute this from start_asm_index
				//TODO ACTUALLY we should just get this from ip register like we do for disassembly pane
				stop_d_line := GetDebugLineAsm(perm.all_data.all_register_memory[RegDef.pc].int_value, text_op.text_comp_data);
				// stop_index : int = text_op.exec_info.debug_info.stop_line - text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index;
				stop_index : int = stop_d_line.line_number - text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index;
				//TODO Hardcoded for now since we always have asm starting on first line
				// hit_instr -= 1;
				//TODO This should be a function like above
				op_pos : Vector2F = MakeV2F(DEBUG_START_X, DEBUG_START_Y - (TEXT_LINE_HEIGHT*stop_index));
				cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				PushQuadArrowViewport(cam_pos,cam_pos+Vector2F.{0.85,0},YELLOW_V,0.1,op_space.render_groups.scissor_group,order=left_margin_order+2);
				//TODO Can use this code for line highlighting or also cursor highlighting.
				#if 0 {
				//TODO This is taken from PushTypeCursor so we should either recompute it somewhere or make a function.
				font_height_squares : float = ComputeFontHeightSquares(perm.text_editor_data.char_height, op_space.render_groups.scissor_group);
				//TODO Need to put x here as the size of the text + debug 
				rect := RectMinDim(cam_pos-Vector2F.{0,0.6*font_height_squares}, Vector2F.{15,font_height_squares});
				PushRectangle(rect, DBLUE_V, op_space.render_groups.scissor_group, 10001);
				}
			}


			/*Right rect starts here. I think we can put a lower rect as well in a similar way later if needed.
			Could set the scissors and shader at 30000 for example on lower rect and even put a console in it
			for easy access to compilation and execution console output info.
			We can also have dropdown menus that let us switch to stack frames and disassembly.
			TODO Could we generalize some of these rectangles a bit so it's easier to reason about later?

			TODO FROM HERE Make this clearer so that we are just starting from somewhere and then generating
			evertyhing from there, so just pull out the variable we are starting from.
			Although I guess right_min is that... maybe rename it

			TODO WOULD NEED TO PULL THESE OUT FOR MOUSE COLLISION. Then we can compute them and recompute on resize
			and then we would not have to compute them here. I am leaving here for now for coding simplicity
			until we do mouse collision. Then this will be both easier to test and work for mouse collision.
			LIKELY JUST COMPUTE AS FUNCTION FIRST AND THEN WE CAN TRY STORING FOR EFFICIENCY LATER.
			*/
			//Set shaders and scissor for right section
			right_order : int = 20000;
			PushSetShaderColor(op_space.render_groups.scissor_group, right_order+1);
			//TODO Leaving this here so we make sure the scissor reset is good.
			//We need the split_rect to bet on top of everything here and not get split out.
			debug_reset_scissor_order : int = 21010;
			//This is a safety reset scissor so we can place things on top of the debugger like the split_rect in the middle.
			//We do an extra scissor at the end after everything as well just in case but it probably does not really matter.
			PushSetScissor(op_space.render_groups.scissor_group.render_viewport, op_space.render_groups.scissor_group, order = debug_reset_scissor_order);
			PushSetShaderColor(op_space.render_groups.scissor_group, debug_reset_scissor_order+1);

			right_proportion : float = 1.0 - left_proportion;
			//TODO Should update this to be watch_min so we can generalize later.
			//THIS IS THE STARTING POINT OR INPUT FOR THE WATCH RECT IF EVER WE ALLOW IT TO BE MOVED
			right_min := Vector2F.{op_rect.min.x + left_proportion*op_space.world_size.x, op_rect.min.y};
			//TODO Could put DrawRectangleOutline here instead of that seems better.
			// op_right_min : Vector2F = OpSpaceToCameraSpace(right_min, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			#if NEW_TEXT_OP_RECTS {
			split_rect : Rectangle2 = text_op.ator.split_rect;
			} else {
			split_rect : Rectangle2 = RectCenterDim(right_min + Vector2F.{0,0.5*op_space.world_size.y}, 
				Vector2F.{0.1,op_space.world_size.y});
			}
			//TODO FROM HERE make split rect be RectRenderLeftOutline and then adjust bottom rect
			//so it can be adjusted independently BUT if we close the assembler then it matches left_proportion
			//Put the rects in the text_op
			cam_split_rect := OpRectToCamRect(split_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);			
			if text_op.mouse_hovering_split_rect || text_op.mouse_pressing_split_rect {
				PushRectangle(cam_split_rect, LBLUE_V, op_space.render_groups.scissor_group, final_reset_scissor_order+2);
			} else {
				PushRectangle(cam_split_rect, LIGHT_BROWN, op_space.render_groups.scissor_group, final_reset_scissor_order+2);
			}

			#if NEW_TEXT_OP_RECTS {
			right_rect : Rectangle2 = text_op.ator.right_rect;
			} else {
			right_rect : Rectangle2 = RectMinDim(right_min, 
				Vector2F.{right_proportion*op_space.world_size.x, op_space.world_size.y});
			}
			cam_right_rect := OpRectToCamRect(right_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			right_pixel_rect := CamRectToPixelRect(cam_right_rect, op_space.render_groups.scissor_group);
			PushSetScissor(right_pixel_rect, op_space.render_groups.scissor_group, order=right_order);


			/*TODO I am putting this here since we can pull it out and put it in a function eventually.
			That can be used both for testing AND also do only update these rects when we change the size
			of the window. That would be more efficient overall but also a bit more complicated code-wise.
			So I will leave it for here until the whole debug and text ui is more finalized.

			FINAL TEST : Would be to test the actual rendering objects directly. We could have unique order
			numbers which we store somewhere (probably consistently so can store somewhere generalized)
			and then we would right a test to grab the rectangles and text render objects directly by order.
			This way we can even move the op_space around and make sure everything moved around.
			*/
			//TODO Should make this rect independent so people can setup the editor however they want
			//and put text and debug window and console and stuff wherever they want.
			top_watch_pos : Vector2F;
			top_watch_pos.x = right_min.x;
			top_watch_pos.y = LOC_START_Y;
			watch_rect_dim : Vector2F;
			watch_rect_dim.x = right_proportion * op_space.world_size.x;
			//TODO Put TEXT_LINE_HEIGHT and other vars in TextOpSpaceData
			watch_rect_dim.y = TEXT_LINE_HEIGHT;

			#if NEW_TEXT_OP_RECTS {
			name_rect : Rectangle2 = text_op.ator.watch_name_rect;
			name_rect_dim : Vector2F = GetDim(name_rect);
			} else {
			name_proportion : float = 0.333333;
			name_rect_dim : Vector2F = GetDim(right_rect);
			name_rect_dim.x *= name_proportion;
			name_rect : Rectangle2 = RectMinDim(right_rect.min, name_rect_dim);
			}

			#if NEW_TEXT_OP_RECTS {
			value_rect : Rectangle2 = text_op.ator.watch_value_rect;
			value_rect_min : Vector2F = value_rect.min;
			value_rect_dim : Vector2F = GetDim(value_rect);
			} else {
			value_proportion : float = 0.4;
			value_rect_min : Vector2F = name_rect.min;
			value_rect_min.x += name_rect_dim.x;
			value_rect_dim : Vector2F = GetDim(right_rect);
			value_rect_dim.x *= value_proportion;
			value_rect : Rectangle2 = RectMinDim(value_rect_min, value_rect_dim);
			}
			top_value_pos : Vector2F;
			top_value_pos.x = value_rect_min.x;
			top_value_pos.y = LOC_START_Y;

			#if NEW_TEXT_OP_RECTS {
			value_split_rect := text_op.ator.name_value_split_rect;
			} else {
			value_split_rect : Rectangle2 = RectCenterDim(value_rect.min + Vector2F.{0,0.5*op_space.world_size.y}, 
				Vector2F.{0.06,op_space.world_size.y});
			}

			// type_proportion : float = 1.0-name_proportion-value_proportion;
			type_rect_min : Vector2F = value_rect.min;
			type_rect_min.x += value_rect_dim.x;
			// type_rect_dim : Vector2F = GetDim(right_rect);
			// type_rect_dim.x *= type_proportion;
			// type_rect : Rectangle2 = RectMinDim(type_rect_min, type_rect_dim);
			top_type_pos : Vector2F;
			top_type_pos.x = type_rect_min.x;
			top_type_pos.y = LOC_START_Y;



			/*NOTE : We need to compute this every frame since we have to put it in camera space
			and the scissor in pixel space. So we would leave this here no matter what.
			*/
			cam_top_watch_pos := OpSpaceToCameraSpace(top_watch_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			cam_name_rect := OpRectToCamRect(name_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			name_pixel_rect := CamRectToPixelRect(cam_name_rect, op_space.render_groups.scissor_group);
			name_order : int = 20100;
			PushSetScissor(name_pixel_rect, op_space.render_groups.scissor_group, name_order);
			//Name text shader for scissoring
			name_text_order : int = name_order+1;
			PushSetShaderText(op_space.render_groups.scissor_group, name_text_order);

			cam_top_value_pos := OpSpaceToCameraSpace(top_value_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			cam_value_rect := OpRectToCamRect(value_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			value_pixel_rect := CamRectToPixelRect(cam_value_rect, op_space.render_groups.scissor_group);
			value_order : int = 20200;
			value_text_order : int = value_order+1;
			PushSetScissor(value_pixel_rect, op_space.render_groups.scissor_group, value_order);
			PushSetShaderText(op_space.render_groups.scissor_group, value_text_order);

			cam_value_split := OpRectToCamRect(value_split_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			if text_op.mouse_hovering_name_value_split_rect || text_op.mouse_pressing_name_value_split_rect {
				PushRectangle(cam_value_split, LBLUE_V, op_space.render_groups.scissor_group, right_order+5);
			} else {
				PushRectangle(cam_value_split, GREY_DARKER_V, op_space.render_groups.scissor_group, right_order+5);
			}

			cam_top_type_pos := OpSpaceToCameraSpace(top_type_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			#if NEW_TEXT_OP_RECTS {
			type_split_rect := text_op.ator.value_type_split_rect;
			} else {
			type_split_rect : Rectangle2 = RectCenterDim(type_rect_min + Vector2F.{0,0.5*op_space.world_size.y}, 
				Vector2F.{0.06,op_space.world_size.y});
			}
			cam_type_split := OpRectToCamRect(type_split_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			if text_op.mouse_hovering_value_type_split_rect || text_op.mouse_pressing_value_type_split_rect {
				PushRectangle(cam_type_split, LBLUE_V, op_space.render_groups.scissor_group, right_order+5);
			} else {
				PushRectangle(cam_type_split, GREY_DARKER_V, op_space.render_groups.scissor_group, right_order+5);
			}
			type_order : int = value_order+10;
			type_text_order : int = type_order+1;
			PushSetScissor(op_space.render_groups.scissor_group.render_viewport, op_space.render_groups.scissor_group, order = type_order);


			//TODO 0.1 is margin should store in TextOpSpaceData.
			//Should we just do this with the spit_rect to not overlap?
			watch_margin := Vector2F.{GetDim(split_rect).x,
				//TODO We slightly raise this somewhere else but this is used for text now so we just do this
				//to slightly center the text. Not sure if it works if we change the font size. Will need to test that eventually.
				0.1*perm.text_editor_data.char_height/op_space.render_groups.scissor_group.pixels_per_square};
			// for text_op.watch_data_rows {
			//NOTE : This should never be 0 so we can input text on for the first watch name.
			assert(text_op.watch_data_rows.count > 0, "watch_data rows count should not be 0 because we need an empty first row.");
			//NOTE : We do start_watch_index-1 and end_watch_index+1 so that in case we have are rendering
			//and extra line which does not align perfectly with the window size, we can still see it.
			watch_render_start : int = max(0, text_op.start_watch_index);
			watch_render_end : int = min(text_op.watch_data_rows.count-1, text_op.end_watch_index+1);

			//NOTE : We use this to keep track of the top_index for each drop_down
			top_index : int = 0;
			for ri : watch_render_start..watch_render_end {
				//Render top watch data first
				row_pos : Vector2F = cam_top_watch_pos;
				row_pos.y -= (ri-watch_render_start) * TEXT_LINE_HEIGHT;
				PushText(row_pos+watch_margin, text_op.watch_data_rows[ri].display_name, LIGHT_BROWN, op_space.render_groups.scissor_group, name_text_order);
				//TODO Could convert this if_statement into an array and just grab based on index but since
				//one is black we just don't render a rectangle for now of them which might be better.
				is_odd_index : bool = top_index % 2 == 1;
				if is_odd_index {
					cam_rect : Rectangle2 = RectLeftCenterDim(row_pos, watch_rect_dim);
					PushRectangle(cam_rect, GREY_DARKEST2_V, op_space.render_groups.scissor_group, order = right_order+2);
				}

				//TODO FROM HERE Is this the cleanest and write some tests and cleanup input code as well.
				//Possibly put a memcpy for the deleting
				//Render each watch drop down with indent and corresponding color to top
				while ri + 1 <= watch_render_end && IsDroppedRow(text_op.watch_data_rows[ri + 1]) {
					ri += 1;
					row_pos.y -= TEXT_LINE_HEIGHT;
					text_pos : Vector2F = row_pos + watch_margin;
					text_pos.x += 1.5 * text_op.watch_data_rows[ri].watch_indent * perm.text_editor_data.code_font_1_char_width_world;
					PushText(text_pos, text_op.watch_data_rows[ri].display_name, LIGHT_BROWN, op_space.render_groups.scissor_group, name_text_order);
					//TODO Could pass in color here or have 2 loops for efficiency but I think branch prediction deals with that
					//since this will be the same everytime for each loop dropdown.
					if is_odd_index {
						cam_rect : Rectangle2 = RectLeftCenterDim(row_pos, watch_rect_dim);
						PushRectangle(cam_rect, GREY_DARKEST2_V, op_space.render_groups.scissor_group, order = right_order+2);
					}
				}

				top_index += 1;
			}
			//TODO I am not sure if this is better than just 1 loop. We did it because it removes the last element
			//and also we don't process this at all if we are not debugging. This seems like it would make
			//things SIMDable later and also possibly more efficient overall since we avoid 
			//if name.count > 0 if statements in the loop below.
			//OTHERWSIE We can just put it back in the loop above with a check like
			// if text_op.exec_info.debug_info.is_debug_stop && watch_data.name.count > 0
			//TODO Should we check DEBUG mode here too. OR make sure debug_stop can only be set when in debug mode.
			if text_op.exec_info.exec_state == .IS_DEBUG_STOP {
				debug_render_end : int = watch_render_end;
				if debug_render_end == text_op.watch_data_rows.count-1 {
					//We remove 1 in this case to not process the last watch row which is always empty.
					//This way we don't have to check name.count > 0 in the loop below.
					debug_render_end -= 1;
				}
				for watch_render_start..debug_render_end {
					watch_data : WatchData = text_op.watch_data_rows[it];

					value_pos : Vector2F = cam_top_value_pos;
					value_pos.y -= (it-watch_render_start) * TEXT_LINE_HEIGHT;
					PushText(value_pos+watch_margin, watch_data.value_str, LIGHT_BROWN, op_space.render_groups.scissor_group, value_text_order);

					type_pos : Vector2F = cam_top_type_pos;
					type_pos.y -= (it-watch_render_start) * TEXT_LINE_HEIGHT;				
					PushText(type_pos+watch_margin, watch_data.type_str, LIGHT_BROWN, op_space.render_groups.scissor_group, type_text_order);
				}	
			}

			//TODO Could generalize this as in InputBox maybe or maybe there is not enough code...
			//Could be useful to allow a text box wherever we want for example.
			//NOTE : We don't need another scissor here because the last type_text_order scissor is the whole watch pane.
			//So we just use that directly since we only want to easier on the left and right anyways.
			//TODO Should this be not rendering if we unchoose this op space?
			// if is_chosen_op_space && text_op.selected_pane == SelectedTextPane.WATCH {
			if text_op.selected_pane == SelectedTextPane.WATCH {
				text_pos : Vector2F = cam_top_watch_pos;
				text_pos.y -= (text_op.highlighted_name_index-watch_render_start) * TEXT_LINE_HEIGHT;

				cam_rect : Rectangle2 = RectLeftCenterDim(text_pos, watch_rect_dim);
				if text_op.is_watch_editing {
					edit_watch_order : int = type_text_order+1;
					PushSetShaderColor(op_space.render_groups.scissor_group, edit_watch_order);
					PushRectangle(cam_rect, GREY_V, op_space.render_groups.scissor_group, order = edit_watch_order+1);

					edit_watch_text_order : int = edit_watch_order+10;
					PushSetShaderText(op_space.render_groups.scissor_group, edit_watch_text_order);
					text_with_bounds : string = SingleLineTextInBounds(text_op.edit_watch_name.text_string, text_op.watch_cursor);
					PushText(text_pos+watch_margin, text_with_bounds, BLACK_V, op_space.render_groups.scissor_group, order = edit_watch_text_order+1);
					// PushText(text_pos+watch_margin, text_op.edit_watch_name.text_string, BLACK_V, op_space.render_groups.scissor_group, order = edit_watch_text_order+1);

					edit_watch_cursor_order : int = edit_watch_order+5;
					if text_op.watch_cursor.cursor_line_char >= text_op.watch_cursor.left_char_bound {
						line_char_delta : int = text_op.watch_cursor.cursor_line_char - text_op.watch_cursor.left_char_bound;
						PushSetShaderColor(op_space.render_groups.scissor_group, edit_watch_cursor_order);
						#if 1 {
						//TODO SETTINGS have some of these be adjustable through the settings file like highlight color here
						//so we can set it to whatever we want based on font color and background color
						watch_cursor_settings : SingleCursorSettings;
						watch_cursor_settings.input_cursor_width = CURSOR_WIDTH;
						watch_cursor_settings.cursor_height_factor = 0.8;
						DrawSingleLineCursor(text_op.watch_cursor, text_pos+watch_margin, cam_rect.min.x,
							edit_watch_cursor_order+1, op_space.render_groups.scissor_group, perm.text_editor_data, watch_cursor_settings);
						} else {
						PushTypeCursor(text_pos+watch_margin, line_char_delta * perm.text_editor_data.code_font_1_char_width_world, 
							//TODO Maybe the height here should not be multiplied by TEXT_LINE_HEIGHT by default...
							cast(int)(0.8*perm.text_editor_data.char_height), 
							op_space.render_groups.scissor_group, edit_watch_cursor_order+1, BLACK_V);
						}
					}

					#if 0 {
					//TODO Should we create 1 function to draw both of these or just leave it as separate cursors in case
					//we do highlighting later instead of 2 cursor (or leave the option in settings)
					if text_op.watch_cursor.cursor_is_selecting && 
						text_op.watch_cursor.fixed_select_line_char >= text_op.watch_cursor.left_char_bound
					{
						fixed_line_char_delta : int = text_op.watch_cursor.fixed_select_line_char - text_op.watch_cursor.left_char_bound;
						PushTypeCursor(text_pos+watch_margin, fixed_line_char_delta * perm.text_editor_data.code_font_1_char_width_world, 
							//TODO Maybe the height here should not be multiplied by TEXT_LINE_HEIGHT by default...
							cast(int)(0.8*perm.text_editor_data.char_height), 
							op_space.render_groups.scissor_group, edit_watch_cursor_order+1, LBLUE_V);
					}
					}
				} else {
					PushRectangle(cam_rect, DBLUE_V, op_space.render_groups.scissor_group, order = right_order+3);
				}
			}

			#if 0 {
			//TODO Put this in chosen text op_space and update TextOpSpaceData
			UpdateFileStringAtCursor(*perm.text_command_string, *perm.text_command_cursor, <<keyboard,
				perm.text_editor_data, single_line = true); 
			// DrawTextInputBox(perm.text_command_type, perm.text_command_string.text_string, perm.text_command_cursor.cursor_line_char * perm.text_editor_data.code_font_1_char_width_world, 
			// 	perm.text_editor_data.char_height, renderer_data.overlay_render_group);

			text_cursor_start : Vector2F = world_rect.min;
			text_cursor_start.y += 0.5*rect_height;
			PushText(text_cursor_start, text_string, GREY_DARK_V, render_group, order = 10003);
			PushTypeCursor(text_cursor_start, cursor_diff_x, font_height, render_group);
			}

			// PushSetShaderColor(op_space.render_groups.scissor_group, reset_scissor_order+1);
			// name_cam_rect := OpRectToCamRect(name_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			// PushRectangleOutline(name_cam_rect, GREY_DARKER_V, op_space.render_groups.scissor_group, 5.0, reset_scissor_order+1);
		}

		/*We are going to overlay the compiler output for now so that we can use it for text and debug.
		Ultimately it is probably better to have a system where we place things in each section so we can
		place whatever we want wherever, but for now this seems to make the most sense and I can collapse things
		later if needed.
		*/
		if text_op.l_bottom_pane_type != TextPaneType.NONE {
			//TODO I think r_bottom can be 30000 so this can be 40000. Just need to check for the reset_scissor_order and pull that out.

			//TODO I think we can pull this out and resize the rect with the proportions whenever we change it.
			//Then we can reuse the rect here or wherever else it's needed like for mouse clicking or testing.
			//Then we would be able to just pass in the rect to the pane and move the panes around the text space.
			l_bottom_order : int = 40000;
			PushSetShaderColor(op_space.render_groups.scissor_group, l_bottom_order+1);
			l_bottom_text_order : int = l_bottom_order+100;
			PushSetShaderText(op_space.render_groups.scissor_group, l_bottom_text_order);

			#if NEW_TEXT_OP_RECTS {
			l_bottom_rect : Rectangle2 = text_op.ator.l_bottom_rect;
			} else {
			bottom_proportion : float = text_op.bottom_proportion;
			l_bottom_left_proportion : float = text_op.l_bottom_left_proportion;
			l_bottom_rect : Rectangle2 = op_rect;
			l_bottom_rect.max.x = op_rect.min.x + l_bottom_left_proportion*op_space.world_size.x;
			l_bottom_rect.max.y = op_rect.min.y + bottom_proportion*op_space.world_size.y;			
			}


			//TODO Should we have a separate cam here so we can move along x-axis?
			cam_l_bottom_rect := OpRectToCamRect(l_bottom_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushRectangle(cam_l_bottom_rect, BLACK_V, op_space.render_groups.scissor_group, l_bottom_order+2);

			// l_bottom_split_cam_rect := RectRenderTopOutline(cam_l_bottom_rect, 4.0, op_space.render_groups.scissor_group.pixels_per_square);
			l_bottom_split_cam_rect := OpRectToCamRect(text_op.ator.l_bottom_split_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			if text_op.mouse_hovering_l_bottom_split_rect || text_op.mouse_pressing_l_bottom_split_rect {
				PushRectangle(l_bottom_split_cam_rect, LBLUE_V, op_space.render_groups.scissor_group, l_bottom_order+10);
			} else {
				PushRectangle(l_bottom_split_cam_rect, LIGHT_BROWN, op_space.render_groups.scissor_group, l_bottom_order+10);
			}

			//TODO This should just be a rect on top instead of an outline
			// PushRectangleOutline(cam_l_bottom_rect, LIGHT_BROWN, op_space.render_groups.scissor_group, 4.0, l_bottom_order+10);
			l_bottom_pixel_rect := CamRectToPixelRect(cam_l_bottom_rect, op_space.render_groups.scissor_group);
			PushSetScissor(l_bottom_pixel_rect, op_space.render_groups.scissor_group, order=l_bottom_order);


			if text_op.l_bottom_pane_type == {
			//TODO Should eventually allow input here so we can easily input text from a text_op and do things everywhere.
			case TextPaneType.COMPILER_CONSOLE; {
				if text_op.console_tsl.split_lines.count > 0 {
					console_render_end_line : int = min(text_op.console_tsl.split_lines.count-1,
						text_op.console_tsl.start_file_line_index + text_op.console_tsl.viewable_lines_from_zero + 1);
					for line_number : text_op.console_tsl.start_file_line_index..console_render_end_line {
						op_pos : Vector2F = LineStartToOpPos(line_number, text_op.console_tsl);
						cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
						//TODO We could slice here from the split selcs if we have one on the same line and then just print that
						//and not the rest so that the text looks cleaner when highlighted below
						next_line : string = text_op.console_tsl.split_lines[line_number].split_string;
						PushText(cam_pos, next_line, GREY_DARK_V, op_space.render_groups.scissor_group, l_bottom_text_order+1);
					}

					// l_bottom_order_2 : int = l_bottom_text_order+10;
					// PushSetShaderColor(op_space.render_groups.scissor_group, l_bottom_order_2);
					// l_bottom_text_order_2 : int = l_bottom_order_2+10;
					// PushSetShaderText(op_space.render_groups.scissor_group, l_bottom_text_order_2);

					//TODO FROM HERE we want to draw the text red instead because the highlighting feels intrusive
					//we can compare in any case and then select things however we want with the split selcs here
					//TODO We could make this look cleaner by drawing a black rectangle over the console text and 
					//then the highlighted text here over that
					//BLACK RECTANGLE does not work, we would have to split the text above if we wanted it to not be overlapped
					//text, but I don't know if adding that complexity is actually worth it but we can think about it later if needed.
					//ACTUALLY adding black text and then our text on top of it seems to be pretty good so I'll just leave it like that for now
					//TODO We can put a setting here if people prefer highlighted or text color change or underlining
					//could also add allowing all 3 to be added if needed later
					#if 1 {
					//sanity check since we convert the split selcs from the console highlights although eventually we might not...
					// assert(text_op.console_tsl.split_selcs.count == text_op.console_highlights.count);
					for selc, selc_index : text_op.console_tsl.split_selcs {
						//TODO Can reuse this for terminal text coloring if we add that later and also don't
						//forget the resize for the terminal text as well.
						for line_number : selc.start_line..selc.end_line {
							if InRange(text_op.console_tsl.start_file_line_index, line_number, console_render_end_line) {
								line_string : string = text_op.console_tsl.split_lines[line_number].split_string;
								start_line_char, end_line_char := LineSpecificStartEndChar(line_string, line_number, selc);
								char_count : int = end_line_char - start_line_char + 1;
								slice_string : string = String.slice(line_string, start_line_char, char_count);
								op_pos : Vector2F = LineStartToOpPos(line_number, text_op.console_tsl);
								op_pos.x += start_line_char * perm.text_editor_data.code_font_1_char_width_world;
								cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
								//ADDING black text and then color text on top of it seems to be pretty good so I'll just leave it like that for now
								//TODO SETTINGS This would have to be set to the background color if we eventually change the background color from the settings
								//TODO SETTINGS background color instead of black here
								PushText(cam_pos, slice_string, BLACK_V, op_space.render_groups.scissor_group, l_bottom_text_order+2);
								PushText(cam_pos, slice_string, text_op.console_highlights[selc_index].highlight_color, op_space.render_groups.scissor_group, l_bottom_text_order+3);

								//TODO This does not work because then the cursor highlighting stays under this black rect
								//I guess we would therefore have to remove the other text then and cut it off to render it properly
								//I can do that later if needed
								//we would have to check the split selcs for the given line and then slice the string above
								//and then just print this here like normal
								// op_highlighted_rect : Rectangle2 = 
								// 	TSLHighlightedRect(line_number, selc, text_op.console_tsl, perm.text_editor_data.code_font_1_char_width_world);
								// //TODO SETTINGS console highlighting color could be same as other highlighting color
								// cam_highlighted_rect : Rectangle2 = 
								// 	OpRectToCamRect(op_highlighted_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
								// // PushRectangle(cam_highlighted_rect, text_op.console_highlights[it_index].highlight_color, op_space.render_groups.scissor_group, order=l_bottom_order+3);
								// PushRectangle(cam_highlighted_rect, BLACK_V, op_space.render_groups.scissor_group, order=l_bottom_order_2+1);
							}
						}
					}
					} else {
					//TODO maybe we highlight text later that is selectable so we can click it and it does something
					//Maybe can have a separate array for highlighted rects or for highlighted text
					for selc : text_op.console_tsl.split_selcs {
						for line_number : selc.start_line..selc.end_line {
							//TODO We could precompute these rects if needed for efficiency since they are half the size of a selc
							//selc is however more general than a rect for split text selection overall
							//this rect function is however not very expensive 
							op_highlighted_rect : Rectangle2 = 
								TSLHighlightedRect(line_number, selc, text_op.console_tsl, perm.text_editor_data.code_font_1_char_width_world, add_1_count=true);
							//TODO Adding this line does an underline which does feel good, but the red text is very clear i think for errors
							op_highlighted_rect.max.y = op_highlighted_rect.min.y + 0.1*GetHeight(op_highlighted_rect);
							//TODO SETTINGS console highlighting color could be same as other highlighting color
							cam_highlighted_rect : Rectangle2 = 
								OpRectToCamRect(op_highlighted_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
							PushRectangle(cam_highlighted_rect, text_op.console_highlights[it_index].highlight_color, op_space.render_groups.scissor_group, order=l_bottom_order+3);
							// PushRectangle(cam_highlighted_rect, BLACK_V, op_space.render_groups.scissor_group, order=l_bottom_order+3);
						}
					}
					}

					if text_op.console_tsl.cursor_is_selecting {
						selc : StartEndLineChar = TextSplitLineOrderedStartEndLineChar(text_op.console_tsl); 
						for line_number : selc.start_line..selc.end_line {
							op_highlighted_rect : Rectangle2 = 
								TSLHighlightedRect(line_number, selc, text_op.console_tsl, perm.text_editor_data.code_font_1_char_width_world);
							//TODO SETTINGS console highlighting color could be same as other highlighting color
							cam_highlighted_rect : Rectangle2 = 
								OpRectToCamRect(op_highlighted_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
							PushRectangle(cam_highlighted_rect, LMBLUE_V, op_space.render_groups.scissor_group, order=l_bottom_order+4);
						}
					}
				}
			} 
			case TextPaneType.DISASSEMBLY; {
				//TODO If we put this in a function, then we just have to adjust these based on the rect that we're in
				//and then we can move things around the text area wherever we want.
				#if NEW_TEXT_OP_RECTS {
				LOC_BOTTOM_START_Y : float = text_op.ator.L_BOTTOM_LOC_ASM_Y;
				LOC_BOTTOM_START_X : float = text_op.ator.L_BOTTOM_LOC_ASM_X;
				} else {
				LOC_BOTTOM_START_Y : float = l_bottom_rect.max.y - 0.5*TEXT_LINE_HEIGHT - text_op.top_margin_height;
				LOC_BOTTOM_START_X : float = LOC_START_X;
				}
				ASM_DEBUG_START_Y : float = LOC_BOTTOM_START_Y - y_cursor_adjust;


				#if 0 {
				if IsInRectangle(op_mouse, text_op.ator.l_bottom_rect) {
					//We use LOC_START_Y instead of ASM_DEBUG_Y here because we want to click within the text line
					//and the asm debug is for setting the breakpoints in the correct visual position.
					mouse_asm_y_float_diff : float = (text_op.ator.L_BOTTOM_LOC_ASM_Y - op_mouse.y) / TEXT_LINE_HEIGHT;
					mouse_asm_y_diff : int = round_to_int(mouse_asm_y_float_diff);
					mouse_asm_index : int = text_op.start_disasm_index + mouse_asm_y_diff;
					if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
						// print("start_disasm_index=%,end_disasm_index=%\n", text_op.start_disasm_index, text_op.end_disasm_index);
						print("asm_index_diff=%,asm_index=%\n", mouse_asm_y_diff, mouse_asm_index);
						if text_op.selected_pane != SelectedTextPane.DISASSEMBLY {
							ChangeTextPane(SelectedTextPane.DISASSEMBLY, text_op, perm.all_data);
						}
						text_op.highlighted_disasm_index = Clamp(0, mouse_asm_index, text_op.text_comp_data.disassembly_loc.count-1);
					}
					//This means l_bottom_rect && left_margin_rect so its left_bottom_margin_rect because of the outer if
					if IsInRectangle(op_mouse, text_op.ator.left_margin_rect) &&
						IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input)
					{
						PressAsmBreakpoint(text_op);
					}
				}
				}


				//TODO We should be fetching this from a specific place eventually when we can have multiple compilations
				//each for separate text op spaces.
				if text_op.text_comp_data != null && text_op.text_comp_data.disassembly_loc.count > 0 {
					//We add end_disasm_index+1 to have an extra rendered line on the bottom
					end_disasm_render : int = min(text_op.text_comp_data.disassembly_loc.count-1, text_op.end_disasm_index+1);
					for text_op.start_disasm_index..end_disasm_render {
						disasm_text : string = text_op.text_comp_data.disassembly_loc[it];
						line_delta : int = it - text_op.start_disasm_index;
						// op_pos : Vector2F = MakeV2F(LOC_START_X, LOC_BOTTOM_START_Y - (TEXT_LINE_HEIGHT*(line_number-text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index)));
						op_pos : Vector2F = MakeV2F(LOC_BOTTOM_START_X, LOC_BOTTOM_START_Y - (TEXT_LINE_HEIGHT*line_delta));
						//TODO I think we need a l_bottom cam so we can move around that space on the x if needed.
						// cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, text_op.file_tabs[text_op.ftab_i].tab_cam_pos, default_base_cam);
						cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
						PushText(cam_pos, disasm_text, GREY_DARK_V, op_space.render_groups.scissor_group, l_bottom_text_order+1);
					}

					//NOTE : We print all breakpoints in asm because even BP_CODE has asm_index
					for text_op.exec_info.debug_info.break_points {
						if it.asm_index >= text_op.start_disasm_index && it.asm_index <= end_disasm_render {
							rel_y : int = it.asm_index-text_op.start_disasm_index;
							//TODO This should be a function to get LineIndexToOpPos since we reuse it below as well.
							op_pos : Vector2F = MakeV2F(DEBUG_START_X, ASM_DEBUG_START_Y - (TEXT_LINE_HEIGHT*rel_y));
							cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
							//TODO This radius should be based on char_width so it changes if we increment
							PushCircle(cam_pos, 0.5, RED_V, op_space.render_groups.scissor_group, res=6, order=l_bottom_order+4);
						}
					}

					if text_op.exec_info.exec_mode == .DEBUG && text_op.exec_info.exec_state == .IS_DEBUG_STOP {
						ip_reg : int = perm.all_data.all_register_memory[RegDef.pc].int_value;
						if ip_reg >= text_op.start_disasm_index && ip_reg <= text_op.end_disasm_index {
							rel_ip_index : int = ip_reg - text_op.start_disasm_index;
							//TODO FROM HERE I Think we want a separate DEBUG_START_Y which gets adjusted by the 
							//cursor_line_height with the same adjustment as the cursor, so we can pull that out and set it
							//above and then reuse it here for debug arrow and asm breakpoints
							//and also for code debug arrow and code breakpoints I think because it is all slightly to high.
							op_pos : Vector2F = MakeV2F(DEBUG_START_X, ASM_DEBUG_START_Y - (TEXT_LINE_HEIGHT*rel_ip_index));
							cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
							PushQuadArrowViewport(cam_pos,cam_pos+Vector2F.{0.85,0},YELLOW_V,0.1,op_space.render_groups.scissor_group,order=l_bottom_order+5);
						}

						//TODO Can use this code for line highlighting or also cursor highlighting.
						//Can highlight all the disasm associated to the current line here as well.
						#if 0 {
						//TODO This is taken from PushTypeCursor so we should either recompute it somewhere or make a function.
						font_height_squares : float = ComputeFontHeightSquares(perm.text_editor_data.char_height, op_space.render_groups.scissor_group);
						//TODO Need to put x here as the size of the text + debug 
						rect := RectMinDim(cam_pos-Vector2F.{0,0.6*font_height_squares}, Vector2F.{15,font_height_squares});
						PushRectangle(rect, DBLUE_V, op_space.render_groups.scissor_group, 10001);
						}
					}
				} else {
					op_pos : Vector2F = MakeV2F(LOC_BOTTOM_START_X, LOC_BOTTOM_START_Y);
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushText(cam_pos, "no disassembly", GREY_DARK_V, op_space.render_groups.scissor_group, l_bottom_text_order+1);					
				}

				if text_op.selected_pane == SelectedTextPane.DISASSEMBLY {
					op_pos := Vector2F.{LOC_BOTTOM_START_X, LOC_BOTTOM_START_Y};
					//TODO Need to consider start_disasm_index once we use that above.
					op_pos.y -= (text_op.highlighted_disasm_index-text_op.start_disasm_index) * TEXT_LINE_HEIGHT;
					//TODO Should we use a separate camera for l_bottom_cam?
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					rect_dim := Vector2F.{GetWidth(l_bottom_rect), TEXT_LINE_HEIGHT};
					cam_rect : Rectangle2 = RectLeftCenterDim(cam_pos, rect_dim);
					PushRectangle(cam_rect, DBLUE_V, op_space.render_groups.scissor_group, order = l_bottom_order+3);
				}
			}
			}
		}

		//TODO For now we only render this in DEBUG mode but maybe later if we can move things around then we have to readjust it.
		//This way allows us to not have to change the pane types so we can store the last setting and remember it once we reopen debug mode.
		if text_op.r_bottom_pane_type != TextPaneType.NONE &&
			//TODO If we can have bottom right open without DEBUG then maybe we can just use this for CALL_STACK or anything that requires debug
			text_op.exec_info.exec_mode == ExecutionMode.DEBUG
		{
			//TODO I think r_bottom can be 30000 and l_bottom is 40000. Just need to check for the reset_scissor_order and pull that out.

			//TODO I think we can pull this out and resize the rect with the proportions whenever we change it.
			//Then we can reuse the rect here or wherever else it's needed like for mouse clicking or testing.
			//Then we would be able to just pass in the rect to the pane and move the panes around the text space.
			r_bottom_order : int = 30000;
			PushSetShaderColor(op_space.render_groups.scissor_group, r_bottom_order+1);
			r_bottom_text_order : int = r_bottom_order+100;
			PushSetShaderText(op_space.render_groups.scissor_group, r_bottom_text_order);

			#if NEW_TEXT_OP_RECTS {
			r_bottom_rect : Rectangle2 = text_op.ator.r_bottom_rect;
			} else {
			bottom_proportion : float = text_op.r_bottom_height_proportion;
			r_bottom_height_proportion : float = 1 - text_op.l_bottom_left_proportion;
			r_bottom_rect : Rectangle2 = op_rect;
			r_bottom_rect.min.x = op_rect.min.x + text_op.l_bottom_left_proportion*op_space.world_size.x;
			r_bottom_rect.max.y = op_rect.min.y + bottom_proportion*op_space.world_size.y;
			}

			//TODO Should we have a separate cam here so we can move along x-axis?
			cam_r_bottom_rect := OpRectToCamRect(r_bottom_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			PushRectangle(cam_r_bottom_rect, BLACK_V, op_space.render_groups.scissor_group, r_bottom_order+2);

			//TODO This should just be a rect on top instead of an outline
			cam_r_bottom_split_rect := OpRectToCamRect(text_op.ator.r_bottom_split_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			if text_op.mouse_hovering_r_bottom_split_rect || text_op.mouse_pressing_r_bottom_split_rect {
				PushRectangle(cam_r_bottom_split_rect, LBLUE_V, op_space.render_groups.scissor_group, r_bottom_order+10);
			} else {
				PushRectangle(cam_r_bottom_split_rect, LIGHT_BROWN, op_space.render_groups.scissor_group, r_bottom_order+10);
			}
			// PushRectangleOutline(cam_r_bottom_rect, LIGHT_BROWN, op_space.render_groups.scissor_group, 4.0, r_bottom_order+10);

			r_bottom_pixel_rect := CamRectToPixelRect(cam_r_bottom_rect, op_space.render_groups.scissor_group);
			PushSetScissor(r_bottom_pixel_rect, op_space.render_groups.scissor_group, order=r_bottom_order);

			if text_op.r_bottom_pane_type == {
			case TextPaneType.CALL_STACK; {
			if text_op.exec_info.exec_state == .IS_DEBUG_STOP {
				//TODO If we put this in a function, then we just have to adjust these based on the rect that we're in
				//and then we can move things around the text area wherever we want.
				#if NEW_TEXT_OP_RECTS {
				LOC_BOTTOM_START_Y : float = text_op.ator.R_BOTTOM_LOC_CALL_STACK_Y;
				LOC_BOTTOM_START_X : float = text_op.ator.R_BOTTOM_LOC_CALL_STACK_X;
				} else {
				LOC_BOTTOM_START_Y : float = r_bottom_rect.max.y - 0.5*TEXT_LINE_HEIGHT - text_op.top_margin_height;
				LOC_BOTTOM_START_X : float = r_bottom_rect.min.x + X_GAP;
				// ASM_DEBUG_START_Y : float = LOC_BOTTOM_START_Y - y_cursor_adjust;
				}

				#if 0 {
				//TODO Remember that this is in IS_DEBUG_STOP along with other ones as well.
				if IsInRectangle(op_mouse, text_op.ator.r_bottom_rect) {
					mouse_call_stack_y_float_diff : float = (text_op.ator.R_BOTTOM_LOC_CALL_STACK_Y - op_mouse.y) / TEXT_LINE_HEIGHT;
					mouse_call_stack_y_diff : int = round_to_int(mouse_call_stack_y_float_diff);
					mouse_call_stack_index : int = text_op.start_call_stack_index + mouse_call_stack_y_diff;
					if IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) {
						print("call_stack_index_diff=%,call_stack_index=%\n", mouse_call_stack_y_diff, mouse_call_stack_index);
						if text_op.selected_pane != SelectedTextPane.CALL_STACK {
							ChangeTextPane(SelectedTextPane.CALL_STACK, text_op, perm.all_data);
						}
						text_op.highlighted_call_stack_index = Clamp(0, mouse_call_stack_index, text_op.exec_info.debug_info.debug_call_stack.count-1);
					}
					//TODO Can add a double click here to choose that call stack OR set it when we move up there
					//and see if they overlap. ALSO need to adjust code pointer so we can see where we are in the code
					//when we choose the other call stack
				}
				}

				//TODO Need to add text file name here once we add that
				//We can put it before like file_name.function() OR file_name->functon OR something else that is clear
				//and also include input/output types from the function type.
				// if text_op.text_comp_data != null {
				end_call_stack_render : int = min(text_op.exec_info.debug_info.debug_call_stack.count-1, 
					text_op.end_call_stack_index);
				// for text_op.exec_info.debug_info.debug_call_stack {
				// for #v2 < text_op.start_call_stack_index..end_call_stack_render {
				for text_op.start_call_stack_index..end_call_stack_render {
					/*DOC : We grab from the end of the c_frames and then render from the top of the pane.
					The c_frames c_index does not need an offset since we are taking directly from the array
					but the render_index needs the offset so we are always centered.
					*/
					c_index : int = text_op.exec_info.debug_info.debug_call_stack.count-1 - it;
					c_frame : *DebugCallFrame = *text_op.exec_info.debug_info.debug_call_stack[c_index];
					render_index : int = it-text_op.start_call_stack_index;
					op_pos : Vector2F = MakeV2F(LOC_BOTTOM_START_X+1, LOC_BOTTOM_START_Y - (TEXT_LINE_HEIGHT*render_index));
					//TODO I think we need a r_bottom cam so we can move around that space on the x if needed.
					// cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, text_op.file_tabs[text_op.ftab_i].tab_cam_pos, default_base_cam);
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushText(cam_pos, c_frame.func_decl.name, GREY_DARK_V, op_space.render_groups.scissor_group, r_bottom_text_order+1);
				}
				// }

				//TODO FROM HERE cleanup the ui a tiny bit (adjust arrows) and cleanup code if needed, then can continue 
				//and maybe also for foo with input and output to make sure data is in the right place OR add call stack check for other func tests
				if text_op.start_call_stack_index == 0 {
					//Always print yellow arrow on top stack to show where we are
					op_pos : Vector2F = MakeV2F(LOC_BOTTOM_START_X, LOC_BOTTOM_START_Y);
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushQuadArrowViewport(cam_pos,cam_pos+Vector2F.{0.85,0},YELLOW_V,0.1,op_space.render_groups.scissor_group,order=r_bottom_order+5);
				}

				//Only print selected arrow if we chose another call frame
				if text_op.exec_info.debug_info.chose_other_call_frame {
					//TODO Draw selected arrow different color
					//Need to take subtraction from call frame count since the selected_call_frame_index is based on
					from_top_index : int = (text_op.exec_info.debug_info.debug_call_stack.count - 1) - 
						text_op.exec_info.debug_info.selected_call_frame_index;
					from_top_index -= text_op.start_call_stack_index;
					op_pos : Vector2F = MakeV2F(LOC_BOTTOM_START_X, LOC_BOTTOM_START_Y - (TEXT_LINE_HEIGHT*from_top_index));
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushQuadArrowViewport(cam_pos,cam_pos+Vector2F.{0.85,0},ORANGE_V,0.1,op_space.render_groups.scissor_group,order=r_bottom_order+5);
				}

				if text_op.selected_pane == SelectedTextPane.CALL_STACK {
					op_pos := Vector2F.{r_bottom_rect.min.x, LOC_BOTTOM_START_Y};
					//TODO Need to consider start_disasm_index once we use that above.
					op_pos.y -= (text_op.highlighted_call_stack_index - text_op.start_call_stack_index) * TEXT_LINE_HEIGHT;
					//TODO Should we use a separate camera for r_bottom_cam?
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					rect_dim := Vector2F.{GetWidth(r_bottom_rect), TEXT_LINE_HEIGHT};
					cam_rect : Rectangle2 = RectLeftCenterDim(cam_pos, rect_dim);
					PushRectangle(cam_rect, DBLUE_V, op_space.render_groups.scissor_group, order = r_bottom_order+3);
				}

				#if 0 {
				//TODO We should be fetching this from a specific place eventually when we can have multiple compilations
				//each for separate text op spaces.
				if text_op.text_comp_data != null && text_op.text_comp_data.disassembly_loc.count > 0 {
					//We add end_disasm_index+1 to have an extra rendered line on the bottom
					end_disasm_render : int = min(text_op.text_comp_data.disassembly_loc.count-1, text_op.end_disasm_index+1);
					for text_op.start_disasm_index..end_disasm_render {
						disasm_text : string = text_op.text_comp_data.disassembly_loc[it];
						line_delta : int = it - text_op.start_disasm_index;
						// op_pos : Vector2F = MakeV2F(LOC_START_X, LOC_BOTTOM_START_Y - (TEXT_LINE_HEIGHT*(line_number-text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index)));
						op_pos : Vector2F = MakeV2F(LOC_BOTTOM_START_X, LOC_BOTTOM_START_Y - (TEXT_LINE_HEIGHT*line_delta));
						//TODO I think we need a r_bottom cam so we can move around that space on the x if needed.
						// cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, text_op.file_tabs[text_op.ftab_i].tab_cam_pos, default_base_cam);
						cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
						PushText(cam_pos, disasm_text, GREY_DARK_V, op_space.render_groups.scissor_group, r_bottom_text_order+1);
					}

					//NOTE : We print all breakpoints in asm because even BP_CODE has asm_index
					for text_op.exec_info.debug_info.break_points {
						if it.asm_index >= text_op.start_disasm_index && it.asm_index <= end_disasm_render {
							rel_y : int = it.asm_index-text_op.start_disasm_index;
							//TODO This should be a function to get LineIndexToOpPos since we reuse it below as well.
							op_pos : Vector2F = MakeV2F(DEBUG_START_X, ASM_DEBUG_START_Y - (TEXT_LINE_HEIGHT*rel_y));
							cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
							//TODO This radius should be based on char_width so it changes if we increment
							PushCircle(cam_pos, 0.5, RED_V, op_space.render_groups.scissor_group, res=6, order=r_bottom_order+4);
						}
					}

					if text_op.exec_info.exec_mode == .DEBUG && text_op.exec_info.exec_state == .IS_DEBUG_STOP {
						ip_reg : int = perm.all_data.all_register_memory[RegDef.pc].int_value;
						if ip_reg >= text_op.start_disasm_index && ip_reg <= text_op.end_disasm_index {
							rel_ip_index : int = ip_reg - text_op.start_disasm_index;
							//TODO FROM HERE I Think we want a separate DEBUG_START_Y which gets adjusted by the 
							//cursor_line_height with the same adjustment as the cursor, so we can pull that out and set it
							//above and then reuse it here for debug arrow and asm breakpoints
							//and also for code debug arrow and code breakpoints I think because it is all slightly to high.
							op_pos : Vector2F = MakeV2F(DEBUG_START_X, ASM_DEBUG_START_Y - (TEXT_LINE_HEIGHT*rel_ip_index));
							cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
							PushQuadArrowViewport(cam_pos,cam_pos+Vector2F.{0.85,0},YELLOW_V,0.1,op_space.render_groups.scissor_group,order=r_bottom_order+5);
						}

						//TODO Can use this code for line highlighting or also cursor highlighting.
						//Can highlight all the disasm associated to the current line here as well.
						#if 0 {
						//TODO This is taken from PushTypeCursor so we should either recompute it somewhere or make a function.
						font_height_squares : float = ComputeFontHeightSquares(perm.text_editor_data.char_height, op_space.render_groups.scissor_group);
						//TODO Need to put x here as the size of the text + debug 
						rect := RectMinDim(cam_pos-Vector2F.{0,0.6*font_height_squares}, Vector2F.{15,font_height_squares});
						PushRectangle(rect, DBLUE_V, op_space.render_groups.scissor_group, 10001);
						}
					}
				} else {
					op_pos : Vector2F = MakeV2F(LOC_BOTTOM_START_X, LOC_BOTTOM_START_Y);
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					PushText(cam_pos, "no disassembly", GREY_DARK_V, op_space.render_groups.scissor_group, r_bottom_text_order+1);					
				}

				if text_op.selected_pane == SelectedTextPane.DISASSEMBLY {
					op_pos := Vector2F.{LOC_BOTTOM_START_X, LOC_BOTTOM_START_Y};
					//TODO Need to consider start_disasm_index once we use that above.
					op_pos.y -= (text_op.highlighted_disasm_index-text_op.start_disasm_index) * TEXT_LINE_HEIGHT;
					//TODO Should we use a separate camera for r_bottom_cam?
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					rect_dim := Vector2F.{GetWidth(r_bottom_rect), TEXT_LINE_HEIGHT};
					cam_rect : Rectangle2 = RectLeftCenterDim(cam_pos, rect_dim);
					PushRectangle(cam_rect, DBLUE_V, op_space.render_groups.scissor_group, order = r_bottom_order+3);
				}
				}
			}
			}
			}
		}

		//TODO Leaving like this for now and not hardcoding in TextEditorData in case we use pixels_per_square
		//for zooming on the memory later.
		#if 0 {
		square_1_char_width : float = PixelSpaceToWorldSpace(perm.text_editor_data.code_font_1_char_width_pixel, op_space.render_groups.scissor_group.pixels_per_square);
		world_char_height : float = PixelSpaceToWorldSpace(perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);
		for error : perm.all_data.all_parse_errors
		{
			y_pos : float = 5 - (TEXT_LINE_HEIGHT * error.line_number) - (0.8 * world_char_height);
			op_pos : Vector2F = MakeV2F(LOC_START_X, y_pos);
			cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			error_rect := RectMinDim(cam_pos, MakeV2F(square_1_char_width, 0.15));
			PushRectangle(error_rect, RED_V, op_space.render_groups.scissor_group, order = 10001);
		}
		}
	}
	else if OpSpaceExternalType.terminal == op_space.op_space_external_type {
		//TODO We could separate this out now eventually and put it in the text editor directly if that is useful
		term_op : TerminalOpSpaceData = ArrayFindFirstConstByNameId(perm.all_data.all_terminal_op_space_data,
			op_space.id, "op_space_id");

		terminal_shader_order : int = 1000;
		PushSetShaderColor(op_space.render_groups.scissor_group, terminal_shader_order-1);
		terminal_text_order : int = terminal_shader_order+100;
		PushSetShaderText(op_space.render_groups.scissor_group, terminal_text_order-1);
		
		if term_op.terminal_tsl.split_lines.count > 0 {
			cmd_start_line : int = TerminalCmdStartLine(perm.terminal_data, term_op);
			// terminal_start_render_line : int = term_op.terminal_tsl.start_file_line_index;
			// terminal_end_render_line : int = min(term_op.terminal_tsl.split_lines.count-1,
			// 	term_op.terminal_tsl.start_file_line_index + term_op.terminal_tsl.viewable_lines_from_zero);
			// terminal_end_render_line : int = min(max(0,cmd_start_line-1),
			// 	term_op.terminal_tsl.start_file_line_index + term_op.terminal_tsl.viewable_lines_from_zero);
			// for next_line, line_index : term_op.terminal_tsl.split_lines {
			//DOC : We don't want to double render this if its the same as the cmd since then we get overlapping text
			if term_op.terminal_tsl.start_file_line_index != cmd_start_line {
				terminal_end_line : int = max(0, cmd_start_line-1);
				for line_number : term_op.terminal_tsl.start_file_line_index..terminal_end_line {
					next_line : string = term_op.terminal_tsl.split_lines[line_number].split_string;
					op_pos : Vector2F = LineStartToOpPos(line_number, term_op.terminal_tsl);
					// op_pos : Vector2F = TerminalLineStartToOpPos(line_number, term_op);
					cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
					// cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, perm.terminal_cam);
					PushText(cam_pos, next_line, GREY_DARK_V, op_space.render_groups.scissor_group, terminal_text_order);
				}
			}

			end_cmd_line : int = term_op.terminal_tsl.split_lines.count-1;
			for line_number : cmd_start_line..end_cmd_line {
				next_line : string = term_op.terminal_tsl.split_lines[line_number].split_string;
				op_pos : Vector2F = LineStartToOpPos(line_number, term_op.terminal_tsl);
				// op_pos : Vector2F = TerminalLineStartToOpPos(line_number, term_op);
				cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				// cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, perm.terminal_cam);
				PushText(cam_pos, next_line, TEXT_BROWN, op_space.render_groups.scissor_group, terminal_text_order);
			}
		}

		//TODO this is for the ">" we could set that in terminal data if we need it elsewhere
		//TODO Remove this since we will put it in terminal_split_lines
		// start_cmd_char_count : int = 1;
		#if 0 {
		cmd_split_lines : [..] string;
		cmd_split_lines.allocator = temp;
		cmd_string : string = tprint(">%", perm.terminal_command_string.text_string);
		AddSplitStringByLines(cmd_string, term_op.terminal_tsl.line_char_count, *cmd_split_lines);
		for next_line, line_index : cmd_split_lines {
			// op_pos : Vector2F = MakeV2F(term_op.terminal_tsl.x_start_left, 
			// 	term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.line_height*(line_index+term_op.terminal_tsl.split_lines.count)));
			op_pos : Vector2F = TerminalLineStartToOpPos(line_index+term_op.terminal_tsl.split_lines.count, term_op);
			cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			// PushText(cam_pos + MakeV2F(char_width,0), next_line, TEXT_BROWN, renderer_data.terminal_render_group, 10003);
			PushText(cam_pos, next_line, TEXT_BROWN, op_space.render_groups.scissor_group, terminal_text_order);
		}
		}

		// TerminalOpToTextPos :: inline (op_pos : Vector2F) -> line_number : int, line_char : int {
		// }
		if term_op.terminal_tsl.cursor_is_selecting {
			selc : StartEndLineChar = TextSplitLineOrderedStartEndLineChar(term_op.terminal_tsl); 
			for line_number : selc.start_line..selc.end_line {
				op_highlighted_rect : Rectangle2 = 
					TSLHighlightedRect(line_number, selc, term_op.terminal_tsl, perm.text_editor_data.code_font_1_char_width_world);
				//TODO SETTINGS console highlighting color could be same as other highlighting color
				cam_highlighted_rect : Rectangle2 = 
					OpRectToCamRect(op_highlighted_rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				PushRectangle(cam_highlighted_rect, LMBLUE_V, op_space.render_groups.scissor_group, order=terminal_shader_order+1);
			}
		}

		terminal_cursor : *TextCursor = *perm.terminal_data.terminal_cursor;
		//TODO I think we can use something similar for mouse highlighting
		/*DOC : This allows cmd highlighting with the cursor the way we normally do it with text
		and has the offset for the terminal cmd start string.
		MAN all this code even though we can already highlight with the mouse.
		We could just put 2 cursor in this case for simplicity but I guess this is more consistent
		with other highlighting.
		*/
		if terminal_cursor.cursor_is_selecting {			
			min_char_point : int;
			max_char_point : int;
			if terminal_cursor.fixed_select_char_point < terminal_cursor.char_point {
				min_char_point = terminal_cursor.fixed_select_char_point;
				max_char_point = terminal_cursor.char_point;
			} else if terminal_cursor.char_point < terminal_cursor.fixed_select_char_point { //cursor_line_char < fixed_select_line_char
				//Sanity check, this should never happen to avoid extra button presses to move it.
				//This case should set cursor_is_selecting=false in UpdateFileStringAtCursor
				assert(terminal_cursor.cursor_line_char != terminal_cursor.fixed_select_line_char);
				min_char_point = terminal_cursor.char_point;
				max_char_point = terminal_cursor.fixed_select_char_point;
			}
			min_line_diff : int = TerminalCmdLineDiff(min_char_point, term_op.terminal_tsl.line_char_count);
			max_line_diff : int = TerminalCmdLineDiff(max_char_point, term_op.terminal_tsl.line_char_count);

			// cursor_height : float = ComputeCursorHeight(perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);
			// y_adjust : float = YAdjustCursorHeight(cursor_height);
			current_char_point : int = min_char_point;
			first_line_size : int = TerminalCmdFirstLineSize(term_op, perm.terminal_data);
			for line_diff : min_line_diff..max_line_diff 
			{
				next_char_point : int;
				if min_line_diff == max_line_diff {
					next_char_point = max_char_point;
				} else if line_diff == 0 {
					next_char_point = first_line_size;
				} else if line_diff == min_line_diff {
					next_char_point = first_line_size + min_line_diff*term_op.terminal_tsl.line_char_count;
				} else if line_diff == max_line_diff {
					next_char_point = max_char_point;
				} else {
					next_char_point = current_char_point + term_op.terminal_tsl.line_char_count;
				}
				char_count : int = next_char_point - current_char_point;

				min_op_pos : Vector2F = TerminalCmdCharPointToOpPos(current_char_point,
					perm.text_editor_data.code_font_1_char_width_world, term_op, perm.terminal_data);

				//TODO Reuse this function for text highlighting as well
				TextToMinCursorPos(*min_op_pos, term_op.terminal_tsl.cursor_height);
				//TODO We reuse this from highlighting text editor so maybe we can make a function to adjust... not sure since we don't do x here
				//Maybe just a reminder to update there too if we update here...
				// min_op_pos.y -= YAdjustCursorHeight(term_op.terminal_tsl.cursor_height) + 0.5*term_op.terminal_tsl.cursor_height;
				//TODO Only do this highlighting offset for cmd lines not for general terminal lines
				#if 0 {
				if line_diff == min_line_diff {
					min_op_pos.x += perm.terminal_data.terminal_start_cmd_string.count * perm.text_editor_data.code_font_1_char_width_world;
				} else {
					char_count += perm.terminal_data.terminal_start_cmd_string.count;
				}
				}
				min_cam_pos : Vector2F = OpSpaceToCameraSpace(min_op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
				highlighted_rect : Rectangle2 = HighlightedLineRect(char_count, term_op.terminal_tsl.cursor_height, min_cam_pos, 
					perm.text_editor_data.code_font_1_char_width_world);
				//TODO SETTINGS terminal_highlighting_color
				PushRectangle(highlighted_rect, LMBLUE_V, op_space.render_groups.scissor_group, order=terminal_shader_order+1);

				current_char_point = next_char_point;
			}
		}

		if is_chosen_op_space {
			op_pos : Vector2F = TerminalCmdCharPointToOpPos(perm.terminal_data.terminal_cursor.char_point,
				perm.text_editor_data.code_font_1_char_width_world, term_op, perm.terminal_data);
			//NOTE : We add one char here for the ">" so the cursor does not go over that
			//This works because we end up going back to the previous line char anyways and it lines up.
			//TODO If there are issues then just bring the code from TerminalCmdCharPointToOpPos specifically
			//in here but otherwise it's nice to reuse the code everywhere.
			// op_pos.x += perm.terminal_data.terminal_start_cmd_string.count * perm.text_editor_data.code_font_1_char_width_world;
			// cam_pos : Vector2F = WorldSpaceToCameraSpace(op_pos, perm.terminal_cam);
			cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
			//TODO move terminal_cursor to TerminalOpSpaceData 
			//OR actually could just keep it here so the terminal is exactly the same everywhere
			//TODO Could pull this out with rect for text highlighting after
			//NOTE : x_diff is 0 since we add it to the op_pos above
			//TODO Maybe we can do it this way in other places and remove the x_diff or set the default for it to 0? Maybe it does not matter
			PushTypeCursor(cam_pos, 0, perm.text_editor_data.char_height,
				op_space.render_groups.scissor_group, cursor_width=term_op.TERMINAL_CURSOR_WIDTH, order=terminal_shader_order+2);
		}
	}
	/*DOC : This is the new 3d space that allows us to add arbitrary 3d rects and text right now.
	Eventually we can add other shapes with less triangles for convenience.
	*/
	else if OpSpaceExternalType.space_3d == op_space.op_space_external_type {
		op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
			op_space.id, "op_space_id");
		assert(found_op_3D);

		//TODO can we put cam_offset update somehwere else so we don't do any mutating in here?
		//Note : We have added the op_space.world_offset but really that is the world_pos because
		//chord_s3_world_pos always remains == Vector2F.{0,0}.
	 	op_3D.op_space_3D.viewport.cam_offset = WorldSpaceToCameraSpace(op_space.world_offset, default_base_cam);

		/**
		Multiply camera with Quaternions up till this point and then set the rotation matrix
		only once here before taking the inverse of the camera transform
		Would also multiply the set rotation matrix by the camera transform. Therefore,
		we would not store the camera rotation in the transform but only in the quaternion
		and pass it at the end here
		**/
		rotate_with_temp : Matrix3F = op_3D.op_space_3D.temp_cam_rotate * GetTransform(op_3D.op_space_3D.cam_trans);
		rotate_camera := MakeMatrix4x3F(rotate_with_temp, GetTranslation(op_3D.op_space_3D.cam_trans));
		inv_camera : Matrix4x3F = InverseLengyel(rotate_camera);
		frustum_inv_camera : Matrix4F = op_3D.op_space_3D.p_frustum * inv_camera;

		// vl_scale_matrix : Matrix3F = MakeScaleMatrix(0.3,0.3,0.35);
		//TODO We can fetch this per point given a bool or have a separate type that has this stored in the data
		vl_transform_matrix := Matrix3F_Identity;
		for sp_3d : op_3D.all_op_space_points_3D {
			rotate_pos : Vector3F = RotatedGrid3DPosition(sp_3d.rel_pos, op_3D.op_space_3D);
	    	rotate_transform : Matrix4x3F = MakeMatrix4x3F(MakeScaleMatrix(sp_3d.scale_value), rotate_pos);
		   mvp_cube := frustum_inv_camera * rotate_transform;
	    	order_by_length : int = -round_to_int(100 * Length(rotate_pos - GetTranslation(op_3D.op_space_3D.cam_trans)));

	    	//TODO We can separate this into separate arrays later if that is more efficient. also allows for better data separation
			if sp_3d.draw_wire_mesh {
	    		TransformAndPushMesh(CUBE_TRI_FACE, mvp_cube, op_space.render_groups.scissor_group, null, op_3D.op_space_3D.viewport, 
	    			order_by_length+1, color=sp_3d.color, draw_wire_mesh=true);
			} else {
			   TransformAndPushMesh(CUBE_TRI_FACE, mvp_cube, op_space.render_groups.scissor_group_3D, null, op_3D.op_space_3D.viewport, 
			   	order_by_length, color=sp_3d.color);
			}
		}
		for space_text : op_3D.all_op_text_3D {
			rotate_pos : Vector3F = RotatedGrid3DPosition(space_text.op_pos, op_3D.op_space_3D);
	    	rotate_transform : Matrix4x3F = MakeMatrix4x3F(Matrix3F_Identity, rotate_pos);
		   mvp_cube := frustum_inv_camera * rotate_transform;
			text_formatted_pos, in_view_frustum := Position3DTo2D(mvp_cube, op_3D.op_space_3D.viewport, op_space.render_groups.scissor_group);
			//TODO This cuts out a bit early. It will get scissored out anyways if we want to remove it I think.
			if in_view_frustum {
				PushText(text_formatted_pos, space_text.text, WHITE_V, op_space.render_groups.scissor_group, 10003);
				rect_formatted : Rectangle2 = Text3DBackgroundRect(space_text.text, text_formatted_pos, 
					op_space.render_groups.scissor_group.pixels_per_square, perm.text_editor_data);
				PushRectangle(rect_formatted, BLACK_V, op_space.render_groups.scissor_group, order = 10001);
			}
		}
		if op_3D.op_space_3D.chosen_cube.type == GridTriangleType.VERTEX &&
			op_3D.op_space_3D.click_cube.point_index != op_3D.op_space_3D.chosen_cube.point_index
		{
	    	sp_3d : SpacePoint3D = op_3D.all_op_space_points_3D[op_3D.op_space_3D.chosen_cube.point_index];
			rotate_pos : Vector3F = RotatedGrid3DPosition(sp_3d.rel_pos, op_3D.op_space_3D);
	    	rotate_transform : Matrix4x3F = MakeMatrix4x3F(MakeScaleMatrix(sp_3d.scale_value), rotate_pos);
			mvp_cube := frustum_inv_camera * rotate_transform;
	    	order_by_length : int = -round_to_int(100 * Length(rotate_pos - GetTranslation(op_3D.op_space_3D.cam_trans)));
    		TransformAndPushMesh(CUBE_TRI_FACE, mvp_cube, op_space.render_groups.scissor_group, null, op_3D.op_space_3D.viewport, 
    			order_by_length+2, ORANGE_V, draw_wire_mesh=true);
    		// TransformAndPushMesh(sp_3d.data.mesh, mvp_cube, op_space.render_groups.scissor_group, null, op_3D.op_space_3D.viewport, order_by_length+1, ORANGE_V, true);
	    	if sp_3d.shape_text.data != null && sp_3d.shape_text.count > 0 {
	    		/*TODO Could pass in a setting where we show or don't show this.
	    		Could also allow it to be place on an upper ui instead directly on the cube.
	    		*/
	    		text_formatted_pos, in_view_frustum := Position3DTo2D(mvp_cube, op_3D.op_space_3D.viewport, op_space.render_groups.scissor_group);
				if in_view_frustum {
					// pitch_text := tprint("%",sp_3d.pitch_set);
					PushText(text_formatted_pos, sp_3d.shape_text, WHITE_V, op_space.render_groups.scissor_group, 10003);

					rect_formatted : Rectangle2 = Text3DBackgroundRect(sp_3d.shape_text, text_formatted_pos, 
						op_space.render_groups.scissor_group.pixels_per_square, perm.text_editor_data);
					PushRectangle(rect_formatted, BLACK_V, op_space.render_groups.scissor_group, order = 10001);
				}
			}
    	}
	}
}
}
/*RENDERING ENDS HERE
*/

// game_input.last_frame_mouse_cam = mouse_cam;

ResetTransientMemory(trans);
//TODO Should we call this after rendering in win_thegame?
reset_temporary_storage();

//TODO could have multiple temporary storages for each mode and
//push new contexts for each one
//TODO replace this with transient memory in context everywhere
//TODO or replace jai temp allocator with my own transient memory
// reset_temporary_storage();
}