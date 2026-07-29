/*DOC : Apparently this just loads the default values if it is invalid anyways

TODO I THINKS THIS WAY OF DOING SETTINGS and input mappings MIGHT BE TEMPORARY
We can just use dynamic libraries eventually and then store everything in there
and just have a dynamic library system instead of these files.
I guess this might be good for now and maybe we can use it later anyways for other things
or just for specific startup settings or something like that.
*/
//TODO FROM HERE add fixed settings data for default window size and then also add op space default size
//and text op default factor and set those. THEN use the save_test_mac for macos tests with that file
//and then adjust the Test_TextTabs for macos since we use a string internally so can just set the copmile time in 2 places for now
//Maybe we can do the same for Test_TextTabs so it works seamlessly on mac and windows
GLOBAL_STARTUP_SETTINGS : StartupSettingsData;
StartupSettingsData :: struct {
	use_startup_screen_dim : bool = false;
	startup_screen_width : int = 3840;
	startup_screen_height : int = 2160;

	use_startup_window_dim : bool = false;
	startup_window_width : int = 3168;
	startup_window_height : int = 1782;

	startup_window_pos_x_screen_fraction : float = 0.15;
	startup_window_pos_y_screen_fraction : float = 0.075;
}
StartupSettingsReturn :: struct {
	new_settings : StartupSettingsData;
	success : bool;
	error_msg : string;
}
ParseStartupSettingsFile :: (file_path : string) -> StartupSettingsReturn {
	ssr : StartupSettingsReturn;
	//TODO We can check if file exists here but I think it happens in json_parse_file anyways
	success, parsed_settings := json_parse_file(file_path, StartupSettingsData,, temp);
	if !success {
		ssr.success = false;
		ssr.error_msg = tprint("Invalid startup settings file %.\n", file_path);
		return ssr;
	}

	ssr.success = true;
	ssr.new_settings = parsed_settings;
	return ssr;
}
STARTUP_SETTINGS_REL_PATH :: "settings/startup_settings";
GENERATED_STARTUP_SETTINGS_REL_PATH :: "settings/generated_startup_settings";
GenerateStartupSettingsFile :: inline (settings : StartupSettingsData, file_path : string) -> bool {
	success : bool = json_write_file(file_path, settings);
	return success;
}

/*
TODO I THINKS THIS WAY OF DOING SETTINGS and input mappings MIGHT BE TEMPORARY
We can just use dynamic libraries eventually and then store everything in there
and just have a dynamic library system instead of these files.
I guess this might be good for now and maybe we can use it later anyways for other things
or just for specific startup settings or something like that.
ESPECIALLY FOR runtime settings, it would make a lot more sense to just allow updating directly
from there instead of havint to write all this extra conversion code. Then we could just automatically
load a dynamic lib precompiled file at runtime or even suggest an automatic script to run whenever
updating so that the each person does that
*/
//TODO We could test these conversion functions but meh
ParsedToRuntimeSettings :: inline (prs : ParsedRuntimeSettings) -> RuntimeSettingsData {
	rsd : RuntimeSettingsData;
	// rsd.default_input_mappings_file = copy_string(prs.default_input_mappings_file);
	rsd.save_file_on_focus_lost = prs.save_file_on_focus_lost;

	rsd.terminal_size = Dim2DSettingToVector2F(prs.terminal_size);
	rsd.text_op_size = Dim2DSettingToVector2F(prs.text_op_size);
	rsd.default_op_space_size = Dim2DSettingToVector2F(prs.default_op_space_size);

	rsd.default_font_size = prs.default_font_size;
	rsd.default_font_color = RGBASettingToVector4F(prs.default_font_color);
	rsd.default_text_op_background_color = RGBASettingToVector4F(prs.default_text_op_background_color);
	rsd.default_text_op_border_color = RGBASettingToVector4F(prs.default_text_op_border_color);
	return rsd;
}
RuntimeToParsedSettings :: inline (rsd : RuntimeSettingsData) -> ParsedRuntimeSettings {
	prs : ParsedRuntimeSettings;
	// prs.default_input_mappings_file = copy_string(rsd.default_input_mappings_file);
	prs.save_file_on_focus_lost = rsd.save_file_on_focus_lost;

	prs.terminal_size = Vector2FToDim2DSetting(rsd.terminal_size);
	prs.text_op_size = Vector2FToDim2DSetting(rsd.text_op_size);
	prs.default_op_space_size = Vector2FToDim2DSetting(rsd.default_op_space_size);

	prs.default_font_size = rsd.default_font_size;
	prs.default_font_color = Vector4FToRGBASetting(rsd.default_font_color);
	prs.default_text_op_background_color = Vector4FToRGBASetting(rsd.default_text_op_background_color);
	prs.default_text_op_border_color = Vector4FToRGBASetting(rsd.default_text_op_border_color);
	return prs;
}
ParsedRuntimeSettings :: struct {
	// default_input_mappings_file : string = INPUT_MAPPINGS_REL_PATH;
	save_file_on_focus_lost : bool = false;

	//TODO Should this be in it's own file eventually so we can have custom shareable themes with just 1 file?
	//Maybe we wait till there are too many setting options or if we want to add colors/settings as variables as well.
	//TODO We could add that as part of the language and have a specific file for current theme which is just code...
	//and then have a specific asm instruction to do that. ALSO can do it with external dynamic libraries
	//ACTUALLY external dynamic library is even better I think. Gives an example of using external dynamic libraries as well
	//which could be fun to play around with how things look
	//Theme settings
	default_font_size : float = 18.0;
	default_font_color : RGBASetting;
	default_text_op_background_color : RGBASetting;
	default_text_op_border_color : RGBASetting;	

	terminal_size : Dim2DSetting = #run Vector2FToDim2DSetting(OP_SPACE_DEFAULT_SIZE);
	text_op_size : Dim2DSetting = #run Vector2FToDim2DSetting(DEFAULT_TEXT_OP_SIZE);
	default_op_space_size : Dim2DSetting = #run Vector2FToDim2DSetting(OP_SPACE_DEFAULT_SIZE);
}
Dim2DSetting :: struct {
	width : float;
	height : float;
}
Dim2DSettingToVector2F :: inline (dim : Dim2DSetting) -> Vector2F {
	v : Vector2F = ---;
	v.x = dim.width;
	v.y = dim.height;
	return v;
}
Vector2FToDim2DSetting :: inline (v : Vector2F) -> Dim2DSetting {
	dim : Dim2DSetting = ---;
	dim.width = v.x;
	dim.height = v.y;
	return dim;
}
ClampDimV2FSetting :: inline (v : Vector2F) -> Vector2F {
	ret_v : Vector2F = ---;
	ret_v.x = Clamp(OP_SPACE_MIN_SIZE.x, v.x, OP_SPACE_MAX_SIZE.x);
	ret_v.y = Clamp(OP_SPACE_MIN_SIZE.y, v.y, OP_SPACE_MAX_SIZE.y);
	return ret_v;
}
//TODO FROM HERE convert this to an internal settings so we can use it directly with vector4f and vector2f
//DOC : This is temporary. Eventually we will allow this to be upgraded with code directly probably via dynamic libraries.
//Then people can use whatever color format they want and we will have them set it directly as a vector 4.
RGBASetting :: struct {
	r, g, b : u8;
	a : float;
}
operator == :: (r1 : RGBASetting, r2 : RGBASetting) -> bool {
	equals : bool = r1.r == r2.r && r1.g == r2.g && r1.b == r2.b &&
		FloatEqual(r1.a, r2.a);
	return equals;
}
RGBASettingToVector4F :: inline (rgbas : RGBASetting) -> Vector4F {
	v : Vector4F = ---;
	v.x = rgbas.r / 255.0;
	v.y = rgbas.g / 255.0;
	v.z = rgbas.b / 255.0;
	v.w = rgbas.a;
	return v;
}
Vector4FToRGBASetting :: inline (v : Vector4F) -> RGBASetting {
	rgbas : RGBASetting = ---;
	rgbas.r = cast(u8) round_to_int(v.x * 255.0);
	rgbas.g = cast(u8) round_to_int(v.y * 255.0);
	rgbas.b = cast(u8) round_to_int(v.z * 255.0);
	rgbas.a = v.w;
	return rgbas;
}
// operator == :: (r1 : RuntimeSettingsData, r2 : RuntimeSettingsData) -> bool {
// 	equals : bool = 
// 		r1.default_input_mappings_file == r2.default_input_mappings_file &&
// 		r1.terminal_start_pos == r2.terminal_start_pos &&
// 		r1.terminal_start_size == r2.terminal_start_size &&
// 		r1.default_font_size == r2.default_font_size &&
// 		r1.default_font_color == r2.default_font_color &&
// 		r1.default_text_op_background_color == r2.default_text_op_background_color &&
// 		r1.default_text_op_border_color == r2.default_text_op_border_color;
// 	return equals;
// }
RUNTIME_SETTINGS_REL_PATH :: "settings/runtime_settings";
GENERATED_RUNTIME_SETTINGS_REL_PATH :: "settings/generated_runtime_settings";
//TODO INPUT file name here so we can let user change path and for testing
GenerateRuntimeSettingsFile :: inline (settings : RuntimeSettingsData, file_path : string) -> bool {
	parsed_settings : ParsedRuntimeSettings = RuntimeToParsedSettings(settings);
	success : bool = json_write_file(file_path, parsed_settings);
	return success;
}
//TODO Could just return the settings, then we have to set the correct one for the tests as well but we could
//also just make that a separate file
RuntimeSettingsReturn :: struct {
	new_settings : RuntimeSettingsData;
	success : bool;
	error_msg : string;
}
/*DOC : 
If a file contains members that are not in the runtime settings but everything else is valid, then it will
just skip over it. So that is good in general but if someone mistypes a setting, then that setting will be set to default.
This can be corrected in general by generating new settings and verifying by the user.
I am not going to go too much into changing this because i think using external dynamic libraries eventually is a better solution
overall. HOWEVER we may continue using this for startup settings or some specific startup file names eventually maybe
although overall i prefer to just have everything be code anyways, even startup can be a dynamic loaded library.
Having it all be code also allows code to be used to generate settings which is interesting because then even that
can be associated to the music, like colors and other settings.
MAYBE we can juse use this for settings dynamic library paths eventually and then do something
closer to input mappings and just have like a settings dynamic library and then an array of runtime dynamic libraries
and then maybe some other specific ones for input or other things depending on how we design it.
*/
ParseRuntimeSettingsFile :: (all_text_files : *[..] TextFile, file_path : string) -> RuntimeSettingsReturn {
	rsr : RuntimeSettingsReturn;

	text_file, found_text_file := GetOrLoadTextFileByAbsolutePath(file_path, all_text_files, check_absolute_path=true);
	//If not found then we keep the same one we have for now
	if !found_text_file {
		rsr.success = false;
		rsr.error_msg = tprint("% not found. Runtime settings not updated.\n", file_path);
		return rsr;
	}

	success, parsed_settings := json_parse_string(text_file.file_string.text_string, ParsedRuntimeSettings,, temp);
	if !success {
		rsr.success = false;
		rsr.error_msg = tprint("Invalid runtime settings file %.\n", file_path);
		return rsr;
	}

	rsr.success = true;
	rsr.new_settings = ParsedToRuntimeSettings(parsed_settings);
	return rsr;
}
//TODO Can use this to check invalid files eventually if we set any files in here
// ValidateRuntimeSettings :: inline (rs : RuntimeSettingsData) -> valid : bool, error_msg : string {
// }
ClampV4Color :: inline (v : Vector4F) -> Vector4F {
	v_clamp : Vector4F = ---;
	v_clamp.x = Clamp(0.,v.x,1.);
	v_clamp.y = Clamp(0.,v.y,1.);
	v_clamp.z = Clamp(0.,v.z,1.);
	v_clamp.w = Clamp(0.,v.w,1.);
	return v_clamp;
}
UpdateRuntimeSettings :: inline (
	new_rs : RuntimeSettingsData, 
	perm : *Persist, 
	rd : *RendererData)
{
	//TODO I am updating this every time because otherwise we don't pickup the update if the font size is
	//the regular size like with macos laptop. I could pass in a force all update flag but maybe better
	//to always update so that we keep things consistent for now
	// if !FloatEqual(new_rs.default_font_size, perm.all_data.runtime_settings.default_font_size) {
		perm.all_data.runtime_settings.default_font_size = Clamp(9., new_rs.default_font_size, 31.);
		UpdateFontSize(perm.all_data.runtime_settings.default_font_size, *perm.text_editor_data, rd);
		for * text_op : perm.all_data.all_text_op_space_data {
			op_space, found_op_space := FindOpSpaceOpenOrClosed(text_op.op_space_id, perm.all_data);
			assert(found_op_space);
			ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square, perm.text_editor_data);
		}
		for * term_op : perm.all_data.all_terminal_op_space_data {
			op_space, found_op_space := FindOpSpaceOpenOrClosed(term_op.op_space_id, perm.all_data);
			assert(found_op_space);
			ResizeTerminalOpSpace(term_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
				perm.text_editor_data, perm.terminal_data);
		}
	// }
	perm.all_data.runtime_settings.terminal_size = ClampDimV2FSetting(new_rs.terminal_size);
	perm.all_data.runtime_settings.text_op_size = ClampDimV2FSetting(new_rs.text_op_size);
	perm.all_data.runtime_settings.default_op_space_size = ClampDimV2FSetting(new_rs.default_op_space_size);
	perm.all_data.runtime_settings.save_file_on_focus_lost = new_rs.save_file_on_focus_lost;
	perm.all_data.runtime_settings.default_font_color = ClampV4Color(new_rs.default_font_color);
	perm.all_data.runtime_settings.default_text_op_background_color = ClampV4Color(new_rs.default_text_op_background_color);
	perm.all_data.runtime_settings.default_text_op_border_color = ClampV4Color(new_rs.default_text_op_border_color);

	//We don't let this go below 1 to avoid stalling at 0 or having negative instructions
	perm.all_data.runtime_settings.asm_instructions_per_frame = max(1, new_rs.asm_instructions_per_frame);
}

ParsedInputMapping :: struct {
	//TODO FROM HERE write unit tests for input mappings and settings and see if we should make errors clearer
	//Then can write integration tests to update it in game and make sure it updates and also maybe to output error messages better
	//TOOD If we load this in as a string as well, then we can validate it internally and output an error message if needed.
	//ALSO if it's a string then it can parse invalid commands and still work for the rest of the valid ones
	// command : InputMapType;
	command : string;
	description : string;
	keyboard_keys : [] string;
}
/*DOC : jaison does not take in arrays directly so need to add this so jaison does not error out.
*/
ParsedInputMappingData :: struct {
	input_mappings : [] ParsedInputMapping;
}
ParsedInputMappingReturn :: struct {
	parsed_input_mappings : [] ParsedInputMapping;
	error_msg : string;
	success : bool;
}
//TODO Pass this in through the function so we can let the user do that if needed
//and then also simplifies testing so we can generate and test from a separate test settings folder
//TODO SETTINGS we could put this in settings and then be able to update it to whatever we want
//then we could just set that in tests and then update it for updating data for input mappings
INPUT_MAPPINGS_REL_PATH :: "settings/input_mappings";
GENERATED_INPUT_MAPPINGS_REL_PATH :: "settings/generated_input_mappings";
KEY_IM_SEPARATOR :: "+";
ALT_IM_STRING :: "alt";
SHIFT_IM_STRING :: "shift";
CTRL_IM_STRING :: "ctrl";
CMD_IM_STRING :: "cmd";
/*DOC : Genarate input mappings file from given input mappings so we can pass in defaults here OR just pass
in the current mappings and we can else set a file but the default file is the only place we actually pull
the settings from in-game. Otherwise it can be used for testing or maybe later to allow different input mappings
so you can pull in a specific one and we can set the file in settings if needed.
NOTE everything is set to lower case in here to make it clear that it is just the key but it does not actually matter
in general since we can just leave it as is or upper case but this way i think it is consistent and clear.

TODO Although people could just change the name of the file but maybe this makes it easier to switch things
around later with a terminal command and just update the file name in the command
*/
GenerateInputMappingsFile :: (input_mappings : [] InputMapping, file_path : string) -> bool {
//This gets check in json write anyways so we can remove it if not needed later but im using it as a sanity check for now
assert(file_path.data != null && file_path.count > 0);

	all_pim : [] ParsedInputMapping = NewArray(input_mappings.count, ParsedInputMapping);
	//TODO I think we should put this in game_input and pull it from there instead
	sb : String_Builder;
	sb.allocator = temp;
	for mapping, m_index : input_mappings {
		all_pim[m_index].command = INPUT_MAP_TYPE_NAMES[mapping.input_map_type];
		all_pim[m_index].description = IM_DESCRIPTIONS[mapping.input_map_type];
		all_pim[m_index].keyboard_keys = NewArray(mapping.keyboard_maps.count, string);
		for keymap, keymap_index : mapping.keyboard_maps {
			added_modifier : bool = false;
			if keymap.modifier_flags.shift_pressed {
				append(*sb, SHIFT_IM_STRING);
				added_modifier = true;
			}
			if keymap.modifier_flags.ctrl_pressed {
				if added_modifier append(*sb, KEY_IM_SEPARATOR);
				append(*sb, CTRL_IM_STRING);
				added_modifier = true;
			}
			if keymap.modifier_flags.alt_pressed {
				if added_modifier append(*sb, KEY_IM_SEPARATOR);
				append(*sb, ALT_IM_STRING);
				added_modifier = true;
			}
			if keymap.modifier_flags.cmd_meta_pressed {
				if added_modifier append(*sb, KEY_IM_SEPARATOR);
				append(*sb, CMD_IM_STRING);
				added_modifier = true;
			}
			if added_modifier append(*sb, KEY_IM_SEPARATOR);
			char_value := cast(u8) keymap.key_code;
			if IsValidInputMapKey(char_value) {
				//NOTE : to_lower only lower alphabet characters
				append(*sb, to_lower(char_value));
			} else {
				key_string : string = tprint("%", keymap.key_code);
				String.to_lower_in_place(key_string);
				append(*sb, key_string);
			}
			all_pim[m_index].keyboard_keys[keymap_index] = builder_to_string(*sb);
		}
	}

	pimd : ParsedInputMappingData;
	pimd.input_mappings = all_pim;
	success : bool = json_write_file(file_path, pimd);
	return success;
}
/*DOC : This file just parses the json but does not validate any data.
Jaison validates that the json is correct and otherwise returns an error which we return here.
I think it does not do any further validation because i think all the values are strings
but maybe if it was specific values it would check.
TODO We can check that in the settings.
*/
ParseInputMappingsFile :: (all_text_files : *[..] TextFile, file_path : string) -> ParsedInputMappingReturn {
	sr : ParsedInputMappingReturn;

	//DOC : We get or load here because even if we update externally, we will reload the file
	//when we come back in here and then update the input mappings from here.
	//Should we just parse settings then on file reload or on file save and not have terminal command?
	// text_file, found_text_file := GetOrLoadTextFileByFileName(file_path, all_text_files);
	text_file, found_text_file := GetOrLoadTextFileByAbsolutePath(file_path, all_text_files,
		check_absolute_path=true);
	//If not found then we keep the same one we have for now
	if !found_text_file {
		sr.success = false;
		sr.error_msg = tprint("% not found. Input mappings not updated.\n", file_path);
		return sr;
	}

	success, pimd := json_parse_string(text_file.file_string.text_string, ParsedInputMappingData,, temp);
	if !success {
		sr.success = false;
		sr.error_msg = tprint("Invalid shortcuts file %.\n", file_path);
		return sr;
	}

	//TODO Should we valid input mappings here as well or only on updating?

	sr.success = true;
	sr.parsed_input_mappings = pimd.input_mappings;
	return sr;
}
/*DOC : Valid input mappings tested in unit test Test_InputMappings.
Valid parsed inputs require : 
- valid command name (TODO might have to set a warning for renames here)
- only 1 key code
- valid key code as either 1 alphanumeric char or a key code name like "enter" or a modifier name like "ctrl"
*/
ValidateParsedInputMappings :: inline (pimd : [] ParsedInputMapping) -> valid : bool, error_msg : string {
	valid_mapping : bool = true;
	sb : String_Builder;
	//TODO We could pass this in through context.allocator or just copy it over here
	sb.allocator = context.allocator;
	for parsed_mapping : pimd {
		//TODO We could set the input_map_index here so we don't have to check again but there aren't that many of them...
		//TODO We could only set invalid commands as a warning if we did a rename here
		valid_name, input_map_index := array_find(INPUT_MAP_TYPE_NAMES, parsed_mapping.command);
		if !valid_name {
			//TODO So if it's a rename we could not set this to false and put a warning message instead
			valid_mapping = false;
			print_to_builder(*sb, "Invalid input mapping command \"%\".\n", parsed_mapping.command);
			continue;
		}
		for keymap_string : parsed_mapping.keyboard_keys {
			key_split : [] string = String.split(keymap_string, KEY_IM_SEPARATOR,, temp);
			//DOC : We can only find 1 key code per keymap so if we find more than one, then it should be invalid
			found_key_code : bool = false;
			invalid_key : bool = false;
			for key : key_split {
				//TODO FROM HERE if key.count == 0 && key.data != null && key_split_index < key_split.count-1 then 
				//also check key.data < keymap_string.data + count so that is in the string for sure and not out of bounds memory
				//check if key[0] == KEY_IM_SEPARATOR, 
				//then set key to be + so we can make key a pointer and just increase count by 1 in this case
				//to get the plus thats already in memory
				if key.count == 1 && IsValidInputMapKey(key[0]) && !found_key_code { 
					found_key_code = true;
					continue key;
				}
				else if AllOrEquals(key, .[ALT_IM_STRING,SHIFT_IM_STRING,CTRL_IM_STRING,CMD_IM_STRING]) {
					continue key;
				} 
				else if !found_key_code {
					//NOTE : Technically modifier keys are in here but i'll leave them up there for clarity
					for all_key_code_names if String.equal_nocase(it, key) {
						found_key_code = true;
						continue key;
					}
				}
				else {
					invalid_key = true;
				}
			}
			if !found_key_code || invalid_key {
				valid_mapping = false;
				print_to_builder(*sb, "Invalid input mapping \"%\" for command %.\n", keymap_string, parsed_mapping.command);
			}
		}
	}

	return valid_mapping, builder_to_string(*sb);
}
//DOC : Can probably just have the range, but let's do both just in case
IsValidInputMapKey :: inline (c : u8) -> bool {
	return is_alnum(c) || (c >= 33 && c <= 126);
}
/*DOC : If we have an invalid parsed input mapping, then we don't update anything here.
So it will just leave the mappings the way they were if it is invalid.

We could validate each parsed input mapping to still take in the correct ones but this makes
validation cleaner and less prone to error overall.
ALSO easier to add other input mappings later, for example if we add input mappings for midi later.

NOTE WE SET key code single chars as upper case in here because that is what we are using for all inputs.
BUT we use a no case check for the actually input map file parsing so it does not matter what we write in the file
since a lower and upper case character does not change anything in terms of mapping an input.
*/
UpdateGameInputMappings :: inline (pimd : [] ParsedInputMapping, game_input : *GameInput) -> valid : bool, error_msg : string {
//DOC : This should be setup on startup so we should always have valid input mappings
assert(game_input.game_input_mappings.data != null && game_input.game_input_mappings.count == INPUT_MAP_TYPE_ENUMS.count);

	//TODO We can just let this be passed in through UpdateGameInputMappings eventually if we want to just set it in an allocator
	//For now we copy this over in both cases so storing in temp here simplifies that
	valid, error_msg := ValidateParsedInputMappings(pimd,, temp);
	if !valid return false, error_msg;

	for parsed_mapping : pimd {
		found, input_map_index := array_find(INPUT_MAP_TYPE_NAMES, parsed_mapping.command);
		game_im : *InputMapping = *game_input.game_input_mappings[input_map_index];
		game_im.input_map_type = INPUT_MAP_TYPE_ENUMS[input_map_index];
		if parsed_mapping.keyboard_keys.count != game_im.keyboard_maps.count {
			//TODO If we copy this array and don't just use the constant, then we should free this
			//This was causing some issues in testing so we remove it for now.
			//I think it's not a huge deal since input keyboard maps should not be updated that often
			// if game_im.keyboard_maps.data != null array_free(game_im.keyboard_maps);
			//TODO We could also add a limited number of keyboard maps in the InputMapping struct to avoid null pointer issues
			game_im.keyboard_maps = NewArray(parsed_mapping.keyboard_keys.count, KeyboardMap);
		} else {
			//Reset the keymaps here if we did not create a new array
			for * game_im.keyboard_maps it.* = .{};
		}
		for k_value, ki : parsed_mapping.keyboard_keys {
			split_keys : [] string = String.split(k_value, KEY_IM_SEPARATOR,, temp);
			for key : split_keys if key == {
			case ALT_IM_STRING; game_im.keyboard_maps[ki].modifier_flags.alt_pressed = true;
			case SHIFT_IM_STRING; game_im.keyboard_maps[ki].modifier_flags.shift_pressed = true;
			case CTRL_IM_STRING; game_im.keyboard_maps[ki].modifier_flags.ctrl_pressed = true;
			case CMD_IM_STRING; game_im.keyboard_maps[ki].modifier_flags.cmd_meta_pressed = true;
			case; {
				if key.count == 1 && IsValidInputMapKey(key[0]) {
					//DOC : Input should not matter if it's upper or lower but we use upper in code so set to upper here.
					game_im.keyboard_maps[ki].key_code = cast(Input.Key_Code) to_upper(key[0]);
				} else {
					for all_key_code_names if String.equal_nocase(it, key) {
						game_im.keyboard_maps[ki].key_code = all_key_code_enums[it_index];
						break;
					}
				}
			}
			}	
		}
	}

	return true, "";
}
CopyDefaultInputMappings :: inline () -> [] InputMapping {
	copy_im : [] InputMapping = array_copy(DEFAULT_INPUT_MAPPINGS);
	for DEFAULT_INPUT_MAPPINGS {
		copy_im[it_index].keyboard_maps = array_copy(it.keyboard_maps);
	}	
	return copy_im;
}
/*DOC : This is to setup the game input mappings on startup. We grab the parsed input mappings file and if that
fails then we grab the defaults and log the error. If we update the game input mappings, in game, then
we can set the errors in the text console as well.
*/
SetupGameInputMappings :: inline (game_input : *GameInput, all_text_files : *[..] TextFile, file_path : string) {
	game_input.game_input_mappings = CopyDefaultInputMappings();
	// game_input.game_input_mappings = array_copy(DEFAULT_INPUT_MAPPINGS);
	// for DEFAULT_INPUT_MAPPINGS {
	// 	game_input.game_input_mappings[it_index].keyboard_maps = array_copy(it.keyboard_maps);
	// }
	pimr : ParsedInputMappingReturn = ParseInputMappingsFile(all_text_files, file_path);
	if pimr.success {
		valid, error_msg := UpdateGameInputMappings(pimr.parsed_input_mappings, game_input);
		if !valid log_error(error_msg);
	} 
	//I think this is just a log since the file could be missing and just defaults are used
	//but i will leave it out for now since if there is no file then we should be setting defaults as we are above.
	//NOTE : This creates an log msg in Test_InputMappings unit test which is fine since we did not generate the file yet
	//to check that default mappings are set here properly.
	// else {
	// 	log(pimr.error_msg);
	// }
}