//had to move this in here because the hippie autocomplete in sublime text does not work after around 20000 lines
AssertAsmIndex :: inline (expected : TextOpSpaceData, actual : TextOpSpaceData) {
	AssertEquals(expected.start_disasm_index, actual.start_disasm_index);
	AssertEquals(expected.end_disasm_index, actual.end_disasm_index);
	AssertEquals(expected.highlighted_disasm_index, actual.highlighted_disasm_index);
}
Test_MoveAsmIndex :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	if !perm.test_data.initialized_test {
		perm.test_data.initialized_test = true;
		perm.all_data = InitAllData();
		ResetAllRendererData(renderer_data);
		perm.test_data.spec_data = New(TextTestData);

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	i : int;
	i += 1;
	i -= 1;
	i = 1;






	


	tano(0,0) ~= int.[0,4,7];
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 48+1);
	}

	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	tt_op : *TextOpSpaceData = *tt_data.test_text_op;
	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; DownUpInputMap(.TEXT_BOTTOM_LEFT_PANE, game_input);
	case 4; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);

		//Below 0 should set to 0
		MoveToAsmIndex(-1, text_op);
		AssertEquals(0, text_op.start_disasm_index);
		AssertEquals(8, text_op.end_disasm_index);
		AssertEquals(0, text_op.highlighted_disasm_index);

		//Within bounds should keep bounds same
		MoveToAsmIndex(4, text_op);
		AssertEquals(0, text_op.start_disasm_index);
		AssertEquals(8, text_op.end_disasm_index);
		AssertEquals(4, text_op.highlighted_disasm_index);

		//> end_disasm_index should move bounds
		MoveToAsmIndex(9, text_op);
		AssertEquals(5, text_op.start_disasm_index);
		AssertEquals(13, text_op.end_disasm_index);
		AssertEquals(9, text_op.highlighted_disasm_index);

		//> disassembly_loc should go to disassembly_loc.count-1
		MoveToAsmIndex(20, text_op);
		AssertEquals(text_op.text_comp_data.disassembly_loc.count-5, text_op.start_disasm_index);
		AssertEquals(text_op.text_comp_data.disassembly_loc.count+3, text_op.end_disasm_index);
		AssertEquals(text_op.text_comp_data.disassembly_loc.count-1, text_op.highlighted_disasm_index);

		//< start_disasm_index should move bounds
		MoveToAsmIndex(10, text_op);
		AssertEquals(6, text_op.start_disasm_index);
		AssertEquals(14, text_op.end_disasm_index);
		AssertEquals(10, text_op.highlighted_disasm_index);

		//keep bounds the same
		MoveToAsmIndex(13, text_op);
		AssertEquals(6, text_op.start_disasm_index);
		AssertEquals(14, text_op.end_disasm_index);
		AssertEquals(13, text_op.highlighted_disasm_index);

		tt_op.start_disasm_index = text_op.start_disasm_index;
		tt_op.end_disasm_index = text_op.end_disasm_index;
		tt_op.highlighted_disasm_index = text_op.highlighted_disasm_index+1;
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 5; {
		AssertAsmIndex(tt_op, text_op);

		//TEST move asm index should move bounds down
		DownUpThisFrame(.ARROW_DOWN, game_input);
		tt_op.start_disasm_index += 1;
		tt_op.end_disasm_index += 1;
		tt_op.highlighted_disasm_index += 1;
	}
	case 6; {
		AssertAsmIndex(tt_op, text_op);

		//TEST should move highlighted with bounds since we are on border
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
		tt_op.start_disasm_index -= 1;
		tt_op.end_disasm_index -= 1;
		tt_op.highlighted_disasm_index -= 1;
	}
	case 7; {
		AssertAsmIndex(tt_op, text_op);

		MoveToAsmIndex(text_op.start_disasm_index+1, text_op);
		AssertEquals(text_op.start_disasm_index+1, text_op.highlighted_disasm_index);

		//TEST just move arrow
		DownUpThisFrame(.ARROW_UP, game_input);
		tt_op.highlighted_disasm_index = text_op.start_disasm_index;
	}
	case 8; {
		AssertAsmIndex(tt_op, text_op);

		MoveToAsmIndex(text_op.start_disasm_index+1, text_op);
		AssertEquals(text_op.start_disasm_index+1, text_op.highlighted_disasm_index);

		//TEST should move highlighted with bounds since we are on border
		DownUpThisFrame(.ARROW_DOWN, .{ctrl_pressed=true}, game_input);
		tt_op.start_disasm_index += 1;
		tt_op.end_disasm_index += 1;
		tt_op.highlighted_disasm_index += 1;
	}
	case 9; {
		AssertAsmIndex(tt_op, text_op);

		//TEST should move highlighted with bounds since we are on border
		DownUpThisFrame(.ARROW_DOWN, game_input);
		tt_op.highlighted_disasm_index += 1;
	}
	case 10; {
		AssertAsmIndex(tt_op, text_op);

		//TEST should only move bounds since highlighted is not on edge
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
		tt_op.start_disasm_index -= 1;
		tt_op.end_disasm_index -= 1;
	}
	case 11; {
		AssertAsmIndex(tt_op, text_op);

		//TEST should only move bounds since highlighted is not on edge
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
		tt_op.start_disasm_index -= 1;
		tt_op.end_disasm_index -= 1;
	}
	case 12; {
		AssertAsmIndex(tt_op, text_op);

		//TEST should only move bounds since highlighted is not on edge
		DownUpThisFrame(.ARROW_DOWN, .{ctrl_pressed=true}, game_input);
		tt_op.start_disasm_index += 1;
		tt_op.end_disasm_index += 1;
	}
	case 13; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);

		//TEST should only move bounds since highlighted is not on edge
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 14; {
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);

		//test goto asm negative should set us to 0
		AddTextInput("a-2", game_input);
	}
	case 15; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("a-2", text_op.first_bar_input_text.text_string);

		tt_op.start_disasm_index = 0;
		tt_op.end_disasm_index = 8;
		tt_op.highlighted_disasm_index = 0;
		DownUpThisFrame(.ENTER, game_input);
	}
	case 16; {
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(0, text_op.first_bar_input_text.text_string.count);
		AssertAsmIndex(tt_op, text_op);

		//TEST ctrl down from here should not move since we are at top
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
	}
	case 17; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(0, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		DownUpInputMap(.DEBUG_ASM_GOTO_CODE, game_input);
	}
	case 18; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(1, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		DownUpInputMap(.DEBUG_CODE_GOTO_ASM, game_input);
	}
	case 19; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(1, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		DownUpInputMap(.DEBUG_ASM_GOTO_CODE, game_input);
	}
	case 20; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(1, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 21; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(1, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		AddTextInput("a10", game_input);
	}
	case 22; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("a10", text_op.first_bar_input_text.text_string);
		AssertEquals(1, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		tt_op.highlighted_disasm_index = 10;
		tt_op.start_disasm_index = tt_op.highlighted_disasm_index-4;
		tt_op.end_disasm_index = tt_op.highlighted_disasm_index+4;
		//TEST goto asm line should move asm bounds
		DownUpThisFrame(.ENTER, game_input);
	}
	case 23; {
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(0, text_op.first_bar_input_text.text_string.count);
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(1, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		//TEST move text bounds when we move to line out of text bounds
		DownUpInputMap(.DEBUG_ASM_GOTO_CODE, game_input);
	}
	case 24; {
		AssertAsmIndex(tt_op, text_op);
		line_num : int = 14;
		AssertEquals(line_num, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(line_num-6, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(line_num+6, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST status bar shows asm
		//Actually we cant but we can visually
		DownUpInputMap(.TEXT_SHOW_STATUS_BAR, game_input);
	}
	case 25; {
		//TEST move bounds so we can check moving to code does not move bounds if we are in bounds
		RunSubTestNTimes(5, *perm.test_data);
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);		
	}
	case 26; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(3, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		tt_op.highlighted_disasm_index = 4;
		tt_op.start_disasm_index = 0;
		tt_op.end_disasm_index = 8;
		DownUpInputMap(.DEBUG_CODE_GOTO_ASM, game_input);
	}
	case 27; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(3, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST SHould not move bounds
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
	}
	case 28; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(3, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST arrow up should not change bounds
		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 29; {
		tt_op.highlighted_disasm_index -= 1;

		AssertAsmIndex(tt_op, text_op);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(3, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST moving from asm to code does not move bounds if we are in bounds
		DownUpInputMap(.DEBUG_ASM_GOTO_CODE, game_input);
	}
	case 30; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);

		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 31; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		//TEST go over bounds on bottom and stay on last asm index
		AddTextInput("a20", game_input);
	}
	case 32; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("a20", text_op.first_bar_input_text.text_string);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		tt_op.highlighted_disasm_index = 15;
		tt_op.start_disasm_index = tt_op.highlighted_disasm_index-4;
		tt_op.end_disasm_index = tt_op.highlighted_disasm_index+4;
		//TEST goto asm line should move asm bounds
		DownUpThisFrame(.ENTER, game_input);
	}
	case 33; {
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(0, text_op.first_bar_input_text.text_string.count);
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		//TEST asm bounds should not move since we already at the bottom
		DownUpThisFrame(.ARROW_DOWN, .{ctrl_pressed=true}, game_input);
	}
	case 34; {
		AssertAsmIndex(tt_op, text_op);

		//TEST asm bounds move up but not index
		tt_op.start_disasm_index -= 4;
		tt_op.end_disasm_index -= 4;
	}
	case 35; {
		RunSubTestNTimes(4, *perm.test_data);
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
	}
	case 36; {
		AssertAsmIndex(tt_op, text_op);

		//TEST asm bounds and index move since we are at bottom
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
		tt_op.highlighted_disasm_index -= 1;
		tt_op.start_disasm_index -= 1;
		tt_op.end_disasm_index -= 1;
	}
	case 37; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		//TEST GOTO code line within bounds so it does not move and then goto asm line within asm bounds so it does not move
		DownUpInputMap(.DEBUG_ASM_GOTO_CODE, game_input);
	}
	case 38; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		DownUpThisFrame(.ARROW_DOWN, .{ctrl_pressed=true}, game_input);
	}
	case 39; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(15, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST GOTO code line within bounds so it does not move and then goto asm line within asm bounds so it does not move
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 40; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		AddTextInput("4", game_input);
	}
	case 41; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("4", text_op.first_bar_input_text.text_string);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST goto asm line should move asm bounds
		DownUpThisFrame(.ENTER, game_input);
	}
	case 42; {
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(0, text_op.first_bar_input_text.text_string.count);
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(15, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST goto asm line within asm bounds so it does not move
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 43; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		AddTextInput("14", game_input);
	}
	case 44; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("14", text_op.first_bar_input_text.text_string);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST goto asm line should move asm bounds
		DownUpThisFrame(.ENTER, game_input);
	}
	case 45; {
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(0, text_op.first_bar_input_text.text_string.count);
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(15, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST goto asm line within asm bounds so it does not move
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 46; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);

		//TEST go over bounds on bottom and stay on last asm index
		AddTextInput("a12", game_input);
	}
	case 47; {
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("a12", text_op.first_bar_input_text.text_string);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST goto asm line should not move asm bounds since we are still withing bounds
		tt_op.highlighted_disasm_index = 12;
		DownUpThisFrame(.ENTER, game_input);
	}
	case 48; {
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(0, text_op.first_bar_input_text.text_string.count);
		AssertAsmIndex(tt_op, text_op);
		AssertEquals(14, text_op.file_tabs[text_op.ftab_i].tab_cursor.cursor_line_number);
		AssertEquals(4, text_op.file_tabs[text_op.ftab_i].tab_cursor.start_file_line_index);
		AssertEquals(15, text_op.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index);

		//TEST goto asm line within asm bounds so it does not move
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest