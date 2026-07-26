//TODO FROM HERE test text selection and check up/down arrows on selection and then the undo system and copy/paste before doing mouse input
//TODO Can use this for all text testing if that is a useful way to do it.
/*TODO DOC REMINDER, I Think we can use AssertTextCursor with the new test_cursor now and that would remove
alot of superfluous lines of testing code in here now.
Should do that as a refactor one day. Can likely remove a few thousand lines of code but it might take a day or so
to do the full refactor. Would be worth it if the sublime auto-complete stops at that 20k+ line limit or something.
*/
TextTestData :: struct {
	test_char_point : int;
	test_line_number : int;
	test_line_char : int;

	test_left_char_bound : int;
	test_right_char_bound : int;
	test_start_line_index : int;
	test_end_line_index : int;

	fixed_char_point : int;
	fixed_line_number : int;
	fixed_line_char : int;

	test_cursor : TextCursor;

	test_text_op : TextOpSpaceData;

	test_time : Apollo_Time;
}
WRITE_TEST_FILE_NAME :: "c_test/write_test";
TEST_TEXT :: #string DONE
main :: () {
  tano(0..1,0..2) = int.[0, 16, 123];
  s : Thing;
  s.x_var += 20.01;
}
DONE;

TestAddTextInputBlock :: (text : string, sub_test : *SubTestData, game_input : *GameInput) {
	if sub_test.run_index == 0 {
		//This will get allocated in test_alloc anyways but putting here for explicit clarity.
		sub_test.spec_data = New(int,,test_alloc);
	} 

	s_index := cast(*int) sub_test.spec_data;
	if s_index.* < text.count {
		write_length :: ControllerInput.text_input_buffer.count;
		next_write : string = String.slice(text, s_index.*, write_length);
		AddTextInput(next_write, game_input);
		s_index.* += write_length;
		sub_test.run_count += 1;
	}
}

Test_TextWrite :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	if !perm.test_data.initialized_test {
		perm.test_data.initialized_test = true;

		//TODO Use InitAllData here once we remove this
		perm.all_data = InitAllData();
		ResetAllRendererData(renderer_data);

		SetupMusicAndRows(perm.all_data, TWO_ROWS);

		main_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		/*DOC : We can't open a file in a text op space yet, so we just load it and add it to the tabs here for now.
		TODO - We can open this file in the tab manually once that is possible to do.
		REMINDER - We will write to the loaded file but never save, so it does not get saved on the system.
			This way we can rerun this test as much as we want and reuse the write_test file
		*/
		load_file, load_success := LoadTextFile("c_test/write_test", *perm.all_data.all_text_files);
		if load_success {
			//TODO Should we do this in LoadTextFile?
			// array_add(*perm.all_data.all_text_files, load_file);
		}

		text_op := CreateTextOpSpace(.[main_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 34+1);
	} 

main_string :: #string DONE
#load "c_test/utest";
main :: () {
  x := Foo(0);
}
DONE;
load_string :: #string DONE
Foo :: (x : int) -> int {
  return x + 1;
}
DONE;
	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		sub_test : *SubTestData = *perm.test_data.all_sub_tests[perm.test_data.sub_test_index];
		TestAddTextInputBlock(main_string, sub_test, game_input);
	}
	case 2; DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	case 3; {
		sub_test : *SubTestData = *perm.test_data.all_sub_tests[perm.test_data.sub_test_index];
		TestAddTextInputBlock(load_string, sub_test, game_input);
	}
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(4, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(main_string.count, tab_0.tab_cursor.char_point);

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(3, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(load_string.count, tab_1.tab_cursor.char_point);
		}
	}
	case 5; DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	case 6; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(0, text_op.ftab_i);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(4, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(main_string.count, tab_0.tab_cursor.char_point);

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(3, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(load_string.count, tab_1.tab_cursor.char_point);
		}		
	}
	case 7; {
		RunSubTestNTimes(4, *perm.test_data);
		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 8; DownUpThisFrame(.ARROW_RIGHT, game_input);
	case 9; {
		//TEST That moving the cursor around tests the correct tab cursor
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(0, text_op.ftab_i);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(1, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(1, tab_0.tab_cursor.char_point);

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(3, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(load_string.count, tab_1.tab_cursor.char_point);
		}
	}
	case 10; DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	case 11; {
		//TEST that nothing changes with cursors when we change tabs
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(1, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(1, tab_0.tab_cursor.char_point);
			AssertEquals(0, tab_0.tab_cursor.left_char_bound);
			AssertEquals(64, tab_0.tab_cursor.right_char_bound);


			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(3, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(load_string.count, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(64, tab_1.tab_cursor.right_char_bound);
		}
	}
	case 12; DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	case 13; {
		RunSubTestNTimes(4, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_RIGHT_CHAR_BOUND, game_input);
	}
	case 14; {
		//TEST that right char bound works and that we move that camera for rendering
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(0, text_op.ftab_i);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(1, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(1, tab_0.tab_cursor.char_point);
			AssertEquals(4, tab_0.tab_cursor.left_char_bound);
			AssertEquals(68, tab_0.tab_cursor.right_char_bound);
			cam_x : float = tab_0.tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(3, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(load_string.count, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(64, tab_1.tab_cursor.right_char_bound);
		}
	}
	case 15; DownUpThisFrame(.ARROW_RIGHT, game_input);
	case 16; {
		//TEST moving the cursor adjust the left and right char bounds as well since the cursor is off screen
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(0, text_op.ftab_i);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			AssertEquals(66, tab_0.tab_cursor.right_char_bound);
			cam_x : float = tab_0.tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(3, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(load_string.count, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(64, tab_1.tab_cursor.right_char_bound);
		}
	}
	case 17; DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	case 18; {
		RunSubTestNTimes(3, *perm.test_data);
		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 19; {
		//10 new lines * 3 = 30 new lines
		RunSubTestNTimes(3, *perm.test_data);
		AddTextInput("\n\n\n\n\n\n\n\n\n\n", game_input);
	}
	case 20; {
		//TEST debug toggling pushes text up if it is below the bottom proportion
		op_space : OperationSpace = perm.all_data.all_open_op_spaces[0];
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space.world_size);
			viewable_lines : int = TextViewableLinesFromZero(text_op.text_line_height_factor, text_rect_world_height, 
				perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			AssertEquals(66, tab_0.tab_cursor.right_char_bound);

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(30, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(30, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(64, tab_1.tab_cursor.right_char_bound);
			AssertEquals(30-viewable_lines, tab_1.tab_cursor.start_file_line_index);
			AssertEquals(30, tab_1.tab_cursor.end_file_line_index);
		}

		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	}
	case 21; {
		//TEST debug toggling pushes text up if it is below the bottom proportion
		op_space : OperationSpace = perm.all_data.all_open_op_spaces[0];
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertFloatEquals(text_op.set_bottom_proportion, text_op.bottom_proportion);
		AssertFloatEquals(text_op.set_bottom_proportion, text_op.r_bottom_height_proportion);
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space.world_size);
			viewable_lines : int = TextViewableLinesFromZero(text_op.text_line_height_factor, text_rect_world_height, 
				perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			//Note : We check if this reduced only since we don't really use right_char bound for now 
			//so I don't want the test to be too stringent.
			AssertEquals(true, tab_0.tab_cursor.right_char_bound < 66);
			AssertEquals(0, tab_0.tab_cursor.start_file_line_index);
			AssertEquals(viewable_lines, tab_0.tab_cursor.end_file_line_index);

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(30, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(30, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(true , tab_1.tab_cursor.right_char_bound < 64);
			AssertEquals(9, tab_1.tab_cursor.start_file_line_index);
			AssertEquals(9+viewable_lines, tab_1.tab_cursor.end_file_line_index);
		}
	}
	case 22; DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	case 23; {
		//TEST tab left with debug mode works
		op_space : OperationSpace = perm.all_data.all_open_op_spaces[0];
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertFloatEquals(text_op.set_bottom_proportion, text_op.bottom_proportion);
		AssertFloatEquals(text_op.set_bottom_proportion, text_op.r_bottom_height_proportion);
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(0, text_op.ftab_i);

			text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space.world_size);
			viewable_lines : int = TextViewableLinesFromZero(text_op.text_line_height_factor, text_rect_world_height, 
				perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			//Note : We check if this reduced only since we don't really use right_char bound for now 
			//so I don't want the test to be too stringent.
			AssertEquals(true, tab_0.tab_cursor.right_char_bound < 66);
			AssertEquals(0, tab_0.tab_cursor.start_file_line_index);
			AssertEquals(viewable_lines, tab_0.tab_cursor.end_file_line_index);

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(30, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(30, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(true , tab_1.tab_cursor.right_char_bound < 64);
			AssertEquals(9, tab_1.tab_cursor.start_file_line_index);
			AssertEquals(9+viewable_lines, tab_1.tab_cursor.end_file_line_index);
		}
	}
	case 24; DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	case 25; DownUpInputMap(.TEXT_DISASM_TOGGLE, game_input);
	case 26; {
		//TEST console toggling pushes text back down
		op_space : OperationSpace = perm.all_data.all_open_op_spaces[0];
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertFloatEquals(0, text_op.bottom_proportion);
		AssertFloatEquals(text_op.set_bottom_proportion, text_op.r_bottom_height_proportion);
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space.world_size);
			viewable_lines : int = TextViewableLinesFromZero(text_op.text_line_height_factor, text_rect_world_height, 
				perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			//Note : We check if this reduced only since we don't really use right_char bound for now 
			//so I don't want the test to be too stringent.
			AssertEquals(true, tab_0.tab_cursor.right_char_bound < 66);
			AssertEquals(0, tab_0.tab_cursor.start_file_line_index);
			AssertEquals(viewable_lines, tab_0.tab_cursor.end_file_line_index);

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(30, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(30, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(true, tab_1.tab_cursor.right_char_bound < 64);
			AssertEquals(9, tab_1.tab_cursor.start_file_line_index);
			AssertEquals(tab_1.tab_cursor.start_file_line_index+viewable_lines, tab_1.tab_cursor.end_file_line_index);
			//TODO This is the old test in case we decide to put it back the way it was before
			// AssertEquals(tab_1.tab_cursor.cursor_line_number-viewable_lines, tab_1.tab_cursor.start_file_line_index);
			// AssertEquals(tab_1.tab_cursor.cursor_line_number, tab_1.tab_cursor.end_file_line_index);
		}
	}
	case 27; {
		RunSubTestNTimes(30, *perm.test_data);
		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 28; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 29; {
		RunSubTestNTimes(30, *perm.test_data);
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 30; {
		//TEST proper bounds after untoggling everything
		op_space : OperationSpace = perm.all_data.all_open_op_spaces[0];
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertFloatEquals(0, text_op.bottom_proportion);
		AssertFloatEquals(0, text_op.r_bottom_height_proportion);
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space.world_size);
			viewable_lines : int = TextViewableLinesFromZero(text_op.text_line_height_factor, text_rect_world_height, 
				perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			//Note : We check if this reduced only since we don't really use right_char bound for now 
			//so I don't want the test to be too stringent.
			AssertEquals(66, tab_0.tab_cursor.right_char_bound);
			AssertEquals(0, tab_0.tab_cursor.start_file_line_index);
			AssertEquals(viewable_lines, tab_0.tab_cursor.end_file_line_index);
			cam_x : float = tab_0.tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(30, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(30, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(64 , tab_1.tab_cursor.right_char_bound);
			AssertEquals(30-viewable_lines, tab_1.tab_cursor.start_file_line_index);
			AssertEquals(30, tab_1.tab_cursor.end_file_line_index);
		}
	}
	case 31; {
		//TEST simple resize text space test
		//TODO We should do more extensive test with mouse input and also could have a terminal event to resize
		//and then we make it into a function as well hmmm...
		op_space : *OperationSpace = *perm.all_data.all_open_op_spaces[0];
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];

		//TODO This can likely be a function so we can reuse in the game as well so we can adjust op space sizes
		//both with the mouse and with terminal events / other possibilities
		resize_rect_world : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size);
		resize_rect_world.min.y -= 3;
		resize_rect_world.max.x += 2;
		op_space.world_offset = GetCenter(resize_rect_world);
		op_space.world_size = GetDim(resize_rect_world);
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);

		AssertFloatEquals(0, text_op.bottom_proportion);
		AssertFloatEquals(0, text_op.r_bottom_height_proportion);
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space.world_size);
			viewable_lines : int = TextViewableLinesFromZero(text_op.text_line_height_factor, text_rect_world_height, 
				perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			//Note : We check if this reduced only since we don't really use right_char bound for now 
			//so I don't want the test to be too stringent.
			// AssertEquals(69, tab_0.tab_cursor.right_char_bound);
			AssertEquals(true, tab_0.tab_cursor.right_char_bound > 66);
			AssertEquals(0, tab_0.tab_cursor.start_file_line_index);
			AssertEquals(viewable_lines, tab_0.tab_cursor.end_file_line_index);
			cam_x : float = tab_0.tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(30, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(30, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(true, tab_1.tab_cursor.right_char_bound > 64);
			AssertEquals(32-viewable_lines, tab_1.tab_cursor.start_file_line_index);
			AssertEquals(32, tab_1.tab_cursor.end_file_line_index);
		}

		//TODO I am going to leave this here as this I think I prefer this way of testing but maybe
		//we can do it somewhere else as well.
		//BUT it cannot work until we have mouse position for mac as well so it can be one thing we test
		//for both to start off with.
		//ALSO We would need to add mouse button events which we still have with the old windows only way right now.
		#if 0 {
		resize_rect_world : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size);
		op_bottom_right : Vector2F = GetBottomRight(resize_rect_world);
		//TODO Can likely set this somewhere so we can get it more easily. Maybe a function that creates it
		//both here and where the actual input is processed.
		rect_bottom_right : Rectangle2 = RectBottomRightDim(op_bottom_right, Vector2F.{0.75,0.75});
		default_base_cam : Camera2D = GetRenderMSpace(perm.all_data).mspace_cam;
		rect_world_pos : Vector2F = GetCenter(rect_bottom_right);
		SetMouseWorldPos(rect_world_pos, default_base_cam, op_space.render_groups.scissor_group);

	   // MouseP : POINT;
	   // GetCursorPos(*MouseP);
	   // ScreenToClient(Window, *MouseP);
	   // new_input.MouseX = MouseP.x;
	   // new_input.MouseY = screen_height - MouseP.y;

		// game_input.MouseX = cast(s32) mouse_pos.x;
		// game_input.MouseY = cast(s32) mouse_pos.y;
		// game_input.MouseX += cast(s32) 5;
		// game_input.MouseY += cast(s32) 5;

		// game_input.MouseY = renderer_data.base_render_group.window_height - cast(s32) mouse_pos.y;
      // Win32ProcessMouse(Window, *new_input, *old_input, renderer_data.base_render_group.window_height);
		// SetCursorPos(cast(s32) mouse_pos.x, 
		// 	cast(s32) mouse_pos.y);
		// 	renderer_data.base_render_group.window_height - cast(s32) mouse_pos.y);
			// renderer_data.base_render_group.window_height - cast(s32) mouse_pos.y);
		}
	}
	case 32; {
		//TEST simple resize text space test
		//TODO We should do more extensive test with mouse input and also could have a terminal event to resize
		//and then we make it into a function as well hmmm...
		op_space : *OperationSpace = *perm.all_data.all_open_op_spaces[0];
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];

		//TODO This can likely be a function so we can reuse in the game as well so we can adjust op space sizes
		//both with the mouse and with terminal events / other possibilities
		resize_rect_world : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size);
		resize_rect_world.min.y += 3;
		resize_rect_world.max.x -= 2;
		op_space.world_offset = GetCenter(resize_rect_world);
		op_space.world_size = GetDim(resize_rect_world);
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);

		AssertFloatEquals(0, text_op.bottom_proportion);
		AssertFloatEquals(0, text_op.r_bottom_height_proportion);
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space.world_size);
			viewable_lines : int = TextViewableLinesFromZero(text_op.text_line_height_factor, text_rect_world_height, 
				perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			//Note : We check if this reduced only since we don't really use right_char bound for now 
			//so I don't want the test to be too stringent.
			AssertEquals(66, tab_0.tab_cursor.right_char_bound);
			AssertEquals(0, tab_0.tab_cursor.start_file_line_index);
			AssertEquals(viewable_lines, tab_0.tab_cursor.end_file_line_index);
			cam_x : float = tab_0.tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(30, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(30, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(64 , tab_1.tab_cursor.right_char_bound);
			AssertEquals(30-viewable_lines, tab_1.tab_cursor.start_file_line_index);
			AssertEquals(30, tab_1.tab_cursor.end_file_line_index);
		}
	}
	case 33; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 34; {
		//TEST Check that moving cursor also moves camera after resizing where cursor is no longer visible
		op_space : OperationSpace = perm.all_data.all_open_op_spaces[0];
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];

		AssertFloatEquals(0, text_op.bottom_proportion);
		AssertFloatEquals(0, text_op.r_bottom_height_proportion);
		AssertEquals(2, perm.all_data.all_text_files.count);
		count_equals := AssertEquals(2, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.ftab_i);

			text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space.world_size);
			viewable_lines : int = TextViewableLinesFromZero(text_op.text_line_height_factor, text_rect_world_height, 
				perm.text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);

			file_0 := perm.all_data.all_text_files[0];
			tab_0 : TextTab = text_op.file_tabs[0];
			AssertEquals(file_0.id, tab_0.text_file_id);
			AssertEquals(0, tab_0.tab_cursor.cursor_line_number);
			AssertEquals(2, tab_0.tab_cursor.cursor_line_char);
			AssertEquals(2, tab_0.tab_cursor.char_point);
			AssertEquals(2, tab_0.tab_cursor.left_char_bound);
			AssertEquals(66, tab_0.tab_cursor.right_char_bound);
			AssertEquals(0, tab_0.tab_cursor.start_file_line_index);
			AssertEquals(viewable_lines, tab_0.tab_cursor.end_file_line_index);
			cam_x : float = tab_0.tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;

			file_1 := perm.all_data.all_text_files[1];
			tab_1 : TextTab = text_op.file_tabs[1];
			AssertEquals(file_1.id, tab_1.text_file_id);
			AssertEquals(31, tab_1.tab_cursor.cursor_line_number);
			AssertEquals(0, tab_1.tab_cursor.cursor_line_char);
			AssertEquals(56, tab_1.tab_cursor.char_point);
			AssertEquals(0, tab_1.tab_cursor.left_char_bound);
			AssertEquals(64 , tab_1.tab_cursor.right_char_bound);
			AssertEquals(31-viewable_lines, tab_1.tab_cursor.start_file_line_index);
			AssertEquals(31, tab_1.tab_cursor.end_file_line_index);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TextCtrlMove :: (
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
		array_resize(*perm.test_data.all_sub_tests, 50);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	/*DOC : First we go over the file with ctrl+left testing the boundaries cases.
	Then we go back over the file ctrl+right testing the boundary cases.
	Boundary cases include ending or starting the file with "\n", "   " (multi-space or tab) and "text"
	*/
	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);
	}
	cursor : TextCursor;
	if perm.all_data.all_text_op_space_data.count > 0 {
		cursor = perm.all_data.all_text_op_space_data[0].file_tabs[0].tab_cursor;
	}
	tf_string : string;
	if perm.all_data.all_text_files.count > 0 {
		tf_string = perm.all_data.all_text_files[0].file_string.text_string;
	}
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		AddTextBlock(TEST_TEXT, game_input);
		//Note : We can't seem to add this ourselves at the end of TEST_TEXT, so we
		//add two spaces at the end to make sure we skip over them and don't make the file wierd.
		AddTextInput("  ", game_input);
	}
	case 2; {
		//Test that we are at the end of the file and that we added the text.
		//We added to spaces to make sure we don't go over end of file with spaces as well
		AssertEquals(TEST_TEXT.count+2, cursor.char_point);
		AssertEquals(5, cursor.cursor_line_number);

		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
	}
	case 3; {
		//Test that we did not move at the end of a file by pressing ctrl+right
		AssertEquals(TEST_TEXT.count, cursor.char_point);
		AssertEquals(5, cursor.cursor_line_number);

		//Test 2 arrow rights to make sure we don't go over the end of the text file string
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
	}
	case 4; {
		//We added to spaces to make sure we don't go over end of file with spaces as well
		AssertEquals(TEST_TEXT.count+2, cursor.char_point);
		AssertEquals(5, cursor.cursor_line_number);

		//Test remove spaces and then go right to make sure that works too and we don't go over end
		DownUpThisFrame(.BACKSPACE, game_input);
		DownUpThisFrame(.BACKSPACE, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
	}
	case 5; {
		AssertEquals(TEST_TEXT.count, cursor.char_point);
		AssertEquals(5, cursor.cursor_line_number);

		AddTextInput("endtext", game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
	}
	case 6; {
		//Test that we skip over the endtext and then don't go over end of file when we have text
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
	}
	case 7; {
		//7 = size of "endtext"
		AssertEquals(TEST_TEXT.count+7, cursor.char_point);
		AssertEquals(5, cursor.cursor_line_number);

		//Remove endtext
		for 0..6 DownUpThisFrame(.BACKSPACE, game_input);
	}
	case 8; {
		AssertEquals(TEST_TEXT.count, cursor.char_point);
		AssertEquals(5, cursor.cursor_line_number);		

		//Test that we only skip over new line
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
	}
	case 9; {
		AssertEquals(TEST_TEXT.count-1, cursor.char_point);
		AssertEquals(4, cursor.cursor_line_number);

		//Test that we don't go over file end on a new line
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = TEST_TEXT.count;
		tt_data.test_line_number = 5;
	}
	case 10; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we gove back a line and go over the close brace }
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //"}\n"
		tt_data.test_line_number -= 1; 
	}
	case 11; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we move back a line and go over the 01; and stop at the .
		//We always skip over 1 char and then alphanum if the next char back is alphanum
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 4; //"01;\n"
		tt_data.test_line_number -= 1; 
	}
	case 12; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over 20. and stop at the space
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 3; //"20."
	}
	case 13; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "+= " and stop at the space
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 3; //"+= "
	}
	case 14; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "x_var " and stop at the "."
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 6; //"x_var "
	}
	case 15; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "s." and stop at the space
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //"s."
	}
	case 16; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "  " and stop at the "\n"
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //"  "
	}
	case 17; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(#char " ", tf_string[cursor.char_point]);

		//Test that we go over "\n" only
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 1; //"\n"
		tt_data.test_line_number -= 1;
		tt_data.test_line_char = 12;
	}
	case 18; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);

		//Test that we go over "Thing;" and stop at the " "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 6; //"Thing;"
		tt_data.test_line_char -= 6; //"Thing;"
	}
	case 19; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "T", tf_string[cursor.char_point]);

		//Test that we go over ": " and stop at the " "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //": "
		tt_data.test_line_char -= 2; //": "
	}
	case 20; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char ":", tf_string[cursor.char_point]);

		//Test that we go over "s " and stop at the " "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //"s "
		tt_data.test_line_char -= 2; //"s "
	}
	case 21; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "s", tf_string[cursor.char_point]);

		//Test that we go over "  " and then "\n"
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 3; //"\n  "
		tt_data.test_line_number -= 1;
	}
	case 22; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "];" and stop at "123"
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //"\];"
	}
	case 23; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "123" and stop at " "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 3; //"123"
	}
	case 24; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "16, " since we skip over space first and then one char and then alphanum and stop at " "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 4; //"16, "
	}
	case 25; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "0, " since we skip over space first and then one char and then alphanum and stop at " "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 3; //"0, "
	}
	case 26; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over ".["
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //".["
	}
	case 27; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "int"
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 3; //"int"
	}
	case 28; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "= "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //"= "
	}
	case 29; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "2) " go over spaces and then 1 char and then alphanum and stop at ".."
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 3; //"2) "
	}
	case 30; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over ".." go over all non_alphanum till we hit alphanum
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //".."
	}
	case 31; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "0"
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		//Test that we go over "1,"
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		//Test that we go over ".."
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		//Test that we go over "0"
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 6;
	}
	case 32; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "tano("
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 5; //"tano("
	}
	case 33; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "  "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		//Test that we go over "\n" go over all non_alphanum till we hit alphanum
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		//Test that we go over "{"
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 4; //"{\n  "
		tt_data.test_line_number -= 1;
	}
	case 34; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "() "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		//Test that we go over ":: "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 6; //":: ()  "
	}
	case 35; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "main "
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 5; //"main  "
	}
	case 36; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "  " and then stay at 0
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
	}
	case 37; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);

		//Test that we go over "  " and then stay at 0 and then remove the space and try and go left
		DownUpThisFrame(.SPACEBAR, game_input);
		DownUpThisFrame(.SPACEBAR, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0; //"  "
	}
	case 38; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(#char "m", tf_string[cursor.char_point]);

		//Test that we go over "  " and then stay at 0 and then remove the space
		DownUpThisFrame(.ENTER, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
	}
	case 39; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);

		//Test that we stay in same place with a \n
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
	}
	case 40; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);

		//Test go over "\n"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 1; //"\n"
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 41; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);

		//Remove "\n" and then test go over "main" from start
		DownUpThisFrame(.BACKSPACE, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 4; //"main" from start
		tt_data.test_line_char = 4;
		tt_data.test_line_number = 0;
	}
	case 42; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);

		//Test go over " ::"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 3; //" ::"
		tt_data.test_line_char += 3;
	}
	case 43; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);

		//Test go over " ()"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 3; //" ()"
		tt_data.test_line_char += 3;
	}
	case 44; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);

		//Test go over " {" and then "\n"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 3; //" {\n"
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 45; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);

		//Test go over "  tano"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		//Test go over "(0"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		//Test go over ".."
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 10; //"  tano(0.."
		tt_data.test_line_char += 10;
	}
	case 46; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "1", tf_string[cursor.char_point]);

		//Test go down to "+="
		DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.ARROW_DOWN, game_input);
		tt_data.test_line_number += 2;
		//TODO If we have an issue here just check the char point of the "+=" and then set it to that
		tt_data.test_char_point = 74;
	}
	case 47; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "+", tf_string[cursor.char_point]);

		//Test go over "+="
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		//Test go over " 20"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		//Test go over ".01"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		//Test go over ";"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		//Test go over "\n"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 10;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 48; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "}", tf_string[cursor.char_point]);

		//Test go over "}"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		//Test go over "\n"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 2;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 49; {
		AssertEquals(TEST_TEXT.count, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TextSelect :: (
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
		array_resize(*perm.test_data.all_sub_tests, 58);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	/*DOC : Move around space with selections with arrows and home and end.
	Also ctrl+l is used and then also left and right and up and down arrow during selection.
	Left and right should go to fixed or cursor depending on position and 
	up and down currently moves up a line from top of selection and down from bottom respectively.
	not sure if i like that better than just moving cursor from where it is, but that is how every other editor does it.
	*/
	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);
	}
	cursor : TextCursor;
	if perm.all_data.all_text_op_space_data.count > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data[0].file_tabs.count);
		if perm.all_data.all_text_op_space_data[0].file_tabs.count > 0 {
			cursor = perm.all_data.all_text_op_space_data[0].file_tabs[0].tab_cursor;
		}
	}
	tf_string : string;
	if perm.all_data.all_text_files.count > 0 {
		tf_string = perm.all_data.all_text_files[0].file_string.text_string;
	}
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		AddTextBlock(TEST_TEXT, game_input);
	}
	case 2; {
		for 0..4 DownUpThisFrame(.ARROW_UP, game_input);

		//Test left boundary presses do nothing
		DownUpThisFrame(.ARROW_LEFT, .{shift_pressed=true}, game_input);		
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
	}
	case 3; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);

		//Test highlight over "m"
		DownUpThisFrame(.ARROW_RIGHT, .{shift_pressed=true}, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 4; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "a", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(0, cursor.fixed_select_char_point);
		AssertEquals(0, cursor.fixed_select_line_number);
		AssertEquals(0, cursor.fixed_select_line_char);

		//Test highlight over main
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		tt_data.test_char_point += 3;
		tt_data.test_line_char += 3;
	}
	case 5; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(0, cursor.fixed_select_char_point);
		AssertEquals(0, cursor.fixed_select_line_number);
		AssertEquals(0, cursor.fixed_select_line_char);

		//Test unhighlight main
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
	}
	case 6; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);


		//Test highlight to end of line
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 12;
		tt_data.test_line_char = 12;
	}
	case 7; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(0, cursor.fixed_select_char_point);
		AssertEquals(0, cursor.fixed_select_line_number);
		AssertEquals(0, cursor.fixed_select_line_char);


		//Test unhighlight to start of line
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
	}
	case 8; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test go to end of line so we can highlight backwards
		DownUpThisFrame(.END, game_input);
		tt_data.test_char_point = 12;
		tt_data.test_line_char = 12;
	}
	case 9; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);


		//Test highlight to start of line
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
	}
	case 10; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(12, cursor.fixed_select_char_point);
		AssertEquals(0, cursor.fixed_select_line_number);
		AssertEquals(12, cursor.fixed_select_line_char);


		//Test unhighlight to end of line
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 12;
		tt_data.test_line_char = 12;
	}
	case 11; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test start boundary with home
		DownUpThisFrame(.HOME, game_input);
		DownUpThisFrame(.HOME, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;		
	}
	case 12; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test end line with 2 ends
		DownUpThisFrame(.END, game_input);
		DownUpThisFrame(.END, game_input);
		tt_data.test_char_point = 12;
		tt_data.test_line_char = 12;		
	}
	case 13; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);


		DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.HOME, game_input);
		tt_data.test_char_point = 15;
		tt_data.test_line_char = 2;
		tt_data.test_line_number = 1;
	}
	case 14; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "t", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);


		//Test select not from start of line "tano"
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.test_char_point += 4; //"tano"
		tt_data.test_line_char += 4;		
	}
	case 15; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "(", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);


		//TODO Test that when char_point > fixed on selection, then arrow left brings us to the fixed point
		DownUpThisFrame(.ARROW_LEFT, game_input);
		tt_data.test_char_point = tt_data.fixed_char_point;
		tt_data.test_line_char = tt_data.fixed_line_char;
	}
	case 16; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "t", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		DownUpThisFrame(.ARROW_RIGHT, .{shift_pressed=true, ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.test_char_point += 4;
		tt_data.test_line_char += 4;
	}
	case 17; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "(", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);


		//Test that when char_point > fixed on selection, then arrow right does not move cursor but undoes selection
		DownUpThisFrame(.ARROW_RIGHT, game_input);
	}
	case 18; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "(", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);


		//Test ctrl+L shortcut without any selection
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 13;
		tt_data.fixed_line_number = 1;
		tt_data.fixed_line_char = 0;
		tt_data.test_char_point = 51;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 19; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test move arrow key up on selection with char_point > fixed which moves arrow above fixed by 1 line and unselects
		DownUpThisFrame(.ARROW_UP, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = tt_data.fixed_line_number - 1;
	}
	case 20; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test ctrl+l and then arrow down should go one line below
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_DOWN, game_input);
		tt_data.test_char_point = 51;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 2;
	}
	case 21; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test select with .END which should select to end of line (move arrow down to "s : Thing;" line)
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point += 12;
		tt_data.test_line_char += 12;
	}
	case 22; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test .END after select which should unselect and remain at end of line
		DownUpThisFrame(.END, game_input);
	}
	case 23; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test .END without selection at end of line which remain at same point
		DownUpThisFrame(.END, game_input);
	}
	case 24; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test .END with smaller selection
		DownUpThisFrame(.ARROW_LEFT, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{shift_pressed=true,ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point - 1;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.fixed_line_char = tt_data.test_line_char - 1;
		tt_data.test_char_point -= 6;
		tt_data.test_line_char -= 6;
	}
	case 25; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "T", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test .END with shift pressed during smaller selection (should hold fixed point and go to end of line)
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = tt_data.fixed_char_point + 1;
		tt_data.test_line_char = tt_data.fixed_line_char + 1;
	}
	case 26; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test home with shift pressed during smaller selection (should hold fixed point and go to start of line)
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 53;
		tt_data.test_line_char = 2;
	}
	case 27; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "s", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test home with smaller selection (should go to beggining line since we were already at beginning of chars from previous home)
		DownUpThisFrame(.HOME, game_input);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
	}
	case 28; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test home with smaller selection (should go back to beggining of line chars)
		DownUpThisFrame(.HOME, game_input);
		tt_data.test_char_point += 2;
		tt_data.test_line_char += 2;
	}
	case 29; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "s", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test home with smaller selection (should go back to beggining of line before chars)
		DownUpThisFrame(.HOME, game_input);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
	}
	case 30; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test ctrl+L a few times till end of file
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point += 13;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 3;
	}
	case 31; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test ctrl+L a few times till end of file
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 20;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
	}
	case 32; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "}", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test ctrl+L a few times till end of file
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 2;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 5;
	}
	case 33; {
		AssertEquals(tf_string.count, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test ctrl+L at end of file so it should not change
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
	}
	case 34; {
		AssertEquals(tf_string.count, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test arrow right at end of file so it unselect and not change cursor
		DownUpThisFrame(.ARROW_RIGHT, game_input);
	}
	case 35; {
		AssertEquals(tf_string.count, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test ctrl+l and then arrow right next frame to make sure we unselect as well
		DownUpThisFrame(.ARROW_UP, game_input);
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 84;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 4;
	}
	case 36; {
		AssertEquals(tf_string.count, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test ctrl arrow right end of file does not change cursor and unselects
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
	}
	case 37; {
		AssertEquals(tf_string.count, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test move arrow up and then start selecting around making sure it does not change
		for 0..2 DownUpThisFrame(.ARROW_UP, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 17;
		tt_data.test_line_char = 4;
		tt_data.test_line_number = 1;
		tt_data.fixed_char_point = 55;
		tt_data.fixed_line_char = 4;
		tt_data.fixed_line_number = 2;
	}
	case 38; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "n", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test move arrow up and then start selecting around making sure it does not change
		DownUpThisFrame(.ARROW_LEFT, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 3;
		tt_data.test_line_char -= 1;
		tt_data.test_line_number -= 1;
	}
	case 39; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "n", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test move shift arrow left after selection
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
	}
	case 40; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test ctrl arrow left at start and we don't move and unselect
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
	}
	case 41; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test move arrow up and then start selecting around making sure it does not change
		for 0..1 DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		tt_data.test_char_point = 55;
		tt_data.test_line_char = 4;
		tt_data.test_line_number = 2;
	}
	case 42; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char ":", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test move around but select does not change
		DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point = 50;
		tt_data.test_line_char = 37;
		tt_data.test_line_number = 1;
	}
	case 43; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "\n", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test move around but select does not change
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 15;
		tt_data.test_line_char = 2;
		tt_data.test_line_number = 1;
	}
	case 44; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "t", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test move around but select does not change
		DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{shift_pressed=true,ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 45; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test arrow_left at start of file does not change cursor and unselects
		DownUpThisFrame(.ARROW_LEFT, game_input);
	}
	case 46; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test select from bottom up and then ctrl+l to make sure cursor goes below fixed select
		DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		tt_data.fixed_char_point = 13;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 1;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 47; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "m", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test select from bottom up and then ctrl+l to make sure cursor goes below fixed select
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point = 51;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 2;
	}
	case 48; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test select from bottom up and then ctrl+l to make sure cursor goes below fixed select
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 17;
		tt_data.test_line_char = 4;
		tt_data.test_line_number = 1;
		tt_data.fixed_char_point = 55;
		tt_data.fixed_line_char = 4;
		tt_data.fixed_line_number = 2;
	}
	case 49; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "n", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test select from bottom up and then ctrl+l to make sure cursor goes below fixed select
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 13;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 1;
		tt_data.test_char_point = 64;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 3;
	}
	case 50; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test arrow down after selection with cursor < fixed moves cursor down 1 line
		DownUpThisFrame(.ARROW_DOWN, game_input);
		tt_data.test_char_point = 84;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 51; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "}", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test select from bottom up and arrow up to make sure cursor goes up
		for 0..1 DownUpThisFrame(.ARROW_UP, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = 17;
		tt_data.test_line_char = 4;
		tt_data.test_line_number = 1;
		tt_data.fixed_char_point = 55;
		tt_data.fixed_line_char = 4;
		tt_data.fixed_line_number = 2;
	}
	case 52; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char "n", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test select from bottom up and arrow up to make sure cursor goes up
		DownUpThisFrame(.ARROW_UP, game_input);
		tt_data.test_char_point = 4;
		tt_data.test_line_char = 4;
		tt_data.test_line_number -= 1;
	}
	case 53; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test select cursor > fixed and then right arrow should just unselect
		DownUpThisFrame(.HOME, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true,shift_pressed=true}, game_input);
		tt_data.test_char_point = 4;
		tt_data.test_line_char = 4;
		tt_data.test_line_number = 0;
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
	}
	case 54; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test select and then right arrow should just unselect
		DownUpThisFrame(.ARROW_RIGHT, game_input);
	}
	case 55; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test select left cursor < fixed and then right left should just unselect
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true,shift_pressed=true}, game_input);
		tt_data.test_char_point = 5;
		tt_data.test_line_char = 5;
		tt_data.test_line_number = 0;
		tt_data.fixed_char_point = 7;
		tt_data.fixed_line_char = 7;
		tt_data.fixed_line_number = 0;
	}
	case 56; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char ":", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		//Test select and then right arrow should just unselect
		DownUpThisFrame(.ARROW_LEFT, game_input);
	}
	case 57; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char ":", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test select and then right arrow should just unselect
		// DownUpThisFrame(.ARROW_LEFT, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TextCopyPaste :: (
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
		array_resize(*perm.test_data.all_sub_tests, 20);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	/*DOC : Copy paste with some selections AND 
	copy withou selection which should copy the entire line
	*/
	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);
	}
	cursor : TextCursor;
	if perm.all_data.all_text_op_space_data.count > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data[0].file_tabs.count);
		if perm.all_data.all_text_op_space_data[0].file_tabs.count > 0 {
			cursor = perm.all_data.all_text_op_space_data[0].file_tabs[0].tab_cursor;
		}
	}
	tf_string : string;
	if perm.all_data.all_text_files.count > 0 {
		tf_string = perm.all_data.all_text_files[0].file_string.text_string;
	}
	first_line :: "main :: () {\n";
	cut_text :: "  s.x_var += 20.01;\n}\n";
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		AddTextBlock(TEST_TEXT, game_input);
	}
	case 2; {
		//Go to start of file
		for 0..4 DownUpThisFrame(.ARROW_UP, game_input);

		//Test left boundary presses do nothing
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		tt_data.test_char_point = 4;
		tt_data.test_line_char = 4;
	}	
	case 3; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 4; {
		cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals("main", cb_text);		

		//Test left copy without selection (arrow_right undoes selection and should not move cursor)
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = 13;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 1;
	}
	case 5; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals(first_line, cb_text);

		//Test start of line and paste main line below
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += first_line.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 6; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		add_size : int = first_line.count;
		line_0 := string.{add_size, tf_string.data};
		line_1 := string.{add_size, tf_string.data+add_size};
		AssertEquals(line_0, line_1);

		AssertEquals(TEST_TEXT.count+add_size, tf_string.count);

		//Test cut removes text with selection (should not move cursor)
		DownUpThisFrame(.ARROW_UP, game_input);
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "X", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= first_line.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number -= 1;
	}
	case 7; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals(first_line, cb_text);

		AssertEquals(TEST_TEXT.count, tf_string.count);

		//Test cut and paste
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += first_line.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 8; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		add_size : int = first_line.count;
		line_0 := string.{add_size, tf_string.data};
		line_1 := string.{add_size, tf_string.data+add_size};
		AssertEquals(line_0, line_1);

		//Set back to original text (should move down a line from paste)
		DownUpThisFrame(.ARROW_UP, game_input);
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "X", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= first_line.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number -= 1;
	}
	case 9; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(#char " ", tf_string[cursor.char_point]);
		AssertEquals(false, cursor.cursor_is_selecting);

		AssertEquals(TEST_TEXT, tf_string);

		//Test multi-line copy paste (starting at "  s.x_var...")
		for 0..1 DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 64;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 3;
		tt_data.test_char_point = 86;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 5;
	}
	case 10; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals(cut_text, cb_text);
		AssertEquals(TEST_TEXT.count, tf_string.count);

		//Test multi-line copy paste 
		//we are selecting so pasting should remove the selection and copy back what was there and so nothing should change
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
	}
	case 11; {
		AssertEquals(TEST_TEXT.count, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

		AssertEquals(TEST_TEXT.count, tf_string.count);

		//Test multi-line copy paste at end of file
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += cut_text.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 7;
	}
	case 12; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

	   sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TEST_TEXT);
	   append(*sb, cut_text);
	   text_with_paste : string = builder_to_string(*sb);
		AssertEquals(text_with_paste, tf_string);

		//Test cut line from end of line
		DownUpThisFrame(.ARROW_UP, game_input);
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "X", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2; //"}\n"
		tt_data.test_line_char = 0;
		tt_data.test_line_number -= 1;
	}
	case 13; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

	   sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TEST_TEXT);
	   append(*sb, cut_text);
	   text_with_paste : string = builder_to_string(*sb);
	   text_with_paste.count -= 2; //since we remove "}\n"
		AssertEquals(text_with_paste, tf_string);

	   cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals("}\n", cb_text);

		//Test cut line from end of line
		DownUpThisFrame(.ARROW_UP, game_input);
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "X", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 86; //remove 2 since we already remove "}\n"
		tt_data.test_line_char = 0;
		tt_data.test_line_number -= 1;
	}
	case 14; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

		AssertEquals(TEST_TEXT, tf_string);

		cut_text_minus_2 := cut_text;
		cut_text_minus_2.count -= 2;
	   cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals(cut_text_minus_2, cb_text);

		//Test cut line from middle of line and putting it back
		for 0..2 DownUpThisFrame(.ARROW_UP, game_input);
		for 0..2 DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true,shift_pressed=true}, game_input);
		DownUpThisFrame(#char "X", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 57;
		tt_data.test_line_char = 6; 
		tt_data.test_line_number = 2;
	}
	case 15; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

		cut_Thing :: "Thing";
		cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals(cut_Thing, cb_text);
		AssertEquals(TEST_TEXT.count-cut_Thing.count, tf_string.count);

		//Test cut line from end of file which should do nothing since theres nothing on that line
		//We also should not copy anything since there was nothing on that line
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += cut_Thing.count;
		tt_data.test_line_char += cut_Thing.count; 
	}
	case 16; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

		//Test cut the file out out with a few cuts
		for 0..1 DownUpThisFrame(.ARROW_UP, game_input);
		for 0..4 DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = TEST_TEXT.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 5;
	}
	case 17; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);

		AssertEquals(TEST_TEXT, tf_string);

		//Cut the whole file
		DownUpThisFrame(#char "X", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 18; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

		AssertEquals("", tf_string);

		//Make sure we copied last line properly
	   cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals(TEST_TEXT, cb_text);

		//TODO We could undo the above change here if we want to test other copy-paste functionality
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = TEST_TEXT.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 5;
	}
	case 19; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);

		AssertEquals(TEST_TEXT, tf_string);

		//Make sure we copied last line properly
	   cb_text : string = os_clipboard_get_text(,,temp);
		AssertEquals(TEST_TEXT, cb_text);

		//TODO We could undo the above change here if we want to test other copy-paste functionality
		// DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TextUndo :: (
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
		array_resize(*perm.test_data.all_sub_tests, 109);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	/*DOC : Copy paste with some selections AND 
	copy withou selection which should copy the entire line
	*/
	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);
	}
	cursor : TextCursor;
	if perm.all_data.all_text_op_space_data.count > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data[0].file_tabs.count);
		if perm.all_data.all_text_op_space_data[0].file_tabs.count > 0 {
			cursor = perm.all_data.all_text_op_space_data[0].file_tabs[0].tab_cursor;
		}
	}
	text_fs : *FileString;
	tf_string : string;
	if perm.all_data.all_text_files.count > 0 {
		text_fs = *perm.all_data.all_text_files[0].file_string;
		tf_string = perm.all_data.all_text_files[0].file_string.text_string;
	}
	first_line  :: "main :: () {";
	second_line :: "\n x : int = 5;";
	// third_line  :: "\n Foo(x);";
	third_line :: "\n}";
	split_line :: "\ny :    float;";
	enter_count : int = 22;
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		//We reduce the text_action_history for the test so we can make sure that 
		//the circle buffer is working properly. It is stored in test_alloc so it does not change anything
		//since it will be cleared at the end of the 
		text_fs.text_action_history.count = 3;

		//TODO FROM HERE add undo/redo tests and see if adding undo till space feels better or not
		//We could just write text here line by line and save lines in this functions 
		//and test undo/redo as we go instead of copying the whole block and then remove text after and undo redo
		//also test at boundaries and make sure cursor_char != fixed_char ever.
		AddTextInput(first_line, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 2; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[0].action_type);
		AssertEquals(0, text_fs.text_action_history[0].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[0].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[0].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[0].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[0].undo_chars.count, text_fs.text_action_history[0].undo_chars.data};
		AssertEquals(first_line, undo_string);

		//Test undo of first line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}	
	case 3; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);


		//Test redo of first line
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 4; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		//Test redo of first line
		AddTextInput(second_line, game_input);
		tt_data.test_char_point += second_line.count;
		tt_data.test_line_char = second_line.count-1;//-1 to remove the "\n"
		tt_data.test_line_number += 1;
	}
	case 5; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[1].action_type);
		AssertEquals(first_line.count, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(second_line, undo_string);

		//Test undo of second line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 6; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//Test redo of second line
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += second_line.count;
		tt_data.test_line_char = second_line.count-1;//-1 to remove the "\n"
		tt_data.test_line_number += 1;
	}
	case 7; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		//Test redo of third line
		AddTextInput(third_line, game_input);
		tt_data.test_char_point += third_line.count;
		tt_data.test_line_char = third_line.count-1;//-1 to remove the "\n"
		tt_data.test_line_number += 1;
	}
	case 8; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[2].action_type);
		AssertEquals(first_line.count+second_line.count, text_fs.text_action_history[2].cursor_before_action.char_point);
		AssertEquals(1, text_fs.text_action_history[2].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[2].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[2].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[2].undo_chars.count, text_fs.text_action_history[2].undo_chars.data};
		AssertEquals(third_line, undo_string);

		//Test undo of third line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= third_line.count;
		tt_data.test_line_char = second_line.count-1;//-1 to remove the "\n"
		tt_data.test_line_number -= 1;
	}
	case 9; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

	   sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//Test undo of second line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= second_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number -= 1;
	}
	case 10; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//Test undo of first line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= first_line.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 11; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//Test redo of first line
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 12; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//Test redo of second line
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += second_line.count;
		tt_data.test_line_char = second_line.count-1;//-1 to remove the "\n"
		tt_data.test_line_number += 1;
	}
	case 13; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//Test redo of third line
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += third_line.count;
		tt_data.test_line_char = third_line.count-1;//-1 to remove the "\n"
		tt_data.test_line_number += 1;
	}
	case 14; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   all_text : string = builder_to_string(*sb);
		AssertEquals(all_text, tf_string);

		//Test undo twitch and then backspace to make sure buffer lengths change
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;//-1 to remove the "\n"
		tt_data.test_line_number = 0;
	}
	case 15; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		//Test undo and then backspace so we can see that it changes the total_buffer_length
		DownUpThisFrame(.BACKSPACE, game_input);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
	}
	case 16; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);
		AssertEquals(TextActionType.REMOVE_TEXT_LEFT, text_fs.text_action_history[1].action_type);
		AssertEquals(first_line.count, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals("{", undo_string);

		first_line_minus_bracket := first_line;
		first_line_minus_bracket.count -= 1;
		AssertEquals(first_line_minus_bracket, tf_string);

		//Test redo does nothing since we added an action after an undo
		DownUpThisFrame(#char "Y", game_input);
	}
	case 17; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);
		first_line_minus_bracket := first_line;
		first_line_minus_bracket.count -= 1;
		AssertEquals(first_line_minus_bracket, tf_string);

		//Test undo puts back bracket
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 18; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//Test undo still remove first line afterwards
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
	}
	case 19; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//Test undo does nothing since we have no undos left
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
	}
	case 20; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//Test redo
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
	}
	case 21; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//Test redo
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
	}
	case 22; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		first_line_minus_bracket := first_line;
		first_line_minus_bracket.count -= 1;
		AssertEquals(first_line_minus_bracket, tf_string);

		//Test redo does nothing since we have no more redos
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
	}
	case 23; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		first_line_minus_bracket := first_line;
		first_line_minus_bracket.count -= 1;
		AssertEquals(first_line_minus_bracket, tf_string);

		//Test add bracket and lines back so we overlap undo buffer
		AddTextInput("{", game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 24; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		AddTextInput(second_line, game_input);
		tt_data.test_char_point += second_line.count;
		tt_data.test_line_char = second_line.count-1;//-1 to remove the "\n"
		tt_data.test_line_number += 1;
	}
	case 25; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST Undo 3 times now until we reach first line since we no longer have the undo first line
		//first undo undoes second line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= second_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number -= 1;
	}
	case 26; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST Undo 3 times now until we reach first line since we no longer have the undo first line
		//second undo undoes "{"
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
	}
	case 27; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		first_line_minus_bracket := first_line;
		first_line_minus_bracket.count -= 1;
		AssertEquals(first_line_minus_bracket, tf_string);

		//TEST Undo 3 times now until we reach first line since we no longer have the undo first line
		//third undo adds "{" back
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 28; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST Undo 3 times now until we reach first line since we no longer have the undo first line
		//try undoing again but nothing should happen since we have no undos left
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
	}
	case 29; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST delete entire first line and then undo should put the whole line back
		//and we should have no other undos as well since we undid previous ones already
		DownUpThisFrame(.HOME, game_input);
		for 0..first_line.count-1 DownUpThisFrame(.DELETE, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 30; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.REMOVE_TEXT_RIGHT, text_fs.text_action_history[1].action_type);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(first_line, undo_string);

		AssertEquals("", tf_string);

		//TEST undo delete line should be 1 undo (cursor does not move since we were deleting and not backspacing)
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
	}
	case 31; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo delete line should be 1 redo (cursor does not move because it is a delete right-remove action)
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
	}
	case 32; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo delete line and then go to end of line to backspace
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.END, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 33; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo delete line should be 1 undo
		for 0..first_line.count-1 DownUpThisFrame(.BACKSPACE, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 34; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo backspace line should be 1 undo
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 35; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo backspace line should be 1 redo
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 36; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo and then select line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		tt_data.fixed_char_point = first_line.count;
		tt_data.fixed_line_char = first_line.count;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 37; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST backspace remove selected text from right
		DownUpThisFrame(.BACKSPACE, game_input);
	}
	case 38; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.REMOVE_TEXT_RIGHT, text_fs.text_action_history[1].action_type);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(first_line, undo_string);


		AssertEquals("", tf_string);

		//TEST undo backspace selected line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = first_line.count;
		tt_data.fixed_line_char = first_line.count;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 39; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo backspace selected line
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
	}
	case 40; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo backspace selected line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = first_line.count;
		tt_data.fixed_line_char = first_line.count;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 41; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST delete remove selected text from right
		DownUpThisFrame(.DELETE, game_input);
	}
	case 42; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.REMOVE_TEXT_RIGHT, text_fs.text_action_history[1].action_type);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(first_line, undo_string);


		AssertEquals("", tf_string);

		//TEST undo delete selected line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = first_line.count;
		tt_data.fixed_line_char = first_line.count;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 43; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo delete selected line
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
	}
	case 44; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo delete selected line
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = first_line.count;
		tt_data.fixed_line_char = first_line.count;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 45; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST undo delete selection with remove text left
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 46; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST undo delete selection with remove text left
		DownUpThisFrame(.DELETE, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 47; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.REMOVE_TEXT_LEFT, text_fs.text_action_history[1].action_type);
		AssertEquals(first_line.count, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(first_line, undo_string);

		AssertEquals("", tf_string);

		//TEST undo delete selection remove text left
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 48; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo delete selection remove text left
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 49; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo delete selection remove text left
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 50; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST undo backspace selection with remove text left
		DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 51; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST undo backspace selection with remove text left
		DownUpThisFrame(.BACKSPACE, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 52; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.REMOVE_TEXT_LEFT, text_fs.text_action_history[1].action_type);
		AssertEquals(first_line.count, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(first_line, undo_string);

		AssertEquals("", tf_string);

		//TEST undo backspace selection remove text left
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 53; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo backspace selection remove text left
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 54; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo backspace selection remove text left
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 55; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST undo cutremove text left
		DownUpThisFrame(#char "X", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 56; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.REMOVE_TEXT_LEFT, text_fs.text_action_history[1].action_type);
		AssertEquals(first_line.count, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(first_line, undo_string);

		AssertEquals("", tf_string);

		//TEST undo cut selection remove text left
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 57; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo cut selection remove text left
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 58; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo cut selection remove text left
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 59; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST undo cut and paste remove text right
		DownUpThisFrame(.END, game_input);
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		tt_data.fixed_char_point = first_line.count;
		tt_data.fixed_line_char = first_line.count;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 60; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST undo cut and paste remove text right (cursor does not change on remove text right)
		DownUpThisFrame(#char "X", .{ctrl_pressed=true}, game_input);
	}
	case 61; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.REMOVE_TEXT_RIGHT, text_fs.text_action_history[1].action_type);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(first_line, undo_string);

		AssertEquals("", tf_string);

		//TEST undo cut and paste
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 62; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[2].action_type);
		AssertEquals(0, text_fs.text_action_history[2].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[2].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[2].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[2].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[2].undo_chars.count, text_fs.text_action_history[2].undo_chars.data};
		AssertEquals(first_line, undo_string);

		AssertEquals(first_line, tf_string);

		//TEST undo paste
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 63; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo cut
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = first_line.count;
		tt_data.fixed_line_char = first_line.count;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 64; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST undo text block
		DownUpThisFrame(.END, game_input);
		AddTextBlock(second_line, game_input);
		tt_data.test_char_point = first_line.count + second_line.count;
		tt_data.test_line_char = second_line.count-1; //-1 to remove \n
		tt_data.test_line_number = 1;
	}
	case 65; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[1].action_type);
		AssertEquals(first_line.count, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(second_line, undo_string);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST undo text block
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= second_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 66; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo text block
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += second_line.count;
		tt_data.test_line_char = second_line.count-1;//-1 to remove \n
		tt_data.test_line_number = 1;
	}
	case 67; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(1, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST do shift enter between lines to test undo after
		DownUpThisFrame(.ARROW_UP, game_input);
		DownUpThisFrame(.ENTER, .{shift_pressed=true}, game_input);
		tt_data.test_char_point -= second_line.count;
		tt_data.test_char_point += 1;//+1 for \n from shift+enter
		tt_data.test_line_char = 0;
	}
	case 68; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[2].action_type);
		AssertEquals(first_line.count, text_fs.text_action_history[2].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[2].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[2].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[2].after_action_cursor.cursor_line_number);
		undo_string := string.{text_fs.text_action_history[2].undo_chars.count, text_fs.text_action_history[2].undo_chars.data};
		AssertEquals("\n", undo_string);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, "\n");
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST undo shift+enter
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char = first_line.count;//-1 to remove \n
		tt_data.test_line_number -= 1;
	}
	case 69; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST redo shift+enter
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 70; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, "\n");
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST undo shift+enter again
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;//-1 to remove "\n"
		tt_data.test_line_number = 0;
	}
	case 71; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST undo second_line to make sure undo order is still good
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count;
		tt_data.test_line_char = first_line.count;
		tt_data.test_line_number = 0;
	}
	case 72; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		AssertEquals(first_line, tf_string);

		//TEST redo second line and 
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += second_line.count;
		tt_data.test_line_char = second_line.count-1;//-1 to remove "\n"
		tt_data.test_line_number += 1;
	}
	case 73; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST add third line and then do a full text copy paste to check undo redo of copy paste
		AddTextInput(third_line, game_input);
		tt_data.test_char_point += third_line.count;
		tt_data.test_line_char = third_line.count-1;//-1 to remove "\n"
		tt_data.test_line_number += 1;
	}
	case 74; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST add third line and then do a full text copy paste to check undo redo of copy paste
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		for 0..2 DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 75; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST test undo copy paste with char_point < fixed
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 76; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST test paste should do nothing since we are pasting what we copied in the same place but cursor should move
		//and we should also have another undo action added
		//test also paste removes the selection which it does
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char = third_line.count-1;
		tt_data.test_line_number = 2;
	}
	case 77; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);
		//remove text for paste
		AssertEquals(TextActionType.REMOVE_TEXT_RIGHT, text_fs.text_action_history[0].action_type);
		AssertEquals(0, text_fs.text_action_history[0].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[0].cursor_before_action.cursor_line_number);
		AssertEquals(true, text_fs.text_action_history[0].cursor_before_action.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, text_fs.text_action_history[0].cursor_before_action.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_number, text_fs.text_action_history[0].cursor_before_action.fixed_select_line_number);
		AssertEquals(false, text_fs.text_action_history[0].after_action_cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.text_action_history[0].after_action_cursor.char_point);
		AssertEquals(0, text_fs.text_action_history[0].after_action_cursor.cursor_line_number);
		//add text for paste
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[1].action_type);
		AssertEquals(false, text_fs.text_action_history[1].cursor_before_action.cursor_is_selecting);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(0, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(false, text_fs.text_action_history[1].after_action_cursor.cursor_is_selecting);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);
		undo_string_remove := string.{text_fs.text_action_history[0].undo_chars.count, text_fs.text_action_history[0].undo_chars.data};
		AssertEquals(three_lines, undo_string_remove);
		undo_string_add := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(three_lines, undo_string_add);


		//TEST undo paste add text with cursor before action
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 78; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST undo paste remove text with cursor before action
		//test cursor is selected again because cursor goes before action which was highlighted text we copy pasted
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = first_line.count + second_line.count + third_line.count;
		tt_data.fixed_line_char = third_line.count-1;
		tt_data.fixed_line_number = 2;
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 79; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);		
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST undo third line to makes sure that works
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count + second_line.count;
		tt_data.test_line_char = second_line.count-1;
		tt_data.test_line_number = 1;
	}
	case 80; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   two_lines : string = builder_to_string(*sb);
		AssertEquals(two_lines, tf_string);

		//TEST redo third line
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += third_line.count;
		tt_data.test_line_char = third_line.count-1;// -1 to remove "\n"
		tt_data.test_line_number += 1;
	}
	case 81; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST redo remove text with cursor after action
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 82; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals("", tf_string);

		//TEST redo add text with cursor after action which is different from the undo before since 
		//we don't have a selection now but we had it before since cursor after adding text from paste is not selected
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char = third_line.count-1;
		tt_data.test_line_number = 2;
	}
	case 83; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST we highlight now with char_point > fixed since we did char_point < fixed before
		//cursor is at same point as before (end of file) and fixed is at start now
		//we also copy here so we can add it after and check
		DownUpThisFrame(.HOME, game_input);
		for 0..2 DownUpThisFrame(.ARROW_UP, game_input);
		for 0..2 DownUpThisFrame(#char "L", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char = third_line.count-1;
		tt_data.test_line_number = 2;
	}
	case 84; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);		
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST copy with char point > fixed
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char = third_line.count-1;
		tt_data.test_line_number = 2;
	}
	case 85; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(true, cursor.cursor_is_selecting);
		AssertEquals(tt_data.fixed_char_point, cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, cursor.fixed_select_line_number);		
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0, cursor.start_file_line_index);
		AssertEquals(21, cursor.end_file_line_index);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);
		cb_text : string = os_clipboard_get_text();
		AssertEquals(three_lines, cb_text);

		//TEST go down so we go off the op_space screen and make sure that copy and undo copy moves the 
		//multiple enters should be 1 undo and then undoing the paste should be one undo
		//and the end and start line index should go back to the top and that is good for undo system tests
		DownUpThisFrame(.ARROW_DOWN, game_input);
		for 1..enter_count DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point += enter_count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += enter_count;
	}
	case 86; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0+3, cursor.start_file_line_index);
		AssertEquals(21+3, cursor.end_file_line_index);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   for 1..enter_count append(*sb, "\n");
	   three_lines_with_enters : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_enters, tf_string);

		//TEST go down so we go off the op_space screen and make sure that copy and undo copy moves the 
		//multiple enters should be 1 undo and then undoing the paste should be one undo
		//and the end and start line index should go back to the top and that is good for undo system tests
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char = third_line.count-1;//-1 to remove \n
		tt_data.test_line_number += 2;
	}
	case 87; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0+5, cursor.start_file_line_index);
		AssertEquals(21+5, cursor.end_file_line_index);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   for 1..enter_count append(*sb, "\n");
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines_with_enters_and_paste : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_enters_and_paste, tf_string);

		//TEST go down so we go off the op_space screen and make sure that copy and undo copy moves the 
		//multiple enters should be 1 undo and then undoing the paste should be one undo
		//and the end and start line index should go back to the top and that is good for undo system tests
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number -= 2;
	}
	case 88; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0+3, cursor.start_file_line_index);
		AssertEquals(21+3, cursor.end_file_line_index);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   for 1..enter_count append(*sb, "\n");
	   three_lines_with_enters : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_enters, tf_string);

		//TEST go down so we go off the op_space screen and make sure that copy and undo copy moves the 
		//multiple enters should be 1 undo and then undoing the paste should be one undo
		//and the end and start line index should go back to the top and that is good for undo system tests
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= enter_count;
		tt_data.test_line_char = third_line.count-1;
		tt_data.test_line_number -= enter_count;//-1 since we start from 0
	}
	case 89; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0, cursor.start_file_line_index);
		AssertEquals(21, cursor.end_file_line_index);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST go down so we go off the op_space screen and make sure that copy and undo copy moves the 
		//multiple enters should be 1 undo and then undoing the paste should be one undo
		//and the end and start line index should go back to the top and that is good for undo system tests
		//ALSO Make sure undoing twice does not go back anymore here
		//undo the 3 lines to make sure we still have the last action which was copying the 3 lines
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 90; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0, cursor.start_file_line_index);
		AssertEquals(21, cursor.end_file_line_index);

		AssertEquals("", tf_string);

		//TEST go down so we go off the op_space screen and make sure that copy and undo copy moves the 
		//multiple enters should be 1 undo and then undoing the paste should be one undo
		//and the end and start line index should go back to the top and that is good for undo system tests
		//redo first 3 lines
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char = third_line.count-1;
		tt_data.test_line_number = 2;
	}
	case 91; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0, cursor.start_file_line_index);
		AssertEquals(21, cursor.end_file_line_index);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TEST go down so we go off the op_space screen and make sure that copy and undo copy moves the 
		//multiple enters should be 1 undo and then undoing the paste should be one undo
		//and the end and start line index should go back to the top and that is good for undo system tests
		//redo enters
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += enter_count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += enter_count;
	}
	case 92; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0+3, cursor.start_file_line_index);
		AssertEquals(21+3, cursor.end_file_line_index);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   for 1..enter_count append(*sb, "\n");
	   three_lines_with_enter : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_enter, tf_string);

		//TEST go down so we go off the op_space screen and make sure that copy and undo copy moves the 
		//multiple enters should be 1 undo and then undoing the paste should be one undo
		//and the end and start line index should go back to the top and that is good for undo system tests
		//do 2 redos to make sure we don't go past. this imitates human usage when overpressing redo shortcut
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char += third_line.count-1;//-1 to remove "\n"
		tt_data.test_line_number += 2;
	}
	case 93; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(0+5, cursor.start_file_line_index);
		AssertEquals(21+5, cursor.end_file_line_index);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   for 1..enter_count append(*sb, "\n");
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines_with_enter : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_enter, tf_string);

		//test 2 undos till we just have 3 lines again to test shift+enter
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count + second_line.count + third_line.count;
		tt_data.test_line_char = third_line.count-1;//-1 to remove "\n"
		tt_data.test_line_number = 2;
	}
	case 94; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//test undo shift enter
		DownUpThisFrame(.ARROW_UP, game_input);
		for 0..1 DownUpThisFrame(.ARROW_RIGHT, game_input);
		DownUpThisFrame(.ENTER, .{shift_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count + second_line.count + 1;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 2;
	}
	case 95; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, third_line);
	   three_lines_with_enter : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_enter, tf_string);

		//test undo shift enter should be at end of line we shift+entered from
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = first_line.count + second_line.count;
		tt_data.test_line_char = second_line.count-1;
		tt_data.test_line_number = 1;
	}
	case 96; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//test redo a shift+enter
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 97; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(2, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, third_line);
	   three_lines : string = builder_to_string(*sb);
		AssertEquals(three_lines, tf_string);

		//TODO WE COULD SEPARATE THIS TEST OUT to test for more undo_split_string if needed
		//but I think "\n" or " \n" or " \n\t\r" is likely enough for most people
		//test add some text with undo_split = " \n" and the undo and redo to make sure it's working
		//the first "\n" should get added to the undo "\n" char
		perm.text_editor_data.undo_split_chars[0] = " ";
		perm.text_editor_data.undo_split_chars[1] = "\n";
		perm.text_editor_data.undo_split_string = string.{2, perm.text_editor_data.undo_split_chars.data};
		text_fs.text_undo_split = string.{2, perm.text_editor_data.undo_split_chars.data};
		AddTextInput(split_line, game_input);
		tt_data.test_char_point += split_line.count;
		tt_data.test_line_char = split_line.count-1;
		tt_data.test_line_number += 1;
	}
	case 98; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		//TODO We actually test these below anyways with the actual undo test so we can remove them if needed later.
		//It is somewhat superfluous but we check the cursors here to make sure anyways.
		//we added 2 new undos here and the last undo is added as "\ny"
		//undo "    float;"
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[1].action_type);
		AssertEquals(tt_data.test_char_point-10, text_fs.text_action_history[1].cursor_before_action.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[1].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[1].after_action_cursor.cursor_line_number);
		undo_1 := string.{text_fs.text_action_history[1].undo_chars.count, text_fs.text_action_history[1].undo_chars.data};
		AssertEquals(string.{10, split_line.data+4}, undo_1);
		//undo " :"
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[0].action_type);
		AssertEquals(tt_data.test_char_point-12, text_fs.text_action_history[0].cursor_before_action.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[0].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point-10, text_fs.text_action_history[0].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[0].after_action_cursor.cursor_line_number);
		undo_0 := string.{text_fs.text_action_history[0].undo_chars.count, text_fs.text_action_history[0].undo_chars.data};
		AssertEquals(string.{2, split_line.data+2}, undo_0);
		//undo "\n\ny"
		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[2].action_type);
		AssertEquals(tt_data.test_char_point-split_line.count-1, text_fs.text_action_history[2].cursor_before_action.char_point);
		AssertEquals(tt_data.test_line_number-2, text_fs.text_action_history[2].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point-split_line.count+2, text_fs.text_action_history[2].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[2].after_action_cursor.cursor_line_number);
		undo_2 := string.{text_fs.text_action_history[2].undo_chars.count, text_fs.text_action_history[2].undo_chars.data};
		AssertEquals("\n\ny", undo_2);



		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, split_line);
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test undo now with undo_split = " \n" so we should remove from multiple spaces or multiple "\n"
		//undo the "    float;" which is 10 chars
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 10;
		tt_data.test_line_char -= 10;
	}
	case 99; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, string.{split_line.count-10, split_line.data});
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test undo now with undo_split = " \n" so we should remove from multiple spaces or multiple "\n"
		//undo the " :" which is 2 chars
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
	}
	case 100; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, string.{split_line.count-12, split_line.data});
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test undo now with undo_split = " \n" so we should remove from multiple spaces or multiple "\n"
		//undo the "\n\ny" which is 3 chars and 2 lines
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 3;
		tt_data.test_line_char = second_line.count-1;
		tt_data.test_line_number -= 2;
	}
	case 101; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(0, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test undo now with undo_split = " \n" so we should remove from multiple spaces or multiple "\n"
		//redo "\n\ny"
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 3;
		tt_data.test_line_char = 1;
		tt_data.test_line_number += 2;
	}
	case 102; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(1, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, string.{split_line.count-12, split_line.data});
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test undo now with undo_split = " \n" so we should remove from multiple spaces or multiple "\n"
		//redo the " :" which is 3 chars
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 2;
		tt_data.test_line_char += 2;
	}
	case 103; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(1, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, string.{split_line.count-10, split_line.data});
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test undo now with undo_split = " \n" so we should remove from multiple spaces or multiple "\n"
		//redo the "    float;" which is 10 chars
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 10;
		tt_data.test_line_char += 10;
	}
	case 104; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, split_line);
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test add "\n" to make sure a single "\n" still works with undo_split " \n"
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 105; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[2].action_type);
		AssertEquals(tt_data.test_char_point-1, text_fs.text_action_history[2].cursor_before_action.char_point);
		AssertEquals(tt_data.test_line_number-1, text_fs.text_action_history[2].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[2].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[2].after_action_cursor.cursor_line_number);
		undo_1 := string.{text_fs.text_action_history[2].undo_chars.count, text_fs.text_action_history[2].undo_chars.data};
		AssertEquals("\n", undo_1);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, split_line);
	   append(*sb, "\n");
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test add another "\n" to make sure double "\n" works as well with undo_split " \n"
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 106; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		AssertEquals(TextActionType.ADD_TEXT, text_fs.text_action_history[2].action_type);
		AssertEquals(tt_data.test_char_point-2, text_fs.text_action_history[2].cursor_before_action.char_point);
		AssertEquals(tt_data.test_line_number-2, text_fs.text_action_history[2].cursor_before_action.cursor_line_number);
		AssertEquals(tt_data.test_char_point, text_fs.text_action_history[2].after_action_cursor.char_point);
		AssertEquals(tt_data.test_line_number, text_fs.text_action_history[2].after_action_cursor.cursor_line_number);
		undo_1 := string.{text_fs.text_action_history[2].undo_chars.count, text_fs.text_action_history[2].undo_chars.data};
		AssertEquals("\n\n", undo_1);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, split_line);
	   append(*sb, "\n");
	   append(*sb, "\n");
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test add "\n" to make sure a single "\n" still works with undo_split " \n"
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char = split_line.count-1;
		tt_data.test_line_number -= 2;
	}
	case 107; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(2, text_fs.action_write_index);
		AssertEquals(2, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, split_line);
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//test redo "\n" to make sure a single "\n" still works with undo_split " \n"
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 2;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 2;
	}
	case 108; {
		AssertEquals(tt_data.test_char_point, cursor.char_point);
		AssertEquals(tt_data.test_line_number, cursor.cursor_line_number);
		AssertEquals(tt_data.test_line_char, cursor.cursor_line_char);
		AssertEquals(false, cursor.cursor_is_selecting);
		AssertEquals(0, text_fs.action_write_index);
		AssertEquals(3, text_fs.undo_buffer_length);
		AssertEquals(3, text_fs.total_buffer_length);

		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, first_line);
	   append(*sb, second_line);
	   append(*sb, "\n");
	   append(*sb, split_line);
	   append(*sb, "\n");
	   append(*sb, "\n");
	   append(*sb, third_line);
	   three_lines_with_split_line : string = builder_to_string(*sb);
		AssertEquals(three_lines_with_split_line, tf_string);

		//reset this back now to default for later use
		//TODO Should likely have this in the text op space data eventually say it can be set for each op space
		SetupTextEditorData(*perm.text_editor_data, renderer_data.*);

		//test redo "\n" to make sure a single "\n" still works with undo_split " \n"
		// DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		// tt_data.test_char_point -= 2;
		// tt_data.test_line_char = split_line.count-1;
		// tt_data.test_line_number -= 2;
	}
	}
	//TODO If we need to add more undo tests, it's likely best to split them out into a new test function

	ContinueTest(*perm.test_data);

} @ITest

