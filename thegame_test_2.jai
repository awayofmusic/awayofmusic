//TODO I think maybe we can also put tests in the same file as code if we separate some of it out eventually
AssertSplitSelcs :: (test_selcs : [] StartEndLineChar, selcs : [] StartEndLineChar) {
	count_equal := AssertEquals(test_selcs.count, selcs.count);
	if count_equal for test_selcs {
		AssertEquals(it.start_line, selcs[it_index].start_line, "start_line");
		AssertEquals(it.start_line_char, selcs[it_index].start_line_char, "start_line_char");
		AssertEquals(it.end_line, selcs[it_index].end_line, "end_line");
		AssertEquals(it.end_line_char, selcs[it_index].end_line_char, "end_line_char");
	}
}
//REMINDER : THIS TEST FAILES when running from the shared or thegame folder because of the added shared folder in between
//It is not a valid failure and that is fine. 
//GENERALLY I can run the code from the main file and that should be fine.
Test_TextConsole :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	if !perm.test_data.initialized_test {
		perm.test_data.initialized_test = true;
		//TODO Can't we call this when the test is started instead so we don't have to call it in each test?
		//Maybe we can just do the renderer if we want specific data, but this way we have clean data for every test...
		//I can see wanting specific data to start a test though but not renderer...
		perm.all_data = InitAllData();
		ResetAllRendererData(renderer_data);
		perm.test_data.spec_data = New(TextTestData);
		array_resize(*perm.test_data.all_sub_tests, 41+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	tt_op : *TextOpSpaceData = *tt_data.test_text_op;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);
	}
	text_op : *TextOpSpaceData;
	text_cursor : TextCursor;
	watch_cursor : TextCursor;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
		watch_cursor = text_op.watch_cursor;
		AssertEquals(1, perm.all_data.all_text_op_space_data[0].file_tabs.count);
		if perm.all_data.all_text_op_space_data[0].file_tabs.count > 0 {
			text_cursor = perm.all_data.all_text_op_space_data[0].file_tabs[0].tab_cursor;
		}
	}
	tf_string : string;
	text_file : *TextFile;
	if perm.all_data.all_text_files.count > 0 {
		text_file = *perm.all_data.all_text_files[0];
		tf_string = text_file.file_string.text_string;
	}
	op_space : OperationSpace;
	op_2D_cam : Camera2D;
	default_base_cam : Camera2D;
	// ator : AllTextOpRects;	
	// top : TextOpPositions;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_open_op_spaces.count);
		if perm.all_data.all_open_op_spaces.count > 0 {
			op_space = perm.all_data.all_open_op_spaces[0];
			op_2D_cam = op_space.op_2D_cam;
		}	
		default_base_cam = GetRenderMSpace(perm.all_data).mspace_cam;
		// top = ComputeTextOpPositions(text_op.ator, op_space, text_op, perm.text_editor_data);
	}

	one_line_msg :: "this is a 1 line msg";
	two_line_msg :: "this is a 2 line msg with more word than the 1 line";
	three_line_msg :: "this is a 3 line msg with even more words than the 2 line so that then we actually have 3 lines";
	four_line_msg :: "even more text here to test a 4 line command and so we keep writing so that we can test three lines clearly more test goes here yes yes yes";
	five_line_msg :: "even more text here to test a 5 line command and so we keep writing so that we can test three lines clearly more test goes here yes yes yes can test five lines clearly more test goes here";

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	}
	case 2; {
		DownUpInputMap(.TEXT_CONSOLE_TOGGLE, game_input);
	}
	case 3; {
		AssertEquals(TextPaneType.COMPILER_CONSOLE, text_op.l_bottom_pane_type);
		AssertEquals(SelectedTextPane.COMPILER_CONSOLE, text_op.selected_pane);

		text_op.text_comp_data = New(CompilationData);
		//We add the text console manually here to be systematic about it
		SetTextOpConsoleMessage(one_line_msg, text_op);
		// ResetTextCursor(*text_op.console_tsl.cursor);
		// text_op.console_tsl.split_lines.count = 0;
		// array_add(*text_op.all_console_lines, one_line_msg);
		// AddSplitStringByLines(one_line_msg, *text_op.console_tsl);
		tt_op.console_tsl.split_lines.count = 1;
		tt_op.console_tsl.line_char_count = 39;
		tt_op.console_tsl.viewable_lines_from_zero = 8;
		tt_op.console_dynamic_string.text_string.count = one_line_msg.count;
		tt_op.all_console_lines.count = 1;
	}
	case 4; {
		AssertEquals(tt_op.console_dynamic_string.text_string.count, text_op.console_dynamic_string.text_string.count);
		AssertEquals(tt_op.all_console_lines.count, text_op.all_console_lines.count);
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		SetTextOpConsoleMessage(two_line_msg, text_op, add_text=true);
		tt_op.console_tsl.split_lines.count += 2;
		tt_op.console_dynamic_string.text_string.count += two_line_msg.count + 1; //+1 for the added "\n"
		// array_add(*text_op.all_console_lines, two_line_msg);
		// AddSplitStringByLines(two_line_msg, *text_op.console_tsl);

		SetTextOpConsoleMessage(three_line_msg, text_op, add_text=true);
		tt_op.console_tsl.split_lines.count += 3;
		tt_op.console_dynamic_string.text_string.count += three_line_msg.count + 1; //+1 for the added "\n"
		// array_add(*text_op.all_console_lines, three_line_msg);
		// AddSplitStringByLines(three_line_msg, *text_op.console_tsl);

		SetTextOpConsoleMessage(four_line_msg, text_op, add_text=true);
		tt_op.console_tsl.split_lines.count += 4;
		tt_op.console_dynamic_string.text_string.count += four_line_msg.count + 1; //+1 for the added "\n"
		// array_add(*text_op.all_console_lines, four_line_msg);
		// AddSplitStringByLines(four_line_msg, *text_op.console_tsl);

		SetTextOpConsoleMessage(five_line_msg, text_op, add_text=true);
		tt_op.console_tsl.split_lines.count += 5;
		tt_op.console_dynamic_string.text_string.count += five_line_msg.count + 1; //+1 for the added "\n"
		// array_add(*text_op.all_console_lines, five_line_msg);
		// AddSplitStringByLines(five_line_msg, *text_op.console_tsl);

		tt_op.all_console_lines.count = 5;
	}
	case 5; {
		AssertEquals(tt_op.console_dynamic_string.text_string.count, text_op.console_dynamic_string.text_string.count);
		AssertEquals(tt_op.all_console_lines.count, text_op.all_console_lines.count);
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		op_console := Vector2F.{
			text_op.console_tsl.x_start_left,
			text_op.console_tsl.y_start_top
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_console, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -1;
		tt_op.console_tsl.start_file_line_index += 1;
	}
	case 6; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		op_console := Vector2F.{
			text_op.console_tsl.x_start_left,
			text_op.console_tsl.y_start_top
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_console, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -3;
		tt_op.console_tsl.start_file_line_index += 3;
	}
	case 7; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		op_console := Vector2F.{
			text_op.console_tsl.x_start_left,
			text_op.console_tsl.y_start_top
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_console, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 1;
		tt_op.console_tsl.start_file_line_index -= 1;
	}
	case 8; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		op_console := Vector2F.{
			text_op.console_tsl.x_start_left,
			text_op.console_tsl.y_start_top
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_console, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 3;
		tt_op.console_tsl.start_file_line_index -= 3;
	}
	case 9; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//TEST highlight the three line cmd in the middle and then copy
		op_console := Vector2F.{
			text_op.console_tsl.x_start_left,
			text_op.console_tsl.y_start_top - 3*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_console, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		tt_op.console_tsl.cursor_left_mouse_holding = true;
		tt_op.console_tsl.cursor_line_number = 3;
	}
	case 10; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//TEST highlight the three line cmd in the middle and then copy
		op_console := Vector2F.{
			text_op.console_tsl.x_start_left + text_op.console_tsl.line_char_count * perm.text_editor_data.code_font_1_char_width_world,
			text_op.console_tsl.y_start_top - 5*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_console, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.console_tsl.fixed_select_line_number = tt_op.console_tsl.cursor_line_number;
		tt_op.console_tsl.fixed_select_line_char = tt_op.console_tsl.cursor_line_char;
		tt_op.console_tsl.cursor_line_number = 5;
		tt_op.console_tsl.cursor_line_char = 17;
		tt_op.console_tsl.cursor_is_selecting = true;
	}
	case 11; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//TEST highlight the three line cmd in the middle and then copy
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		tt_op.console_tsl.cursor_left_mouse_holding = false;
	}
	case 12; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//TEST highlight the three line cmd in the middle and then copy
		DownUpInputMap(.TEXT_COPY, game_input);
	}
	case 13; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//TEST highlight the three line cmd in the middle and then copy
		cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals(three_line_msg, cb_text);
	}
	case 14; {
		//test moving arrow up and down (checking also that cursor selection is still there)
		//TODO We could test going more below but we could update it later so no need since we can allow lines on the bottom anyways
		RunSubTestNTimes(5, *perm.test_data);
		DownUpThisFrame(.ARROW_DOWN, game_input);
		tt_op.console_tsl.start_file_line_index += 1;
	}
	case 15; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);
	}
	case 16; {
		RunSubTestNTimes(5, *perm.test_data);
		DownUpThisFrame(.ARROW_UP, game_input);
		tt_op.console_tsl.start_file_line_index -= 1;
	}
	case 17; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//test that going up 1 more does nothing since we are at 0
		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 18; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//test horizontal resize should change line_char_count with split line
		split_center : Vector2F = GetCenter(text_op.ator.split_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(split_center, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 19; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(true, text_op.mouse_pressing_split_rect);

		half_l_bottom_rect : Vector2F = GetCenter(text_op.ator.l_bottom_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(half_l_bottom_rect, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 20; {
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);

		tt_op.console_tsl.line_char_count /= 2;
		tt_op.console_tsl.split_lines.count *= 2;
		tt_op.console_tsl.split_lines.count -= 1;//-1 since we are going from zero and we are on the boundary
	}
	case 21; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//Reset manually here to get the right proportion
		text_op.set_left_proportion = 0.6;
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);
		tt_op.console_tsl.line_char_count *= 2;
		tt_op.console_tsl.line_char_count += 1;
		tt_op.console_tsl.split_lines.count += 1;//I guess we need to subtract 1 since its offset by 1 on the boundary and not a perfect multiple
		tt_op.console_tsl.split_lines.count /= 2;

		//test vertical resize should change viewable_lines with split line
		left_split : Vector2F = GetCenter(text_op.ator.l_bottom_split_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(left_split, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 22; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		AssertEquals(false, text_op.mouse_hovering_l_bottom_split_rect);
		AssertEquals(true, text_op.mouse_pressing_l_bottom_split_rect);

		half_l_bottom_rect : Vector2F = GetCenter(text_op.ator.l_bottom_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(half_l_bottom_rect, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 23; {
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);

		tt_op.console_tsl.viewable_lines_from_zero /= 2;
		tt_op.console_tsl.viewable_lines_from_zero -= 1;//subtract 1 since we are going from zero
	}
	case 24; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//Reset manually here to get the right proportion
		text_op.set_bottom_proportion = 0.4;
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);
		tt_op.console_tsl.viewable_lines_from_zero += 1;
		tt_op.console_tsl.viewable_lines_from_zero *= 2;
	}
	case 25; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);
	
		//Test a general resize here increase
		text_op.set_left_proportion = 0.8;
		text_op.set_bottom_proportion = 0.8;
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);

		tt_op.console_tsl.split_lines.count = 11;
		tt_op.console_tsl.viewable_lines_from_zero = 17;
		tt_op.console_tsl.line_char_count = 52;
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);
	}
	case 26; {
		//Reset manually here to get the right proportion
		text_op.set_left_proportion = 0.6;
		text_op.set_bottom_proportion = 0.4;
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);

		tt_op.console_tsl.split_lines.count = 15;
		tt_op.console_tsl.viewable_lines_from_zero = 8;
		tt_op.console_tsl.line_char_count = 39;
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);
	}
	//TODO FROM HERE do some tests for text op selc both directly with function and through console highlights
	//check bounds and edge cases probably and then also add a test below to check with the compiler error
	//we can add them above before settings text op console messages or add them separately after here
	//and make sure that it highlights properly here
	//should we set a black rectangle under the highlighted text for rendering? can maybe see that
	//need to add and extra text and shader order then
	case 27; {
		//test highlighting first line
		th : *TextHighlight = array_add(*text_op.console_highlights);
		th.char_point = 0;
		th.char_count = 5;
		th.highlight_color = MRED_V;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = array_add(*tt_op.console_tsl.split_selcs);
		selc.start_line = 0;
		selc.start_line_char = 0;
		selc.end_line = 0;
		selc.end_line_char = 4;

		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 28; {
		//test highlighting first line bounds before new line
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_point = 0;
		th.char_count = text_op.all_console_lines[0].count;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.start_line = 0;
		selc.start_line_char = 0;
		selc.end_line = 0;
		selc.end_line_char = text_op.all_console_lines[0].count-1;

		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 29; {
		//test highlighting first line bounds on new line
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_point = 0;
		th.char_count = text_op.all_console_lines[0].count+1;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.start_line = 0;
		selc.start_line_char = 0;
		selc.end_line = 0;
		selc.end_line_char = text_op.all_console_lines[0].count-1;

		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 30; {
		//test highlighting first line bounds before new line should be same as on new line
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_point = 19;
		th.char_count = 1;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.start_line = 0;
		selc.start_line_char = 19;
		selc.end_line = 0;
		selc.end_line_char = text_op.all_console_lines[0].count-1;
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);

		//test next char is new line so it should be the same here
		th.char_point = 19;
		th.char_count = 2;
		ResizeTextOpSplitLines(text_op);
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 31; {
		//test go over new line from previous line
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_point = 19;
		th.char_count = 3;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.start_line = 0;
		selc.start_line_char = 19;
		selc.end_line = 1;
		selc.end_line_char = 0;
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 32; {
		//test go over new line from previous line new line char
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_point = 20;
		th.char_count = 3;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.start_line = 1;
		selc.start_line_char = 0;
		selc.end_line = 1;
		selc.end_line_char = 2;
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 33; {
		//test go to end of split line
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_point = 24;
		th.char_count = text_op.console_tsl.line_char_count - (th.char_point - text_op.all_console_lines[0].count - 1);
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.start_line = 1;
		selc.start_line_char = 3;
		selc.end_line = 1;
		selc.end_line_char = text_op.console_tsl.line_char_count-1;
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 34; {
		//test go over split line
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_point = 24;
		th.char_count = text_op.console_tsl.line_char_count - (th.char_point - text_op.all_console_lines[0].count - 1);
		th.char_count += 1;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.start_line = 1;
		selc.start_line_char = 3;
		selc.end_line = 2;
		selc.end_line_char = 0;
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);

		//test go one more char should go one more for both
		th.char_count += 1;
		selc.end_line_char += 1;
		ResizeTextOpSplitLines(text_op);
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 35; {
		//test go over split line and new line
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_point = 24;
		th.char_count = text_op.console_tsl.line_char_count - (th.char_point - text_op.all_console_lines[0].count - 1);
		th.char_count += text_op.console_tsl.split_lines[2].split_string.count;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.start_line = 1;
		selc.start_line_char = 3;
		selc.end_line = 2;
		selc.end_line_char = text_op.console_tsl.split_lines[2].split_string.count-1;
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);

		//test go one more char should not change since we hit a new line
		th.char_count += 1;
		ResizeTextOpSplitLines(text_op);
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 36; {
		//test onew more char should go over next new line
		th : *TextHighlight = *text_op.console_highlights[0];
		th.char_count += 1;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[0];
		selc.end_line += 1;
		selc.end_line_char = 0;
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 37; {
		//test adding another highlight to check
		th : *TextHighlight = array_add(*text_op.console_highlights);
		for 0..4 {
			th.char_point += text_op.console_tsl.split_lines[it].split_string.count;
		}
		th.char_count = 5;
		th.highlight_color = MRED_V;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = array_add(*tt_op.console_tsl.split_selcs);
		selc.start_line = 4;
		selc.start_line_char = 37;
		selc.end_line = 5;
		selc.end_line_char = 2;

		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
	}
	case 38; {
		//test second highlight goes over new line
		th : *TextHighlight = *text_op.console_highlights[1];
		th.char_count += 16;
		ResizeTextOpSplitLines(text_op);

		selc : *StartEndLineChar = *tt_op.console_tsl.split_selcs[1];
		selc.end_line = 6;
		selc.end_line_char = 0;

		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);

		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 39; {
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

missing_semicolon :: #string DONE
main :: () {
	x : int
}
DONE;
		AddTextBlock(missing_semicolon, game_input);		
	}
	case 40; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//test compiling invalid code adds error message to console
		//message should be 2 lines
		//won't test the actual message here since it might change later
		DownUpInputMap(.TEXT_COMPILE, game_input);
		tt_op.console_tsl.cursor_is_selecting = false;
		tt_op.console_tsl.cursor_line_number = 0;
		tt_op.console_tsl.cursor_line_char = 0;
		tt_op.console_tsl.split_lines.count = 6;

		array_reset_keeping_memory(*tt_op.console_tsl.split_selcs);
		selc : *StartEndLineChar = array_add(*tt_op.console_tsl.split_selcs);
		selc.start_line = 4;
		selc.start_line_char = 6;
		selc.end_line = 4;
		selc.end_line_char = 8;
		print("op_space_size=%\n", op_space.world_size);
	}
	case 41; {
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		for 0..2 DownUpThisFrame(.ARROW_LEFT, game_input);
	}
	case 42; {
		AddTextInput(";", game_input);
	}
	case 43; {
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);

		//TEST successfull compilation so message should be only 1 line now
		//won't test the actual message here since it might change later
		DownUpInputMap(.TEXT_COMPILE, game_input);
		tt_op.console_tsl.split_lines.count = 1;
		tt_op.all_console_lines.count = 1;
		array_reset_keeping_memory(*tt_op.console_tsl.split_selcs);
	}
	case 44; {
		AssertSplitSelcs(tt_op.console_tsl.split_selcs, text_op.console_tsl.split_selcs);
		AssertEquals(tt_op.all_console_lines.count, text_op.all_console_lines.count);
		AssertTextSplitLine(tt_op.console_tsl, text_op.console_tsl);
	}
	}
	//TODO FROM HERE highlight the three line cmd in the middle and then test resizing works
	//and with the center line proportions
	//and then do 1 simple compilation do make sure that works to change it
	//and then compile with nothing to make sure we get the other message, 
	//then start on settings
	//TODO Make a test at the end to compile normally and make sure it updates
	//can just make an invalid ; code so we get a compiler error
	//also same with checking the data updates properly when we resize or move the lines in the middle

	ContinueTest(*perm.test_data);

} @ITest