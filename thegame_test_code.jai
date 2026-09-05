//TODO FROM HERE Do this test and then while and inline and functions and also remove old unit test
//ALSO add comp_data to text op
//MySimplePool for the comp_alloc so we use teh allocator and think of many small pools
//accessing the larger pool so we can reuse them and possibly reuse them at the higher level too
//we could also use MySimpleAllocProc as the allocator for resizable array if we know the total size for example.
//We could also swap out allocators depending on if its a test or not. But the pool is still needed but 
//we can use a different allocator for
/*NOTE TODO : Is this test too elaborate. We go through each step of the for loop, maybe we could remove some steps
if it is an issue but also maybe it is good to have at least 1 very elaborate test for completeness to check
a slow full debugging session of a for loop.
*/
Test_ForLoopRange :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	x : int = 0;
	for 1..3 {
		x = it + 1;
		y : int = 3;
	}
	for < 11..13 {
	}

	x0 : int = 2;
	x1 : int = 4;
	for i : x0..x1 {
		x = i;
	}
	for < x0..x1 {
		x = it;
	}
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 47+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	//TODO We could set the breakpoint directly here if we have an issue. That's what we do later in this test.
	case 2; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 3; DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	case 4; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 5; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 6; {
		//Before the for scope
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(4, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(3, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 7; {
		//In the for scope now - at for 1..3
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+1, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+8, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				y_var := c_frame.frame_vars[4];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(for_scope.id, y_var.scope_id);
				AssertEquals(for_scope.function_id, y_var.function_id);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 8; {
		//at x = x + 1;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				y_var := c_frame.frame_vars[4];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
			}
		}


		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 9; {
		//At the y : int for the 1st time
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(1, c_frame.call_open_scopes.count);
			AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, x_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 10; {
		//At the close "}" of the foor loop for we add to "it" and reset the scope.
		//TODO Eventually we will likely not reset the scope and just store all stack positions directly.
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			AssertEquals(5, c_frame.frame_vars.count);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		//Back at the for scope now - at for 0..1
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				y_var := c_frame.frame_vars[4];
				AssertEquals("y", y_var.name);
			}
		}


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	}
	case 12; {
		//At the y : int for the 2nd time
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(1, c_frame.call_open_scopes.count);
			AssertEquals(5, c_frame.frame_vars.count);
		}

		//Check all the variables are correct in the loop in the watch data
		AddWatchDataForTest(.["x", "y", "it"], text_op);
		for 0..text_op.watch_data_rows.count-2 {
			EvaluateWatchData(it, text_op, perm.all_data, true);
		}
		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			x_var : WatchData = GetWatch("x", text_op.watch_data_rows);
			AssertEquals("3", x_var.value_str);
			AssertEquals("int", x_var.type_str);

			y_var : WatchData = GetWatch("y", text_op.watch_data_rows);
			AssertEquals("int", y_var.type_str);

			it_var : WatchData = GetWatch("it", text_op.watch_data_rows);
			AssertEquals("2", it_var.value_str);
			AssertEquals("int", it_var.type_str);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 13; {
		//At the close "}" of the for loop for we add to "it" and reset the scope.
		//TODO Eventually we will likely not reset the scope and just store all stack positions directly.
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			AssertEquals(5, c_frame.frame_vars.count);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 14; {
		//Back at the top for loop for the final check
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 15; {
		//Back at the top for loop for the final check
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				//We increment it at the bottom of the for loop so it should be 2 now
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);
			}
		}


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 16; {
		//Back y : int for last time
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 18; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 19; {
		//Back at top for last check
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				//We increment it at the top of the for loop so it should be 3 now
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);
			}
		}


		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 20; {
		//At for < 11..13
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		AssertEquals(9, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(1, c_frame.call_open_scopes.count);
			AssertEquals(4, c_frame.frame_vars.count);
		}

		//Check that the y and it var are no longer available but x still is with correct value.
		count_equals = AssertEquals(4, text_op.watch_data_rows.count);
		if count_equals {
			x_var : WatchData = GetWatch("x", text_op.watch_data_rows);
			AssertEquals("4", x_var.value_str);
			AssertEquals("int", x_var.type_str);

			y_var : WatchData = GetWatch("y", text_op.watch_data_rows);
			AssertEquals(true, y_var.is_error);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 21; {
		//End of first iteration for < 11..13
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+4, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+4, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(13, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 22; {
		//Start of second iteration for < 11..13
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+4, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(13, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 23; {
		//End of second iteration for < 11..13
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+4, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+4, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(12, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 24; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 25; {
		//End of third iteration for < 11..13
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+4, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+4, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(11, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 26; {
		//Start of fourth iteration for < 11..13
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+4, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(11, it_value);
			}
		}

		CodeBPForTest(11, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	}
	case 27; {
		//Start of fourth iteration for < 11..13
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 28; {
		//At for i : x0..x1 { x = i;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+4, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 29; {
		//At end of first iteration for i : x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 30; {
		//Start of second iteration for i : x0..x1
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 31; {
		//In second iteration for i : x0..x1 { x = i;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+4, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("2", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 32; {
		//End of second iteration for i : x0..x1 {};
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 33; {
		//Start of third iteration for i : x0..x1 {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 34; {
		//In third iteration for i : x0..x1 { x = i;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+4, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 35; {
		//End third iteration for i : x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 36; {
		//Start fourth iteration for i : x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}

		CodeBPForTest(14, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 37; {
		//Start first iteration for < x0..x1 {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(5, it_value);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 38; {
		//In first iteration for < x0..x1 { x = it;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index+4, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 39; {
		//End first iteration for < x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 40; {
		//Start second iteration for < x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 41; {
		//In second iteration for < x0..x1 { x = it;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index+4, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 42; {
		//End second iteration for < x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 43; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 44; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 45; {
		//End third iteration for < x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("2", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 46; {
		//Start fourth iteration for < x0..x1 {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+5, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[3];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("2", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 47; {
		//Out of all for loops
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(5, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[4];
			AssertEquals(bp.asm_index+6, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(3, c_frame.frame_vars.count);
			if count_equals {
				it_watch := GetWatch("it", text_op.watch_data_rows);
				AssertEquals(true, it_watch.is_error);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("2", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ForLoopRangePointer :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	x : int;
	x0 : int = 2;
	px0 : *int = *x0;
	x1 : int = 4;
	px1 : *int = *x1;
	for i : px0.*..px1.* {
		x = i;
	}
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 15+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		comp_success : bool = AssertEquals(false, IsCompilationFail(text_op.text_comp_data));
		if !comp_success {
			EndTest(*perm.test_data);
		} else {
			AddWatchDataForTest(.["x", "i"], text_op);
			CodeBPForTest(5, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		}
	}
	case 4; {
		//Before the for scope
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(1, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
		}	

		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	} 
	case 5; {
		//Start first iteration for i : px0.*..px1.* {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				AssertEquals(TypeInfoTag.INTEGER, i_var.t_info.type_enum);
				AssertEquals(for_scope.id, i_var.scope_id);
				AssertEquals(for_scope.function_id, i_var.function_id);
				it_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 6; {
		//At for i : px0.*..px1.* { x = i;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+8, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 7; {
		//At end of first iteration for i : x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 8; {
		//Start of second iteration for i : x0..x1
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 9; {
		//In second iteration for i : x0..x1 { x = i;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+8, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("2", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 10; {
		//End of second iteration for i : x0..x1 {};
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 11; {
		//Start of third iteration for i : x0..x1 {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 12; {
		//In third iteration for i : x0..x1 { x = i;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+8, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 13; {
		//End third iteration for i : x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 14; {
		//Start fourth iteration for i : x0..x1 { }
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+5, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("i", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(4, it_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 15; {
		//Out of all for loops
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp.asm_index+10, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(5, c_frame.frame_vars.count);
			if count_equals {
				it_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals(true, it_watch.is_error);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ForLoopArray :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	x : int;
	fa := int.[1,3];
	for fa {
		x += it;
	}

	av : [] int = fa;
	for av {
		x += it;
	}

	fap : *[2] int = *fa;
	for fap.* {
		x += it;
	}

	ap : *[] int = *av;
	for ap.* {
		x += it;
	}
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 34+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		AddWatchDataForTest(.["it", "it_index", "x"], text_op);
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		//Before the for scope
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(4, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 5; {
		//Start of for scope now - at "for fa {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 6; {
		//In the for scope now - at for fa { "x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 7; {
		//End of first for loop iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 8; {
		//Start of first loop second iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 9; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 10; {
		//End of first loop second iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		//Start of first loop third iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 12; {
		//"av : [] int = fa;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+13, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(5, c_frame.frame_vars.count);
		}

		CodeBPForTest(8, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 13; {
		//Start of second loop - at "for av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 14; {
		//Inside second loop - at "for av { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 15; {
		//End of second loop first iteration - at "for av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 16; {
		//Second loop second iteration - at "for av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 17; {
		//Second loop second iteration - at "for av { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 18; {
		//End Second loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 19; {
		//End Second loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		CodeBPForTest(13, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 20; {
		//Start of third loop - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 21; {
		//Inside third loop - at "for fap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+10, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 22; {
		//End of third loop first iteration - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 23; {
		//Third loop second iteration - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 24; {
		//Third loop second iteration - at "for fap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+10, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 25; {
		//End Third loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 26; {
		//End Third loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		CodeBPForTest(18, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 27; {
		//Start of fourth loop - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+15, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 28; {
		//Inside fourth loop - at "for ap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+14, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 29; {
		//End of fourth loop first iteration - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+15, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 30; {
		//Fourth loop second iteration - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 31; {
		//Fourth loop second iteration - at "for ap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+14, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 32; {
		//End Fourth loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+15, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 33; {
		//End Fourth loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+15, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(3, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 34; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+16, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		x_watch := GetWatch("x", text_op.watch_data_rows);
		AssertEquals("16", x_watch.value_str);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ForLoopArrayPointer :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	x : float;
	fa := float.[1,3];
	for * fa {
		it.* = 3.;
	}

	av : [] float = NewArray(3, float);
	for * av {
		it.* = 14.1;
	}

	fap : *[2] float = *fa;
	for * i : fap.* {
		x = i.*;
	}

	ap : *[] float = *av;
	for * i, y_ind : ap.* {
		x = i.*;
	}
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 40+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		if IsCompilationFail(text_op.text_comp_data) {
			EndTest(*perm.test_data);
		} else {
			AddWatchDataForTest(.["it", "it_index", "x"], text_op);
			CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		}
	}
	case 4; {
		//Before the for scope
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(4, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(5, c_frame.frame_vars.count);
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 5; {
		//Start of for scope now - at "for fa {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 6; {
		//In the for scope now - at for fa { "x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(8, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("float", x_watch.type_str);
				AssertEquals("0", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 7; {
		//End of first for loop iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(8, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 8; {
		//Start of first loop second iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_watch := GetWatch("it", text_op.watch_data_rows);
				AssertEquals("*float", it_watch.type_str);
				AssertEquals("8", it_watch.value_str);

				it_index_watch := GetWatch("it_index", text_op.watch_data_rows);
				AssertEquals("int", it_index_watch.type_str);
				AssertEquals("0", it_index_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 9; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 10; {
		//End of first loop second iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_watch := GetWatch("it", text_op.watch_data_rows);
				AssertEquals("*float", it_watch.type_str);
				AssertEquals("16", it_watch.value_str);

				it_index_watch := GetWatch("it_index", text_op.watch_data_rows);
				AssertEquals("int", it_index_watch.type_str);
				AssertEquals("1", it_index_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		//Start of first loop third iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_watch := GetWatch("it", text_op.watch_data_rows);
				AssertEquals("*float", it_watch.type_str);
				AssertEquals("16", it_watch.value_str);

				it_index_watch := GetWatch("it_index", text_op.watch_data_rows);
				AssertEquals("int", it_index_watch.type_str);
				AssertEquals("1", it_index_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 12; {
		//"av : [] int = fa;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+13, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(5, c_frame.frame_vars.count);
		}

		CodeBPForTest(8, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 13; {
		//Start of second loop - at "for * av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals("it", it_var.name);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 14; {
		//Inside second loop - at "for * av { x = it.*;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 15; {
		//End of second loop first iteration - at "for av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("float", x_watch.type_str);
				AssertEquals("0", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 16; {
		//Second loop second iteration - at "for av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("float", x_watch.type_str);
				AssertEquals("0", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 17; {
		//Second loop second iteration - at "for av { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("float", x_watch.type_str);
				AssertEquals("0", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 18; {
		//End Second loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 19; {
		//Second loop third iteration - at "for * av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 20; {
		//Second loop third iteration - at "for * av { x = it.*;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 21; {
		//End Second loop third iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 22; {
		//End Second loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[5];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, it_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_index_value);
			}
		}


		CodeBPForTest(13, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 23; {
		//Start of third loop - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, i_var.t_info.type_enum);
				AssertEquals("i", i_var.name);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 24; {
		//Inside third loop - at "for fap.* { x = i.*;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+8, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, i_var.t_info.type_enum);
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(8, i_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 25; {
		//End of third loop first iteration - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, i_var.t_info.type_enum);
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(8, i_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 26; {
		//Third loop second iteration - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, i_var.t_info.type_enum);
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(8, i_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 27; {
		//Third loop second iteration - at "for fap.* { x = i.*;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+8, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(16, i_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 28; {
		//End Third loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(16, i_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 29; {
		//End Third loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(16, i_value);

				it_index_var := c_frame.frame_vars[6];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("3", x_watch.value_str);
			}
		}


		CodeBPForTest(18, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 30; {
		//Start of fourth loop - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+15, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, i_var.t_info.type_enum);
				AssertEquals("i", i_var.name);

				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals("y_ind", y_var.name);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 31; {
		//Inside fourth loop - at "for ap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, i_var.t_info.type_enum);
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, y_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 32; {
		//End of fourth loop first iteration - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+15, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, y_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("14.1", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 33; {
		//Fourth loop second iteration - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, y_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("14.1", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 34; {
		//Fourth loop second iteration - at "for ap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, y_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("14.1", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 35; {
		//End Fourth loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+15, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, i_var.t_info.type_enum);
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, y_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("14.1", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 36; {
		//Fourth loop third iteration - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, y_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("14.1", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 37; {
		//Fourth loop second iteration - at "for ap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, y_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("14.1", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 38; {
		//End Fourth loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+15, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals(TypeInfoTag.POINTER, i_var.t_info.type_enum);
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, y_value);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("14.1", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 39; {
		//End Fourth loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+15, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(7, c_frame.frame_vars.count);
			if count_equals {
				i_var := c_frame.frame_vars[5];
				AssertEquals("i", i_var.name);
				i_value := ComputeOperandInt(i_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, i_value);

				y_var := c_frame.frame_vars[6];
				AssertEquals("y_ind", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, y_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 40; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+16, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		x_watch := GetWatch("x", text_op.watch_data_rows);
		AssertEquals("14.1", x_watch.value_str);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ForLoopArrayReverse :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	i : int;
	fa := int.[11,13];
	for < fa {
		i = it;
	}

	f : float;
	av : [] float = NewArray(3, float);
	av[2] = 4.5;
	for < * y, y_ind : av {
		f = y.*;
	}

	fap : *[2] int = *fa;
	for * < x : fap.* {
		i = x.*;
	}

	ap : *[] float = *av;
	for < n, n_ind : ap.* {
		f = n;
	}
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 40+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		if IsCompilationFail(text_op.text_comp_data) {
			EndTest(*perm.test_data);
		} else {
			AddWatchDataForTest(.["it", "it_index", "i", "f"], text_op);
			CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		}
	}
	case 4; {
		//Before the for scope
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(4, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(6, c_frame.frame_vars.count);
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 5; {
		//Start of for scope now - at "for < fa {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[6];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 6; {
		//In the for scope now - at for fa { "x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[6];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(13, it_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);

				i_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("int", i_watch.type_str);
				AssertEquals("0", i_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 7; {
		//End of first for loop iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[6];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(13, it_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);

				i_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("int", i_watch.type_str);
				AssertEquals("13", i_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 8; {
		//Start of first loop second iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				it_watch := GetWatch("it", text_op.watch_data_rows);
				AssertEquals("int", it_watch.type_str);
				AssertEquals("13", it_watch.value_str);

				it_index_watch := GetWatch("it_index", text_op.watch_data_rows);
				AssertEquals("int", it_index_watch.type_str);
				AssertEquals("1", it_index_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 9; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 10; {
		//End of first loop second iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				it_watch := GetWatch("it", text_op.watch_data_rows);
				AssertEquals("int", it_watch.type_str);
				AssertEquals("11", it_watch.value_str);

				it_index_watch := GetWatch("it_index", text_op.watch_data_rows);
				AssertEquals("int", it_index_watch.type_str);
				AssertEquals("0", it_index_watch.value_str);

				i_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("int", i_watch.type_str);
				AssertEquals("11", i_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		//Start of first loop third iteration - at for fa {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+2, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				it_watch := GetWatch("it", text_op.watch_data_rows);
				AssertEquals("int", it_watch.type_str);
				AssertEquals("11", it_watch.value_str);

				it_index_watch := GetWatch("it_index", text_op.watch_data_rows);
				AssertEquals("int", it_index_watch.type_str);
				AssertEquals("0", it_index_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 12; {
		//"av : [] int = fa;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+13, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(6, c_frame.frame_vars.count);
		}

		CodeBPForTest(10, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 13; {
		//Start of second loop - at "for < * y, y_ind : av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals("y", y_var.name);

				y_ind_var := c_frame.frame_vars[7];
				AssertEquals("y_ind", y_ind_var.name);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 14; {
		//Inside second loop - at "for * av { x = it.*;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, y_ind_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 15; {
		//End of second loop first iteration - at "for av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals(TypeInfoTag.INTEGER, y_ind.t_info.type_enum);
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, y_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("float", f_watch.type_str);
				AssertEquals("4.5", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 16; {
		//Second loop second iteration - at "for av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+16, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals(TypeInfoTag.INTEGER, y_ind.t_info.type_enum);
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, y_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("float", f_watch.type_str);
				AssertEquals("4.5", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 17; {
		//Second loop second iteration - at "for av { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals(TypeInfoTag.INTEGER, y_ind.t_info.type_enum);
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, y_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("float", f_watch.type_str);
				AssertEquals("4.5", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 18; {
		//End Second loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals(TypeInfoTag.INTEGER, y_ind.t_info.type_enum);
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, y_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("float", f_watch.type_str);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 19; {
		//Second loop third iteration - at "for * av {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size+8, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals(TypeInfoTag.INTEGER, y_ind.t_info.type_enum);
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, y_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("float", f_watch.type_str);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 20; {
		//Second loop third iteration - at "for * av { x = it.*;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+9, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals(TypeInfoTag.INTEGER, y_ind.t_info.type_enum);
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, y_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("float", f_watch.type_str);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 21; {
		//End Second loop third iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+12, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals(TypeInfoTag.INTEGER, y_ind.t_info.type_enum);
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, y_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("float", f_watch.type_str);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 22; {
		//End Second loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp1 : DebugBreakpoint;
		if count_equals {
			bp1 = text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp1.asm_index, for_scope.start_instr_index);
				AssertEquals(bp1.asm_index+12, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals("y", y_var.name);
				y_value := ComputeOperandInt(y_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(perm.all_data.ram_memory.stack_size, y_value);

				y_ind := c_frame.frame_vars[7];
				AssertEquals(TypeInfoTag.INTEGER, y_ind.t_info.type_enum);
				AssertEquals("y_ind", y_ind.name);
				y_ind_value := ComputeOperandInt(y_ind.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, y_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("float", f_watch.type_str);
				AssertEquals("0", f_watch.value_str);
			}
		}

		CodeBPForTest(15, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 23; {
		//Start of third loop - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, x_var.t_info.type_enum);
				AssertEquals("x", x_var.name);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 24; {
		//Inside third loop - at "for fap.* { x = i.*;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+8, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, x_var.t_info.type_enum);
				AssertEquals("x", x_var.name);
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(16, x_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 25; {
		//End of third loop first iteration - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, x_var.t_info.type_enum);
				AssertEquals("x", x_var.name);
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(16, x_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);

				x_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("13", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 26; {
		//Third loop second iteration - at "for fap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, x_var.t_info.type_enum);
				AssertEquals("x", x_var.name);
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(16, x_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);

				x_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("13", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 27; {
		//Third loop second iteration - at "for fap.* { x = i.*;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+8, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, x_var.t_info.type_enum);
				AssertEquals("x", x_var.name);
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(8, x_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				x_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("13", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 28; {
		//End Third loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+11, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, x_var.t_info.type_enum);
				AssertEquals("x", x_var.name);
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(8, x_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				x_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("11", x_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 29; {
		//End Third loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(bp.asm_index+2, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(3, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.POINTER, x_var.t_info.type_enum);
				AssertEquals("x", x_var.name);
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(8, x_value);

				it_index_var := c_frame.frame_vars[7];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				x_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("11", x_watch.value_str);
			}
		}


		CodeBPForTest(20, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 30; {
		//Start of fourth loop - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+14, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 31; {
		//Inside fourth loop - at "for ap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+13, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(4.5, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, n_ind_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 32; {
		//End of fourth loop first iteration - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+14, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(4.5, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, n_ind_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 33; {
		//Fourth loop second iteration - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(4.5, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, n_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("4.5", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 34; {
		//Fourth loop second iteration - at "for ap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+13, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(0, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, n_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("4.5", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 35; {
		//End Fourth loop second iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+14, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(0, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, n_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 36; {
		//Fourth loop third iteration - at "for ap.* {"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(0, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, n_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 37; {
		//Fourth loop third iteration - at "for ap.* { x += 1;"
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+13, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(0, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, n_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 38; {
		//End Fourth loop third iteration
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+14, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(0, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, n_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 39; {
		//End Fourth loop
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+3, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp.asm_index, for_scope.start_instr_index);
				AssertEquals(bp.asm_index+14, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(8, c_frame.frame_vars.count);
			if count_equals {
				n_var := c_frame.frame_vars[6];
				AssertEquals(TypeInfoTag.FLOAT, n_var.t_info.type_enum);
				AssertEquals("n", n_var.name);
				n_value := ComputeMemoryValue(n_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory).float_value;
				AssertFloat64Equals(0, n_value);

				n_ind_var := c_frame.frame_vars[7];
				AssertEquals("n_ind", n_ind_var.name);
				n_ind_value := ComputeOperandInt(n_ind_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, n_ind_value);

				f_watch := GetWatch("f", text_op.watch_data_rows);
				AssertEquals("0", f_watch.value_str);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 40; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(4, text_op.exec_info.debug_info.break_points.count);
		bp : DebugBreakpoint;
		if count_equals {
			bp = text_op.exec_info.debug_info.break_points[3];
			AssertEquals(bp.asm_index+15, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}
		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(4, c_frame.all_scopes_in_function.count);
			AssertEquals(4, c_frame.s_index);

			AssertEquals(0, c_frame.call_open_scopes.count);
		}

		f_watch := GetWatch("f", text_op.watch_data_rows);
		AssertEquals("0", f_watch.value_str);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ForArray :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  a : [2] int;
  for a {
    y : int = it;
  }
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 11);
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
	case 3; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(1, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		//Before the for scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(1, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, a_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, a_var.function_id);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 5; {
		//In the for scope now on first line - for a
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+1, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				y_var := c_frame.frame_vars[3];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(for_scope.id, y_var.scope_id);
				AssertEquals(for_scope.function_id, y_var.function_id);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 6; {
		//y : int = it;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+10, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}
		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(4, c_frame.frame_vars.count);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 7; {
		//At the close "}" of the foor loop for we add to "it" and reset the scope.
		//TODO Eventually we will likely not reset the scope and just store all stack positions directly.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			AssertEquals(4, c_frame.frame_vars.count);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 8; {
		//Back at the for scope now - at for 0..1
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				array_data_address : int = 
					ComputeRAMLocation(a_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);

				//We increment it at the bottom of the for loop so it should be 1 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}

		//TODO FROM HERE finish this test and then add a for < test and then
		//do 1 for * unit and 1 for * integration test for completeness for now.
		//could do a for * < to check (or not for now to reduce tests until we complete it)
		//CLEANUP UNIT TESTS AND CODE GENERATION FOR FOR LOOPS AFTER
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 9; {
		//Back at for a {} start loop for the 3rd time. Should be jumping out after
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				array_data_address : int = 
					ComputeRAMLocation(a_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);

				//We increment it at the bottom of the for loop so it should be 1 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 10; {
		//After the for scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);
		AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(1, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, a_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, a_var.function_id);
			}
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ForRevArray :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  a : [2] int;
  for < a {
    y : int = it_index;
  }
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 14);
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
	case 3; {
		count_equals : bool = AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
			AssertEquals(true, text_op.text_comp_data.comp_errors.all_compiler_errors.count == 0);
			CodeBPForTest(1, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		} else {
			EndTest(*perm.test_data);
		}
	}
	case 4; {
		//Before the for scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(1, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, a_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, a_var.function_id);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 5; {
		//In the for scope now on first line - for a
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+1, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+11, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				y_var := c_frame.frame_vars[3];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(for_scope.id, y_var.scope_id);
				AssertEquals(for_scope.function_id, y_var.function_id);
			}
		}


		DownUpInputMap(.TEXT_BOTTOM_LEFT_PANE, game_input);
	} 
	case 6; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 7; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		//Should be 1 after the for < a line since we just stepped over it to check if it_index is set to a.count-1
		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);

		count_equals := AssertEquals(1, c_frame.call_open_scopes.count);
		for_scope : ScopeData;
		if count_equals {
			for_scope = c_frame.call_open_scopes[0];
			AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
			AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
		}

		//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
		//see how the variables change through the for loop cycles and not for it to reset each for loop.
		count_equals = AssertEquals(4, c_frame.frame_vars.count);
		if count_equals {
			it_index_var := c_frame.frame_vars[2];
			AssertEquals("it_index", it_index_var.name);
			AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
			AssertEquals(for_scope.id, it_index_var.scope_id);
			AssertEquals(for_scope.function_id, it_index_var.function_id);
			it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
			AssertEquals(2, it_index_value);
		}


		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 8; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 9; {
		//y : int = it;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		d_line := GetDebugLineNumber(3, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);


		//TEST Here next if we stop within the range of the code array
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 10; {
		//Back at the for scope now for 2nd time
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				//We increment it at the bottom of the for loop so it should be 1 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 11; {
		//Back at for a {} start loop for the 3rd time. Should be jumping out after since it_index == -1
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				//We increment it at the bottom of the for loop so it should be 1 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		AsmBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 12; {
		//TEST Stopped at the asm debug breakpoint just before jmp out of for loop
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.break_points.count);
		asm_bp : DebugBreakpoint;
		if count_equals {
			asm_bp = text_op.exec_info.debug_info.break_points[2];
			AssertEquals(asm_bp.bp_type, BreakpointType.BP_ASM);
			AssertEquals(asm_bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 13; {
		//After the for scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);
		AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(1, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);
			AssertEquals(1, c_frame.frame_vars.count);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ForPointerArray :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  a : [2] int;
  for * a {
    y : *int = it;
  }
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 10);
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
	case 3; {
		count_equals : bool = AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
			AssertEquals(true, text_op.text_comp_data.comp_errors.all_compiler_errors.count == 0);
			CodeBPForTest(1, *text_op.exec_info.debug_info, text_op.text_comp_data);
			CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		} else {
			EndTest(*perm.test_data);
		}
	}
	case 4; {
		//Before the for scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, a_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, a_var.function_id);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 5; {
		//In the for scope now on first line - for a
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+1, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+9, for_scope.end_instr_index);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);

				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				int_p_info := GetTypeInfoPointer(*text_op.text_comp_data.int_type_info, text_op.text_comp_data);
				AssertEquals(int_p_info, cast(*TypeInfoPointer) it_var.t_info);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				//NOTE : We don't check the value here because it has not been set yet
				// it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				// a_address : int = ComputeRAMLocation(a_var.op, all_register_memory, ram);
				// //Because a is a fixed array, the op is the data pointer since we store the values directly in memory
				// //without any count,data pointing towards it.
				// AssertEquals(a_address, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_index_var.scope_id);
				AssertEquals(for_scope.function_id, it_index_var.function_id);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);

				y_var := c_frame.frame_vars[3];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.POINTER, y_var.t_info.type_enum);
				AssertEquals(int_p_info, cast(*TypeInfoPointer) y_var.t_info);
				AssertEquals(for_scope.id, y_var.scope_id);
				AssertEquals(for_scope.function_id, y_var.function_id);
			}
		}


		// DownUpInputMap(.TEXT_BOTTOM_LEFT_PANE, game_input);
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 6; {
		//y : int = it;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		d_line := GetDebugLineNumber(3, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 7; {
		//Back at the for scope now for 2nd time
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);

				//We increment it at the bottom of the for loop so it should be 1 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				//We should have the previous loops address here
				a_address : int = ComputeRAMLocation(a_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(a_address, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 8; {
		//Back at for a {} start loop for the 3rd time. Should be jumping out after since it_index == -1
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];

			//note the for scope is still open and never closed
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
			}

			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);

				//We increment it at the bottom of the for loop so it should be 1 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				//We should have the previous loops address here (a.data + 8) since we don't want any invalid pointers
				//to be computed.
				a_address : int = ComputeRAMLocation(a_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(a_address+8, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 9; {
		//After the for scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);
		AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			count_equals = AssertEquals(1, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);
			AssertEquals(1, c_frame.frame_vars.count);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ForPtrRevArray :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  a : [2] int;
  for * < a {
    y : *int = it;
  }
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 6);
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
	case 3; {
		count_equals : bool = AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
			AssertEquals(true, text_op.text_comp_data.comp_errors.all_compiler_errors.count == 0);
			CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		} else {
			EndTest(*perm.test_data);
		}
	}
	case 4; {
		//End of for scope }
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);

				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.POINTER, it_var.t_info.type_enum);
				int_p_info := GetTypeInfoPointer(*text_op.text_comp_data.int_type_info, text_op.text_comp_data);
				AssertEquals(int_p_info, cast(*TypeInfoPointer) it_var.t_info);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				//We should have the previous loops address here
				a_address : int = ComputeRAMLocation(a_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(a_address+8, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_index_var.t_info.type_enum);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_index_value);
			}
		}

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	}
	case 5; {
		//Back at the end of for scope now for 2nd time
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			count_equals = AssertEquals(4, c_frame.frame_vars.count);
			if count_equals {
				a_var := c_frame.frame_vars[0];
				//We increment it at the bottom of the for loop so it should be 1 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				//We should have the previous loops address here
				a_address : int = ComputeRAMLocation(a_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(a_address, it_value);

				it_index_var := c_frame.frame_vars[2];
				AssertEquals("it_index", it_index_var.name);
				it_index_value := ComputeOperandInt(it_index_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_index_value);
			}
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CompileArray :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	fa : [4] int;
	fc : int = fa.count;
	fa[0] = 9;
	fa.data[1] = 10;
	fi : int = fa[0];
	fi = fa.data[1];

	a : [] int = fa;
	c : int = a.count;
	a[2] = 4;
	a.data[3] = 5;
	i : int = a[2];
	i = a.data[3];
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 12+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		AddWatchDataForTest(.["fc", "fi", "c", "i", "fa"], text_op);
		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 8; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 9; DownUpThisFrame(.ENTER, game_input);
	case 10; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);
			AssertEquals(6, c_frame.frame_vars.count);

			fc_watch := GetWatch("fc", text_op.watch_data_rows);
			AssertEquals("4", fc_watch.value_str);

			fi_watch := GetWatch("fi", text_op.watch_data_rows);
			AssertEquals("9", fi_watch.value_str);

			fa0 := GetWatch("fa[0]", text_op.watch_data_rows);
			AssertEquals("9", fa0.value_str);

			fa1 := GetWatch("fa[1]", text_op.watch_data_rows);
			AssertEquals("10", fa1.value_str);
		}	

		CodeBPForTest(13, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	}
	case 11; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp := text_op.exec_info.debug_info.break_points[1];
		AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		fc_watch := GetWatch("fc", text_op.watch_data_rows);
		AssertEquals("4", fc_watch.value_str);

		fi_watch := GetWatch("fi", text_op.watch_data_rows);
		AssertEquals("10", fi_watch.value_str);

		i_watch := GetWatch("i", text_op.watch_data_rows);
		AssertEquals("4", i_watch.value_str);

		fa0 := GetWatch("fa[0]", text_op.watch_data_rows);
		AssertEquals("9", fa0.value_str);

		fa1 := GetWatch("fa[1]", text_op.watch_data_rows);
		AssertEquals("10", fa1.value_str);

		fa2 := GetWatch("fa[2]", text_op.watch_data_rows);
		AssertEquals("4", fa2.value_str);

		fa3 := GetWatch("fa[3]", text_op.watch_data_rows);
		AssertEquals("5", fa3.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 12; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		fc_watch := GetWatch("fc", text_op.watch_data_rows);
		AssertEquals("4", fc_watch.value_str);

		fi_watch := GetWatch("fi", text_op.watch_data_rows);
		AssertEquals("10", fi_watch.value_str);

		i_watch := GetWatch("i", text_op.watch_data_rows);
		AssertEquals("5", i_watch.value_str);

		fa0 := GetWatch("fa[0]", text_op.watch_data_rows);
		AssertEquals("9", fa0.value_str);

		fa1 := GetWatch("fa[1]", text_op.watch_data_rows);
		AssertEquals("10", fa1.value_str);

		fa2 := GetWatch("fa[2]", text_op.watch_data_rows);
		AssertEquals("4", fa2.value_str);

		fa3 := GetWatch("fa[3]", text_op.watch_data_rows);
		AssertEquals("5", fa3.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CompileMultiArray :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
//TODO FROM HERE Update unit tests and write some simple multi-dimensional unit tests for fixed array and array view
//and also 1 integration test with a 3d array combination for completion
//ALSO cleanup code to remove old cases and check pointer case above
//TODO Then do structs with arrays inside and maybe 1 multidimensional array
//although honestly multi dimensional arrays should be discouraged due to memory confusion
#string DONE
main :: () {
	f : [3][3] int;
	f[2][1] = 5;
	f[1].data[2] = 10;

	t : int = f[1][2];
	t = f[2].data[1];
	t = f[1].count;

	f_1 : [3] int = f[1];

	d : *[3] int = f.data;
	da : *int = f.data[2].data;
	dp : *[3] int = *f[1];
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 25+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		comp_success : bool = AssertEquals(false, IsCompilationFail(text_op.text_comp_data));
		if !comp_success {
			EndTest(*perm.test_data);
		} else {
			AddWatchDataForTest(.["t", "f_1", "f", "d", "da", "dp"], text_op);
			CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		}
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ENTER, game_input);
	case 8; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 9; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 10; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 11; DownUpThisFrame(.ENTER, game_input);
	case 12; DownUpThisFrame(.ARROW_UP, game_input);
	case 13; DownUpThisFrame(.ENTER, game_input);
	case 14; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);
			AssertEquals(6, c_frame.frame_vars.count);

			f := GetWatch("f", text_op.watch_data_rows);
			AssertEquals("[3][3] int", f.type_str);

			f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
			AssertEquals("5", f21.value_str);
			f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
			AssertEquals("10", f12.value_str);

			t_watch := GetWatch("t", text_op.watch_data_rows);
			AssertEquals("10", t_watch.value_str);
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 15; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
		AssertEquals("5", f21.value_str);
		f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
		AssertEquals("10", f12.value_str);

		t_watch := GetWatch("t", text_op.watch_data_rows);
		AssertEquals("5", t_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 16; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
		AssertEquals("5", f21.value_str);
		f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
		AssertEquals("10", f12.value_str);

		t_watch := GetWatch("t", text_op.watch_data_rows);
		AssertEquals("3", t_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 17; DownUpThisFrame(.ARROW_UP, game_input);
	case 18; DownUpThisFrame(.ARROW_UP, game_input);
	case 19; DownUpThisFrame(.ENTER, game_input);
	case 20; DownUpThisFrame(.ARROW_UP, game_input);
	case 21; DownUpThisFrame(.ENTER, game_input);
	case 22; DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	case 23; DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	case 24; DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	case 25; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f1_2 := GetWatch("f_1[2]", text_op.watch_data_rows);
		AssertEquals("10", f1_2.value_str);
		AssertEquals("int", f1_2.type_str);

		d_watch := GetWatch("d", text_op.watch_data_rows);
		AssertEquals("0", d_watch.value_str);
		AssertEquals("*[3] int", d_watch.type_str);

		da_watch := GetWatch("da", text_op.watch_data_rows);
		AssertEquals("48", da_watch.value_str);
		AssertEquals("*int", da_watch.type_str);

		dp_watch := GetWatch("dp", text_op.watch_data_rows);
		AssertEquals("24", dp_watch.value_str);
		AssertEquals("*[3] int", dp_watch.type_str);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_MultiArrayView :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//Honestly, this is so confusing it should just be banned. Maybe we just allow fixed multi-dimensional arrays
#string DONE
main :: () {
	f : [][] int = NewArray(3, [] int);
	f[0] = NewArray(3, int);
	f[1] = NewArray(3, int);
	f[2] = NewArray(3, int);
	f[2].data[1] = 5;
	f[1][2] = 10;

	t : int = f[1][2];
	t = f[2].data[1];
	t = f[1].count;

	f_1 : [] int = f[1];

	d : *[] int = f.data;
	da : *int = f.data[0].data;
	dp : *[] int = *f[1];
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 25+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		comp_success : bool = AssertEquals(false, IsCompilationFail(text_op.text_comp_data));
		if !comp_success {
			EndTest(*perm.test_data);
		} else {
			AddWatchDataForTest(.["t", "f_1", "f", "d", "da", "dp"], text_op);
			CodeBPForTest(9, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		}
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ENTER, game_input);
	case 8; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 9; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 10; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 11; DownUpThisFrame(.ENTER, game_input);
	case 12; DownUpThisFrame(.ARROW_UP, game_input);
	case 13; DownUpThisFrame(.ENTER, game_input);
	case 14; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);
			AssertEquals(6, c_frame.frame_vars.count);

			f := GetWatch("f", text_op.watch_data_rows);
			AssertEquals("[][] int", f.type_str);

			f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
			AssertEquals("5", f21.value_str);
			f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
			AssertEquals("10", f12.value_str);

			t_watch := GetWatch("t", text_op.watch_data_rows);
			AssertEquals("10", t_watch.value_str);
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 15; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
		AssertEquals("5", f21.value_str);
		f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
		AssertEquals("10", f12.value_str);

		t_watch := GetWatch("t", text_op.watch_data_rows);
		AssertEquals("5", t_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 16; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
		AssertEquals("5", f21.value_str);
		f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
		AssertEquals("10", f12.value_str);

		t_watch := GetWatch("t", text_op.watch_data_rows);
		AssertEquals("3", t_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 17; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 18; DownUpThisFrame(.ARROW_UP, game_input);
	case 19; DownUpThisFrame(.ARROW_UP, game_input);
	case 20; DownUpThisFrame(.ENTER, game_input);
	case 21; DownUpThisFrame(.ARROW_UP, game_input);
	case 22; DownUpThisFrame(.ENTER, game_input);
	case 23; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 24; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 25; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f1_2 := GetWatch("f_1[2]", text_op.watch_data_rows);
		AssertEquals("10", f1_2.value_str);

		d_watch := GetWatch("d", text_op.watch_data_rows);
		array_address : int = perm.all_data.ram_memory.stack_size;
		AssertEquals(sprint("%", array_address), d_watch.value_str);
		AssertEquals("*[] int", d_watch.type_str);

		da_watch := GetWatch("da", text_op.watch_data_rows);
		//first actual int value
		array_address = perm.all_data.ram_memory.stack_size + 16*3;
		AssertEquals(sprint("%", array_address), da_watch.value_str);
		AssertEquals("*int", da_watch.type_str);

		dp_watch := GetWatch("dp", text_op.watch_data_rows);
		//second array view
		array_address = perm.all_data.ram_memory.stack_size+16;
		AssertEquals(sprint("%", array_address), dp_watch.value_str);
		AssertEquals("*[] int", dp_watch.type_str);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_MultiArrayViewFixed :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//Again this is SO confusing in terms of memory location, it should not even be used ever
#string DONE
main :: () {
	f : [][3] int = NewArray(3, [3] int);
	f[0] = int.[0,0,0];
	f[1] = int.[0,0,0];
	f[2] = int.[0,0,0];
	f[2].data[1] = 5;
	f[1].data[2] = 10;

	t : int = f[1][2];
	t = f[2].data[1];
	t = f[1].count;

	f_1 : [3] int = f[1];

	d : *[3] int = f.data;
	da : *int = f.data[1].data;
	dp : *[3] int = *f[1];
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 25+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		comp_success : bool = AssertEquals(false, IsCompilationFail(text_op.text_comp_data));
		if !comp_success {
			EndTest(*perm.test_data);
		} else {
			AddWatchDataForTest(.["t", "f_1", "f", "d", "da", "dp"], text_op);
			CodeBPForTest(9, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		}
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ENTER, game_input);
	case 8; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 9; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 10; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 11; DownUpThisFrame(.ENTER, game_input);
	case 12; DownUpThisFrame(.ARROW_UP, game_input);
	case 13; DownUpThisFrame(.ENTER, game_input);
	case 14; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);
			AssertEquals(6, c_frame.frame_vars.count);

			f := GetWatch("f", text_op.watch_data_rows);
			AssertEquals("[][3] int", f.type_str);

			f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
			AssertEquals("5", f21.value_str);
			f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
			AssertEquals("10", f12.value_str);

			t_watch := GetWatch("t", text_op.watch_data_rows);
			AssertEquals("10", t_watch.value_str);
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 15; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
		AssertEquals("5", f21.value_str);
		f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
		AssertEquals("10", f12.value_str);

		t_watch := GetWatch("t", text_op.watch_data_rows);
		AssertEquals("5", t_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 16; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f21 := GetWatch("f[2][1]", text_op.watch_data_rows);
		AssertEquals("5", f21.value_str);
		f12 := GetWatch("f[1][2]", text_op.watch_data_rows);
		AssertEquals("10", f12.value_str);

		t_watch := GetWatch("t", text_op.watch_data_rows);
		AssertEquals("3", t_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 17; DownUpThisFrame(.ARROW_UP, game_input);
	case 18; DownUpThisFrame(.ARROW_UP, game_input);
	case 19; DownUpThisFrame(.ENTER, game_input);
	case 20; DownUpThisFrame(.ARROW_UP, game_input);
	case 21; DownUpThisFrame(.ENTER, game_input);
	case 22; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 23; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 24; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 25; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f1_2 := GetWatch("f_1[2]", text_op.watch_data_rows);
		AssertEquals("10", f1_2.value_str);

		d_watch := GetWatch("d", text_op.watch_data_rows);
		array_address : int = perm.all_data.ram_memory.stack_size;
		AssertEquals(sprint("%", array_address), d_watch.value_str);
		AssertEquals("*[3] int", d_watch.type_str);

		da_watch := GetWatch("da", text_op.watch_data_rows);
		//first actual int value
		array_address = perm.all_data.ram_memory.stack_size + 8*3;
		AssertEquals(sprint("%", array_address), da_watch.value_str);
		AssertEquals("*int", da_watch.type_str);

		dp_watch := GetWatch("dp", text_op.watch_data_rows);
		//second fixed array
		array_address = perm.all_data.ram_memory.stack_size+8*3;
		AssertEquals(sprint("%", array_address), dp_watch.value_str);
		AssertEquals("*[3] int", dp_watch.type_str);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_MultiArray3D :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//Again this is SO confusing in terms of memory location, it should not even be used ever
#string DONE
main :: () {
	f : [][2][2] int = NewArray(3, [2][2] int);
	f[0][0] = int.[1,1];
	f[1][1][1] = 3;
	f[2].data[1].data[0] = 5;

	t : int = f[1][1][1];
	t = f[1][0].count;

	f_1 : [2][2] int = f[1];

	d : *[2][2] int = f.data;
	da : *[2] int = f.data[0].data;
	da2 : *int = f.data[0].data[1].data;
	dp : *[2] int = *(f[0][0]);
	dp2 : *int = *(f[0][1][0]);
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 36+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		comp_success : bool = AssertEquals(false, IsCompilationFail(text_op.text_comp_data));
		if !comp_success {
			EndTest(*perm.test_data);
		} else {
			AddWatchDataForTest(.["t", "f_1", "f", "d", "da", "dp", "da2", "dp2"], text_op);
			CodeBPForTest(7, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		}
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ENTER, game_input);
	case 9; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 10; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 11; DownUpThisFrame(.ENTER, game_input);
	case 12; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 13; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 14; DownUpThisFrame(.ENTER, game_input);
	case 15; DownUpThisFrame(.ARROW_UP, game_input);
	case 16; DownUpThisFrame(.ARROW_UP, game_input);
	case 17; DownUpThisFrame(.ARROW_UP, game_input);
	case 18; DownUpThisFrame(.ENTER, game_input);
	case 19; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 20; DownUpThisFrame(.ENTER, game_input);
	case 21; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);
			AssertEquals(8, c_frame.frame_vars.count);

			f := GetWatch("f", text_op.watch_data_rows);
			AssertEquals("[][2][2] int", f.type_str);

			f00 := GetWatch("f[0][0]", text_op.watch_data_rows);
			AssertEquals("[2] int", f00.type_str);

			f000 := GetWatch("f[0][0][0]", text_op.watch_data_rows);
			AssertEquals("1", f000.value_str);
			AssertEquals("int", f000.type_str);

			f001 := GetWatch("f[0][0][1]", text_op.watch_data_rows);
			AssertEquals("1", f001.value_str);
			AssertEquals("int", f001.type_str);

			f111 := GetWatch("f[1][1][1]", text_op.watch_data_rows);
			AssertEquals("3", f111.value_str);
			AssertEquals("int", f111.type_str);

			t_watch := GetWatch("t", text_op.watch_data_rows);
			AssertEquals("3", t_watch.value_str);
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 22; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f111 := GetWatch("f[1][1][1]", text_op.watch_data_rows);
		AssertEquals("3", f111.value_str);
		AssertEquals("int", f111.type_str);

		t_watch := GetWatch("t", text_op.watch_data_rows);
		AssertEquals("2", t_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 23; DownUpThisFrame(.ARROW_UP, game_input);
	case 24; DownUpThisFrame(.ARROW_UP, game_input);
	case 25; DownUpThisFrame(.ENTER, game_input);
	case 26; DownUpThisFrame(.ARROW_UP, game_input);
	case 27; DownUpThisFrame(.ENTER, game_input);
	case 28; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 29; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 30; DownUpThisFrame(.ENTER, game_input);
	case 31; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 32; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 33; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 34; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 35; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 36; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		f1_1 := GetWatch("f_1[1][1]", text_op.watch_data_rows);
		AssertEquals("3", f1_1.value_str);

		d_watch := GetWatch("d", text_op.watch_data_rows);
		array_address : int = perm.all_data.ram_memory.stack_size;
		AssertEquals(sprint("%", array_address), d_watch.value_str);
		AssertEquals("*[2][2] int", d_watch.type_str);

		da_watch := GetWatch("da", text_op.watch_data_rows);
		//first actual int value
		array_address = perm.all_data.ram_memory.stack_size;
		AssertEquals(sprint("%", array_address), da_watch.value_str);
		AssertEquals("*[2] int", da_watch.type_str);

		dp_watch := GetWatch("dp", text_op.watch_data_rows);
		//second fixed array
		AssertEquals(sprint("%", array_address), dp_watch.value_str);
		AssertEquals("*[2] int", dp_watch.type_str);

		da2_watch := GetWatch("da2", text_op.watch_data_rows);
		//first actual int value
		array_address = perm.all_data.ram_memory.stack_size + 8*2;
		AssertEquals(sprint("%", array_address), da2_watch.value_str);
		AssertEquals("*int", da2_watch.type_str);

		dp2_watch := GetWatch("dp2", text_op.watch_data_rows);
		//second fixed array
		AssertEquals(sprint("%", array_address), dp2_watch.value_str);
		AssertEquals("*int", dp2_watch.type_str);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_PointerArrayAccess :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	f : *float;
	#asm { alloc 32, f; }

	f[0] = 1.1;
	f[1] = 2.2;
	f[2] = 3.3;
	f[3] = 4.4;

	av : [] float;
	av.data = f;
	av.count = 4;

	pf : *float = *f[3];
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 7+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		comp_success : bool = AssertEquals(false, IsCompilationFail(text_op.text_comp_data));
		if !comp_success {
			EndTest(*perm.test_data);
		} else {
			AddWatchDataForTest(.["f", "av", "pf"], text_op);
			CodeBPForTest(14, *text_op.exec_info.debug_info, text_op.text_comp_data);
			DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
		}
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 6; DownUpThisFrame(.ENTER, game_input);
	case 7; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(0, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);
			AssertEquals(3, c_frame.frame_vars.count);

			f_watch := GetWatch("f", text_op.watch_data_rows);
			AssertEquals(sprint("%", perm.all_data.ram_memory.stack_size), f_watch.value_str);
			AssertEquals("*float", f_watch.type_str);

			f0 : float64 = GetMemValue(perm.all_data.ram_memory.stack_size, float64, perm.all_data.ram_memory);
			AssertFloat64Equals(1.1, f0);
			f1 : float64 = GetMemValue(perm.all_data.ram_memory.stack_size+8, float64, perm.all_data.ram_memory);
			AssertFloat64Equals(2.2, f1);
			f2 : float64 = GetMemValue(perm.all_data.ram_memory.stack_size+16, float64, perm.all_data.ram_memory);
			AssertFloat64Equals(3.3, f2);
			f3 : float64 = GetMemValue(perm.all_data.ram_memory.stack_size+24, float64, perm.all_data.ram_memory);
			AssertFloat64Equals(4.4, f3);

			av0 := GetWatch("av[0]", text_op.watch_data_rows);
			AssertEquals("1.1", av0.value_str);
			AssertEquals("float", av0.type_str);
			av1 := GetWatch("av[1]", text_op.watch_data_rows);
			AssertEquals("2.2", av1.value_str);
			AssertEquals("float", av1.type_str);
			av2 := GetWatch("av[2]", text_op.watch_data_rows);
			AssertEquals("3.3", av2.value_str);
			AssertEquals("float", av2.type_str);
			av3 := GetWatch("av[3]", text_op.watch_data_rows);
			AssertEquals("4.4", av3.value_str);
			AssertEquals("float", av3.type_str);

			pf := GetWatch("pf", text_op.watch_data_rows);
			array_address : int = perm.all_data.ram_memory.stack_size + 8*3;
			AssertEquals(sprint("%", array_address), pf.value_str);
			AssertEquals("*float", pf.type_str);
		}	

	}
	}

	ContinueTest(*perm.test_data);

} @ITest