SOME_TEXT_LINE :: "some text\n";
TAB_LINE :: "\twith tab\n";
TAB2_LINE :: "\twith\ttab\t";
Test_TextMouse :: (
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
		array_resize(*perm.test_data.all_sub_tests, 150+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);
	}
	text_op : *TextOpSpaceData;
	tab_cursor : TextCursor;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];

		AssertEquals(1, perm.all_data.all_text_op_space_data[0].file_tabs.count);
		if perm.all_data.all_text_op_space_data[0].file_tabs.count > 0 {
			tab_cursor = perm.all_data.all_text_op_space_data[0].file_tabs[0].tab_cursor;
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

	//TODO FROM HERE write a bunch of tests here for all this and then cleanup rendering code
	//could also check updating font size before or after tests to make sure it looks ok and with mouse
	//for font width and height
	//TODO FROM HERE Might be worth testing some of the functions with unit tests separately
	//if they are precise like the mouse scrolling and things like that or pressing breakpoints
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		AddTextInput(SOME_TEXT_LINE, game_input);
	}
	case 2; {
		AssertEquals(SOME_TEXT_LINE.count, tab_cursor.char_point);
		AssertEquals(1, tab_cursor.cursor_line_number);

		//TEST set the the cursor at the beginning of the file with the mouse
		loc_start_pos := Vector2F.{text_op.ator.LOC_START_X, text_op.ator.LOC_START_Y};
		game_input.mouse_cam = OpSpaceToCameraSpace(loc_start_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		//TODO FROM HERE set AddDownUpKeyboard function and then make this default with the false
		//We can write a few small tests but maybe just do the tabs and then add tests as we go along now.
		//So maybe start writing tests each time we add something new now and maybe just a few larger
		//tests for main test cases for all the new text op mouse and keyboard input before terminal and then find/line bar.
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 3; {
		AssertEquals(0, tab_cursor.char_point);
		AssertEquals(0, tab_cursor.cursor_line_number);
		AssertEquals(0, tab_cursor.cursor_line_char);

		//TEST that selecting text with mouse works
		line_0_end_pos := Vector2F.{
			text_op.ator.LOC_START_X + (SOME_TEXT_LINE.count-1) * perm.text_editor_data.code_font_1_char_width_world, 
			text_op.ator.LOC_START_Y
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_0_end_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 4; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(SOME_TEXT_LINE.count-1, tab_cursor.char_point);
		AssertEquals(SOME_TEXT_LINE.count-1, tab_cursor.cursor_line_char);
		AssertEquals(0, tab_cursor.cursor_line_number);
		AssertEquals(0, tab_cursor.fixed_select_char_point);
		AssertEquals(0, tab_cursor.fixed_select_line_number);
		AssertEquals(0, tab_cursor.fixed_select_line_char);


		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 5; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(SOME_TEXT_LINE.count-1, tab_cursor.char_point);
		AssertEquals(SOME_TEXT_LINE.count-1, tab_cursor.cursor_line_char);
		AssertEquals(0, tab_cursor.cursor_line_number);
		AssertEquals(0, tab_cursor.fixed_select_char_point);
		AssertEquals(0, tab_cursor.fixed_select_line_number);
		AssertEquals(0, tab_cursor.fixed_select_line_char);

		//Test copy paste with mouse
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 6; {
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X, 
			text_op.ator.LOC_START_Y - text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 7; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);		
		AssertEquals(SOME_TEXT_LINE.count, tab_cursor.char_point);
		AssertEquals(0, tab_cursor.cursor_line_char);
		AssertEquals(1, tab_cursor.cursor_line_number);

		//Test copy paste with mouse
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count-1;
		tt_data.test_line_char = SOME_TEXT_LINE.count-1;
		tt_data.test_line_number = 1;
	}
	case 8; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		//TEST Press mouse a few lines down and off the text to the right so it should not change
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + (SOME_TEXT_LINE.count+1)*perm.text_editor_data.code_font_1_char_width_world, 
			text_op.ator.LOC_START_Y - 5*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 9; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);


		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 10; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		//Test mouse with tab
		AddTextInput(TAB_LINE, game_input);	
		tt_data.test_char_point += TAB_LINE.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 11; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		//TEST Press mouse should be on left hand side of tab
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + (0.4*TAB_CHAR_COUNT)*perm.text_editor_data.code_font_1_char_width_world, 
			text_op.ator.LOC_START_Y - 2*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 2;
	}
	case 12; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);


		//TEST Press mouse should be on right hand side of tab since tab is 2 characters by default
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + (0.6*TAB_CHAR_COUNT)*perm.text_editor_data.code_font_1_char_width_world, 
			text_op.ator.LOC_START_Y - 2*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 13; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);


		//TEST highlight line with tab to make sure its working
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X, 
			text_op.ator.LOC_START_Y - 2*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 2;
	}
	case 14; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		//We already have the tab as 1 char in the line, so we remove 1
		mouse_char_count : int = TAB_LINE.count + TAB_CHAR_COUNT-1;
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + mouse_char_count * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 2*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count + TAB_LINE.count-1;
		tt_data.test_line_char = TAB_LINE.count-1;
		tt_data.test_line_number = 2;
	}
	case 15; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 16; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		//Test copy paste tab with mouse
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 17; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);


		//move mouse down 1 line from before
		mouse_char_count : int = TAB_LINE.count + TAB_CHAR_COUNT-1;
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - 3*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count + TAB_LINE.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
	}
	case 18; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		//Test paste tab with mouse
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count + 2*TAB_LINE.count-1;
		tt_data.test_line_char = TAB_LINE.count-1;
	}
	case 19; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		//Test mouse with 3 tabs
		DownUpThisFrame(.ENTER, game_input);
		AddTextInput(TAB2_LINE, game_input);	
		tt_data.test_char_point += TAB2_LINE.count + 1;//+1 for the enter
		tt_data.test_line_char = TAB2_LINE.count;
		tt_data.test_line_number += 1;
	}
	case 20; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		start_mid_tab : float = 0.4*TAB_CHAR_COUNT + TAB_CHAR_COUNT + 4;
		//TEST Press mouse should be on left hand side of tab
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + start_mid_tab*perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count + 2*TAB_LINE.count + 5;
		tt_data.test_line_char = 5;
		tt_data.test_line_number = 4;
	}
	case 21; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);


		end_mid_tab : float = 0.6*TAB_CHAR_COUNT + TAB_CHAR_COUNT + 4;
		//TEST Press mouse should be on left hand side of tab
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + end_mid_tab*perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 22; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);


		//end tab so 4 = with and 3 = tab plus start and mid tab
		start_end_tab : float = 0.4*TAB_CHAR_COUNT + TAB_CHAR_COUNT + 4 + TAB_CHAR_COUNT + 3;
		//TEST Press mouse should be on left hand side of tab
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + start_end_tab*perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point += 3;
		tt_data.test_line_char += 3;
	}
	case 23; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);


		//end tab so 4 = with and 3 = tab plus start and mid tab
		end_end_tab : float = 0.6*TAB_CHAR_COUNT + TAB_CHAR_COUNT + 4 + TAB_CHAR_COUNT + 3;
		//TEST Press mouse should be on left hand side of tab
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + end_end_tab*perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	//TODO FROM HERE copy tab2_line instead and then paste that 5 times to go off and
	//then test bounds with cursor and with mouse highlighting on both sides and then do scroll
	//also check a second line with right and left char bounds
	case 24; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);


		//TEST Copy tab2line to test line chars bounds with a bunch of tabs
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count + 2*TAB_LINE.count;
		tt_data.test_line_char = 0;
	}
	case 25; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		end_end_tab : float = 0.6*TAB_CHAR_COUNT + TAB_CHAR_COUNT + 4 + TAB_CHAR_COUNT + 3;
		line_1_pos := Vector2F.{
			text_op.ator.LOC_START_X + end_end_tab*perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point += TAB2_LINE.count;
		tt_data.test_line_char = TAB2_LINE.count;
	}
	case 26; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 27; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 28; DownUpThisFrame(.ARROW_RIGHT, game_input);
	case 29; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);

		//TEST left and right char bounds with keyboard and mouse in text pane
		//We can run this here since the text inputs all get run no matter what
		paste_times : int = 5;
		for 1..paste_times DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += TAB2_LINE.count*paste_times;
		tt_data.test_line_char += TAB2_LINE.count*paste_times;
		//left char bounds are per character so they are >= the actual line_char
		tt_data.test_left_char_bound = 14;
		tt_data.test_right_char_bound = 78;
	}
	case 30; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST that we press the correct line even though we are on a tab at the start of the left_char_bound
		line_left := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_line_char = 11;
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count + 2*TAB_LINE.count + tt_data.test_line_char;
	}
	case 31; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST that the left char bound moves since the left char is a tab and so we should be slightly to the left of the tab char rounding
		rect_left := Vector2F.{
			text_op.ator.left_rect.min.x,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(rect_left, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
		tt_data.test_left_char_bound -= 1;
		tt_data.test_right_char_bound -= 1;
	}
	case 32; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		line_left := Vector2F.{
			text_op.ator.left_rect.max.x,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		//5 is from the paste_times above
		tt_data.test_char_point += 5*TAB2_LINE.count;
		tt_data.test_line_char += 5*TAB2_LINE.count;
		tt_data.test_left_char_bound += 1;
		tt_data.test_right_char_bound += 1;
	}
	case 33; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST holding the mouse across the left op boundary by 2.1 chars so we should move over everything and 1 character
		//the left is currently half of the tab so 2.1 back from there should be the lhs of the previous tab
		line_left_2_char := Vector2F.{
			text_op.ator.LOC_START_X - 2.1*perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left_2_char, op_space, op_2D_cam.world_pos, default_base_cam);
		//We go back the tab and then also the next tab since its 2 chars from the left which is half of the tab
		tt_data.test_char_point -= 5*TAB2_LINE.count + 1;
		tt_data.test_line_char -= 5*TAB2_LINE.count + 1;
		//the 1 + is because we have only 1 char of the tab on the left side
		tt_data.test_left_char_bound -= 1 + TAB_CHAR_COUNT;
		tt_data.test_right_char_bound -= 1 + TAB_CHAR_COUNT;
	}
	case 34; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go back exactly 2 char to the previous char since it's not a tab here but a 1 char character
		line_left_1_char := Vector2F.{
			text_op.ator.LOC_START_X - perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left_1_char, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
		tt_data.test_left_char_bound -= 1;
		tt_data.test_right_char_bound -= 1;
	}
	case 35; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST moving over by 2 tabs of the left side precisely
		line_left_2_char := Vector2F.{
			text_op.ator.LOC_START_X - 2 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left_2_char, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
		tt_data.test_left_char_bound -= 2;
		tt_data.test_right_char_bound -= 2;
	}
	case 36; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//Test moving left < 1 char on the tab
		line_left_1_char := Vector2F.{
			text_op.ator.LOC_START_X - 0.8*perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left_1_char, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 37; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//Test moving left > 1 char on the tab
		line_left_1_char := Vector2F.{
			text_op.ator.LOC_START_X - 1.2*perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left_1_char, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
		tt_data.test_left_char_bound -= TAB_CHAR_COUNT;
		tt_data.test_right_char_bound -= TAB_CHAR_COUNT;
	}
	case 38; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go on rhs of a tab rounding with left_char_bound > 0
		line_left_1_char := Vector2F.{
			text_op.ator.LOC_START_X + 1.5 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left_1_char, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
		//test boundaries don't move here since were just moving over
		// tt_data.test_left_char_bound += TAB_CHAR_COUNT;
		// tt_data.test_right_char_bound += TAB_CHAR_COUNT;
	}
	case 39; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go on rhs of a tab rounding with left_char_bound > 0
		line_over_left := Vector2F.{
			text_op.ator.LOC_START_X - 3 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_over_left, op_space, op_2D_cam.world_pos, default_base_cam);
		//We move back by the tab + 3 chars on the left because we are 3 chars over but only 3 on the char bound since the tab is 2 chars
		tt_data.test_char_point -= 4;
		tt_data.test_line_char -= 4;
		tt_data.test_left_char_bound -= 3;
		tt_data.test_right_char_bound -= 3;
	}
	case 40; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST we go over one more before final tab where we should stop
		line_over_left := Vector2F.{
			text_op.ator.LOC_START_X - 1 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_over_left, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
		tt_data.test_left_char_bound -= 1;
		tt_data.test_right_char_bound -= 1;
	}
	case 41; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go over last tab where we should stop
		line_over_left := Vector2F.{
			text_op.ator.LOC_START_X - 1.5 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_over_left, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
		tt_data.test_left_char_bound -= 2;
		tt_data.test_right_char_bound -= 2;
	}
	case 42; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST that we don't move char points or bounds anymore since we are at the end of the line on the left
		line_over_left := Vector2F.{
			text_op.ator.LOC_START_X - 5 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_over_left, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 43; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST that we don't move char points or bounds anymore since we are at the end of the line on the left
		line_over_left := Vector2F.{
			text_op.ator.LOC_START_X - 5 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_over_left, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 44; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST now we go over with mouse over the right char bound and that everything moves properly
		line_left := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 45; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST now we go over with mouse over the right char bound and that everything moves properly
		// we dont fully go over tab so we don't have
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + 0.4 * TAB_CHAR_COUNT * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 46; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST now we go over with mouse over the right char bound and that everything moves properly
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + 0.6 * TAB_CHAR_COUNT * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 47; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST now we go over with mouse over the right char bound and that everything moves properly
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (1 + TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 48; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST now we go over with mouse over the right char bound and that everything moves properly
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (3 + TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 2;
		tt_data.test_line_char += 2;
	}
	case 49; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST we go over another char and part of a tab but not the whole tab
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (4 + 0.4*TAB_CHAR_COUNT + TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 50; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST we go over another char and part of a tab but not the whole tab
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (4 + 0.6*TAB_CHAR_COUNT + TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
	}
	case 51; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST we go over a few chars and a few tabs
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (7 + 4*TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 5;
		tt_data.test_line_char += 5;
	}
	case 52; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go over right op and update bounds
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 89;
		tt_data.test_line_char = TAB2_LINE.count * 5 - 1;
	}
	case 53; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go over right op and update bounds by 1 char
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
		tt_data.test_left_char_bound += 1;
		tt_data.test_right_char_bound += 1;
	}
	case 54; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go over right op and update bounds by 1 char and tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 2) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
		tt_data.test_left_char_bound += 2;
		tt_data.test_right_char_bound += 2;
	}
	case 55; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go over right op and update bounds by 1 more char
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
		tt_data.test_left_char_bound += 1;
		tt_data.test_right_char_bound += 1;
	}
	case 56; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go over right op and update bounds by 3 chars and a tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 3 + 0.6*TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 4;
		tt_data.test_line_char += 4;
		tt_data.test_left_char_bound += 5;
		tt_data.test_right_char_bound += 5;
	}
	case 57; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go over right op and update bounds by 3 more chars
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 3) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 3;
		tt_data.test_line_char += 3;
		tt_data.test_left_char_bound += 3;
		tt_data.test_right_char_bound += 3;
	}
	case 58; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go over right op to end of line
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 5) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
		tt_data.test_left_char_bound += 2;
		tt_data.test_right_char_bound += 2;
	}
	case 59; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST go past right char bound to make sure we dont change anything
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 5) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 60; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 61; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST copy paste the line and make sure char bounds update
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 62; DownUpThisFrame(.ARROW_RIGHT, game_input);
	case 63; {
		//TEST enter should change the char bounds
		DownUpThisFrame(.ENTER, game_input);
		//right and left char bounds should not have changed since we are at the same point we were before
		tt_data.test_char_point += 1;//+1 for the \n new line
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
		bound_diff : int = tt_data.test_right_char_bound - tt_data.test_left_char_bound;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = bound_diff;
	}
	case 64; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);

		//TEST past on a new line and make sure char bounds changed
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 6 * TAB2_LINE.count;
		tt_data.test_line_char = 6 * TAB2_LINE.count;
		bound_diff : int = tt_data.test_right_char_bound - tt_data.test_left_char_bound;
		tt_data.test_left_char_bound = 14;
		tt_data.test_right_char_bound = 14+bound_diff;
	}
	case 65; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		//TEST rhs tab at end should not move anything
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff - 0.4 * TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 5*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 66; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		//TEST go past right char bound to make sure we dont change anything
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff - 0.6 * TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 5*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
	}
	case 67; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		//TEST shoudl not move on half the previous char before the tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff - TAB_CHAR_COUNT - 0.4) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 5*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 68; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		//TEST shoudl not move on half the previous char before the tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff - TAB_CHAR_COUNT - 0.6) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 5*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
	}
	case 69; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		//TEST highlighting line above should work the same way left and right
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 5*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		tt_data.test_char_point += 2;
		tt_data.test_line_char += 2;
	}
	case 70; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		//TEST highlighting line above should work the same way left and right
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point -= 6*TAB2_LINE.count + 1; //+1 for the \n
		tt_data.test_line_char = 6*TAB2_LINE.count;
		tt_data.test_line_number -= 1;
	}
	case 71; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above should work the same way left char bound
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 1 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 5*TAB2_LINE.count;
		tt_data.test_line_char = TAB2_LINE.count;
		tt_data.test_left_char_bound -= 1;
		tt_data.test_right_char_bound -= 1;
	}
	case 72; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above should work the same way left tab and char
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - (TAB_CHAR_COUNT + 0.6) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
		tt_data.test_left_char_bound -= TAB_CHAR_COUNT + 1;
		tt_data.test_right_char_bound -= TAB_CHAR_COUNT + 1;
	}
	case 73; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above should work the same way right tab and char
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + TAB_CHAR_COUNT + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 5*TAB2_LINE.count + 1;
		tt_data.test_line_char = 6*TAB2_LINE.count - 1;
		tt_data.test_left_char_bound += TAB_CHAR_COUNT;
		tt_data.test_right_char_bound += TAB_CHAR_COUNT;
	}
	case 74; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above should work the same way right tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 1;
		tt_data.test_line_char += 1;
		tt_data.test_left_char_bound += TAB_CHAR_COUNT;
		tt_data.test_right_char_bound += TAB_CHAR_COUNT;
	}
	case 75; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above should work with not moving off the end
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 4*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 76; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above which is shorter
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 3*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count + 2*TAB_LINE.count - 1;//-1 for last /n since we are not over it
		tt_data.test_line_char = TAB_LINE.count - 1;
		tt_data.test_line_number -= 1;
		tt_data.test_left_char_bound = tt_data.test_line_char - 1 + TAB_CHAR_COUNT;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
	}
	case 77; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above go back 1 char
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 1.5 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 3*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 1;//-1 for last /n since we are not over it
		tt_data.test_line_char -= 1;
		tt_data.test_left_char_bound -= 1;
		tt_data.test_right_char_bound -= 1;
	}
	case 78; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above which is shorter
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 2 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 3*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 2;//-1 for last /n since we are not over it
		tt_data.test_line_char -= 2;
		tt_data.test_left_char_bound -= 2;
		tt_data.test_right_char_bound -= 2;
	}
	case 79; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above which is shorter
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 5 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 3*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 5;//-1 for last /n since we are not over it
		tt_data.test_line_char -= 5;
		tt_data.test_left_char_bound -= 5;
		tt_data.test_right_char_bound -= 5;
	}
	case 80; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line above with tab should not move
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - (0.4*TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 3*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 81; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting line to the beggining with rhs of tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - (0.6*TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 3*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char -= 1;
		tt_data.test_left_char_bound -= TAB_CHAR_COUNT;
		tt_data.test_right_char_bound -= TAB_CHAR_COUNT;
	}
	case 82; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting before line shoudl not move from beggining
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 1 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 3*text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 83; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting before line shoudl not move from beggining
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = char_bound_diff;
	}
	case 84; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST highlighting above the top should not anything
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y + 1 * perm.text_editor_data.code_font_1_char_width_world
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 85; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST copy entire block and paste it below a few times to get more lines on bottom
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 86; {
		DownUpThisFrame(.ARROW_DOWN, game_input);

		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		tt_data.test_char_point = text_file.file_string.text_string.count;
		tt_data.test_line_char = 6*TAB2_LINE.count;
		tt_data.test_line_number = text_file.file_loc.count-1;
		tt_data.test_left_char_bound = 14;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
	}
	case 87; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		DownUpThisFrame(.ENTER, game_input);

		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		tt_data.test_char_point += 1;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 1;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = char_bound_diff;
	}
	case 88; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);

		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		tt_data.test_char_point = 2*text_file.file_string.text_string.count-1;
		tt_data.test_line_char = 6*TAB2_LINE.count;
		tt_data.test_line_number = 2*(text_file.file_loc.count-1)-1;//-1 since we dont have new line on bottom
		tt_data.test_left_char_bound = 14;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
	}
	case 89; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		

		//TEST copy entire block and paste it below a few times to get more lines on bottom
		DownUpThisFrame(.ENTER, game_input);
	}
	case 90; DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
	case 91; DownUpThisFrame(.ENTER, game_input);
	case 92; DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
	case 93; {
		tt_data.test_char_point = text_file.file_string.text_string.count;
		tt_data.test_line_char = 6*TAB2_LINE.count;
		tt_data.test_line_number = text_file.file_loc.count-1;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		tt_data.test_start_line_index = 2;
		tt_data.test_end_line_index = tt_data.test_start_line_index + line_diff;
	}
	case 94; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		

		//TEST copy entire block and paste it below a few times to get more lines on bottom
		DownUpThisFrame(.ENTER, game_input);
	}
	case 95; DownUpThisFrame(.ARROW_LEFT, game_input);
	case 96; {
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		AssertEquals(21, line_diff);
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		AssertEquals(64, char_bound_diff);

		//TEST highlighting above the top should not anything
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff-1) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);

		tt_data.test_start_line_index = 3;
		tt_data.test_end_line_index = tt_data.test_start_line_index + line_diff;
	}
	case 97; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		

		//TEST move up 1 line from the top to change the line bound indices from right bound chars
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y + 1 * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count + TAB_LINE.count - 1;
		tt_data.test_line_char = TAB_LINE.count-1;//-1 to remove \n
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound = 10;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 98; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);


		//TEST move up 2 lines from the top to change the line bound indices from right bound chars
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y + 2 * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = SOME_TEXT_LINE.count-1;
		tt_data.test_line_char =  SOME_TEXT_LINE.count-1;//-1 to remove \n
		tt_data.test_line_number = 0;
		tt_data.test_left_char_bound = SOME_TEXT_LINE.count-1;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 99; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		

		//TEST move up 2 lines and nothing should move since we are at the top
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y + 2 * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 100; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		

		//TEST move down 1 line from the bottom to change the line bound indices from right bound chars
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 10) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff + 1) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = tt_data.fixed_char_point - 6 * TAB2_LINE.count - 1;//-1 to remove \n
		tt_data.test_line_char = 6*TAB2_LINE.count;//tab2line does not have \n
		tt_data.test_line_number = tt_data.fixed_line_number-1;
		tt_data.test_left_char_bound = 14;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
		tt_data.test_start_line_index += 1;
		tt_data.test_end_line_index += 1;
	}
	case 101; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		

		//TEST move to the left 1 char after moving down
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_left := Vector2F.{
			text_op.ator.LOC_START_X - 1 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff) * text_op.ator.TEXT_LINE_HEIGHT
		};	
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 5 * TAB2_LINE.count;
		tt_data.test_line_char -= 5 * TAB2_LINE.count;
		tt_data.test_left_char_bound -= 1;
		tt_data.test_right_char_bound -= 1;
	}
	case 102; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		

		//TEST move to the left by 1 tab and 1 char after moving down
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_left := Vector2F.{
			text_op.ator.LOC_START_X - (TAB_CHAR_COUNT + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff) * text_op.ator.TEXT_LINE_HEIGHT
		};	
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
		tt_data.test_left_char_bound -= TAB_CHAR_COUNT + 1;
		tt_data.test_right_char_bound -= TAB_CHAR_COUNT + 1;
	}
	case 103; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		

		//TEST move to the left > 1 char after moving down
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_left := Vector2F.{
			text_op.ator.LOC_START_X - 15 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff) * text_op.ator.TEXT_LINE_HEIGHT
		};	
		game_input.mouse_cam = OpSpaceToCameraSpace(line_left, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 1 * TAB2_LINE.count - 2;//-1 from the previous 2
		tt_data.test_line_char = 0;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
	}
	case 104; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST move down 2 line from the bottom to change the line bound indices from right bound chars
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff + 2) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = text_file.file_string.text_string.count;
		tt_data.test_line_char = 0;//-1 to remove \n
		tt_data.test_line_number = text_file.file_string.file_loc.count-1;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 105; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		

		//TEST move down 2 lines and nothing should move since we are at the bottom
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff + 2) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 106; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);		
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);

		//TEST move down 2 lines and nothing should move since we are at the bottom
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - (line_diff) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 107; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);	

		//TEST move up 1 line from the left side
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y + 1 * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point = 2*SOME_TEXT_LINE.count;
		tt_data.test_line_number = 2;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 108; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);	

		//TEST move up 2 lines from the left side
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y + 2 * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.test_char_point = 0;
		tt_data.test_line_number = 0;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 109; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);	

		//TEST move down 1 lines from the left side
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - (line_diff + 1) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.test_char_point = text_file.file_string.text_string.count - 2*6 * TAB2_LINE.count - 2;
		tt_data.test_line_number = text_file.file_string.file_loc.count - 3;
		tt_data.test_start_line_index += 1;
		tt_data.test_end_line_index += 1;
	}
	case 110; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);	

		//TEST move down 2 lines from the left side and back where we started so no longer selecting
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - (line_diff + 2) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.test_char_point = text_file.file_string.text_string.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count - 1;
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 111; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	
		AssertEquals(tt_data.fixed_char_point, tab_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, tab_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, tab_cursor.fixed_select_line_number);	

		//TEST move down 2 more lines which should not move since we are at the bottom
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - (line_diff + 2) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 112; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle and check bounds left, right up and down
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 35;
		tt_data.test_start_line_index = 3;
		tt_data.test_end_line_index = 15;
	}
	case 113; {
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		AssertEquals(35, char_bound_diff);
		AssertEquals(12, tab_cursor.end_file_line_index - tab_cursor.start_file_line_index);

		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle and check bounds left, right up and down
		DownUpThisFrame(.ARROW_LEFT, game_input);
		DownUpThisFrame(.ARROW_DOWN, .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 1;
		tt_data.test_line_char = 6 * TAB2_LINE.count;
		tt_data.test_line_number -= 1;
		tt_data.test_left_char_bound = 43;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
		tt_data.test_start_line_index = 12;
		tt_data.test_end_line_index = 24;
	}
	case 114; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TODO FROM HERE test left right up and down with debug toggle and then do few extra tests on bottom
		//before testing switch pane and then doing watch pane tests
		//TEST debug toggle and check bounds left, right up and down
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 115; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check left bound 1 char
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 1 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 3 * TAB2_LINE.count - 2;
		tt_data.test_line_char = 3 * TAB2_LINE.count + 2;
		tt_data.test_left_char_bound = 42;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
	}
	case 116; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check left bound 1 char and 1 tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - (TAB_CHAR_COUNT + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};		
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
		tt_data.test_left_char_bound -= TAB_CHAR_COUNT + 1;
		tt_data.test_right_char_bound -= TAB_CHAR_COUNT + 1;
	}
	case 117; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check left bound 3 chars and a tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - (TAB_CHAR_COUNT + 3) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point -= 4;
		tt_data.test_line_char -= 4;
		tt_data.test_left_char_bound -= TAB_CHAR_COUNT + 3;
		tt_data.test_right_char_bound -= TAB_CHAR_COUNT + 3;
	}
	case 118; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check left bound 3 chars and a tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 100 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 587;
		tt_data.test_line_char = 0;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
	}
	case 119; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check upper bound 1 line
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y + 1 * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 263;
		tt_data.test_line_number = 11;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 120; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check upper bound 2 lines
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y + 2 * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 192;
		tt_data.test_line_number -= 2;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 121; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check right bound 1 char
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 1 * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 230;
		tt_data.test_line_char = 28;
		tt_data.test_line_number += 1;
		tt_data.test_left_char_bound += 1;
		tt_data.test_right_char_bound += 1;
	}
	case 122; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check upper bound 1 char and 1 tab
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + TAB_CHAR_COUNT + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - 1 * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point += 2;
		tt_data.test_line_char += 2;
		tt_data.test_left_char_bound += TAB_CHAR_COUNT + 1;
		tt_data.test_right_char_bound += TAB_CHAR_COUNT + 1;
	}
	case 123; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check lower bound by 1 line
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff + 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 556;
		tt_data.test_line_number += line_diff;
		tt_data.test_start_line_index += 1;
		tt_data.test_end_line_index += 1;
	}
	case 124; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check lower bound by 2 lines
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff + 2) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_data.test_char_point = 648;
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 2;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = char_bound_diff;
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 125; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(true, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST we are at the bottom so this should not move
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff + 2) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 126; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check mouse scrolling up 1 - move the cursor back into the text pane
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + char_bound_diff * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 2) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 1;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 127; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check mouse scrolling up 2
		game_input.mouse_wheel = 2;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 128; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check mouse scrolling down 1
		game_input.mouse_wheel = -1;
		tt_data.test_start_line_index += 1;
		tt_data.test_end_line_index += 1;
	}
	case 129; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST debug toggle check mouse scrolling down 2
		game_input.mouse_wheel = -2;
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 130; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST move mouse to watch window and then back should not change anything
		watch_center : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_center, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 131; {
		AssertEquals(SelectedTextPane.WATCH, text_op.selected_pane);
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check lhs scroll up when pane is not selected
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (0.4 * TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		game_input.mouse_wheel = 1;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 132; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check lhs scroll down when pane is not selected
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (0.4 * TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		game_input.mouse_wheel = -1;
		tt_data.test_start_line_index += 1;
		tt_data.test_end_line_index += 1;
	}
	case 133; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check lhs scroll down when pane is not selected
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (0.4 * TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		game_input.mouse_wheel = 2;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 134; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check lhs scroll down when pane is not selected
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (0.4 * TAB_CHAR_COUNT) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		game_input.mouse_wheel = -2;
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 135; {
		AssertEquals(true, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check lhs scroll down when pane is not selected
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 136; {
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);
		DownUpThisFrame(.END, game_input);

		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		tt_data.test_char_point = text_file.file_string.text_string.count-1;
		tt_data.test_line_char = 6*TAB2_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-2;
		tt_data.test_left_char_bound = 43;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + char_bound_diff;
	}
	case 137; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST test to make sure mouse changes over the left edge
		//NOTE We are technically already testing this with the cursor moving over it's just
		//not a precise testings
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 1 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 138; {
		AssertEquals(32, perm.test_data.test_mouse_line_char);

		//TEST check lhs scroll down when pane is not selected
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X - 2 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 139; {
		AssertEquals(31, perm.test_data.test_mouse_line_char);

		DownUpThisFrame(.HOME, game_input);
		DownUpThisFrame(.HOME, game_input);
	}
	case 140; {
		//TEST check lhs scroll down when pane is not selected
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 141; {
		AssertEquals(28, perm.test_data.test_mouse_line_char);

		//TEST check lhs scroll down when pane is not selected
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 2) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 142; {
		AssertEquals(29, perm.test_data.test_mouse_line_char);

		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count-6*TAB2_LINE.count-1;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = text_file.file_string.file_loc.count-2;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;
		tt_data.test_start_line_index = 3;
		tt_data.test_end_line_index = 24;
	}
	case 143; {
		game_input.mouse_wheel = 9;
	}
	case 144; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check rhs mouse line char with 1 char without debug
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 145; {
		AssertEquals(50, perm.test_data.test_mouse_line_char);

		//TEST check rhs mouse line char with 1 tab and 1 char without debug
		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		char_bound_diff : int = tab_cursor.right_char_bound - tab_cursor.left_char_bound;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + (char_bound_diff + TAB_CHAR_COUNT + 1) * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 146; {
		AssertEquals(51, perm.test_data.test_mouse_line_char);

		line_diff : int = tab_cursor.end_file_line_index - tab_cursor.start_file_line_index;
		line_right := Vector2F.{
			text_op.ator.LOC_START_X + 1 * perm.text_editor_data.code_font_1_char_width_world,
			text_op.ator.LOC_START_Y - (line_diff - 1) * text_op.ator.TEXT_LINE_HEIGHT
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(line_right, op_space, op_2D_cam.world_pos, default_base_cam);

		//TEST check scroll up without debug
		game_input.mouse_wheel = 1;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 147; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check scroll up without debug
		game_input.mouse_wheel = 2;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 148; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check scroll up without debug
		game_input.mouse_wheel = -1;
		tt_data.test_start_line_index += 1;
		tt_data.test_end_line_index += 1;
	}
	case 149; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check scroll up without debug
		game_input.mouse_wheel = -2;
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 150; {
		AssertEquals(false, tab_cursor.cursor_is_selecting);
		AssertEquals(false, tab_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, tab_cursor.char_point);
		AssertEquals(tt_data.test_line_char, tab_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, tab_cursor.cursor_line_number);
		AssertEquals(tt_data.test_left_char_bound, tab_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, tab_cursor.right_char_bound);		
		AssertEquals(tt_data.test_start_line_index, tab_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, tab_cursor.end_file_line_index);	

		//TEST check scroll up without debug
		// game_input.mouse_wheel = -2;
		// tt_data.test_start_line_index += 2;
		// tt_data.test_end_line_index += 2;
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

COMPILE_TEXT_STRING :: #string DONE
main :: () {
	t : Test;
	t.x = 2;
	tano(0..1,0..2) ~= int.[0, 16, 123];
}
Test :: struct {
	x : int;
}
DONE;
Test_TextWatchMouse :: (
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
		array_resize(*perm.test_data.all_sub_tests, 73);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	tt_data := cast(*TextTestData) perm.test_data.spec_data;
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

TEST_WATCH_TEXT :: "test watch";
TEST_WATCH_TEXT_3 :: "test watchtest watchtest watch";
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		AddTextBlock(COMPILE_TEXT_STRING, game_input);
	}
	case 2; {
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	}
	case 3; {
		r_top_center : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(r_top_center, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 4; {
		AssertEquals(SelectedTextPane.WATCH, text_op.selected_pane);
		AddTextInput(TEST_WATCH_TEXT, game_input);
	}
	case 5; {
		DownUpThisFrame(.ENTER, game_input);
	}
	case 6; {
		//TODO FROM HERE check the edit tab. MAYBE We remove this double click thing since it's irritating and just use ctrl+e
		value_width : float = GetWidth(text_op.ator.watch_name_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += 0.5*value_width;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 7; {
		AssertEquals(0, text_op.highlighted_name_index);

		DownUpInputMap(.DEBUG_WATCH_EDIT, game_input);
		tt_data.test_char_point = TEST_WATCH_TEXT.count;
		tt_data.test_line_char = TEST_WATCH_TEXT.count;
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 26;
	}
	case 8; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		
	}
	case 9; {
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 10; {
		value_width : float = GetWidth(text_op.ator.watch_name_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += watch_cursor.right_char_bound * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 11; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 3*TEST_WATCH_TEXT.count;
		tt_data.test_line_char = 3*TEST_WATCH_TEXT.count;
		tt_data.test_left_char_bound = 4;
		tt_data.test_right_char_bound = 30;
	}
	case 12; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		

		edit_width : float = GetWidth(text_op.ator.r_top_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += edit_width - 0.3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 13; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		

		//TEST the hovering left bound for 1 char moves char bounds
		value_width : float = GetWidth(text_op.ator.watch_name_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.test_char_point = tt_data.test_left_char_bound-1;
		tt_data.test_line_char = tt_data.test_char_point;
		tt_data.test_left_char_bound -= 1;
		tt_data.test_right_char_bound -= 1;
	}
	case 14; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST the hovering left bound for 3 chars moves char bounds
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x -= 3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.test_char_point -= 3;
		tt_data.test_line_char -= 3;
		tt_data.test_left_char_bound -= 3;
		tt_data.test_right_char_bound -= 3;
	}
	case 15; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST left bound should not move now since we are at the limit
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x -= 3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 16; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST right char bound going over text op
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);

		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 26;
	}
	case 17; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST right char bound going over text op 1 char
		edit_width : float = GetWidth(text_op.ator.r_top_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += edit_width + 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.test_char_point = tt_data.test_right_char_bound + 1;
		tt_data.test_line_char = tt_data.test_char_point;
		tt_data.test_left_char_bound += 1;
		tt_data.test_right_char_bound += 1;
	}
	case 18; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST right char bound going over text op 3 chars
		edit_width : float = GetWidth(text_op.ator.r_top_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += edit_width + 3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.test_char_point += 3;
		tt_data.test_line_char += 3;
		tt_data.test_left_char_bound += 3;
		tt_data.test_right_char_bound += 3;
	}
	case 19; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST right char bound going over text op 3 chars should not move since we are at the end now
		edit_width : float = GetWidth(text_op.ator.r_top_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += edit_width + 3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 20; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		

		//TEST right char bound going over text op 3 chars should not move since we are at the end now
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 21; {
		//TEST right char bound going over text op 3 chars should not move since we are at the end now
		name_width : float = GetWidth(text_op.ator.watch_name_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += 0.5*name_width;
		top_value.y -= 1.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 22; {
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(1, text_op.highlighted_name_index);

		//TEST right char bound going over text op 3 chars should not move since we are at the end now
		DownUpInputMap(.DEBUG_WATCH_EDIT, game_input);
	}
	case 23; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(0, watch_cursor.char_point);
		AssertEquals(0, watch_cursor.cursor_line_char);


		//TEST right char bound going over text op 3 chars should not move since we are at the end now
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = TEST_WATCH_TEXT_3.count;
		tt_data.test_line_char = TEST_WATCH_TEXT_3.count;
		tt_data.test_left_char_bound = 4;
		tt_data.test_right_char_bound = 30;
	}
	case 24; {
		AssertEquals(TEST_WATCH_TEXT_3, text_op.edit_watch_name.text_string);
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);


		//TEST pressing below watch pane names and still selected
		name_width : float = GetWidth(text_op.ator.watch_name_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += 0.5*name_width;
		top_value.y -= 4*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 25; {
		AssertEquals(2, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);

		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 3*TEST_WATCH_TEXT.count;
		tt_data.test_line_char = 3*TEST_WATCH_TEXT.count;
		tt_data.test_left_char_bound = 4;
		tt_data.test_right_char_bound = 30;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 12;
	}
	case 26; {
		AssertEquals(TEST_WATCH_TEXT_3, text_op.edit_watch_name.text_string);
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		DownUpThisFrame(.ENTER, game_input);
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ENTER, game_input);
	}
	case 27; {
		AssertEquals(3, text_op.highlighted_name_index);

		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 28; {
		AssertEquals(4, text_op.highlighted_name_index);

		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 29; {
		AssertEquals(5, text_op.highlighted_name_index);
	}
	case 30; {
		RunSubTestNTimes(10, *perm.test_data);
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ENTER, game_input);
	}
	case 31; {
		AssertEquals(15, text_op.highlighted_name_index);

		tt_data.test_start_line_index += 3;
		tt_data.test_end_line_index += 3;
	}
	case 32; {
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);
	}
	case 33; {
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 1;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 34; {
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 2;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 35; {
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling more should do nothing since we are already at the top
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 2;
	}
	case 36; {
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -1;
		tt_data.test_start_line_index += 1;
		tt_data.test_end_line_index += 1;
	}
	case 37; {
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -2;
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 38; {
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling more should do nothing since we are already at the bottom
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -2;
	}
	case 39; {
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		DownUpInputMap(.TEXT_CALL_STACK, game_input);
		tt_data.test_end_line_index = 24;
	}
	case 40; {
		AssertEquals(TextPaneType.NONE, text_op.r_bottom_pane_type);
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling down shoudl do nothing
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -1;
	}
	case 41; {
		AssertEquals(TextPaneType.NONE, text_op.r_bottom_pane_type);
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling up when we remove call stack
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 1;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 42; {
		AssertEquals(TextPaneType.NONE, text_op.r_bottom_pane_type);
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling when we remove call stack
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 2;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 43; {
		AssertEquals(TextPaneType.NONE, text_op.r_bottom_pane_type);
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling up more should do nothign since we are already at the top
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 2;
	}
	case 44; {
		AssertEquals(TextPaneType.NONE, text_op.r_bottom_pane_type);
		AssertEquals(15, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling up more should do nothign since we are already at the top
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 2;
	}
	case 45; {
		//TEST Add a few more to make sure scrolling is working with call stack gone
		RunSubTestNTimes(9, *perm.test_data);
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ENTER, game_input);
	}
	case 46; {
		AssertEquals(24, text_op.highlighted_name_index);

		tt_data.test_start_line_index += 3;
		tt_data.test_end_line_index += 3;
	}
	case 47; {
		AssertEquals(24, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 1;
		tt_data.test_start_line_index -= 1;
		tt_data.test_end_line_index -= 1;
	}
	case 48; {
		AssertEquals(24, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 2;
		tt_data.test_start_line_index -= 2;
		tt_data.test_end_line_index -= 2;
	}
	case 49; {
		AssertEquals(24, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling more should do nothing since we are already at the top
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 2;
	}
	case 50; {
		AssertEquals(24, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -1;
		tt_data.test_start_line_index += 1;
		tt_data.test_end_line_index += 1;
	}
	case 51; {
		AssertEquals(24, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -2;
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 52; {
		AssertEquals(24, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		//TEST scrolling more should do nothing since we are already at the bottom
		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = -2;
	}
	case 53; {
		AssertEquals(24, text_op.highlighted_name_index);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 54; {
		DownUpInputMap(.DEBUG_WATCH_EDIT, game_input);
		tt_data.test_char_point = TEST_WATCH_TEXT_3.count;
		tt_data.test_line_char = TEST_WATCH_TEXT_3.count;
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.test_left_char_bound = 4;
		tt_data.test_right_char_bound = 30;
	}
	case 55; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		

		edit_width : float = GetWidth(text_op.ator.r_top_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += edit_width - 0.3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= (text_op.highlighted_name_index-text_op.start_watch_index+0.5)*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 56; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		

		//TEST the hovering left bound for 1 char moves char bounds
		value_width : float = GetWidth(text_op.ator.watch_name_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= (text_op.highlighted_name_index-text_op.start_watch_index+0.5)*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.test_char_point = tt_data.test_left_char_bound-1;
		tt_data.test_line_char = tt_data.test_char_point;
		tt_data.test_left_char_bound -= 1;
		tt_data.test_right_char_bound -= 1;
	}
	case 57; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST the hovering left bound for 3 chars moves char bounds
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x -= 3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= (text_op.highlighted_name_index-text_op.start_watch_index+0.5)*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.test_char_point -= 3;
		tt_data.test_line_char -= 3;
		tt_data.test_left_char_bound -= 3;
		tt_data.test_right_char_bound -= 3;
	}
	case 58; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST left bound should not move now since we are at the limit
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x -= 3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= (text_op.highlighted_name_index-text_op.start_watch_index+0.5)*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 59; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST right char bound going over text op
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= (text_op.highlighted_name_index-text_op.start_watch_index+0.5)*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);

		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 26;
	}
	case 60; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST right char bound going over text op 1 char
		edit_width : float = GetWidth(text_op.ator.r_top_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += edit_width + 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= (text_op.highlighted_name_index-text_op.start_watch_index+0.5)*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.test_char_point = tt_data.test_right_char_bound + 1;
		tt_data.test_line_char = tt_data.test_char_point;
		tt_data.test_left_char_bound += 1;
		tt_data.test_right_char_bound += 1;
	}
	case 61; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST right char bound going over text op 3 chars
		edit_width : float = GetWidth(text_op.ator.r_top_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += edit_width + 3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= (text_op.highlighted_name_index-text_op.start_watch_index+0.5)*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_data.test_char_point += 3;
		tt_data.test_line_char += 3;
		tt_data.test_left_char_bound += 3;
		tt_data.test_right_char_bound += 3;
	}
	case 62; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(true, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		


		//TEST right char bound going over text op 3 chars should not move since we are at the end now
		edit_width : float = GetWidth(text_op.ator.r_top_rect);
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_value.x += edit_width + 3 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= (text_op.highlighted_name_index-text_op.start_watch_index+0.5)*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 63; {
		AssertEquals(true, text_op.is_watch_editing);
		AssertEquals(true, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_char_point, watch_cursor.char_point);
		AssertEquals(tt_data.test_line_char, watch_cursor.cursor_line_char);
		AssertEquals(tt_data.fixed_char_point, watch_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, watch_cursor.fixed_select_line_char);
		AssertEquals(tt_data.test_left_char_bound, watch_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, watch_cursor.right_char_bound);		

		//TEST Toggle while editing so we should not be editing anymore and 
		DownUpInputMap(.TEXT_CALL_STACK, game_input);
		tt_data.test_start_line_index = 3;
		tt_data.test_end_line_index = 15;
	}
	case 64; {
		AssertEquals(TEST_WATCH_TEXT_3, text_op.watch_data_rows[text_op.highlighted_name_index].name);
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		watch_pane : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(watch_pane, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 3;
		tt_data.test_start_line_index -= 3;
		tt_data.test_end_line_index -= 3;
	}
	case 65; {
		AssertEquals(false, text_op.is_watch_editing);
		AssertEquals(false, watch_cursor.cursor_is_selecting);
		AssertEquals(false, watch_cursor.cursor_left_mouse_holding);
		AssertEquals(tt_data.test_start_line_index, text_op.start_watch_index);
		AssertEquals(tt_data.test_end_line_index, text_op.end_watch_index);

		DownUpInputMap(.TEXT_COMPILE, game_input);
	}
	case 66; {
		AssertEquals(true, text_op.text_comp_data != null);
		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data, text_file.absolute_path_name);
	}
	case 67; {
		top_name : Vector2F = GetTopLeft(text_op.ator.watch_name_rect);
		top_name.x += 0.5 * perm.text_editor_data.code_font_1_char_width_world;
		top_name.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_name, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 68; {
		AddTextInput("t", game_input);
	}
	case 69; {
		DownUpThisFrame(.ENTER, game_input);
	}
	case 70; {
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 71; {
		AssertEquals(25, text_op.watch_data_rows.count);

		//TEST dropdown menu with mouse on value dropdown
		top_value : Vector2F = GetTopLeft(text_op.ator.watch_value_rect);
		top_value.x += 0.5 * perm.text_editor_data.code_font_1_char_width_world;
		top_value.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(top_value, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 72; {
		count_equals := AssertEquals(26, text_op.watch_data_rows.count);
		if count_equals {
			watch_data := text_op.watch_data_rows[1];
			AssertEquals("t.x", watch_data.name);
			AssertEquals("x", watch_data.display_name);
			AssertEquals(1, watch_data.watch_indent);
		}
	}
	}
	//TODO FROM HERE then do proportion testing for each line
	//and then do dissasembly and call stack with mouse click and remove double click

	ContinueTest(*perm.test_data);

} @ITest

Test_TextPropMouse :: (
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
		array_resize(*perm.test_data.all_sub_tests, 31);
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

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; AddTextBlock(COMPILE_TEXT_STRING, game_input);
	case 2; {
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
		tt_op.ator.l_top_rect = RectMinMax(.{-22.3, -3.345}, .{4.46, 16.725});
		//TODO SETTINGS This should be pulled in from test settings file once we add that
		tt_op.left_proportion = 0.6;
	}
	case 3; {
		AssertEquals(tt_op.ator.l_top_rect.min, text_op.ator.l_top_rect.min);
		AssertEquals(tt_op.ator.l_top_rect.max, text_op.ator.l_top_rect.max);
		AssertFloatEquals(tt_op.left_proportion, text_op.left_proportion);

		DownUpInputMap(.TEXT_COMPILE, game_input);
	}
	case 4; {
		split_center : Vector2F = GetCenter(text_op.ator.split_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(split_center, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 5; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(true, text_op.mouse_pressing_split_rect);

		half_l_top_rect : Vector2F = GetCenter(text_op.ator.l_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(half_l_top_rect, op_space, op_2D_cam.world_pos, default_base_cam);
		// tt_op.ator.l_top_rect = RectMinMax(.{-22.3, -3.345}, .{4.46, 16.725});
		new_dim : Vector2F = GetDim(tt_op.ator.l_top_rect);
		new_dim.x *= 0.5;
		tt_op.ator.l_top_rect = RectMinDim(.{-22.3, -3.345}, new_dim);
		//TODO SETTINGS This should be pulled in from test settings file once we add that
		tt_op.left_proportion = 0.5 * 0.6;
	}
	case 6; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(true, text_op.mouse_pressing_split_rect);
		AssertEquals(tt_op.ator.l_top_rect.min, text_op.ator.l_top_rect.min);
		AssertEquals(tt_op.ator.l_top_rect.max, text_op.ator.l_top_rect.max);
		AssertFloatEquals(tt_op.left_proportion, text_op.left_proportion);
	}
	case 7; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(true, text_op.mouse_pressing_split_rect);

		//TEST make split rect min size
		left_of_op : Vector2F = GetCenter(text_op.ator.l_top_rect);
		// left_of_op.x = text_op.ator.l_top_rect.min.x + (text_op.left_margin_char_width+0.5) * perm.text_editor_data.code_font_1_char_width_world;
		left_of_op.x = text_op.ator.LOC_START_X;
		game_input.mouse_cam = OpSpaceToCameraSpace(left_of_op, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.ator.l_top_rect = RectMinMax(.{-22.3, -3.345}, .{-20.07, 16.725});
		tt_op.left_proportion = TEXT_SPLIT_MIN;
	}
	case 8; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(true, text_op.mouse_pressing_split_rect);
		AssertEquals(tt_op.ator.l_top_rect.min, text_op.ator.l_top_rect.min);
		AssertEquals(tt_op.ator.l_top_rect.max, text_op.ator.l_top_rect.max);
		AssertFloatEquals(tt_op.left_proportion, text_op.left_proportion);

		//TEST Go beyond left op side should not change anything
		left_of_op : Vector2F = GetCenter(text_op.ator.l_top_rect);
		// left_of_op.x = text_op.ator.l_top_rect.min.x + (text_op.left_margin_char_width+0.5) * perm.text_editor_data.code_font_1_char_width_world;
		left_of_op.x = text_op.ator.LOC_START_X;
		game_input.mouse_cam = OpSpaceToCameraSpace(left_of_op, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 9; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(true, text_op.mouse_pressing_split_rect);
		AssertEquals(tt_op.ator.l_top_rect.min, text_op.ator.l_top_rect.min);
		AssertEquals(tt_op.ator.l_top_rect.max, text_op.ator.l_top_rect.max);
		AssertFloatEquals(tt_op.left_proportion, text_op.left_proportion);

		//TEST go to right of op max
		right_of_op : Vector2F = text_op.ator.op_rect.max;
		game_input.mouse_cam = OpSpaceToCameraSpace(right_of_op, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.l_top_rect = RectMinMax(.{-22.3, -3.345}, .{20.07, 16.725});
		tt_op.left_proportion = TEXT_SPLIT_MAX;
		tt_op.ator.r_top_rect = RectMinMax(tt_op.ator.l_top_rect.max, text_op.ator.op_rect.max);
		tt_op.ator.r_top_rect.min.y = tt_op.ator.l_top_rect.min.y;
	}
	case 10; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(true, text_op.mouse_pressing_split_rect);
		AssertEquals(tt_op.ator.l_top_rect.min, text_op.ator.l_top_rect.min);
		AssertEquals(tt_op.ator.l_top_rect.max, text_op.ator.l_top_rect.max);
		AssertEquals(tt_op.ator.r_top_rect.min, text_op.ator.r_top_rect.min);
		AssertEquals(tt_op.ator.r_top_rect.max, text_op.ator.r_top_rect.max);
		AssertFloatEquals(tt_op.left_proportion, text_op.left_proportion);

		//Reset manually here so we don't have to compute the proportions in the test again
		text_op.set_left_proportion = 0.6;
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		tt_op.left_proportion = text_op.set_left_proportion;
	}
	case 11; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(false, text_op.mouse_pressing_split_rect);

		split_center : Vector2F = GetCenter(text_op.ator.l_bottom_split_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(split_center, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 12; {
		AssertEquals(false, text_op.mouse_hovering_split_rect);
		AssertEquals(false, text_op.mouse_pressing_split_rect);
		AssertEquals(false, text_op.mouse_hovering_l_bottom_split_rect);
		AssertEquals(true, text_op.mouse_pressing_l_bottom_split_rect);

		//TEST moving bottom left proportion up
		asm_pane_up : Vector2F = GetCenter(text_op.ator.l_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(asm_pane_up, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.l_top_rect = RectMinMax(.{-22.3, 6.69}, .{4.46, 16.725});
		tt_op.bottom_proportion = 0.7;
		tt_op.ator.l_bottom_rect = RectMinMax(tt_op.ator.l_top_rect.max, text_op.ator.op_rect.max);
		tt_op.ator.l_bottom_rect.max.x = tt_op.ator.l_top_rect.max.x;
		tt_op.ator.l_bottom_rect.max.y = tt_op.ator.l_top_rect.min.y;
		tt_op.ator.l_bottom_rect.min.x = tt_op.ator.l_top_rect.min.x;
		tt_op.ator.l_bottom_rect.min.y = text_op.ator.op_rect.min.y;
		tt_op.start_disasm_index = 0;
		tt_op.end_disasm_index = 14;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 5;
	}
	case 13; {
		AssertEquals(false, text_op.mouse_hovering_l_bottom_split_rect);
		AssertEquals(true, text_op.mouse_pressing_l_bottom_split_rect);
		AssertEquals(tt_op.ator.l_top_rect.min, text_op.ator.l_top_rect.min);
		AssertEquals(tt_op.ator.l_top_rect.max, text_op.ator.l_top_rect.max);
		AssertEquals(tt_op.ator.l_bottom_rect.min, text_op.ator.l_bottom_rect.min);
		AssertEquals(tt_op.ator.l_bottom_rect.max, text_op.ator.l_bottom_rect.max);
		AssertFloatEquals(tt_op.bottom_proportion, text_op.bottom_proportion);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);

		//TEST moving bottom left proportion up to the top
		asm_pane_top : Vector2F = text_op.ator.l_top_rect.max;
		game_input.mouse_cam = OpSpaceToCameraSpace(asm_pane_top, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.l_top_rect = RectMinMax(.{-22.3, 15.0525}, .{4.46, 16.725});
		tt_op.bottom_proportion = TEXT_SPLIT_MAX;
		tt_op.ator.l_bottom_rect = RectMinMax(tt_op.ator.l_top_rect.max, text_op.ator.op_rect.max);
		tt_op.ator.l_bottom_rect.max.x = tt_op.ator.l_top_rect.max.x;
		tt_op.ator.l_bottom_rect.max.y = tt_op.ator.l_top_rect.min.y;
		tt_op.ator.l_bottom_rect.min.x = tt_op.ator.l_top_rect.min.x;
		tt_op.ator.l_bottom_rect.min.y = text_op.ator.op_rect.min.y;
		tt_op.end_disasm_index = 20;
		//NOTE : 0 is ok here because we render + 1 so its better to see that we are above the 0th index to be accurate
		tt_data.test_end_line_index = 0;
	}
	case 14; {
		AssertEquals(false, text_op.mouse_hovering_l_bottom_split_rect);
		AssertEquals(true, text_op.mouse_pressing_l_bottom_split_rect);
		AssertEquals(tt_op.ator.l_top_rect.min, text_op.ator.l_top_rect.min);
		AssertEquals(tt_op.ator.l_top_rect.max, text_op.ator.l_top_rect.max);
		AssertEquals(tt_op.ator.l_bottom_rect.min, text_op.ator.l_bottom_rect.min);
		AssertEquals(tt_op.ator.l_bottom_rect.max, text_op.ator.l_bottom_rect.max);
		AssertFloatEquals(tt_op.bottom_proportion, text_op.bottom_proportion);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);

		//TEST moving bottom left proportion up higher should not do anything since we already at the top
		asm_pane_top : Vector2F = text_op.ator.l_top_rect.max;
		asm_pane_top.y += 1;
		game_input.mouse_cam = OpSpaceToCameraSpace(asm_pane_top, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 15; {
		AssertEquals(false, text_op.mouse_hovering_l_bottom_split_rect);
		AssertEquals(false, text_op.mouse_pressing_l_bottom_split_rect);
		AssertEquals(tt_op.ator.l_top_rect.min, text_op.ator.l_top_rect.min);
		AssertEquals(tt_op.ator.l_top_rect.max, text_op.ator.l_top_rect.max);
		AssertEquals(tt_op.ator.l_bottom_rect.min, text_op.ator.l_bottom_rect.min);
		AssertEquals(tt_op.ator.l_bottom_rect.max, text_op.ator.l_bottom_rect.max);
		AssertFloatEquals(tt_op.bottom_proportion, text_op.bottom_proportion);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);

		//TEST moving bottom right proportion up
		split_center : Vector2F = GetCenter(text_op.ator.r_bottom_split_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(split_center, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 16; {
		AssertEquals(false, text_op.mouse_hovering_l_bottom_split_rect);
		AssertEquals(false, text_op.mouse_pressing_l_bottom_split_rect);
		AssertEquals(false, text_op.mouse_hovering_r_bottom_split_rect);
		AssertEquals(true, text_op.mouse_pressing_r_bottom_split_rect);

		//TEST moving bottom right proportion up
		cs_pane_up : Vector2F = GetCenter(text_op.ator.r_top_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(cs_pane_up, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.r_top_rect = RectMinMax(.{4.46, 6.69}, .{22.3, 16.725});
		tt_op.r_bottom_height_proportion = 0.7;
		tt_op.ator.r_bottom_rect = RectMinMax(tt_op.ator.r_top_rect.max, text_op.ator.op_rect.max);
		tt_op.ator.r_bottom_rect.max.x = tt_op.ator.r_top_rect.max.x;
		tt_op.ator.r_bottom_rect.max.y = tt_op.ator.r_top_rect.min.y;
		tt_op.ator.r_bottom_rect.min.x = tt_op.ator.r_top_rect.min.x;
		tt_op.ator.r_bottom_rect.min.y = text_op.ator.op_rect.min.y;
		tt_op.start_call_stack_index = 0;
		tt_op.end_call_stack_index = 14;
		tt_op.start_watch_index = 0;
		tt_op.end_watch_index = 5;
	}
	case 17; {
		AssertEquals(false, text_op.mouse_hovering_r_bottom_split_rect);
		AssertEquals(true, text_op.mouse_pressing_r_bottom_split_rect);
		AssertEquals(tt_op.ator.r_top_rect.min, text_op.ator.r_top_rect.min);
		AssertEquals(tt_op.ator.r_top_rect.max, text_op.ator.r_top_rect.max);
		AssertEquals(tt_op.ator.r_bottom_rect.min, text_op.ator.r_bottom_rect.min);
		AssertEquals(tt_op.ator.r_bottom_rect.max, text_op.ator.r_bottom_rect.max);
		AssertFloatEquals(tt_op.r_bottom_height_proportion, text_op.r_bottom_height_proportion);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.start_watch_index, text_op.start_watch_index);
		AssertEquals(tt_op.end_watch_index, text_op.end_watch_index);

		//TEST moving bottom right proportion up to top
		cs_pane_up : Vector2F = text_op.ator.r_top_rect.max;
		game_input.mouse_cam = OpSpaceToCameraSpace(cs_pane_up, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.ator.r_top_rect = RectMinMax(.{4.46, 15.0525}, .{22.3, 16.725});
		tt_op.r_bottom_height_proportion = TEXT_SPLIT_MAX;
		tt_op.ator.r_bottom_rect = RectMinMax(tt_op.ator.r_top_rect.max, text_op.ator.op_rect.max);
		tt_op.ator.r_bottom_rect.max.x = tt_op.ator.r_top_rect.max.x;
		tt_op.ator.r_bottom_rect.max.y = tt_op.ator.r_top_rect.min.y;
		tt_op.ator.r_bottom_rect.min.x = tt_op.ator.r_top_rect.min.x;
		tt_op.ator.r_bottom_rect.min.y = text_op.ator.op_rect.min.y;
		tt_op.end_call_stack_index = 20;
		//NOTE : 0 is ok here because we render + 1 so its better to see that we are above the 0th index to be accurate
		tt_op.end_watch_index = 0;
	}
	case 18; {
		AssertEquals(false, text_op.mouse_hovering_r_bottom_split_rect);
		AssertEquals(true, text_op.mouse_pressing_r_bottom_split_rect);
		AssertEquals(tt_op.ator.r_top_rect.min, text_op.ator.r_top_rect.min);
		AssertEquals(tt_op.ator.r_top_rect.max, text_op.ator.r_top_rect.max);
		AssertEquals(tt_op.ator.r_bottom_rect.min, text_op.ator.r_bottom_rect.min);
		AssertEquals(tt_op.ator.r_bottom_rect.max, text_op.ator.r_bottom_rect.max);
		AssertFloatEquals(tt_op.r_bottom_height_proportion, text_op.r_bottom_height_proportion);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.start_watch_index, text_op.start_watch_index);
		AssertEquals(tt_op.end_watch_index, text_op.end_watch_index);

		//TEST moving bottom right proportion up above top should not change anything
		cs_pane_up : Vector2F = text_op.ator.r_top_rect.max;
		cs_pane_up.y += 1;
		game_input.mouse_cam = OpSpaceToCameraSpace(cs_pane_up, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 19; {
		AssertEquals(false, text_op.mouse_hovering_r_bottom_split_rect);
		AssertEquals(false, text_op.mouse_pressing_r_bottom_split_rect);
		AssertEquals(tt_op.ator.r_top_rect.min, text_op.ator.r_top_rect.min);
		AssertEquals(tt_op.ator.r_top_rect.max, text_op.ator.r_top_rect.max);
		AssertEquals(tt_op.ator.r_bottom_rect.min, text_op.ator.r_bottom_rect.min);
		AssertEquals(tt_op.ator.r_bottom_rect.max, text_op.ator.r_bottom_rect.max);
		AssertFloatEquals(tt_op.r_bottom_height_proportion, text_op.r_bottom_height_proportion);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.start_watch_index, text_op.start_watch_index);
		AssertEquals(tt_op.end_watch_index, text_op.end_watch_index);

		//Reset proportions before doing the watch pane proportions
		text_op.set_bottom_proportion = 0.4;
		text_op.set_r_bottom_height_proportion = 0.4;
		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);
	}
	case 20; {
		nv_split : Vector2F = GetCenter(text_op.ator.name_value_split_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(nv_split, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 21; {
		AssertEquals(false, text_op.mouse_hovering_r_bottom_split_rect);
		AssertEquals(false, text_op.mouse_pressing_r_bottom_split_rect);
		AssertEquals(false, text_op.mouse_hovering_name_value_split_rect);
		AssertEquals(true, text_op.mouse_pressing_name_value_split_rect);

		name_left : Vector2F = GetCenter(text_op.ator.watch_name_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(name_left, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.watch_name_rect = RectMinMax(text_op.ator.r_top_rect.min, 
			.{7.43333, text_op.ator.r_top_rect.max.y});
		tt_op.ator.watch_value_rect = RectMinMax(.{tt_op.ator.watch_name_rect.max.x, text_op.ator.r_top_rect.min.y}, 
			.{17.54268, text_op.ator.op_rect.max.y});
		tt_op.ator.watch_type_rect = RectMinMax(.{tt_op.ator.watch_value_rect.max.x,text_op.ator.r_top_rect.min.y}, 
			text_op.ator.r_top_rect.max);
		//TODO SETTINGS Take these from settings
		tt_op.name_proportion = 0.166666;
		tt_op.type_proportion = 0.266666;
	}
	case 22; {
		AssertEquals(false, text_op.mouse_hovering_name_value_split_rect);
		AssertEquals(true, text_op.mouse_pressing_name_value_split_rect);
		AssertEquals(tt_op.ator.watch_name_rect.min, text_op.ator.watch_name_rect.min);
		AssertEquals(tt_op.ator.watch_name_rect.max, text_op.ator.watch_name_rect.max);
		AssertEquals(tt_op.ator.watch_value_rect.min, text_op.ator.watch_value_rect.min);
		AssertEquals(tt_op.ator.watch_value_rect.max, text_op.ator.watch_value_rect.max);
		AssertEquals(tt_op.ator.watch_type_rect.min, text_op.ator.watch_type_rect.min);
		AssertEquals(tt_op.ator.watch_type_rect.max, text_op.ator.watch_type_rect.max);
		AssertFloatEquals(tt_op.name_proportion, text_op.name_proportion);
		AssertFloatEquals(tt_op.type_proportion, text_op.type_proportion);

		//TEST Going all the way to left for name
		name_left : Vector2F = text_op.ator.r_top_rect.min;
		game_input.mouse_cam = OpSpaceToCameraSpace(name_left, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.watch_name_rect = RectMinMax(text_op.ator.r_top_rect.min, 
			.{5.352, text_op.ator.r_top_rect.max.y});
		tt_op.ator.watch_value_rect = RectMinMax(.{tt_op.ator.watch_name_rect.max.x, text_op.ator.r_top_rect.min.y}, 
			.{17.54268, text_op.ator.op_rect.max.y});
		tt_op.ator.watch_type_rect = RectMinMax(.{tt_op.ator.watch_value_rect.max.x,text_op.ator.r_top_rect.min.y}, 
			text_op.ator.r_top_rect.max);
		//TODO SETTINGS Take these from settings
		tt_op.name_proportion = TEXT_SPLIT_MIN;
	}
	case 23; {
		AssertEquals(false, text_op.mouse_hovering_name_value_split_rect);
		AssertEquals(true, text_op.mouse_pressing_name_value_split_rect);
		AssertEquals(tt_op.ator.watch_name_rect.min, text_op.ator.watch_name_rect.min);
		AssertEquals(tt_op.ator.watch_name_rect.max, text_op.ator.watch_name_rect.max);
		AssertEquals(tt_op.ator.watch_value_rect.min, text_op.ator.watch_value_rect.min);
		AssertEquals(tt_op.ator.watch_value_rect.max, text_op.ator.watch_value_rect.max);
		AssertEquals(tt_op.ator.watch_type_rect.min, text_op.ator.watch_type_rect.min);
		AssertEquals(tt_op.ator.watch_type_rect.max, text_op.ator.watch_type_rect.max);
		AssertFloatEquals(tt_op.name_proportion, text_op.name_proportion);
		AssertFloatEquals(tt_op.type_proportion, text_op.type_proportion);

		//TEST Going over left for name should not change
		name_left : Vector2F = text_op.ator.r_top_rect.min;
		name_left.x -= 1;
		game_input.mouse_cam = OpSpaceToCameraSpace(name_left, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 24; {
		AssertEquals(false, text_op.mouse_hovering_name_value_split_rect);
		AssertEquals(false, text_op.mouse_pressing_name_value_split_rect);
		AssertEquals(tt_op.ator.watch_name_rect.min, text_op.ator.watch_name_rect.min);
		AssertEquals(tt_op.ator.watch_name_rect.max, text_op.ator.watch_name_rect.max);
		AssertEquals(tt_op.ator.watch_value_rect.min, text_op.ator.watch_value_rect.min);
		AssertEquals(tt_op.ator.watch_value_rect.max, text_op.ator.watch_value_rect.max);
		AssertEquals(tt_op.ator.watch_type_rect.min, text_op.ator.watch_type_rect.min);
		AssertEquals(tt_op.ator.watch_type_rect.max, text_op.ator.watch_type_rect.max);
		AssertFloatEquals(tt_op.name_proportion, text_op.name_proportion);
		AssertFloatEquals(tt_op.type_proportion, text_op.type_proportion);

		//TEST moving value rect to the left
		type_split : Vector2F = GetCenter(text_op.ator.value_type_split_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(type_split, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 25; {
		AssertEquals(false, text_op.mouse_hovering_name_value_split_rect);
		AssertEquals(false, text_op.mouse_pressing_name_value_split_rect);
		AssertEquals(false, text_op.mouse_hovering_value_type_split_rect);
		AssertEquals(true, text_op.mouse_pressing_value_type_split_rect);

		value_left : Vector2F = GetCenter(text_op.ator.watch_value_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(value_left, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.watch_name_rect = RectMinMax(text_op.ator.r_top_rect.min, 
			.{5.352, text_op.ator.r_top_rect.max.y});
		tt_op.ator.watch_value_rect = RectMinMax(.{tt_op.ator.watch_name_rect.max.x, text_op.ator.r_top_rect.min.y}, 
			.{11.44734, text_op.ator.op_rect.max.y});
		tt_op.ator.watch_type_rect = RectMinMax(.{tt_op.ator.watch_value_rect.max.x,text_op.ator.r_top_rect.min.y}, 
			text_op.ator.r_top_rect.max);
		//TODO SETTINGS Take these from settings
		tt_op.type_proportion = 0.608333;
	}
	case 26; {
		AssertEquals(false, text_op.mouse_hovering_value_type_split_rect);
		AssertEquals(true, text_op.mouse_pressing_value_type_split_rect);
		AssertEquals(tt_op.ator.watch_name_rect.min, text_op.ator.watch_name_rect.min);
		AssertEquals(tt_op.ator.watch_name_rect.max, text_op.ator.watch_name_rect.max);
		AssertEquals(tt_op.ator.watch_value_rect.min, text_op.ator.watch_value_rect.min);
		AssertEquals(tt_op.ator.watch_value_rect.max, text_op.ator.watch_value_rect.max);
		AssertEquals(tt_op.ator.watch_type_rect.min, text_op.ator.watch_type_rect.min);
		AssertEquals(tt_op.ator.watch_type_rect.max, text_op.ator.watch_type_rect.max);
		AssertFloatEquals(tt_op.name_proportion, text_op.name_proportion);
		AssertFloatEquals(tt_op.type_proportion, text_op.type_proportion);

		//TEST Going all the way to left for name
		value_left : Vector2F = text_op.ator.r_top_rect.min;
		game_input.mouse_cam = OpSpaceToCameraSpace(value_left, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.watch_name_rect = RectMinMax(text_op.ator.r_top_rect.min, 
			.{5.352, text_op.ator.r_top_rect.max.y});
		tt_op.ator.watch_value_rect = RectMinMax(.{tt_op.ator.watch_name_rect.max.x, text_op.ator.r_top_rect.min.y}, 
			.{6.244, text_op.ator.op_rect.max.y});
		tt_op.ator.watch_type_rect = RectMinMax(.{tt_op.ator.watch_value_rect.max.x,text_op.ator.r_top_rect.min.y}, 
			text_op.ator.r_top_rect.max);
		//TODO SETTINGS Take these from settings
		tt_op.name_proportion = TEXT_SPLIT_MIN;
		tt_op.type_proportion = 1.0 - 2*TEXT_SPLIT_MIN;
	}
	case 27; {
		AssertEquals(false, text_op.mouse_hovering_value_type_split_rect);
		AssertEquals(true, text_op.mouse_pressing_value_type_split_rect);
		AssertEquals(tt_op.ator.watch_name_rect.min, text_op.ator.watch_name_rect.min);
		AssertEquals(tt_op.ator.watch_name_rect.max, text_op.ator.watch_name_rect.max);
		AssertEquals(tt_op.ator.watch_value_rect.min, text_op.ator.watch_value_rect.min);
		AssertEquals(tt_op.ator.watch_value_rect.max, text_op.ator.watch_value_rect.max);
		AssertEquals(tt_op.ator.watch_type_rect.min, text_op.ator.watch_type_rect.min);
		AssertEquals(tt_op.ator.watch_type_rect.max, text_op.ator.watch_type_rect.max);
		AssertFloatEquals(tt_op.name_proportion, text_op.name_proportion);
		AssertFloatEquals(tt_op.type_proportion, text_op.type_proportion);

		//TEST Going over left for name should not change
		value_left : Vector2F = text_op.ator.r_top_rect.min;
		value_left.x -= 1;
		game_input.mouse_cam = OpSpaceToCameraSpace(value_left, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 28; {
		AssertEquals(false, text_op.mouse_hovering_value_type_split_rect);
		AssertEquals(true, text_op.mouse_pressing_value_type_split_rect);
		AssertEquals(tt_op.ator.watch_name_rect.min, text_op.ator.watch_name_rect.min);
		AssertEquals(tt_op.ator.watch_name_rect.max, text_op.ator.watch_name_rect.max);
		AssertEquals(tt_op.ator.watch_value_rect.min, text_op.ator.watch_value_rect.min);
		AssertEquals(tt_op.ator.watch_value_rect.max, text_op.ator.watch_value_rect.max);
		AssertEquals(tt_op.ator.watch_type_rect.min, text_op.ator.watch_type_rect.min);
		AssertEquals(tt_op.ator.watch_type_rect.max, text_op.ator.watch_type_rect.max);
		AssertFloatEquals(tt_op.name_proportion, text_op.name_proportion);
		AssertFloatEquals(tt_op.type_proportion, text_op.type_proportion);

		//TEST Going over right
		value_right : Vector2F = text_op.ator.r_top_rect.max;
		game_input.mouse_cam = OpSpaceToCameraSpace(value_right, op_space, op_2D_cam.world_pos, default_base_cam);

		tt_op.ator.watch_name_rect = RectMinMax(text_op.ator.r_top_rect.min, 
			.{5.352, text_op.ator.r_top_rect.max.y});
		tt_op.ator.watch_value_rect = RectMinMax(.{tt_op.ator.watch_name_rect.max.x, text_op.ator.r_top_rect.min.y}, 
			.{21.408, text_op.ator.op_rect.max.y});
		tt_op.ator.watch_type_rect = RectMinMax(.{tt_op.ator.watch_value_rect.max.x,text_op.ator.r_top_rect.min.y}, 
			text_op.ator.r_top_rect.max);
		//TODO SETTINGS Take these from settings
		tt_op.name_proportion = TEXT_SPLIT_MIN;
		tt_op.type_proportion = TEXT_SPLIT_MIN;
	}
	case 29; {
		AssertEquals(false, text_op.mouse_hovering_value_type_split_rect);
		AssertEquals(true, text_op.mouse_pressing_value_type_split_rect);
		AssertEquals(tt_op.ator.watch_name_rect.min, text_op.ator.watch_name_rect.min);
		AssertEquals(tt_op.ator.watch_name_rect.max, text_op.ator.watch_name_rect.max);
		AssertEquals(tt_op.ator.watch_value_rect.min, text_op.ator.watch_value_rect.min);
		AssertEquals(tt_op.ator.watch_value_rect.max, text_op.ator.watch_value_rect.max);
		AssertEquals(tt_op.ator.watch_type_rect.min, text_op.ator.watch_type_rect.min);
		AssertEquals(tt_op.ator.watch_type_rect.max, text_op.ator.watch_type_rect.max);
		AssertFloatEquals(tt_op.name_proportion, text_op.name_proportion);
		AssertFloatEquals(tt_op.type_proportion, text_op.type_proportion);

		//TEST Going over right for value should not change
		value_right : Vector2F = text_op.ator.r_top_rect.max;
		game_input.mouse_cam = OpSpaceToCameraSpace(value_right, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 30; {
		AssertEquals(false, text_op.mouse_hovering_value_type_split_rect);
		AssertEquals(false, text_op.mouse_pressing_value_type_split_rect);
		AssertEquals(tt_op.ator.watch_name_rect.min, text_op.ator.watch_name_rect.min);
		AssertEquals(tt_op.ator.watch_name_rect.max, text_op.ator.watch_name_rect.max);
		AssertEquals(tt_op.ator.watch_value_rect.min, text_op.ator.watch_value_rect.min);
		AssertEquals(tt_op.ator.watch_value_rect.max, text_op.ator.watch_value_rect.max);
		AssertEquals(tt_op.ator.watch_type_rect.min, text_op.ator.watch_type_rect.min);
		AssertEquals(tt_op.ator.watch_type_rect.max, text_op.ator.watch_type_rect.max);
		AssertFloatEquals(tt_op.name_proportion, text_op.name_proportion);
		AssertFloatEquals(tt_op.type_proportion, text_op.type_proportion);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TextAsmMouse :: (
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
		array_resize(*perm.test_data.all_sub_tests, 13);
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

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; AddTextBlock(COMPILE_TEXT_STRING, game_input);
	case 2; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);

		//TEST mouse press first asm line
		line_0 : Vector2F = GetTopLeft(text_op.ator.l_bottom_rect);
		line_0.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		line_0.x += (text_op.left_margin_char_width+1) * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_0, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);

		tt_op.start_disasm_index = 0;
		tt_op.end_disasm_index = 8;
		tt_op.highlighted_disasm_index = 0;
	}
	case 5; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_op.highlighted_disasm_index, text_op.highlighted_disasm_index);

		//TEST mouse press second asm line
		line_0 : Vector2F = GetTopLeft(text_op.ator.l_bottom_rect);
		line_0.y -= 1.5*text_op.ator.TEXT_LINE_HEIGHT;
		line_0.x += (text_op.left_margin_char_width+1) * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_0, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_op.highlighted_disasm_index = 1;
	}
	case 6; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_op.highlighted_disasm_index, text_op.highlighted_disasm_index);

		//TEST scroll mouse wheel down
		game_input.mouse_wheel -= 1;
		tt_op.start_disasm_index += 1;
		tt_op.end_disasm_index += 1;
	}
	case 7; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_op.highlighted_disasm_index, text_op.highlighted_disasm_index);

		//TEST scroll mouse wheel down 2
		game_input.mouse_wheel -= 2;
		tt_op.start_disasm_index += 2;
		tt_op.end_disasm_index += 2;
	}
	case 8; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_op.highlighted_disasm_index, text_op.highlighted_disasm_index);

		//TEST scroll mouse wheel up 1
		game_input.mouse_wheel += 1;
		tt_op.start_disasm_index -= 1;
		tt_op.end_disasm_index -= 1;
	}
	case 9; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_op.highlighted_disasm_index, text_op.highlighted_disasm_index);

		//TEST scroll mouse wheel up 2
		game_input.mouse_wheel += 2;
		tt_op.start_disasm_index -= 2;
		tt_op.end_disasm_index -= 2;
	}
	case 10; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_op.highlighted_disasm_index, text_op.highlighted_disasm_index);

		//TEST scroll mouse wheel up 2
		game_input.mouse_wheel -= 6;
		tt_op.start_disasm_index += 6;
		tt_op.end_disasm_index += 6;
	}
	case 11; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_op.highlighted_disasm_index, text_op.highlighted_disasm_index);

		//Test the moving arrow should adjust start and end index since the highlighted index is not visible
		DownUpThisFrame(.ARROW_UP, game_input);
		tt_op.highlighted_disasm_index = 0;
		tt_op.start_disasm_index = 0;
		tt_op.end_disasm_index = 8;
	}
	case 12; {
		AssertEquals(SelectedTextPane.DISASSEMBLY, text_op.selected_pane);
		AssertEquals(tt_op.start_disasm_index, text_op.start_disasm_index);
		AssertEquals(tt_op.end_disasm_index, text_op.end_disasm_index);
		AssertEquals(tt_op.highlighted_disasm_index, text_op.highlighted_disasm_index);

		//Test the moving arrow should 
		// DownUpThisFrame(.ARROW_DOWN, game_input);
		// tt_op.highlighted_disasm_index = 0;
		// tt_op.start_disasm_index = 0;
		// tt_op.end_disasm_index = 8;
	}
	}
	//TODO FROM HERE dissasembly and call stack with mouse click and remove double click

	ContinueTest(*perm.test_data);

} @ITest

Test_TextCallStackMouse :: (
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
		array_resize(*perm.test_data.all_sub_tests, 14);
	}

	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	tt_op : *TextOpSpaceData = *tt_data.test_text_op;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);
	}
	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}
	text_file : *TextFile;
	if perm.all_data.all_text_files.count > 0 {
		text_file = *perm.all_data.all_text_files[0];
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

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; AddTextBlock(TEST_RECURSE_STRING, game_input);
	case 2; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		AddWatchDataForTest(.["x"], text_op);
		CodeBPForTest(8, *text_op.exec_info.debug_info, text_op.text_comp_data, text_file.absolute_path_name);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		AssertEquals(SelectedTextPane.TEXT, text_op.selected_pane);

		cs_center : Vector2F = GetCenter(text_op.ator.r_bottom_rect);
		// cs_center.y -= 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		// cs_center.x += (text_op.left_margin_char_width+1) * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(cs_center, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);

		tt_op.highlighted_call_stack_index = 0;
		tt_op.start_call_stack_index = 0;
		tt_op.end_call_stack_index = 8;
	}
	case 6; {	
		AssertEquals(SelectedTextPane.CALL_STACK, text_op.selected_pane);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.highlighted_call_stack_index, text_op.highlighted_call_stack_index);
	}
	case 7; {
		//TEST go all the way down the recursion
		RunSubTestNTimes(20, *perm.test_data);
		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 8; {
		//TEST stop at recursion base case "return x";
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		count_equals := AssertEquals(11, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			for 1..text_op.exec_info.debug_info.debug_call_stack.count-1 {
				foo_frame := text_op.exec_info.debug_info.debug_call_stack[it];
				AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
				// AssertEquals(d_line.start_asm_index, foo_frame.function_scope.start_instr_index);
				// AssertEquals(d_line.end_asm_index, foo_frame.function_scope.end_instr_index);
				AssertEquals("foo", foo_frame.func_decl.name);
				AssertEquals(2, foo_frame.all_scopes_in_function.count);
				AssertEquals(1, foo_frame.call_open_scopes.count);

				count_equals = AssertEquals(1, foo_frame.frame_vars.count);
				if count_equals {
					var := foo_frame.frame_vars[0];
					AssertEquals("x", var.name);
					AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
					AssertEquals(foo_frame.function_scope.id, var.scope_id);
					AssertEquals(foo_frame.function_scope.function_id, var.function_id);

				}
			}

			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("10", x_watch.value_str);
		}

		//TEST pressing line 1 changes the call stack
		line_1 : Vector2F = text_op.ator.r_bottom_rect.max;
		line_1.y -= 1.5*text_op.ator.TEXT_LINE_HEIGHT;
		line_1.x -= 2 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_1, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_op.highlighted_call_stack_index = 1;
	}
	case 9; {
		AssertEquals(SelectedTextPane.CALL_STACK, text_op.selected_pane);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.highlighted_call_stack_index, text_op.highlighted_call_stack_index);

		//TEST check 1 stack frame down the recursion
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		AssertEquals(true, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(9, text_op.exec_info.debug_info.selected_call_frame_index);

		count_equals := AssertEquals(11, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("9", x_watch.value_str);
		}

		game_input.mouse_wheel -= 2;
		tt_op.start_call_stack_index += 2;
		tt_op.end_call_stack_index += 2;
	}
	case 10; {
		AssertEquals(SelectedTextPane.CALL_STACK, text_op.selected_pane);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.highlighted_call_stack_index, text_op.highlighted_call_stack_index);

		//Go to check the last foo
		second_last_line : Vector2F = text_op.ator.r_bottom_rect.min;
		second_last_line.y += 1.5*text_op.ator.TEXT_LINE_HEIGHT;
		second_last_line.x += 2*perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_last_line, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_op.highlighted_call_stack_index = 9;
	}
	case 11; {
		AssertEquals(SelectedTextPane.CALL_STACK, text_op.selected_pane);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.highlighted_call_stack_index, text_op.highlighted_call_stack_index);
		//TEST Stop at the last recursion and move the call stack ui
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//Selected call frame is array index BUT highlighted is rendering from the top so they should be inversed
		AssertEquals(true, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(text_op.exec_info.debug_info.debug_call_stack.count-1-tt_op.highlighted_call_stack_index, 
			text_op.exec_info.debug_info.selected_call_frame_index);

		count_equals := AssertEquals(11, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("1", x_watch.value_str);
		}

		last_line : Vector2F = text_op.ator.r_bottom_rect.min;
		last_line.y += 0.5*text_op.ator.TEXT_LINE_HEIGHT;
		last_line.x += 2*perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(last_line, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_op.highlighted_call_stack_index = 10;
	}
	case 12; {
		AssertEquals(SelectedTextPane.CALL_STACK, text_op.selected_pane);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.highlighted_call_stack_index, text_op.highlighted_call_stack_index);
		//TEST stop at main and move the call stack ui
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//Selected call frame is array index BUT highlighted is rendering from the top so they should be inversed
		AssertEquals(true, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(text_op.exec_info.debug_info.debug_call_stack.count-1-tt_op.highlighted_call_stack_index, 
			text_op.exec_info.debug_info.selected_call_frame_index);

		count_equals := AssertEquals(11, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("0", x_watch.value_str);
		}

		game_input.mouse_wheel += 2;
		tt_op.start_call_stack_index -= 2;
		tt_op.end_call_stack_index -= 2;
	}
	case 13; {
		AssertEquals(SelectedTextPane.CALL_STACK, text_op.selected_pane);
		AssertEquals(tt_op.start_call_stack_index, text_op.start_call_stack_index);
		AssertEquals(tt_op.end_call_stack_index, text_op.end_call_stack_index);
		AssertEquals(tt_op.highlighted_call_stack_index, text_op.highlighted_call_stack_index);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_GoToLine :: (
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
		array_resize(*perm.test_data.all_sub_tests, 41+1);
	}

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

	FIRST_LINE :: "FIRST LINE\n";
	LAST_LINE :: "LAST LINE";
	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		AddTextInput(FIRST_LINE, game_input);
	}
	case 2; {
		//TEST create 40 lines of text so we can goto a few times
		RunSubTestNTimes(39, *perm.test_data);
		AddTextBlock(TAB2_LINE, game_input);
		DownUpThisFrame(.ENTER, game_input);
	}
	case 3; {
		AddTextInput(LAST_LINE, game_input);
		DownUpThisFrame(.ENTER, game_input);
	}
	case 4; {
		//TEST that the goto line bar opens properly
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 5; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("Goto Line:", text_op.first_bar_name_text);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		AddTextInput("10", game_input);
		tt_op.first_bar_cursor.char_point = 2;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 6; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("10", text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);

		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TODO TEST the pressing enter closes the bar and resets the bar cursor
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_line_number = 10;
		tt_data.test_char_point = 11*TAB2_LINE.count;
		tt_data.test_line_char = 0;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 21;
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 7; {
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TODO FROM HERE test that we went to the correct line possibly with bounds and move around a few times
		//with edge cases and out of bounds cases and also do one with invalid text to decide the behavior on that
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);

		//TEST select and goto line should undo the selection
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.test_char_point += TAB2_LINE.count;
		tt_data.test_line_char = TAB2_LINE.count;
	}
	case 8; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//Test goto line does not affect text cursor also line index should shrink because of goto line bar
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}
	case 9; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST typing text in gotoline does not affect text cursor
		AddTextInput("5", game_input);
	}
	case 10; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST going to new line should remove the selection closing bar should increase end line index again
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_line_number = 5;
		tt_data.test_char_point = FIRST_LINE.count+(tt_data.test_line_number-1)*(1+TAB2_LINE.count);//1+ for all the \n
		tt_data.test_line_char = 0;
		tt_data.test_end_line_index += 1;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;
	}
	case 11; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.test_left_char_bound, text_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, text_cursor.right_char_bound);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST moving right char bound over and then gotoline should reset that and also line bounds
		DownUpThisFrame(.END, game_input);
	}
	case 12; {
		RunSubTestNTimes(5, *perm.test_data);
		AddTextBlock(TAB2_LINE, game_input);
	}
	case 13; {
		tt_data.test_line_number = 5;
		tt_data.test_char_point += 6*TAB2_LINE.count;
		tt_data.test_line_char = 6*TAB2_LINE.count;
		tt_data.test_left_char_bound += 1;
		tt_data.test_right_char_bound += 1;
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//opening gotoline with right and left char bounds should not change anything other then end line index
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}
	case 14; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST typing text in gotoline does not affect text cursor
		AddTextInput("25", game_input);
	}
	case 15; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);
		
		//TEST going to a new line below should reset char bouds and move line bounds as well
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_line_number = 25;
		//+5* is from the line with many tabs before
		tt_data.test_char_point = FIRST_LINE.count+(tt_data.test_line_number-1)*(1+TAB2_LINE.count)+5*TAB2_LINE.count;//1+ for all the \n
		tt_data.test_line_char = 0;
		//Cursor line at 25 is adjusted to be in between start and end line index
		tt_data.test_start_line_index = 15;
		tt_data.test_end_line_index = 36;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;
	}
	case 16; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST go to line and moving cursor with selection and out of bounds
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
		tt_op.first_bar_cursor.left_char_bound = 0;
		tt_op.first_bar_cursor.right_char_bound = 55;//this is less than the text line bounds because of the bar text on lhs
	}
	case 17; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
	} 
	case 18; {
		//TEST adding some lines with space so we can check undo and redo is working
		//ALSO tabs are unknown characters and will be displayed as such
		AddTextInput(TAB2_LINE, game_input);
		AddTextInput(" ", game_input);
		AddTextInput(TAB2_LINE, game_input);
		tt_op.first_bar_cursor.char_point += 2*TAB2_LINE.count+1;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 19; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   append(*sb, " ");
	   append(*sb, TAB2_LINE);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST undo with goto line bar
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point -= TAB2_LINE.count + 1;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 20; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST redo with goto line bar
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point += TAB2_LINE.count + 1;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 21; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   append(*sb, " ");
	   append(*sb, TAB2_LINE);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
	}
	case 22; {
		//TEST add tab2 line a few times to go over right char bound
		RunSubTestNTimes(4, *perm.test_data);
		AddTextInput(TAB2_LINE, game_input);
		AddTextInput(" ", game_input);
	}
	case 23; {
		tt_op.first_bar_cursor.char_point = 6*(TAB2_LINE.count+1)-1;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
		tt_op.first_bar_cursor.left_char_bound += 10;
		tt_op.first_bar_cursor.right_char_bound += 10;
	}
	case 24; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   append(*sb, " ");
	   append(*sb, TAB2_LINE);
	   for 0..3 {
		   append(*sb, TAB2_LINE);
		   append(*sb, " ");
		}
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST ctrl move arrow keys should work
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point -= 5;
		tt_op.first_bar_cursor.cursor_line_char -= 5;
	}
	case 25; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   append(*sb, " ");
	   append(*sb, TAB2_LINE);
	   for 0..3 {
		   append(*sb, TAB2_LINE);
		   append(*sb, " ");
		}
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST ctrl arrow right. need to do it twice since we stop at the tab
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
	}
	case 26; {
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point += 5;
		tt_op.first_bar_cursor.cursor_line_char += 5;		
	}
	case 27; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   append(*sb, " ");
	   append(*sb, TAB2_LINE);
	   for 0..3 {
		   append(*sb, TAB2_LINE);
		   append(*sb, " ");
		}
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST arrow rigth again does nto move anything since we are at the end
		DownUpThisFrame(.ARROW_RIGHT, .{ctrl_pressed=true}, game_input);
	}
	case 28; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   append(*sb, " ");
	   append(*sb, TAB2_LINE);
	   for 0..3 {
		   append(*sb, TAB2_LINE);
		   append(*sb, " ");
		}
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST shift press to home should highlight the whole line minus the first tab since we are at the end
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		tt_op.first_bar_cursor.fixed_select_char_point = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.fixed_select_line_char = tt_op.first_bar_cursor.cursor_line_char;
		tt_op.first_bar_cursor.char_point = 1;
		tt_op.first_bar_cursor.cursor_line_char = 1;
		tt_op.first_bar_cursor.left_char_bound -= 9;
		tt_op.first_bar_cursor.right_char_bound -= 9;
	}
	case 29; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   append(*sb, " ");
	   append(*sb, TAB2_LINE);
	   for 0..3 {
		   append(*sb, TAB2_LINE);
		   append(*sb, " ");
		}
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST shift press to home again to go to beginning of line
		DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point -= 1;
		tt_op.first_bar_cursor.cursor_line_char -= 1;
		tt_op.first_bar_cursor.left_char_bound -= 1;
		tt_op.first_bar_cursor.right_char_bound -= 1;
	}
	case 30; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		sb : String_Builder;
	   sb.allocator = temp;
	   append(*sb, TAB2_LINE);
	   append(*sb, " ");
	   append(*sb, TAB2_LINE);
	   for 0..3 {
		   append(*sb, TAB2_LINE);
		   append(*sb, " ");
		}
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST backspace should clear the whole line
		DownUpThisFrame(.BACKSPACE, game_input);
	}
	case 31; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, tt_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TEST input negative number
		AddTextInput("-1", game_input);
	}
	case 32; {
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_line_number = 0;
		//+5* is from the line with many tabs before
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		line_bound_diff : int = tt_data.test_end_line_index - tt_data.test_start_line_index;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = line_bound_diff;
	}
	case 33; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST out of bounds > than line count
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 34; {
		AddTextInput(tprint("%", text_file.file_string.file_loc.count + 10), game_input);
	}
	case 35; {
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_line_number = text_file.file_string.file_loc.count-1;
		tt_data.test_char_point = text_file.file_string.text_string.count;
		tt_data.test_line_char = 0;
		//> than total since we center at the bottom anyways since we can
		tt_data.test_start_line_index += 31;
		tt_data.test_end_line_index += 31;
	}
	case 36; {
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST invalid line number prints a text status message
		DownUpInputMap(.TEXT_FILE_GOTO_LINE_BAR, game_input);
	}
	case 37; {
		AddTextInput("test", game_input);
	}
	case 38; {
		DownUpThisFrame(.ENTER, game_input);
	}
	case 39; {
		AssertEquals(TextFirstBarType.GOTO_LINE, text_op.text_first_bar_type);
		AssertEquals(true, text_op.text_status_timer > 0);
		AssertEquals("Invalid goto line number.", text_op.text_status_message);

		//Test closing gotoline text bar
		DownUpThisFrame(.ESCAPE, game_input);
	}
	case 40; {
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals(0, text_op.first_bar_input_text.text_string.count);
		AssertEquals(0, text_op.first_bar_cursor.char_point);
		AssertEquals(0, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(0, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);

		//TEST that opening find is now clear
		DownUpInputMap(.TEXT_FILE_FIND_TEXT_BAR, game_input);
	}
	case 41; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(0, text_op.first_bar_input_text.text_string.count);
		AssertEquals(0, text_op.first_bar_cursor.char_point);
		AssertEquals(0, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(0, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);		
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

/*DOC : We should write somewhere for the user that we have to do 2 undos in order to do a full replace because
we only have add and remove actions so a replace is a remove and then an add so we need 2 undos for a replace
*/
Test_TextFindReplace :: (
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
		array_resize(*perm.test_data.all_sub_tests, 170+1);
	}

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

	FIRST_LINE :: "FIRST LINE\n";
	LAST_LINE :: "LAST LINE";
	FIRST_WORD : string = String.slice(FIRST_LINE, 0, 5);
	LINE_WORD :: "LINE";
	MY_TEST_WORD :: "\tMY TEST\n";
	MY_TEST_WORD_NO_NEWLINE := String.slice(MY_TEST_WORD, 0, MY_TEST_WORD.count-1);
	LAST_TEST :: "LAST \tMY TEST";

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, WRITE_TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		AddTextInput(FIRST_LINE, game_input);
	}
	case 2; {
		//TEST create 40 lines of text so we can find a few times
		RunSubTestNTimes(39, *perm.test_data);
		AddTextBlock(TAB2_LINE, game_input);
		DownUpThisFrame(.ENTER, game_input);
	}
	case 3; {
		AddTextInput(LAST_LINE, game_input);
		DownUpThisFrame(.ENTER, game_input);
	}
	case 4; {
		//TEST that the goto line bar opens properly
		DownUpInputMap(.TEXT_FILE_FIND_TEXT_BAR, game_input);
	}
	case 5; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find:", text_op.first_bar_name_text);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		AddTextInput(FIRST_WORD, game_input);
		tt_op.first_bar_cursor.char_point = FIRST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = FIRST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 6; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(FIRST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);

		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TODO TEST the pressing enter closes the bar and resets the bar cursor
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point = FIRST_WORD.count;
		tt_data.test_line_char = FIRST_WORD.count;
		tt_data.test_line_number = 0;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 20;
		tt_data.fixed_char_point = 0;
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number = 0;
	}
	case 7; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(FIRST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		//TODO FROM HERE test that we went to the correct line possibly with bounds and move around a few times
		//with edge cases and out of bounds cases and also do one with invalid text to decide the behavior on that
		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(FIRST_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST Find again but we don't have another FIRST so we don't change anything
		DownUpThisFrame(.ENTER, game_input);
	}
	case 8; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(FIRST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(FIRST_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//Test select all should select in find bar
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		tt_op.first_bar_cursor.char_point = FIRST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = FIRST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_number = 0;
		tt_op.first_bar_cursor.fixed_select_char_point = 0;
		tt_op.first_bar_cursor.fixed_select_line_char = 0;
		tt_op.first_bar_cursor.fixed_select_line_number = 0;
	}
	case 9; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(FIRST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);

		AddTextInput(LINE_WORD, game_input);
		tt_op.first_bar_cursor.char_point = LINE_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = LINE_WORD.count;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 10; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);

		//TEST search for line word on top and then bottom and then rotate back around
		DownUpThisFrame(.ENTER, game_input);
		tt_data.fixed_char_point = FIRST_WORD.count+1;
		tt_data.fixed_line_char = FIRST_WORD.count+1;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = FIRST_WORD.count+1+LINE_WORD.count;
		tt_data.test_line_char = FIRST_WORD.count+1+LINE_WORD.count;
		tt_data.test_line_number = 0;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 20;
	}
	case 11; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST search for line word on bottom and then rotate
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count-1;
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-2;
		tt_data.fixed_char_point = tt_data.test_char_point-LINE_WORD.count;
		tt_data.fixed_line_char = tt_data.test_line_char-LINE_WORD.count;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_start_line_index += 30;
		tt_data.test_end_line_index += 30;
	}
	case 12; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST search for line word on bottom and then rotate
		DownUpThisFrame(.ENTER, game_input);
		tt_data.fixed_char_point = FIRST_WORD.count+1;
		tt_data.fixed_line_char = FIRST_WORD.count+1;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = FIRST_WORD.count+1+LINE_WORD.count;
		tt_data.test_line_char = FIRST_WORD.count+1+LINE_WORD.count;
		tt_data.test_line_number = 0;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 20;
	}
	case 13; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST search for line word backwords back to end of file
		DownUpInputMap(.TEXT_FILE_BACK_FIND, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count-1;
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-2;
		tt_data.fixed_char_point = tt_data.test_char_point-LINE_WORD.count;
		tt_data.fixed_line_char = tt_data.test_line_char-LINE_WORD.count;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_start_line_index += 30;
		tt_data.test_end_line_index += 30;
	}
	case 14; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST search for line word backwords to start of file
		DownUpInputMap(.TEXT_FILE_BACK_FIND, game_input);
		tt_data.fixed_char_point = FIRST_WORD.count+1;
		tt_data.fixed_line_char = FIRST_WORD.count+1;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = FIRST_WORD.count+1+LINE_WORD.count;
		tt_data.test_line_char = FIRST_WORD.count+1+LINE_WORD.count;
		tt_data.test_line_number = 0;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 20;
	}
	case 15; {
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST open replace text bar should reduce line index by 1
		DownUpInputMap(.TEXT_FILE_REPLACE_TEXT_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}
	case 16; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST tab should switch to replace bar cursor
		DownUpThisFrame(.TAB, game_input);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char = 0;
		tt_op.second_bar_cursor.cursor_line_number = 0;
	}
	case 17; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST add replace text with a space and tab to see if that works on replace
		AddTextInput(MY_TEST_WORD, game_input);
		tt_op.second_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.second_bar_cursor.cursor_line_char = MY_TEST_WORD.count;
		tt_op.second_bar_cursor.cursor_line_number = 0;
	}
	case 18; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST pressing enter should do a find even with replace text bar selected
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count-1;
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-2;
		tt_data.fixed_char_point = tt_data.test_char_point-LINE_WORD.count;
		tt_data.fixed_line_char = tt_data.test_line_char-LINE_WORD.count;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_start_line_index += 30;
		tt_data.test_end_line_index += 30;
	}
	case 19; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		//TEST replace the word and rotate back to start
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.fixed_char_point = FIRST_WORD.count+1;
		tt_data.fixed_line_char = FIRST_WORD.count+1;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = FIRST_WORD.count+1+LINE_WORD.count;
		tt_data.test_line_char = FIRST_WORD.count+1+LINE_WORD.count;
		tt_data.test_line_number = 0;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 20-1;//-1 since we open the replace text bar
	}
	case 20; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(LINE_WORD, find_text);
		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);

		last_line_replace : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-3];
		AssertEquals(tprint("LAST %", MY_TEST_WORD_NO_NEWLINE), last_line_replace);

		//TEST replace the first word and then stop since we dont have anymore
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.test_char_point += MY_TEST_WORD.count-LINE_WORD.count;
		tt_data.test_line_char = 0; //went to newline
		tt_data.test_line_number += 1; //went to newline
	}
	case 21; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line_replace : string = text_file.file_string.file_loc[0];
		AssertEquals(tprint("FIRST %", MY_TEST_WORD_NO_NEWLINE), first_line_replace);

		//TEST pressing enter again should do nothing
		DownUpThisFrame(.ENTER, game_input);
	}
	case 22; {
		AssertEquals(true, text_op.text_status_timer > 0);

		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST swap find and replace to get back where we were
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		tt_op.second_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.second_bar_cursor.cursor_line_char = MY_TEST_WORD.count;
		tt_op.second_bar_cursor.cursor_line_number = 0;
		tt_op.second_bar_cursor.fixed_select_char_point = 0;
		tt_op.second_bar_cursor.fixed_select_line_char = 0;
		tt_op.second_bar_cursor.fixed_select_line_number = 0;
	}
	case 23; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST swap find and replace to get back where we were
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 24; DownUpThisFrame(.TAB, game_input);
	case 25; {
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		tt_op.first_bar_cursor.char_point = LINE_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = LINE_WORD.count;
		tt_op.first_bar_cursor.cursor_line_number = 0;
		tt_op.first_bar_cursor.fixed_select_char_point = 0;
		tt_op.first_bar_cursor.fixed_select_line_char = 0;
		tt_op.first_bar_cursor.fixed_select_line_number = 0;
	}
	case 26; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST swap find and replace to get back where we were
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = MY_TEST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 27; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST swap find and replace to get back where we were
		DownUpThisFrame(.TAB, game_input);
		tt_op.first_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = MY_TEST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 28; {
		AddTextInput(LINE_WORD, game_input);
		tt_op.second_bar_cursor.char_point = LINE_WORD.count;
		tt_op.second_bar_cursor.cursor_line_char = LINE_WORD.count;
		tt_op.second_bar_cursor.cursor_line_number = 0;
	}
	case 29; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(LINE_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST We should find and select the next value at the end here before replacing
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count-1;
		tt_data.test_line_char = 0;//new line
		tt_data.test_line_number = text_file.file_string.file_loc.count-2;
		tt_data.fixed_char_point = tt_data.test_char_point-MY_TEST_WORD.count;
		tt_data.fixed_line_char = 4+1;//"LAST"+1 for the space
		tt_data.fixed_line_number = tt_data.test_line_number-1;
		tt_data.test_start_line_index += 32;
		tt_data.test_end_line_index += 32;
	}
	case 30; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(LINE_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST We should replace the last one and rotate to the first one here
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.fixed_char_point = FIRST_WORD.count+1;
		tt_data.fixed_line_char = FIRST_WORD.count+1;
		tt_data.fixed_line_number = 0;
		tt_data.test_char_point = FIRST_LINE.count-LINE_WORD.count+MY_TEST_WORD.count-1;//-1 for \n
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 1;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 20-1;//-1 since we open the replace text bar
	}
	case 31; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(LINE_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		last_line_replace : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-2];
		AssertEquals(LAST_LINE, last_line_replace);

		//TEST We should replace the first one and find no more
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.test_char_point = FIRST_LINE.count-1;//-1 for \n
		tt_data.test_line_char = FIRST_LINE.count-1;//-1 for \n
		tt_data.test_line_number = 0;
	}
	case 32; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(LINE_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line_replace : string = text_file.file_string.file_loc[0];
		first_line_no_new_line : string = String.slice(FIRST_LINE,0,FIRST_LINE.count-1);
		AssertEquals(first_line_no_new_line, first_line_replace);

		//TEST We have no more so this should do nothing
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
	}
	case 33; {
		AssertEquals(true, text_op.text_status_timer > 0);

		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(LINE_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST multi-line replace and also test the multi-line is working with single line input
		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 34; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(LINE_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST multi-line replace and also test the multi-line is working with single line input
		DownUpThisFrame(.ARROW_RIGHT, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point;
		tt_data.fixed_line_char = tt_data.test_line_char;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_char_point = FIRST_LINE.count+2*(TAB2_LINE.count+1);//+1 for \n
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 3;
	}
	case 35; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(LINE_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST this should copy the multi-line text to the find bar properly and then we do a multi-line replace test
		DownUpInputMap(.TEXT_FILE_REPLACE_TEXT_BAR, game_input);
		tt_op.first_bar_cursor.char_point = 2*TAB2_LINE.count+3;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
		tt_op.first_bar_cursor.fixed_select_char_point = 0;
		tt_op.first_bar_cursor.fixed_select_line_char = 0;
		tt_op.first_bar_cursor.fixed_select_line_number = 0;
	}
	case 36; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(LINE_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST this should copy the multi-line text to the find bar properly and then we do a multi-line replace test
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 37; DownUpThisFrame(.TAB, game_input);
	case 38; DownUpInputMap(.TEXT_SELECT_ALL, game_input);
	case 39; {
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = 2*TAB2_LINE.count+3;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.second_bar_cursor.cursor_line_number = 0;
	}
	case 40; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST this should copy the multi-line text to the find bar properly and then we do a multi-line replace test
		for 0..4 DownUpThisFrame(.BACKSPACE, game_input);
		AddTextInput("test", game_input);
		tt_op.second_bar_cursor.char_point = 2*TAB2_LINE.count+2;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 41; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		replace_line : string = tprint("\n%\n\twith\ttest", TAB2_LINE);
		AssertEquals(replace_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

	   third_line_check : string = tprint("\twith\ttest%", TAB2_LINE);
		//TEST this should copy the multi-line text to the find bar properly and then we do a multi-line replace test
		//should replace this and then also find the new one below next
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.fixed_char_point = tt_data.test_char_point + TAB2_LINE.count - 1;//since we remove the \n
		tt_data.fixed_line_char = third_line_check.count;
		tt_data.fixed_line_number = tt_data.test_line_number-1;
		tt_data.test_char_point += FIRST_LINE.count+2*(TAB2_LINE.count+1)-1;//+1 for \n and -1 since we removed 1 \n
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 2;
	}
	case 42; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		replace_line : string = tprint("\n%\n\twith\ttest", TAB2_LINE);
		AssertEquals(replace_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//Check 3rd line changed properly with removal of \n and \t
		third_line : string = text_file.file_string.file_loc[2];
	   third_line_check : string = tprint("\twith\ttest%", TAB2_LINE);
		AssertEquals(third_line_check, third_line);

		//TEST undo and redo second bar and then first bar and then text in pane with \n and \t
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point -= 4;//remove "test"
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 43; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		replace_line : string = tprint("\n%\n\twith\t", TAB2_LINE);
		AssertEquals(replace_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo second bar and then first bar and then text in pane with \n and \t
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point += 5;//remove "test"
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 44; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		replace_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(replace_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST redo second bar and then first bar and then text in pane with \n and \t
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point -= 5;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 45; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		replace_line : string = tprint("\n%\n\twith\t", TAB2_LINE);
		AssertEquals(replace_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo second bar and then first bar and then text in pane with \n and \t
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point += 4;//add back "test"
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 46; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		replace_line : string = tprint("\n%\n\twith\ttest", TAB2_LINE);
		AssertEquals(replace_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo second bar and then first bar and then text in pane with \n and \t
		//NOTE THAT here we have to undo twice in order to get the replace back
		for 0..2 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 47; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo first bar
		DownUpThisFrame(.TAB, game_input);
	}
	case 48; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);

		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);

		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo first bar
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 49; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo first bar
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 50; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo first bar
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 51; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo first bar
		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = multi_line.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 52; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo first bar
		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 53; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST undo and redo first bar
		for 0..9 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count;
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-1;
		tt_data.fixed_char_point = tt_data.test_char_point - 4;
		tt_data.fixed_line_char = tt_data.test_line_char-4;
		tt_data.fixed_line_number = tt_data.test_line_number;
		tt_data.test_start_line_index = 30;
		tt_data.test_end_line_index = 49;
	}
	case 54; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		first_line_no_new_line : string = String.slice(FIRST_LINE,0,FIRST_LINE.count-1);
		AssertEquals(first_line_no_new_line, first_line);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-2];
		AssertEquals(LAST_LINE, last_line);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST with debug toggle to make sure it is in the right place and with breakpoint mouse pressing
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
		tt_data.test_end_line_index -= 9;
	}
	case 55; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST mouse on bars and do some single replace and find with debug and mouse
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		// first_bar_pos.x += 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = 0;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 56; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST mouse on bars check bounds crossing on both sides
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		tt_op.first_bar_cursor.char_point = multi_line.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
		tt_op.first_bar_cursor.left_char_bound = 0;
		tt_op.first_bar_cursor.right_char_bound = 31;
	}
	case 57; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST mouse on bars
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = 2*multi_line.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
		tt_op.first_bar_cursor.left_char_bound += 15;
		tt_op.first_bar_cursor.right_char_bound += 15;
	}
	case 58; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST selecting find bar cursor with mouse and moving over bounds
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		first_bar_pos.x -= 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 59; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST selecting find bar cursor with mouse and moving over bounds
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		// first_bar_pos.x += 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.fixed_select_char_point = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.fixed_select_line_char = tt_op.first_bar_cursor.cursor_line_char;
		tt_op.first_bar_cursor.fixed_select_line_number = 0;
		tt_op.first_bar_cursor.char_point = 15;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
	}
	case 60; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar left bound should move text
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		first_bar_pos.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point -= 1;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound -= 1;
		tt_op.first_bar_cursor.right_char_bound -= 1;
	}
	case 61; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar left bound by 2 chars
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		first_bar_pos.x -= 2 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point -= 2;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound -= 2;
		tt_op.first_bar_cursor.right_char_bound -= 2;
	}
	case 62; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar left bound till the end
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		first_bar_pos.x -= 15 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		char_bound_diff : int = tt_op.first_bar_cursor.right_char_bound - tt_op.first_bar_cursor.left_char_bound;
		tt_op.first_bar_cursor.right_char_bound = char_bound_diff;
		tt_op.first_bar_cursor.left_char_bound = 0;
	}
	case 63; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		find_text : string = GetSelectedText(text_op.first_bar_cursor, text_op.first_bar_input_text);
		AssertEquals(multi_line, find_text);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 64; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar left bound till the end
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		// first_bar_pos.x -= 10 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 65; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		//We need to -1 here since we leave 1 char at the end so we can see the end of the text in a single line more clearly
		first_bar_pos.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.fixed_select_char_point = 0;
		tt_op.first_bar_cursor.fixed_select_line_char = 0;
		tt_op.first_bar_cursor.char_point = 31;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound += 0;
		tt_op.first_bar_cursor.right_char_bound += 0;
	}
	case 66; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		first_bar_pos.x += 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point += 1;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound += 1;
		tt_op.first_bar_cursor.right_char_bound += 1;
	}
	case 67; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		first_bar_pos.x += 1.4 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point += 2;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound += 2;
		tt_op.first_bar_cursor.right_char_bound += 2;
	}
	case 68; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		first_bar_pos.x += 15 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point = multi_line.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound += 12;
		tt_op.first_bar_cursor.right_char_bound += 12;
	}
	case 69; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 70; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST copy and do undo redo and then quick same test on replace bar
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = multi_line.count/2;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound = 0;
		tt_op.first_bar_cursor.right_char_bound = 31;
	}
	case 71; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n", TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST copy and do undo redo and then quick same test on replace bar
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = 2*multi_line.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound += 15;
		tt_op.first_bar_cursor.right_char_bound += 15;
	}
	case 72; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST paste and then quick same test on replace bar
		DownUpThisFrame(.TAB,  game_input);
	}
	case 73; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST paste and then quick same test on replace bar
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = multi_line.count;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound = 15;
		tt_op.second_bar_cursor.right_char_bound = 31+15;
	}
	case 74; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST do right and left char bounds on replace as well
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound = 0;
		tt_op.second_bar_cursor.right_char_bound = 31;
	}
	case 75; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST do right and left char bounds on replace as well
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = multi_line.count;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound += 15;
		tt_op.second_bar_cursor.right_char_bound += 15;
	}
	case 76; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_char, text_op.first_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.first_bar_cursor.fixed_select_line_number, text_op.first_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST press mouse on right and go over left char bound and then do right char bound and then do a replace and replace all with debug mode
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		second_bar_pos.x -= 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 77; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST selecting find bar cursor with mouse and moving over bounds
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		// second_bar_pos.x += 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.fixed_select_char_point = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.fixed_select_line_char = tt_op.second_bar_cursor.cursor_line_char;
		tt_op.second_bar_cursor.fixed_select_line_number = 0;
		tt_op.second_bar_cursor.char_point = 15;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.cursor_line_number = 0;
	}
	case 78; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar left bound should move text
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		second_bar_pos.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point -= 1;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound -= 1;
		tt_op.second_bar_cursor.right_char_bound -= 1;
	}
	case 79; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar left bound by 2 chars
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		second_bar_pos.x -= 2 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point -= 2;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound -= 2;
		tt_op.second_bar_cursor.right_char_bound -= 2;
	}
	case 80; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar left bound till the end
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		second_bar_pos.x -= 12 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound -= 12;
		tt_op.second_bar_cursor.right_char_bound -= 12;
	}
	case 81; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		find_text : string = GetSelectedText(text_op.first_bar_cursor, text_op.first_bar_input_text);
		AssertEquals(multi_line, find_text);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 82; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar left bound till the end
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		// second_bar_pos.x -= 10 * perm.text_editor_data.code_font_1_char_width_world;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 83; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		second_bar_pos.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.fixed_select_char_point = 0;
		tt_op.second_bar_cursor.fixed_select_line_char = 0;
		tt_op.second_bar_cursor.char_point = 31;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound = 0;
		tt_op.second_bar_cursor.right_char_bound = 31;
	}
	case 84; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		second_bar_pos.x += 0.4 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point += 1;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound += 1;
		tt_op.second_bar_cursor.right_char_bound += 1;
	}
	case 85; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.first_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		second_bar_pos.x += 1.4 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point += 2;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound += 2;
		tt_op.second_bar_cursor.right_char_bound += 2;
	}
	case 86; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		second_bar_pos.x += 12 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point = multi_line.count;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound += 12;
		tt_op.second_bar_cursor.right_char_bound += 12;
	}
	case 87; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST do some simple replace with debug mode and then to replace all before checking
		//mouse on text bar without debug.
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 88; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(multi_line, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		AddTextBlock(MY_TEST_WORD, game_input);
		tt_op.second_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.left_char_bound = 0;
		tt_op.second_bar_cursor.right_char_bound = 31;
	}
	case 89; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		DownUpThisFrame(.TAB, game_input);
	}
	case 90; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		multi_line : string = tprint("\n%\n%\n\n%\n%\n", TAB2_LINE, TAB2_LINE, TAB2_LINE, TAB2_LINE);
		AssertEquals(multi_line, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST moving over find bar right bound till end and then over
		//TODO FROM HERE forgot to add char bounds in previous tests and also seems like charbounds
		//dont' go all the way to the left here. I THINK it's because of the new update char bounds
		//code maybe so let's check that maybe we remove it or just for single line
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		AddTextInput(TAB2_LINE, game_input);
		tt_op.first_bar_cursor.char_point = TAB2_LINE.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.left_char_bound = 0;
		tt_op.first_bar_cursor.right_char_bound = 31;
	}
	case 91; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(TAB2_LINE, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST replace should do a find in debug mode here
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.test_char_point = FIRST_LINE.count+TAB2_LINE.count;
		tt_data.test_line_char = TAB2_LINE.count;
		tt_data.test_line_number = 1;
		tt_data.fixed_char_point = tt_data.test_char_point - TAB2_LINE.count;
		tt_data.fixed_line_char = tt_data.test_line_char - TAB2_LINE.count;
		tt_data.fixed_line_number = 1;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 10;
	}
	case 92; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(TAB2_LINE, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(TAB2_LINE, find_text);

		//TEST replace should do a find in debug mode here
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.test_char_point += text_op.second_bar_input_text.text_string.count+1;//+1 for new line
		tt_data.test_line_char = text_op.second_bar_input_text.text_string.count+1;//+1 for new line
		tt_data.test_line_number += 2;
		tt_data.fixed_char_point += text_op.second_bar_input_text.text_string.count+1;//+1 for new line
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number += 2;
	}
	case 93; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(TAB2_LINE, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(TAB2_LINE, find_text);

		first_line : string = text_file.file_string.file_loc[1];
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, first_line);

		//TEST do a second replace in debug mode here
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
		tt_data.test_char_point += text_op.second_bar_input_text.text_string.count+1;//+1 for new line
		tt_data.test_line_char = text_op.second_bar_input_text.text_string.count+1;//+1 for new line
		tt_data.test_line_number += 2;
		tt_data.fixed_char_point += text_op.second_bar_input_text.text_string.count+1;//+1 for new line
		tt_data.fixed_line_char = 0;
		tt_data.fixed_line_number += 2;
	}
	case 94; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(TAB2_LINE, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		find_text : string = GetSelectedText(text_cursor, text_file.file_string);
		AssertEquals(TAB2_LINE, find_text);

		first_line : string = text_file.file_string.file_loc[3];
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, first_line);

		//TEST find line and make sure we go over bounds and then do replace all with line and then unreplace without debug
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		tt_op.second_bar_cursor.char_point = TAB2_LINE.count-1;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 95; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(TAB2_LINE, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_char_point, text_op.second_bar_cursor.fixed_select_char_point);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_char, text_op.second_bar_cursor.fixed_select_line_char);
		AssertEquals(tt_op.second_bar_cursor.fixed_select_line_number, text_op.second_bar_cursor.fixed_select_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST find line and make sure we go over bounds and then do replace all with line and then unreplace without debug
		AddTextInput(LINE_WORD, game_input);
		tt_op.first_bar_cursor.char_point = LINE_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 96; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST find line and make sure we go over bounds and then do replace all with line and then unreplace without debug
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count-1;//-1 for new line
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-2;
		tt_data.fixed_char_point = text_file.file_string.text_string.count - LINE_WORD.count-1;//-1 for new line
		tt_data.fixed_line_char = LAST_LINE.count - LINE_WORD.count;
		tt_data.fixed_line_number = text_file.file_string.file_loc.count-2;
		tt_data.test_start_line_index = 37;
		tt_data.test_end_line_index = tt_data.test_start_line_index+10;
	}
	case 97; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST find again should rotate back to start
		DownUpThisFrame(.ENTER, game_input);
		tt_data.test_char_point = FIRST_LINE.count-1;//-1 for new line
		tt_data.test_line_char = FIRST_LINE.count-1;
		tt_data.test_line_number = 0;
		tt_data.fixed_char_point = FIRST_LINE.count - LINE_WORD.count-1;//-1 for new line
		tt_data.fixed_line_char = tt_data.fixed_char_point;
		tt_data.fixed_line_number = 0;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = tt_data.test_start_line_index+10;
	}
	case 98; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.fixed_char_point, text_cursor.fixed_select_char_point);
		AssertEquals(tt_data.fixed_line_char, text_cursor.fixed_select_line_char);
		AssertEquals(tt_data.fixed_line_number, text_cursor.fixed_select_line_number);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		//TEST replace all in debug mode (we set replace all to go to end of file for now since we use replace without knowing exactly where)
		DownUpInputMap(.TEXT_FILE_REPLACE_ALL, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count + 
			2 * (text_op.second_bar_input_text.text_string.count - text_op.first_bar_input_text.text_string.count);
		tt_data.test_line_char = 0;
		tt_data.test_line_number = text_file.file_string.file_loc.count+1;//add+1 and also not -1 so 2 lines because both replacements have a new line
		tt_data.test_start_line_index = 35;
		tt_data.test_end_line_index = tt_data.test_start_line_index+10;
	}
	case 99; {
		AssertEquals(true, text_op.text_status_timer > 0);

		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		AssertEquals(tprint("FIRST %", MY_TEST_WORD_NO_NEWLINE), first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-3];
		AssertEquals(tprint("LAST %", MY_TEST_WORD_NO_NEWLINE), last_line);

		//TEST undo and redo the replace all
		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 100; {
		//we undo twice since we remove and add for the undo
		for 0..1 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 448;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = text_file.file_string.file_loc.count-3;
		tt_data.test_start_line_index = 38;
		tt_data.test_end_line_index = tt_data.test_start_line_index+10;
	}
	case 101; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		first_line_no_new_line : string = String.slice(FIRST_LINE,0,FIRST_LINE.count-1);
		AssertEquals(first_line_no_new_line, first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-2];
		AssertEquals(LAST_LINE, last_line);

		//TEST redo replace all in debug mode
		for 0..1 DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count + 
			2 * (text_op.second_bar_input_text.text_string.count - text_op.first_bar_input_text.text_string.count);
		tt_data.test_line_char = 0;
		tt_data.test_line_number = text_file.file_string.file_loc.count+1;//add+1 and also not -1 so 2 lines because both replacements have a new line
		tt_data.test_start_line_index = 35;
		tt_data.test_end_line_index = tt_data.test_start_line_index+10;
	}
	case 102; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		AssertEquals(tprint("FIRST %", MY_TEST_WORD_NO_NEWLINE), first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-3];
		AssertEquals(tprint("LAST %", MY_TEST_WORD_NO_NEWLINE), last_line);

		//TEST undo all changes from replace in debug mode
		for 0..6 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 449;
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-6;
		tt_data.test_start_line_index = 30;
		tt_data.test_end_line_index = tt_data.test_start_line_index+10;
	}
	case 103; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		first_line_no_new_line : string = String.slice(FIRST_LINE,0,FIRST_LINE.count-1);
		AssertEquals(first_line_no_new_line, first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(LAST_LINE, last_line);

		//TEST redo single replace in debug mode
		for 0..2 DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = FIRST_LINE.count + MY_TEST_WORD.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 2;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = tt_data.test_start_line_index+10;
	}
	case 104; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[1];
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, first_line);

		//TEST move out of debug mode and see if undo and redo still works
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
		tt_data.test_char_point = FIRST_LINE.count + MY_TEST_WORD.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 2;
		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = tt_data.test_start_line_index+19;
	}
	case 105; {
		AssertEquals(ExecutionMode.RUN, text_op.exec_info.exec_mode);

		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST undo single replace in debug mode
		for 0..2 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 449;
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-3;
		tt_data.test_start_line_index = 21;
		tt_data.test_end_line_index = tt_data.test_start_line_index+19;
	}
	case 106; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		first_line_no_new_line : string = String.slice(FIRST_LINE,0,FIRST_LINE.count-1);
		AssertEquals(first_line_no_new_line, first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(LAST_LINE, last_line);

		//TEST check all redos without debug mode
		for 0..6 DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 458;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = text_file.file_string.file_loc.count+4;
		tt_data.test_start_line_index = 26;
		tt_data.test_end_line_index = tt_data.test_start_line_index+19;
	}
	case 107; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		AssertEquals(tprint("FIRST %", MY_TEST_WORD_NO_NEWLINE), first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-3];
		AssertEquals(tprint("LAST %", MY_TEST_WORD_NO_NEWLINE), last_line);

		//TEST check all redos without debug mode
		for 0..6 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point = 449;
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number = text_file.file_string.file_loc.count-6;
		tt_data.test_start_line_index = 21;
		tt_data.test_end_line_index = tt_data.test_start_line_index+19;
	}
	case 108; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		first_line_no_new_line : string = String.slice(FIRST_LINE,0,FIRST_LINE.count-1);
		AssertEquals(first_line_no_new_line, first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(LAST_LINE, last_line);

		//TEST check mouse on find and replace bar with bounds
		DownUpInputMap(.TEXT_FILE_REPLACE_TEXT_BAR, game_input);
	}
	case 109; {
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		AddTextInput(MY_TEST_WORD, game_input);
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
		for 0..6 DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = 7 * MY_TEST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		tt_op.first_bar_cursor.cursor_line_number = 0;
		tt_op.first_bar_cursor.left_char_bound = 6;
		tt_op.first_bar_cursor.right_char_bound = tt_op.first_bar_cursor.char_point;
	}
	case 110; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		first_bar_pos.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 111; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		// first_bar_pos.x += 12 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point = tt_op.first_bar_cursor.left_char_bound;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
		// tt_op.first_bar_cursor.left_char_bound += 12;
		// tt_op.first_bar_cursor.right_char_bound += 12;
	}
	case 112; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds left side 2 chars
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		left_move : int = 1;
		first_bar_pos.x -= left_move * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point -= left_move;
		tt_op.first_bar_cursor.cursor_line_char -= left_move;
		tt_op.first_bar_cursor.left_char_bound -= left_move;
		tt_op.first_bar_cursor.right_char_bound -= left_move;
	}
	case 113; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds left side 2 chars
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		left_move : int = 5;
		first_bar_pos.x -= left_move * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char -= left_move;
		tt_op.first_bar_cursor.left_char_bound -= left_move;
		tt_op.first_bar_cursor.right_char_bound -= left_move;
	}
	case 114; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds left keep going even though were still off shoudl not move
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		left_move : int = 5;
		first_bar_pos.x -= left_move * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 115; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 116; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side
		first_bar_pos : Vector2F = text_op.ator.first_bar_input_text_pos;
		// first_bar_pos.x -= 2 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 117; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		first_bar_pos.x -= 2 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point = tt_op.first_bar_cursor.right_char_bound;
		tt_op.first_bar_cursor.cursor_line_char = tt_op.first_bar_cursor.char_point;
	}
	case 118; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		right_diff : int = 1;
		//We subtract here because we leave off by 1 char from the end so its 1.5-2 to the middle from the end rect
		first_bar_pos.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point += right_diff;
		tt_op.first_bar_cursor.cursor_line_char += right_diff;
		tt_op.first_bar_cursor.left_char_bound += right_diff;
		tt_op.first_bar_cursor.right_char_bound += right_diff;
	}
	case 119; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		right_diff : int = 5;
		first_bar_pos.x += right_diff * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.first_bar_cursor.char_point += right_diff;
		tt_op.first_bar_cursor.cursor_line_char += right_diff;
		tt_op.first_bar_cursor.left_char_bound += right_diff;
		tt_op.first_bar_cursor.right_char_bound += right_diff;
	}
	case 120; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side keep going to make sure it does not move
		first_bar_pos : Vector2F = text_op.ator.first_bar_text_rect.max;
		right_diff : int = 5;
		first_bar_pos.x += right_diff * perm.text_editor_data.code_font_1_char_width_world;
		first_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(first_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 121; {
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 122; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
		AssertEquals(builder_to_string(*sb), text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.first_bar_cursor.cursor_left_mouse_holding);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side keep going to make sure it does not move
		DownUpThisFrame(#char "C", .{ctrl_pressed=true}, game_input);
	}
	case 123; DownUpThisFrame(.TAB, game_input);
	case 124; {
		//TEST mouse on replace bar without debug mode
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		DownUpThisFrame(#char "V", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = 7 * MY_TEST_WORD.count;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		tt_op.second_bar_cursor.cursor_line_number = 0;
		tt_op.second_bar_cursor.left_char_bound = 6;
		tt_op.second_bar_cursor.right_char_bound = tt_op.second_bar_cursor.char_point;
	}
	case 125; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on replace bar with bounds
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		second_bar_pos.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 126; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		// second_bar_pos.x += 12 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point = tt_op.second_bar_cursor.left_char_bound;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
		// tt_op.second_bar_cursor.left_char_bound += 12;
		// tt_op.second_bar_cursor.right_char_bound += 12;
	}
	case 127; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds left side 2 chars
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		left_move : int = 1;
		second_bar_pos.x -= left_move * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point -= left_move;
		tt_op.second_bar_cursor.cursor_line_char -= left_move;
		tt_op.second_bar_cursor.left_char_bound -= left_move;
		tt_op.second_bar_cursor.right_char_bound -= left_move;
	}
	case 128; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds left side 2 chars
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		left_move : int = 5;
		second_bar_pos.x -= left_move * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char -= left_move;
		tt_op.second_bar_cursor.left_char_bound -= left_move;
		tt_op.second_bar_cursor.right_char_bound -= left_move;
	}
	case 129; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds left keep going even though were still off shoudl not move
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		left_move : int = 5;
		second_bar_pos.x -= left_move * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 130; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 131; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side
		second_bar_pos : Vector2F = text_op.ator.second_bar_input_text_pos;
		// second_bar_pos.x -= 2 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 132; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		second_bar_pos.x -= 2 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point = tt_op.second_bar_cursor.right_char_bound;
		tt_op.second_bar_cursor.cursor_line_char = tt_op.second_bar_cursor.char_point;
	}
	case 133; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		right_diff : int = 1;
		//We subtract here because we leave off by 1 char from the end so its 1.5-2 to the middle from the end rect
		second_bar_pos.x -= 1 * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point += right_diff;
		tt_op.second_bar_cursor.cursor_line_char += right_diff;
		tt_op.second_bar_cursor.left_char_bound += right_diff;
		tt_op.second_bar_cursor.right_char_bound += right_diff;
	}
	case 134; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		right_diff : int = 5;
		second_bar_pos.x += right_diff * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		tt_op.second_bar_cursor.char_point += right_diff;
		tt_op.second_bar_cursor.cursor_line_char += right_diff;
		tt_op.second_bar_cursor.left_char_bound += right_diff;
		tt_op.second_bar_cursor.right_char_bound += right_diff;
	}
	case 135; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side keep going to make sure it does not move
		second_bar_pos : Vector2F = text_op.ator.second_bar_text_rect.max;
		right_diff : int = 5;
		second_bar_pos.x += right_diff * perm.text_editor_data.code_font_1_char_width_world;
		second_bar_pos.y -= 0.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(second_bar_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 136; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(true, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST check mouse on find bar with bounds right side keep going to make sure it does not move
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 137; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test block and undo and redo to make sure bounds change on replace and find bar
		AddTextBlock(MY_TEST_WORD, game_input);
		tt_op.second_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.second_bar_cursor.cursor_line_char = MY_TEST_WORD.count;
		tt_op.second_bar_cursor.left_char_bound = 0;
		tt_op.second_bar_cursor.right_char_bound = 57;
	}
	case 138; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		for 0..1 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = bar_text.count;
		tt_op.second_bar_cursor.cursor_line_char = bar_text.count;
		tt_op.second_bar_cursor.left_char_bound += 6;
		tt_op.second_bar_cursor.right_char_bound += 6;
	}
	case 139; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST undo and redo to make sure bounds change on replace and find bar
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char = 0;
		tt_op.second_bar_cursor.left_char_bound -= 6;
		tt_op.second_bar_cursor.right_char_bound -= 6;
	}
	case 140; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = bar_text.count;
		tt_op.second_bar_cursor.cursor_line_char = bar_text.count;
		tt_op.second_bar_cursor.left_char_bound += 6;
		tt_op.second_bar_cursor.right_char_bound += 6;
	}
	case 141; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		//We go home twice to skip over the tab at the beginning as well
		for 0..1 DownUpThisFrame(.HOME, game_input);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char = 0;
		tt_op.second_bar_cursor.left_char_bound -= 6;
		tt_op.second_bar_cursor.right_char_bound -= 6;
	}
	case 142; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		tt_op.second_bar_cursor.char_point = bar_text.count;
		tt_op.second_bar_cursor.cursor_line_char = bar_text.count;
		tt_op.second_bar_cursor.left_char_bound += 6;
		tt_op.second_bar_cursor.right_char_bound += 6;
	}
	case 143; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(bar_text, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		DownUpThisFrame(.BACKSPACE, game_input);
		tt_op.second_bar_cursor.char_point = 0;
		tt_op.second_bar_cursor.cursor_line_char = 0;
		tt_op.second_bar_cursor.left_char_bound -= 6;
		tt_op.second_bar_cursor.right_char_bound -= 6;
	}
	case 144; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.second_bar_cursor.cursor_is_selecting);
		AssertEquals(false, text_op.second_bar_cursor.cursor_left_mouse_holding);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		DownUpThisFrame(.TAB, game_input);
	}
	case 145; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
	}
	case 146; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.second_bar_cursor.left_char_bound, text_op.second_bar_cursor.left_char_bound);
		AssertEquals(tt_op.second_bar_cursor.right_char_bound, text_op.second_bar_cursor.right_char_bound);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test block and undo and redo to make sure bounds change on replace and find bar
		AddTextBlock(MY_TEST_WORD, game_input);
		tt_op.first_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = MY_TEST_WORD.count;
		tt_op.first_bar_cursor.left_char_bound = 0;
		tt_op.first_bar_cursor.right_char_bound = 57;
	}
	case 147; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(MY_TEST_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		for 0..1 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = bar_text.count;
		tt_op.first_bar_cursor.cursor_line_char = bar_text.count;
		tt_op.first_bar_cursor.left_char_bound += 6;
		tt_op.first_bar_cursor.right_char_bound += 6;
	}
	case 148; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST undo and redo to make sure bounds change on replace and find bar
		//Need to undo a few times here because we copy pasted it a few times
		for 0..6 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = 0;
		tt_op.first_bar_cursor.left_char_bound -= 6;
		tt_op.first_bar_cursor.right_char_bound -= 6;
	}
	case 149; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		//Redo a few times here since we had to undo it a few times before
		for 0..6 DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = bar_text.count;
		tt_op.first_bar_cursor.cursor_line_char = bar_text.count;
		tt_op.first_bar_cursor.left_char_bound += 6;
		tt_op.first_bar_cursor.right_char_bound += 6;
	}
	case 150; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		//We go home twice to skip over the tab at the beginning as well
		for 0..1 DownUpThisFrame(.HOME, game_input);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = 0;
		tt_op.first_bar_cursor.left_char_bound -= 6;
		tt_op.first_bar_cursor.right_char_bound -= 6;
	}
	case 151; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		tt_op.first_bar_cursor.char_point = bar_text.count;
		tt_op.first_bar_cursor.cursor_line_char = bar_text.count;
		tt_op.first_bar_cursor.left_char_bound += 6;
		tt_op.first_bar_cursor.right_char_bound += 6;
	}
	case 152; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		sb : String_Builder;
	   sb.allocator = temp;
	   for 0..6 append(*sb, MY_TEST_WORD);
	   bar_text : string = builder_to_string(*sb);
		AssertEquals(bar_text, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test pase and undo and redo to make sure bounds change on replace and find bar
		DownUpThisFrame(.BACKSPACE, game_input);
		tt_op.first_bar_cursor.char_point = 0;
		tt_op.first_bar_cursor.cursor_line_char = 0;
		tt_op.first_bar_cursor.left_char_bound -= 6;
		tt_op.first_bar_cursor.right_char_bound -= 6;
	}
	case 153; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals("", text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test replace all without debug mode
		AddTextInput(LINE_WORD, game_input);
		tt_op.first_bar_cursor.char_point = LINE_WORD.count;
		tt_op.first_bar_cursor.cursor_line_char = LINE_WORD.count;
	}
	case 154; DownUpThisFrame(.TAB, game_input);
	case 155; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals("", text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test replace all without debug mode
		AddTextBlock(MY_TEST_WORD, game_input);
		tt_op.second_bar_cursor.char_point = MY_TEST_WORD.count;
		tt_op.second_bar_cursor.cursor_line_char = MY_TEST_WORD.count;
	}
	case 156; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		//TEST test replace all without debug mode
		//this should just do a find since were not highlighting
		DownUpInputMap(.TEXT_FILE_REPLACE_ALL, game_input);
		tt_data.test_char_point += 2 * (MY_TEST_WORD.count - LINE_WORD.count);
		tt_data.test_line_char = 0;
		tt_data.test_line_number += 2; //We add 2 lines since there are 2 newlines in the replace all
		tt_data.test_start_line_index += 2;
		tt_data.test_end_line_index += 2;
	}
	case 157; {
		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 158; {
		AssertEquals(true, text_op.text_status_timer > 0);

		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		AssertEquals(tprint("FIRST %", MY_TEST_WORD_NO_NEWLINE), first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-2];
		AssertEquals(tprint("LAST %", MY_TEST_WORD_NO_NEWLINE), last_line);

		//TEST test undo replace all without debug mode
		//need to undo twice so that we do both the remove and add back
		for 0..1 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point -= 2 * (MY_TEST_WORD.count - LINE_WORD.count);
		tt_data.test_line_char = LAST_LINE.count;
		tt_data.test_line_number -= 2; //We add 2 lines since there are 2 newlines in the replace all
		tt_data.test_start_line_index = 30;
		tt_data.test_end_line_index = tt_data.test_start_line_index+19;
	}
	case 159; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		first_line : string = text_file.file_string.file_loc[0];
		first_line_no_new_line : string = String.slice(FIRST_LINE,0,FIRST_LINE.count-1);
		AssertEquals(first_line_no_new_line, first_line);

		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(LAST_LINE, last_line);

		//TEST left and right char bounds work with replace on and off
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		for 0..5 {
			AddTextInput(" ", game_input);
			AddTextBlock(LAST_LINE, game_input);
		}
		tt_data.test_char_point += 6 * (1 + LAST_LINE.count);//1+ for the space
		tt_data.test_line_char += 6 * (1 + LAST_LINE.count);
	}
	case 160; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		multi_last : string = tprint("% % % % % % %", LAST_LINE, LAST_LINE, LAST_LINE, LAST_LINE, LAST_LINE, LAST_LINE, LAST_LINE);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(multi_last, last_line);

		DownUpThisFrame(.HOME, game_input);
		tt_data.test_char_point -= 7*(1 + LAST_LINE.count) - 1;//1+ for the space, -1 since we dont have a space at the beginning
		tt_data.test_line_char = 0;
	}
	case 161; {		
		replace_rect_center := GetCenter(text_op.ator.second_bar_text_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(replace_rect_center, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 162; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);

		DownUpThisFrame(.BACKSPACE, game_input);
		tt_op.second_bar_cursor.char_point -= 1;
		tt_op.second_bar_cursor.cursor_line_char -= 1;
	}
	case 163; {
		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		multi_last : string = tprint("% % % % % % %", LAST_LINE, LAST_LINE, LAST_LINE, LAST_LINE, LAST_LINE, LAST_LINE, LAST_LINE);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(multi_last, last_line);

		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
	}
	case 164; {
		RunSubTestNTimes(4, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_SINGLE_REPLACE, game_input);
	}
	case 165; {
		tt_data.test_char_point = 505;
		tt_data.test_line_char = 65;
		tt_data.fixed_char_point = tt_data.test_char_point - LINE_WORD.count;
		tt_data.fixed_line_char = tt_data.test_line_char - LINE_WORD.count;
		tt_data.test_left_char_bound = 5;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + 64;

		AssertEquals(SelectedTextBarType.SELECTED_SECOND_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find   :", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(tt_op.first_bar_cursor.char_point, text_op.first_bar_cursor.char_point);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_char, text_op.first_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.first_bar_cursor.cursor_line_number, text_op.first_bar_cursor.cursor_line_number);
		AssertEquals(tt_op.first_bar_cursor.left_char_bound, text_op.first_bar_cursor.left_char_bound);
		AssertEquals(tt_op.first_bar_cursor.right_char_bound, text_op.first_bar_cursor.right_char_bound);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.REPLACE_TEXT, text_op.text_second_bar_type);
		AssertEquals("Replace:", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, text_op.second_bar_input_text.text_string);
		AssertEquals(tt_op.second_bar_cursor.char_point, text_op.second_bar_cursor.char_point);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_char, text_op.second_bar_cursor.cursor_line_char);
		AssertEquals(tt_op.second_bar_cursor.cursor_line_number, text_op.second_bar_cursor.cursor_line_number);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.test_left_char_bound, text_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, text_cursor.right_char_bound);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		multi_last : string = tprint("% % % % % % %", LAST_TEST, LAST_TEST, LAST_TEST, LAST_TEST, LAST_LINE, LAST_LINE, LAST_LINE);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(multi_last, last_line);

		//TEST close find bars and make sure that left and right char bounds stay the same
		DownUpThisFrame(.ESCAPE, game_input);
		tt_data.test_end_line_index += 2;
	}
	case 166; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.NONE, text_op.text_first_bar_type);
		AssertEquals("", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(false, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, text_op.second_bar_input_text.text_string);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.test_left_char_bound, text_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, text_cursor.right_char_bound);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		multi_last : string = tprint("% % % % % % %", LAST_TEST, LAST_TEST, LAST_TEST, LAST_TEST, LAST_LINE, LAST_LINE, LAST_LINE);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(multi_last, last_line);

		//TEST open find bar and make sure that left and right char bounds are good
		DownUpInputMap(.TEXT_FILE_FIND_TEXT_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}
	case 167; {
		AssertEquals(SelectedTextBarType.SELECTED_FIRST_BAR, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find:", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, text_op.second_bar_input_text.text_string);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.test_left_char_bound, text_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, text_cursor.right_char_bound);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		multi_last : string = tprint("% % % % % % %", LAST_TEST, LAST_TEST, LAST_TEST, LAST_TEST, LAST_LINE, LAST_LINE, LAST_LINE);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(multi_last, last_line);

		//TEST close find bars and make sure that left and right char bounds are good
		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 168; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find:", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, text_op.second_bar_input_text.text_string);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.test_left_char_bound, text_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, text_cursor.right_char_bound);
		AssertEquals(true, text_cursor.cursor_is_selecting);

		multi_last : string = tprint("% % % % % % %", LAST_TEST, LAST_TEST, LAST_TEST, LAST_TEST, LAST_LINE, LAST_LINE, LAST_LINE);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(multi_last, last_line);

		//TEST close find bars and make sure that left and right char bounds are good
		DownUpThisFrame(.HOME, game_input);
		tt_data.test_char_point -= 5*(1+LAST_TEST.count)-1-4;//-4 is for the extra line or last word i think
		tt_data.test_line_char = 0;
		tt_data.test_left_char_bound -= 5;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + 64;
	}
	case 169; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find:", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, text_op.second_bar_input_text.text_string);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.test_left_char_bound, text_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, text_cursor.right_char_bound);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		multi_last : string = tprint("% % % % % % %", LAST_TEST, LAST_TEST, LAST_TEST, LAST_TEST, LAST_LINE, LAST_LINE, LAST_LINE);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(multi_last, last_line);

		//TEST close find bars and make sure that left and right char bounds are good
		DownUpThisFrame(.END, game_input);
		tt_data.test_char_point = text_file.file_string.text_string.count;
		tt_data.test_line_char += 4*(1+LAST_TEST.count) + 3*(1+LAST_LINE.count) - 1;//-1 because no space at beginning
		tt_data.test_left_char_bound += 25;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + 64;
	}
	case 170; {
		AssertEquals(SelectedTextBarType.NONE, text_op.selected_text_bar);
		AssertEquals(TextFirstBarType.FIND_TEXT, text_op.text_first_bar_type);
		AssertEquals("Find:", text_op.first_bar_name_text);
		AssertEquals(LINE_WORD, text_op.first_bar_input_text.text_string);
		AssertEquals(true, text_op.first_bar_cursor.cursor_is_selecting);
		AssertEquals(TextSecondBarType.NONE, text_op.text_second_bar_type);
		AssertEquals("", text_op.second_bar_name_text);
		AssertEquals(MY_TEST_WORD_NO_NEWLINE, text_op.second_bar_input_text.text_string);

		AssertEquals(tt_data.test_char_point, text_cursor.char_point);
		AssertEquals(tt_data.test_line_char, text_cursor.cursor_line_char);
		AssertEquals(tt_data.test_line_number, text_cursor.cursor_line_number);
		AssertEquals(tt_data.test_start_line_index, text_cursor.start_file_line_index);
		AssertEquals(tt_data.test_end_line_index, text_cursor.end_file_line_index);
		AssertEquals(tt_data.test_left_char_bound, text_cursor.left_char_bound);
		AssertEquals(tt_data.test_right_char_bound, text_cursor.right_char_bound);
		AssertEquals(false, text_cursor.cursor_is_selecting);

		multi_last : string = tprint("% % % % % % %", LAST_TEST, LAST_TEST, LAST_TEST, LAST_TEST, LAST_LINE, LAST_LINE, LAST_LINE);
		last_line : string = text_file.file_string.file_loc[text_file.file_string.file_loc.count-1];
		AssertEquals(multi_last, last_line);

		//TEST close find bars and make sure that left and right char bounds are good
		// DownUpThisFrame(.END, game_input);
		// tt_data.test_char_point = text_file.file_string.text_string.count;
		// tt_data.test_line_char += 4*(1+LAST_TEST.count) + 3*LAST_LINE.count;
		// tt_data.test_left_char_bound += 10;
		// tt_data.test_right_char_bound = tt_data.test_left_char_bound + 64;
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

AssertTabCursor :: (tt_data : TextTestData, cursor : TextCursor) {
	AssertEquals(tt_data.test_char_point, cursor.char_point, "char_point");
	AssertEquals(tt_data.test_line_char, cursor.cursor_line_char, "cursor_line_char");
	AssertEquals(tt_data.test_line_number, cursor.cursor_line_number, "cursor_line_number");
	AssertEquals(tt_data.test_start_line_index, cursor.start_file_line_index, "start_file_line_index");
	AssertEquals(tt_data.test_end_line_index, cursor.end_file_line_index, "end_file_line_index");
	AssertEquals(tt_data.test_left_char_bound, cursor.left_char_bound, "left_char_bound");
	AssertEquals(tt_data.test_right_char_bound, cursor.right_char_bound, "right_char_bound");
}

Test_TextTabs :: (
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
		array_resize(*perm.test_data.all_sub_tests, 119+1);

		main_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		//TODO I think it's best to do this manually in the test in case we change how do it in-game later
		//We could use the text op save file eventually but maybe best to leave this as is
		load_file, load_success := LoadTextFile("c_test/write_test", *perm.all_data.all_text_files);
		if load_success {
			//TODO Should we do this in LoadTextFile?
			// array_add(*perm.all_data.all_text_files, load_file);
		}
		lf_1 := LoadTextFile("c_test/write_test_1", *perm.all_data.all_text_files);
		lf_2 := LoadTextFile("c_test/write_test_2", *perm.all_data.all_text_files);
		lf_3 := LoadTextFile("c_test/write_test_3", *perm.all_data.all_text_files);
		lf_4 := LoadTextFile("c_test/write_test_4", *perm.all_data.all_text_files);
		lf_5 := LoadTextFile("c_test/write_test_5", *perm.all_data.all_text_files);
		bound_test := LoadTextFile("c_test/bound_test", *perm.all_data.all_text_files);

		text_op := CreateTextOpSpace(.[main_file.id, load_file.id, lf_1.id, lf_2.id, lf_3.id, lf_4.id, lf_5.id, bound_test.id],
			// main_file.id, load_file.id, lf_1.id, lf_2.id, lf_3.id, lf_4.id, lf_5.id, bound_test.id,
			// main_file.id, load_file.id, lf_1.id, lf_2.id, lf_3.id, lf_4.id, lf_5.id, bound_test.id,
			// main_file.id, load_file.id, lf_1.id, lf_2.id, lf_3.id, lf_4.id, lf_5.id, bound_test.id,
			// main_file.id, load_file.id, lf_1.id, lf_2.id, lf_3.id, lf_4.id, lf_5.id, bound_test.id],
			perm.text_editor_data, renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	}

main_string :: #string DONE
#load "c_test/utest";
main :: () {
  x := Foo(0);
}
DONE;
// load_string :: #string DONE
// Foo :: (x : int) -> int {
//   return x + 1;
// }
// DONE;

	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	tt_op : *TextOpSpaceData = *tt_data.test_text_op;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(8, perm.all_data.all_text_files.count);
	}
	text_op : *TextOpSpaceData;
	ftab_cursor : TextCursor;
	ftab : TextTab;
	ftab_string : string;
	ftab_file : *TextFile;
	bound_test_string : string;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
		if text_op.file_tabs.count > 0 {
			ftab = text_op.file_tabs[text_op.ftab_i];
			ftab_cursor = ftab.tab_cursor;
			if perm.all_data.all_text_files.count > 0 {
				ftab_file = ArrayFindFirstByNameId(perm.all_data.all_text_files, ftab.text_file_id, "id");
				ftab_string = ftab_file.file_string.text_string;
				//Do it this way so when we close it then we don't crash the test
				for perm.all_data.all_text_files if it.file_short_name == "bound_test" {
					bound_test_string = it.file_string.text_string;
				}
			}
		}
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

	//TODO REMOVE this if not used OR pull out from other test if needed to reuse
	// FIRST_LINE :: "FIRST LINE\n";
	// LAST_LINE :: "LAST LINE";
	// FIRST_WORD : string = String.slice(FIRST_LINE, 0, 5);
	// LINE_WORD :: "LINE";
	// MY_TEST_WORD :: "\tMY TEST\n";
	// MY_TEST_WORD_NO_NEWLINE := String.slice(MY_TEST_WORD, 0, MY_TEST_WORD.count-1);
	// LAST_TEST :: "LAST \tMY TEST";

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	file_tab_op_rects : [] Rectangle2 = CreateFileTabOpRects(text_op);
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);

		tt_data.test_start_line_index = 0;
		tt_data.test_end_line_index = 21;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;
	}
	case 1; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);

		//TEST OPEN text file tabs should decrease line index
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}
	case 2; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);

		//TEST Close file tab should add the line bound index back
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index += 1;
	}
	case 3; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);

		//TEST open tabs again to continue test
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}
	case 4; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);

		AddTextBlock(main_string, game_input);
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
	}
	case 5; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 6; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(1, text_op.ftab_i);
	}
	case 7; {
		//TEST going around should bring us back to zero on the right
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 8; {
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_number = 4;

		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST going around LEFT should wrap around
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);

		tt_data.test_char_point = 0;
		tt_data.test_line_number = 0;
	}
	case 9; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(text_op.file_tabs.count-1, text_op.ftab_i);

		//TEST move arrow down so that we can check it stays changed later
		for 0..1 DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.END, game_input);
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 25;
		tt_data.test_right_char_bound += 25;
	}
	case 10; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(text_op.file_tabs.count-1, text_op.ftab_i);
	}
	case 11; {
		//TEST move arrow down so that we can check it stays changed later
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	}
	case 12; {
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;

		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST file tabs left and right with top bar closed
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index += 1;
	}
	case 13; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 14; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(1, text_op.ftab_i);
	}
	case 15; {
		//TEST going around should bring us back to zero on the right
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 16; {
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;

		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST going around LEFT should wrap around
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);

		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 25;
		tt_data.test_right_char_bound += 25;	
	}
	case 17; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(text_op.file_tabs.count-1, text_op.ftab_i);
	}
	case 18; {
		//TEST move arrow down so that we can check it stays changed later
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	}
	case 19; {
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;

		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST moving file tabs with top bar closed
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}	
	case 20; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST shift file tabs
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
		tt_op.ftab_i += 1;
	}
	case 21; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);
	}
	case 22; {
		//TEST shift file tabs to end
		RunSubTestNTimes(text_op.file_tabs.count-2, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
		tt_op.ftab_i += 1;
	}
	case 23; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST shifting one more time to the right should do nothing since we are at the end
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
	}
	case 24; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		tt_op.ftab_i -= 1;
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 25;
		tt_data.test_right_char_bound += 25;	
	}
	case 25; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_op.ftab_i += 1;
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;
	}
	case 26; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);
	}
	case 27; {
		//TEST shift file tabs left back to start
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_LEFT, game_input);
		tt_op.ftab_i -= 1;
	}
	case 28; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST one more left to make sure nothing changes
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_LEFT, game_input);
	}
	case 29; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		tt_op.ftab_i = text_op.file_tabs.count-1;
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 25;
		tt_data.test_right_char_bound += 25;	
	}
	case 30; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST back to start so we can test swapping without bar open
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_op.ftab_i = 0;
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;
	}
	case 31; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST tab swapping without bar open
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index += 1;
	}
	case 32; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);
	}
	case 33; {
		//TEST shift file tabs to end
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
		tt_op.ftab_i += 1;
	}
	case 34; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST shifting one more time to the right should do nothing since we are at the end
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
	}
	case 35; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		tt_op.ftab_i -= 1;
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 25;
		tt_data.test_right_char_bound += 25;	
	}
	case 36; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_op.ftab_i += 1;
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64;
	}
	case 37; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);
	}
	case 38; {
		//TEST shift file tabs left back to start
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_LEFT, game_input);
		tt_op.ftab_i -= 1;
	}
	case 39; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST one more left to make sure nothing changes
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_LEFT, game_input);
	}
	case 40; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		tt_op.ftab_i = text_op.file_tabs.count-1;
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 25;
		tt_data.test_right_char_bound += 25;	
	}
	case 41; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST back to start so we can test swapping without bar open
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_op.ftab_i = 0;
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = tt_data.test_left_char_bound + 64;
	}
	case 42; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST swap to debug mode and do all same tests again and then do mouse tabs and swapping
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
		tt_data.test_end_line_index -= 9;
		tt_data.test_right_char_bound -= 29;
	}
	case 43; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(ExecutionMode.DEBUG, text_op.exec_info.exec_mode);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}
	case 44; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(ExecutionMode.DEBUG, text_op.exec_info.exec_mode);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 45; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(1, text_op.ftab_i);
	}
	case 46; {
		//TEST going around should bring us back to zero on the right
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 47; {
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_number = 4;

		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST going around LEFT should wrap around
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	}
	case 48; {
		//TEST go back to end to bring cursor in bounds again
		DownUpThisFrame(.END, game_input);
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 54;
		tt_data.test_right_char_bound += 54;
	}
	case 49; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(text_op.file_tabs.count-1, text_op.ftab_i);
	}
	case 50; {
		//TEST move arrow down so that we can check it stays changed later
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	}
	case 51; {
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64-29;

		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST file tabs left and right with top bar closed
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index += 1;
	}
	case 52; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_data.test_char_point = 0;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 0;
	}
	case 53; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(1, text_op.ftab_i);
	}
	case 54; {
		//TEST going around should bring us back to zero on the right
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 55; {
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64-29;

		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST going around LEFT should wrap around
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);

		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 54;
		tt_data.test_right_char_bound += 54;	
	}
	case 56; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(text_op.file_tabs.count-1, text_op.ftab_i);
	}
	case 57; {
		//TEST move arrow down so that we can check it stays changed later
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	}
	case 58; {
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64-29;

		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST moving file tabs with top bar closed
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}	
	case 59; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(0, text_op.ftab_i);

		//TEST shift file tabs
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
		tt_op.ftab_i += 1;
	}
	case 60; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);
	}
	case 61; {
		//TEST shift file tabs to end
		RunSubTestNTimes(text_op.file_tabs.count-2, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
		tt_op.ftab_i += 1;
	}
	case 62; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST shifting one more time to the right should do nothing since we are at the end
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
	}
	case 63; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		tt_op.ftab_i -= 1;
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 54;
		tt_data.test_right_char_bound += 54;	
	}
	case 64; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_op.ftab_i += 1;
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64-29;
	}
	case 65; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);
	}
	case 66; {
		//TEST shift file tabs left back to start
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_LEFT, game_input);
		tt_op.ftab_i -= 1;
	}
	case 67; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST one more left to make sure nothing changes
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_LEFT, game_input);
	}
	case 68; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		tt_op.ftab_i = text_op.file_tabs.count-1;
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 54;
		tt_data.test_right_char_bound += 54;	
	}
	case 69; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST back to start so we can test swapping without bar open
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_op.ftab_i = 0;
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64-29;
	}
	case 70; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST tab swapping without bar open
		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index += 1;
	}
	case 71; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);
	}
	case 72; {
		//TEST shift file tabs to end
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
		tt_op.ftab_i += 1;
	}
	case 73; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST shifting one more time to the right should do nothing since we are at the end
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_RIGHT, game_input);
	}
	case 74; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		tt_op.ftab_i -= 1;
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 54;
		tt_data.test_right_char_bound += 54;	
	}
	case 75; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_op.ftab_i += 1;
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64-29;
	}
	case 76; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);
	}
	case 77; {
		//TEST shift file tabs left back to start
		RunSubTestNTimes(text_op.file_tabs.count-1, *perm.test_data);
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_LEFT, game_input);
		tt_op.ftab_i -= 1;
	}
	case 78; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST one more left to make sure nothing changes
		DownUpInputMap(.TEXT_FILE_TAB_SWAP_LEFT, game_input);
	}
	case 79; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST check left tab to make sure we have cursor in the right tab and cursor
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		tt_op.ftab_i = text_op.file_tabs.count-1;
		tt_data.test_char_point = bound_test_string.count;
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_left_char_bound += 54;
		tt_data.test_right_char_bound += 54;	
	}
	case 80; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST back to start so we can test swapping without bar open
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
		tt_op.ftab_i = 0;
		tt_data.test_char_point = main_string.count;
		tt_data.test_line_char = 0;
		tt_data.test_line_number = 4;
		tt_data.test_left_char_bound = 0;
		tt_data.test_right_char_bound = 64-29;
	}
	case 81; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(ExecutionMode.DEBUG, text_op.exec_info.exec_mode);
		AssertEquals(TextTopBarType.NONE, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		DownUpInputMap(.TEXT_FILE_TAB_BAR, game_input);
		tt_data.test_end_line_index -= 1;
	}
	case 82; {
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(TextTopBarType.TEXT_FILE_TABS, text_op.text_top_bar_type);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(tt_op.ftab_i, text_op.ftab_i);

		//TEST moving the tab with the mouse
		tab_0_pos : Vector2F = GetCenter(file_tab_op_rects[0]);
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_0_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 83; {
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(0, text_op.mouse_hovering_tab_i);

		//TEST moving the tab with the mouse
		tab_0_pos : Vector2F = GetCenter(file_tab_op_rects[0]);
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_0_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 84; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(0, text_op.mouse_hovering_tab_i);
		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[0].tab_cursor);
		AssertEquals(1, text_op.file_tabs[1].text_file_id);
		AssertEquals(0, text_op.file_tabs[1].tab_cursor.char_point);


		//TEST moving the tab with the mouse we go right before the end of the next tab
		tab_1_swap_pos : Vector2F = file_tab_op_rects[1].max;
		tab_1_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_1_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 85; {
		AssertEquals(1, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(1, text_op.mouse_hovering_tab_i);
		AssertEquals(1, text_op.file_tabs[0].text_file_id);
		AssertEquals(0, text_op.file_tabs[0].tab_cursor.char_point);
		AssertEquals(0, text_op.file_tabs[1].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[1].tab_cursor);

		//TEST moving the tab with the mouse
		tab_2_swap_pos : Vector2F = file_tab_op_rects[2].max;
		tab_2_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_2_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 86; {
		AssertEquals(2, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(2, text_op.mouse_hovering_tab_i);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(0, text_op.file_tabs[1].tab_cursor.char_point);
		AssertEquals(0, text_op.file_tabs[2].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[2].tab_cursor);

		//TEST moving the tab with the mouse
		tab_3_swap_pos : Vector2F = file_tab_op_rects[3].max;
		tab_3_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_3_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 87; {
		AssertEquals(3, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(3, text_op.mouse_hovering_tab_i);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(0, text_op.file_tabs[2].tab_cursor.char_point);
		AssertEquals(0, text_op.file_tabs[3].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[3].tab_cursor);

		//TEST moving the tab with the mouse
		tab_4_swap_pos : Vector2F = file_tab_op_rects[4].max;
		tab_4_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_4_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 88; {
		AssertEquals(4, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(4, text_op.mouse_hovering_tab_i);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(0, text_op.file_tabs[3].tab_cursor.char_point);
		AssertEquals(0, text_op.file_tabs[4].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[4].tab_cursor);

		//TEST moving the tab with the mouse
		tab_5_swap_pos : Vector2F = file_tab_op_rects[5].max;
		tab_5_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_5_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 89; {
		AssertEquals(5, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(5, text_op.mouse_hovering_tab_i);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(0, text_op.file_tabs[4].tab_cursor.char_point);
		AssertEquals(0, text_op.file_tabs[5].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[5].tab_cursor);

		//TEST moving the tab with the mouse skip over 2 tabs
		tab_7_swap_pos : Vector2F = file_tab_op_rects[7].max;
		tab_7_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_7_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 90; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(7, text_op.mouse_hovering_tab_i);
		AssertTabCursor(tt_data, text_op.file_tabs[7].tab_cursor);
		AssertEquals(8, file_tab_op_rects.count);

		AssertEquals(1, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(6, text_op.file_tabs[5].text_file_id);
		AssertEquals(7, text_op.file_tabs[6].text_file_id);
		AssertEquals(0, text_op.file_tabs[7].text_file_id);

		//TEST going over the add tab rect
		tab_6_swap_pos : Vector2F = file_tab_op_rects[7].max;
		tab_6_swap_pos.x += 0.5*GetWidth(text_op.ator.add_file_tab_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_6_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 91; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(-1, text_op.mouse_hovering_tab_i);
		AssertEquals(0, text_op.file_tabs[7].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[7].tab_cursor);
		AssertEquals(8, file_tab_op_rects.count);

		//TEST going over the right should do nothing
		tab_6_swap_pos : Vector2F = file_tab_op_rects[7].max;
		tab_6_swap_pos.x += GetWidth(text_op.ator.add_file_tab_rect)+1.0;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_6_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 92; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(false, text_op.mouse_hovering_top_bar);
		AssertEquals(-1, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs[6].text_file_id);
		#if OS == .WINDOWS AssertEquals(103, text_op.file_tabs[6].tab_cursor.char_point);
		else #if OS == .MACOS AssertEquals(101, text_op.file_tabs[6].tab_cursor.char_point);
		AssertEquals(0, text_op.file_tabs[7].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[7].tab_cursor);
		AssertEquals(8, file_tab_op_rects.count);

		//TEST moving the tab with the mouse to the left
		tab_6_swap_pos : Vector2F = file_tab_op_rects[6].min;
		tab_6_swap_pos.x += 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_6_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 93; {
		AssertEquals(6, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(6, text_op.mouse_hovering_tab_i);
		AssertEquals(0, text_op.file_tabs[6].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[6].tab_cursor);

		AssertEquals(1, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(6, text_op.file_tabs[5].text_file_id);
		AssertEquals(0, text_op.file_tabs[6].text_file_id);
		AssertEquals(7, text_op.file_tabs[7].text_file_id);

		//TEST moving the tab with the mouse to the left by 2
		tab_4_swap_pos : Vector2F = file_tab_op_rects[4].min;
		tab_4_swap_pos.x += 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_4_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 94; {
		AssertEquals(4, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(4, text_op.mouse_hovering_tab_i);
		AssertEquals(0, text_op.file_tabs[4].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[4].tab_cursor);

		AssertEquals(1, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(0, text_op.file_tabs[4].text_file_id);
		AssertEquals(5, text_op.file_tabs[5].text_file_id);
		AssertEquals(6, text_op.file_tabs[6].text_file_id);
		AssertEquals(7, text_op.file_tabs[7].text_file_id);


		//TEST moving the tab with the mouse to the left
		tab_0_swap_pos : Vector2F = file_tab_op_rects[0].min;
		tab_0_swap_pos.x += 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_0_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 95; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(0, text_op.mouse_hovering_tab_i);
		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[0].tab_cursor);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(1, text_op.file_tabs[1].text_file_id);
		AssertEquals(2, text_op.file_tabs[2].text_file_id);
		AssertEquals(3, text_op.file_tabs[3].text_file_id);
		AssertEquals(4, text_op.file_tabs[4].text_file_id);
		AssertEquals(5, text_op.file_tabs[5].text_file_id);
		AssertEquals(6, text_op.file_tabs[6].text_file_id);
		AssertEquals(7, text_op.file_tabs[7].text_file_id);

		//TEST going over the left should do nothing
		tab_0_swap_pos : Vector2F = file_tab_op_rects[0].min;
		tab_0_swap_pos.x -= 1.0;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_0_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 96; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(false, text_op.mouse_hovering_top_bar);
		AssertEquals(-1, text_op.mouse_hovering_tab_i);
		AssertTabCursor(tt_data, text_op.file_tabs[0].tab_cursor);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(1, text_op.file_tabs[1].text_file_id);
		AssertEquals(2, text_op.file_tabs[2].text_file_id);
		AssertEquals(3, text_op.file_tabs[3].text_file_id);
		AssertEquals(4, text_op.file_tabs[4].text_file_id);
		AssertEquals(5, text_op.file_tabs[5].text_file_id);
		AssertEquals(6, text_op.file_tabs[6].text_file_id);
		AssertEquals(7, text_op.file_tabs[7].text_file_id);

		//TEST close tab in debug mode and then reopen twice to make sure it only opens once
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 97; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(false, text_op.mouse_hovering_top_bar);
		AssertEquals(-1, text_op.mouse_hovering_tab_i);
		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertTabCursor(tt_data, text_op.file_tabs[0].tab_cursor);

		//TEST close tab in debug mode and then reopen twice to make sure it only opens once
		close_tab_1_rect : Rectangle2 = GetFileTabXRect(file_tab_op_rects[1], perm.text_editor_data.code_font_1_char_width_world);
		close_tab_1_pos : Vector2F = GetCenter(close_tab_1_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(close_tab_1_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 98; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(1, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs.count);

		//TEST reopen twice to make sure it only opens once
		abs_path := get_absolute_path("c_test/write_test");
		OpenFileTab(abs_path, text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
		count_equals := AssertEquals(8, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.file_tabs[7].text_file_id);
			AssertEquals(0, text_op.file_tabs[0].text_file_id);
			//Make sure we only open this up here once
			OpenFileTab(abs_path, text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
			AssertEquals(8, text_op.file_tabs.count);
			AssertEquals(1, text_op.file_tabs[7].text_file_id);
			AssertEquals(0, text_op.file_tabs[0].text_file_id);
		}
	}
	case 99; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(1, text_op.mouse_hovering_tab_i);
		AssertEquals(8, text_op.file_tabs.count);

		//TEST Do the same mouse and close and open without debug and also check 
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	}
	case 100; {
		AssertEquals(ExecutionMode.RUN, text_op.exec_info.exec_mode);
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(1, text_op.mouse_hovering_tab_i);
		AssertEquals(8, text_op.file_tabs.count);

		//TEST moving the tab with the mouse not in debug mode
		tab_6_pos : Vector2F = GetCenter(file_tab_op_rects[6]);
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_6_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 101; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(6, text_op.mouse_hovering_tab_i);

		//TEST moving the tab with the mouse
		tab_6_pos : Vector2F = GetCenter(file_tab_op_rects[6]);
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_6_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		#if OS == .WINDOWS {
		tt_data.test_char_point = 103;
		} else #if OS == .MACOS {
		tt_data.test_char_point = 101;
		}
		tt_data.test_line_char = 80;
		tt_data.test_line_number = 2;
		tt_data.test_end_line_index = 20;
		tt_data.test_left_char_bound = 54;
		tt_data.test_right_char_bound = 118;
	}
	case 102; {
		AssertEquals(6, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(6, text_op.mouse_hovering_tab_i);
		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(7, text_op.file_tabs[6].text_file_id);
		AssertTabCursor(tt_data, ftab_cursor);


		//TEST moving the tab with the mouse we go right before the end of the next tab
		tab_5_swap_pos : Vector2F = file_tab_op_rects[5].min;
		tab_5_swap_pos.x += 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_5_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 103; {
		AssertEquals(5, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(5, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs[5].text_file_id);
		AssertTabCursor(tt_data, ftab_cursor);

		//TEST moving the tab with the mouse 2 tabs
		tab_3_swap_pos : Vector2F = file_tab_op_rects[3].min;
		tab_3_swap_pos.x += 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_3_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 104; {
		AssertEquals(3, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(3, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs[3].text_file_id);
		AssertTabCursor(tt_data, ftab_cursor);

		//TEST moving the tab with the mouse all the way over
		tab_3_swap_pos : Vector2F = file_tab_op_rects[0].min;
		tab_3_swap_pos.x += 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_3_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 105; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(0, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs[0].text_file_id);
		AssertTabCursor(tt_data, ftab_cursor);

		//TEST moving the tab with the mouse
		tab_0_swap_pos : Vector2F = file_tab_op_rects[0].min;
		tab_0_swap_pos.x += 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_0_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 106; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(0, text_op.mouse_hovering_tab_i);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(8, file_tab_op_rects.count);

		AssertEquals(7, text_op.file_tabs[0].text_file_id);
		AssertEquals(0, text_op.file_tabs[1].text_file_id);
		AssertEquals(2, text_op.file_tabs[2].text_file_id);
		AssertEquals(3, text_op.file_tabs[3].text_file_id);
		AssertEquals(4, text_op.file_tabs[4].text_file_id);
		AssertEquals(5, text_op.file_tabs[5].text_file_id);
		AssertEquals(6, text_op.file_tabs[6].text_file_id);
		AssertEquals(1, text_op.file_tabs[7].text_file_id);

		//TEST going over the left should do nothing
		over_left_pos : Vector2F = file_tab_op_rects[0].min;
		over_left_pos.x -= 1.0;
		game_input.mouse_cam = OpSpaceToCameraSpace(over_left_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 107; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(false, text_op.mouse_hovering_top_bar);
		AssertEquals(-1, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs[0].text_file_id);
		AssertTabCursor(tt_data, ftab_cursor);
		AssertEquals(8, file_tab_op_rects.count);

		//TEST moving the tab with the mouse to the right without debug mode
		tab_1_swap_pos : Vector2F = file_tab_op_rects[1].max;
		tab_1_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_1_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 108; {
		AssertEquals(1, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(1, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs[1].text_file_id);
		AssertTabCursor(tt_data, ftab_cursor);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(7, text_op.file_tabs[1].text_file_id);
		AssertEquals(2, text_op.file_tabs[2].text_file_id);
		AssertEquals(3, text_op.file_tabs[3].text_file_id);
		AssertEquals(4, text_op.file_tabs[4].text_file_id);
		AssertEquals(5, text_op.file_tabs[5].text_file_id);
		AssertEquals(6, text_op.file_tabs[6].text_file_id);
		AssertEquals(1, text_op.file_tabs[7].text_file_id);

		//TEST moving the tab with the mouse to the right by 2
		tab_3_swap_pos : Vector2F = file_tab_op_rects[3].max;
		tab_3_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_3_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 109; {
		AssertEquals(3, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(3, text_op.mouse_hovering_tab_i);
		AssertTabCursor(tt_data, ftab_cursor);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(7, text_op.file_tabs[3].text_file_id);
		AssertEquals(4, text_op.file_tabs[4].text_file_id);
		AssertEquals(5, text_op.file_tabs[5].text_file_id);
		AssertEquals(6, text_op.file_tabs[6].text_file_id);
		AssertEquals(1, text_op.file_tabs[7].text_file_id);


		//TEST moving the tab with the mouse to the right all the way
		tab_7_swap_pos : Vector2F = file_tab_op_rects[7].max;
		tab_7_swap_pos.x -= 0.1;
		game_input.mouse_cam = OpSpaceToCameraSpace(tab_7_swap_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 110; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(7, text_op.mouse_hovering_tab_i);
		AssertTabCursor(tt_data, ftab_cursor);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(6, text_op.file_tabs[5].text_file_id);
		AssertEquals(1, text_op.file_tabs[6].text_file_id);
		AssertEquals(7, text_op.file_tabs[7].text_file_id);

		//TEST going over the add tab rect
		add_tab_pos : Vector2F = file_tab_op_rects[7].max;
		add_tab_pos.x += 0.5*GetWidth(text_op.ator.add_file_tab_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(add_tab_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 111; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(-1, text_op.mouse_hovering_tab_i);
		AssertTabCursor(tt_data, ftab_cursor);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(6, text_op.file_tabs[5].text_file_id);
		AssertEquals(1, text_op.file_tabs[6].text_file_id);
		AssertEquals(7, text_op.file_tabs[7].text_file_id);

		//TEST going over the right end should do nothing
		over_right_pos : Vector2F = file_tab_op_rects[7].max;
		over_right_pos.x += GetWidth(text_op.ator.add_file_tab_rect) + 1.0;
		game_input.mouse_cam = OpSpaceToCameraSpace(over_right_pos, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 112; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(true, text_op.mouse_holding_ftab);
		AssertEquals(false, text_op.mouse_hovering_top_bar);
		AssertEquals(-1, text_op.mouse_hovering_tab_i);
		AssertTabCursor(tt_data, ftab_cursor);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(6, text_op.file_tabs[5].text_file_id);
		AssertEquals(1, text_op.file_tabs[6].text_file_id);
		AssertEquals(7, text_op.file_tabs[7].text_file_id);

		//TEST close tab in debug mode and then reopen twice to make sure it only opens once
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	}
	case 113; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(false, text_op.mouse_hovering_top_bar);
		AssertEquals(-1, text_op.mouse_hovering_tab_i);
		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(52, text_op.file_tabs[0].tab_cursor.char_point);
		AssertEquals(7, text_op.file_tabs[7].text_file_id);
		AssertTabCursor(tt_data, ftab_cursor);

		//TEST close tab in debug mode and then reopen twice to make sure it only opens once
		close_tab_7_rect : Rectangle2 = GetFileTabXRect(file_tab_op_rects[7], perm.text_editor_data.code_font_1_char_width_world);
		close_tab_7_pos : Vector2F = GetCenter(close_tab_7_rect);
		game_input.mouse_cam = OpSpaceToCameraSpace(close_tab_7_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 114; {
		AssertEquals(6, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(7, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs.count);

		//TEST reopen twice to make sure it only opens once
		abs_path := get_absolute_path("c_test/bound_test");
		OpenFileTab(abs_path, text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
		count_equals := AssertEquals(8, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(7, text_op.file_tabs[7].text_file_id);
			AssertEquals(0, text_op.file_tabs[0].text_file_id);
			//Make sure we only open this up here once
			OpenFileTab(abs_path, text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
			AssertEquals(8, text_op.file_tabs.count);
			AssertEquals(7, text_op.file_tabs[7].text_file_id);
			AssertEquals(0, text_op.file_tabs[0].text_file_id);
		}

		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	}
	case 115; {
		AssertEquals(6, text_op.ftab_i);
		AssertEquals(1, text_op.file_tabs[6].text_file_id);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(7, text_op.mouse_hovering_tab_i);
		AssertEquals(8, text_op.file_tabs.count);

		//TEST close tab with shortcut and make sure reopening is at the same place
		AddTextInput("test", game_input);
	}
	case 116; {
		AssertEquals(true, ftab_file.file_string.not_saved_text_edit);
		AssertEquals(6, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(7, text_op.mouse_hovering_tab_i);
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(4, ftab_cursor.char_point);

		//TEST close tab with shortcut and make sure reopening is at the same place
		DownUpInputMap(.TEXT_FILE_TAB_CLOSE, game_input);
	}
	case 117; {
		AssertEquals(5, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(7, text_op.mouse_hovering_tab_i);
		AssertEquals(7, text_op.file_tabs.count);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(6, text_op.file_tabs[5].text_file_id);
		AssertEquals(7, text_op.file_tabs[6].text_file_id);

		//TEST reopen twice to make sure it only opens once
		abs_path := get_absolute_path("c_test/write_test");
		OpenFileTab(abs_path, text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
		count_equals := AssertEquals(8, text_op.file_tabs.count);
		if count_equals {
			AssertEquals(1, text_op.file_tabs[7].text_file_id);
			AssertEquals(0, text_op.file_tabs[0].text_file_id);
			//Make sure we only open this up here once
			OpenFileTab(abs_path, text_op, *perm.all_data.all_text_files, op_space, perm.text_editor_data);
			AssertEquals(8, text_op.file_tabs.count);
			AssertEquals(1, text_op.file_tabs[7].text_file_id);
			AssertEquals(0, text_op.file_tabs[0].text_file_id);
		}
	}
	case 118; {
		AssertEquals(7, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(7, text_op.mouse_hovering_tab_i);
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(true, ftab_file.file_string.not_saved_text_edit);
		AssertEquals(0, ftab_cursor.char_point);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(6, text_op.file_tabs[5].text_file_id);
		AssertEquals(7, text_op.file_tabs[6].text_file_id);
		AssertEquals(1, text_op.file_tabs[7].text_file_id);

		//TEST that the first file did not change and the cursor did not move after all this tab stuff
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 119; {
		AssertEquals(0, text_op.ftab_i);
		AssertEquals(false, text_op.mouse_holding_ftab);
		AssertEquals(true, text_op.mouse_hovering_top_bar);
		AssertEquals(7, text_op.mouse_hovering_tab_i);
		AssertEquals(8, text_op.file_tabs.count);
		AssertEquals(true, ftab_file.file_string.not_saved_text_edit);
		AssertEquals(52, ftab_cursor.char_point);

		AssertEquals(0, text_op.file_tabs[0].text_file_id);
		AssertEquals(2, text_op.file_tabs[1].text_file_id);
		AssertEquals(3, text_op.file_tabs[2].text_file_id);
		AssertEquals(4, text_op.file_tabs[3].text_file_id);
		AssertEquals(5, text_op.file_tabs[4].text_file_id);
		AssertEquals(6, text_op.file_tabs[5].text_file_id);
		AssertEquals(7, text_op.file_tabs[6].text_file_id);
		AssertEquals(1, text_op.file_tabs[7].text_file_id);

		//TEST that the first file did not change
		// DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
	}
	}
	//TODO should we put a cap on the number of tabs that can be open? Maybe like 20 for now just to avoid issues
	//Or do we add scrolling tabs or do we do that later?
	//TODO FROM HERE if we save a file, then we have to update the cursor everywhere else
	//to the line number or clamped which we are already doing for reload. If we reload
	//then we reload all files, but if we save we don't want to reload the particular file we saved from
	//since that one is ok. Then we also don't reload the text file on save
	//So we should call SaveTextFile directly from the save command and put the save command
	//in text op space data.
	//ALSO don't load a file twice in the same op space to avoid issues.
	//BUT we can load the same file twice in separate op spaces which creates a similar thing to what we have in sublime text right now
	//Should test this by opening another text op space and adding a line and then saving and making
	//sure the cursor is good in both op spaces BUT IF we already have a tab open with that file in that space then just go to that tab.
	//I think we can update this in OpenFileTabWithExplorer so that if we already have that text_file open, then we just go to that file

	ContinueTest(*perm.test_data);

} @ITest

TEXT_2_NAME :: "text_2";
Test_TextSave :: (
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
		array_resize(*perm.test_data.all_sub_tests, 20+1);

		//TODO I think it's best to do this manually in the test in case we change how do it in-game later
		//We could use the text op save file eventually but maybe best to leave this as is
		load_file, load_success := LoadTextFile("c_test/save_test", *perm.all_data.all_text_files);
		if load_success {
			//TODO Should we do this in LoadTextFile?
			// array_add(*perm.all_data.all_text_files, load_file);
		}
	}

	tt_data := cast(*TextTestData) perm.test_data.spec_data;
	tt_op : *TextOpSpaceData = *tt_data.test_text_op;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(true, perm.all_data.all_text_op_space_data.count > 0);
		AssertEquals(1, perm.all_data.all_text_files.count);
	}
	text_op : *TextOpSpaceData;
	text_op_2 : *TextOpSpaceData;
	cursor_1 : TextCursor;
	cursor_2 : TextCursor;
	tab_1 : TextTab;
	tab_2 : TextTab;
	tab_string_1 : string;
	tab_string_2 : string;
	tab_file_1 : *TextFile;
	tab_file_2 : *TextFile;
	if perm.all_data.all_text_op_space_data.count > 0 {
		AssertEquals(true, AllOrEquals(perm.all_data.all_text_op_space_data.count, int.[0,1,2]));
		text_op = *perm.all_data.all_text_op_space_data[0];
		if text_op.file_tabs.count > 0 {
			tab_1 = text_op.file_tabs[0];
			cursor_1 = tab_1.tab_cursor;
			if perm.all_data.all_text_files.count > 0 {
				tab_file_1 = ArrayFindFirstByNameId(perm.all_data.all_text_files, tab_1.text_file_id, "id");
				tab_string_1 = tab_file_1.file_string.text_string;
			}
		}
		if perm.all_data.all_text_op_space_data.count == 2 {
			AssertEquals(2, perm.all_data.all_open_op_spaces.count);
			text_op_2 = *perm.all_data.all_text_op_space_data[1];
			tab_2 = text_op_2.file_tabs[0];
			AssertEquals(tab_2.text_file_id, tab_1.text_file_id);
			cursor_2 = tab_2.tab_cursor;
			if perm.all_data.all_text_files.count > 0 {
				tab_file_2 = ArrayFindFirstByNameId(perm.all_data.all_text_files, tab_2.text_file_id, "id");
				tab_string_2 = tab_file_2.file_string.text_string;
			}
		}
	}
	op_space : OperationSpace;
	op_2D_cam : Camera2D;
	default_base_cam : Camera2D;
	// ator : AllTextOpRects;	
	// top : TextOpPositions;
	if perm.all_data.all_open_op_spaces.count > 0 {
	op_space = perm.all_data.all_open_op_spaces[0];
		op_2D_cam = op_space.op_2D_cam;
		default_base_cam = GetRenderMSpace(perm.all_data).mspace_cam;
		// top = ComputeTextOpPositions(text_op.ator, op_space, text_op, perm.text_editor_data);
	}

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, "c_test/save_test");
		array_add(*perm.all_data.all_terminal_events, open_test);
		tt_data.test_end_line_index = 21;
		tt_data.test_right_char_bound = 64;
	}
	case 1; {
		AssertTabCursor(tt_data, cursor_1);
	}
	case 2; {
		open_test := MakeTerminalEvent(.load_op, TEXT_2_NAME, "c_test/save_test");
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 3; {
		RunSubTestNTimes(5, *perm.test_data);
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 4; {
		DownUpThisFrame(.END, game_input);
		#if OS == .WINDOWS {
		tt_data.test_char_point = 126;
		tt_data.test_line_char = 65;
		tt_data.test_line_number = 5;
		tt_data.test_left_char_bound += 2;
		tt_data.test_right_char_bound += 2;
		} else #if OS == .MACOS {
		tt_data.test_char_point = 120;
		tt_data.test_line_char = 64;
		tt_data.test_line_number = 5;
		tt_data.test_left_char_bound += 1;
		tt_data.test_right_char_bound += 1;
		}
	}
	case 5; {
		AssertTabCursor(tt_data, cursor_2);

		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 6; {
		RunSubTestNTimes(5, *perm.test_data);
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 7; {
		DownUpThisFrame(.END, game_input);
	}
	case 8; {
		AssertTabCursor(tt_data, cursor_1);

		//TEST remove a line in this text op and then save should update the cursor in the other text op
		for 0..1 DownUpThisFrame(.BACKSPACE, game_input);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
	}
	case 9; {
		AssertTabCursor(tt_data, cursor_1);
		AssertEquals(true, tab_file_1.file_string.not_saved_text_edit);

		//TEST test saving by switching op space other cursor should also be the same
		perm.all_data.runtime_settings.save_file_on_focus_lost = true;

		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 10; {
		AssertEquals(false, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);
		AssertTabCursor(tt_data, cursor_2);

		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
		tt_data.test_time = tab_file_1.file_write_time;
	}
	case 11; {
		AssertNotEquals(tt_data.test_time, tab_file_1.file_write_time);
		AssertEquals(false, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);
		AssertTabCursor(tt_data, cursor_2);

		//TEST remove a line in this text op and then save should update the cursor in the other text op
		//NOT ANYMORE but we should check that autosave works maybe in a separate test
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 2;
		tt_data.test_line_char += 2;
	}
	case 12; {
		AssertEquals(true, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);

		//Should save on ChangeTextPane which should work for any case
		DownUpInputMap(.TEXT_CONSOLE_TOGGLE, game_input);
		tt_data.test_time = tab_file_1.file_write_time;
		tt_data.test_end_line_index -= 9;
	}
	case 13; {
		AssertNotEquals(tt_data.test_time, tab_file_1.file_write_time);
		AssertEquals(false, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);

		DownUpInputMap(.TEXT_CONSOLE_TOGGLE, game_input);
	}
	case 14; {
		DownUpInputMap(.TEXT_PANE, game_input);
		tt_data.test_end_line_index += 9;
	}
	case 15; {
		AssertEquals(false, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);

		for 0..1 DownUpThisFrame(.BACKSPACE, game_input);
		tt_data.test_char_point -= 2;
		tt_data.test_line_char -= 2;
	}
	case 16; {
		AssertEquals(true, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);

		unselect_pos : Vector2F = text_op.ator.op_rect.min;
		unselect_pos.x -= 2;
		// game_input.mouse_cam = OpSpaceToCameraSpace(unselect_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_cam = unselect_pos;
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		tt_data.test_time = tab_file_1.file_write_time;	
	}
	case 17; {
		AssertEquals(0, perm.all_data.all_chosen_entities.count);
		AssertNotEquals(tt_data.test_time, tab_file_1.file_write_time);
		AssertEquals(false, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);

		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 18; {
		AssertEquals(true, perm.all_data.all_chosen_entities.count > 0);
		AssertNotEquals(tt_data.test_time, tab_file_1.file_write_time);
		AssertTabCursor(tt_data, cursor_1);

		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		tt_data.test_char_point += 2;
		tt_data.test_line_char += 2;
	}
	case 19; {
		AssertEquals(true, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);

		DownUpInputMap(.TEXT_FILE_SAVE, game_input);
		tt_data.test_time = tab_file_1.file_write_time;	
	}
	case 20; {
		AssertNotEquals(tt_data.test_time, tab_file_1.file_write_time);
		AssertEquals(false, tab_file_1.file_string.not_saved_text_edit);
		AssertTabCursor(tt_data, cursor_1);
	}
	}
	//TODO FROM HERE if we save a file, then we have to update the cursor everywhere else
	//to the line number or clamped which we are already doing for reload. If we reload
	//then we reload all files, but if we save we don't want to reload the particular file we saved from
	//since that one is ok. Then we also don't reload the text file on save
	//So we should call SaveTextFile directly from the save command and put the save command in text op space data.
	//ALSO don't load a file twice in the same op space to avoid issues.
	//BUT we can load the same file twice in separate op spaces which creates a similar thing to what we have in sublime text right now
	//Should test this by opening another text op space and adding a line and then saving and making
	//sure the cursor is good in both op spaces BUT IF we already have a tab open with that file in that space then just go to that tab.
	//I think we can update this in OpenFileTabWithExplorer so that if we already have that text_file open, then we just go to that file

	//TODO FROM HERE finish save text file test and do a small reload text file test

	//can do auto save now for change text pane and choose op space to test and then add setting after
	//and also when we reset selection i think might be enough overall

	//ALSO add a reset op space command just in case we ever have a weird invalid cursor 
	//where we reset the cursor AND the bounds to 0 AND the op space

	//MAYBE I should write some extensive documentation on top of save file and update cursor line char and reload text file after

	//TODO CONSIDER NOT updating all tabs on save so we only update on choosing, this means we only adjust in 1 place
	//which could reduce errors for now... or maybe updating on save reduces errors... not updating does make it faster
	//since then we just save the file for auto-saving
	//NOW we could update the save file only if its open but then that is still a bunch of checks
	//I THINK it's better to not update for now and leave this as a TODO in documentation depending on what we see later.

	//TODO Also can we test reload text file or no? just test the function independently in an integration test when everything
	//is setup to make sure it works but I guess it would be the same as just saving, let's see
	//RELOAD should set not_saved_text_edit = false since we now replaced it with the external system file

	ContinueTest(*perm.test_data);

} @ITest

#if OS == .WINDOWS {
SAVE_TEST_NAME :: "c_test/save_test";
} else {
//NOTE I WONT push this to git since the file endings will be changed automatically anyways
//instead just transfer the file over whenever we move the codebase to a mac
SAVE_TEST_NAME :: "c_test/save_test_mac";
}
Test_TextOpCursor :: (
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
		perm.test_data.spec_data = New([2] TextTestData);
		array_resize(*perm.test_data.all_sub_tests, 114+1);

		//TODO I think it's best to do this manually in the test in case we change how do it in-game later
		//We could use the text op save file eventually but maybe best to leave this as is
		load_file, load_success := LoadTextFile(SAVE_TEST_NAME, *perm.all_data.all_text_files);
		if load_success {
			//TODO Should we do this in LoadTextFile?
			// array_add(*perm.all_data.all_text_files, load_file);
		}
	}

	test_spec_data := cast(*[2] TextTestData) perm.test_data.spec_data;
	tt_data : *TextTestData = *((test_spec_data.*)[0]);
	test_cursor : *TextCursor = *tt_data.test_cursor;
	tt_op : *TextOpSpaceData = *tt_data.test_text_op;
	tt_data_2 : *TextTestData = *((test_spec_data.*)[1]);
	test_cursor_2 : *TextCursor = *tt_data_2.test_cursor;
	tt_op_2 : *TextOpSpaceData = *tt_data_2.test_text_op;
	op_space : OperationSpace;
	op_space_2 : OperationSpace;
	op_2_cam : Camera2D;
	op_cam : Camera2D;
	default_base_cam : Camera2D;
	// ator : AllTextOpRects;	
	// top : TextOpPositions;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(true, perm.all_data.all_open_op_spaces.count > 0);
		if perm.all_data.all_open_op_spaces.count > 0 {
			op_space = perm.all_data.all_open_op_spaces[0];
			op_cam = op_space.op_2D_cam;
		}	
		if perm.all_data.all_open_op_spaces.count == 2 {
			op_space_2 = perm.all_data.all_open_op_spaces[1];
			op_2_cam = op_space_2.op_2D_cam;
		}
		default_base_cam = GetRenderMSpace(perm.all_data).mspace_cam;
		// top = ComputeTextOpPositions(text_op.ator, op_space, text_op, perm.text_editor_data);

		AssertEquals(true, perm.all_data.all_text_op_space_data.count > 0);
		AssertEquals(true, perm.all_data.all_text_files.count > 0);
	}

	text_op : *TextOpSpaceData;
	text_op_2 : *TextOpSpaceData;
	cursor_1 : TextCursor;
	cursor_2 : TextCursor;
	tab_1 : TextTab;
	tab_2 : TextTab;
	tab_string_1 : string;
	tab_string_2 : string;
	tab_file_1 : *TextFile;
	tab_file_2 : *TextFile;
	if perm.all_data.all_text_op_space_data.count > 0 {
		AssertEquals(true, AllOrEquals(perm.all_data.all_text_op_space_data.count, int.[0,1,2]));
		text_op = *perm.all_data.all_text_op_space_data[0];
		if text_op.file_tabs.count > 0 {
			tab_1 = text_op.file_tabs[0];
			cursor_1 = tab_1.tab_cursor;
			if perm.all_data.all_text_files.count > 0 {
				tab_file_1 = ArrayFindFirstByNameId(perm.all_data.all_text_files, tab_1.text_file_id, "id");
				tab_string_1 = tab_file_1.file_string.text_string;
			}
		}
		if perm.all_data.all_text_op_space_data.count == 2 {
			AssertEquals(2, perm.all_data.all_open_op_spaces.count);
			text_op_2 = *perm.all_data.all_text_op_space_data[1];
			tab_2 = text_op_2.file_tabs[0];
			AssertEquals(tab_2.text_file_id, tab_1.text_file_id);
			cursor_2 = tab_2.tab_cursor;
			if perm.all_data.all_text_files.count > 0 {
				tab_file_2 = ArrayFindFirstByNameId(perm.all_data.all_text_files, tab_2.text_file_id, "id");
				tab_string_2 = tab_file_2.file_string.text_string;
			}
		}
	}

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	TEXT_2_NAME :: "text_2";
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, SAVE_TEST_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
		test_cursor.end_file_line_index = 21;
		test_cursor.right_char_bound = 64;
	}
	case 1; {
		AssertTextCursor(tt_data.test_cursor, cursor_1);
	}
	case 2; {
		open_test := MakeTerminalEvent(.load_op, TEXT_2_NAME, SAVE_TEST_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);

		move_op := MakeTerminalEvent(.move_op, TEST_TEXT_NAME,
			tprint("%", op_space.world_offset.x-op_space.world_size.x/2), tprint("%", op_space.world_offset.y));
		array_add(*perm.all_data.all_terminal_events, move_op);

		move_op_2 := MakeTerminalEvent(.move_op, TEXT_2_NAME,
			tprint("%", op_space.world_offset.x+op_space.world_size.x/2), tprint("%", op_space.world_offset.y));
		array_add(*perm.all_data.all_terminal_events, move_op_2);
	}
	case 3; {
		RunSubTestNTimes(5, *perm.test_data);
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 4; {
		DownUpThisFrame(.END, game_input);
		test_cursor_2.* = test_cursor.*;
		test_cursor_2.char_point = 126;
		test_cursor_2.cursor_line_char = 65;
		test_cursor_2.cursor_line_number = 5;
		test_cursor_2.left_char_bound += 2;
		test_cursor_2.right_char_bound += 2;
	}
	case 5; {
		AssertTextCursor(test_cursor_2, cursor_2);

		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 6; {
		RunSubTestNTimes(5, *perm.test_data);
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 7; {
		DownUpThisFrame(.END, game_input);

		test_cursor.* = test_cursor_2.*;
	}
	case 8; {
		AssertTextCursor(test_cursor, cursor_1);
		//TEST Cursors are in same place so adjusting the line should move both cursors after choosing the other op space
		AssertTextCursor(cursor_1, cursor_2);

		//TEST remove a line in this text op and then choosing the other op space should update it as well
		for 0..1 DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor.char_point -= 2;
		test_cursor.cursor_line_char -= 2;
	}
	case 9; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST check that other op space
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
		test_cursor_2.* = test_cursor.*;
	}
	case 10; {
		AssertTextCursor(cursor_2, cursor_1);
		AssertTextCursor(test_cursor, cursor_1);
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST Highlight beginning of file
		for 0..1 DownUpThisFrame(.HOME, .{shift_pressed=true}, game_input);
		for 0..4 DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.ARROW_RIGHT, .{shift_pressed=true,ctrl_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = test_cursor_2.char_point;
		test_cursor_2.fixed_select_line_char = test_cursor_2.cursor_line_char;
		test_cursor_2.fixed_select_line_number = test_cursor_2.cursor_line_number;
		test_cursor_2.char_point = 2;
		test_cursor_2.cursor_line_char = 2;
		test_cursor_2.cursor_line_number = 0;
		test_cursor_2.left_char_bound -= 2;
		test_cursor_2.right_char_bound -= 2;
	}
	case 11; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST scroll down a bit so we can delete top of file and see that cursor changes correctly
		for 0..2 DownUpThisFrame(.ARROW_DOWN, .{ctrl_pressed=true}, game_input);
		test_cursor_2.start_file_line_index += 3;
		test_cursor_2.end_file_line_index += 3;
	}
	case 12; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST scroll down a bit so we can delete top of file and see that cursor changes correctly
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 13; {
		//TEST DELETE bottom of file and see if other text cursor is properly adjusted
		for 0..tab_file_1.file_string.file_loc.count-1 DownUpThisFrame(.ARROW_DOWN, game_input);
		test_cursor.char_point = tab_file_1.file_string.text_string.count;
		test_cursor.cursor_line_char = 0;
		test_cursor.cursor_line_number = tab_file_1.file_string.file_loc.count-1;
		test_cursor.left_char_bound -= 2;
		test_cursor.right_char_bound -= 2;
		test_cursor.start_file_line_index += 3;
		test_cursor.end_file_line_index += 3;
	}
	case 14; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST DELETE bottom of file and see if other text cursor is properly adjusted
		for 0..tab_file_1.file_string.file_loc.count-4 DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		test_cursor.fixed_select_char_point = test_cursor.char_point;
		test_cursor.fixed_select_line_char = test_cursor.cursor_line_char;
		test_cursor.fixed_select_line_number = test_cursor.cursor_line_number;
		test_cursor.cursor_is_selecting = true;
		test_cursor.char_point = 30;
		test_cursor.cursor_line_char = 0;
		test_cursor.cursor_line_number = 2;
		test_cursor.start_file_line_index -= 1;
		test_cursor.end_file_line_index -= 1;
	}
	case 15; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST DELETE bottom of file and see if other text cursor is properly adjusted
		DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor.cursor_is_selecting = false;
	}
	case 16; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST switch to other op space and line bounds should not have changed but selection should have changed
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = 30;
		test_cursor_2.fixed_select_line_char = 0;
		test_cursor_2.fixed_select_line_number = 2;
	}
	case 17; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST scrollup to make sure it's still good
		for 0..2 DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
		test_cursor_2.start_file_line_index -= 3;
		test_cursor_2.end_file_line_index -= 3;
	}
	case 18; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST move cursor to make sure it's still good
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.char_point = test_cursor_2.fixed_select_char_point;
		test_cursor_2.cursor_line_char = test_cursor_2.fixed_select_line_char;
		test_cursor_2.cursor_line_number = test_cursor_2.fixed_select_line_number;
	}
	case 19; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST move cursor around see it's still good
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.char_point = test_cursor_2.fixed_select_char_point;
		test_cursor_2.cursor_line_char = test_cursor_2.fixed_select_line_char;
		test_cursor_2.cursor_line_number = test_cursor_2.fixed_select_line_number;
	}
	case 20; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST move cursor around see it's still good
		for 0..1 DownUpThisFrame(.HOME, game_input);
		for 0..1 DownUpThisFrame(.END, game_input);
	}
	case 21; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST move cursor around see it's still good
		for 0..3 DownUpThisFrame(.ARROW_UP, game_input);
		test_cursor_2.char_point = 0;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number = 0;
	}
	case 22; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST move cursor around see it's still good
		DownUpThisFrame(.END, game_input);
		test_cursor_2.char_point = tab_file_2.file_string.file_loc[0].count;
		test_cursor_2.cursor_line_char = tab_file_2.file_string.file_loc[0].count;
		test_cursor_2.cursor_line_number = 0;
	}
	case 23; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST move cursor around see it's still good
		DownUpThisFrame(.HOME, game_input);
		test_cursor_2.char_point = 0;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number = 0;
	}
	case 24; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST undo in this op_space should get us the last change we made in the other op space
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor_2.* = test_cursor.*;
		test_cursor_2.cursor_is_selecting = true;
	}
	case 25; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST switch to other op space and we should have the same cursor
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 26; {
		//TEST cursor here which we did backspace with so it should not be selectin anymore and be
		//exactly where it was before since the text is at the same place
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove from the bottom and see that other selection does not change
		for 0..tab_file_1.file_string.file_loc.count-1 DownUpThisFrame(.ARROW_DOWN, game_input);
		for 0..4 DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		test_cursor.cursor_is_selecting = true;
		test_cursor.char_point = 221;
		test_cursor.cursor_line_char = 0;
		test_cursor.cursor_line_number = 19;
		test_cursor.start_file_line_index += 1;
		test_cursor.end_file_line_index += 1;
	}
	case 27; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST change selection to be above removal from other op space
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
		test_cursor_2.cursor_is_selecting = true;
	}
	case 28; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST change selection to be above removal from other op space
		DownUpThisFrame(.ARROW_LEFT, game_input);
		for 0..1 DownUpThisFrame(.ARROW_RIGHT, game_input);
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
		for 0..11 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = test_cursor_2.char_point + 2;
		test_cursor_2.fixed_select_line_char = test_cursor_2.cursor_line_char + 2;
		test_cursor_2.fixed_select_line_number = test_cursor_2.cursor_line_number;
		test_cursor_2.char_point = 211;
		test_cursor_2.cursor_line_char = 70;
		test_cursor_2.cursor_line_number = 14;
		test_cursor_2.start_file_line_index -= 1;
		test_cursor_2.end_file_line_index -= 1;
		test_cursor_2.left_char_bound += 7;
		test_cursor_2.right_char_bound += 7;
	}
	case 29; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST change selection to be above removal from other op space
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 30; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST change selection to be above removal from other op space
		DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor.cursor_is_selecting = false;
	}
	case 31; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST after removing below, other cursor should not have changed at all
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 32; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST we now remove in between the cursor and make sure it adjusts correctly
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 33; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST we now remove in between the cursor and make sure it adjusts correctly
		for 0..14 DownUpThisFrame(.ARROW_UP, game_input);
		for 0..1 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		test_cursor.fixed_select_char_point = 47;
		test_cursor.fixed_select_line_char = 0;
		test_cursor.fixed_select_line_number = 4;
		test_cursor.cursor_is_selecting = true;
		test_cursor.char_point = 125;
		test_cursor.cursor_line_char = 0;
		test_cursor.cursor_line_number = 6;
		// test_cursor_2.start_file_line_index -= 1;
		// test_cursor_2.end_file_line_index -= 1;
	}
	case 34; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST we now remove in between the cursor and make sure it adjusts correctly
		DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor.char_point = test_cursor.fixed_select_char_point;
		test_cursor.cursor_line_char = test_cursor.fixed_select_line_char;
		test_cursor.cursor_line_number = test_cursor.fixed_select_line_number;
		test_cursor.cursor_is_selecting=false;
	}
	case 35; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST we now remove in between the cursor and make sure it adjusts correctly
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);

		//TEST the char point should have changed since we removed code but the line number should not have
		//and cursor should still be selecting something valid
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.char_point = 138;
		test_cursor_2.cursor_line_char = 1;
	}
	case 36; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST undo in previous op space to see that cursor is still valid in this op space althought different
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 37; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST undo in previous op space to see that cursor is still valid in this op space althought different
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor.cursor_is_selecting = true;
		test_cursor.char_point = 125;
		test_cursor.cursor_line_number = 6;
	}
	case 38; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST undo in previous op space to see that cursor is still valid in this op space althought different
		//We should not be in the same position but close to the same position and it should be valid
		//so the line_char and line_number should be the same but not the char point and we should still be selecting
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
		test_cursor_2.char_point = 142;
		test_cursor_2.cursor_is_selecting = true;
	}
	case 39; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST undo and then delete more than what we have on bottom so cursor should be set to end
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = 281;
		test_cursor_2.fixed_select_line_char = 0;
		test_cursor_2.fixed_select_line_number = 24;
		test_cursor_2.char_point = 221;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number = 19;
		test_cursor_2.start_file_line_index += 2;
		test_cursor_2.end_file_line_index += 2;
		test_cursor_2.left_char_bound -= 7;
		test_cursor_2.right_char_bound -= 7;
	}
	case 40; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST undo and then delete more than what we have on bottom so cursor should be set to end
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 41; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove more than other space and make sure other cursor is still valid at end without selection
		for 0..17 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		test_cursor.cursor_is_selecting = true;
		test_cursor.char_point = tab_string_1.count;
		test_cursor.cursor_line_number = tab_file_1.file_string.file_loc.count-1;
	}
	case 42; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove more than other space and make sure other cursor is still valid at end without selection
		DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor.cursor_is_selecting = false;
		test_cursor.char_point = test_cursor.fixed_select_char_point;
		test_cursor.cursor_line_number = test_cursor.fixed_select_line_number;
	}
	case 43; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove more than other space and make sure other cursor is still valid at end without selection
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 44; {
		AssertTextCursor(cursor_1, cursor_2);

		//TEST remove more than other space and make sure other cursor is still valid at end without selection
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = 47;
		test_cursor_2.fixed_select_line_number = 4;
		test_cursor_2.char_point = 281;
		test_cursor_2.cursor_line_number = 24;
	}
	case 45; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove from beginning and make sure text op cursor gets reset
		DownUpThisFrame(.ARROW_LEFT, game_input);
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		for 0..9 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = 48;
		test_cursor_2.fixed_select_line_char = 1;
		test_cursor_2.fixed_select_line_number = 4;
		test_cursor_2.char_point = 211;
		test_cursor_2.cursor_line_char = 70;
		test_cursor_2.cursor_line_number = 14;
		test_cursor_2.left_char_bound += 7;
		test_cursor_2.right_char_bound += 7; 
	}
	case 46; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove more than other space and make sure other cursor is still valid at end
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 47; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove more than other space and make sure other cursor is still valid at end
		DownUpThisFrame(.ARROW_UP, game_input);
		for 0..13 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		test_cursor.cursor_is_selecting = true;
		test_cursor.fixed_select_char_point = 44;
		test_cursor.fixed_select_line_number = 3;
		test_cursor.char_point = 217;
		test_cursor.cursor_line_number = 17;
	}
	case 48; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove more than other space and make sure other cursor is still valid at end
		DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor.cursor_is_selecting = false;
		test_cursor.char_point = test_cursor.fixed_select_char_point;
		test_cursor.cursor_line_number = test_cursor.fixed_select_line_number;
	}
	case 49; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove more than other space and make sure other cursor is still valid at end
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
		//cursor char points and line char should have changed but not bounds
		//line number also changed since we are the end
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.char_point = 108;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number = tab_file_2.file_string.file_loc.count-1;
		test_cursor_2.fixed_select_char_point = 47;
		test_cursor_2.fixed_select_line_char = 1;
	}
	case 50; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove more than other space and make sure other cursor is still valid at end
		DownUpThisFrame(.ARROW_LEFT, game_input);
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.char_point = test_cursor_2.fixed_select_char_point;
		test_cursor_2.cursor_line_char = test_cursor_2.fixed_select_line_char;
		test_cursor_2.cursor_line_number = test_cursor_2.fixed_select_line_number;
		test_cursor_2.left_char_bound -= 6;
		test_cursor_2.right_char_bound -= 6;
	}
	case 51; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST undo previous change here
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor_2.* = test_cursor.*;
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.char_point = 217;
		test_cursor_2.cursor_line_number = 17;
	}
	case 52; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST move the op space over and then delete to make sure cursor is still valid and mouse pressing is valid
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 53; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST move the op space over and then delete to make sure cursor is still valid and mouse pressing is valid
		//we delete from start so it is still valid because we allow empty space on the bottom
		for 0..4 DownUpThisFrame(.ARROW_UP, game_input);
		for 0..4 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor.cursor_is_selecting = false;
		test_cursor.char_point = 0;
		test_cursor.cursor_line_number = 0;
		test_cursor.start_file_line_index = 0;
		test_cursor.end_file_line_index = 21;
	}
	case 54; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST move the op space over and then delete to make sure cursor is still valid and mouse pressing is valid	
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X + 1 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.LOC_START_Y - 6.5 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.char_point = 80;
		test_cursor_2.cursor_line_number = 9;
	}
	case 55; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST move the op space over and then delete to make sure cursor is still valid and mouse pressing is valid
		game_input.mouse_wheel = 3;
		test_cursor_2.start_file_line_index -= 3;
		test_cursor_2.end_file_line_index -= 3;
	}
	case 56; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST press bottom of op space should go to end of file
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X + 1 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.l_text_rect.min.y + 0.5 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		test_cursor_2.char_point = tab_string_2.count;
		test_cursor_2.cursor_line_number = 19;
	}
	case 57; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST press bottom of op space should go to end of file
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.char_point = 61;
		test_cursor_2.cursor_line_number = 5;
		test_cursor_2.fixed_select_char_point = 0;
		test_cursor_2.fixed_select_line_number = 0;
	}
	case 58; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST press bottom of op space should go to end of file
		line_pos : Vector2F;
		line_pos.x = text_op.ator.LOC_START_X + 1 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op.ator.l_text_rect.max.y - 14.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space, op_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_cursor.cursor_left_mouse_holding = true;
		test_cursor.char_point = 141;
		test_cursor.cursor_line_char = 0;
		test_cursor.cursor_line_number = 14;
	}
	case 59; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST press bottom of op space should go to end of file
		line_pos : Vector2F;
		line_pos.x = text_op.ator.LOC_START_X + 1 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op.ator.l_text_rect.min.y - 10.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space, op_cam.world_pos, default_base_cam);
		test_cursor.cursor_is_selecting = true;
		test_cursor.fixed_select_char_point = test_cursor.char_point;
		test_cursor.fixed_select_line_number = test_cursor.cursor_line_number;
		test_cursor.char_point = tab_string_1.count;
		test_cursor.cursor_line_number = tab_file_1.file_string.file_loc.count-1;
		test_cursor.start_file_line_index += 3;
		test_cursor.end_file_line_index += 3;
	}
	case 60; {
		AssertTextCursor(test_cursor, cursor_1);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		//TEST press bottom of op space should go to end of file
		test_cursor.cursor_left_mouse_holding = false;
	}
	case 61; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST delete bottom of op space and check other cursor
		DownUpThisFrame(.BACKSPACE, game_input);
	}
	case 62; {
		test_cursor.cursor_is_selecting = false;
		test_cursor.char_point = tab_string_1.count;
		test_cursor.cursor_line_number = tab_file_1.file_loc.count-1;
		AssertTextCursor(test_cursor, cursor_1);

		//TEST delete bottom of op space and check other cursor
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X + 1 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.LOC_START_Y - 10.5 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.char_point = 134;
		test_cursor_2.cursor_line_char = 1;
		test_cursor_2.cursor_line_number = 10;
	}
	case 63; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST delete bottom of op space and check other cursor
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor_2.* = test_cursor.*;
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.char_point = 281;
		test_cursor_2.cursor_line_number = 24;
	}
	case 64; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST delete in between with right bound moved over
		DownUpThisFrame(.ARROW_LEFT, game_input);
		DownUpThisFrame(.END, game_input);
		for 0..10 DownUpThisFrame(.ARROW_UP, .{shift_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.char_point = 45;
		test_cursor_2.cursor_line_char = 1;
		test_cursor_2.cursor_line_number = 3;
		test_cursor_2.fixed_select_char_point = 211;
		test_cursor_2.fixed_select_line_char = 70;
		test_cursor_2.left_char_bound += 1;
		test_cursor_2.right_char_bound += 1;
	}
	case 65; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST delete in between with right bound moved over
		line_pos : Vector2F;
		line_pos.x = text_op.ator.LOC_START_X + 0.1 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op.ator.l_text_rect.max.y - 1.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space, op_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_cursor.cursor_left_mouse_holding = true;
		test_cursor.char_point = 47;
		test_cursor.cursor_line_number = 4;
	}
	case 66; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST delete in between with right bound moved over
		line_pos : Vector2F;
		line_pos.x = text_op.ator.LOC_START_X + 0.1 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op.ator.l_text_rect.max.y - 3.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space, op_cam.world_pos, default_base_cam);
		test_cursor.cursor_is_selecting = true;
		test_cursor.fixed_select_char_point = test_cursor.char_point;
		test_cursor.fixed_select_line_number = test_cursor.cursor_line_number;
		test_cursor.char_point = 125;
		test_cursor.cursor_line_number += 2;
	}
	case 67; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST delete in between with right bound moved over
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		test_cursor.cursor_left_mouse_holding = false;
	}
	case 68; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST delete in between with right bound moved over
		DownUpThisFrame(.BACKSPACE, game_input);
	}
	case 69; {
		// AssertTextCursor(test_cursor, cursor_1);

		//TEST delete in between with right bound moved over
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X + 2 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.LOC_START_Y - 9.5 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_cursor_2.cursor_left_mouse_holding = true;
		test_cursor_2.char_point = 65;
		test_cursor_2.cursor_line_char = 2;
		test_cursor_2.cursor_line_number = 12;
		test_cursor_2.cursor_is_selecting = false;
	}
	case 70; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST check if mouse holding with bounds moving left and then down works properly after updating text and now reselecting op space
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X - 2 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.LOC_START_Y - 9.5 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = test_cursor_2.char_point;
		test_cursor_2.fixed_select_line_char = test_cursor_2.cursor_line_char;
		test_cursor_2.fixed_select_line_number = test_cursor_2.cursor_line_number;
		test_cursor_2.char_point -= 2;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.left_char_bound -= 1;
		test_cursor_2.right_char_bound -= 1;
	}
	case 71; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST delete in between with right bound moved over
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X - 2 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.LOC_START_Y + 5 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		test_cursor_2.char_point = 0;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number = 0;
		test_cursor_2.start_file_line_index -= 3;
		test_cursor_2.end_file_line_index -= 3;
	}
	case 72; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST delete in between with right bound moved over
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		test_cursor_2.cursor_left_mouse_holding = false;
	}
	case 73; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then undo redo in other text op to makes sure that works
		DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor_2.cursor_is_selecting = false;
	}
	case 74; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then undo redo in other text op to makes sure that works
		//press op space one on bottom to make sure line is correct
		line_pos : Vector2F;
		line_pos.x = text_op.ator.LOC_START_X + 2 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op.ator.l_text_rect.max.y - 9.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space, op_cam.world_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
		test_cursor.cursor_is_selecting = false;
		test_cursor.char_point = 138;
		test_cursor.cursor_line_number = 10;
	}
	case 75; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then undo redo in other text op to makes sure that works
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor.* = test_cursor_2.*;
		test_cursor.cursor_is_selecting = true;
	}
	case 76; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then undo redo in other text op to makes sure that works
		DownUpThisFrame(#char "Y", .{ctrl_pressed=true}, game_input);
		test_cursor.cursor_is_selecting = false;
		test_cursor.char_point = 0;
		test_cursor.cursor_line_number = 0;
	}
	case 77; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then undo redo in other text op to makes sure that works
		for 0..1 DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor.cursor_is_selecting = true;
		test_cursor.char_point = 125;
		test_cursor.cursor_line_char = 0;
		test_cursor.cursor_line_number = 6;
		test_cursor.fixed_select_char_point = 47;
		test_cursor.fixed_select_line_char = 0;
		test_cursor.fixed_select_line_number = 4;
		test_cursor.start_file_line_index += 3;
		test_cursor.end_file_line_index += 3;
	}
	case 78; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then undo redo in other text op to makes sure that works
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 79; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 80; {
		//TEST remove and then undo redo in other text op to makes sure that works
		for 0..4 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = 0;
		test_cursor_2.fixed_select_line_char = 0;
		test_cursor_2.fixed_select_line_number = 0;
		test_cursor_2.char_point = 124;
		test_cursor_2.cursor_line_number += 5;
		test_cursor_2.cursor_line_char = 63;
		test_cursor_2.end_file_line_index = 12;
		test_cursor_2.left_char_bound += 29;
		//Stays the same since we are at the end of the line bounds
		// test_cursor_2.right_char_bound = 29;
	}
	case 81; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then undo redo in other text op to makes sure that works
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 82; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then undo redo in other text op to makes sure that works
		DownUpThisFrame(.BACKSPACE, game_input);
		test_cursor.cursor_is_selecting = false;
		test_cursor.char_point = test_cursor.fixed_select_char_point;
		test_cursor.cursor_line_char = test_cursor.fixed_select_line_char;
		test_cursor.cursor_line_number = test_cursor.fixed_select_line_number;
	}
	case 83; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then undo redo in other text op to makes sure that works
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
		test_cursor_2.char_point = 50;
		test_cursor_2.cursor_line_char = 1;
	}
	case 84; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then undo redo in other text op to makes sure that works
		DownUpThisFrame(.ARROW_RIGHT, game_input);
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.char_point = 50;
		test_cursor_2.cursor_line_char = 1;
		test_cursor_2.cursor_line_number = 5;
		test_cursor_2.left_char_bound = 1;
		test_cursor_2.right_char_bound = 36;
	}
	case 85; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then undo redo in other text op to makes sure that works
		for 0..5 DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.char_point = 133;
		test_cursor_2.cursor_line_char = 70;
		test_cursor_2.cursor_line_number = 12;
		test_cursor_2.left_char_bound += 35;
		test_cursor_2.right_char_bound += 35;
		test_cursor_2.fixed_select_char_point = 62;
		test_cursor_2.fixed_select_line_char = 1;
		test_cursor_2.fixed_select_line_number = 11;
	}
	case 86; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST adding code back and checking if mouse clicking works with scroll bound offsets
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 87; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST adding code back and checking if mouse clicking works with scroll bound offsets
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor.cursor_is_selecting = true;
		test_cursor.char_point = 125;
		test_cursor.cursor_line_number = 6;
	}
	case 88; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST adding code back and checking if mouse clicking and selecting works with scroll bound offsets
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X + 2 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.LOC_START_Y - 5.5 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_cursor_2.char_point = 98;
		test_cursor_2.cursor_line_char = 37;
		test_cursor_2.cursor_line_number = 5;
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.cursor_left_mouse_holding = true;
	}
	case 89; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST adding code back and checking if mouse clicking and selecting works with scroll bound offsets
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X - 2 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op.ator.l_text_rect.max.y - 5.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		test_cursor_2.cursor_left_mouse_holding = true;
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = test_cursor_2.char_point;
		test_cursor_2.fixed_select_line_char = test_cursor_2.cursor_line_char;
		test_cursor_2.fixed_select_line_number = test_cursor_2.cursor_line_number;
		test_cursor_2.char_point -= 4;
		test_cursor_2.cursor_line_char -= 4;
		test_cursor_2.cursor_line_number = 5;
		test_cursor_2.left_char_bound -= 2;
		test_cursor_2.right_char_bound -= 2;
	}
	case 90; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST adding code back and checking if mouse clicking and selecting works with scroll bound offsets
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X - 40 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op.ator.l_text_rect.max.y - 5.5 * text_op.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		test_cursor_2.char_point = 61;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number = 5;
		test_cursor_2.left_char_bound -= 34;
		test_cursor_2.right_char_bound -= 34;
	}
	case 91; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST adding code back and checking if mouse clicking and selecting works with scroll bound offsets
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X - 10 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.l_text_rect.min.y - 1 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		test_cursor_2.char_point = 141;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number = 14;
		test_cursor_2.start_file_line_index += 2;
		test_cursor_2.end_file_line_index += 2;
	}
	case 92; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST adding code back and checking if mouse clicking and selecting works with scroll bound offsets
		line_pos : Vector2F;
		line_pos.x = text_op_2.ator.LOC_START_X - 1 * perm.text_editor_data.code_font_1_char_width_world;
		line_pos.y = text_op_2.ator.l_text_rect.min.y - 10 * text_op_2.ator.TEXT_LINE_HEIGHT;
		game_input.mouse_cam = OpSpaceToCameraSpace(line_pos, op_space_2, op_2_cam.world_pos, default_base_cam);
		test_cursor_2.char_point = tab_string_2.count;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number += 10;
		test_cursor_2.start_file_line_index += 10;
		test_cursor_2.end_file_line_index += 10;
	}
	case 93; {
		AssertTextCursor(test_cursor_2, cursor_2);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		test_cursor_2.cursor_left_mouse_holding = false;
	}
	case 94; {
		AssertTextCursor(test_cursor_2, cursor_2);

		DownUpThisFrame(.ARROW_DOWN, game_input);
		for 0..20 DownUpThisFrame(.ARROW_UP, game_input);
		for 0..10 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		DownUpThisFrame(.END, .{shift_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = 44;
		test_cursor_2.fixed_select_line_char = test_cursor_2.cursor_line_char;
		test_cursor_2.fixed_select_line_number = 3;
		test_cursor_2.char_point = 211;
		test_cursor_2.cursor_line_char = 70;
		test_cursor_2.cursor_line_number = 14;
		test_cursor_2.start_file_line_index = 3;
		test_cursor_2.end_file_line_index = 15;
		test_cursor_2.left_char_bound = 36;
		test_cursor_2.right_char_bound = 71;
	}
	case 95; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST add file tab and then update and then move over to check it's still ok
		abs_path := get_absolute_path("c_test/write_test");
		OpenFileTab(abs_path, text_op_2, *perm.all_data.all_text_files, op_space_2, perm.text_editor_data);
		AssertEquals(2, text_op_2.file_tabs.count);
		AssertEquals(1, text_op_2.ftab_i);

		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 96; {
		AssertTextCursor(test_cursor_2, cursor_2);
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then check that tab is still valid in debug mode
		DownUpThisFrame(.BACKSPACE, game_input);
	}
	case 97; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid in debug mode
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 98; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid in debug mode
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		test_cursor_2.char_point = 138;
		test_cursor_2.cursor_line_char = 1;
	}
	case 99; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid in debug mode
		DownUpThisFrame(.ARROW_DOWN, game_input);
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.char_point = 140;
		test_cursor_2.cursor_line_char = 1;
		test_cursor_2.cursor_line_number = 15;
		test_cursor_2.start_file_line_index = 3;
		test_cursor_2.end_file_line_index = 15;
		test_cursor_2.left_char_bound = 1;
		test_cursor_2.right_char_bound = 36;
	}
	case 100; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid in debug mode
		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
		test_cursor_2.end_file_line_index = 24;
		test_cursor_2.right_char_bound = 65;
	}
	case 101; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid in debug mode
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 102; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid in debug mode
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 103; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid in debug mode
		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
	}
	case 104; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then check that tab is still valid without debug
		for 0..12 DownUpThisFrame(.ARROW_DOWN, game_input);
		for 0..5 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		test_cursor.cursor_is_selecting = true;
		test_cursor.fixed_select_char_point = 221;
		test_cursor.fixed_select_line_number = 19;
		test_cursor.char_point = 281;
		test_cursor.cursor_line_char = 0;
		test_cursor.cursor_line_number = 24;
		test_cursor.start_file_line_index = 3;
		test_cursor.end_file_line_index = 24;
	}
	case 105; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then check that tab is still valid without debug
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 106; {
		//TEST we did not change tab so the cursor did not change yet
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid without debug
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		//TEST we changed the tab so the cursor changed now
		test_cursor_2.char_point = 213;
	}
	case 107; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid without debug
		DownUpThisFrame(.ARROW_LEFT, game_input);
		for 0..5 DownUpThisFrame(.ARROW_DOWN, game_input);
		for 0..1 DownUpThisFrame(.ARROW_DOWN, .{shift_pressed=true}, game_input);
		test_cursor_2.cursor_is_selecting = true;
		test_cursor_2.fixed_select_char_point = 250;
		test_cursor_2.fixed_select_line_number = 21;
		test_cursor_2.char_point = 278;
		test_cursor_2.cursor_line_char = 0;
		test_cursor_2.cursor_line_number = 23;
		test_cursor_2.left_char_bound = 0;
		test_cursor_2.right_char_bound = 64;
	}
	case 108; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid without debug
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 109; {
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid without debug
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 110; {
		AssertTextCursor(test_cursor, cursor_1);

		//TEST remove and then check that tab is still valid without debug
		DownUpThisFrame(.BACKSPACE, game_input);
	}
	case 111; {
		//TEST remove and then check that tab is still valid without debug
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 112; {
		//TEST should not have changed since we are not on that tab
		AssertTextCursor(test_cursor_2, cursor_2);

		//TEST remove and then check that tab is still valid without debug
		DownUpInputMap(.TEXT_FILE_TAB_LEFT, game_input);
		test_cursor_2.cursor_is_selecting = false;
		test_cursor_2.char_point = 221;
		test_cursor_2.cursor_line_number = 19;
	}
	case 113; {
		//TEST cursor changed since we are now on that tab
		AssertTextCursor(test_cursor_2, cursor_2);

		DownUpThisFrame(#char "Z", .{ctrl_pressed=true}, game_input);
		test_cursor_2.* = test_cursor.*;
	}
	case 114; {
		//TEST cursor changed since we are now on that tab
		AssertTextCursor(test_cursor_2, cursor_2);

	}
	}

	ContinueTest(*perm.test_data);

} @ITest
// }