//TODO Pull out larger scale test chunks here so we don't have any text editing issues since these test chunks seems to be in the 10k+ loc
//I think maybe we can also put tests in the same file as code if we separate some of it out eventually
#load "thegame_test_text.jai";
#load "thegame_test_2.jai";
/*
	All tests

	TODO easily run all tests (maybe can separate into unit / integration(play) / benny tests)
	TODO benny tests once we have playable levels

	TODO REMOVE ALL TESTS THAT ARE NOT USED ANYMORE ONCE NEW MODEL IS STABLE AND TESTED

Documentation : 
Note that Test_Name is used by AssertEquals for AccumulateTestResults to print out the stack_trace up the 
function stack until we hit a Test_Name so we know exactly which assertion failed and on which lines.
*/

// #load "thegame_unit_tests.jai";

//TODO I think it's better to use a regular Pool here so that the size can increase if needed. LOOK INTO THAT.
//TODO Can also have a persistent pool which does not get reset on every test like this one.
//OR we just use context.allocator or a passed in allocator to persist things since we don't know
//where we will want to persist logs anyways.
/*Documentation : This test_alloc is for each test and gets reset on each test, so it is only set to default 256 Megabytes flat pool.
Likely we only use < a few pages (4Kb pages) per test in most cases anyways.
We could have one for all tests put if we want to persist logs it seems better to use context.allocator
or some passed in allocator since we don't know where we will wnat them to persist. Then we would have to
not use test_alloc by default for unit tests.

Everything running in the test gets allocated with test_alloc so then we continue using that if we play with the test.
test_alloc_pool will get reset on the next test if we run another one. 
Generally tests should be used as tests and only played around with for testing purposes after running the integration test.
*/
/*NOTE REMINDER : We could have a separate allocator for unit test and integration tests so we can
run unit tests without affecting other tests if needed.
*/
//NOTE : Better to have this external so we can reset it whenever we want like in unit tests.
test_alloc_pool : Flat_Pool;
//NOTE: We set test_alloc.data in UpdateAndRenderTest
test_alloc := Allocator.{flat_pool_allocator_proc, null};



/*TODO One idea (maybe not for tests) is to have it pause after some inputs
and then we do more inputs and then you can run some more after.
I guess this could also be how we setup a level and then the player
plays more and then maybe runs something else after.

TODO I am leaving this here for now but if we never use it, then we can remove this an the procs in SubTestData
Using the other ContinueTest right now
*/
ContinueTest :: (gm : *GameMemory, rd : *RendererData, ad : *AudioData, game_input : *GameInput) {
	perm : *Persist = GetPermanentStorage(gm);
	if perm.test_data.sub_test_index < perm.test_data.all_sub_tests.count { 
		sub_test := *perm.test_data.all_sub_tests[perm.test_data.sub_test_index];

		//TODO Can remove this if we stop using proc by probably good to have for now.
		if sub_test.test_proc != null {
			wait_test : bool = WaitTest(*perm.test_data);
			if wait_test return;

			sub_test.test_proc(perm, gm, rd, ad, game_input);
		}

		UpdateTestIndex(sub_test, *perm.test_data);
		perm.test_data.test_state = .TEST_CONTINUE;
	} else {
		perm.test_data.test_state = .TEST_FINISHED;
	}
}

WaitTest :: inline (test_data : *TestData) -> bool {
	//TODO This could be an assertions since we should not have sub_test_index >= all_sub_tests.count
	//since we end it in ContinueTest and put it to finished at sub_test_index-1 == all_sub_tests.count
	if test_data.sub_test_index < test_data.all_sub_tests.count {
		sub_test := *test_data.all_sub_tests[test_data.sub_test_index];
		frame_wait : int = test_data.default_frame_wait;
		if sub_test.override_wait {
			frame_wait = sub_test.frame_wait_override;
		}
		if sub_test.current_frame_wait < frame_wait {
			sub_test.current_frame_wait += 1;
			test_data.test_state = .TEST_CONTINUE;
			return true;
		}
	}
	return false;
}
//TODO REmove other verion to not have duplicates
ContinueTest :: inline (test_data : *TestData) {
	if test_data.sub_test_index < test_data.all_sub_tests.count {
		sub_test := *test_data.all_sub_tests[test_data.sub_test_index];
		//NOTE : run_index starts at 1 if we set it with SubT, so run_count == number of times we want to run
		if sub_test.run_index < sub_test.run_count {
			sub_test.run_index += 1;
			sub_test.current_frame_wait = 0;
		} else {
			test_data.sub_test_index += 1;
		}
		test_data.test_state = .TEST_CONTINUE;
	} 

	if test_data.sub_test_index >= test_data.all_sub_tests.count {
		test_data.test_state = .TEST_FINISHED;
	}
}
EndTest :: inline (test_data : *TestData) {
	test_data.sub_test_index = test_data.all_sub_tests.count;
	//Technically we don't have to set this since it gets set in continue test, 
	//but it is better for resilience/consistency.
	test_data.test_state = .TEST_FINISHED;
}
//TODO Once we remove the proc ContinueTest we can put this back in other ContinueTest
UpdateTestIndex :: inline (sub_test : *SubTestData, test_data : *TestData) {
	if sub_test.run_index < sub_test.run_count {
		sub_test.run_index += 1;
		sub_test.current_frame_wait = 0;
	} else {
		test_data.sub_test_index += 1;
	}
}

ResetTestData :: inline (test_data : *TestData) {
	test_data.frame_count = 0;
	test_data.last_frame_dt = Apollo_Time.{0,0};
	test_data.all_frames_time = Apollo_Time.{0,0};
	test_data.test_timer = Apollo_Time.{0,0};

	test_data.sub_test_index = 0;
	test_data.initialized_test = false;
	//We always keep the first value as empty for test initialization
	array_reset_keeping_memory(*test_data.all_sub_tests);

	test_data.default_frame_wait = 0;
}

/*NOTE : IntegrationTest now can RunFrames inside AND also TEST_CONTINUE to run actual game loops.
TODO Maybe we should split this up into ITest and PTest/BTest if that helps later on.
NOTE : The current way just does not touch the test_state if we want to just run once and then see what happened.
If we do TEST_CONTINUE, then we will come back to the test after running 1 frame. We can adjust how many frames
we run by only triggering the next event after a certain amount determined by frame_count.
*/
//NOTE : Because we can go back into this test, we don't set anything and we allow the test to set
//everything internally so it can loop back in from the game loop as needed.
RunIntegrationTest :: (
	test_name : string,
	//TODO What if just pass TIPData in here instead
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);

	//TODO add an else if here to check if the level is in a file level once that gets implemented
	// test_function_pointer, found_test := table_find(*perm.testing_data.test_levels, test_name);
	//itest_names, itest_function_names and itest_function_names are generated in win_build_thegame.jai from @Itest note
	found_test, test_index := array_find(itest_names, test_name);
	if found_test {
		function_name : string = itest_function_names[test_index];
		if perm.test_data.test_state == .TEST_STARTED {
			//By setting this to TEST_FINISHED, we run the test functon once by default.
			//TODO We could make a separate test type like @BTest and then set TEST_FINISHED
			//in there whenever we are done and then @ITest would only run once... hmmm...
			perm.test_data.test_state = .TEST_FINISHED;
			ResetTestData(*perm.test_data);
			perm.test_data.test_function_name = function_name;

			//TODO I don't think we need to set true here since all tests are different...
			reset(*test_alloc_pool, true);

			//DOC : We set a fresh input here for every test on test_alloc after resetting. This way
			//we can set back to game_input after the test and not worry about the input memory.
			perm.test_data.use_as_test_input = New(GameInput,,test_alloc);
			//We copy this here so that we have the same behavior as in game with default mappings
			perm.test_data.use_as_test_input.game_input_mappings = CopyDefaultInputMappings(,,test_alloc);

			//TODO We could pass in test_alloc here but we have not thought about allocations in thegame
			//so that may mess things up so we don't for now since all memory is likely temp and default
			//and the windows one. Likely want to keep it anyways, so we can continue running after integration.
			//This is worth thinking about once we do allocation in game.
			ResetTestResults(function_name, *CURRENT_TEST_RESULTS);

			//TODO we could set this here with a InitTestData so that we can set settings and other data
			//based on specific values needed for tests so it does not overlap or interfere with in-game usage data
			// perm.all_data = InitAllData();
			// ResetAllRendererData(renderer_data);
		}

    	test_function : TestLevelType = itest_functions[test_index];
    	/*DOCU : I am pasing in test_alloc by default. This avoids having to pass it in everywhere in tests
    	  BUT we need to be careful with test_data like all_sub_tests which needs to use a default/separate allocator
    	  SO we could change this if that becomes an issue OR set the allocator internally for other things, since
    	  other things are the exception in this case because we want all the game data to be test_alloc in the tests all the time.
    	*/
    	test_function(test_name, game_memory, renderer_data, audio_data, perm.test_data.use_as_test_input,,test_alloc);

    	if perm.test_data.test_state == {
    	case .TEST_CONTINUE;
    		//DOC : Setting this here keeps our event input state updating consistent with the platform layer
    		//since we only udpate it from the events
		   UpdateInputStatesFromEvents(perm.test_data.use_as_test_input);
    		//TODO We could pull this out and set it after the frame runs. We can also adjust when this is run
    		//based on a value to adjust the framerate and then wait for a proportional amount of time to the framerate
    		//so then we can slowdown or speedup how fast it goes.
    		perm.test_data.frame_count += 1;
    		//TODO I had a timer here but I think we need timer for running the frame and not the test itself.
    		//I think the test can time itself if it needs to.
    	case .TEST_FINISHED;
    		perm.test_data.use_as_test_input = game_input;
	    	LogCurrentTestResults(CURRENT_TEST_RESULTS);
		}
	} else {
		print("test % not found\n", test_name);
		perm.test_data.test_state = .TEST_ERROR;
	}
}

INTEGRATION_TEST_RESULTS : TestResults = TestResults.{test_name="ALL_INTEGRATION_TESTS"};
RunAllTests :: (
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	game_state := cast(*GameState) game_memory.PermanentStorage;
	perm := *game_state.persist;

	//TODO Could put unit tests after like we had before and then just set this 
	//Would have to add a flag to reset_test_results here which we would have to reset to false 
	//once all tests is finished.
	if !perm.test_data.all_unit_tests_finished {
		perm.test_data.pre_test_runtime_settings = perm.all_data.runtime_settings;
		ResetTestResults(*ALL_TEST_RESULTS);
		ResetTestResults(*INTEGRATION_TEST_RESULTS);

		RunAllUnitTests();
		ALL_TEST_RESULTS.fail_count += UNIT_TEST_RESULTS.fail_count; 
		ALL_TEST_RESULTS.pass_count += UNIT_TEST_RESULTS.pass_count; 

		perm.test_data.all_unit_tests_finished = true;

		//NOTE : This should be TEST_STARTED from before and should not change, but just in case
		//we set it here so data gets reset properly for integration tests.
		//TODO We could reset data here and also reset perm.all_data but we leave that up to RunIntegrationTest for now.
		perm.test_data.test_state = .TEST_STARTED;
		log("\nINTEGRATION TESTS\n");

		//Write empty to this file when we do all tests to make sure we reset it
		write_entire_file(WRITE_TEST_FILE_NAME, "");
	}	

	if AllOrEquals(perm.test_data.test_state, .[.TEST_STARTED, .TEST_CONTINUE]) && 
		perm.test_data.all_itest_index < itest_names.count
	{
		test_name : string = itest_names[perm.test_data.all_itest_index];
		RunIntegrationTest(test_name, game_memory, renderer_data, audio_data, game_input);

		//If we finish a test, then we can continue processing tests until we have one that TEST_CONTINUE out.
		while perm.test_data.test_state == .TEST_FINISHED {
			if CURRENT_TEST_RESULTS.fail_count == 0 {
				INTEGRATION_TEST_RESULTS.pass_count += 1;
			} else {
				INTEGRATION_TEST_RESULTS.fail_count += 1;
			}

			perm.test_data.all_itest_index += 1;
			if perm.test_data.all_itest_index >= itest_names.count {
				break;
			}

			test_name = itest_names[perm.test_data.all_itest_index];
			perm.test_data.test_state = .TEST_STARTED;
			RunIntegrationTest(test_name, game_memory, renderer_data, audio_data, game_input);
		}
	}

	all_i_test_finished : bool = perm.test_data.all_itest_index >= itest_functions.count;
	if all_i_test_finished && perm.test_data.all_unit_tests_finished {
		perm.test_data.all_itest_index = 0;
		perm.test_data.all_unit_tests_finished = false;
		perm.test_data.test_state = .NO_TEST_RUNNING;

		ALL_TEST_RESULTS.fail_count += INTEGRATION_TEST_RESULTS.fail_count;
		ALL_TEST_RESULTS.pass_count += INTEGRATION_TEST_RESULTS.pass_count;
		LogTestResults(INTEGRATION_TEST_RESULTS);
		LogTestResults(UNIT_TEST_RESULTS); //We rewrite this for easy viewing here.
		LogTestResults(ALL_TEST_RESULTS);

		//Because we are not running a particular test here, we reset everything so we can continue
		//TODO Could also reset audio_data and game_input if needed.
		//TODO If we use a Flat_Pool for GameMemory storage and Persist then we can just reset those here.
		reset(*test_alloc_pool, true);
		perm.all_data = InitAllData();
		UpdateRuntimeSettings(perm.test_data.pre_test_runtime_settings, perm, renderer_data);
		ResetAllRendererData(renderer_data);
	}
}

//These are now generated at compile time. Keeping here for now in case we decide to reuse it 
//if the compile-time generation has any issues.
#if 0 {
BuildTestsTable :: () -> Table(string, TestLevelType) {
	/*Tests that can be called directly for testing framework

	REMINDER : Keep different tests and files with different names. For example
	keep code and asm files/levels with the same purpose but with different names.
	Ultimately we may have some levels that are exactly the same so this is a good
	reminder. May want some levels to in code as a refresher of concepts that have
	already been understood in the asm levels.
	*/
	/*TODO This would be better done with some notes at compile-time.
	*/
	code_tests : Table(string, TestLevelType);
	// table_add(*code_tests, "trans2v", Test_Transposition2_Verify);
	// table_add(*code_tests, "trans2s", Test_Transposition2_Solver);
	// table_add(*code_tests, "test_snap", Test_Snapping);
	//TODO This uses old MusicPtSet so probably should not be working anyways
	// table_add(*code_tests, "test_s3", Test_ChordS3VL);

	//TODO These are note working but maybe should be... not sure
	// table_add(*code_tests, "gen", Test_AsmGenerators); //Need to check data here seems like I may have changed it.
	// table_add(*code_tests, "expr", Test_AsmExpression); //This one is working apparently

	table_add(*code_tests, "mus1", Test_MusCall);
	table_add(*code_tests, "mov0", Test_Mov);
	table_add(*code_tests, "movm", Test_MovMusic);
	table_add(*code_tests, "shift", Test_Shift);
	table_add(*code_tests, "arith", Test_Arithmetic);
	table_add(*code_tests, "arithm", Test_ArithmeticMusic);
	table_add(*code_tests, "logic", Test_Logical);
	table_add(*code_tests, "logicm", Test_LogicalMusic);
	table_add(*code_tests, "compare", Test_Compare);
	table_add(*code_tests, "all", RunAllTests);

	return code_tests;
}

/*Data tests that can be called anytime to validate the data output. These are general tests for myself. 

TODO If we wanted in-game tests, at least part of them would have to independent of these tests because
they would need to show output in-game and the current test framework assertions print everything to console. 
It could be an input parameter where to output the assertions but also we may want the assertions to
be different and the output to be graphical and/or textual in-game.
*/
BuildTestDataTable :: () -> Table(string, TestLevelDataType) {
	data_tests : Table(string, TestLevelDataType);
	table_add(*data_tests, "gen", GeneratorsTest);

	return data_tests;
}
/*TODO Could keep this as just having *Persist
and have more robust tests be only allowed in the
testing framework since this is specifically for testing
data that is allowed in-game.

TODO So we can completely separate this out at some point.
For now we leave it like this since we don't know what we
will do in the future and want to reuse the same tests in
the testing framework and also directly in-game from the temrinal.
*/
TestLevelDataType :: #type (
	perm : *Persist,
	renderer_data : *RendererData = null, 
    audio_data : *AudioData = null,
    game_input : *GameInput = null);

TestingData :: struct {
	is_initialized : bool;
	test_levels : Table(string, TestLevelType);
	/*This is independent of the testing framework and should
	be callable by the testing framework but should not be
	able to call the testing framework.

	HOWEVER Tests called in game will have a very different
	structure than these tests so these can be used for
	my convenience for now. If we decide to have in-game
	tests then we can generalize it.
	*/
	test_level_data : Table(string, TestLevelDataType);
	// test_input : GameInput;
}

}

// UpdateAndRenderTest :: inline (game_memory : *GameMemory,
UpdateAndRenderTest :: (game_memory : *GameMemory,
								renderer_data : *RendererData,
                        audio_data : *AudioData,
                        game_input : *GameInput) 
{
	//TODO move into separate filed and call 1 test function
   game_state := cast(*GameState) game_memory.PermanentStorage;
	perm := *game_state.persist;	

	keyboard := *game_input.Controllers[0];

	if !perm.test_data.is_initialized {
		perm.test_data.is_initialized = true;
		assert(perm.text_command_string.total_allocated_bytes > 0);
		perm.test_data.test_name = alloc_string(perm.text_command_string.total_allocated_bytes);
		perm.test_data.test_name.count = 0;
		perm.test_data.test_state = .NO_TEST_RUNNING;
		perm.test_data.all_sub_tests.allocator = context.default_allocator;
		perm.test_data.use_as_test_input = game_input;

		//TODO Could make this a normal pool in case it increases in size
		//Reserved the default 256Mb but we should use much less than that for each test, but just in case.
		//Each page is 4Kb so probably won't use more than a few of those. I think the compiler should be given
		//something similar so this allows larger tests like that to happen. Can increase size later if needed.
		//NOTE : Better to have this external so we can reset it whenever we want like in unit tests.
		init(*test_alloc_pool);
		test_alloc.data = *test_alloc_pool;
		//TODO We set this at declaration since it's constant
		// test_alloc.proc = flat_pool_allocator_proc;

		init(*unit_test_alloc_pool);
		unit_test_alloc.data = *unit_test_alloc_pool;
		//TODO We set this at declaration since it's constant
		// unit_test_alloc.proc = flat_pool_allocator_proc;
	}

	// if keyboard.only_ctrl_alt_down && keyboard.t_button.down_this_frame {
	if IsInputMapPress(.DEV_TEST_MODE, .DOWN_THIS_FRAME, game_input) {
    	perm.text_command_type = TextCommandType.RUN_TEST;
	}

	if TextCommandType.RUN_TEST == perm.text_command_type {
		//We reset here to remove cursor everywhere else for convenience, but we could also be more precise about preventing text input.
		ResetToUnselectedState(perm.all_data);
		update_text, update_input := 
			UpdateFileStringAtCursor(*perm.text_command_string, *perm.text_command_cursor, 
				game_input.frame_input_events, game_input, perm.text_editor_data, single_line = true);

		DrawTextInputBox(perm.text_command_type, perm.text_command_string.text_string, 
			perm.text_command_cursor.cursor_line_char * perm.text_editor_data.code_font_1_char_width_pixel / renderer_data.overlay_render_group.pixels_per_square,
			perm.text_editor_data.char_height, renderer_data.overlay_render_group);

		// if keyboard.return_enter.down_this_frame {
		if IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) {
			/*TODO ITest now can RunFrames inside AND also TEST_CONTINUE to run actual game loops.
			Maybe we should split this up into ITest and PTest/BTest if that helps later on.
			*/
			memcpy(perm.test_data.test_name.data, perm.text_command_string.text_string.data, perm.text_command_string.text_string.count);
			perm.test_data.test_name.count = perm.text_command_string.text_string.count;

			//We reset and start here for all tests on keyboard enter.
			ResetTestData(*perm.test_data);
			perm.test_data.test_state = .TEST_STARTED;

			/*NOTE REMINDER : We could have a separate allocator for unit test and integration tests so we can
			run unit tests without affecting other tests if needed.
			*/
			//NOTE : We leave it up to the test to reset and allocate the data properly since each test and test type
			//does this differently no need to to do it everytime here. We could reset here for good measure though if needed.
			//I Think it makes sense to run tests while playing but we can see how we want to use it eventually.
			// reset(*test_alloc_pool, true);
			// perm.all_data = InitAllData();

    		ResetTextCursor(*perm.text_command_cursor);
    		perm.text_command_string.text_string.count = 0;
    		perm.text_command_type = TextCommandType.NONE;

    		//Reset the controller input so it does not affect any of the integration tests just in case
    		//and does not get registered by an in game frame update either.
    		ResetGameInput(game_input);
		} else {
			//TODO Could make a ClearGameInput function if that helps with this but generally we don't want to clear
			//all the game input just here while typing in the test
			ResetGameInput(game_input);
			for * game_input.my_input_states it.* = .{};
			keyboard.* = ControllerInput.{};
		}
	}
	//TODO Could add a keyboard command here that kills the test if we have issues like alt+x or whatever works.
	//Probably writing into the textbox would still work to but maybe not the best idea.

	//TODO CFROM HERE leanup test a here with comments and above and elsewhere.
	//Then write a test for breakpoints and for watch window with things changing and look how it works.
	//ALSO consider passing an array to RunAllTests like RunManyTests and maybe make a function that runs many or all tests
	if perm.test_data.test_state == {
	case .TEST_CONTINUE; #through;
	case .TEST_STARTED; {
		//DOC : Resetting game input here before our next test input keeps us consistent with the platform layer.
		//NOTE This does not include the input_button_state and application focus resetting in platform layer.
		ResetGameInput(perm.test_data.use_as_test_input);

		split_input : [] string = String.split(perm.test_data.test_name, " ");
		if split_input.count == 1 {
			if perm.test_data.test_name == "all" {
				RunAllTests(game_memory, renderer_data, audio_data, game_input);
			} else if perm.test_data.test_name == "aut" {
				RunAllUnitTests();
				perm.test_data.test_state = .NO_TEST_RUNNING;
			} else {
				//NOTE : Because we can go back into this test, we don't set anything and we allow the test to set
				//everything internally so it can loop back in from the game loop as needed.
				RunIntegrationTest(split_input[0], game_memory, renderer_data, audio_data, game_input);
			}
		} else if split_input.count == 2 {
			test_type : string = split_input[0];
			test_type_name : string = split_input[1];
			if test_type == "u" {
				RunUnitTest(test_type_name);
				perm.test_data.test_state = .NO_TEST_RUNNING;
			} else {
				print("test_type % not found.\n", test_type);
				perm.test_data.test_state = .TEST_ERROR;
			}
		} else {
			print("tests have 1-2 arguments.\n", perm.test_data.test_name);
			perm.test_data.test_state = .TEST_ERROR;
		}
	}
	}

	t0 := current_time_monotonic();

	//TODO could even have multi-part tests where we can test in between test parts
	UpdateAndRenderBase(game_memory, renderer_data, audio_data, perm.test_data.use_as_test_input);

	//TODO We can use this to test the length of tests later if I think something will take long.
	perm.test_data.last_frame_dt = current_time_monotonic() - t0;
	perm.test_data.all_frames_time += perm.test_data.last_frame_dt;

	//TODO Maybe better to adjust frame_count here (or before) and then also have a wait function
	//to wait for some time proportional to the frame time so that we can adjust how fast the tests run.
	//Then we can remove this from IntegrationTest. We could do it there as well though but then that would
	//be set before the frame runs.
	//.frame_count += 1;
}

//No longer use this but keeping here just in case.
//We use it in GeneratorsTest but we can likely remove that test entirely.
SetupTestProcedure :: (name : string) #expand {
	reset(*test_alloc_pool, true);
	ResetTestResults(name, *CURRENT_TEST_RESULTS);

	//Runs at end of calling procedure
	`defer {
		LogTestResults(CURRENT_TEST_RESULTS);
	}
}

SetupEqualsProcedure :: (test_results : *TestResults) #expand {
	`atr := ifx test_results == null then *CURRENT_TEST_RESULTS else test_results;
}

//TODO Could have an array here to add to one set and then remove
ALL_TEST_RESULTS : TestResults = TestResults.{test_name="ALL_TESTS"};
CURRENT_TEST_RESULTS : TestResults = TestResults.{};
TestResults :: struct {
	test_name : string;
	pass_count : int;
	fail_count : int;
	test_logs : [..] string;
}

MakeTestResults :: inline (name : string) -> TestResults {
	tr : TestResults;
	tr.test_name = name;
	//TODO Could pass this in through context.allocator
	tr.test_logs.allocator = test_alloc;
	return tr;
}

//Input placed here in case we want to do out own accumulation
ResetTestResults :: inline (name : string, test_results : *TestResults) {
	test_results.test_name = name;
	ResetTestResults(test_results);
}

ResetTestResults :: inline (test_results : *TestResults) {
	test_results.pass_count = 0;
	test_results.fail_count = 0;
	array_reset_keeping_memory(*test_results.test_logs);
}

//TODO this should store a running total as well of all passed and failed tests
//and then can look in the log for specific failures
LogTestResults :: inline (tr : TestResults) {
	log("\n");
	//TODO Could remove logs here if we never use and have a different type for the cummulative test results.
	for tr.test_logs log_error(it);

	//TODO This could be a good case for verbose logging.
	if tr.fail_count == 0 {
		log("% - ALL PASSED", tr.test_name);
	} else if tr.fail_count > 0 {
		log("% - # PASSED = %, # FAILED = %\n", tr.test_name, tr.pass_count, tr.fail_count);
	}
}

LogCurrentTestResults :: inline (tr : TestResults) {
	for tr.test_logs log_error(it);

	//TODO This could be a good case for verbose logging.
	if tr.fail_count == 0 {
		log("% - ALL PASSED", tr.test_name);
	} else if tr.fail_count > 0 {
		log("% - # ASSERTS PASSED = %, # ASSERTS FAILED = %\n\n", tr.test_name, tr.pass_count, tr.fail_count);
	}
}

GetFunctionName :: inline () -> string {
	return context.stack_trace.info.name;
}

/*TODO Instead of printing right away, we could accumulate all the strings and then output them later based
on some settings so maybe the tests can be less verbose. ALSO we would need to accumulate them somewhere
if we wanted to render them within the program later.

COULD DO THIS WITH A PASS AND FAIL ARRAY AND THEN STORE THE LOGS IN A PASSED IN ALLOCATOR (maybe context.allocator by convention)
and then we would persist the test results into the game and could display it somewhere in-game.
*/
AccumulateTestResults :: (
	test_passed : bool, 
	//TODO Do we really need this now? We could remove this if we have tests in different functions...
	//And just use GLOBAL and ALL_GLOBAL. I'll leave here for now but can consider later.
	test_results : *TestResults, 
	test_name : string = "",
	assert_flags : AssertFlags = .{})
#expand
{
	//TODO This could be a good case for verbose logging.
	if test_passed {
		//TODO log if verbose
		// log("TEST PASSED : % - %, expected = %, actual = %\n",
		// 	context.stack_trace.info.name, test_name, expected, actual);
		//TODO can pass a test_results from the context if needed to change
		//or pass directly in by function
		test_results.pass_count += 1;
	} else {
		test_results.fail_count += 1;
		if !assert_flags.print_error return;

		//Does this fix the heisenbug of tests halting due to printing/logging?
		//Is it the print to console? I left the old storing logs if we want them in game.
		#if 1 {
		//TODO Can we reuse String_Builder and pass it in?
		//TODO Can put this into a functon so we can reuse for other tests
	   builder: String_Builder;
	   builder.allocator = test_alloc;
	   //TODO Could put test_name at the end since that is how we seem to be using it now
	   // print_to_builder(*builder, "\nFAILED %: ", test_name);
	   print("\nFAILED %: ", test_name);
	   trace_stack : [..] *Stack_Trace_Node;
	   trace_stack.allocator = test_alloc; //Should we use context.allocator?
	   trace : *Stack_Trace_Node = context.stack_trace.next;
	   while !String.starts_with(trace.info.name, "Test_") {
	   	array_add(*trace_stack, trace);
	   	trace = trace.next;
	   }
	 	array_add(*trace_stack, trace);
	 	//TODO can reuse the test_logs if needed but printing directly to console
	 	//is more efficient both for speed and space. But need the logs if we want to print in-game.
	 	// for < trace_stack print_to_builder(*builder, "%(line:%)-", it.info.name, it.line_number);
	 	for < trace_stack print("%(line:%)-", it.info.name, it.line_number);
	 	// print_to_builder(*builder, "\nexpected = %, actual = %", `expected, `actual,,test_alloc);
	 	print("expected = %, actual = %\n", `expected, `actual);
		// array_add(*test_results.test_logs, builder_to_string(*builder,, test_alloc));
		} else {
	   //Note : sprint uses context.allocator by default
	   //If we have an issue, then we can just use another String_Builder here
	   error : string = TestLocationString(test_name,
	   //TODO I think this might be causing an issue we didn't have before
	   //PUT BACK String_Builder here instead of sprint. Maybe it's the TestManyInstr though as well...
	   //TODO IT COULD ALSO BE THE EXCESSIVE USE OF spring in TestManyInstr
	   //which could be causing memory overload if there are lots of errors.
	   //So could try increasing the test_alloc size OR printing to console immediately.
	   //ACTUALLY THIS ALSO DOUBLES THE STRING SO LIKELY SHOULD MAKE THAT MORE EFFICIENT
	   	sprint("\nexpected = %, actual = %", `expected, `actual,,test_alloc));
		array_add(*test_results.test_logs, error);
		}
	}
}

//TODO Could pass in a string to add to the end and beggining here if that helps
TestLocationString :: (test_name : string = "", end_string : string = "") -> string {
	//TODO Can we reuse String_Builder and pass it in?
	//TODO Can put this into a functon so we can reuse for other tests
   builder: String_Builder;
   builder.allocator = test_alloc;
   //TODO Could put test_name at the end since that is how we seem to be using it now
   print_to_builder(*builder, "\nFAILED %: ", test_name);
   trace_stack : [..] *Stack_Trace_Node;
   trace_stack.allocator = test_alloc; //Should we use context.allocator?
   trace : *Stack_Trace_Node = context.stack_trace.next;
   while !String.starts_with(trace.info.name, "Test_") {
   	array_add(*trace_stack, trace);
   	trace = trace.next;
   }
 	array_add(*trace_stack, trace);
 	for < trace_stack print_to_builder(*builder, "%(line:%)-", it.info.name, it.line_number);
 	append(*builder, end_string);
 	return builder_to_string(*builder,, test_alloc);
}

//TODO should we do vector_specific ones or a AssertStructEquals
//and do something similar as in the serializer
AssertFloatEquals :: inline (
	expected : float, actual : float,
	test_name : string = "",
	test_results : *TestResults = *CURRENT_TEST_RESULTS,
	af : AssertFlags = .{})
-> bool
{
	is_equal : bool = FloatEqual(expected, actual);
	AccumulateTestResults(is_equal, test_results, test_name, af);
	return is_equal;
}

AssertFloat64Equals :: inline (
	expected : float64, actual : float64,
	test_name : string = "",
	test_results : *TestResults = *CURRENT_TEST_RESULTS,
	af : AssertFlags = .{})
-> bool
{
	is_equal : bool = Float64Equal(expected, actual);
	AccumulateTestResults(is_equal, test_results, test_name, af);
	return is_equal;
}

AssertArrayEquals :: (
	expected : [] $T, actual : [] T,
	test_name : string = "",
	test_results : *TestResults = *CURRENT_TEST_RESULTS,
	af : AssertFlags = .{})
-> bool 
{
	is_equal : bool = false;
	#if T == float || T == float64 {
	is_equal = ArraysFloatEqual(expected, actual);
	} else {
	is_equal = ArraysEqual(expected, actual);
	}
	AccumulateTestResults(is_equal, test_results, test_name, af);
	return is_equal;
}

//TODO Could make a separate AssertEqualsNoPrint and then have an Acummulate that does not print.
//That would be more efficient but also bunch of extra code... won't do for now.
//TODO Should we just put float in here at compile-time for consistency?
AssertEquals :: (
	expected : $T, actual : T,
	test_name : string = "",
	tr : *TestResults = *CURRENT_TEST_RESULTS,
	af : AssertFlags = .{})
-> bool 
{
	//TODO should we not allow structs here. i guess its ok because of == overloading
	// #assert T != float && T != float64 && type_info(T).type != .ARRAY;
	#if T == float {
	return AssertFloatEquals(expected, actual, test_name, tr, af);
	} else #if T == float64 {
	return AssertFloat64Equals(expected, actual, test_name, tr, af);	
	} else #if type_info(T).type == .ARRAY {
	return AssertArrayEquals(expected, actual, test_name, tr, af);
	} else {
	is_equal : bool = expected == actual;
	AccumulateTestResults(is_equal, tr, test_name, af);
	return is_equal;
	}
}

AssertNotEquals :: (
	expected : $T, actual : T,
	test_name : string = "",
	test_results : *TestResults = *CURRENT_TEST_RESULTS,
	af : AssertFlags = .{})
-> bool 
{
	//TODO should we not allow structs here. i guess its ok because of == overloading
	#assert T != float && T != float64 && type_info(T).type != .ARRAY;

	is_equal : bool = expected != actual;
	AccumulateTestResults(is_equal, test_results, test_name, af);
	return is_equal;
}

AssertFlags :: struct {
	print_error : bool = true;
}

NoNull :: (o : *$T) -> T {
	if o == null T.{};
	return o;
}

AssertEqualsWFoo :: (
	expected : $T, actual : T,
	$is_equal : (t1 : T, t2 : T) -> bool,
	test_name : string = "",
	test_results : *TestResults = *CURRENT_TEST_RESULTS)
-> bool 
{
	// #assert T != float && T != float64 && type_info(T).type != .ARRAY;
	equal_check : bool = is_equal(expected,actual);
	AccumulateTestResults(equal_check, test_results, test_name);
	return equal_check;
}

//NOTE THIs function assumes we have an == operator for every struct member
//I don't think I should usually use this but it is convenient for these settings so we can update them as needed.
//Just need to make sure we add an == operator but generally the settings should be simple.
AssertStruct :: ($T : Type, s1 : string, s2 : string) -> string #expand {
	sb : String_Builder;
	struct_type_info := cast(*Type_Info_Struct) type_info(T);
	for ti_member : struct_type_info.members {
		print_to_builder(*sb, 
		"AssertEquals(%.%, %.%, \"%\");\n",
		s1, ti_member.name, s2, ti_member.name, ti_member.name);
	}
	return builder_to_string(*sb);
}
AssertStructEquals :: inline (test : $T, value : T) {
	#insert #run AssertStruct(T, "test", "value");
}

ASM_CREATE_SPACE :: inline (csd : AsmOpSpaceData = .{0,.space_2d,.{}}, name : string = "test") -> string {
	sb : String_Builder;
	for 0..name.count-1 {
		print_to_builder(*sb, "push %, 1;\n", name[it]);
	}
	push_name_chars : string = builder_to_string(*sb);

	return sprint(
#string DONE 
mov ax, scp;
% //push_name_chars

mov bx, scp;
push %; //op_space_id
push %; //op_space_external_type
push 4; //op_space_name.count
push ax; //op_space_name.data_address
muscall %, [bx];
DONE,
push_name_chars,
csd.ret_op_space_id,
cast(int) csd.op_space_type, 
csd.op_space_name.count, 
csd.op_space_name.data_address, 
cast(int) MusCallType.create_space
,,context.allocator);
}
#if 0 {
//TODO Add an integration test for this once we do the unit tests
Test_AsmCreateSpace :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	//TODO Turn these into terminal events
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	op_name_count, op_name_data := PushRAMString("test", *perm.all_data.ram_memory);
	create_space_data := AsmOpSpaceData.{0,0,ArrayData.{op_name_count, op_name_data}};
	create_space_address : int = PushRAMValue(create_space_data, *perm.all_data.ram_memory);

	cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		muscall %, [%]; //create_space
	}
}
DONE, 
cast(int) MusCallType.create_space, create_space_address
,,test_alloc)
,, test_alloc);

	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);

	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_equals := AssertEquals(1, perm.all_data.all_closed_op_spaces.count);
	if count_equals {
		AssertEquals("test", perm.all_data.all_closed_op_spaces[0].op_space_name);
		AssertEquals(OpSpaceExternalType.space_2d, perm.all_data.all_closed_op_spaces[0].op_space_external_type);
		AssertEquals(0, perm.all_data.all_closed_op_spaces[0].id);
	}
 
} @ITest
}

PushAsmOpSpaceData :: inline (space_name : string, ram_mem : *RAMMemory) -> *AsmOpSpaceData {
	space_data := PushStruct(AsmOpSpaceData, ram_mem);
	space_data.ret_op_space_id = 0; 
	space_data.op_space_type = AsmOpSpaceType.space_2d;

	name_data_address : int = ram_mem.stack_p;
	name_string : string;
	name_string.count = space_name.count;
	name_string.data = PushMulti(u8, space_name.count, ram_mem);
	memcpy(name_string.data, space_name.data, name_string.count);
	space_data.op_space_name.count = space_name.count;		
	space_data.op_space_name.data_address = name_data_address;
	return space_data;
}

Test_HigherDim :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	#if 0 {
	three_rows : [3] CreateRowData;
	for * three_rows it.* = .{row_section_data=.[.{x_length=12}]};
	SetupMusicAndRows(perm.all_data, three_rows);
	}

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_3d;
	cosd.op_space_name = "space";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);


	create_cs3 : CreateChordS3Data = DEFAULT_CS4_DATA;
	create_cs3.higher_dim = 5;
	create_cs3.chord_s3_world_pos = Vector2F.{0,0};
	create_cs3.op_space_id = op_space.id;
	//TODO Need to recompute this when we change the size of 
	// viewport_dim := Vector2F.{49,28}; //ORIGINAL SIZE
	// viewport_dim := Vector2F.{25,25};
	// viewport_dim := OP_SPACE_DEFAULT_SIZE;
	create_cs3.chord_s3_dim = OP_SPACE_DEFAULT_SIZE;
	new_cs_filters : [..] CSFilter;
	new_cs_filters.allocator = test_alloc;
	array_add(*new_cs_filters, CSFilter.{0,0,.[],.ALL});
	// array_add(*new_cs_filters, CSFilter.{0,0,.[],.CHROMATIC});
	// array_add(*new_cs_filters, CSFilter.{3,0,.[],.SUM});
	// array_add(*new_cs_filters, CSFilter.{0,0,.[],.NO_DUPLICATE_PITCHES});
	// array_add(*new_cs_filters, CSFilter.{0,0,.[],.DIATONIC});
	create_cs3.new_cs_filters = new_cs_filters;
	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "et24";
	// ts_name := "et48";
	// ts_name := "et53";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");
	//TODO We could make a function that gets and checks the tuning_system for convenience and consistency.
	create_cs3.tuning_system_id = tuning_system.id;
	lp_count : int = tuning_system.music_pt_count; //linear_point_count
	create_cs3.lp_count = lp_count;
	//This is set by default now.
	// create_cs3.mouse_rotate = DEFAULT_CHORD_S3_ROTATION;
	// create_cs3.cam_trans = DEFAULT_CAM_TRANS;
	//TODO This is convenient 3d translation for chromatic.
	//We could turn it into a function and reuse it if needed.
	// create_cs3.s3_cam_start_type = S3CamStartType.MIN_ZY;
	// create_cs3.s3_cam_start_type = S3CamStartType.POINT_FOCUS;
	// create_cs3.cam_focus_fun_region_pos = 
	// 	OrderedPitchSetToFundamentalRegion(float64.[1,8,17], cast(float64) lp_count);
	create_cs3.s3_cam_start_type = S3CamStartType.MIN_ZY;
	// CHROMATIC_TRANSLATION := Vector3F.{0,0,2.0*(create_cs3.lp_count-12)};
	// AddToTranslation(*create_cs3.cam_trans, CHROMATIC_TRANSLATION);
	//These are set to default but leaving here just in case.
	// create_cs3.depth = renderer_data.base_render_group.focal_squares;
	// create_cs3.depth = 24.0;
	// create_cs3.n = 1.0;
	// create_cs3.f = 240.0;

	op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
		op_space.id, "op_space_id");
	assert(found_op_3D);

	CreateSpace3D(op_space.world_size, create_cs3, op_3D);

	//TODO Use this in asm for new high dimension chord spaces
	start_time := seconds_since_init();
	#if 0 {
	//202 seconds - 7 dim with sum filter
	//7.5 seconds - 6 dim with diatonic filter
	ChordSpacePoints3DWithFilter(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count,
		new_cs_filters, .INTERSECTION, *op_3D.all_op_space_points_3D);
	} else {
	//This take 7.5 seconds - 6 dim with filter
	chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, *perm.all_data.all_chord_space_points);
	FilterCS3D(chord_space_points, 
		*op_3D.all_op_space_points_3D, new_cs_filters, .INTERSECTION);
	}
	print("time_taken = % seconds\n", seconds_since_init() - start_time);
	op_3D.op_space_3D.cam_trans = Space3DStartCamTrans(create_cs3.s3_cam_start_type, create_cs3.cam_focus_fun_region_pos, create_cs3.cam_trans, op_3D);

} @ITest

Test_AsmChordS3 :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	three_rows : [3] CreateRowData;
	for * three_rows it.* = .{row_section_data=.[.{x_length=12}]};
	SetupMusicAndRows(perm.all_data, three_rows);

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "et24";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	create_op : CreateOpSpaceData;
	create_op.op_space_external_type = OpSpaceExternalType.space_3d;
	create_op.op_space_name = "space";
	op_space : OperationSpace = CreateClosedOpSpace(create_op,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;
	//Reset stack so we can put on new data for new calls
	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;
	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	acs3_data : *AsmSpace3Data = PushStruct(AsmSpace3Data, *perm.all_data.ram_memory);
	acs3_data.op_space_id = op_space.id;
	acs3_data.higher_dim = 3;
	acs3_data.tuning_system_id = tuning_system.id;
	acs3_data.s3_cam_start_type = S3CamStartType.USER_SET;

	//TODO Can check value_set with this and update the filter below
	// value_set_count, value_set_address :=
	// 	PushRAMArray(float64.[0,4,7], *perm.all_data.ram_memory);
	asm_cs_filters := AsmCSFilter.[
		AsmCSFilter.{0,0,.{},.CHROMATIC},
		// AsmCSFilter.{3,0,.{},.SUM}
		// AsmCSFilter.{0,0,.{value_set_count,value_set_address},.IN_VALUE_SET},
		// AsmCSFilter.{0,0,.{},.NO_DUPLICATE_PITCHES},
	];
	acs3_data.asm_cs_filters.count, acs3_data.asm_cs_filters.data_address = 
		PushRAMArray(asm_cs_filters, *perm.all_data.ram_memory);

	vl_input_address : int = perm.all_data.ram_memory.stack_p;
	// vl_input := float64.[0,8,16];
	vl_input := float64.[0,4,7];
	PushRAMValue(vl_input, *perm.all_data.ram_memory);

	vl_sizes : [1][3] float64 = .[
		float64.[0,-0.5,+1],
		// float64.[2,0,0],
		// float64.[0,1,0],
		// float64.[-0.1,1.3,2.4]
	];
	vl_data_address : int = perm.all_data.ram_memory.stack_p;
	for vl_sizes {
		PushRAMValue(it, *perm.all_data.ram_memory);
	}

	map_data_address : int = perm.all_data.ram_memory.stack_p;
	map_cs3 : *MapChordS3Data = PushStruct(MapChordS3Data, *perm.all_data.ram_memory);
	map_cs3.op_space_id = op_space.id;
	map_cs3.vl_index_ref = 0;
	// map_cs3.old_vl_input_data = vl_input_address;
	map_cs3.vl_start_chord.data_address = vl_input_address;
	map_cs3.vl_start_chord.count = acs3_data.higher_dim;
	map_cs3.vl_deltas.data_address = vl_data_address;
	map_cs3.vl_deltas.count = vl_sizes.count * vl_sizes[0].count;
	// map_cs3.vl_data = vl_data_address;
	// map_cs3.vl_count = vl_sizes.count;

	array_reset_keeping_memory(*perm.all_data.all_music_instructions);
	cd_new : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_cs3 [%];
		map_cs3 [%];
	}
}
DONE, 
dspace_id_address, map_data_address,
// map_chord_s3_dspace_id_address, dspace_id_address,
// cast(int) MusCallType.map_cs3, 
// mem_range_dspace_id_address, dspace_id_address,
// cast(int) MusCallType.map_memory, mem_range_address
,,test_alloc)
,, test_alloc);
	ArrayAddAll(cd_new.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);	

	op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
		acs3_data.op_space_id, "op_space_id");
	assert(found_op_3D);
	chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, *perm.all_data.all_chord_space_points);
	count_equals := AssertEquals(12, chord_space_points.tuning_system_count);
	count_equals = AssertEquals(3, chord_space_points.chord_dim);
	count_equals = AssertEquals(364, chord_space_points.chord_sp_3D.count);
	count_equals = AssertEquals(42+11, op_3D.all_op_space_points_3D.count);
	count_equals = AssertEquals(2, op_3D.all_op_text_3D.count);

} @ITest

//TODO FROM HERE do a 4d and 5d test for good measure
//and then do resizable 3d 
//then add code directly for 3d space
Test_CustomS3 :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "et24";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	create_op : CreateOpSpaceData;
	create_op.op_space_external_type = OpSpaceExternalType.space_3d;
	create_op.op_space_name = "space";
	op_space : OperationSpace = CreateClosedOpSpace(create_op,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	//Reset stack so we can put on new data for new calls
	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;
	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	acs3_data : *AsmSpace3Data = PushStruct(AsmSpace3Data, *perm.all_data.ram_memory);
	acs3_data.op_space_id = op_space.id;
	acs3_data.higher_dim = 3;
	acs3_data.tuning_system_id = tuning_system.id;
	acs3_data.s3_cam_start_type = S3CamStartType.USER_SET;
	// acs3_data.asm_cs_filters = .[
	// 	CSFilter.{0,0,.[],.CHROMATIC}
	// 	// CSFilter.{3,0,.[],.SUM}
	// ];
	asm_cs_filters := AsmCSFilter.[
		AsmCSFilter.{0,0,.{},.CHROMATIC}
		// AsmCSFilter.{3,0,.{},.SUM}
	];
	acs3_data.asm_cs_filters.count, acs3_data.asm_cs_filters.data_address = 
		PushRAMArray(asm_cs_filters, *perm.all_data.ram_memory);

	//COMPARE tests stopped working for some reason...
	//TODO FROM HERE add a geometry here and add tests
	//then do resize 3d space before adding 3d code and test code
	//need to pass in op space size for resize so when we recreate it keeps new size
	//Can update chord_s2 as well for filtering maybe create
	//a 3d and 2d in the same test to make sure its good
	//maybe we add spiral then or can add it later as well.

	//Need to start at 2 since 0 and 1 are reserved. We could set those somewhere if needed
	group_id : int = 2;

	//NOTE : If we don't add the geometry, then the points will use
	//the default tuning system declared above
	geom_3d_address : int = perm.all_data.ram_memory.stack_p;
	geom_3d : *AsmGeom3D = PushStruct(AsmGeom3D, *perm.all_data.ram_memory);
	geom_3d.* = .{};
	geom_3d.op_space_id = op_space.id;
	geom_3d.group_id = group_id;
	tuning_system = ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, "et24", "short_name");
	//24 tone eq for testing
	geom_3d.tuning_system_id = tuning_system.id;
	geom_3d.osc_wave_type = OscWaveType.SAW;


	s_count, s_address := PushString("C#", *perm.all_data.ram_memory);

	shape_3d_address : int = perm.all_data.ram_memory.stack_p;
	shape_3d : *AsmShape3D = PushStruct(AsmShape3D, *perm.all_data.ram_memory);
	shape_3d.* = .{};
	shape_3d.op_space_id = op_space.id;
	shape_3d.group_id = group_id;
	shape_3d.rel_pos = Vector3F64.{0,20,30};
	// fun_region : [] float64;
	shape_3d.shape_text = AsmString.{s_count, s_address};
	// shape_3d.do_not_remove_with_filter = ToAsmBool(true);
	// draw_wire_mesh : AsmBool;
	// shape_3d.not_selectable = ToAsmBool(true);
	// shape_3d.color = Vector4F64.{-1,-1,-1,-1};
	shape_3d.color = MakeV4F64(LBLUE_V);
	shape_3d.scale_value = 1.0;
	pitch_set := float64.[0,4,7];
	shape_3d.pitch_set.count, shape_3d.pitch_set.data_address = 
		PushRAMArray(pitch_set, *perm.all_data.ram_memory);


	text_string := "TEST TEXT";
	text_count, text_address := PushString(text_string, *perm.all_data.ram_memory);
	text_ram_address : int = perm.all_data.ram_memory.stack_p;
	text_3d : *AsmText3D = PushStruct(AsmText3D, *perm.all_data.ram_memory);
	text_3d.op_space_id = op_space.id;
	text_3d.group_id = group_id;
	text_3d.op_pos = Vector3F64.{0,22,30};
	text_3d.text = AsmString.{text_count, text_address};


	array_reset_keeping_memory(*perm.all_data.all_music_instructions);
	cd_new : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_cs3 [%];
		create_custom_3D [%];
		create_shape_3D [%];
		create_text_3D [%];
	}
}
DONE, 
dspace_id_address, 
geom_3d_address, 
shape_3d_address,
text_ram_address,
,,test_alloc)
,, test_alloc);
	ArrayAddAll(cd_new.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);	

	op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
		acs3_data.op_space_id, "op_space_id");
	assert(found_op_3D);
	chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, *perm.all_data.all_chord_space_points);
	// count_equals := AssertEquals(0, perm.all_data.all_chord_space_points.count);
	count_equals := AssertEquals(3, chord_space_points.chord_dim);
	count_equals = AssertEquals(364, chord_space_points.chord_sp_3D.count);
	count_equals = AssertEquals(41, op_3D.all_op_space_points_3D.count);
	if count_equals {
		AssertArrayEquals(pitch_set, op_3D.all_op_space_points_3D[40].pitch_set);
		AssertEquals(shape_3d.group_id, op_3D.all_op_space_points_3D[40].group_id);
		AssertEquals(MakeV3FFrom64(shape_3d.rel_pos), op_3D.all_op_space_points_3D[40].rel_pos);
	}

	count_equals = AssertEquals(1, op_3D.all_custom_geom_3D.count);
	if count_equals {
		AssertEquals(geom_3d.group_id, op_3D.all_custom_geom_3D[0].group_id);
		AssertEquals(geom_3d.tuning_system_id, op_3D.all_custom_geom_3D[0].tuning_system_id);
		AssertEquals(geom_3d.osc_wave_type, op_3D.all_custom_geom_3D[0].osc_wave_type);
	}

	count_equals = AssertEquals(1, op_3D.all_op_text_3D.count);
	if count_equals {
		AssertEquals(text_3d.group_id, op_3D.all_op_text_3D[0].group_id);
		AssertEquals(text_string, op_3D.all_op_text_3D[0].text);
		AssertEquals(MakeV3FFrom64(text_3d.op_pos), op_3D.all_op_text_3D[0].op_pos);
	}

} @ITest

Test_ClearOp :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "et24";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	create_op : CreateOpSpaceData;
	create_op.op_space_external_type = OpSpaceExternalType.space_3d;
	create_op.op_space_name = "space";
	op_space : OperationSpace = CreateClosedOpSpace(create_op,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	//Reset stack so we can put on new data for new calls
	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;
	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	acs3_data : *AsmSpace3Data = PushStruct(AsmSpace3Data, *perm.all_data.ram_memory);
	acs3_data.op_space_id = op_space.id;
	acs3_data.higher_dim = 3;
	acs3_data.tuning_system_id = tuning_system.id;
	acs3_data.s3_cam_start_type = S3CamStartType.USER_SET;
	// acs3_data.asm_cs_filters = .[
	// 	CSFilter.{0,0,.[],.CHROMATIC}
	// 	// CSFilter.{3,0,.[],.SUM}
	// ];
	asm_cs_filters := AsmCSFilter.[
		AsmCSFilter.{0,0,.{},.CHROMATIC}
		// CSFilter.{3,0,.{},.SUM}
	];
	acs3_data.asm_cs_filters.count, acs3_data.asm_cs_filters.data_address = 
		PushRAMArray(asm_cs_filters, *perm.all_data.ram_memory);


	clear_data_address : int = perm.all_data.ram_memory.stack_p;
	clear_data : *AsmClearOpData = PushStruct(AsmClearOpData, *perm.all_data.ram_memory);
	clear_data.op_space_id = op_space.id;
	//TODO CAn test this later if needed
	// clear_data.clear_not_filter_3D = ToAsmBool(true); 

	array_reset_keeping_memory(*perm.all_data.all_music_instructions);
	cd_new : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_cs3 [%];
		clear_op_space [%];
	}
}
DONE, 
dspace_id_address, clear_data_address,
,,test_alloc)
,, test_alloc);
	ArrayAddAll(cd_new.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);	

	op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
		acs3_data.op_space_id, "op_space_id");
	assert(found_op_3D);
	chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, *perm.all_data.all_chord_space_points);
	count_equals := AssertEquals(12, chord_space_points.tuning_system_count);
	count_equals = AssertEquals(3, chord_space_points.chord_dim);
	count_equals = AssertEquals(364, chord_space_points.chord_sp_3D.count);
	count_equals = AssertEquals(0, op_3D.all_op_space_points_3D.count);
	count_equals = AssertEquals(0, op_3D.all_op_text_3D.count);

} @ITest

Test_AsmChordS4 :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	three_rows : [3] CreateRowData;
	for * three_rows it.* = .{row_section_data=.[.{x_length=12}]};
	SetupMusicAndRows(perm.all_data, three_rows);

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "et24";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	create_op : CreateOpSpaceData;
	create_op.op_space_external_type = OpSpaceExternalType.space_3d;
	create_op.op_space_name = "space";
	op_space : OperationSpace = CreateClosedOpSpace(create_op,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;
	//Reset stack so we can put on new data for new calls
	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;
	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	acs3_data : *AsmSpace3Data = PushStruct(AsmSpace3Data, *perm.all_data.ram_memory);
	acs3_data.op_space_id = op_space.id;
	acs3_data.higher_dim = 4;
	acs3_data.tuning_system_id = tuning_system.id;
	acs3_data.s3_cam_start_type = S3CamStartType.MIN_ZY;
	asm_cs_filters := AsmCSFilter.[
		AsmCSFilter.{0,0,.{},.ALL}
		// AsmCSFilter.{3,0,.{},.SUM}
	];
	acs3_data.asm_cs_filters.count, acs3_data.asm_cs_filters.data_address = 
		PushRAMArray(asm_cs_filters, *perm.all_data.ram_memory);


	vl_input_address : int = perm.all_data.ram_memory.stack_p;
	vl_input := float64.[1,4,8,11];
	// vl_input := float64.[0,3,7];
	PushRAMValue(vl_input, *perm.all_data.ram_memory);

	vl_sizes : [3][4] float64 = .[
		float64.[1,-1,-1,1],
		float64.[0,2,2,0],
		float64.[0,+1,0,-0.5],
	];
	vl_data_address : int = perm.all_data.ram_memory.stack_p;
	for vl_sizes {
		PushRAMValue(it, *perm.all_data.ram_memory);
	}

	map_data_address : int = perm.all_data.ram_memory.stack_p;
	map_cs3 : *MapChordS3Data = PushStruct(MapChordS3Data, *perm.all_data.ram_memory);
	map_cs3.op_space_id = op_space.id;
	map_cs3.vl_index_ref = 0;
	// map_cs3.old_vl_input_data = vl_input_address;
	map_cs3.vl_start_chord.data_address = vl_input_address;
	map_cs3.vl_start_chord.count = acs3_data.higher_dim;
	map_cs3.vl_deltas.data_address = vl_data_address;
	map_cs3.vl_deltas.count = vl_sizes.count * vl_sizes[0].count;
	// map_cs3.vl_data = vl_data_address;
	// map_cs3.vl_count = vl_sizes.count;

	array_reset_keeping_memory(*perm.all_data.all_music_instructions);
	cd_new : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_cs3 [%];
		map_cs3 [%];
	}
}
DONE, 
dspace_id_address, map_data_address,
// map_chord_s3_dspace_id_address, dspace_id_address,
// cast(int) MusCallType.map_cs3, 
// mem_range_dspace_id_address, dspace_id_address,
// cast(int) MusCallType.map_memory, mem_range_address
,,test_alloc)
,, test_alloc);
	ArrayAddAll(cd_new.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);	

	op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
		acs3_data.op_space_id, "op_space_id");
	assert(found_op_3D);
	chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, *perm.all_data.all_chord_space_points);
	count_equals := AssertEquals(12, chord_space_points.tuning_system_count);
	count_equals = AssertEquals(4, chord_space_points.chord_dim);
	count_equals = AssertEquals(1365, chord_space_points.chord_sp_3D.count);
	count_equals = AssertEquals(1412, op_3D.all_op_space_points_3D.count);
	count_equals = AssertEquals(4, op_3D.all_op_text_3D.count);

} @ITest
Test_AsmChordS5 :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "et24";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	create_op : CreateOpSpaceData;
	create_op.op_space_external_type = OpSpaceExternalType.space_3d;
	create_op.op_space_name = "space";
	op_space : OperationSpace = CreateClosedOpSpace(create_op,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;
	//Reset stack so we can put on new data for new calls
	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;
	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	acs3_data : *AsmSpace3Data = PushStruct(AsmSpace3Data, *perm.all_data.ram_memory);
	acs3_data.op_space_id = op_space.id;
	acs3_data.higher_dim = 5;
	acs3_data.tuning_system_id = tuning_system.id;
	acs3_data.s3_cam_start_type = S3CamStartType.MIN_ZY;
	// acs3_data.asm_cs_filters = .[
	// 	// CSFilter.{0,0,.[],.CHROMATIC}
	// 	CSFilter.{4,0,.[],.SUM}
	// ];
	asm_cs_filters := AsmCSFilter.[
		// AsmCSFilter.{0,0,.{},.ALL}
		AsmCSFilter.{4,0,.{},.SUM}
	];
	acs3_data.asm_cs_filters.count, acs3_data.asm_cs_filters.data_address = 
		PushRAMArray(asm_cs_filters, *perm.all_data.ram_memory);

	vl_input_address : int = perm.all_data.ram_memory.stack_p;
	vl_input := float64.[0,2,4,7,11];
	// vl_input := float64.[0,3,7];
	PushRAMValue(vl_input, *perm.all_data.ram_memory);

	vl_sizes : [3][5] float64 = .[
		float64.[1,-1,-1,1,0],
		float64.[0,2,2,0,0],
		float64.[0,+1,0,-0.5,0],
	];
	vl_data_address : int = perm.all_data.ram_memory.stack_p;
	for vl_sizes {
		PushRAMValue(it, *perm.all_data.ram_memory);
	}

	map_data_address : int = perm.all_data.ram_memory.stack_p;
	map_cs3 : *MapChordS3Data = PushStruct(MapChordS3Data, *perm.all_data.ram_memory);
	map_cs3.op_space_id = op_space.id;
	map_cs3.vl_index_ref = 0;
	// map_cs3.old_vl_input_data = vl_input_address;
	map_cs3.vl_start_chord.data_address = vl_input_address;
	map_cs3.vl_start_chord.count = acs3_data.higher_dim;
	map_cs3.vl_deltas.data_address = vl_data_address;
	map_cs3.vl_deltas.count = vl_sizes.count * vl_sizes[0].count;
	// map_cs3.vl_data = vl_data_address;
	// map_cs3.vl_count = vl_sizes.count;

	array_reset_keeping_memory(*perm.all_data.all_music_instructions);
	cd_new : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_cs3 [%];
		map_cs3 [%];
	}
}
DONE, 
dspace_id_address, map_data_address,
// map_chord_s3_dspace_id_address, dspace_id_address,
// cast(int) MusCallType.map_cs3, 
// mem_range_dspace_id_address, dspace_id_address,
// cast(int) MusCallType.map_memory, mem_range_address
,,test_alloc)
,, test_alloc);
	ArrayAddAll(cd_new.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);	

	op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
		acs3_data.op_space_id, "op_space_id");
	assert(found_op_3D);
	chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, *perm.all_data.all_chord_space_points);
	count_equals := AssertEquals(12, chord_space_points.tuning_system_count);
	count_equals = AssertEquals(5, chord_space_points.chord_dim);
	count_equals = AssertEquals(4368, chord_space_points.chord_sp_3D.count);
	count_equals = AssertEquals(411, op_3D.all_op_space_points_3D.count);
	count_equals = AssertEquals(4, op_3D.all_op_text_3D.count);

} @ITest

Test_CreateChordS2 :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput)
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	SetupMusicAndRows(perm.all_data, TWO_ROWS);

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	s2_op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
	op_spec_data : *OpSpaceSpecData;
	if count_equal {
		op_spec_data = *perm.all_data.all_op_space_spec_data[0];
	}

	create_cs2 : CreateChordS2Data;
	create_cs2.world_pos = Vector2F.{5,1};
	//TODO Can write tests to make sure this is working with the base case and rotation case for example
	// create_cs2.transform = Matrix2F_IDENTITY;
	create_cs2.transform = ROTATE_NEG90 * ROTATE_NEG45 * REFLECT_90;
	create_cs2.scale_world_unit = 2.0;
	//TODO Should pass this in could use tuning_system for now but best to just be count
	//Pass this in once we generate the points generally and then filter then use int instead of tuning system count
	//TODO Should write tests to make sure filtering is working
	cs_filters : [..] CSFilter;
	cs_filters.allocator = test_alloc;
	array_add(*cs_filters, CSFilter.{0,0,.[],.ALL});
	create_cs2.new_cs_filters = cs_filters;
	// array_add(*cs_filters, CSFilter.{0,0,.[],.DIATONIC});
	// array_add(*cs_filters, CSFilter.{0,0,.[],.CHROMATIC});
	// array_add(*cs_filters, CSFilter.{0,0,.[],.LOCAL_VL_DISTANCE_TO_CHORD});
	// array_add(*cs_filters, CSFilter.{0,4,.[],.SUM});

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "et24";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	lp_count : int = tuning_system.music_pt_count;
	create_cs2.lp_count = lp_count;
	create_cs2.tuning_system_id = tuning_system.id;
	create_cs2.is_sound_float = false;
	create_cs2.vl_order_text = true;
	create_cs2.vl_order_color = true;
	chord_s2 : *ChordSpace2 = CreateChordSpace2(create_cs2, op_spec_data);

	//TODO Should write tests to makes sure point generation is working eventually
	cs2_points : *ChordS2Points2D = GetOrCreateCS2Points(create_cs2.lp_count, *perm.all_data.all_cs2_points_2D);
	FilterCS2D(chord_s2.*, cs2_points.*, *op_spec_data.ass, chord_s2.cs_filters, chord_s2.cs_filter_aggregate,,op_spec_data.spec_2D_alloc);

	AddChordS2ToOpSpace(s2_op_space.id, chord_s2,
		*op_spec_data.all_op_collision_entities);


	vl_end_points, vl_points_no_dim := ProcessVoiceLeadingEventsNDim(chord_s2.dspace_id,
		float64.[0,2], 
		VLEvent.[.{.[0,2]}], 
		chord_s2.music_pt_count,
		//TODO I am not sure we need to pass this in anymore...
		chord_s2.next_group_order,,temp);
	vl_index_0 : int = chord_s2.next_group_order;
	CreateVoiceLeadingShapes2D(s2_op_space.id, chord_s2,
		vl_end_points, vl_points_no_dim, *op_spec_data.ass);

	vl_end_points_2, vl_points_2 := ProcessVoiceLeadingEventsNDim(chord_s2.dspace_id,
		float64.[4,4], 
		VLEvent.[.{.[-1,1]},
		.{.[-0.8,0.3]}], 
		// .{.[0.8,7.3]}], 
		chord_s2.music_pt_count,
		//TODO I am not sure we need to pass this in anymore...
		chord_s2.next_group_order,,test_alloc);
	vl_index_1 : int = chord_s2.next_group_order;
	CreateVoiceLeadingShapes2D(s2_op_space.id, chord_s2,
		vl_end_points_2, vl_points_2,
		*op_spec_data.ass);



	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);


	//TODO Could also check that the values are correct based on color and size...
	//This is interesting since the tests are showing me how the points will be accessed.
	//Will leave for now since its better to just test FunRegionPosToWorldPosMatrix and if that
	//works then this should be fine, since we have it in all_vl_line_points_2D then that tests its anyways.
	// AssertEquals(3, perm.all_data.all_space_triangles.count);
	if op_spec_data.ass.all_space_rects.count > 0 {
		vl_0_rects := ArrayFindAllVarName(op_spec_data.ass.all_space_rects, 
			vl_index_0, "dspace_shape_group",, test_alloc);
		AssertEquals(108, vl_0_rects.count);

		vl_1_rects := ArrayFindAllVarName(op_spec_data.ass.all_space_rects, 
			vl_index_1, "dspace_shape_group",, test_alloc);
		AssertEquals(23, vl_1_rects.count);

		space_pt_rects := ArrayFindAllVarName(op_spec_data.ass.all_space_rects, 
			chord_s2.space_pt_render_order, "render_order",, test_alloc);
		AssertEquals(85, space_pt_rects.count);

		dspace_rects := ArrayFindAllVarName(op_spec_data.ass.all_space_rects, 
			chord_s2.dspace_id, "dspace_id",, test_alloc);
		AssertEquals(131, dspace_rects.count);
	}


	//TODO Can make a simple test with 2D and 3D spaces in separate op_space to make sure its working
	#if 0 {
	s3_cosd : CreateOpSpaceData;
	s3_cosd.op_space_external_type = OpSpaceExternalType.chord_s3;
	s3_cosd.op_space_name = "test_3d";
	s3_op_space : OperationSpace = CreateClosedOpSpace(perm.all_data, s3_cosd);

	//This is separated out so we can reuse but may note be necessary
	//with new methods of coding now.
	create_cs3 : CreateChordS3Data = DEFAULT_CS3_DATA;
	//TODO Need to recompute this when we change the size of 
	// viewport_dim := Vector2F.{49,28}; //ORIGINAL SIZE
	// viewport_dim := Vector2F.{25,25};
	cs_filters_3d : [..] ChordSpaceFilter;
	array_add(*cs_filters_3d, ChordSpaceFilter.{0,0,.CHROMATIC});
	create_cs3.cs_filters = cs_filters_3d;
	// array_add(*cs_filters_3d, ChordSpaceFilter.{0,3,.SUM});
	chord_s3 : *ChordSpace3 = CreateChordSpace3(create_cs3, audio_data, 
		*perm.all_data.visible_space_points_3D, 
		*perm.all_data.all_space_points_3D,
		*perm.all_data.all_chord_spaces_3,
		*perm.all_data.all_chord_space_points);
	}

} @ITest

Test_AsmChordS2 :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);
	CreateManyMusicPtsInMemory(float64.[0,4], 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	base_chord := float64.[0,4,7];

	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;

	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	asm_cs2 : *AsmChordS2Data = PushStruct(AsmChordS2Data, *perm.all_data.ram_memory);
	asm_cs2.* = .{};
	asm_cs2.world_pos = Vector2F64.{5,1};
	asm_cs2.scale_world_unit = 2.0;
   asm_cs2.point_dim = Vector2F64.{0.7,0.7};
   //TODO Should put this as the default somewhere
	// asm_cs2.transform = MakeMatrix2F64(ROTATE_NEG90 * ROTATE_NEG45 * REFLECT_90);
   asm_cs2.lp_count = 12;
	asm_cs2.tuning_system_id = tuning_system.id;
	asm_cs2.is_sound_float = ToAsmBool(false);
	asm_cs2.vl_order_text = ToAsmBool(false);
	asm_cs2.vl_order_color = ToAsmBool(true);
	asm_cs2.op_space_id = op_space.id;

	//TODO Can check value_set with this and update the filter below
	// value_set_count, value_set_address :=
	// 	PushRAMArray(float64.[0,5], *perm.all_data.ram_memory);
	asm_cs_filters := AsmCSFilter.[
		AsmCSFilter.{0,0,.{},.ALL},
		// AsmCSFilter.{0,0,.{},.CHROMATIC},
		// AsmCSFilter.{0,0,.{},.DIATONIC},
		// AsmCSFilter.{3,0,.{},.SUM}
		// AsmCSFilter.{0,0,.{value_set_count,value_set_address},.IN_VALUE_SET},
		// AsmCSFilter.{0,0,.{},.NO_DUPLICATE_PITCHES},
	];
	asm_cs2.asm_cs_filters.count, asm_cs2.asm_cs_filters.data_address = 
		PushRAMArray(asm_cs_filters, *perm.all_data.ram_memory);

	vl_input_address : int = perm.all_data.ram_memory.stack_p;
	vl_input := float64.[0,5];
	// vl_input := float64.[0,3,7];
	PushRAMValue(vl_input, *perm.all_data.ram_memory);

	vl_sizes : [2][2] float64 = .[
		float64.[1,1],
		float64.[-0.9,1.3]
	];
	vl_data_address : int = perm.all_data.ram_memory.stack_p;
	for vl_sizes {
		PushRAMValue(it, *perm.all_data.ram_memory);
	}

	ti_member, dspace_id_offset_in_bytes := 
		get_field(type_info(MapChordS2Data), "dspace_id");
	map_chord_s2_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	map_data_address : int = perm.all_data.ram_memory.stack_p;
	map_cs2 : *MapChordS2Data = PushStruct(MapChordS2Data, *perm.all_data.ram_memory);
	map_cs2.op_space_id = op_space.id;
	map_cs2.vl_start_chord.data_address = vl_input_address;
	map_cs2.vl_start_chord.count = vl_input.count;
	map_cs2.vl_deltas.data_address = vl_data_address;
	map_cs2.vl_deltas.count = vl_sizes.count * vl_sizes[0].count;

	//TODO I think we can remove this unless we want to test adding MemoryRange later
	#if 0 {
	//NOTE : I prefer this way over the generated asm since we don't have to update tests every time
	//we change this data and the compiler helps. Only if we change the name of dspace_id basically.
	ti_member, dspace_id_offset_in_bytes := 
		get_field(type_info(MapSpiralData), "dspace_id");
	map_spiral_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	map_spiral_data := MapSpiralData.{
		op_space_id=op_space.id,
		dspace_shape_group=0,
		chord_data=asm_spiral.base_chord_data,
		chord_count=2,
		draw_vl_lines=cast(int) true
	};
	map_spiral_address : int = PushRAMValue(map_spiral_data, *perm.all_data.ram_memory);

	ti_member, dspace_id_offset_in_bytes = 
		get_field(type_info(MemoryRangeToDSpace), "dspace_id");
	mem_range_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	mem_range := MemoryRangeToDSpace.{
		x_start=0,
		x_end=1,
		row_index=0,
		op_dspace_type=OpDSpaceType.SPIRAL,
		x_dspace_start=0//This does not matter for spiral
	};
	mem_range_address : int = PushRAMValue(mem_range, *perm.all_data.ram_memory);
	}

	cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_cs2 [%]; //create_cs2

		mov [%], [%];
		map_cs2 [%]; //map_cs2	
	}
}
DONE, 
dspace_id_address,
map_chord_s2_dspace_id_address, dspace_id_address,
map_data_address,
// mem_range_dspace_id_address, dspace_id_address,
// cast(int) MusCallType.map_memory, mem_range_address
,,test_alloc)
,, test_alloc);
//TODO Can add this back when we do map_cs2 to get dspace_id

		// mov [%], [%];
		// muscall %, [%]; //map_memory
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});
	

	//TODO We could run >= 2 frames if terminal events happen after some other events thats are needed.
	//Note : We accumulate the renderer_data so we need to clear every frame.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
	op_spec_data : *OpSpaceSpecData;
	if count_equal {
		op_spec_data = *perm.all_data.all_op_space_spec_data[0];
	}
	//TODO FROM HERE Can put a test here to make sure we creating the ChordSpace
	//and the the voice leadings in general I think.
	//THEN UPDATE CreateChordSpace2 and cleanup that
	//I think just OLDCreateChordSpace2 and new one
	//does not make SpacePoint. Then can either do triangles
	//for chord_s2 vl end points or start on chord_s3
	//can likely do all at once.
	count_equal = AssertEquals(1, op_spec_data.all_op_chord_s2.count);
	if count_equal {
		cs2 : ChordSpace2 = op_spec_data.all_op_chord_s2[0];
		AssertFloat64Equals(asm_cs2.world_pos.x, cast(float64)cs2.dspace_world_center.x);
		AssertFloat64Equals(asm_cs2.world_pos.y, cast(float64)cs2.dspace_world_center.y);
		AssertFloat64Equals(asm_cs2.point_dim.x, cast(float64)cs2.dspace_point_dim.x);
		AssertFloat64Equals(asm_cs2.point_dim.y, cast(float64)cs2.dspace_point_dim.y);
		AssertEquals(tuning_system.music_pt_count, cs2.music_pt_count);
		AssertFloat64Equals(asm_cs2.scale_world_unit, cast(float64)cs2.scale_world_unit);
		AssertEquals(AsmBoolToBool(asm_cs2.is_sound_float), cs2.is_sound_float);
		AssertEquals(asm_cs2.tuning_system_id, cs2.tuning_system_id);
		// AssertFloat64Equals(asm_cs2.transform.m11, cast(float64)cs2.transform.m11);
		// AssertFloat64Equals(asm_cs2.transform.m12, cast(float64)cs2.transform.m12);
		// AssertFloat64Equals(asm_cs2.transform.m21, cast(float64)cs2.transform.m21);
		// AssertFloat64Equals(asm_cs2.transform.m22, cast(float64)cs2.transform.m22);

		//TODO Could check the world_poses are actually valid here too.
		space_pt_rects := ArrayFindAllByAndOp(op_spec_data.ass.all_space_rects,
			cs2.dspace_id, "dspace_id",
			cs2.space_pt_render_order, "render_order",,test_alloc);
		AssertEquals(85, space_pt_rects.count);

		dspace_rects := ArrayFindAllVarName(op_spec_data.ass.all_space_rects,
			cs2.dspace_id, "dspace_id");
		AssertEquals(113, dspace_rects.count);

		//TODO These no longer work because we add the end point order so we just check all of them above
		//this avoid changing overlapping points at runtime
		// music_pt_rects := ArrayFindAllByAndOp(op_spec_data.ass.all_space_rects,
		// 	cs2.dspace_id, "dspace_id",
		// 	cs2.music_pt_render_order, "render_order",,test_alloc);
		// AssertEquals(3, music_pt_rects.count);

		// vl_pt_rects := ArrayFindAllByAndOp(op_spec_data.ass.all_space_rects,
		// 	cs2.dspace_id, "dspace_id",
		// 	cs2.vl_pt_render_order, "render_order",,test_alloc);
		// AssertEquals(25, vl_pt_rects.count);

		// AssertEquals(1, perm.all_data.all_space_triangles.count);
	}
} @ITest

//TODO We can add later OR better yet put it as an example for a dll space.
//Would also be able to put the input the dll and remove it from thegame_base.
//Then we can also add PitchS3 so people can see how incomprehensible it is even with 12-ET.
Test_CreatePitchS2 :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput)
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	SetupMusicAndRows(perm.all_data, TWO_ROWS);

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);


	//TODO Pull this out into it's own MakePitchSpace2D function
	pitch_s2 : PitchSpace2D;
	pitch_s2.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	context.ALL_NEXT_IDS.DSPACE_ID += 1;
	pitch_s2.base_point_count = 12;
	//TODO To see that moving this works.
	pitch_s2.bottom_left_point_pos = Vector2F.{0,0};
	pitch_s2.octave_count = 1;
	pitch_s2.inter_point_gap = Vector2F.{1,1};
	pitch_s2.point_dim = Vector2F.{0.7,0.7};
	array_add(*perm.all_data.all_pitch_space_2D, pitch_s2);

	//TODO Could add a filter to this later. Could also use PermutationLoops if that helps.
	point_count : int = pitch_s2.base_point_count * pitch_s2.octave_count;
	for x : 0..point_count-1 for y : 0..point_count-1 {
		//TODO I kind of want to make this a separate array since it seems
		//liek it would have way less values but can leave like this for now for convenience.
		sp : *SpacePoint = array_add(*perm.all_data.all_space_points);
		sp.id = context.ALL_NEXT_IDS.POINT_ID;
		context.ALL_NEXT_IDS.POINT_ID += 1;
		sp.dspace_id = pitch_s2.dspace_id;
		sp.fun_region_float[0] = cast(float64) x;
		sp.fun_region_float[1] = cast(float64) y;
		//TODO Technically we can just compute these at runtime from the fun_region_float
		//So we would only need 4 * 64 bits stored above since there could be a lot of points
		//Specifically : id, dspace_id and [2] float64
		sp.world_pos = pitch_s2.bottom_left_point_pos + 
			MakeV2F(x * (pitch_s2.point_dim.x + pitch_s2.inter_point_gap.x),
					  y * (pitch_s2.point_dim.y + pitch_s2.inter_point_gap.y));
		sp.rect_mesh = RectCenterDim(sp.world_pos, pitch_s2.point_dim);

		//TODO Could pass in all these values
		if IsOnAxis(float64.[1.0,3.0,6.0,8.0,10.0], sp.fun_region_float, cast(float64) pitch_s2.base_point_count) {
			sp.color = GREY_BLACK_V;
		} else {
			sp.color = GREY_DARKER_V;
		}
	}

	//TODO This might have to be a quad if we allow rotation on the pitch space 2d
	coll : *CollisionEntity = array_add(*perm.all_data.all_op_collision_entities);
	coll.entity_id = pitch_s2.dspace_id;
	coll.entity_type = EntityType.PITCH_S2;
	coll.op_space_id = op_space.id;
	coll.shape = CollisionShape.RECTANGLE;
	bottom_left_corner := pitch_s2.bottom_left_point_pos - 0.5 * pitch_s2.point_dim;
	top_right_corner := bottom_left_corner;
	top_right_corner.x += pitch_s2.octave_count * (pitch_s2.base_point_count * (pitch_s2.point_dim.x + pitch_s2.inter_point_gap.x)) - pitch_s2.inter_point_gap.x;
	top_right_corner.y += pitch_s2.octave_count * (pitch_s2.base_point_count * (pitch_s2.point_dim.y + pitch_s2.inter_point_gap.y)) - pitch_s2.inter_point_gap.y;
	coll.rect = RectMinMax(bottom_left_corner, top_right_corner);

	dspace_to_op : DSpaceToOpSpaceIndex = ---;
	dspace_to_op.dspace_id = pitch_s2.dspace_id;
	dspace_to_op.op_dspace_type = OpDSpaceType.PITCH_S2;
	dspace_to_op.op_space_id = op_space.id;
	array_add(*perm.all_data.all_dspace_to_op_space_id, dspace_to_op);

} @ITest


//TODO Then we can also add PitchS3 so people can see how incomprehensible it is even with 12-ET.
Test_CreatePitchS3 :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	SetupMusicAndRows(perm.all_data, CreateRowData.[
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		]);


	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.chord_s3;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	//This is separated out so we can reuse but may note be necessary
	//with new methods of coding now.
	cam_trans : Matrix4x3F = DEFAULT_CAM_TRANS;
	//TODO Need to recompute this when we change the size of 
	// viewport_dim := Vector2F.{49,28}; //ORIGINAL SIZE
	// viewport_dim := Vector2F.{25,25};
	viewport_dim := OP_SPACE_DEFAULT_SIZE;
	//TODO This should be passed into MakeChordSpace3
	bp_count : int = 12;
	//TODO This is incomprehensible in 3D but maybe good for showing that it is and why we have to reduce the space.
	chord_s3 := MakePitchSpace3(Vector2F.{0,0}, viewport_dim,
		renderer_data.base_render_group.focal_squares, 1.0, 240.0,
		*perm.all_data.visible_space_points_3D);
	//TODO Should we pass this into MakeChordSpace3?
	//Where should this be? Maybe only update it once we update the op_space model properly.
	chord_s3.op_space_id = op_space.id;
	array_add(*perm.all_data.all_chord_spaces_3, chord_s3);


	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);	


} @ITest

//TODO FROM HERE update spiral to use OpSpaceSpecData and remove the vls here and just do 2 spirals
//then update asm spirals using the op space spec data instead and generate asm library
//and then do the same thing for circles before doing setup music and then rows
Test_CreateSpiral :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	SetupMusicAndRows(perm.all_data, TWO_ROWS);

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
	op_spec_data : *OpSpaceSpecData;
	if count_equal {
		op_spec_data = *perm.all_data.all_op_space_spec_data[0];
	}

	//TODO Where do we store these? We need to attach arbitrarily sized arrays to the SpacePoint or to something else.
	//Should it just be the value of the first point?
	//TODO Should we store these as inter_onsets in a separate array so we can compare them easily for
	//ChordToSpiralPoint which can just check inter_onsets more easily then.
	// base_chords : [..][] float64;
	// array_add(*base_chords, CreateArray(float64, temp, 0,4,7));
	// array_add(*base_chords, CreateArray(float64, temp, 0,3,7));
	base_chord := float64.[0,4,7];

	spiral : SpiralSpace;
	spiral.spiral_type = SpiralType.PROPER;
	spiral.world_center_pos = Vector2F.{0,0};
	spiral.tuning_system_id = 0;
	spiral.pitch_zero_freq = C3;
	spiral.tuning_count = 12;
	// spiral.tuning_count = 120;
	// spiral.tuning_count = 53;
	spiral.chord_count = base_chord.count;
	// spiral.rotate = 3*PI/2.0;
	spiral.rotate = PI/2.0;
	spiral.is_clockwise = true;
	spiral.radius_size = 3.6; // Use to adjust spiral_delta size going out
	spiral.sr_factor = 1.5; // Use to adjust inner radius size (although it does effect overall spiral size as well)
	spiral.is_in_out = true;
	spiral.sound_float = true;
	spiral.point_dim = Vector2F.{0.5,0.5};
	spiral.synth.wave_type = OscWaveType.SAW;
	sp : *SpiralSpace = CreateSpiralInSpace(spiral, op_spec_data);
	//TODO Just don't call this if we want to put our own points on Spiral.
	//Then can still associate those to the tuning_system of the spiral for example.
	//TODO sound_float should be off if we don't set this since we only have arbitrary points then
	SetSpiralBase(base_chord, 0, sp, op_spec_data);

	//NOTE : The major/minor double spiral
	#if 1 {
	minor_chord := float64.[0,3,7];

	create_s2 : SpiralSpace;
	create_s2.spiral_type = SpiralType.PROPER;
	create_s2.world_center_pos = Vector2F.{0,0};
	create_s2.tuning_system_id = 0;
	create_s2.pitch_zero_freq = C3;
	create_s2.tuning_count = 12;
	// create_s2.tuning_count = 120;
	// create_s2.tuning_count = 53;
	create_s2.chord_count = minor_chord.count;
	// create_s2.rotate = 3*PI/2.0;
	create_s2.rotate = PI/2.0;
	create_s2.is_clockwise = true;
	create_s2.radius_size = 3.8; // Use to adjust spiral_delta size going out
	create_s2.sr_factor = 1.5; // Use to adjust inner radius size (although it does effect overall create_s2 size as well)
	create_s2.is_in_out = true;
	create_s2.sound_float = false;
	create_s2.point_dim = Vector2F.{0.5,0.5};
	create_s2.synth.wave_type = OscWaveType.SAW;
	s2 : *SpiralSpace = CreateSpiralInSpace(create_s2, op_spec_data);
	SetSpiralBase(minor_chord, 1, s2, op_spec_data);
	}

	#if 0 {
	float_base := float64.[0,4,7];
	float_chord := float_base;
	for * float_chord it.* += 1.11111;
	CreateSpiralPointAndValues(float_chord, spiral,
		*perm.all_data.all_space_points,
		*perm.all_data.all_space_point_to_value,
		color = LIGHT_BROWN);

	//NOTE : Example of mapping another chord to the same point. Any chord with 3 values and base 0
	//would be mapped here in the same way
	CreateSpiralPoint(0, 0, spiral.*, *perm.all_data.all_space_points, FGREEN_V);
	//TODO Could add values here otherwise there is an assertion error in spiral hovering
	/*NOTE TODO : This flexible voice leading along with CreateSpiralPoint function allows us to place any point
	so we can even ignore the base_chord and just place anything with the same starting value.
	TODO We COULD even add voice leadings between 2 spaces here as well and then store both dspaces OR
	just store both points at that point. THAT MIGHT BE BETTER EVENTUALLY to draw vls between spaces and then
	we just store the points and possibly dspaces if we need more info and thats it. Can leave like this for now
	but won't be too hard to do inter-dspace voice leading eventually like this but storing both points instead.
	*/
	//TODO Could use BaseValueToSpiralIndex but I like the explicitness of this. It shows the linearity of the spiral.
	vl : *SpiralVoiceLeading = array_add(*perm.all_data.all_spiral_vls);
	vl.dspace_id = spiral.dspace_id;
	// vl.start_spiral_index = 0.0 * spiral.chord_count;
	// vl.end_spiral_index = 2.0 * spiral.chord_count;
	vl.start_pos = FloatIndexToSpiralPos(0.0 * spiral.chord_count, spiral.*);
	vl.end_pos = FloatIndexToSpiralPos(2.0 * spiral.chord_count, spiral.*);

	vl = array_add(*perm.all_data.all_spiral_vls);
	vl.dspace_id = spiral.dspace_id;
	// vl.start_spiral_index = 2.0 * spiral.chord_count;
	// vl.end_spiral_index = 5.0 * spiral.chord_count;
	vl.start_pos = FloatIndexToSpiralPos(2.0 * spiral.chord_count, spiral.*);
	vl.end_pos = FloatIndexToSpiralPos(5.0 * spiral.chord_count, spiral.*);
	}
	//TODO Voice leadings would look something like this when we implement them in asm.
	/*Can store voice leadings as point index instead of chords so we just connect 2 space_point_ids
	and then connect those and can possibly cache the point_index and the space_point_ids
	and then compute at runtime.
	*/
	#if 0 {
	first_point : Vector2F = ChordToSpiralPoint(float64.[0,4,7], base_chord, 0, spiral.*);
	second_point : Vector2F = ChordToSpiralPoint(float64.[2,6,9], base_chord, 0, spiral.*);
	PushQuadArrowViewport(first_point, second_point, LBLUE_V, 0.1, renderer_data.base_render_group, order = 12);

	third_point : Vector2F = ChordToSpiralPoint(float64.[5,8,12], base_chord, 1, spiral.*);
	PushQuadArrowViewport(second_point, third_point, LBLUE_V, 0.1, renderer_data.base_render_group, order = 12);

	dspace_to_op : DSpaceToOpSpaceIndex = ---;
	dspace_to_op.dspace_id = spiral.dspace_id;
	dspace_to_op.op_dspace_type = OpDSpaceType.SPIRAL;
	dspace_to_op.op_space_id = op_space.id;
	array_add(*perm.all_data.all_dspace_to_op_space_id, dspace_to_op);
	}

	//We run 2 frames so that the next_frame_terminal_events get processed.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);	

} @ITest

ASM_MEM_RANGE :: inline (mr : MemoryRangeToDSpace) -> string {
	return sprint(
#string DONE 
mov ax, scp;
push %; //x_start
push %; //x_end
push %; //row_index
push [%]; //dspace_id
push %; //op_dspace_type
push %; //x_dspace_start
muscall %, [ax];
DONE,
formatFloat(mr.x_start,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
formatFloat(mr.x_end,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
mr.row_index,
mr.dspace_id, 
cast(int) mr.op_dspace_type,
formatFloat(mr.x_dspace_start,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
cast(int) MusCallType.map_memory
,,context.allocator);
}
ASM_MAP_SPIRAL :: inline (msd : MapSpiralData) -> string {
	return sprint(
#string DONE 
mov ax, scp;
push %; //op_space_id
push [%]; //dspace_id
push %; //dspace_shape_group
push %; //chord_data
push %; //chord_count
push %; //draw_vl_lines
muscall %, [ax];
DONE,
msd.op_space_id,
msd.dspace_id,
msd.dspace_shape_group,
msd.chord_data,
msd.chord_count,
msd.draw_vl_lines,
cast(int) MusCallType.map_spiral
,,context.allocator);
}
Test_AsmSpiral :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);
	CreateManyMusicPtsInMemory(float64.[0,4,7], 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
	op_spec_data : *OpSpaceSpecData;
	if count_equal {
		op_spec_data = *perm.all_data.all_op_space_spec_data[0];
	}

	// ts_name := "gamma";
	// ts_name := "et12";
	// ts_name := "pyth";
	ts_name := "natural";
	//TODO Need to set this in AsmCreateSpiral and SpiralSpace if we want to be able to hear it eventually.
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	base_chord := float64.[0,4,7];

	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;

	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	asm_spiral : *AsmCreateSpiral = PushStruct(AsmCreateSpiral, *perm.all_data.ram_memory);
	asm_spiral.op_space_id = 0;
	asm_spiral.spiral_type = SpiralType.PROPER;
	asm_spiral.world_pos = Vector2F64.{0,0};
	asm_spiral.tuning_system_id = 0;
	asm_spiral.pitch_zero_freq = C3;
	//TODO Should we rename these? Maybe chord_count -> turn_count
	asm_spiral.tuning_count = 12;
	asm_spiral.chord_count = base_chord.count;
	asm_spiral.rotate = PI64/2;
	// asm_spiral.rotate = 0;
	asm_spiral.is_clockwise = ToAsmBool(true);
	asm_spiral.radius_size = 3.0; // Use to adjust spiral_delta size going out
	asm_spiral.sr_factor = 1.5; // Use to adjust inner radius size (although it does effect overall spiral size as well)
	asm_spiral.is_in_out = ToAsmBool(true);
	asm_spiral.sound_float = ToAsmBool(false);
	asm_spiral.is_loop = ToAsmBool(true);
	asm_spiral.show_values = ToAsmBool(true);
	asm_spiral.point_dim = Vector2F64.{0.5,0.5};
	asm_spiral.osc_wave_type = OscWaveType.SAW;

	//Add some base points to memory
	// asm_spiral.set_base_points = cast(int) true; //asm bool
	// asm_spiral.base_chord_data = perm.all_data.ram_memory.stack_p;
	asm_spiral.base_index = 0;
	asm_spiral.base_chord.count, asm_spiral.base_chord.data_address = 
		PushRAMArray(base_chord, *perm.all_data.ram_memory);

	second_chord := NewArray(base_chord.count, float64, false);
	for base_chord second_chord[it_index] = it+2.5;
	PushRAMValues(second_chord, *perm.all_data.ram_memory);

	//NOTE : I prefer this way over the generated asm since we don't have to update tests every time
	//we change this data and the compiler helps. Only if we change the name of dspace_id basically.
	ti_member, dspace_id_offset_in_bytes := 
		get_field(type_info(MapSpiralData), "dspace_id");
	map_spiral_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	map_spiral_data := AsmMapSpiral.{
		op_space_id=op_space.id,
		dspace_shape_group=0,
		map_chords=.{2*base_chord.count, asm_spiral.base_chord.data_address},
		draw_vl_lines=ToAsmBool(true)
	};
	map_spiral_address : int = PushRAMValue(map_spiral_data, *perm.all_data.ram_memory);

	#if 0 {
	ti_member, dspace_id_offset_in_bytes = 
		get_field(type_info(MemoryRangeToDSpace), "dspace_id");
	mem_range_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	mem_range := MemoryRangeToDSpace.{
		x_start=0,
		x_end=1,
		row_index=0,
		op_dspace_type=OpDSpaceType.SPIRAL,
		x_dspace_start=0//This does not matter for spiral
	};
	mem_range_address : int = PushRAMValue(mem_range, *perm.all_data.ram_memory);
	}

	cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_spiral [%]; //create_spiral

		mov [%], [%];
		map_spiral [%]; //map_spiral	
	}
}
DONE, 
dspace_id_address,
map_spiral_dspace_id_address, dspace_id_address,
map_spiral_address,
// mem_range_dspace_id_address, dspace_id_address,
// cast(int) MusCallType.map_memory, mem_range_address
,,test_alloc)
,, test_alloc);
		// mov [%], [%];
		// muscall %, [%]; //map_memory
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});
	

	//TODO We could run >= 2 frames if terminal events happen after some other events thats are needed.
	//Note : We accumulate the renderer_data so we need to clear every frame.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_good := AssertEquals(1, op_spec_data.all_op_spirals.count);
	if count_good {
		spiral : SpiralSpace = op_spec_data.all_op_spirals[0];
		AssertEquals(asm_spiral.spiral_type, spiral.spiral_type);
		AssertFloat64Equals(asm_spiral.world_pos.x, cast(float64)spiral.world_center_pos.x);
		AssertFloat64Equals(asm_spiral.world_pos.y, cast(float64)spiral.world_center_pos.y);
		AssertEquals(asm_spiral.tuning_count, spiral.tuning_count);
		AssertEquals(asm_spiral.chord_count, spiral.chord_count);
		AssertFloat64Equals(asm_spiral.rotate, cast(float64)spiral.rotate);
		AssertFloat64Equals(asm_spiral.rotate, cast(float64)spiral.rotate);
		AssertFloat64Equals(asm_spiral.point_dim.x, cast(float64)spiral.point_dim.x);
		AssertFloat64Equals(asm_spiral.point_dim.y, cast(float64)spiral.point_dim.y);
		// AssertEquals(AsmBoolToBool(asm_spiral.set_base_points), spiral.has_base_points);
		AssertEquals(AsmBoolToBool(asm_spiral.is_clockwise), spiral.is_clockwise);
		AssertEquals(AsmBoolToBool(asm_spiral.sound_float), spiral.sound_float);
		AssertEquals(AsmBoolToBool(asm_spiral.is_loop), spiral.is_loop);
		AssertEquals(AsmBoolToBool(asm_spiral.show_values), spiral.show_values);

		//TODO We need to check SpacePoint as well but I will likely
		//make them rects later, so I would rather just wait to do that
		//before writing more explicit tests.
		//Also should check the world_poses and dspace_id and everything here
		//once we change that.
		map_count : int = 2;
		AssertEquals(asm_spiral.tuning_count+map_count, op_spec_data.ass.all_space_rects.count);
		AssertEquals(1, op_spec_data.ass.all_space_quads.count);
		AssertEquals(1, op_spec_data.ass.all_space_triangles.count);
		AssertEquals(asm_spiral.tuning_count, op_spec_data.ass.all_space_text.count);
		// AssertEquals(asm_spiral.tuning_count*asm_spiral.chord_count + map_count*asm_spiral.chord_count, perm.all_data.all_space_shape_values.count);
		//TODO Could check the world_poses are actually valid here too.
	}
} @ITest

//TODO Rename to Test_CreateCircle once we update the asm
//and then remove the old circle since this is now generalized.
Test_CreateNewCircle :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	SetupMusicAndRows(perm.all_data, TWO_ROWS);

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
	op_spec_data : *OpSpaceSpecData;
	if count_equal {
		op_spec_data = *perm.all_data.all_op_space_spec_data[0];
	}

	// ts_name := "gamma";
	// ts_name := "et12";
	// ts_name := "pyth";
	ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	//TODO Should make a version of this where we pass in num_of_points
	c_data := CreateCircleSpaceData.{
	tuning_system_id = tuning_system.id,
	radius = 10,
	start_note = 0,
	repeating_interval_ratio = 4.0,
	//TODO Should we make this automatically false based on repeating_interval_ratio if it's not a multiple of compass_interval?
	is_repeating = true,
	is_sound_float = true,
	inner_circle_mute = 0.3,
	no_base_points = false,
	show_text = true
	};

	circle : *CircleSpace = CreateCircleInOpSpace(c_data, op_spec_data, 
		perm.all_data.all_tuning_systems, perm.all_data.all_tuning_pitches);

	mem := float64.[0.5,4.5,7.5];
	CreateManyMusicPtsInMemory(mem, 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);
	mem_to_dspace : *MemoryUnitToDSpace = array_add(*perm.all_data.all_memory_unit_to_dspace);
	mem_to_dspace.x_index = 0;
	mem_to_dspace.row_index = 0;
	mem_to_dspace.dspace_id = circle.dspace_id;

} @ITest

Test_AsmCircle :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);
	base_chord := float64.[0,4,7];
	CreateManyMusicPtsInMemory(base_chord, 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);

	// ts_name := "gamma";
	// ts_name := "et12";
	// ts_name := "pyth";
	ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;

	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	asm_circle : AsmCircleData;
	asm_circle.world_center = Vector2F64.{0,0};
	asm_circle.point_dim = Vector2F64.{0.6,0.6};
	asm_circle.op_space_id = op_space.id;
	asm_circle.tuning_system_id = tuning_system.id;
	asm_circle.radius = 10;
	asm_circle.start_note = 0;
	asm_circle.repeating_interval_ratio = 4.0;
	asm_circle.non_repeating = ToAsmBool(false);
	asm_circle.is_sound_float = ToAsmBool(false);
	asm_circle.inner_circle_mute = 0.6;
	asm_circle.no_base_points = ToAsmBool(false);
	asm_circle.show_text = ToAsmBool(true);
	PushRAMValue(asm_circle, *perm.all_data.ram_memory);

	base_chord_address := PushRAMValues(base_chord, *perm.all_data.ram_memory);

	// second_chord := NewArray(base_chord.count, float64, false);
	// for base_chord second_chord[it_index] = it+2;
	// PushRAMValues(second_chord, *perm.all_data.ram_memory);

	//NOTE : I prefer this way over the generated asm since we don't have to update tests every time
	//we change this data and the compiler helps. Only if we change the name of dspace_id basically.
	ti_member, dspace_id_offset_in_bytes := 
		get_field(type_info(AsmMapCircle), "dspace_id");
	map_circle_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	map_circle_data := AsmMapCircle.{
		dspace_shape_group = 0,
		pitches = .{base_chord.count, base_chord_address},
		draw_vl_type = DrawVLType.VL_LINE,
	};
	map_circle_address : int = PushRAMValue(map_circle_data, *perm.all_data.ram_memory);

cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_circle [%];

		mov [%], [%];
		map_circle [%];
	}
}
DONE, 
dspace_id_address,
map_circle_dspace_id_address, dspace_id_address,
map_circle_address,
,,test_alloc)
,, test_alloc);
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});


	//TODO We could run >= 2 frames if terminal events happen after some other events thats are needed.
	//Note : We accumulate the renderer_data so we need to clear every frame.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
	op_spec_data : *OpSpaceSpecData;
	if count_equal {
		op_spec_data = *perm.all_data.all_op_space_spec_data[0];
	}

	count_equal = AssertEquals(op_spec_data.all_op_circle_spaces.count, 1);
	if count_equal {
		circle : CircleSpace = op_spec_data.all_op_circle_spaces[0];
		AssertFloat64Equals(asm_circle.radius, circle.radius);
		AssertFloat64Equals(asm_circle.inner_circle_mute, circle.inner_circle_mute);
		AssertFloat64Equals(asm_circle.repeating_interval_ratio, circle.repeating_interval_ratio);
		AssertEquals(MakeV2FFrom64(asm_circle.world_center), circle.world_center);
		AssertEquals(AsmBoolToBool(asm_circle.is_sound_float), circle.is_sound_float);
		AssertEquals(asm_circle.start_note, circle.start_note);
		AssertEquals(24, circle.inter_points.count);

		AssertEquals(27, op_spec_data.ass.all_space_rects.count);
		AssertEquals(3, op_spec_data.ass.all_space_quads.count);
		AssertEquals(24, op_spec_data.ass.all_space_text.count);

		// circle_point_count : int = 0;
		// for op_spec_data.all_op_space_points if it.dspace_id == circle.dspace_id {
		// 	circle_point_count += 1;
		// }
		count_equal = AssertEquals(0, op_spec_data.all_op_space_points.count);
		//TODO Could check the world_poses are actually valid here too.
	}
	//TODO Could check specific space points for different tuning_systems later
	//to make sure it works for most cases in general


} @ITest

Test_AsmCircleShape :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);
	base_chord := float64.[0,4,7];
	CreateManyMusicPtsInMemory(base_chord, 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");
	tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id");

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;

	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	asm_circle : AsmCircleData;
	asm_circle.world_center = Vector2F64.{0,0};
	asm_circle.point_dim = Vector2F64.{0.6,0.6};
	asm_circle.op_space_id = 0;
	asm_circle.tuning_system_id = tuning_system.id;
	asm_circle.radius = 10;
	asm_circle.start_note = 0;
	asm_circle.repeating_interval_ratio = 2.0;
	asm_circle.non_repeating = ToAsmBool(false);
	asm_circle.is_sound_float = ToAsmBool(true);
	asm_circle.inner_circle_mute = 0.6;
	asm_circle.no_base_points = ToAsmBool(false);
	PushRAMValue(asm_circle, *perm.all_data.ram_memory);

	base_chord_address := PushRAMValues(base_chord, *perm.all_data.ram_memory);

	// second_chord := NewArray(base_chord.count, float64, false);
	// for base_chord second_chord[it_index] = it+2;
	// PushRAMValues(second_chord, *perm.all_data.ram_memory);

	//NOTE : I prefer this way over the generated asm since we don't have to update tests every time
	//we change this data and the compiler helps. Only if we change the name of dspace_id basically.
	shape_member, shape_id_offset_in_bytes := 
		get_field(type_info(AsmShapeData), "shape_id");
	asm_shape_id_address : int = 
		perm.all_data.ram_memory.stack_p + shape_id_offset_in_bytes;	
	ti_member, dspace_id_offset_in_bytes := 
		get_field(type_info(AsmShapeData), "dspace_id");
	asm_shape_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	asm_shape_address : int = perm.all_data.ram_memory.stack_p;
	asd : *AsmShapeData = PushStruct(AsmShapeData, *perm.all_data.ram_memory);
	asd.op_space_id = op_space.id;
	asd.dspace_shape_group = 1;
	asd.render_order = 100;
	//TODO can store this with other colors if we reuse
	FGREEN_V_64 :: Vector4F64.{143.0/255.0, 210.0/255.0, 121.0/255.0, 1.0};
	asd.color = FGREEN_V_64;
	asd.type = AsmShapeType.RECTANGLE;
	asd.rect_pos = Vector2F64.{0,0};
	asd.rect_dim = Vector2F64.{1,1};
	asd_rect := RectCenterDim(MakeV2FFrom64(asd.rect_pos), MakeV2FFrom64(asd.rect_dim));
	// asm_shape_address : int = PushRAMValue(asd, *perm.all_data.ram_memory);

	pitch_set := float64.[12];
	asd.pitch_set.count, asd.pitch_set.data_address = 
		PushRAMArray(pitch_set, *perm.all_data.ram_memory);

	#if 0 {
	value_member, value_shape_id_offset_in_bytes := 
		get_field(type_info(SpaceShapeValue), "shape_id");
	value_shape_id_address : int = 
		perm.all_data.ram_memory.stack_p + value_shape_id_offset_in_bytes;
	ssv : SpaceShapeValue;
	ssv.float_value = MusicPtToFrequency(12, tuning_system, tuning_pitches);
	shape_value_address : int = PushRAMValue(ssv, *perm.all_data.ram_memory);
	}


cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_circle [%];

		mov [%], [%];
		create_shape [%];
	}
}
DONE, 
dspace_id_address,
asm_shape_dspace_id_address, dspace_id_address,
asm_shape_address,
,,test_alloc)
,, test_alloc);
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});


	//TODO We could run >= 2 frames if terminal events happen after some other events thats are needed.
	//Note : We accumulate the renderer_data so we need to clear every frame.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
	op_spec_data : *OpSpaceSpecData;
	if count_equal {
		op_spec_data = *perm.all_data.all_op_space_spec_data[0];
	}

	count_equal = AssertEquals(12+1, op_spec_data.ass.all_space_rects.count);
	if !count_equal return;
	// count_equal = AssertEquals(12+1, op_spec_data.ass.all_space_shape_values.count);
	// if !count_equal return;
	count_equal = AssertEquals(1, op_spec_data.all_op_circle_spaces.count);
	if !count_equal return;
	circle : CircleSpace = op_spec_data.all_op_circle_spaces[0];
	last_rect : SpaceRect = peek(op_spec_data.ass.all_space_rects);
	AssertEquals(circle.dspace_id, last_rect.dspace_id);
	AssertEquals(op_space.id, last_rect.op_space_id);
	AssertEquals(asd.dspace_shape_group, last_rect.dspace_shape_group);
	AssertEquals(asd.render_order, last_rect.render_order);
	AssertFloatEquals(FGREEN_V.x, last_rect.color.x);
	AssertFloatEquals(FGREEN_V.y, last_rect.color.y);
	AssertFloatEquals(FGREEN_V.z, last_rect.color.z);
	AssertFloatEquals(FGREEN_V.w, last_rect.color.w);
	AssertFloatEquals(asd_rect.min.x, last_rect.rect.min.x);
	AssertFloatEquals(asd_rect.min.y, last_rect.rect.min.y);
	AssertFloatEquals(asd_rect.max.x, last_rect.rect.max.x);
	AssertFloatEquals(asd_rect.max.y, last_rect.rect.max.y);
	// last_value : SpaceShapeValue = peek(op_spec_data.ass.all_space_shape_values);
	// AssertEquals(last_rect.shape_id, last_value.shape_id);
	// AssertFloat64Equals(ssv.float_value, last_value.float_value);


} @ITest

Test_AsmGeom2D :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	// SetupMusicAndRows(perm.all_data, TWO_ROWS);
	// base_chord := float64.[0,4,7];
	// CreateManyMusicPtsInMemory(base_chord, 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);

	// ts_name := "gamma";
	ts_name := "et12";
	// ts_name := "pyth";
	// ts_name := "natural";
	tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, ts_name, "short_name");
	tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id");

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	perm.all_data.ram_memory.stack_p = DEFAULT_RAM_DATA;

	dspace_id_address : int = perm.all_data.ram_memory.stack_p;
	asm_cg_address : int = perm.all_data.ram_memory.stack_p;
	asm_cg : *AsmGeom2D = PushStruct(AsmGeom2D, *perm.all_data.ram_memory);
	asm_cg.* = .{};
	asm_cg.op_space_id = op_space.id;
	asm_cg.tuning_system_id = tuning_system.id;
	asm_cg.op_space_id = op_space.id;
	asm_cg.osc_wave_type = OscWaveType.SINE;
	asm_cg.collision_pos = Vector2F64.{1,1};
	asm_cg.collision_dim = Vector2F64.{8,8};
	asm_cg_rect := RectCenterDim(
		MakeV2FFrom64(asm_cg.collision_pos), 
		MakeV2FFrom64(asm_cg.collision_dim));
	asm_cg.show_collision = ToAsmBool(true);
	// asm_cg_address := PushRAMValue(asm_cg, *perm.all_data.ram_memory);

	//NOTE : I prefer this way over the generated asm since we don't have to update tests every time
	//we change this data and the compiler helps. Only if we change the name of dspace_id basically.
	shape_member, shape_id_offset_in_bytes := 
		get_field(type_info(AsmShapeData), "shape_id");
	asm_shape_id_address : int = 
		perm.all_data.ram_memory.stack_p + shape_id_offset_in_bytes;	
	ti_member, dspace_id_offset_in_bytes := 
		get_field(type_info(AsmShapeData), "dspace_id");
	asm_shape_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	asm_shape_address : int = perm.all_data.ram_memory.stack_p;
	asd : *AsmShapeData = PushStruct(AsmShapeData, *perm.all_data.ram_memory);
	asd.op_space_id = op_space.id;
	asd.dspace_shape_group = 1;
	asd.render_order = 100;
	//TODO can store this with other colors if we reuse
	FGREEN_V_64 :: Vector4F64.{143.0/255.0, 210.0/255.0, 121.0/255.0, 1.0};
	asd.color = FGREEN_V_64;
	asd.type = AsmShapeType.RECTANGLE;
	asd.rect_pos = Vector2F64.{-1,-1};
	asd.rect_dim = Vector2F64.{0.8,0.8};
	asd_rect := RectCenterDim(MakeV2FFrom64(asd.rect_pos), MakeV2FFrom64(asd.rect_dim));
	// asm_shape_address : int = PushRAMValue(asd, *perm.all_data.ram_memory);

	pitch_set := float64.[12,12+3];
	asd.pitch_set.count, asd.pitch_set.data_address = 
		PushRAMArray(pitch_set, *perm.all_data.ram_memory);

	#if 0 {
	value_member, value_shape_id_offset_in_bytes := 
		get_field(type_info(SpaceShapeValue), "shape_id");
	v1_shape_id_address : int = 
		perm.all_data.ram_memory.stack_p + value_shape_id_offset_in_bytes;
	ssv : SpaceShapeValue;
	ssv.op_space_id = op_space.id;
	ssv.float_value = MusicPtToFrequency(12, tuning_system, tuning_pitches);
	v1_address : int = PushRAMValue(ssv, *perm.all_data.ram_memory);

	v2_shape_id_address : int = perm.all_data.ram_memory.stack_p 
		+ value_shape_id_offset_in_bytes;
	ssv_2 : SpaceShapeValue;
	ssv_2.op_space_id = op_space.id;
	ssv_2.float_value = MusicPtToFrequency(12+3, tuning_system, tuning_pitches);
	v2_address : int = PushRAMValue(ssv_2, *perm.all_data.ram_memory);
	}

	//TODO FROM HERE add another shape with differing values
	s2_shape_id_address : int = 
		perm.all_data.ram_memory.stack_p + shape_id_offset_in_bytes;	
	s2_dspace_id_address : int = 
		perm.all_data.ram_memory.stack_p + dspace_id_offset_in_bytes;
	s2_address : int = perm.all_data.ram_memory.stack_p;
	asd_2 : *AsmShapeData = PushStruct(AsmShapeData, *perm.all_data.ram_memory);
	asd_2.op_space_id = op_space.id;
	asd_2.dspace_shape_group = 1;
	asd_2.render_order = 100;
	//TODO can store this with other colors if we reuse
	asd_2.color = FGREEN_V_64;
	asd_2.type = AsmShapeType.RECTANGLE;
	asd_2.rect_pos = Vector2F64.{2,3};
	asd_2.rect_dim = Vector2F64.{1.2,0.8};
	s2_rect := RectCenterDim(MakeV2FFrom64(asd_2.rect_pos), MakeV2FFrom64(asd_2.rect_dim));
	// s2_address : int = PushRAMValue(asd_2, *perm.all_data.ram_memory);

	pitch_set_2 := float64.[12,12+4,12+7];
	asd_2.pitch_set.count, asd_2.pitch_set.data_address = 
		PushRAMArray(pitch_set_2, *perm.all_data.ram_memory);

	#if 0 {
	s2_v1_shape_id_address : int = 
		perm.all_data.ram_memory.stack_p + value_shape_id_offset_in_bytes;
	s2_ssv : SpaceShapeValue;
	s2_ssv.op_space_id = op_space.id;
	s2_ssv.float_value = MusicPtToFrequency(12, tuning_system, tuning_pitches);
	s2_v1_address : int = PushRAMValue(s2_ssv, *perm.all_data.ram_memory);

	s2_v2_shape_id_address : int = perm.all_data.ram_memory.stack_p 
		+ value_shape_id_offset_in_bytes;
	s2_ssv_2 : SpaceShapeValue;
	s2_ssv_2.op_space_id = op_space.id;
	s2_ssv_2.float_value = MusicPtToFrequency(12+4, tuning_system, tuning_pitches);
	s2_v2_address : int = PushRAMValue(s2_ssv_2, *perm.all_data.ram_memory);

	s2_v3_shape_id_address : int = perm.all_data.ram_memory.stack_p 
		+ value_shape_id_offset_in_bytes;
	s2_ssv_3 : SpaceShapeValue;
	s2_ssv_3.op_space_id = op_space.id;
	s2_ssv_3.float_value = MusicPtToFrequency(12+7, tuning_system, tuning_pitches);
	s2_v3_address : int = PushRAMValue(s2_ssv_3, *perm.all_data.ram_memory);
	}


cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_custom_geometry [%];

		//shape 1
		mov [%], [%];
		create_shape [%];

		//shape 2
		mov [%], [%];
		create_shape [%];
	}
}
DONE, 
asm_cg_address,
//shape 1
asm_shape_dspace_id_address, dspace_id_address,
asm_shape_address,
//shape 2
s2_dspace_id_address, dspace_id_address,
s2_address,
,,test_alloc)
,, test_alloc);
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});


	//TODO We could run >= 2 frames if terminal events happen after some other events thats are needed.
	//Note : We accumulate the renderer_data so we need to clear every frame.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
	op_spec_data : *OpSpaceSpecData;
	if count_equal {
		op_spec_data = *perm.all_data.all_op_space_spec_data[0];
	}

	count_equal = AssertEquals(2, op_spec_data.ass.all_space_rects.count);
	if !count_equal return;
	// count_equal = AssertEquals(5, op_spec_data.ass.all_space_shape_values.count);
	// if !count_equal return;
	count_equal = AssertEquals(1, op_spec_data.ass.all_custom_geometries.count);
	if !count_equal return;
	cg : CustomGeometry = op_spec_data.ass.all_custom_geometries[0];
	// AssertEquals(asm_cg.op_space_id, cg.op_space_id);
	AssertEquals(asm_cg.tuning_system_id, cg.tuning_system_id);
	AssertEquals(asm_cg.osc_wave_type, cg.synth.wave_type);
	AssertEquals(AsmBoolToBool(asm_cg.show_collision), cg.show_collision);
	AssertFloatEquals(asm_cg_rect.min.x, cg.collision_rect.min.x);
	AssertFloatEquals(asm_cg_rect.min.y, cg.collision_rect.min.y);
	AssertFloatEquals(asm_cg_rect.max.x, cg.collision_rect.max.x);
	AssertFloatEquals(asm_cg_rect.max.y, cg.collision_rect.max.y);

	r0 : SpaceRect = op_spec_data.ass.all_space_rects[0];
	AssertEquals(cg.dspace_id, r0.dspace_id);
	AssertEquals(op_space.id, r0.op_space_id);
	AssertEquals(asd.dspace_shape_group, r0.dspace_shape_group);
	AssertEquals(asd.render_order, r0.render_order);
	AssertFloatEquals(FGREEN_V.x, r0.color.x);
	AssertFloatEquals(FGREEN_V.y, r0.color.y);
	AssertFloatEquals(FGREEN_V.z, r0.color.z);
	AssertFloatEquals(FGREEN_V.w, r0.color.w);
	AssertFloatEquals(asd_rect.min.x, r0.rect.min.x);
	AssertFloatEquals(asd_rect.min.y, r0.rect.min.y);
	AssertFloatEquals(asd_rect.max.x, r0.rect.max.x);
	AssertFloatEquals(asd_rect.max.y, r0.rect.max.y);
	AssertArrayEquals(pitch_set, r0.pitch_set);
	// v0 : SpaceShapeValue = op_spec_data.ass.all_space_shape_values[0];
	// AssertEquals(r0.shape_id, v0.shape_id);
	// AssertFloat64Equals(ssv.float_value, v0.float_value);
	// v1 : SpaceShapeValue = op_spec_data.ass.all_space_shape_values[1];
	// AssertEquals(r0.shape_id, v1.shape_id);
	// AssertFloat64Equals(ssv_2.float_value, v1.float_value);

	r1 : SpaceRect = op_spec_data.ass.all_space_rects[1];
	AssertEquals(cg.dspace_id, r1.dspace_id);
	AssertEquals(op_space.id, r1.op_space_id);
	AssertEquals(asd.dspace_shape_group, r1.dspace_shape_group);
	AssertEquals(asd.render_order, r1.render_order);
	AssertFloatEquals(FGREEN_V.x, r1.color.x);
	AssertFloatEquals(FGREEN_V.y, r1.color.y);
	AssertFloatEquals(FGREEN_V.z, r1.color.z);
	AssertFloatEquals(FGREEN_V.w, r1.color.w);
	AssertFloatEquals(s2_rect.min.x, r1.rect.min.x);
	AssertFloatEquals(s2_rect.min.y, r1.rect.min.y);
	AssertFloatEquals(s2_rect.max.x, r1.rect.max.x);
	AssertFloatEquals(s2_rect.max.y, r1.rect.max.y);
	AssertArrayEquals(pitch_set_2, r1.pitch_set);
	// v2 : SpaceShapeValue = op_spec_data.ass.all_space_shape_values[2];
	// AssertEquals(r1.shape_id, v2.shape_id);
	// AssertFloat64Equals(s2_ssv.float_value, v2.float_value);
	// v3 : SpaceShapeValue = op_spec_data.ass.all_space_shape_values[3];
	// AssertEquals(r1.shape_id, v3.shape_id);
	// AssertFloat64Equals(s2_ssv_2.float_value, v3.float_value);
	// v4 : SpaceShapeValue = op_spec_data.ass.all_space_shape_values[4];
	// AssertEquals(r1.shape_id, v4.shape_id);
	// AssertFloat64Equals(s2_ssv_3.float_value, v4.float_value);


} @ITest

//TODO FROM HERE Make a separate render group for this
//Then start on op_space rows with render group in all_render_groups
//but we need to update code for op_space and also allow adjustable x in op_space
//We need separate code because it will likely be very different long term
//can leave a note that we need to transfer code over if needed though.
Test_MusicRows :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusic(perm.all_data);

	rows : [2] CreateRowData;
	// rows[0].tuning_system_type = .EQUAL_TEMPERAMENT;
	// rows[0].tuning_system_count = 12;
	//Note : This is set by default
	//TODO This should set the original octave height and then we can set row_height after.
	//Should we allow being able to set from point size for equal note linear spaces?
	//Should be able to just set the row_height independently.
	rows[0].octave_height = 12;
	rows[0].row_height = 19;
	// rows[0].row_system_type = RowSystemType.midi_pitch;
	//TODO I don't think we need this anymore since octave and row height adjust everything now
	rows[0].music_lane_row_point_type = .float_based;
	rows[0].num_of_points = 12;
	rows[0].use_num_of_points = true;
	rows[0].row_section_data = RowSectionData.[
		MakeRowSectionData(perm.all_data.all_tuning_systems[13].id, 2),
		MakeRowSectionData(perm.all_data.all_tuning_systems[0].id, 2),
		MakeRowSectionData(perm.all_data.all_tuning_systems[1].id, 2),
		// MakeRowSectionData(perm.all_data.all_tuning_systems[1].id, 2),
		// MakeRowSectionData(perm.all_data.all_tuning_systems[2].id, 4),
		// MakeRowSectionData(perm.all_data.all_tuning_systems[1].id, 12, .FORCE_EQUAL)
		// MakeRowSectionData(perm.all_data.all_tuning_systems[0].id, 12)
	];

	// rows[1].tuning_system_type = .EQUAL_TEMPERAMENT;
	// rows[1].tuning_system_count = 12;
	rows[1].octave_height = 12;
	rows[1].row_height = 12;
	rows[1].music_lane_row_point_type = .float_based;
	rows[1].num_of_points = 12;
	rows[1].use_num_of_points = true;
	rows[1].row_section_data = RowSectionData.[
		MakeRowSectionData(perm.all_data.all_tuning_systems[0].id, 12),
		// MakeRowSectionData(perm.all_data.all_tuning_systems[2].id, 12, .FORCE_EQUAL)
		// MakeRowSectionData(perm.all_data.all_tuning_systems[1].id, 12)
	];

	for rows CreateMusicRow(it, perm.all_data);


	c1 := float64.[0,2];
	c2 := float64.[0,2];
	CreateManyMusicPtsInMemory(c1, 0, 0.5, 1.5, *perm.all_data.all_mspace_data[0].all_music_pts);
	CreateManyMusicPtsInMemory(c2, 0, 2, 4, *perm.all_data.all_mspace_data[0].all_music_pts);

	c3 := float64.[0,2];
	CreateManyMusicPtsInMemory(c3, 0, 4, 6, *perm.all_data.all_mspace_data[0].all_music_pts);

} @ITest

#if 0 {
//TODO We could also just set the memory directly instead
//and then don't have to worry about order either...
//This is a temporary way of generalizing some asm calls until
//we have working functions and imports in code.
//We can however use these to generalize putting asm muscalls
//for people that want to do raw asm. Although intrinsics will likely
//work better since we can easily add them to the code anyways.
ASM_SETUP_MUSIC :: inline (smd : SetupMusicData = .{}) -> string {
	return sprint(
#string DONE 
mov ax, scp;
//TODO Remove this once we remove OLDSetupMusic
push %; //row_size
//TODO Should these be push.f? It copies the mem_value so I don't think it's necessary.
push %; //memory_units_per_second
push %; //bpm
muscall %, [ax];
DONE,
smd.row_size, 
formatFloat(smd.memory_units_per_second,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
formatFloat(smd.bpm,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
cast(int) MusCallType.setup_music
,,context.allocator);
}
Test_AsmSetupMusic :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	setup_music_data := SetupMusicData.{bpm=90, memory_units_per_second=2.0};
	setup_music_address : int = PushRAMValue(setup_music_data, *perm.all_data.ram_memory);

	cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		muscall %, [%]; //setup_music
	}
}
DONE, 
cast(int) MusCallType.setup_music, setup_music_address
,,test_alloc)
,, test_alloc);

	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	//TODO We could run >= 2 frames if terminal events happen after some other events thats are needed.
	//Note : We accumulate the renderer_data so we need to clear every frame.
	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	AssertEquals(perm.all_data.global_rules.row_size, setup_music_data.row_size);
	//TODO I think I want to remove bpm here
	AssertFloat64Equals(perm.all_data.audio_timing.bpm, setup_music_data.bpm);
	AssertFloat64Equals(perm.all_data.game_audio_play.memory_units_per_second, setup_music_data.memory_units_per_second);
} @ITest
}

Test_AsmMusicRows :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusic(perm.all_data);

	et12 := RowSectionData.{0,0,6};
	et24 := RowSectionData.{0,1,6};
	asm_sections := RowSectionData.[et12, et24];
	asm_sections_count, asm_sections_address := PushRAMArray(asm_sections, *perm.all_data.ram_memory);

	asm_row : AsmCreateRowData;
	asm_row.octave_height = 12;
	asm_row.row_height = 12;
	asm_row.muted_row = ToAsmBool(false);
	asm_row.row_sections = .{asm_sections_count, asm_sections_address};
	asm_row.row_system_type = .internal_pitch;
	asm_row_address : int = PushRAMValue(asm_row, *perm.all_data.ram_memory);

	cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		create_row [%];
	}
}
DONE, 
asm_row_address,
,,test_alloc)
,, test_alloc);
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_good := AssertEquals(perm.all_data.all_mspace_data[0].all_music_lane_rows.count, 1);
	if count_good {
		row := perm.all_data.all_mspace_data[0].all_music_lane_rows[0];
		AssertFloatEquals(row.octave_height, cast(float) asm_row.octave_height);
		AssertFloatEquals(row.row_height, cast(float) asm_row.row_height);
		AssertEquals(row.is_muted_row, AsmBoolToBool(asm_row.muted_row));
		AssertEquals(row.row_system_type, asm_row.row_system_type);
	}

	count_good = AssertEquals(perm.all_data.all_mspace_data[0].all_section_to_row.count, 2);
	if count_good {
		s0 := perm.all_data.all_mspace_data[0].all_section_to_row[0];
		AssertEquals(s0.tuning_system_id, et12.tuning_system_id);
		AssertEquals(s0.end_x - s0.start_x, et12.x_length);
		s1 := perm.all_data.all_mspace_data[0].all_section_to_row[1];
		AssertEquals(s1.tuning_system_id, et24.tuning_system_id);
		AssertEquals(s1.end_x - s1.start_x, et24.x_length);
	}

} @ITest

//TODO In code we could just muscall directly with the memory value of the passed in row cause its already on the function stack
ASM_OP_ROW :: inline (row : AsmOpRowData, row_sections : [] RowSectionData) -> string {
	sb : String_Builder;
	append(*sb, "mov ax, scp;\n");
	for section : row_sections {
		print_to_builder(*sb,
#string DONE 
push %; //linear_view
push %; //tuning_system_id
push %; //x_length
DONE,
cast(int) section.linear_view,
section.tuning_system_id,
section.x_length,
,,context.allocator);
	}

	print_to_builder(*sb,
#string DONE 
mov bx, scp;
push %; //octave_height
push %; //row_height
push ax; //row_section_memory_index
push %; //row_section_count
push %; //sound_on (bool represented as int)
push %; //row_system_type
push %; //op_space_id
push %; //x_point_width
push %; //is_music_row_copy
push %; //x_op_pos
push %; //y_op_pos
muscall %, [bx];
DONE,
formatFloat(row.octave_height, zero_removal=.ONE_ZERO_AFTER_DECIMAL),
formatFloat(row.row_height,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
row_sections.count,
row.sound_on,
cast(int) row.row_system_type,
row.op_space_id,
formatFloat(row.x_point_width,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
row.is_music_row_copy,
row.x_op_pos,
row.y_op_pos,
cast(int) MusCallType.create_op_row
,,context.allocator);

	return builder_to_string(*sb,,context.allocator);
}
ASM_MAP_LINEAR :: inline (ld : MapLinearData) -> string {
	return sprint(
#string DONE 
mov ax, scp;
push [%]; //dspace_id
push %; //row_index
push %; //x_index
push %; //op_x_row_pos
push %; //map_linear_type
push %; //x_end_index
muscall %, [ax];
DONE,
ld.dspace_id, 
ld.row_index, 
formatFloat(ld.x_index,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
formatFloat(ld.op_x_row_pos,zero_removal=.ONE_ZERO_AFTER_DECIMAL), 
cast(int) ld.map_linear_type, 
formatFloat(ld.x_end_index,zero_removal=.ONE_ZERO_AFTER_DECIMAL),
cast(int) MusCallType.map_linear
,,context.allocator);
}
DEFAULT_RAM_DATA : int = 100;
Test_AsmOpRows :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);
	CreateManyMusicPtsInMemory(float64.[0,4,7], 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);

	section_ram_loc : int = DEFAULT_RAM_DATA + size_of(AsmOpRowData);
	et12 := RowSectionData.{0,0,6};
	et24 := RowSectionData.{0,1,6};
	asm_sections := RowSectionData.[et12, et24];
	for asm_sections {
		SetRAMValue(section_ram_loc+it_index*size_of(RowSectionData), 
			it, *perm.all_data.ram_memory);
	}

	//TODO I think storing this directly in memory is more worth it here
	asm_row : AsmOpRowData;
	asm_row.octave_height = 12;
	asm_row.row_height = 12;
	asm_row.op_space_id = 0;
	asm_row.x_point_width = 1.75;
	asm_row.is_music_row_copy = cast(int) 0;
	asm_row.x_op_pos = 0;
	asm_row.y_op_pos = 0;
	asm_row.row_section_memory_index = section_ram_loc;
	asm_row.row_section_count = asm_sections.count;
	// asm_music_rows := ASM_OP_ROW(asm_row, asm_sections,, test_alloc);
	//Maybe we pull this out and can set it so we only have to change in 1 place
	//later if default base value changes everywhere.
	//TODO Need to change this if we add default
	SetRAMValue(DEFAULT_RAM_DATA, asm_row, *perm.all_data.ram_memory);

	map_linear : MapLinearData;
	//This will fetch the dspace from memory here
	map_linear.dspace_id = DEFAULT_RAM_DATA;
	map_linear.row_index = 0;
	map_linear.x_index = 0;
	map_linear.op_x_row_pos = 0;
	//We can't do this because we need to get the dspace_id from creating the op_linear_row
	// ram_map_linear : int = section_ram_loc + asm_sections.count * size_of(RowSectionData);
	// SetRAMValue(ram_map_linear, map_linear, *perm.all_data.ram_memory);

	cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		% //create_space
		muscall %, [%]; //create_op_linear
		% //map_linear
	}
}
DONE, 
ASM_CREATE_SPACE(,,test_alloc), 
cast(int) MusCallType.create_op_row,
DEFAULT_RAM_DATA,
ASM_MAP_LINEAR(map_linear,,test_alloc)
,, test_alloc)
,, test_alloc);
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_good := AssertEquals(perm.all_data.all_op_linear_rows.count, 1);
	if count_good {
		row := perm.all_data.all_op_linear_rows[0];
		AssertFloatEquals(cast(float) asm_row.octave_height, row.octave_height);
		AssertFloatEquals(cast(float) asm_row.row_height, row.row_height);
		AssertEquals(cast(bool) asm_row.sound_on, row.is_muted_row);
		AssertEquals(asm_row.row_system_type, row.row_system_type);
		AssertEquals(OpRowType.MULTI_SECTION, row.op_row_type);
	}	

	count_good = AssertEquals(perm.all_data.all_op_section_to_row.count, 2);
	if count_good {
		s0 := perm.all_data.all_op_section_to_row[0];
		AssertEquals(et12.tuning_system_id, s0.tuning_system_id);
		AssertEquals(et12.x_length, s0.end_x - s0.start_x);
		s1 := perm.all_data.all_op_section_to_row[1];
		AssertEquals(et24.tuning_system_id, s1.tuning_system_id);
		AssertEquals(et24.x_length, s1.end_x - s1.start_x);
	}

} @ITest

Test_AsmOpLinearRange :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);
	CreateManyMusicPtsInMemory(float64.[0,4,7], 0, 1, 2, *perm.all_data.all_mspace_data[0].all_music_pts);
	CreateManyMusicPtsInMemory(float64.[0,3,7], 0, 7.5, 8.5, *perm.all_data.all_mspace_data[0].all_music_pts);

	section_ram_loc : int = DEFAULT_RAM_DATA + size_of(AsmOpRowData);
	et12 := RowSectionData.{0,0,6};
	et24 := RowSectionData.{0,1,6};
	asm_sections := RowSectionData.[et12, et24];
	for asm_sections {
		SetRAMValue(section_ram_loc+it_index*size_of(RowSectionData), 
			it, *perm.all_data.ram_memory);
	}

	asm_row : AsmOpRowData;
	asm_row.octave_height = 12;
	asm_row.row_height = 12;
	asm_row.op_space_id = 0;
	asm_row.x_point_width = 1.75;
	asm_row.is_music_row_copy = cast(int) 0;
	asm_row.x_op_pos = 0;
	asm_row.y_op_pos = 0;
	asm_row.row_section_memory_index = section_ram_loc;
	asm_row.row_section_count = asm_sections.count;
	SetRAMValue(DEFAULT_RAM_DATA, asm_row, *perm.all_data.ram_memory);

	//TODO Should write a test case for each way.
	map_linear : MapLinearData;
	//This will fetch the dspace_id from memory here
	map_linear.dspace_id = DEFAULT_RAM_DATA;
	map_linear.row_index = 0;
	map_linear.x_index = 1;
	map_linear.op_x_row_pos = 5;
	map_linear.map_linear_type = MapLinearType.RANGE;
	map_linear.x_end_index = 8;


	cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		% //create_space
		muscall %, [%]; //create_op_linear
		% //map_linear range
	}
}
DONE, 
ASM_CREATE_SPACE(,,test_alloc), 
cast(int) MusCallType.create_op_row,
DEFAULT_RAM_DATA,
ASM_MAP_LINEAR(map_linear,,test_alloc)
,, test_alloc)
,, test_alloc);
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_good := AssertEquals(1, perm.all_data.all_memory_range_to_dspace.count);

	#if 0 {
	count_good = AssertEquals(perm.all_data.all_op_section_to_row.count, 2);
	if count_good {
		s0 := perm.all_data.all_op_section_to_row[0];
		AssertEquals(et12.tuning_system_id, s0.tuning_system_id);
		AssertEquals(et12.x_length, s0.end_x - s0.start_x);
		s1 := perm.all_data.all_op_section_to_row[1];
		AssertEquals(et24.tuning_system_id, s1.tuning_system_id);
		AssertEquals(et24.x_length, s1.end_x - s1.start_x);
	}
	}
} @ITest

Test_AsmOpCopyRow :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);
	CreateManyMusicPtsInMemory(float64.[0,4,7], 1, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);
	CreateManyMusicPtsInMemory(float64.[0,3,7,10], 1, 2.5, 4.25, *perm.all_data.all_mspace_data[0].all_music_pts);

	asm_row : AsmOpRowData;
	asm_row.octave_height = 12;
	asm_row.row_height = 12;
	asm_row.op_space_id = 0;
	asm_row.x_point_width = 1.75;
	asm_row.is_music_row_copy = cast(int) true;
	asm_row.copy_music_row_id = perm.all_data.all_mspace_data[0].all_music_lane_rows[1].id;
	SetRAMValue(DEFAULT_RAM_DATA, asm_row, *perm.all_data.ram_memory);

	cd : *CompilationData = CompileCode(.{},
sprint(
#string DONE
main :: () {
	#asm {
		% //create_space
		muscall %, [%]; //create_op_linear
	}
}
DONE, 
ASM_CREATE_SPACE(,,test_alloc), 
cast(int) MusCallType.create_op_row,
DEFAULT_RAM_DATA
,, test_alloc)
,, test_alloc);
	//TODO Do this more efficiently with a memcpy
	ArrayAddAll(cd.all_music_instructions, *perm.all_data.all_music_instructions);
	array_add(*perm.all_data.all_process_instruction_events, ProcessInstructionEvent.{});

	RunFrames(2, game_memory, renderer_data, audio_data, game_input);

	count_good := AssertEquals(1, perm.all_data.all_op_linear_rows.count);
	if count_good {
		row := perm.all_data.all_op_linear_rows[0];
		AssertFloatEquals(cast(float) asm_row.octave_height, row.octave_height);
		AssertFloatEquals(cast(float) asm_row.row_height, row.row_height);
		AssertFloatEquals(cast(float) asm_row.x_point_width, row.x_point_width);
		AssertEquals(OpRowType.COPY_MUSIC_ROW, row.op_row_type);
		AssertEquals(perm.all_data.all_mspace_data[0].all_music_lane_rows[1].id, row.copy_music_row_id);
		AssertEquals(perm.all_data.all_mspace_data[0].all_music_lane_rows[1].total_row_index, row.total_row_index);
	}	

	AssertEquals(0, perm.all_data.all_op_section_to_row.count);

} @ITest

Test_OpLinearRow :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);

	cosd : CreateOpSpaceData;
	cosd.op_space_external_type = OpSpaceExternalType.space_2d;
	cosd.op_space_name = "test";
	op_space : OperationSpace = CreateClosedOpSpace(cosd,
		*perm.all_data.all_closed_op_spaces, 
		*perm.all_data.all_op_space_spec_data, 
		*perm.all_data.all_op_spec_data_3D);

	rows : [1] CreateRowData;
	rows[0].octave_height = 12;
	rows[0].row_height = 19;
	rows[0].op_world_pos = Vector2F.{0,0};
	// rows[0].x_point_width = perm.all_data.global_rules.memory_unit_width;
	rows[0].x_point_width = 1.75;
	// rows[0].op_row_type = OpRowType.COPY_MUSIC_ROW;
	rows[0].copy_music_row_id = perm.all_data.all_mspace_data[0].all_music_lane_rows[0].id;
	rows[0].row_section_data = RowSectionData.[
		MakeRowSectionData(perm.all_data.all_tuning_systems[13].id, 2),
		MakeRowSectionData(perm.all_data.all_tuning_systems[0].id, 2),
		MakeRowSectionData(perm.all_data.all_tuning_systems[1].id, 2),
		// MakeRowSectionData(perm.all_data.all_tuning_systems[1].id, 2),
		// MakeRowSectionData(perm.all_data.all_tuning_systems[2].id, 4),
		// MakeRowSectionData(perm.all_data.all_tuning_systems[1].id, 12, .FORCE_EQUAL)
		// MakeRowSectionData(perm.all_data.all_tuning_systems[0].id, 12)
	];

	#if 0 {
	// rows[1].tuning_system_type = .EQUAL_TEMPERAMENT;
	// rows[1].tuning_system_count = 12;
	rows[1].octave_height = 12;
	rows[1].row_height = 12;
	rows[1].music_lane_row_point_type = .float_based;
	rows[1].num_of_points = 12;
	rows[1].use_num_of_points = true;
	rows[1].row_section_data = RowSectionData.[
		MakeRowSectionData(perm.all_data.all_tuning_systems[0].id, 12),
		// MakeRowSectionData(perm.all_data.all_tuning_systems[2].id, 12, .FORCE_EQUAL)
		// MakeRowSectionData(perm.all_data.all_tuning_systems[1].id, 12)
	];
	}

	for rows {
		row : MusicLaneRow = CreateOpLinearRow(it, perm.all_data);

		//TODO I think we should put this in the above so it remains consistent everywhere.
		dspace_to_op : *DSpaceToOpSpaceIndex = array_add(*perm.all_data.all_dspace_to_op_space_id);
		dspace_to_op.dspace_id = row.id;
		dspace_to_op.op_dspace_type = OpDSpaceType.LINEAR;
		dspace_to_op.op_space_id = op_space.id;
	}

	c1 := float64.[0,2];
	c2 := float64.[0,2];
	CreateManyMusicPtsInMemory(c1, 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);
	// CreateManyMusicPtsInMemory(c2, 0, 2, 4, *perm.all_data.all_mspace_data[0].all_music_pts);

	// c3 := float64.[0,2];
	// CreateManyMusicPtsInMemory(c3, 0, 4, 6, *perm.all_data.all_mspace_data[0].all_music_pts);

	mem_to_dspace : *MemoryUnitToDSpace = array_add(*perm.all_data.all_memory_unit_to_dspace);
	mem_to_dspace.x_index = 0;
	mem_to_dspace.row_index = 0;
	mem_to_dspace.op_dspace_type = OpDSpaceType.LINEAR;
	mem_to_dspace.dspace_id = perm.all_data.all_op_linear_rows[0].id;
	mem_to_dspace.x_grid_pos = 2;

} @ITest

//TODO MAYBE WE CAN REMOVE THIS TEST now since I don't think we use it anymore...
//and we copied the code and tested it in other integration tests now...
//TOdO Maybe we can use it just to open a blank text file... and then rename it
Test_AsmDebug :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	//TODO Use InitAllData here once we remove this
	perm.all_data = InitAllData();
	ResetAllRendererData(renderer_data);

	SetupMusicAndRows(perm.all_data, TWO_ROWS);

	//TODO Should we just create generally in here? I guess this makes things consistent across tests.
	text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
#if 0 {
	WriteFileString(*perm.all_data.all_text_files[0],
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  x : int = 1;
  x = x + 1;
}
DONE);	
} else {
	WriteFileString(*perm.all_data.all_text_files[0],
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () { #asm {
  mov ax, 1;
  mov <0,0>, 0;
  mov.f <0,0>, 4.5;
  mov <0,0>, 7;
  mov.f [0], 10.5;




  mov <0,0>, 4;
  mov <0,0>, 7;











  mov <0,0>, 4;
  mov <0,0>, 7;

  add <0,0>, 2;
}}
DONE);
// main :: () { #asm {
//   mov <0,0>, 0;mov <0,0>, 0;mov <0,0>, 0;mov <0,0>, 0;mov <0,0>, 0;
//   mov <0,0>, 4;
//   mov <0,0>, 7;
// }}
}

	CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

	/*TODO CAN WRITE SOME TEST HERE.
	ULTIMATELY We would want to check render objects before resetting
	the render groups so we can make sure everything was created properly.
	This would be the best and most consistent test but likely better to do
	once the ui for debug and text is more finalized.
	*/

} @ITest

Test_textbp :: (
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
#if 0 {
		WriteFileString(*perm.all_data.all_text_files[0],
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  x : int = 1;
  x = x + 1;
}
DONE);	
} else {
		WriteFileString(*perm.all_data.all_text_files[0],
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () { #asm {
  mov ax, 1;
  mov <0,0>, 0;
  mov.f <0,0>, 4.5;
  mov <0,0>, 7;
  mov.f [0], 10.5;




  mov <0,0>, 4;
  mov <0,0>, 7;











  mov <0,0>, 4;
  mov <0,0>, 7;

  add <0,0>, 2;
}}
DONE);
// main :: () { #asm {
//   mov <0,0>, 0;mov <0,0>, 0;mov <0,0>, 0;mov <0,0>, 0;mov <0,0>, 0;
//   mov <0,0>, 4;
//   mov <0,0>, 7;
// }}
}
		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 9);

		//TODO We could set this in the test actions below but I think this is clearer and also
		//we have to set wait here to know how much to wait before the test runs.
		// perm.test_data.all_sub_tests[2] = SubT(10,frame_wait_override=5);
		perm.test_data.all_sub_tests[4] = SubT(10);

		//TODO REMINDER if we want to SubTest to just run a few frames, we would just put how many
		//frames we want to run as the repeat_count and have the test be an empty function.
		//So if we want the test to run more slowly we could just check a timer and keep running frames
		//This is just an easier way to slow down an entire test instead of putting specific waiting in between.
		//This also waits in between repeats of a test action if needed.
		// perm.test_data.default_frame_wait = 2;
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	} 
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 3; DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	case 4; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 5; DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	case 6; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 7; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 8; {
		text_op : TextOpSpaceData = perm.all_data.all_text_op_space_data[0];
		ei : ExecutionInfo = text_op.exec_info;

		//TODO Could get this based on chosen op space. But in case we change that later
		AssertEquals(ei.exec_state, .IS_DEBUG_STOP);
		count_equal := AssertEquals(2, ei.debug_info.break_points.count);
		if count_equal {
			AssertEquals(ei.debug_info.break_points[0].asm_index, perm.all_data.all_register_memory[RegDef.ir].int_value);
			stop_d_line := GetDebugLineAsm(perm.all_data.all_register_memory[RegDef.ir].int_value, text_op.text_comp_data);
			AssertEquals(ei.debug_info.break_points[0].line_number, stop_d_line.line_number);

			AssertEquals(6, ei.debug_info.break_points[1].asm_index);
			AssertEquals(11, ei.debug_info.break_points[1].line_number);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TextWatch :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  x : int = 1;
  x = x + 1;
  //TODO Should check another variable here for non-0 ram location
  z : int;
}
DONE,,test_alloc);	

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 20);
		// perm.test_data.default_frame_wait = 20;
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;
	
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	} 
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);	
	//TODO Could use MoveToLine(11) since that might be clearer in this case.
	case 2; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 3; DownUpThisFrame(.ARROW_DOWN, game_input);
	//Set breakpoint on line 2
	case 4; DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	case 5; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 6; AddTextInput("x", game_input);
	//TODO Could use MoveToLine - would need the text_file for string and cursor
	case 7; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 8; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 9; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 10; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);

			AssertEquals("x", wd.name);
			AssertEquals("1", wd.value_str);
			//TODO We could call TypeToString here and test that separately
			AssertEquals("int", wd.type_str);
		}
	} 
	case 11; AddTextInput("y", game_input);
	//TODO Could use MoveToLine - would need the text_file for string and cursor
	case 12; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 13; AddTextInput("ax", game_input);
	// TODO Could use MoveToLine - would need the text_file for string and cursor
	case 14; DownUpThisFrame(.ARROW_UP, game_input);
	case 15; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[1];
			AssertEquals(true, wd.is_error);

			wd = text_op.watch_data_rows[2];
			AssertEquals(false, wd.is_error);
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.REGISTER, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.ax, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.NONE, wd.node.code_ir.op.values[1].type);
			AssertEquals("ax", wd.name);
			AssertEquals("0", wd.value_str);
			//TODO We could call TypeToString here and test that separately
			AssertEquals("int", wd.type_str);

			wd = text_op.watch_data_rows[3];
			AssertEquals(false, wd.is_error);
			AssertEquals(0, wd.watch_pool.used);
			AssertEquals(0, wd.name.count);
			AssertEquals(true, wd.node == null);
		}


		DownUpThisFrame(.DELETE, game_input);
	} 
	case 16; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(1, text_op.watch_data_pool.count);
		count_equal := AssertEquals(3, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[1];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.REGISTER, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.ax, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.NONE, wd.node.code_ir.op.values[1].type);

			AssertEquals("ax", wd.name);
			AssertEquals("0", wd.value_str);
			//TODO We could call TypeToString here and test that separately
			AssertEquals("int", wd.type_str);

			wd = text_op.watch_data_rows[2];
			AssertEquals(0, wd.name.count);
			AssertEquals(0, wd.watch_pool.used);
			AssertEquals(true, wd.node == null);
		}		

		DownUpThisFrame(.ARROW_DOWN, game_input);
	} 
	case 17; AddTextInput("bx", game_input);
	case 18; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 19; {
		//We add back a value to make sure the pool worked
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		AssertEquals(4, text_op.watch_data_rows.count);


		AddWatchDataForTest(.["*x", "ram(ax)", "ram(ax+8)", "*(ram(ax + 8))", "*(ram(x))"], text_op);
		for 0..text_op.watch_data_rows.count-2 {
			EvaluateWatchData(it, text_op, perm.all_data, true);
		}

		count_equal := AssertEquals(9, text_op.watch_data_rows.count);
		if count_equal {
			px : WatchData = text_op.watch_data_rows[3];
			AssertEquals("0", px.value_str);
			AssertEquals("*int", px.type_str);

			ram_ax : WatchData = text_op.watch_data_rows[4];
			AssertEquals("1", ram_ax.value_str);
			AssertEquals("int", ram_ax.type_str);

			ram_ax_8 : WatchData = text_op.watch_data_rows[5];
			AssertEquals("0", ram_ax_8.value_str);
			AssertEquals("int", ram_ax_8.type_str);

			pram_ax_8 : WatchData = text_op.watch_data_rows[6];
			AssertEquals("8", pram_ax_8.value_str);
			AssertEquals("*int", pram_ax_8.type_str);

			pram_x : WatchData = text_op.watch_data_rows[7];
			AssertEquals("1", pram_x.value_str);
			AssertEquals("*int", pram_x.type_str);
		}
	}
	}

	// ContinueTest(game_memory, renderer_data, audio_data, game_input);
	ContinueTest(*perm.test_data);

} @ITest

//TODO FROM HERE do tano-neume and struct and then do add and remove many with memcpy and check with tests
//and then start on debug with functions
Test_WatchArray :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  a := int.[1,2];
  a2 : [] int = a;
  a2[1] = 4;
}
DONE,,test_alloc);	

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 21);
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
		AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; AddTextInput("a", game_input);
	//TODO Could use MoveToLine - would need the text_file for string and cursor
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ARROW_UP, game_input);
	case 8; DownUpThisFrame(.ENTER, game_input);
	case 9; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//array count (2) + a var (1) + empty bottom row (1)
		neume_ti := type_info(Neume);
		count_equal := AssertEquals(2 + 2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.ARRAY, wd.node.code_ir.t_info.type_enum);
			AssertEquals(ArrayInfoType.FIXED, (cast(*TypeInfoArray) wd.node.code_ir.t_info).array_type);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("a", wd.name);
			AssertEquals("a", wd.display_name);
			//TODO Leaving this out for now in case this changes
			// AssertEquals("dropdown(struct)", wd.value_str);
			AssertEquals("[2] int", wd.type_str);
			AssertEquals(0, wd.watch_indent);

			wd_0 := text_op.watch_data_rows[1];
			AssertEquals(true, wd_0.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_0.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_0.node.code_ir.op.operand_type);
			//NOTE : We store the address here directly for debugging.
			AssertEquals(OperandValueType.INTEGER, wd_0.node.code_ir.op.values[0].type);
			AssertEquals(0, wd_0.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.NONE, wd_0.node.code_ir.op.values[1].type);
			AssertEquals("a[0]", wd_0.name);
			AssertEquals("[0]", wd_0.display_name);
			AssertEquals("1", wd_0.value_str);
			AssertEquals("int", wd_0.type_str);
			AssertEquals(1, wd_0.watch_indent);

			wd_1 := text_op.watch_data_rows[2];
			AssertEquals(true, wd_1.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_1.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_1.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.INTEGER, wd_1.node.code_ir.op.values[0].type);
			AssertEquals(8, wd_1.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.NONE, wd_1.node.code_ir.op.values[1].type);
			AssertEquals("a[1]", wd_1.name);
			AssertEquals("[1]", wd_1.display_name);
			AssertEquals("2", wd_1.value_str);
			AssertEquals("int", wd_1.type_str);
			AssertEquals(1, wd_1.watch_indent);

			wd_last := text_op.watch_data_rows[3];
			AssertEquals(true, wd_last.node == null);
			AssertEquals(0, wd_last.name.count);
			AssertEquals(0, wd_last.display_name.count);
			AssertEquals(0, wd_last.value_str.count);
			AssertEquals(0, wd_last.type_str.count);
			AssertEquals(0, wd_last.watch_indent);
		}


		DownUpThisFrame(.ENTER, game_input);	
		// DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 10; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, text_op.watch_data_pool.count);
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.ARRAY, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("a", wd.name);
			AssertEquals("a", wd.display_name);
			// AssertEquals("", wd.value_str);
			AssertEquals("[2] int", wd.type_str);
			AssertEquals(0, wd.watch_indent);

			wd_empty := text_op.watch_data_rows[1];
			AssertEquals(true, wd_empty.node == null);
			AssertEquals(0, wd_empty.name.count);
		}


		DownUpThisFrame(.ARROW_DOWN, game_input);	
	} 
	case 11; AddTextInput("a2", game_input);
	case 12; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 13; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(1, text_op.watch_data_pool.count);
		//a2_count(2) + a(1) + a2(1) + empty(1) 
 		count_equal := AssertEquals(3, text_op.watch_data_rows.count);
 		if count_equal {
			wd_a := text_op.watch_data_rows[0];
			AssertEquals(true, wd_a.node != null);

			wd_a2 := text_op.watch_data_rows[1];
			AssertEquals(true, wd_a2.node != null);
			AssertEquals("a2", wd_a2.name);
			AssertEquals("[] int", wd_a2.type_str);
			AssertEquals(0, wd_a2.watch_indent);
		}

		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 14; {
		//Test open a2 array
		DownUpThisFrame(.ENTER, game_input);	
	}
	case 15; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//a2_count(2) + a(1) + a2(1) + empty(1) 
 		count_equal := AssertEquals(2+3, text_op.watch_data_rows.count);
 		if count_equal {
			wd_a := text_op.watch_data_rows[0];
			AssertEquals(true, wd_a.node != null);

			wd_a2 := text_op.watch_data_rows[1];
			AssertEquals(true, wd_a2.node != null);
			AssertEquals(TypeInfoTag.ARRAY, wd_a2.node.code_ir.t_info.type_enum);
			AssertEquals(ArrayInfoType.VIEW, (cast(*TypeInfoArray) wd_a2.node.code_ir.t_info).array_type);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_a2.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_a2.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_a2.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_a2.node.code_ir.op.values[1].type);
			AssertEquals(16, wd_a2.node.code_ir.op.values[1].int_value);
			AssertEquals("a2", wd_a2.name);
			AssertEquals("a2", wd_a2.display_name);
			// AssertEquals("", wd_a2.value_str);
			AssertEquals("[] int", wd_a2.type_str);
			AssertEquals(0, wd_a2.watch_indent);

			wd_a2_0 := text_op.watch_data_rows[2];
			AssertEquals(true, wd_a2_0.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_a2_0.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_a2_0.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.INTEGER, wd_a2_0.node.code_ir.op.values[0].type);
			AssertEquals(0, wd_a2_0.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.NONE, wd_a2_0.node.code_ir.op.values[1].type);
			AssertEquals("a2[0]", wd_a2_0.name);
			AssertEquals("[0]", wd_a2_0.display_name);
			AssertEquals("1", wd_a2_0.value_str);
			AssertEquals("int", wd_a2_0.type_str);
			AssertEquals(1, wd_a2_0.watch_indent);

			wd_a2_1 := text_op.watch_data_rows[3];
			AssertEquals(true, wd_a2_1.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_a2_1.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_a2_1.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.INTEGER, wd_a2_1.node.code_ir.op.values[0].type);
			AssertEquals(8, wd_a2_1.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.NONE, wd_a2_1.node.code_ir.op.values[1].type);
			AssertEquals("a2[1]", wd_a2_1.name);
			AssertEquals("[1]", wd_a2_1.display_name);
			AssertEquals("2", wd_a2_1.value_str);
			AssertEquals("int", wd_a2_1.type_str);
			AssertEquals(1, wd_a2_1.watch_indent);
		}	


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	} 
	case 16; DownUpThisFrame(.ARROW_UP, game_input);
	case 17; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//a2_count(2) + a(1) + a2(1) + empty(1) 
 		count_equal := AssertEquals(2+3, text_op.watch_data_rows.count);
 		if count_equal {
			wd_a := text_op.watch_data_rows[0];
			AssertEquals(true, wd_a.node != null);

			wd_a2_1 := text_op.watch_data_rows[3];
			AssertEquals(true, wd_a2_1.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_a2_1.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_a2_1.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.INTEGER, wd_a2_1.node.code_ir.op.values[0].type);
			AssertEquals(8, wd_a2_1.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.NONE, wd_a2_1.node.code_ir.op.values[1].type);
			AssertEquals("a2[1]", wd_a2_1.name);
			AssertEquals("[1]", wd_a2_1.display_name);
			AssertEquals("4", wd_a2_1.value_str);
			AssertEquals("int", wd_a2_1.type_str);
			AssertEquals(1, wd_a2_1.watch_indent);
		}

		//Test open dropdown above
		DownUpThisFrame(.ENTER, game_input);
	}
	case 18; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//a2_count(2) + a(1) + a2(1) + empty(1) 
 		count_equal := AssertEquals(4+3, text_op.watch_data_rows.count);

		DownUpThisFrame(.DELETE, game_input);
	} 
	case 19; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(3, text_op.watch_data_pool.count);
		//a2_count(2) + a2(1) + empty(1) 
 		count_equal := AssertEquals(3+1, text_op.watch_data_rows.count);
		if count_equal {
			wd_a2 := text_op.watch_data_rows[0];
			AssertEquals(true, wd_a2.node != null);
			AssertEquals("a2", wd_a2.name);

			wd_a2_0 := text_op.watch_data_rows[1];
			AssertEquals(true, wd_a2_0.node != null);
			AssertEquals("a2[0]", wd_a2_0.name);
		}

		//Test close so we should only have var and empty row left
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	}
	case 20; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(5, text_op.watch_data_pool.count);
		//empty(1) 
 		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		if count_equal {
			wd_a2 := text_op.watch_data_rows[0];
			AssertEquals(true, wd_a2.node != null);
			AssertEquals("a2", wd_a2.name);

			wd_empty := text_op.watch_data_rows[1];
			AssertEquals(true, wd_empty.node == null);
			AssertEquals(0, wd_empty.name.count);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_WatchEnum :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
Test :: enum {
  test_0;
  test_1;
  test_2;
}
main :: () {
  t : Test;
  t = Test.test_1;
  t2 := T2.test_1;
  t3 := t2;

  //TEST casting enums
  i := cast(int) t2;
  e := cast(T2) -10;
  //NOTE : Technically this works since an enum is just an int at runtime.
  //But it is out of bounds of the enum names/values itself.
  e2 := cast(Test) 3;
}
T2 :: enum {
  test_0 :: 1;
  test_1 :: -10;
  test_2 :: 24;
}
DONE,,test_alloc);	

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 24);
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
		AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		CodeBPForTest(7, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; AddTextInput("t", game_input);
	//TODO Could use MoveToLine - would need the text_file for string and cursor
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//t var (1) + empty bottom row (1)
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.ENUM, wd.node.code_ir.t_info.type_enum);
			AssertEquals("Test", (cast(*TypeInfoEnum) wd.node.code_ir.t_info).name);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("t", wd.name);
			AssertEquals("t", wd.display_name);
			AssertEquals("test_0 (0)", wd.value_str);
			AssertEquals("Test", wd.type_str);
			AssertEquals(0, wd.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 8; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//t var (1) + empty bottom row (1)
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.ENUM, wd.node.code_ir.t_info.type_enum);
			AssertEquals("Test", (cast(*TypeInfoEnum) wd.node.code_ir.t_info).name);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("t", wd.name);
			AssertEquals("t", wd.display_name);
			AssertEquals("test_1 (1)", wd.value_str);
			AssertEquals("Test", wd.type_str);
			AssertEquals(0, wd.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 9; AddTextInput("t2", game_input);
	case 10; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 11; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//t var (1) + empty bottom row (1)
		count_equal := AssertEquals(3, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[1];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.ENUM, wd.node.code_ir.t_info.type_enum);
			AssertEquals("T2", (cast(*TypeInfoEnum) wd.node.code_ir.t_info).name);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(8, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("t2", wd.name);
			AssertEquals("t2", wd.display_name);
			AssertEquals("test_1 (-10)", wd.value_str);
			AssertEquals("T2", wd.type_str);
			AssertEquals(0, wd.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 12; AddTextInput("t3", game_input);
	case 13; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 14; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//t var (1) + empty bottom row (1)
		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[2];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.ENUM, wd.node.code_ir.t_info.type_enum);
			AssertEquals("T2", (cast(*TypeInfoEnum) wd.node.code_ir.t_info).name);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(16, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("t3", wd.name);
			AssertEquals("t3", wd.display_name);
			AssertEquals("test_1 (-10)", wd.value_str);
			AssertEquals("T2", wd.type_str);
			AssertEquals(0, wd.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 15; AddTextInput("i", game_input);
	case 16; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 17; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//t var (1) + empty bottom row (1)
		count_equal := AssertEquals(5, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[3];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(24, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("i", wd.name);
			AssertEquals("i", wd.display_name);
			AssertEquals("-10", wd.value_str);
			AssertEquals("int", wd.type_str);
			AssertEquals(0, wd.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 18; AddTextInput("e", game_input);
	case 19; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 20; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//t var (1) + empty bottom row (1)
		count_equal := AssertEquals(6, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[4];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.ENUM, wd.node.code_ir.t_info.type_enum);
			AssertEquals("T2", (cast(*TypeInfoEnum) wd.node.code_ir.t_info).name);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(32, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("e", wd.name);
			AssertEquals("e", wd.display_name);
			AssertEquals("test_1 (-10)", wd.value_str);
			AssertEquals("T2", wd.type_str);
			AssertEquals(0, wd.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 21; AddTextInput("e2", game_input);
	case 22; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 23; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//t var (1) + empty bottom row (1)
		count_equal := AssertEquals(7, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[5];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.ENUM, wd.node.code_ir.t_info.type_enum);
			AssertEquals("Test", (cast(*TypeInfoEnum) wd.node.code_ir.t_info).name);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(40, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("e2", wd.name);
			AssertEquals("e2", wd.display_name);
			AssertEquals("3 (enum out of range)", wd.value_str);
			AssertEquals("Test", wd.type_str);
			AssertEquals(0, wd.watch_indent);
		}


		// DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_WatchNeume :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  n : neume;
  n.svara = 1.;
  n.x_end = 1.5;
}
DONE,,test_alloc);	

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 25);
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
		AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; AddTextInput("n", game_input);
	//TODO Could use MoveToLine - would need the text_file for string and cursor
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ARROW_UP, game_input);
	case 8; DownUpThisFrame(.ENTER, game_input);
	case 9; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//Neume members (4) + top var row (1) + empty bottom row (1)
		neume_ti := type_info(Neume);
		count_equal := AssertEquals(neume_ti.members.count + 2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.NEUME, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("n", wd.name);
			AssertEquals("n", wd.display_name);
			//TODO Leaving this out for now in case this changes
			// AssertEquals("dropdown(struct)", wd.value_str);
			AssertEquals("neume", wd.type_str);
			AssertEquals(0, wd.watch_indent);

			wd_svara := text_op.watch_data_rows[1];
			AssertEquals(true, wd_svara.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_svara.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_svara.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_svara.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_svara.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_svara.node.code_ir.op.values[1].type);
			AssertEquals(neume_ti.members[0].offset_in_bytes, wd_svara.node.code_ir.op.values[1].int_value);
			AssertEquals("n.svara", wd_svara.name);
			AssertEquals("svara", wd_svara.display_name);
			AssertEquals("0", wd_svara.value_str);
			AssertEquals("float", wd_svara.type_str);
			AssertEquals(1, wd_svara.watch_indent);

			wd_row := text_op.watch_data_rows[2];
			AssertEquals(true, wd_row.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_row.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_row.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_row.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_row.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_row.node.code_ir.op.values[1].type);
			AssertEquals(neume_ti.members[1].offset_in_bytes, wd_row.node.code_ir.op.values[1].int_value);
			AssertEquals("n.row", wd_row.name);
			AssertEquals("row", wd_row.display_name);
			AssertEquals("0", wd_row.value_str);
			AssertEquals("int", wd_row.type_str);
			AssertEquals(1, wd_row.watch_indent);

			wd_x_start := text_op.watch_data_rows[3];
			AssertEquals(true, wd_x_start.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_x_start.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_x_start.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_x_start.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_x_start.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_x_start.node.code_ir.op.values[1].type);
			AssertEquals(neume_ti.members[2].offset_in_bytes, wd_x_start.node.code_ir.op.values[1].int_value);
			AssertEquals("n.x_start", wd_x_start.name);
			AssertEquals("x_start", wd_x_start.display_name);
			AssertEquals("0", wd_x_start.value_str);
			AssertEquals("float", wd_x_start.type_str);
			AssertEquals(1, wd_x_start.watch_indent);

			wd_x_end := text_op.watch_data_rows[4];
			AssertEquals(true, wd_x_end.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_x_end.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_x_end.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_x_end.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_x_end.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_x_end.node.code_ir.op.values[1].type);
			AssertEquals(neume_ti.members[3].offset_in_bytes, wd_x_end.node.code_ir.op.values[1].int_value);
			AssertEquals("n.x_end", wd_x_end.name);
			AssertEquals("x_end", wd_x_end.display_name);
			AssertEquals("0", wd_x_end.value_str);
			AssertEquals("float", wd_x_end.type_str);
			AssertEquals(1, wd_x_end.watch_indent);

			wd_last := text_op.watch_data_rows[5];
			AssertEquals(true, wd_last.node == null);
			AssertEquals(0, wd_last.name.count);
			AssertEquals(0, wd_last.display_name.count);
			AssertEquals(0, wd_last.value_str.count);
			AssertEquals(0, wd_last.type_str.count);
			AssertEquals(0, wd_last.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 10; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		count_equal := AssertEquals(type_info(Neume).members.count + 2, text_op.watch_data_rows.count);
		wd_svara := text_op.watch_data_rows[1];
		AssertEquals(true, wd_svara.node != null);
		AssertEquals(TypeInfoTag.FLOAT, wd_svara.node.code_ir.t_info.type_enum);
		AssertEquals(MusicOperandType.RAM_MEMORY, wd_svara.node.code_ir.op.operand_type);
		AssertEquals(OperandValueType.REGISTER, wd_svara.node.code_ir.op.values[0].type);
		AssertEquals(RegDef.sbp, cast(RegDef) wd_svara.node.code_ir.op.values[0].int_value);
		AssertEquals(OperandValueType.INTEGER, wd_svara.node.code_ir.op.values[1].type);
		AssertEquals(type_info(Neume).members[0].offset_in_bytes, wd_svara.node.code_ir.op.values[1].int_value);
		AssertEquals("n.svara", wd_svara.name);
		AssertEquals("svara", wd_svara.display_name);
		AssertEquals("1", wd_svara.value_str);
		AssertEquals("float", wd_svara.type_str);
		AssertEquals(1, wd_svara.watch_indent);


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 11; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		count_equal := AssertEquals(type_info(Neume).members.count + 2, text_op.watch_data_rows.count);
		wd_x_end := text_op.watch_data_rows[4];
		AssertEquals(true, wd_x_end.node != null);
		AssertEquals(TypeInfoTag.FLOAT, wd_x_end.node.code_ir.t_info.type_enum);
		AssertEquals(MusicOperandType.RAM_MEMORY, wd_x_end.node.code_ir.op.operand_type);
		AssertEquals(OperandValueType.REGISTER, wd_x_end.node.code_ir.op.values[0].type);
		AssertEquals(RegDef.sbp, cast(RegDef) wd_x_end.node.code_ir.op.values[0].int_value);
		AssertEquals(OperandValueType.INTEGER, wd_x_end.node.code_ir.op.values[1].type);
		AssertEquals(type_info(Neume).members[3].offset_in_bytes, wd_x_end.node.code_ir.op.values[1].int_value);
		AssertEquals("n.x_end", wd_x_end.name);
		AssertEquals("x_end", wd_x_end.display_name);
		AssertEquals("1.5", wd_x_end.value_str);
		AssertEquals("float", wd_x_end.type_str);
		AssertEquals(1, wd_x_end.watch_indent);

		
		//Test close the drop struct
		DownUpThisFrame(.ENTER, game_input);
	} 
	case 12; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		wd_n := text_op.watch_data_rows[0];
		AssertEquals(true, wd_n.node != null);
		AssertEquals(TypeInfoTag.NEUME, wd_n.node.code_ir.t_info.type_enum);
		AssertEquals(MusicOperandType.RAM_MEMORY, wd_n.node.code_ir.op.operand_type);
		AssertEquals(OperandValueType.REGISTER, wd_n.node.code_ir.op.values[0].type);
		AssertEquals(RegDef.sbp, cast(RegDef) wd_n.node.code_ir.op.values[0].int_value);
		AssertEquals(OperandValueType.INTEGER, wd_n.node.code_ir.op.values[1].type);
		AssertEquals(0, wd_n.node.code_ir.op.values[1].int_value);
		AssertEquals("n", wd_n.name);
		AssertEquals("n", wd_n.display_name);
		//TODO Leaving out in case we change it later
		// AssertEquals("1", wd_n.value_str);
		AssertEquals("neume", wd_n.type_str);
		AssertEquals(0, wd_n.watch_indent);


		DownUpThisFrame(.DELETE, game_input);
	} 
	case 13; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(type_info(Neume).members.count+1, text_op.watch_data_pool.count);
		count_equal := AssertEquals(1, text_op.watch_data_rows.count);
		wd := text_op.watch_data_rows[0];
		AssertEquals(true, wd.node == null);
		AssertEquals(0, wd.name.count);
		AssertEquals(0, wd.display_name.count);
		AssertEquals(0, wd.value_str.count);
		AssertEquals(0, wd.type_str.count);
		AssertEquals(0, wd.watch_indent);


		AddTextInput("n", game_input);
	} 
	case 14; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 15; AddTextInput("n", game_input);
	case 16; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 17; DownUpThisFrame(.ARROW_UP, game_input);
	case 18; DownUpThisFrame(.ENTER, game_input);
	case 19; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//n_var (2) + Neume members (4) + empty bottom row (1)
		neume_ti := type_info(Neume);
		count_equal := AssertEquals(neume_ti.members.count + 3, text_op.watch_data_rows.count);
		if count_equal {
			wd_svara := text_op.watch_data_rows[1+1];
			AssertEquals(true, wd_svara.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_svara.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_svara.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_svara.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_svara.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_svara.node.code_ir.op.values[1].type);
			AssertEquals(neume_ti.members[0].offset_in_bytes, wd_svara.node.code_ir.op.values[1].int_value);
			AssertEquals("n.svara", wd_svara.name);
			AssertEquals("svara", wd_svara.display_name);
			AssertEquals("1", wd_svara.value_str);
			AssertEquals("float", wd_svara.type_str);
			AssertEquals(1, wd_svara.watch_indent);
		}

		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 20; DownUpThisFrame(.ENTER, game_input);
	case 21; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//n_var (2) + 2*Neume members (4) + empty bottom row (1)
		neume_ti := type_info(Neume);
		count_equal := AssertEquals(2*neume_ti.members.count + 3, text_op.watch_data_rows.count);
		if count_equal {
			wd_svara := text_op.watch_data_rows[1];
			AssertEquals(true, wd_svara.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_svara.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_svara.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_svara.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_svara.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_svara.node.code_ir.op.values[1].type);
			AssertEquals(neume_ti.members[0].offset_in_bytes, wd_svara.node.code_ir.op.values[1].int_value);
			AssertEquals("n.svara", wd_svara.name);
			AssertEquals("svara", wd_svara.display_name);
			AssertEquals("1", wd_svara.value_str);
			AssertEquals("float", wd_svara.type_str);
			AssertEquals(1, wd_svara.watch_indent);

			wd_s2 := text_op.watch_data_rows[1+5];
			AssertEquals(true, wd_s2.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_s2.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_s2.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_s2.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_s2.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_s2.node.code_ir.op.values[1].type);
			AssertEquals(neume_ti.members[0].offset_in_bytes, wd_s2.node.code_ir.op.values[1].int_value);
			AssertEquals("n.svara", wd_s2.name);
			AssertEquals("svara", wd_s2.display_name);
			AssertEquals("1", wd_s2.value_str);
			AssertEquals("float", wd_s2.type_str);
			AssertEquals(1, wd_s2.watch_indent);
		}

		//Test deleting while open
		DownUpThisFrame(.DELETE, game_input);
	} 
	case 22; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(type_info(Neume).members.count+1, text_op.watch_data_pool.count);
		count_equal := AssertEquals(type_info(Neume).members.count + 2, text_op.watch_data_rows.count);


		//TODO Test add a second one and all dropdown should be removed when not debuggin
		//Tests while not debugging
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	} 
	case 23; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		//2*members(4) + var(1)
		AssertEquals(2*type_info(Neume).members.count+1, text_op.watch_data_pool.count);
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		if count_equal {
			wd_n := text_op.watch_data_rows[0];
			AssertEquals(true, wd_n.node != null);
			AssertEquals("n", wd_n.name);
			AssertEquals("n", wd_n.display_name);
			AssertEquals(0, wd_n.watch_indent);

			wd_empty := text_op.watch_data_rows[1];
			AssertEquals(true, wd_empty.node == null);
			AssertEquals(0, wd_empty.name.count);
			AssertEquals(0, wd_empty.display_name.count);
			AssertEquals(0, wd_empty.value_str.count);
			AssertEquals(0, wd_empty.type_str.count);
			AssertEquals(0, wd_empty.watch_indent);
		}


		//Test deleting while not debugging
		DownUpThisFrame(.DELETE, game_input);
	}
	case 24; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		//2*(members(4) + var(1))
		AssertEquals(2*(type_info(Neume).members.count+1), text_op.watch_data_pool.count);
		count_equal := AssertEquals(1, text_op.watch_data_rows.count);
		if count_equal {
			wd_empty := text_op.watch_data_rows[0];
			AssertEquals(true, wd_empty.node == null);
			AssertEquals(0, wd_empty.name.count);
			AssertEquals(0, wd_empty.display_name.count);
			AssertEquals(0, wd_empty.value_str.count);
			AssertEquals(0, wd_empty.type_str.count);
			AssertEquals(0, wd_empty.watch_indent);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_WatchTanoNeume :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  t := tano(0,1);
  t.row_end = 1;
  n : neume;
  n.x_start = 1.5;
}
DONE,,test_alloc);	

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 22);
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
		AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; AddTextInput("t", game_input);
	//TODO Could use MoveToLine - would need the text_file for string and cursor
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ARROW_UP, game_input);
	case 8; DownUpThisFrame(.ENTER, game_input);
	case 9; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		//tano members (5) + top var row (1) + empty bottom row (1)
		count_equal := AssertEquals(type_info(tano).members.count + 2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.TANO, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("t", wd.name);
			AssertEquals("t", wd.display_name);
			//TODO Leaving this out for now in case this changes
			// AssertEquals("dropdown(struct)", wd.value_str);
			AssertEquals("tano", wd.type_str);
			AssertEquals(0, wd.watch_indent);

			wd_row_s := text_op.watch_data_rows[1];
			AssertEquals(true, wd_row_s.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_row_s.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_row_s.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_row_s.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_row_s.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_row_s.node.code_ir.op.values[1].type);
			AssertEquals(type_info(tano).members[0].offset_in_bytes, wd_row_s.node.code_ir.op.values[1].int_value);
			AssertEquals("t.row_start", wd_row_s.name);
			AssertEquals("row_start", wd_row_s.display_name);
			AssertEquals("0", wd_row_s.value_str);
			AssertEquals("int", wd_row_s.type_str);
			AssertEquals(1, wd_row_s.watch_indent);

			wd_row_e := text_op.watch_data_rows[2];
			AssertEquals(true, wd_row_e.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_row_e.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_row_e.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_row_e.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_row_e.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_row_e.node.code_ir.op.values[1].type);
			AssertEquals(type_info(tano).members[1].offset_in_bytes, wd_row_e.node.code_ir.op.values[1].int_value);
			AssertEquals("t.row_end", wd_row_e.name);
			AssertEquals("row_end", wd_row_e.display_name);
			AssertEquals("0", wd_row_e.value_str);
			AssertEquals("int", wd_row_e.type_str);
			AssertEquals(1, wd_row_e.watch_indent);

			wd_x_start := text_op.watch_data_rows[3];
			AssertEquals(true, wd_x_start.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_x_start.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_x_start.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_x_start.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_x_start.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_x_start.node.code_ir.op.values[1].type);
			AssertEquals(type_info(tano).members[2].offset_in_bytes, wd_x_start.node.code_ir.op.values[1].int_value);
			AssertEquals("t.x_start", wd_x_start.name);
			AssertEquals("x_start", wd_x_start.display_name);
			AssertEquals("1", wd_x_start.value_str);
			AssertEquals("float", wd_x_start.type_str);
			AssertEquals(1, wd_x_start.watch_indent);

			wd_x_end := text_op.watch_data_rows[4];
			AssertEquals(true, wd_x_end.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_x_end.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_x_end.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_x_end.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_x_end.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_x_end.node.code_ir.op.values[1].type);
			AssertEquals(type_info(tano).members[3].offset_in_bytes, wd_x_end.node.code_ir.op.values[1].int_value);
			AssertEquals("t.x_end", wd_x_end.name);
			AssertEquals("x_end", wd_x_end.display_name);
			AssertEquals("2", wd_x_end.value_str);
			AssertEquals("float", wd_x_end.type_str);
			AssertEquals(1, wd_x_end.watch_indent);

			wd_mspace := text_op.watch_data_rows[5];
			AssertEquals(true, wd_mspace.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_mspace.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_mspace.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_mspace.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_mspace.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_mspace.node.code_ir.op.values[1].type);
			AssertEquals(type_info(tano).members[4].offset_in_bytes, wd_mspace.node.code_ir.op.values[1].int_value);
			AssertEquals("t.mspace_start", wd_mspace.name);
			AssertEquals("mspace_start", wd_mspace.display_name);
			AssertEquals("0", wd_mspace.value_str);
			AssertEquals("int", wd_mspace.type_str);
			AssertEquals(1, wd_mspace.watch_indent);

			wd_last := text_op.watch_data_rows[6];
			AssertEquals(true, wd_last.node == null);
			AssertEquals(0, wd_last.name.count);
			AssertEquals(0, wd_last.display_name.count);
			AssertEquals(0, wd_last.value_str.count);
			AssertEquals(0, wd_last.type_str.count);
			AssertEquals(0, wd_last.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 10; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		count_equal := AssertEquals(type_info(tano).members.count + 2, text_op.watch_data_rows.count);
		wd_row_end := text_op.watch_data_rows[2];
		AssertEquals(true, wd_row_end.node != null);
		AssertEquals(TypeInfoTag.INTEGER, wd_row_end.node.code_ir.t_info.type_enum);
		AssertEquals(MusicOperandType.RAM_MEMORY, wd_row_end.node.code_ir.op.operand_type);
		AssertEquals(OperandValueType.REGISTER, wd_row_end.node.code_ir.op.values[0].type);
		AssertEquals(RegDef.sbp, cast(RegDef) wd_row_end.node.code_ir.op.values[0].int_value);
		AssertEquals(OperandValueType.INTEGER, wd_row_end.node.code_ir.op.values[1].type);
		AssertEquals(type_info(tano).members[1].offset_in_bytes, wd_row_end.node.code_ir.op.values[1].int_value);
		AssertEquals("t.row_end", wd_row_end.name);
		AssertEquals("row_end", wd_row_end.display_name);
		AssertEquals("1", wd_row_end.value_str);
		AssertEquals("int", wd_row_end.type_str);
		AssertEquals(1, wd_row_end.watch_indent);


		//Test close the drop struct
		DownUpThisFrame(.ENTER, game_input);
	} 
	case 11; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(5, text_op.watch_data_pool.count);
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		wd := text_op.watch_data_rows[0];
		AssertEquals(true, wd.node != null);
		AssertEquals(TypeInfoTag.TANO, wd.node.code_ir.t_info.type_enum);
		AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
		AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
		AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
		AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
		AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
		AssertEquals("t", wd.name);
		AssertEquals("t", wd.display_name);
		//TODO Leaving out in case we change it later
		// AssertEquals("1", wd.value_str);
		AssertEquals("tano", wd.type_str);
		AssertEquals(0, wd.watch_indent);

		
		DownUpThisFrame(.ARROW_DOWN, game_input);
	} 
	case 12; DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	case 13; AddTextInput("n", game_input);
	case 14; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 15; DownUpThisFrame(.ARROW_UP, game_input);
	case 16; DownUpThisFrame(.ENTER, game_input);
	case 17; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		count_equal := AssertEquals(2+4+1, text_op.watch_data_rows.count);
		if count_equal {
			wd_n := text_op.watch_data_rows[1];
			AssertEquals(true, wd_n.node != null);
			AssertEquals(TypeInfoTag.NEUME, wd_n.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_n.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_n.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_n.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_n.node.code_ir.op.values[1].type);
			AssertEquals(text_op.text_comp_data.all_type_info.tano_struct_info.runtime_size, wd_n.node.code_ir.op.values[1].int_value);
			AssertEquals("n", wd_n.name);
			AssertEquals("n", wd_n.display_name);
			//TODO Leaving out in case we change it later
			// AssertEquals("1", wd_n.value_str);
			AssertEquals("neume", wd_n.type_str);
			AssertEquals(0, wd_n.watch_indent);

			wd_x_start := text_op.watch_data_rows[4];
			AssertEquals(true, wd_x_start.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_x_start.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_x_start.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_x_start.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_x_start.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_x_start.node.code_ir.op.values[1].type);
			AssertEquals(size_of(tano)+type_info(Neume).members[2].offset_in_bytes, wd_x_start.node.code_ir.op.values[1].int_value);
			AssertEquals("n.x_start", wd_x_start.name);
			AssertEquals("x_start", wd_x_start.display_name);
			AssertEquals("0", wd_x_start.value_str);
			AssertEquals("float", wd_x_start.type_str);
			AssertEquals(1, wd_x_start.watch_indent);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	} 
	case 18; DownUpThisFrame(.ARROW_UP, game_input);
	case 19; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		count_equal := AssertEquals(2+4+1, text_op.watch_data_rows.count);
		if count_equal {
			wd_x_start := text_op.watch_data_rows[4];
			AssertEquals(true, wd_x_start.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_x_start.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_x_start.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_x_start.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_x_start.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_x_start.node.code_ir.op.values[1].type);
			AssertEquals(size_of(tano)+type_info(Neume).members[2].offset_in_bytes, wd_x_start.node.code_ir.op.values[1].int_value);
			AssertEquals("n.x_start", wd_x_start.name);
			AssertEquals("x_start", wd_x_start.display_name);
			AssertEquals("1.5", wd_x_start.value_str);
			AssertEquals("float", wd_x_start.type_str);
			AssertEquals(1, wd_x_start.watch_indent);
		}

		//Open tano to test everything closes
		DownUpThisFrame(.ENTER, game_input);
	} 
	case 20; {
		//Test everything closes
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 21; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(type_info(Neume).members.count+type_info(tano).members.count, text_op.watch_data_pool.count);
		count_equal := AssertEquals(3, text_op.watch_data_rows.count);
		if count_equal {
			wd_t := text_op.watch_data_rows[0];
			AssertEquals(true, wd_t.node != null);
			AssertEquals("t", wd_t.name);
			AssertEquals("t", wd_t.display_name);

			wd_n := text_op.watch_data_rows[1];
			AssertEquals(true, wd_n.node != null);
			AssertEquals("n", wd_n.name);
			AssertEquals("n", wd_n.display_name);

			wd_empty := text_op.watch_data_rows[2];
			AssertEquals(true, wd_n.node != null);
			AssertEquals(0, wd_empty.name.count);
		}

	} 
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO Need to add a struct in a struct and an array in a struct
Test_WatchStruct :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  t : Test;
  t.f = 3.14;
}
Test :: struct {
  x : int;
  f : float;
  //TODO add struct in struct and array in struct
}
DONE,,test_alloc);	

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
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 5; AddTextInput("t", game_input);
	//TODO Could use MoveToLine - would need the text_file for string and cursor
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ARROW_UP, game_input);
	case 8; DownUpThisFrame(.ENTER, game_input);
	case 9; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.watch_data_pool.count);
		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.STRUCT, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("t", wd.name);
			AssertEquals("t", wd.display_name);
			//TODO Leaving this out for now in case this changes
			// AssertEquals("dropdown(struct)", wd.value_str);
			AssertEquals("Test", wd.type_str);
			AssertEquals(0, wd.watch_indent);

			wd_x := text_op.watch_data_rows[1];
			AssertEquals(true, wd_x.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_x.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_x.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_x.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_x.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_x.node.code_ir.op.values[1].type);
			AssertEquals(0, wd_x.node.code_ir.op.values[1].int_value);
			AssertEquals("t.x", wd_x.name);
			AssertEquals("x", wd_x.display_name);
			AssertEquals("0", wd_x.value_str);
			AssertEquals("int", wd_x.type_str);
			AssertEquals(1, wd_x.watch_indent);

			wd_f := text_op.watch_data_rows[2];
			AssertEquals(true, wd_f.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_f.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_f.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_f.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_f.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_f.node.code_ir.op.values[1].type);
			AssertEquals(8, wd_f.node.code_ir.op.values[1].int_value);
			AssertEquals("t.f", wd_f.name);
			AssertEquals("f", wd_f.display_name);
			AssertEquals("0", wd_f.value_str);
			AssertEquals("float", wd_f.type_str);
			AssertEquals(1, wd_f.watch_indent);

			wd_last := text_op.watch_data_rows[3];
			AssertEquals(true, wd_last.node == null);
			AssertEquals(0, wd_last.name.count);
			AssertEquals(0, wd_last.display_name.count);
			AssertEquals(0, wd_last.value_str.count);
			AssertEquals(0, wd_last.type_str.count);
			AssertEquals(0, wd_last.watch_indent);
		}

		//Test update value
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 10; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			wd_f := text_op.watch_data_rows[2];
			AssertEquals(true, wd_f.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_f.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd_f.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd_f.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd_f.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd_f.node.code_ir.op.values[1].type);
			AssertEquals(type_info(tano).members[1].offset_in_bytes, wd_f.node.code_ir.op.values[1].int_value);
			AssertEquals("t.f", wd_f.name);
			AssertEquals("f", wd_f.display_name);
			AssertEquals("3.14", wd_f.value_str);
			AssertEquals("float", wd_f.type_str);
			AssertEquals(1, wd_f.watch_indent);
		}


		//Test close the drop struct
		DownUpThisFrame(.ENTER, game_input);
	} 
	case 11; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, text_op.watch_data_pool.count);
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals(TypeInfoTag.STRUCT, wd.node.code_ir.t_info.type_enum);
			AssertEquals(MusicOperandType.RAM_MEMORY, wd.node.code_ir.op.operand_type);
			AssertEquals(OperandValueType.REGISTER, wd.node.code_ir.op.values[0].type);
			AssertEquals(RegDef.sbp, cast(RegDef) wd.node.code_ir.op.values[0].int_value);
			AssertEquals(OperandValueType.INTEGER, wd.node.code_ir.op.values[1].type);
			AssertEquals(0, wd.node.code_ir.op.values[1].int_value);
			AssertEquals("t", wd.name);
			AssertEquals("t", wd.display_name);
			//TODO Leaving out in case we change it later
			// AssertEquals("1", wd.value_str);
			AssertEquals("Test", wd.type_str);
			AssertEquals(0, wd.watch_indent);
		}

		
		//Test open and then close
		DownUpThisFrame(.ENTER, game_input);
	}
	case 12; {
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 13; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(2, text_op.watch_data_pool.count);
		count_equal := AssertEquals(2, text_op.watch_data_rows.count);
		if count_equal {
			wd := text_op.watch_data_rows[0];
			AssertEquals(true, wd.node != null);
			AssertEquals("t", wd.name);
			AssertEquals("t", wd.display_name);

			wd_empty := text_op.watch_data_rows[1];
			AssertEquals(0, wd_empty.name.count);
		}	
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_StructLiteral :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO IF this is too many tests in one then we can split it up 
//Test autocast here (could make separate test here)
#string DONE
main :: () {
  n := neume.{7.,2,0.,1.};
  ne := neume.{};
  t := tano.{0,x_end=2.};
  t2 := tano.{row_end=1,mspace_start=1};
  
  test := Test.{10,3.1};
  test2 := Test.{x=2};
  teste := Test.{};
  
  t_auto := tano.{0,x_end=2};
  n_auto := neume.{4,0,0,1};
  test_auto := Test.{y=3};
}
Test :: struct {
  x : int;
  y : float;
}
DONE,,test_alloc);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 44);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["n","ne","t","t2","test","test2","teste","t_auto","n_auto","test_auto"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		//Before the while scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 6; DownUpThisFrame(.ENTER, game_input);
	case 7; {
		//n := neume.{7.,2,0.,1.};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		n_watch := GetWatch("n", text_op.watch_data_rows);
		AssertEquals("neume", n_watch.type_str);

		n_svara := GetWatch("n.svara", text_op.watch_data_rows);
		AssertEquals("7", n_svara.value_str);
		AssertEquals("float", n_svara.type_str);

		n_row := GetWatch("n.row", text_op.watch_data_rows);
		AssertEquals("2", n_row.value_str);
		AssertEquals("int", n_row.type_str);

		n_x_start := GetWatch("n.x_start", text_op.watch_data_rows);
		AssertEquals("0", n_x_start.value_str);
		AssertEquals("float", n_x_start.type_str);

		n_x_end := GetWatch("n.x_end", text_op.watch_data_rows);
		AssertEquals("1", n_x_end.value_str);
		AssertEquals("float", n_x_end.type_str);

		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);		
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 8; DownUpThisFrame(.ENTER, game_input);
	case 9; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 10; DownUpThisFrame(.ENTER, game_input);
	case 11; {
		//ne := neume.{};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(3, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		ne_watch := GetWatch("ne", text_op.watch_data_rows);
		AssertEquals("neume", ne_watch.type_str);

		ne_svara := GetWatch("ne.svara", text_op.watch_data_rows);
		AssertEquals("0", ne_svara.value_str);
		AssertEquals("float", ne_svara.type_str);

		ne_row := GetWatch("ne.row", text_op.watch_data_rows);
		AssertEquals("0", ne_row.value_str);
		AssertEquals("int", ne_row.type_str);

		ne_x_start := GetWatch("ne.x_start", text_op.watch_data_rows);
		AssertEquals("0", ne_x_start.value_str);
		AssertEquals("float", ne_x_start.type_str);

		ne_x_end := GetWatch("ne.x_end", text_op.watch_data_rows);
		AssertEquals("0", ne_x_end.value_str);
		AssertEquals("float", ne_x_end.type_str);

		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}	
	case 12; DownUpThisFrame(.ENTER, game_input);
	case 13; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 14; DownUpThisFrame(.ENTER, game_input);
	case 15; {
		//t := tano.{0,x_end=2.};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		t_watch := GetWatch("t", text_op.watch_data_rows);
		AssertEquals("tano", t_watch.type_str);

		t_row_start := GetWatch("t.row_start", text_op.watch_data_rows);
		AssertEquals("0", t_row_start.value_str);
		AssertEquals("int", t_row_start.type_str);
		t_row_end := GetWatch("t.row_end", text_op.watch_data_rows);
		AssertEquals("0", t_row_end.value_str);
		AssertEquals("int", t_row_end.type_str);

		t_x_start := GetWatch("t.x_start", text_op.watch_data_rows);
		AssertEquals("0", t_x_start.value_str);
		AssertEquals("float", t_x_start.type_str);
		t_x_end := GetWatch("t.x_end", text_op.watch_data_rows);
		AssertEquals("2", t_x_end.value_str);
		AssertEquals("float", t_x_end.type_str);

		t_mspace_start := GetWatch("t.mspace_start", text_op.watch_data_rows);
		AssertEquals("0", t_mspace_start.value_str);
		AssertEquals("int", t_mspace_start.type_str);


		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 16; DownUpThisFrame(.ENTER, game_input);
	case 17; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 18; DownUpThisFrame(.ENTER, game_input);
	case 19; {
  		// t2 := tano.{row_end=1,mspace_start=1};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(6, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		t2_watch := GetWatch("t2", text_op.watch_data_rows);
		AssertEquals("tano", t2_watch.type_str);

		t2_row_start := GetWatch("t2.row_start", text_op.watch_data_rows);
		AssertEquals("0", t2_row_start.value_str);
		AssertEquals("int", t2_row_start.type_str);
		t2_row_end := GetWatch("t2.row_end", text_op.watch_data_rows);
		AssertEquals("1", t2_row_end.value_str);
		AssertEquals("int", t2_row_end.type_str);

		t2_x_start := GetWatch("t2.x_start", text_op.watch_data_rows);
		AssertEquals("0", t2_x_start.value_str);
		AssertEquals("float", t2_x_start.type_str);
		t2_x_end := GetWatch("t2.x_end", text_op.watch_data_rows);
		AssertEquals("0", t2_x_end.value_str);
		AssertEquals("float", t2_x_end.type_str);

		t2_mspace_start := GetWatch("t2.mspace_start", text_op.watch_data_rows);
		AssertEquals("1", t2_mspace_start.value_str);
		AssertEquals("int", t2_mspace_start.type_str);


		CodeBPForTest(7, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 20; DownUpThisFrame(.ENTER, game_input);
	case 21; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 22; DownUpThisFrame(.ENTER, game_input);
	case 23; {
	  // test := Test.{10,3.1};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		test_watch := GetWatch("test", text_op.watch_data_rows);
		AssertEquals("Test", test_watch.type_str);

		test_x := GetWatch("test.x", text_op.watch_data_rows);
		AssertEquals("10", test_x.value_str);
		AssertEquals("int", test_x.type_str);
		test_y := GetWatch("test.y", text_op.watch_data_rows);
		AssertEquals("3.1", test_y.value_str);
		AssertEquals("float", test_y.type_str);


		CodeBPForTest(8, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 24; DownUpThisFrame(.ENTER, game_input);
	case 25; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 26; DownUpThisFrame(.ENTER, game_input);
	case 27; {
	  	// test2 := Test.{x=2};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(8, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		test2_watch := GetWatch("test2", text_op.watch_data_rows);
		AssertEquals("Test", test2_watch.type_str);

		test2_x := GetWatch("test2.x", text_op.watch_data_rows);
		AssertEquals("2", test2_x.value_str);
		AssertEquals("int", test2_x.type_str);
		test2_y := GetWatch("test2.y", text_op.watch_data_rows);
		AssertEquals("0", test2_y.value_str);
		AssertEquals("float", test2_y.type_str);


		CodeBPForTest(10, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 28; DownUpThisFrame(.ENTER, game_input);
	case 29; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 30; DownUpThisFrame(.ENTER, game_input);
	case 31; {
	  	// teste := Test.{};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(10, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		teste_watch := GetWatch("teste", text_op.watch_data_rows);
		AssertEquals("Test", teste_watch.type_str);

		teste_x := GetWatch("teste.x", text_op.watch_data_rows);
		AssertEquals("0", teste_x.value_str);
		AssertEquals("int", teste_x.type_str);
		teste_y := GetWatch("teste.y", text_op.watch_data_rows);
		AssertEquals("0", teste_y.value_str);
		AssertEquals("float", teste_y.type_str);


		CodeBPForTest(11, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 32; DownUpThisFrame(.ENTER, game_input);
	case 33; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 34; DownUpThisFrame(.ENTER, game_input);
	case 35; {
	  	// t_auto := tano.{0,x_end=2};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(11, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		t_auto_watch := GetWatch("t_auto", text_op.watch_data_rows);
		AssertEquals("tano", t_auto_watch.type_str);

		t_auto_row_start := GetWatch("t_auto.row_start", text_op.watch_data_rows);
		AssertEquals("0", t_auto_row_start.value_str);
		AssertEquals("int", t_auto_row_start.type_str);
		t_auto_row_end := GetWatch("t_auto.row_end", text_op.watch_data_rows);
		AssertEquals("0", t_auto_row_end.value_str);
		AssertEquals("int", t_auto_row_end.type_str);

		t_auto_x_start := GetWatch("t_auto.x_start", text_op.watch_data_rows);
		AssertEquals("0", t_auto_x_start.value_str);
		AssertEquals("float", t_auto_x_start.type_str);
		t_auto_x_end := GetWatch("t_auto.x_end", text_op.watch_data_rows);
		AssertEquals("2", t_auto_x_end.value_str);
		AssertEquals("float", t_auto_x_end.type_str);

		t_auto_mspace_start := GetWatch("t_auto.mspace_start", text_op.watch_data_rows);
		AssertEquals("0", t_auto_mspace_start.value_str);
		AssertEquals("int", t_auto_mspace_start.type_str);


		CodeBPForTest(12, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 36; DownUpThisFrame(.ENTER, game_input);
	case 37; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 38; DownUpThisFrame(.ENTER, game_input);
	case 39; {
		//n_auto := neume.{4,0,0,1};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(12, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		n_auto_watch := GetWatch("n_auto", text_op.watch_data_rows);
		AssertEquals("neume", n_auto_watch.type_str);

		n_auto_svara := GetWatch("n_auto.svara", text_op.watch_data_rows);
		AssertEquals("4", n_auto_svara.value_str);
		AssertEquals("float", n_auto_svara.type_str);

		n_auto_row := GetWatch("n_auto.row", text_op.watch_data_rows);
		AssertEquals("0", n_auto_row.value_str);
		AssertEquals("int", n_auto_row.type_str);

		n_auto_x_start := GetWatch("n_auto.x_start", text_op.watch_data_rows);
		AssertEquals("0", n_auto_x_start.value_str);
		AssertEquals("float", n_auto_x_start.type_str);

		n_auto_x_end := GetWatch("n_auto.x_end", text_op.watch_data_rows);
		AssertEquals("1", n_auto_x_end.value_str);
		AssertEquals("float", n_auto_x_end.type_str);

		CodeBPForTest(13, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 40; DownUpThisFrame(.ENTER, game_input);
	case 41; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 42; DownUpThisFrame(.ENTER, game_input);
	case 43; {
	  	// test_auto := Test.{y=3};
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(13, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		test_auto_watch := GetWatch("test_auto", text_op.watch_data_rows);
		AssertEquals("Test", test_auto_watch.type_str);

		test_auto_x := GetWatch("test_auto.x", text_op.watch_data_rows);
		AssertEquals("0", test_auto_x.value_str);
		AssertEquals("int", test_auto_x.type_str);
		test_auto_y := GetWatch("test_auto.y", text_op.watch_data_rows);
		AssertEquals("3", test_auto_y.value_str);
		AssertEquals("float", test_auto_y.type_str);


		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ArrayLiteralAutocast :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
#string DONE
main :: () {
  fa : [] float = float.[0,4,7];
}
DONE,,test_alloc);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 8);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["fa"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		//Before the while scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 6; DownUpThisFrame(.ENTER, game_input);
	case 7; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		fa_watch := GetWatch("fa", text_op.watch_data_rows);
		AssertEquals("[] float", fa_watch.type_str);

		fa_0 := GetWatch("fa[0]", text_op.watch_data_rows);
		AssertEquals("0", fa_0.value_str);
		AssertEquals("float", fa_0.type_str);
		fa_1 := GetWatch("fa[1]", text_op.watch_data_rows);
		AssertEquals("4", fa_1.value_str);
		AssertEquals("float", fa_1.type_str);
		fa_2 := GetWatch("fa[2]", text_op.watch_data_rows);
		AssertEquals("7", fa_2.value_str);
		AssertEquals("float", fa_2.type_str);

		// CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);		
		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_ArrayStructLiteral :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
#string DONE
main :: () {
  na := neume.[
    neume.{0,0,0,1}, 
    neume.{4,0,0,1}
  ];
}
DONE,,test_alloc);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 16);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["na"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(5, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 6; DownUpThisFrame(.ENTER, game_input);
	case 7; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			na_wd := text_op.watch_data_rows[0];
			AssertEquals(true, na_wd.node != null);
			t_info_array := cast(*TypeInfoArray) na_wd.node.code_ir.t_info;
			t_info_struct := cast(*TypeInfoStruct) t_info_array.element_type;
			AssertEquals("neume", t_info_struct.name);
			AssertEquals(TypeInfoTag.ARRAY, na_wd.node.code_ir.t_info.type_enum);
			AssertEquals("na", na_wd.name);
			AssertEquals("na", na_wd.display_name);
			// AssertEquals("test_1 (-10)", na_wd.value_str);
			AssertEquals("[2] neume", na_wd.type_str);
			AssertEquals(0, na_wd.watch_indent);

			na_wd_0 := text_op.watch_data_rows[1];
			AssertEquals(true, na_wd_0.node != null);
			wd_0_t_info := cast(*TypeInfoStruct) na_wd_0.node.code_ir.t_info;
			AssertEquals("neume", wd_0_t_info.name);
			AssertEquals(TypeInfoTag.NEUME, na_wd_0.node.code_ir.t_info.type_enum);
			AssertEquals("na[0]", na_wd_0.name);
			AssertEquals("[0]", na_wd_0.display_name);
			// AssertEquals("test_1 (-10)", na_wd_0.value_str);
			AssertEquals("neume", na_wd_0.type_str);
			AssertEquals(1, na_wd_0.watch_indent);

			na_wd_1 := text_op.watch_data_rows[2];
			AssertEquals(true, na_wd_1.node != null);
			wd_1_t_info := cast(*TypeInfoStruct) na_wd_1.node.code_ir.t_info;
			AssertEquals("neume", wd_1_t_info.name);
			AssertEquals(TypeInfoTag.NEUME, na_wd_1.node.code_ir.t_info.type_enum);
			AssertEquals("na[1]", na_wd_1.name);
			AssertEquals("[1]", na_wd_1.display_name);
			// AssertEquals("test_1 (-10)", na_wd_1.value_str);
			AssertEquals("neume", na_wd_1.type_str);
			AssertEquals(1, na_wd_1.watch_indent);
		}
	}
	case 8; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 9; DownUpThisFrame(.ENTER, game_input);
	case 10; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		cd := text_op.text_comp_data;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equal := AssertEquals(8, text_op.watch_data_rows.count);
		if count_equal {
			wd_0 := text_op.watch_data_rows[2];
			AssertEquals(true, wd_0.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_0.node.code_ir.t_info.type_enum);
			member_0_name := cd.neume_struct_info.struct_members[0].name;
			AssertEquals(tprint("na[0].%", member_0_name), wd_0.name);
			AssertEquals(member_0_name, wd_0.display_name);
			AssertEquals("0", wd_0.value_str);
			AssertEquals("float", wd_0.type_str);
			AssertEquals(2, wd_0.watch_indent);

			wd_1 := text_op.watch_data_rows[3];
			AssertEquals(true, wd_1.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_1.node.code_ir.t_info.type_enum);
			member_1_name := cd.neume_struct_info.struct_members[1].name;
			AssertEquals(tprint("na[0].%", member_1_name), wd_1.name);
			AssertEquals(member_1_name, wd_1.display_name);
			AssertEquals("0", wd_1.value_str);
			AssertEquals("int", wd_1.type_str);
			AssertEquals(2, wd_1.watch_indent);

			wd_2 := text_op.watch_data_rows[4];
			AssertEquals(true, wd_2.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_2.node.code_ir.t_info.type_enum);
			member_2_name := cd.neume_struct_info.struct_members[2].name;
			AssertEquals(tprint("na[0].%", member_2_name), wd_2.name);
			AssertEquals(member_2_name, wd_2.display_name);
			AssertEquals("0", wd_2.value_str);
			AssertEquals("float", wd_2.type_str);
			AssertEquals(2, wd_2.watch_indent);

			wd_3 := text_op.watch_data_rows[5];
			AssertEquals(true, wd_3.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_3.node.code_ir.t_info.type_enum);
			member_3_name := cd.neume_struct_info.struct_members[3].name;
			AssertEquals(tprint("na[0].%", member_3_name), wd_3.name);
			AssertEquals(member_3_name, wd_3.display_name);
			AssertEquals("1", wd_3.value_str);
			AssertEquals("float", wd_3.type_str);
			AssertEquals(2, wd_3.watch_indent);
		}
	}
	case 11; DownUpThisFrame(.ENTER, game_input);
	case 12; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 13; DownUpThisFrame(.ENTER, game_input);
	case 14; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		cd := text_op.text_comp_data;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equal := AssertEquals(8, text_op.watch_data_rows.count);
		if count_equal {
			wd_0 := text_op.watch_data_rows[3];
			AssertEquals(true, wd_0.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_0.node.code_ir.t_info.type_enum);
			member_0_name := cd.neume_struct_info.struct_members[0].name;
			AssertEquals(tprint("na[1].%", member_0_name), wd_0.name);
			AssertEquals(member_0_name, wd_0.display_name);
			AssertEquals("4", wd_0.value_str);
			AssertEquals("float", wd_0.type_str);
			AssertEquals(2, wd_0.watch_indent);

			wd_1 := text_op.watch_data_rows[4];
			AssertEquals(true, wd_1.node != null);
			AssertEquals(TypeInfoTag.INTEGER, wd_1.node.code_ir.t_info.type_enum);
			member_1_name := cd.neume_struct_info.struct_members[1].name;
			AssertEquals(tprint("na[1].%", member_1_name), wd_1.name);
			AssertEquals(member_1_name, wd_1.display_name);
			AssertEquals("0", wd_1.value_str);
			AssertEquals("int", wd_1.type_str);
			AssertEquals(2, wd_1.watch_indent);

			wd_2 := text_op.watch_data_rows[5];
			AssertEquals(true, wd_2.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_2.node.code_ir.t_info.type_enum);
			member_2_name := cd.neume_struct_info.struct_members[2].name;
			AssertEquals(tprint("na[1].%", member_2_name), wd_2.name);
			AssertEquals(member_2_name, wd_2.display_name);
			AssertEquals("0", wd_2.value_str);
			AssertEquals("float", wd_2.type_str);
			AssertEquals(2, wd_2.watch_indent);

			wd_3 := text_op.watch_data_rows[6];
			AssertEquals(true, wd_3.node != null);
			AssertEquals(TypeInfoTag.FLOAT, wd_3.node.code_ir.t_info.type_enum);
			member_3_name := cd.neume_struct_info.struct_members[3].name;
			AssertEquals(tprint("na[1].%", member_3_name), wd_3.name);
			AssertEquals(member_3_name, wd_3.display_name);
			AssertEquals("1", wd_3.value_str);
			AssertEquals("float", wd_3.type_str);
			AssertEquals(2, wd_3.watch_indent);
		}

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 15; {
		//Extra test to make sure we remove the dropped array rows after running. 
		//Can remove this test if not needed.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .NOT_RUNNING);	
		//vars + 1 empty row
		AssertEquals(2, text_op.watch_data_rows.count);

		//Can rerun here if we want to see the array.
		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CompileCast :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO bool <-> int casting here once we do that
#string DONE
main :: () {
  v : *void;
  i : *int = cast(*int) v;
  
  i1 : int = 10;
  f1 : float = cast(float) i1;
  
  f2 : float = 3.14159;
  i2 : int = cast(int) f2;
  
  a := int.[0,1];
  ac := cast([] int) a;
}
DONE,,test_alloc);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 14);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	watch_data_vars :: string.["a","ac","v","i","i1","f1","f2","i2"];
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(watch_data_vars, text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
	  // v : *void;
	  // i : *int = cast(*int) v;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		v_watch := GetWatch("v", text_op.watch_data_rows);
		AssertEquals("*void", v_watch.type_str);
		/*DOC : This is -1 because of NULL_POINTER_OP when we declare a pointer without assigning it to an
		address in memory, we set it to -1 so that it points to invalid memory if it is used.
		*/
		AssertEquals("-1", v_watch.value_str);

		i_watch := GetWatch("i", text_op.watch_data_rows);
		AssertEquals("*int", i_watch.type_str);
		AssertEquals("-1", i_watch.value_str);


		CodeBPForTest(7, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 6; {
		// i1 : int = 10;
  		// f1 : float = cast(float) i1;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		i1_watch := GetWatch("i1", text_op.watch_data_rows);
		AssertEquals("int", i1_watch.type_str);
		AssertEquals("10", i1_watch.value_str);

		f1_watch := GetWatch("f1", text_op.watch_data_rows);
		AssertEquals("float", f1_watch.type_str);
		AssertEquals("10", f1_watch.value_str);


		CodeBPForTest(10, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 7; {
		// f2 : float = 3.14159;
  		// i2 : int = cast(int) f2;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(10, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		f2_watch := GetWatch("f2", text_op.watch_data_rows);
		AssertEquals("float", f2_watch.type_str);
		AssertEquals("3.14159", f2_watch.value_str);

		i2_watch := GetWatch("i2", text_op.watch_data_rows);
		AssertEquals("int", i2_watch.type_str);
		AssertEquals("3", i2_watch.value_str);


		CodeBPForTest(12, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 8; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 9; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 10; DownUpThisFrame(.ENTER, game_input);
	case 11; DownUpThisFrame(.ARROW_UP, game_input);
	case 12; DownUpThisFrame(.ENTER, game_input);
	case 13; {
		//  a := int.[0,1];
		// ac := cast([] int) a;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(12, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		a_watch := GetWatch("a", text_op.watch_data_rows);
		AssertEquals("[2] int", a_watch.type_str);
		a_0_watch := GetWatch("a[0]", text_op.watch_data_rows);
		AssertEquals("a[0]", a_0_watch.name);
		AssertEquals("[0]", a_0_watch.display_name);
		AssertEquals("int", a_0_watch.type_str);
		AssertEquals("0", a_0_watch.value_str);
		a_1_watch := GetWatch("a[1]", text_op.watch_data_rows);
		AssertEquals("a[1]", a_1_watch.name);
		AssertEquals("[1]", a_1_watch.display_name);
		AssertEquals("int", a_1_watch.type_str);
		AssertEquals("1", a_1_watch.value_str);

		ac_watch := GetWatch("ac", text_op.watch_data_rows);
		AssertEquals("[] int", ac_watch.type_str);
		ac_0_watch := GetWatch("ac[0]", text_op.watch_data_rows);
		AssertEquals("ac[0]", ac_0_watch.name);
		AssertEquals("[0]", ac_0_watch.display_name);
		AssertEquals("int", ac_0_watch.type_str);
		AssertEquals("0", ac_0_watch.value_str);
		ac_1_watch := GetWatch("ac[1]", text_op.watch_data_rows);
		AssertEquals("ac[1]", ac_1_watch.name);
		AssertEquals("[1]", ac_1_watch.display_name);
		AssertEquals("int", ac_1_watch.type_str);
		AssertEquals("1", ac_1_watch.value_str);


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	// case 14; {
	// 	//Extra test to make sure we remove the dropped array rows after running. 
	// 	//Can remove this test if not needed.
	// 	text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
	// 	AssertEquals(text_op.exec_info.exec_state, .NOT_RUNNING);	
	// 	//vars + 1 empty row
	// 	AssertEquals(watch_data_vars.count+1, text_op.watch_data_rows.count);
	// }
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CompLogic :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO bool <-> int casting here once we do that
#string DONE
main :: () {
	bt : bool = true;
	bf : bool = false;
	b : bool = bt || bf;
	b = bt && bf;

	i : int = 1;
	x : int = 3;
	b = i < x;
	b = i <= x;
	b = i > x;
	b = i >= x;
	b = i == x;
	b = i != x;
}
DONE,,test_alloc);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 13+1);
	} 

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	watch_data_vars :: string.["bt","bf","b","i","x"];
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(watch_data_vars, text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		//TEST bt || bf == true
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("true", b_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 6; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST bt && bf == false
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("false", b_watch.value_str);

		CodeBPForTest(9, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 7; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST (i < x) == (1 < 3) == true
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("true", b_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);		
	}
	case 8; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST (i <= x) == (1 <= 3) == true
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("true", b_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);		
	}
	case 9; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST (i > x) == (1 > 3) == false
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("false", b_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 10; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST (i >= x) == (1 >= 3) == false
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("false", b_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST (i == x) == (1 == 3) == false
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("false", b_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 12; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST (i != x) == (1 != 3) == false
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("true", b_watch.value_str);

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 13; {
		AssertEquals(text_op.exec_info.exec_state, .NOT_RUNNING);	

		//TEST (i != x) == (1 != 3) == false
		b_watch := GetWatch("b", text_op.watch_data_rows);
		AssertEquals("bool", b_watch.type_str);
		AssertEquals("true", b_watch.value_str);

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CompOpEquals :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO bool <-> int casting here once we do that
#string DONE
main :: () {
	x : int = 3;
	i : int = 0;
	i += x;
	i -= 1;
	i /= 2;
	i *= 4;
	i %= 4;

	xf : float = 3.;
	f : float = 0.;
	f += xf;
	f -= 1.0;
	f /= 2.0;
	f *= 4.0;
	f %= 4.0;
}
DONE,,test_alloc);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 14+1);
	} 

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	watch_data_vars :: string.["i","f"];
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(watch_data_vars, text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST i += x;
		i_watch := GetWatch("i", text_op.watch_data_rows);
		AssertEquals("int", i_watch.type_str);
		AssertEquals("3", i_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 6; {
		//TEST i -= 1;
		i_watch := GetWatch("i", text_op.watch_data_rows);
		AssertEquals("int", i_watch.type_str);
		AssertEquals("2", i_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 7; {
		//TEST i /= 2;
		i_watch := GetWatch("i", text_op.watch_data_rows);
		AssertEquals("int", i_watch.type_str);
		AssertEquals("1", i_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 8; {
		//TEST i *= 4;
		i_watch := GetWatch("i", text_op.watch_data_rows);
		AssertEquals("int", i_watch.type_str);
		AssertEquals("4", i_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 9; {
		//TEST i %= 4;
		i_watch := GetWatch("i", text_op.watch_data_rows);
		AssertEquals("int", i_watch.type_str);
		AssertEquals("0", i_watch.value_str);

		CodeBPForTest(12, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 10; {
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		//TEST f += xf;
		f_watch := GetWatch("f", text_op.watch_data_rows);
		AssertEquals("float", f_watch.type_str);
		AssertEquals("3", f_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		//TEST f -= 1.0;
		f_watch := GetWatch("f", text_op.watch_data_rows);
		AssertEquals("float", f_watch.type_str);
		AssertEquals("2", f_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 12; {
		//TEST f /= 2.0;
		f_watch := GetWatch("f", text_op.watch_data_rows);
		AssertEquals("float", f_watch.type_str);
		AssertEquals("1", f_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 13; {
		//TEST f *= 4.0;
		f_watch := GetWatch("f", text_op.watch_data_rows);
		AssertEquals("float", f_watch.type_str);
		AssertEquals("4", f_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 14; {
		//TEST f %= 4.0;
		f_watch := GetWatch("f", text_op.watch_data_rows);
		AssertEquals("float", f_watch.type_str);
		AssertEquals("0", f_watch.value_str);

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CompArrayAccess :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO bool <-> int casting here once we do that
#string DONE
main :: () {
	ta : [2] Test;
	ta[0].x = 5;

	test2 : [1] T2;
	test2[0].arr[1] = ta[0].x;

	fa : [] int = NewArray(4, int);
	ap : *[] int = *fa;
	ap.*[0] = 3;
}
Test :: struct {
	x : int;
}
T2 :: struct {
	arr : [2] int;
}
DONE,,test_alloc);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 21+1);
	} 

	text_op : *TextOpSpaceData;
	if perm.all_data.all_text_op_space_data.count > 0 {
		text_op = *perm.all_data.all_text_op_space_data[0];
	}

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	watch_data_vars :: string.["ta","test2","fa"];
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(watch_data_vars, text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		CodeBPForTest(10, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 6; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 7; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 8; DownUpThisFrame(.ENTER, game_input);
	case 9; DownUpThisFrame(.ARROW_UP, game_input);
	case 10; DownUpThisFrame(.ENTER, game_input);
	case 11; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 12; DownUpThisFrame(.ENTER, game_input);
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

		ta_0_watch := GetWatch("ta[0].x", text_op.watch_data_rows);
		AssertEquals("int", ta_0_watch.type_str);
		AssertEquals("5", ta_0_watch.value_str);

		test_2_watch := GetWatch("test2[0].arr[1]", text_op.watch_data_rows);
		AssertEquals("int", test_2_watch.type_str);
		AssertEquals("5", test_2_watch.value_str);

		fa_watch := GetWatch("fa[0]", text_op.watch_data_rows);
		AssertEquals("int", fa_watch.type_str);
		AssertEquals("3", fa_watch.value_str);

		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_IfScope :: (
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
  if x == 0 {
    y : int = x + 1;
  }
  x = x + 1;
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
	//TODO We could set the breakpoint directly here if we have an issue. That's what we do later in this test.
	case 2; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 3; DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	case 4; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 5; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 6; {
		//Before the if scope
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
				AssertEquals(CodeTokenType.KEYWORD_IF, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);
			}
		}	


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} case 7; {
		//ON the if line now. Scope still not open since the if condition is not checked yet.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			count_equals = AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(1, c_frame.frame_vars.count);
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
	case 8; {
		//In the if scope now. Scope should be open since the condition is true and we are in the if scope.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
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
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			if_scope : ScopeData;
			if count_equals {
				if_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, if_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_IF, if_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+3, if_scope.start_instr_index);
				AssertEquals(bp0.asm_index+3, if_scope.end_instr_index);
			}

			count_equals = AssertEquals(2, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				AssertEquals("x", x_var.name);
				AssertEquals(TypeInfoTag.INTEGER, x_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, x_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, x_var.function_id);

				y_var := c_frame.frame_vars[1];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(if_scope.id, y_var.scope_id);
				AssertEquals(if_scope.function_id, y_var.function_id);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	} 
	case 9; {
		//After the if scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(1, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				AssertEquals("x", x_var.name);
				AssertEquals(TypeInfoTag.INTEGER, x_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, x_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, x_var.function_id);
			}
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

/*TODO Can test inline if-elseif as well
if x == 0 x = 1;
else if x == 1 x = 2;
*/
Test_ElseIf :: (
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
  x : int = 1;
  if x == 0 {
    x = 0;
  } else if x == 1 {
    x = 2;
  }
  x = x + 1;
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
	//TODO We could set the breakpoint directly here if we have an issue. That's what we do later in this test.
	case 2; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 3; DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	case 4; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 5; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 6; {
		//Before the if scope
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

			count_equals = AssertEquals(2, c_frame.all_scopes_in_function.count);
			if count_equals {
				scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_IF, scope.scope_token.token_type);

				scope = c_frame.all_scopes_in_function[1];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_ELSE, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
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
		//ON the if line now. Scope still not open since the if condition is not checked yet.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		bp0 := text_op.exec_info.debug_info.break_points[0];
		AssertEquals(bp0.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			count_equals = AssertEquals(2, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(1, c_frame.frame_vars.count);
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
	case 8; {
		//ON the else if line now. Scope still not open since the else if condition is not checked yet.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		d_line : DebugLine = GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		//NOTE : Need to +2 because of the "}" close scope asm instruction.
		//TODO We can change to +1 when we remove the closing scope instructions
		else_if_index : int = d_line.start_asm_index + 1;
		AssertEquals(else_if_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			count_equals = AssertEquals(2, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(1, c_frame.frame_vars.count);
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
	case 9; {
		//In the if scope now. Scope should be open since the condition is true and we are in the if scope.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			if count_equals {
				if_scope := c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, if_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_ELSE, if_scope.scope_token.token_type);

				d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
				AssertEquals(d_line.start_asm_index, if_scope.start_instr_index);
				// d_line = GetDebugLineNumber(6, text_op.text_comp_data.all_debug_lines);
				AssertEquals(d_line.end_asm_index, if_scope.end_instr_index);
			}
		}

		CodeBPForTest(7, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 10; {
		//After the else if scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(2, c_frame.all_scopes_in_function.count);
			AssertEquals(2, c_frame.s_index);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				AssertEquals("x", x_var.name);
				AssertEquals(TypeInfoTag.INTEGER, x_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, x_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, x_var.function_id);
			}
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//Convenience test function to add breakpoint to line
//since in game the logic is different based on input.
//TODO Remove CompilationData once we have it in DebugInfo
//TODO Should we move this somewhere else?
//TODO Could make this SetBPForTest so we remove breakpoint
CodeBPForTest :: inline (
	line_number : int, 
	d_info : *DebugInfo,
	comp_data : CompilationData,
	abs_path_name : string = "") 
{
	break_point : *DebugBreakpoint = array_add(*d_info.break_points);
	//TODO Could make one for BP_ASM if needed
	break_point.bp_type = .BP_CODE;
	d_line : DebugLine = GetDebugLineNumber(line_number, comp_data.all_debug_lines, abs_path_name);
	break_point.line_number = d_line.line_number;
	break_point.asm_index = d_line.start_asm_index;
	break_point.end_asm_index = d_line.end_asm_index;
}
CodeBPForTestInFile :: inline (
	line_number : int, 
	file_name : string,
	d_info : *DebugInfo,
	comp_data : CompilationData) 
{
	break_point : *DebugBreakpoint = array_add(*d_info.break_points);
	//TODO Could make one for BP_ASM if needed
	break_point.bp_type = .BP_CODE;
	d_line : DebugLine = GetDebugLineNumberInFile(line_number, file_name, comp_data.all_debug_lines);
	break_point.line_number = d_line.line_number;
	break_point.asm_index = d_line.start_asm_index;
	break_point.end_asm_index = d_line.end_asm_index;
}
/*NOTE TODO Could remove breakpoints with this as well and then
reuse this in the code. I think that is a good idea once we know
that the breakpoint code is good so we can functionalize it
and then we write unit tests specifically for those functions
and reuse them. ALSO if we want to create breakpoints from
other places, we would separate out the functionality then.
*/
AsmBPForTest :: inline (
	asm_index : int, 
	d_info : *DebugInfo,
	comp_data : CompilationData) 
{
	break_point : *DebugBreakpoint = array_add(*d_info.break_points);
	break_point.bp_type = .BP_ASM;
	break_point.asm_index = asm_index;
	break_point.end_asm_index = asm_index;
}

/*TEST 
- If we have a range for a BP_CODE then we want to stop within that range on a continue no matter what.
- If we have an asm breakpoint, we want to stop there even if we are not out of a range yet on a continue OR step_over
*/
Test_Breakpoints :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
#string DONE
main :: () {
  a : [3] int;
  for a {
    y : int = it;
  }
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 16);
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
	//Move the arrow down twice so we can remove the breakpoint later.
	case 3; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 6; {
		//Hit the set index instruction for the for scope which we only hit once
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		if count_equals {
			bp0 := text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);	
		}


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	} 
	case 7; {
		//We loop back on the for loop now so we should be stopping on the first breakpoint because it is within
		//range and we are doing a continue and it is a CODE
		//Should be stopping at the second line of the for since the first line is only to set it_index.
		//TEST case where we jmp to an instruction that does not have start_asm_index at the start of a DebugLine
		//but instead we jmp back to the condition to check it_index on the second asm instr of the for loop.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		if count_equals {
			bp0 := text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}


		AsmBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 8; {
		//Should be stopping at the asm breakpoint with a step over
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		if count_equals {
			bp1 := text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 9; {
		//Should be back at the second instr of the for loop breakpoint debugline range.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		if count_equals {
			bp0 := text_op.exec_info.debug_info.break_points[0];
			AssertEquals(bp0.asm_index+1, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	}
	case 10; {
		//Should be stopping at the asm breakpoint with a continue
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		if count_equals {
			bp1 := text_op.exec_info.debug_info.break_points[1];
			AssertEquals(bp1.asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		}

		DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	}
	case 11; {
		//Remove a breakpoint in code window
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		if count_equals {
			bp0 := text_op.exec_info.debug_info.break_points[0];
			AssertEquals(BreakpointType.BP_ASM, bp0.bp_type);
			AssertEquals(4, bp0.asm_index);
			AssertEquals(4, bp0.end_asm_index);
		}


		DownUpInputMap(.TEXT_BOTTOM_LEFT_PANE, game_input);
	}
	case 12; {
		//Move arrow down 4 times
		if perm.test_data.all_sub_tests[perm.test_data.sub_test_index].run_index == 0 {
			perm.test_data.all_sub_tests[perm.test_data.sub_test_index] = SubT(4);
		}
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 13; {
		//Remove the asm breakpoint
		DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	}
	case 14; {
		//Remove a breakpoint in code window
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);
		AssertEquals(0, text_op.exec_info.debug_info.break_points.count);

		DownUpInputMap(.TEXT_STOP, game_input);
	}
	case 15; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(ExecutionState.NOT_RUNNING, text_op.exec_info.exec_state);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

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
Test_ForLoop :: (
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
  for 0..1 {
    x = x + 1;
    y : int = 3;
  }
  x = 2;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 16);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

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
		//In the for scope now - at for 0..1
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
				AssertEquals(bp0.asm_index+7, for_scope.end_instr_index);
			}

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
			count_equals = AssertEquals(3, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(0, it_value);

				y_var := c_frame.frame_vars[2];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(for_scope.id, y_var.scope_id);
				AssertEquals(for_scope.function_id, y_var.function_id);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} 
	case 8; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
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
			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			count_equals = AssertEquals(3, c_frame.frame_vars.count);
		}


		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 9; {
		//At the y : int for the 1st time
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(1, c_frame.call_open_scopes.count);
			AssertEquals(3, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, x_value);
			}
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 10; {
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

			AssertEquals(3, c_frame.frame_vars.count);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
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

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
			count_equals = AssertEquals(3, c_frame.frame_vars.count);
			if count_equals {
				//We increment it at the bottom of the for loop so it should be 1 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(1, it_value);

				y_var := c_frame.frame_vars[2];
				AssertEquals("y", y_var.name);
			}
		}


		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	}
	case 12; {
		//At the y : int for the 2nd time
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		AssertEquals(2, text_op.exec_info.debug_info.break_points.count);
		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(1, c_frame.call_open_scopes.count);
			AssertEquals(3, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				x_value := ComputeOperandInt(x_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, x_value);
			}
		}

		//Check all the variables are correct in the loop in the watch data
		AddWatchDataForTest(.["x", "y", "it"], text_op);
		for 0..text_op.watch_data_rows.count-2 {
			EvaluateWatchData(it, text_op, perm.all_data, true);
		}
		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			x_var : WatchData = text_op.watch_data_rows[0];
			AssertEquals("2", x_var.value_str);
			AssertEquals("int", x_var.type_str);

			y_var : WatchData = text_op.watch_data_rows[1];
			AssertEquals("int", y_var.type_str);

			it_var : WatchData = text_op.watch_data_rows[2];
			AssertEquals("1", it_var.value_str);
			AssertEquals("int", it_var.type_str);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 13; {
		//At the close "}" of the for loop for we add to "it" and reset the scope.
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

			AssertEquals(3, c_frame.frame_vars.count);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 14; {
		//Back at the top for loop for the final check
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

			count_equals = AssertEquals(3, c_frame.frame_vars.count);
			if count_equals {
				//We increment it at the bottom of the for loop so it should be 2 now
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				it_value := ComputeOperandInt(it_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
				AssertEquals(2, it_value);
			}
		}


		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 15; {
		//Out of the for loop now so the for scope should be gone
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals := AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				AssertEquals("x", x_var.name);
			}
		}

		//Check that the y and it var are no longer available but x still is with correct value.
		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			x_var : WatchData = text_op.watch_data_rows[0];
			AssertEquals("2", x_var.value_str);
			AssertEquals("int", x_var.type_str);

			y_var : WatchData = text_op.watch_data_rows[1];
			AssertEquals(true, y_var.is_error);

			it_var : WatchData = text_op.watch_data_rows[2];
			AssertEquals(true, it_var.is_error);
		}
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
				AssertEquals(bp0.asm_index+9, for_scope.end_instr_index);
			}

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
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
			AssertEquals(bp0.asm_index+7, perm.all_data.all_register_memory[RegDef.pc].int_value);
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

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
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

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
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
				AssertEquals(2, it_index_value);
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
				AssertEquals(bp0.asm_index+9, for_scope.end_instr_index);
			}

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
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
			AssertEquals(1, it_index_value);
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
				AssertEquals(0, it_index_value);
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

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
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
				AssertEquals(-1, it_index_value);
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

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
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
				AssertEquals(1, it_index_value);
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

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
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
				AssertEquals(2, it_index_value);
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

/*TODO Need to write tests for (DO UNIT TESTS FIRST TO MAKES SURE JUMP IS ACCURATE)
for 0..10 if x < 0 {
} else if x > 0 {
}
AND ALSO
if x < 0 for 0..10 {
} else if x > 0 {
}
AND ALSO with while loops
Can write small tests just to make sure the scopes are accurate
*/
Test_ForIfLoop :: (
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
  for 0..1 if x < 1 {
    x = x + 1;
    y : int = 3;
  }
  x = 2;
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
	//TODO We could set the breakpoint directly here if we have an issue. That's what we do later in this test.
	case 2; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 3; DownUpInputMap(.DEBUG_SET_BREAKPOINT, game_input);
	case 4; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 5; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 6; {
		//Before the for-if scope
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

			count_equals = AssertEquals(2, c_frame.all_scopes_in_function.count);
			if count_equals {
				while_scope := c_frame.all_scopes_in_function[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, while_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, while_scope.scope_token.token_type);

				if_scope := c_frame.all_scopes_in_function[1];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, if_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_IF, if_scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
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
		//At for 0..1 if x < 1
		//Only have 1 scope open because we did not hit the if scope yet
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
			AssertEquals(2, c_frame.all_scopes_in_function.count);
			AssertEquals(1, c_frame.s_index);

			count_equals = AssertEquals(1, c_frame.call_open_scopes.count);
			for_scope : ScopeData;
			if count_equals {
				//Only open the if scope when we enter the if scope
				for_scope = c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+1, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+9, for_scope.end_instr_index);
			}

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
			count_equals = AssertEquals(2, c_frame.frame_vars.count);
			if count_equals {
				it_var := c_frame.frame_vars[1];
				AssertEquals("it", it_var.name);
				AssertEquals(TypeInfoTag.INTEGER, it_var.t_info.type_enum);
				AssertEquals(for_scope.id, it_var.scope_id);
				AssertEquals(for_scope.function_id, it_var.function_id);
			}
		}

		AddWatchDataForTest(.["x", "it", "y"], text_op);
		for 0..text_op.watch_data_rows.count-2 {
			EvaluateWatchData(it, text_op, perm.all_data, true);
		}
		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			x_var : WatchData = text_op.watch_data_rows[0];
			AssertEquals("x", x_var.name);
			AssertEquals("0", x_var.value_str);
			AssertEquals("int", x_var.type_str);

			it_var : WatchData = text_op.watch_data_rows[1];
			AssertEquals("it", it_var.name);
			AssertEquals("0", it_var.value_str);
			AssertEquals("int", it_var.type_str);

			y_var : WatchData = text_op.watch_data_rows[2];
			AssertEquals(true, y_var.is_error);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	} case 8; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.break_points.count);
		bp0 : DebugBreakpoint;
		if count_equals {
			bp0 = text_op.exec_info.debug_info.break_points[0];
		}

		d_line := GetDebugLineAsm(perm.all_data.all_register_memory[RegDef.pc].int_value, text_op.text_comp_data);
		AssertEquals(3, d_line.line_number);

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			count_equals = AssertEquals(2, c_frame.call_open_scopes.count);
			if_scope : ScopeData;
			if count_equals {
				for_scope := c_frame.call_open_scopes[0];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+1, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+9, for_scope.end_instr_index);

				if_scope = c_frame.call_open_scopes[1];
				AssertEquals(ScopeDataType.CONTROL_SCOPE, if_scope.scope_type);
				AssertEquals(CodeTokenType.KEYWORD_IF, if_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+5, if_scope.start_instr_index);
				AssertEquals(bp0.asm_index+7, if_scope.end_instr_index);
			}

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
			count_equals = AssertEquals(3, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[2];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(if_scope.id, y_var.scope_id);
				AssertEquals(if_scope.function_id, y_var.function_id);
			}
		}

		count_equal := AssertEquals(4, text_op.watch_data_rows.count);
		if count_equal {
			y_var : WatchData = text_op.watch_data_rows[2];
			AssertEquals("y", y_var.name);
			AssertEquals("0", y_var.value_str);
			AssertEquals("int", y_var.type_str);
		}


		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	}
	case 9; {
		//Out of the for-if loop now
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			//No more open scopes since we are out of the for-if loop
			AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals := AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				AssertEquals("x", x_var.name);
			}
		}

		//Check that the y is no longer available but x still is with correct value.
		count_equals = AssertEquals(4, text_op.watch_data_rows.count);
		if count_equals {
			x_var : WatchData = text_op.watch_data_rows[0];
			AssertEquals("1", x_var.value_str);
			AssertEquals("int", x_var.type_str);

			it_var : WatchData = text_op.watch_data_rows[1];
			AssertEquals(true, it_var.is_error);

			y_var : WatchData = text_op.watch_data_rows[2];
			AssertEquals(true, y_var.is_error);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_WhileLoop :: (
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
  while x < 1 {
    x = x + 1;
    y : int = 3;
  }
  x = 2;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 9);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

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
		//Before the while scope
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
				AssertEquals(CodeTokenType.KEYWORD_WHILE, scope.scope_token.token_type);
			}

			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
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
		//In the while scope now - at while x < 1
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
				AssertEquals(CodeTokenType.KEYWORD_WHILE, for_scope.scope_token.token_type);
				AssertEquals(bp0.asm_index+1, for_scope.start_instr_index);
				AssertEquals(bp0.asm_index+6, for_scope.end_instr_index);
			}

			//Note that we have all 3 variables open on the for loop line. This makes sense because we want to
			//see how the variables change through the for loop cycles and not for it to reset each for loop.
			count_equals = AssertEquals(2, c_frame.frame_vars.count);
			if count_equals {
				y_var := c_frame.frame_vars[1];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(for_scope.id, y_var.scope_id);
				AssertEquals(for_scope.function_id, y_var.function_id);
			}
		}

		AddWatchDataForTest(.["x", "y"], text_op);
		for 0..text_op.watch_data_rows.count-2 {
			EvaluateWatchData(it, text_op, perm.all_data, true);
		}
		count_equal := AssertEquals(3, text_op.watch_data_rows.count);
		if count_equal {
			x_var : WatchData = text_op.watch_data_rows[0];
			AssertEquals("0", x_var.value_str);
			AssertEquals("int", x_var.type_str);

			y_var : WatchData = text_op.watch_data_rows[1];
			AssertEquals("int", y_var.type_str);
		}



		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);	
	} 
	case 8; {
		//Out of the while loop now so the while scope should be gone
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(0, c_frame.call_open_scopes.count);
			count_equals := AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				x_var := c_frame.frame_vars[0];
				AssertEquals("x", x_var.name);
			}
		}

		//Check that the y is no longer available but x still is with correct value.
		count_equals = AssertEquals(3, text_op.watch_data_rows.count);
		if count_equals {
			x_var : WatchData = text_op.watch_data_rows[0];
			AssertEquals("1", x_var.value_str);
			AssertEquals("int", x_var.type_str);

			y_var : WatchData = text_op.watch_data_rows[1];
			AssertEquals(true, y_var.is_error);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_compfunc :: (
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
foo :: (x : int) -> int {
  return x + 1;
}
main :: () {
  x : int = foo(1);
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 8);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["ram(0)", "sbp", "scp", "x", "*x", "ram(sbp+0)", "ram(sbp+8)"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		//Before the while scope
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(1, *text_op.exec_info.debug_info, text_op.text_comp_data);
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);		
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		//First function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(d_line.start_asm_index, c_frame.function_scope.start_instr_index);
			AssertEquals(text_op.text_comp_data.all_music_instructions.count-1, c_frame.function_scope.end_instr_index);

			AssertEquals(0, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);
			}
		}	

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 6; {
		//First function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(1, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(d_line.start_asm_index, c_frame.function_scope.start_instr_index);
			AssertEquals(d_line.end_asm_index, c_frame.function_scope.end_instr_index);

			AssertEquals(0, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);
			}

			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("1", x_watch.value_str);
		}

		//Remove line 4 and go to the end so we can check if x was updated
		pop(*text_op.exec_info.debug_info.break_points);
		CodeBPForTest(5, *text_op.exec_info.debug_info, text_op.text_comp_data);		
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 7; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		x_watch := GetWatch("x", text_op.watch_data_rows);
		AssertEquals("2", x_watch.value_str);

		xp_watch := GetWatch("*x", text_op.watch_data_rows);
		AssertEquals("0", xp_watch.value_str);

		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

/*TODO I put all the debug control tests in here but maybe that is confusing and we should separate them into
1 test for each control. That way we can also do more test cases for each control.
Maybe this is ok for now but should do that later for more thorough testing although having this simple one too is good in genereal.
IF WE SEPARATE TESTS we can also show test passed on screen at some point if that helps.
*/
Test_DebugControl :: (
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
foo :: (x : int) -> int {
  return x + 1;
}
main :: () {
  x : int = foo(1);
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 22);
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
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);		
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
		//TEST : STEP_OVER
		//We step over the function call and make sure we are at the end of the function.
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		AssertEquals(perm.all_data.all_music_instructions.count-1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	} 
	case 6; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .NOT_RUNNING);	

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 7; {
		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	} 
	case 8; {
		//TEST : STEP_INTO
		//We step into the functioncal and make sure we are in the function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		d_line := GetDebugLineNumber(1, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		DownUpInputMap(.DEBUG_STEP_OUT, game_input);
	}
	case 9; {
		//TEST : STEP_OUT
		//We step out of the function and make sure we are back at the instruction after the call instruction
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index {
			if perm.all_data.all_music_instructions[it].op_code == OpCode.call {
				after_call_index = it + 1;
				break;
			}
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		//TEST : Try step over to see we go to end of main function
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 10; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		AssertEquals(perm.all_data.all_music_instructions.count-1, perm.all_data.all_register_memory[RegDef.pc].int_value);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .NOT_RUNNING);	

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 12; {
		//SWITCH TO ASM HERE AND TEST ASM STEP_OVER AND THEN ASM_STEP_INTO
		//TEST : ASM_STEP_OVER
		DownUpInputMap(.TEXT_BOTTOM_LEFT_PANE, game_input);
	}
	case 13; {
		//Repeat the step over until the end so we make sure that we skip over the call instruction
		if perm.test_data.all_sub_tests[perm.test_data.sub_test_index].run_index == 0 {
			text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
			d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
			instr_count : int = d_line.end_asm_index - d_line.start_asm_index + 1;
			perm.test_data.all_sub_tests[perm.test_data.sub_test_index] = SubT(instr_count);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	} case 14; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		AssertEquals(perm.all_data.all_music_instructions.count-1, perm.all_data.all_register_memory[RegDef.pc].int_value);		

		//TEST : Restart the execution to test
		DownUpInputMap(.TEXT_RESTART, game_input);
	}
	case 15; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);		
	}
	case 16; {
		//TEST : ASM_STEP_INTO
		if perm.test_data.all_sub_tests[perm.test_data.sub_test_index].run_index == 0 {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
			d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
			for d_line.start_asm_index..d_line.end_asm_index {
				if perm.all_data.all_music_instructions[it].op_code == OpCode.call {
					count_to_call : int = it - d_line.start_asm_index + 1;
					perm.test_data.all_sub_tests[perm.test_data.sub_test_index] = SubT(count_to_call);
					break;
				}
			}
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	} 
	case 17; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		d_line := GetDebugLineNumber(1, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);		

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 18; {
		//We run execution here again to test stop from starting
		//TEST : TEXT_STOP
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 19; {
		//Test stop right after execution
		DownUpInputMap(.TEXT_STOP, game_input);
	}
	case 20; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .NOT_RUNNING);	

		//Start again to make sure it's working
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 21; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);				
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_InstrPerFrame :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
#string DONE
main :: () {
  while 0 < 1 {}
}
DONE);
		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		CreateTextOpSpace(.[text_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data,
			op_space_name = TEXT_2_NAME);
	
		array_resize(*perm.test_data.all_sub_tests, 17+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test_2 := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test_2);

		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		perm.all_data.runtime_settings.asm_instructions_per_frame = 1;

		AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_space := perm.all_data.all_open_op_spaces[0];

		move_op_2 := MakeTerminalEvent(.move_op, TEXT_2_NAME,
			tprint("%", op_space.world_offset.x+op_space.world_size.x/2), tprint("%", op_space.world_offset.y));
		array_add(*perm.all_data.all_terminal_events, move_op_2);

		move_op := MakeTerminalEvent(.move_op, TEST_TEXT_NAME,
			tprint("%", op_space.world_offset.x-op_space.world_size.x/2), tprint("%", op_space.world_offset.y));
		array_add(*perm.all_data.all_terminal_events, move_op);
	}
	case 4; {
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		AssertEquals(1, perm.all_data.all_process_instruction_events.count);

		open_test_2 := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test_2);
	}
	case 6; {
		AssertEquals(1, perm.all_data.all_process_instruction_events.count);

		DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	}
	case 7; {
		//TEST compiling another op while this one is executing should work
		DownUpInputMap(.TEXT_COMPILE, game_input);
	}
	case 8; {
		count_equals := AssertEquals(1, perm.all_data.all_process_instruction_events.count);
		if count_equals {
			AssertEquals(0, perm.all_data.all_process_instruction_events[0].op_space_id);
		}

		text_op_2 : TextOpSpaceData = perm.all_data.all_text_op_space_data[1];
		AssertEquals(true, text_op_2.text_comp_data.all_music_instructions.count > 0);

		//TEST executing another op while one is executing should not work
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 9; {
		count_equals := AssertEquals(1, perm.all_data.all_process_instruction_events.count);
		if count_equals {
			AssertEquals(0, perm.all_data.all_process_instruction_events[0].op_space_id);
		}

		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 10; {
		//TODO I think we should update this to a struct with a bool instead of an array for clarity
		//TEST RUN a few more times and then stop to make sure execution stopping is ok
		RunSubTestNTimes(5, *perm.test_data);
	}
	case 11; {
		DownUpInputMap(.TEXT_STOP, game_input);
	}
	case 12; {
		AssertEquals(0, perm.all_data.all_process_instruction_events.count);

		//TEST that we can execute the other op space now that we stopped the other one
		open_test := MakeTerminalEvent(.open_op, TEXT_2_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 13; {
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 14; {
		count_equals := AssertEquals(1, perm.all_data.all_process_instruction_events.count);
		if count_equals {
			AssertEquals(1, perm.all_data.all_process_instruction_events[0].op_space_id);
		}		
	}
	case 15; {
		//TEST RUN a few more times and then stop to make sure execution stopping is ok
		RunSubTestNTimes(5, *perm.test_data);
	}
	case 16; {
		DownUpInputMap(.TEXT_STOP, game_input);
	}
	case 17; {
		AssertEquals(0, perm.all_data.all_process_instruction_events.count);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_FixedMainCompile :: (
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

		empty_file, load_success := LoadTextFile("c_test/empty_test", *perm.all_data.all_text_files);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
	x : int = 0;
}
DONE);

		// if load_success array_add(*perm.all_data.all_text_files, empty_file);
		text_op := CreateTextOpSpace(.[text_file.id, empty_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		array_resize(*perm.test_data.all_sub_tests, 11+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 3; {
		count_equals := AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op := perm.all_data.all_text_op_space_data[0];
			AssertEquals(false, text_op.set_fixed_main_compile);
		}

		DownUpInputMap(.TEXT_SET_FIXED_MAIN_COMPILE, game_input);
	}
	case 4; {
		count_equals := AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op := perm.all_data.all_text_op_space_data[0];
			AssertEquals(true, text_op.set_fixed_main_compile);
			AssertEquals(true, text_op.text_status_timer > 0);

			count_equals = AssertEquals(2, perm.all_data.all_text_files.count);
			if count_equals {
				AssertEquals(perm.all_data.all_text_files[1].id, text_op.main_compile_text_file_id);
			}
		}

		//TEST Compile a file thats fixed when it is not the current tab
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 5; {
		DownUpInputMap(.TEXT_COMPILE, game_input);
	}
	case 6; {
		count_equals := AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op := perm.all_data.all_text_op_space_data[0];
			AssertEquals(true, text_op.set_fixed_main_compile);

			not_null : bool = AssertEquals(true, text_op.text_comp_data != null);
			if not_null {
				AssertEquals(true, text_op.text_comp_data.all_music_instructions.count > 0);
			}
				AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		}

		//TEST Unset and make sure there is no compilation since it's an empty file
		DownUpInputMap(.TEXT_SET_FIXED_MAIN_COMPILE, game_input);
	}
	case 7; {
		count_equals := AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op := perm.all_data.all_text_op_space_data[0];
			AssertEquals(false, text_op.set_fixed_main_compile);
		}
	}
	case 8; {
		//TEST That we are compiling the current file and that there are errors since its not good
		DownUpInputMap(.TEXT_COMPILE, game_input);
	}
	case 9; {
		count_equals := AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op := perm.all_data.all_text_op_space_data[0];
			AssertEquals(true, text_op.text_comp_data.comp_errors.all_compiler_errors.count > 0);
		}

		//TEST WE compile the current file we are on which is compilable now without the set main
		DownUpInputMap(.TEXT_FILE_TAB_RIGHT, game_input);
	}
	case 10; {
		count_equals := AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op := perm.all_data.all_text_op_space_data[0];
			AssertEquals(false, text_op.set_fixed_main_compile);
		}

		//TEST WE compile the current file we are on which is compilable now without the set main
		DownUpInputMap(.TEXT_COMPILE, game_input);
	}
	case 11; {
		count_equals := AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		if count_equals {
			text_op := perm.all_data.all_text_op_space_data[0];
			not_null : bool = AssertEquals(true, text_op.text_comp_data != null);
			if not_null {
				AssertEquals(true, text_op.text_comp_data.all_music_instructions.count > 0);
			}
				AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO FROM HERE start updating function calls so we remove return pointers and also start removing scope reset.
//Then update unit tests and get this test working since it does not right now because of return pointers.
//For disassembly, I think we can do sbp+-10 -> sbp-10 if the second operand is a negative integer.
//TODO  Replace Test_compfunc with this once we have functions working more clearly.
Test_compfunc2 :: (
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
foo :: (x : int) -> int {
  return x + 1;
}
main :: () {
  x : int = foo2(1);
}
foo2 :: (x : int) -> int {
  return foo(x) + foo(x);
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 20);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["ram(0)", "sbp", "x", "*x"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		//Main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals(d_line.start_asm_index, c_frame.function_scope.start_instr_index);
			AssertEquals(d_line.end_asm_index+1, c_frame.function_scope.end_instr_index);
			AssertEquals("main", c_frame.func_decl.name);

			AssertEquals(0, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 6; {
		//foo2 function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo2_frame.function_scope.scope_type);
			AssertEquals(d_line.start_asm_index, foo2_frame.function_scope.start_instr_index);
			AssertEquals(d_line.end_asm_index, foo2_frame.function_scope.end_instr_index);
			AssertEquals("foo2", foo2_frame.func_decl.name);

			AssertEquals(0, foo2_frame.all_scopes_in_function.count);
			AssertEquals(0, foo2_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, foo2_frame.frame_vars.count);
			if count_equals {
				var := foo2_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(foo2_frame.function_scope.id, var.scope_id);
				AssertEquals(foo2_frame.function_scope.function_id, var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("1", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 7; {
		//foo function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(1, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
			foo2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals("foo2", foo2_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[2];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
			AssertEquals(d_line.start_asm_index, foo_frame.function_scope.start_instr_index);
			AssertEquals(d_line.end_asm_index, foo_frame.function_scope.end_instr_index);
			AssertEquals("foo", foo_frame.func_decl.name);

			AssertEquals(0, foo_frame.all_scopes_in_function.count);
			AssertEquals(0, foo_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, foo_frame.frame_vars.count);
			if count_equals {
				var := foo_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(foo_frame.function_scope.id, var.scope_id);
				AssertEquals(foo_frame.function_scope.function_id, var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("1", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 8; {
		//foo2 function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index {
			if perm.all_data.all_music_instructions[it].op_code == .call {
				after_call_index = it + 1;
				break;
			}
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo2_frame.function_scope.scope_type);
			AssertEquals(d_line.start_asm_index, foo2_frame.function_scope.start_instr_index);
			AssertEquals(d_line.end_asm_index, foo2_frame.function_scope.end_instr_index);
			AssertEquals("foo2", foo2_frame.func_decl.name);

			AssertEquals(0, foo2_frame.all_scopes_in_function.count);
			AssertEquals(0, foo2_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, foo2_frame.frame_vars.count);
			if count_equals {
				var := foo2_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(foo2_frame.function_scope.id, var.scope_id);
				AssertEquals(foo2_frame.function_scope.function_id, var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("1", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 9; {
		//foo function - 2nd time
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(1, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
			foo2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals("foo2", foo2_frame.func_decl.name);
			foo_frame := text_op.exec_info.debug_info.debug_call_stack[2];
			AssertEquals("foo", foo_frame.func_decl.name);
			count_equals = AssertEquals(1, foo_frame.frame_vars.count);
			if count_equals {
				var := foo_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(foo_frame.function_scope.id, var.scope_id);
				AssertEquals(foo_frame.function_scope.function_id, var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("1", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 10; {
		//foo2 function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		after_call2_index : int;
		call_2 : int;
		for d_line.start_asm_index..d_line.end_asm_index {
			if perm.all_data.all_music_instructions[it].op_code == .call {
				if call_2 > 0 {
					after_call2_index = it + 1;
					break;
				} else {
					call_2 += 1;
				}
			}
		}
		AssertEquals(after_call2_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo2_frame.function_scope.scope_type);
			AssertEquals(d_line.start_asm_index, foo2_frame.function_scope.start_instr_index);
			AssertEquals(d_line.end_asm_index, foo2_frame.function_scope.end_instr_index);
			AssertEquals("foo2", foo2_frame.func_decl.name);

			AssertEquals(0, foo2_frame.all_scopes_in_function.count);
			AssertEquals(0, foo2_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, foo2_frame.frame_vars.count);
			if count_equals {
				var := foo2_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(foo2_frame.function_scope.id, var.scope_id);
				AssertEquals(foo2_frame.function_scope.function_id, var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("1", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		//Main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index {
			if perm.all_data.all_music_instructions[it].op_code == .call {
				after_call_index = it + 1;
				break;
			}
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", c_frame.func_decl.name);
			count_equals = AssertEquals(1, c_frame.frame_vars.count);
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
	case 12; {
		//Main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", c_frame.func_decl.name);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 13; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 14;DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	case 15; {
		//TEST Skip over double functions in foo2
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", c_frame.func_decl.name);
			foo2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals("foo2", foo2_frame.func_decl.name);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("1", x_watch.value_str);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 16; {
		//TEST Skip over double functions in foo2
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index {
			if perm.all_data.all_music_instructions[it].op_code == .call {
				after_call_index = it + 1;
				break;
			}
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", c_frame.func_decl.name);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);
			}
		}	

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 17; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 18; {
		//TEST Skip over FIRST FUNCTION CALL
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", c_frame.func_decl.name);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
			}
		}

		//TEST Skip over FIRST FUNCTION CALL
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	// case 19; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 19; {
		//TEST Skip over FIRST FUNCTION CALL
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", c_frame.func_decl.name);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("4", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

/*TODO Should likely use this everywhere now. 
REMINDER IMPOERANT I think we should be going until after pop_all_stack_reg otherwise the watch values are not
correct until we pop the sbp to the previous stack which only happens after pop_all_stack_reg
Then if we use this function everywhere, we can just change it to after pop_all_stack_reg
*/
GetAfterCallIndex :: inline (d_line : DebugLine, all_music_instruction : [] MusicInstruction) -> int {
	after_call_index : int = -1;
	for d_line.start_asm_index..d_line.end_asm_index {
		if all_music_instruction[it].op_code == .call {
			after_call_index = it + 1;
			break;
		}
	}
	return after_call_index;
}
Test_FuncWithPointer :: (
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
  x : int = 3;
  foo(*x);
  f2(**x);
}
foo :: (xp : *int) {
  xp.* = 10;
}
f2 :: (xpp : **int) {
  xpp.*.* = 20;
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
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["x", "*x", "xp", "xpp"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		//Main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals("main", c_frame.func_decl.name);

			AssertEquals(0, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
			if count_equals {
				var := c_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, var.function_id);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 6; {
		//foo function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(6, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
			AssertEquals("foo", foo_frame.func_decl.name);

			AssertEquals(0, foo_frame.all_scopes_in_function.count);
			AssertEquals(0, foo_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, foo_frame.frame_vars.count);
			if count_equals {
				int_p_info := GetTypeInfoPointer(*text_op.text_comp_data.int_type_info, text_op.text_comp_data);
				var := foo_frame.frame_vars[0];
				AssertEquals("xp", var.name);
				AssertEquals(TypeInfoTag.POINTER, var.t_info.type_enum);
				AssertEquals(*int_p_info.info, var.t_info);
				AssertEquals(foo_frame.function_scope.id, var.scope_id);
				AssertEquals(foo_frame.function_scope.function_id, var.function_id);

				xp_watch := GetWatch("xp", text_op.watch_data_rows);
				AssertEquals("0", xp_watch.value_str);
			}
		}

		//Should stop at the bp on line 2 in main
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 7; {
		//back to main
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		after_call_index := GetAfterCallIndex(d_line, perm.all_data.all_music_instructions);
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);


		//TODO IMPORANT Need to remove this so we go back to after pop_all_stack_reg so that the watch values are correct
		//for the return stack frame
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 8; {
		//back to main
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(3, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			count_equals = AssertEquals(1, main_frame.frame_vars.count);
			if count_equals {
				var := main_frame.frame_vars[0];
				AssertEquals("x", var.name);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("10", x_watch.value_str);

				xp_watch := GetWatch("*x", text_op.watch_data_rows);
				AssertEquals("0", xp_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 9; {
		//foo function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(9, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			f2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, f2_frame.function_scope.scope_type);
			AssertEquals("f2", f2_frame.func_decl.name);

			AssertEquals(0, f2_frame.all_scopes_in_function.count);
			AssertEquals(0, f2_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, f2_frame.frame_vars.count);
			if count_equals {
				int_p_info := GetTypeInfoPointer(*text_op.text_comp_data.int_type_info, text_op.text_comp_data);
				p2_info := GetTypeInfoPointer(*int_p_info.info, text_op.text_comp_data);
				var := f2_frame.frame_vars[0];
				AssertEquals("xpp", var.name);
				AssertEquals(TypeInfoTag.POINTER, var.t_info.type_enum);
				AssertEquals(*p2_info.info, var.t_info);
				AssertEquals(f2_frame.function_scope.id, var.scope_id);
				AssertEquals(f2_frame.function_scope.function_id, var.function_id);

				xpp_watch := GetWatch("xpp", text_op.watch_data_rows);
				AssertEquals("8", xpp_watch.value_str);
			}
		}

		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 10; {
		//back to main
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			count_equals = AssertEquals(1, main_frame.frame_vars.count);
			if count_equals {
				var := main_frame.frame_vars[0];
				AssertEquals("x", var.name);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("20", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_FuncWithArray :: (
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
//TODO Eventually we can auto-cast the array
//but it's annoying because we have to check each array type
//since we could possibly have the same function with different fixed array or array view.
//TODO Could implement this casting eventually
// foo(cast([] int) fa);
#string DONE
main :: () {
  fa : [2] int = int.[0,1];
  f2(fa);
  av : [] int = fa;
  foo(av);
}
foo :: (a : [] int) {
  a[1] = 2;
}
f2 :: (a : [2] int) {
  a[1] = 3;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 27);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["fa", "av", "a", "*a"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		//Main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals("main", c_frame.func_decl.name);

			AssertEquals(0, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(2, c_frame.frame_vars.count);
			if count_equals {
				fa_var := c_frame.frame_vars[0];
				AssertEquals("fa", fa_var.name);
				AssertEquals(TypeInfoTag.ARRAY, fa_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, fa_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, fa_var.function_id);

				av_var := c_frame.frame_vars[1];
				AssertEquals("av", av_var.name);
				AssertEquals(TypeInfoTag.ARRAY, av_var.t_info.type_enum);
				AssertEquals(c_frame.function_scope.id, av_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, av_var.function_id);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 6; {
		//foo function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		cd := text_op.text_comp_data;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(10, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			f2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, f2_frame.function_scope.scope_type);
			AssertEquals("f2", f2_frame.func_decl.name);

			AssertEquals(0, f2_frame.all_scopes_in_function.count);
			AssertEquals(0, f2_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, f2_frame.frame_vars.count);
			if count_equals {
				fa_info, found_fa_info := GetArrayType(cd, *cd.int_type_info, .FIXED, 2);
				AssertEquals(true, found_fa_info);

				a_var := f2_frame.frame_vars[0];
				AssertEquals("a", a_var.name);
				AssertEquals(TypeInfoTag.ARRAY, a_var.t_info.type_enum);
				AssertEquals(*fa_info.info, a_var.t_info);
				AssertEquals(f2_frame.function_scope.id, a_var.scope_id);
				AssertEquals(f2_frame.function_scope.function_id, a_var.function_id);

				//TODO Drop this to check values in watch window
				a_watch := GetWatch("a", text_op.watch_data_rows);
				AssertEquals("[2] int", a_watch.type_str);
			}
		}

		DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	}
	case 7; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 8; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 9; DownUpThisFrame(.ENTER, game_input);
	case 10; {
		//f2 function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(10, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			f2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, f2_frame.function_scope.scope_type);
			AssertEquals("f2", f2_frame.func_decl.name);
		}

		count_equals = AssertEquals(7, text_op.watch_data_rows.count);
		if count_equals {
			a_0 := GetWatch("a[0]", text_op.watch_data_rows);
			AssertEquals("a[0]", a_0.name);
			AssertEquals("[0]", a_0.display_name);
			AssertEquals("0", a_0.value_str);

			a_1 := GetWatch("a[1]", text_op.watch_data_rows);
			AssertEquals("a[1]", a_1.name);
			AssertEquals("[1]", a_1.display_name);
			AssertEquals("1", a_1.value_str);

			sa := GetWatch("*a", text_op.watch_data_rows);
			AssertEquals("*a", sa.name);
			AssertEquals("*a", sa.display_name);

			a := GetWatch("a", text_op.watch_data_rows);
			//stack_size + (fa : [2] int from main)
			sa_pos : int = PRE_PROC_STACK_SIZE + a.node.code_ir.t_info.runtime_size;
			AssertEquals(sprint("%",sa_pos), sa.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		//f2 function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(11, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			f2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, f2_frame.function_scope.scope_type);
			AssertEquals("f2", f2_frame.func_decl.name);
		}

		count_equals = AssertEquals(7, text_op.watch_data_rows.count);
		if count_equals {
			a_0 := GetWatch("a[0]", text_op.watch_data_rows);
			AssertEquals("a[0]", a_0.name);
			AssertEquals("[0]", a_0.display_name);
			AssertEquals("0", a_0.value_str);

			a_1 := GetWatch("a[1]", text_op.watch_data_rows);
			AssertEquals("a[1]", a_1.name);
			AssertEquals("[1]", a_1.display_name);
			AssertEquals("3", a_1.value_str);
		}

		//back in main
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 12; {
		//main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	
		//Should have removed the 2 array values since a is not variable anymore
		AssertEquals(5, text_op.watch_data_rows.count);

		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 13; DownUpThisFrame(.ARROW_UP, game_input);
	case 14; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 15; DownUpThisFrame(.ENTER, game_input);
	case 16; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 17; {
		//main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(7, text_op.watch_data_rows.count);
		if count_equals {
			fa_0 := GetWatch("fa[0]", text_op.watch_data_rows);
			AssertEquals("fa[0]", fa_0.name);
			AssertEquals("[0]", fa_0.display_name);
			AssertEquals("0", fa_0.value_str);

			fa_1 := GetWatch("fa[1]", text_op.watch_data_rows);
			AssertEquals("fa[1]", fa_1.name);
			AssertEquals("[1]", fa_1.display_name);
			AssertEquals("1", fa_1.value_str);

			sa := GetWatch("*a", text_op.watch_data_rows);
			AssertEquals("*a", sa.name);
			AssertEquals("*a", sa.display_name);

			fa := GetWatch("fa", text_op.watch_data_rows);
			sa_pos : int = fa.node.code_ir.t_info.runtime_size;
			AssertEquals(true, sa.is_error);
			// AssertEquals("a is unknown identifier", sa.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 18; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 19; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 20; DownUpThisFrame(.ARROW_DOWN, game_input);
	case 21; DownUpThisFrame(.ENTER, game_input);
	case 22; {
		//foo function end check
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(8, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
			AssertEquals("foo", foo_frame.func_decl.name);
		}

		count_equals = AssertEquals(7, text_op.watch_data_rows.count);
		if count_equals {
			a_0 := GetWatch("a[0]", text_op.watch_data_rows);
			AssertEquals("a[0]", a_0.name);
			AssertEquals("[0]", a_0.display_name);
			AssertEquals("0", a_0.value_str);

			a_1 := GetWatch("a[1]", text_op.watch_data_rows);
			AssertEquals("a[1]", a_1.name);
			AssertEquals("[1]", a_1.display_name);
			AssertEquals("2", a_1.value_str);

			sa := GetWatch("*a", text_op.watch_data_rows);
			AssertEquals("*a", sa.name);
			AssertEquals("*a", sa.display_name);

			a := GetWatch("a", text_op.watch_data_rows);
			//stack_size + 2 * (fa and a : [2] int from main)
			sa_pos : int = PRE_PROC_STACK_SIZE + 2 * a.node.code_ir.t_info.runtime_size;
			AssertEquals(sprint("%",sa_pos), sa.value_str);
		}

		//Back to main
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	//Step over pop stack reg
	case 23; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 24; DownUpThisFrame(.ARROW_UP, game_input);
	case 25; DownUpThisFrame(.ENTER, game_input);
	case 26; {
		//end of main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(7, text_op.watch_data_rows.count);
		if count_equals {
			av_0 := GetWatch("av[0]", text_op.watch_data_rows);
			AssertEquals("av[0]", av_0.name);
			AssertEquals("[0]", av_0.display_name);
			AssertEquals("0", av_0.value_str);

			av_1 := GetWatch("av[1]", text_op.watch_data_rows);
			AssertEquals("av[1]", av_1.name);
			AssertEquals("[1]", av_1.display_name);
			AssertEquals("2", av_1.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_FuncWithStruct :: (
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
#string DONE
main :: () {
  v : V2;
  v.x = 1.;
  v0 := foo(v);
}
V2 :: struct {
  x : float;
  y : float;
}
foo :: (v : V2) -> V2 {
  return v;
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
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["v", "v0"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		//Main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		cd := text_op.text_comp_data;
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(3, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals("main", c_frame.func_decl.name);

			AssertEquals(0, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(2, c_frame.frame_vars.count);
			if count_equals {
				v2_info, found_fa_info := GetTypeInfoStructByName("V2", cd.all_type_info_struct);
				AssertEquals(true, found_fa_info);

				v_var := c_frame.frame_vars[0];
				AssertEquals("v", v_var.name);
				AssertEquals(TypeInfoTag.STRUCT, v_var.t_info.type_enum);
				AssertEquals(*v2_info.info, v_var.t_info);
				AssertEquals(c_frame.function_scope.id, v_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, v_var.function_id);

				v0_var := c_frame.frame_vars[1];
				AssertEquals("v0", v0_var.name);
				AssertEquals(TypeInfoTag.STRUCT, v0_var.t_info.type_enum);
				AssertEquals(*v2_info.info, v0_var.t_info);
				AssertEquals(c_frame.function_scope.id, v0_var.scope_id);
				AssertEquals(c_frame.function_scope.function_id, v0_var.function_id);
			}
		}	

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 6; DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	case 7; DownUpThisFrame(.ENTER, game_input);
	case 8; {
		//foo function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(10, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
			AssertEquals("foo", foo_frame.func_decl.name);
		}

		count_equals = AssertEquals(5, text_op.watch_data_rows.count);
		if count_equals {
			v_x := GetWatch("v.x", text_op.watch_data_rows);
			AssertEquals("v.x", v_x.name);
			AssertEquals("x", v_x.display_name);
			AssertEquals("1", v_x.value_str);

			v_y := GetWatch("v.y", text_op.watch_data_rows);
			AssertEquals("v.y", v_y.name);
			AssertEquals("y", v_y.display_name);
			AssertEquals("0", v_y.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	//back in main
	case 9; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 10; {
		//main function exit
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(5, text_op.watch_data_rows.count);
		if count_equals {
			v_x := GetWatch("v.x", text_op.watch_data_rows);
			AssertEquals("v.x", v_x.name);
			AssertEquals("x", v_x.display_name);
			AssertEquals("1", v_x.value_str);

			v_y := GetWatch("v.y", text_op.watch_data_rows);
			AssertEquals("v.y", v_y.name);
			AssertEquals("y", v_y.display_name);
			AssertEquals("0", v_y.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO Should we rename this call stack test
/*DOC : This tests the call stack and moving around it as well as recursive function
*/
TEST_RECURSE_STRING :: #string DONE
foo :: (x : int) -> int {
  if x == 10 {
    return x;
  } else {
    return foo(x + 1);
  }
}
main :: () {
  x : int = foo(1);
}
DONE;
Test_FuncRecurse :: (
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
		WriteFileString(text_file, TEST_RECURSE_STRING);
		
		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 32);
		//10 recursions in foo since each recursion is 2 step into because we hit the if and then the return foo
		//and 1 to step into foo from main.
		perm.test_data.all_sub_tests[10] = SubT(19);
		perm.test_data.all_sub_tests[14] = SubT(8);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["ram(0)", "sbp", "x", "*x"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(8, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	case 6; DownUpInputMap(.TEXT_BOTTOM_RIGHT_PANE, game_input);
	case 7; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(1, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(0, text_op.exec_info.debug_info.selected_call_frame_index);
		AssertEquals(0, text_op.highlighted_call_stack_index);
		AssertEquals(0, text_op.start_call_stack_index);
		AssertEquals(8, text_op.end_call_stack_index);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
			// AssertEquals(d_line.start_asm_index, foo_frame.function_scope.start_instr_index);
			// AssertEquals(d_line.end_asm_index, foo_frame.function_scope.end_instr_index);
			AssertEquals("foo", foo_frame.func_decl.name);
			AssertEquals(2, foo_frame.all_scopes_in_function.count);
			AssertEquals(0, foo_frame.call_open_scopes.count);


			count_equals = AssertEquals(1, foo_frame.frame_vars.count);
			if count_equals {
				var := foo_frame.frame_vars[0];
				AssertEquals("x", var.name);
				AssertEquals(TypeInfoTag.INTEGER, var.t_info.type_enum);
				AssertEquals(foo_frame.function_scope.id, var.scope_id);
				AssertEquals(foo_frame.function_scope.function_id, var.function_id);

			}

			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("1", x_watch.value_str);
		}

		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 8; {
		DownUpThisFrame(.ENTER, game_input);
	}
	case 9; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(1, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		AssertEquals(true, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(0, text_op.exec_info.debug_info.selected_call_frame_index);
		AssertEquals(1, text_op.highlighted_call_stack_index);
		AssertEquals(0, text_op.start_call_stack_index);
		AssertEquals(8, text_op.end_call_stack_index);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("0", x_watch.value_str);
		}
	}
	case 10; {	
		//TEST go all the way down the recursion
		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 11; {
		//TEST stop at recursion base case "return x";
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);

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

		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 12; DownUpThisFrame(.ENTER, game_input);
	case 13; {
		//TEST check 1 stack frame down the recursion
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		AssertEquals(1, text_op.highlighted_call_stack_index);
		AssertEquals(true, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(9, text_op.exec_info.debug_info.selected_call_frame_index);

		count_equals := AssertEquals(11, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("9", x_watch.value_str);
		}
	}
	case 14; {
		//Go down 8 times to check the last foo
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 15; DownUpThisFrame(.ENTER, game_input);
	case 16; {
		//TEST Stop at the last recursion and move the call stack ui
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		//Selected call frame is array index BUT highlighted is rendering from the top so they should be inversed
		AssertEquals(true, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(1, text_op.exec_info.debug_info.selected_call_frame_index);
		AssertEquals(9, text_op.highlighted_call_stack_index);
		AssertEquals(1, text_op.start_call_stack_index);
		AssertEquals(9, text_op.end_call_stack_index);

		count_equals := AssertEquals(11, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("1", x_watch.value_str);
		}

		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 17; DownUpThisFrame(.ENTER, game_input);
	case 18; {
		//TEST stop at main and move the call stack ui
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		//Selected call frame is array index BUT highlighted is rendering from the top so they should be inversed
		AssertEquals(true, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(0, text_op.exec_info.debug_info.selected_call_frame_index);
		AssertEquals(10, text_op.highlighted_call_stack_index);
		AssertEquals(2, text_op.start_call_stack_index);
		AssertEquals(10, text_op.end_call_stack_index);

		count_equals := AssertEquals(11, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("0", x_watch.value_str);
		}

		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 19; {
		//TEST call stack ui did not move since we are at the bottom
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		AssertEquals(true, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(0, text_op.exec_info.debug_info.selected_call_frame_index);
		AssertEquals(10, text_op.highlighted_call_stack_index);
		AssertEquals(2, text_op.start_call_stack_index);
		AssertEquals(10, text_op.end_call_stack_index);


		//TEST resetting the call stack to top on a move
		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 20; {
		//TEST stop at main and move the call stack ui
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index if perm.all_data.all_music_instructions[it].op_code == .call {
			after_call_index = it + 1;
			break;
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		//Selected call frame is array index BUT highlighted is rendering from the top so they should be inversed
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(0, text_op.exec_info.debug_info.selected_call_frame_index);
		AssertEquals(0, text_op.highlighted_call_stack_index);
		AssertEquals(0, text_op.start_call_stack_index);
		AssertEquals(8, text_op.end_call_stack_index);

		count_equals := AssertEquals(10, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("9", x_watch.value_str);
			//REMINDER RESOLVED A BUG HERE without srp when using sbp instead before popping
			// AssertEquals("10", x_watch.value_str);
		}


		//TEST removing entire stack frame after jumping out of recursion
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 21; {
		//TEST stop at main and move the call stack ui
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(8, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index if perm.all_data.all_music_instructions[it].op_code == .call {
			after_call_index = it + 1;
			break;
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		//Selected call frame is array index BUT highlighted is rendering from the top so they should be inversed
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(0, text_op.exec_info.debug_info.selected_call_frame_index);
		AssertEquals(0, text_op.highlighted_call_stack_index);
		AssertEquals(0, text_op.start_call_stack_index);
		AssertEquals(8, text_op.end_call_stack_index);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);


		//TEST removing entire stack frame after jumping out of recursion
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 22; {
		//TEST make sure we have correct output of 10 at the end
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(9, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		//Selected call frame is array index BUT highlighted is rendering from the top so they should be inversed
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);
		AssertEquals(0, text_op.exec_info.debug_info.selected_call_frame_index);
		AssertEquals(0, text_op.highlighted_call_stack_index);
		AssertEquals(0, text_op.start_call_stack_index);
		AssertEquals(8, text_op.end_call_stack_index);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("10", x_watch.value_str);
		}

		//TEST removing entire stack frame after jumping out of recursion
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 23; {
		//TEST going into 1 recursion and then jumping out on a debug step over
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 24; {
		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 25; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(1, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);

			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("1", x_watch.value_str);
		}

		DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 26; {
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 27; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(8, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index if perm.all_data.all_music_instructions[it].op_code == .call {
			after_call_index = it + 1;
			break;
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 28; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(9, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("10", x_watch.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 29; {
		//TEST Skip over entire recursion function call
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 30; {
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 31; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(9, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);
		AssertEquals(false, text_op.exec_info.debug_info.chose_other_call_frame);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			x_watch := GetWatch("x", text_op.watch_data_rows);
			AssertEquals("10", x_watch.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_FuncPointer :: (
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
  y := Apply(2, Foo);
}
Foo :: (x : int) -> int {
  return x + 1;
}
Apply :: (i : int, fp : (int) -> int) -> int {
  ri : int = fp(i);
  return ri;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 12);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["y", "i", "ri", "x", "fp"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(1, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
		// DownUpInputMap(.TEXT_BOTTOM_RIGHT_PANE, game_input);
	}
	case 6; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
			AssertEquals("Apply", foo_frame.func_decl.name);

			i_watch := GetWatch("i", text_op.watch_data_rows);
			AssertEquals("2", i_watch.value_str);

			fp_watch := GetWatch("fp", text_op.watch_data_rows);
			AssertEquals("10", fp_watch.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 7; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(3, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			apply_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, apply_frame.function_scope.scope_type);
			AssertEquals("Apply", apply_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[2];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
			AssertEquals("Foo", foo_frame.func_decl.name);
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 8; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index {
			if perm.all_data.all_music_instructions[it].op_code == OpCode.call {
				after_call_index = it + 1;
				break;
			}
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			apply_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, apply_frame.function_scope.scope_type);
			AssertEquals("Apply", apply_frame.func_decl.name);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 9; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(8, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			apply_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, apply_frame.function_scope.scope_type);
			AssertEquals("Apply", apply_frame.func_decl.name);

			x_watch := GetWatch("ri", text_op.watch_data_rows);
			AssertEquals("3", x_watch.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 10; {
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 11; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			y_watch := GetWatch("y", text_op.watch_data_rows);
			AssertEquals("3", y_watch.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO FROM HERE write tests for function with pointers and function with structs and maybe arrays
//should test passing in array view from a fixed array for example.
//and then try at least a pointer with op overload as well. (maybe also += to start off those as well and finish later)
Test_OpOverload :: (
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
  n : neume;
  i : int = 3;
  ni := i + n;
  ti := -n;
}
operator + :: (i : int, n : neume) -> int {
  return i + 1;
}
operator - :: (n : neume) -> int {
  return 5;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 12);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["n", "i", "ni", "ti"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
		// DownUpInputMap(.TEXT_BOTTOM_RIGHT_PANE, game_input);
	}
	case 6; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(7, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			binary_plus_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, binary_plus_frame.function_scope.scope_type);
			AssertEquals("+", binary_plus_frame.func_decl.name);

			count_equals = AssertEquals(2, binary_plus_frame.frame_vars.count);
			if count_equals {
				i_var := binary_plus_frame.frame_vars[0];
				AssertEquals("i", i_var.name);
				AssertEquals(TypeInfoTag.INTEGER, i_var.t_info.type_enum);
				AssertEquals(binary_plus_frame.function_scope.id, i_var.scope_id);
				AssertEquals(binary_plus_frame.function_scope.function_id, i_var.function_id);

				i_watch := GetWatch("i", text_op.watch_data_rows);
				AssertEquals("3", i_watch.value_str);

				n_var := binary_plus_frame.frame_vars[1];
				AssertEquals("n", n_var.name);
				AssertEquals(TypeInfoTag.NEUME, n_var.t_info.type_enum);
				AssertEquals(binary_plus_frame.function_scope.id, n_var.scope_id);
				AssertEquals(binary_plus_frame.function_scope.function_id, n_var.function_id);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 7; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(3, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index {
			if perm.all_data.all_music_instructions[it].op_code == OpCode.call {
				after_call_index = it + 1;
				break;
			}
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 8; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			ni_watch := GetWatch("ni", text_op.watch_data_rows);
			AssertEquals("4", ni_watch.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 9; {
		//TEST stop at first foo function call;
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(10, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			unary_minus_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, unary_minus_frame.function_scope.scope_type);
			AssertEquals("-", unary_minus_frame.func_decl.name);

			count_equals = AssertEquals(1, unary_minus_frame.frame_vars.count);
			if count_equals {
				i_var := unary_minus_frame.frame_vars[0];
				AssertEquals("n", i_var.name);
				AssertEquals(TypeInfoTag.NEUME, i_var.t_info.type_enum);
				AssertEquals(unary_minus_frame.function_scope.id, i_var.scope_id);
				AssertEquals(unary_minus_frame.function_scope.function_id, i_var.function_id);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 10; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		after_call_index : int;
		for d_line.start_asm_index..d_line.end_asm_index {
			if perm.all_data.all_music_instructions[it].op_code == OpCode.call {
				after_call_index = it + 1;
				break;
			}
		}
		AssertEquals(after_call_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);	
	}
	case 11; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(5, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			ni_watch := GetWatch("ti", text_op.watch_data_rows);
			AssertEquals("5", ni_watch.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO Could add more tests to remove rows (eg for structs) here later if we want to be more thorough
Test_WatchRemoveRows :: (
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
#string DONE
main :: () {
  a : [] int = int.[0,1];
  foo(1);
  f2();
}
foo :: (a : int) {
  i : int = 1;
}
f2 :: () {
  b : tano;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 32);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, TEST_TEXT_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["a", "b"], text_op);
	}
	case 3; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		//Main function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, c_frame.function_scope.scope_type);
			AssertEquals("main", c_frame.func_decl.name);

			AssertEquals(0, c_frame.all_scopes_in_function.count);
			AssertEquals(0, c_frame.call_open_scopes.count);

			count_equals = AssertEquals(1, c_frame.frame_vars.count);
		}	

		DownUpInputMap(.TEXT_WATCH_PANE, game_input);
	}
	case 6;
		DownUpThisFrame(.ENTER, game_input);
	case 7; {
		//main function - check a var
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(2, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(5, text_op.watch_data_rows.count);
		if count_equals {
			a_0 := GetWatch("a[0]", text_op.watch_data_rows);
			AssertEquals("a[0]", a_0.name);
			AssertEquals("[0]", a_0.display_name);
			AssertEquals("0", a_0.value_str);

			a_1 := GetWatch("a[1]", text_op.watch_data_rows);
			AssertEquals("a[1]", a_1.name);
			AssertEquals("[1]", a_1.display_name);
			AssertEquals("1", a_1.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 8; {
		//foo function - should have removed rows since a in main and a in foo are not the same type
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(6, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_frame.function_scope.scope_type);
			AssertEquals("foo", foo_frame.func_decl.name);
		}

		count_equals = AssertEquals(3, text_op.watch_data_rows.count);
		if count_equals {
			a_watch := text_op.watch_data_rows[0];
			AssertEquals("a", a_watch.name);
			AssertEquals("a", a_watch.display_name);
			AssertEquals("1", a_watch.value_str);

			empty_row := text_op.watch_data_rows[2];
			AssertEquals("", empty_row.name);
			AssertEquals("", empty_row.display_name);
			AssertEquals("", empty_row.value_str);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 9; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 10; DownUpInputMap(.DEBUG_STEP_OVER, game_input); 
	case 11; DownUpThisFrame(.ARROW_DOWN, game_input); 
	case 12; DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	case 13; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 14; DownUpThisFrame(.ENTER, game_input);
	case 15; {
		//f2 function
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(10, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			f2_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals("f2", f2_frame.func_decl.name);
		}

		count_equals = AssertEquals(8, text_op.watch_data_rows.count);
		if count_equals {
			b_0 := GetWatch("b.row_start", text_op.watch_data_rows);
			AssertEquals("b.row_start", b_0.name);
			AssertEquals("row_start", b_0.display_name);
			AssertEquals("0", b_0.value_str);
			b_ms := GetWatch("b.mspace_start", text_op.watch_data_rows);
			AssertEquals("b.mspace_start", b_ms.name);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 16; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 17; {
		//main function - should have removed watch sub rows since b is not in function so it should be an error
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(3, text_op.watch_data_rows.count);
		if count_equals {
			b_w := GetWatch("b", text_op.watch_data_rows);
			AssertEquals("b", b_w.name);
			AssertEquals("b", b_w.display_name);
			AssertEquals(true, b_w.is_error);
			// AssertEquals("b is unknown identifier", b_w.value_str);
		}

	}
	//TEST - Check that removing dropped row removes top and row
	case 18; DownUpThisFrame(.ARROW_UP, game_input); 
	case 19; DownUpThisFrame(.ENTER, game_input); 
	case 20; DownUpThisFrame(.DELETE, game_input); 
	case 21; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(2, text_op.watch_data_rows.count);
		if count_equals {
			b_row := text_op.watch_data_rows[0];
			AssertEquals("b", b_row.name);
			AssertEquals("b", b_row.display_name);
			AssertEquals(true, b_row.is_error);

			empty_row := text_op.watch_data_rows[1];
			AssertEquals("", empty_row.name);
			AssertEquals("", empty_row.display_name);
			AssertEquals("", empty_row.value_str);
		}
	}
	//TEST - Check that removing empty row does nothing
	case 22; DownUpThisFrame(.ARROW_DOWN, game_input); 
	case 23; DownUpThisFrame(.DELETE, game_input); 
	case 24; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(2, text_op.watch_data_rows.count);
		if count_equals {
			empty_row := text_op.watch_data_rows[1];
			AssertEquals("", empty_row.name);
			AssertEquals("", empty_row.display_name);
			AssertEquals("", empty_row.value_str);
		}
	}
	//TEST - Remove b watch error row
	case 25; DownUpThisFrame(.ARROW_UP, game_input);
	case 26; DownUpThisFrame(.DELETE, game_input);
	case 27; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(1, text_op.watch_data_rows.count);
		if count_equals {
			empty_row := text_op.watch_data_rows[0];
			AssertEquals("", empty_row.name);
			AssertEquals("", empty_row.display_name);
			AssertEquals("", empty_row.value_str);
		}
	}
	//TEST - double check remove empty row when only have empty row does not remove anything
	case 28; DownUpThisFrame(.DELETE, game_input);
	case 29; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);
		}

		count_equals = AssertEquals(1, text_op.watch_data_rows.count);
		if count_equals {
			empty_row := text_op.watch_data_rows[0];
			AssertEquals("", empty_row.name);
			AssertEquals("", empty_row.display_name);
			AssertEquals("", empty_row.value_str);
		}
	}
	//TEST - double check drop empty row when only have empty row does not do anything
	case 30; DownUpThisFrame(.ENTER, game_input);
	case 31; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		count_equals := AssertEquals(1, text_op.watch_data_rows.count);
		if count_equals {
			empty_row := text_op.watch_data_rows[0];
			AssertEquals("", empty_row.name);
			AssertEquals("", empty_row.display_name);
			AssertEquals("", empty_row.value_str);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO FROM HERE add absolute_path to debug_line and then
//make sure that works well with debugger execution and
//rendering so we don't skip over lines.
//Can test with this by overlapping main and Foo but
//does not matter too much since we will add multiple
//files to editor later and do it properly. 
//Then pull out file load for reuse and then start
//a file test and add melody and a struct
//and a function (maybe sort or later before doing 3d)
Test_DirectiveLoad :: (
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
#load "c_test/utest";
main :: () {
  v : V2;
  x := Foo(0);
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
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["v", "x", "y"], text_op);
		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);
	}
	case 4; DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	case 5; {
		//TEST V2 variable from V2 struct from loaded file
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(3, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			v2_info, found_v2_info := GetTypeInfoStructByName("V2", text_op.text_comp_data.all_type_info_struct);
			AssertEquals(true, found_v2_info);

			count_equals = AssertEquals(2, main_frame.frame_vars.count);
			if count_equals {
				v_var := main_frame.frame_vars[0];
				AssertEquals("v", v_var.name);
				AssertEquals(TypeInfoTag.STRUCT, v_var.t_info.type_enum);
				AssertEquals(*v2_info.info, v_var.t_info);
				AssertEquals(main_frame.function_scope.id, v_var.scope_id);
				AssertEquals(main_frame.function_scope.function_id, v_var.function_id);

				x_var := main_frame.frame_vars[1];
				AssertEquals("x", x_var.name);
				AssertEquals(TypeInfoTag.INTEGER, x_var.t_info.type_enum);
				AssertEquals(main_frame.function_scope.id, x_var.scope_id);
				AssertEquals(main_frame.function_scope.function_id, x_var.function_id);
			}
		}

		DownUpInputMap(.DEBUG_STEP_INTO, game_input);
	}
	case 6; {
		//TEST run foo function from loaded file
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumberInFile(5, "utest", text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, perm.all_data.all_text_files.count);
		if count_equals {
			AssertEquals(true, String.ends_with(perm.all_data.all_text_files[1].absolute_path_name, "utest"));
		}

		count_equals = AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals("Foo", foo_frame.func_decl.name);

			count_equals = AssertEquals(2, foo_frame.frame_vars.count);
			if count_equals {
				x_var := foo_frame.frame_vars[0];
				AssertEquals("x", x_var.name);
				AssertEquals(TypeInfoTag.INTEGER, x_var.t_info.type_enum);
				AssertEquals(foo_frame.function_scope.id, x_var.scope_id);
				AssertEquals(foo_frame.function_scope.function_id, x_var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("x", x_watch.name);
				AssertEquals("0", x_watch.value_str);

				y_var := foo_frame.frame_vars[1];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(foo_frame.function_scope.id, y_var.scope_id);
				AssertEquals(foo_frame.function_scope.function_id, y_var.function_id);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 7; {
		//TEST run foo function from loaded file
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumberInFile(6, "utest", text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, perm.all_data.all_text_files.count);
		if count_equals {
			AssertEquals(true, String.ends_with(perm.all_data.all_text_files[1].absolute_path_name, "utest"));
			AssertEquals(1, text_op.ftab_i);
		}

		count_equals = AssertEquals(2, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			foo_frame := text_op.exec_info.debug_info.debug_call_stack[1];
			AssertEquals("Foo", foo_frame.func_decl.name);

			count_equals = AssertEquals(2, foo_frame.frame_vars.count);
			if count_equals {
				x_var := foo_frame.frame_vars[0];
				AssertEquals("x", x_var.name);
				AssertEquals(TypeInfoTag.INTEGER, x_var.t_info.type_enum);
				AssertEquals(foo_frame.function_scope.id, x_var.scope_id);
				AssertEquals(foo_frame.function_scope.function_id, x_var.function_id);

				y_var := foo_frame.frame_vars[1];
				AssertEquals("y", y_var.name);
				AssertEquals(TypeInfoTag.INTEGER, y_var.t_info.type_enum);
				AssertEquals(foo_frame.function_scope.id, y_var.scope_id);
				AssertEquals(foo_frame.function_scope.function_id, y_var.function_id);

				y_watch := GetWatch("y", text_op.watch_data_rows);
				AssertEquals("y", y_watch.name);
				AssertEquals("1", y_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	//Step over push
	case 8; DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	case 9; {
		//TEST run foo function from loaded file
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(text_op.exec_info.exec_state, .IS_DEBUG_STOP);	

		d_line := GetDebugLineNumber(4, text_op.text_comp_data.all_debug_lines);
		AssertEquals(d_line.start_asm_index, perm.all_data.all_register_memory[RegDef.pc].int_value);

		count_equals := AssertEquals(2, perm.all_data.all_text_files.count);
		if count_equals {
			AssertEquals(true, String.ends_with(perm.all_data.all_text_files[1].absolute_path_name, "utest"));
			AssertEquals(0, text_op.ftab_i);
		}

		count_equals = AssertEquals(1, text_op.exec_info.debug_info.debug_call_stack.count);
		if count_equals {
			main_frame := text_op.exec_info.debug_info.debug_call_stack[0];
			AssertEquals("main", main_frame.func_decl.name);

			count_equals = AssertEquals(2, main_frame.frame_vars.count);
			if count_equals {
				x_var := main_frame.frame_vars[1];
				AssertEquals("x", x_var.name);
				AssertEquals(TypeInfoTag.INTEGER, x_var.t_info.type_enum);
				AssertEquals(main_frame.function_scope.id, x_var.scope_id);
				AssertEquals(main_frame.function_scope.function_id, x_var.function_id);

				x_watch := GetWatch("x", text_op.watch_data_rows);
				AssertEquals("x", x_watch.name);
				AssertEquals("1", x_watch.value_str);
			}
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO This test also messes up if we change the files since we have to recompile every time
//but that is tedious for a test and so maybe we leave it out for now.
//TODO FROM HERE I need to either pull out the file functions so we can use them from a dynamic library
//Or make a simpler dynamic library for now and gradually add to it so it does not crash all the time
//I think that's the better idea
//TODO FROM HERE We can add a test back here with the new dl to see that it loads and also check unit test
//MAYBE We can put the new_test into fixed_test or change the name and check that its working
//maybe even create a tuning system to double check its running properly
//ALSO set the osc_wave_type for chord_s2 so we can update the synth wave type from asm
//and then check memory debugger
//and then make sure everything is working well on mac
#if 1 {
// #if OS == .WINDOWS {
//TODO Technically we would have to compile this before being able to pull it in.
LDLData :: struct {
	fixed_test_path : string;
	test_path_2 : string;
}
Test_LoadDL :: (
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

		fixed_test_path := sprint("%.%", TEST_DL_PATH_NAME, dl_suffix,, test_alloc);
		test_file_exists := file_exists(fixed_test_path);
		AssertEquals(true, test_file_exists);
		test_path_2 := sprint("%.%", TEST_DL_2_PATH_NAME, dl_suffix,, test_alloc);
		test_2_exists := file_exists(test_path_2);
		AssertEquals(true, test_2_exists);
		if test_file_exists && test_2_exists {
			command_strings := string.[jai_cmd, BUILD_DL_NAME, "-import_dir", "./", "-", TEST_DL_PATH_NAME];
			cmd_success := run_command(.. command_strings, capture_and_return_output=true);
			//NOTE : this is stored in test_alloc so should get reset after anyways
			perm.test_data.spec_data = New(LDLData,, test_alloc);
			ldl_data := cast(*LDLData) perm.test_data.spec_data;
			ldl_data.fixed_test_path = fixed_test_path;

			cmd_string_2 := string.[jai_cmd, BUILD_DL_NAME, "-import_dir", "./", "-", TEST_DL_2_PATH_NAME];
			cmd_success_2 := run_command(.. cmd_string_2, capture_and_return_output=true);
			ldl_data.test_path_2 = test_path_2;

			array_resize(*perm.test_data.all_sub_tests, 8);
		} else {
			print("Need to compile % and % to run this test.\n", fixed_test_path, test_path_2);
			print("Can run unit test Test_LoadDL which will compile it if it's there.\n");
		}
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	ldl_data := cast(*LDLData) perm.test_data.spec_data;
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.load_dl, ldl_data.fixed_test_path);
		array_add(*perm.all_data.all_terminal_events, open_test);

		test_2 := MakeTerminalEvent(.load_dl, ldl_data.test_path_2);
		array_add(*perm.all_data.all_terminal_events, test_2);
	}
	case 1; {
		abs_path := get_absolute_path(ldl_data.fixed_test_path);
		count_equal := AssertEquals(2, global_dynamic_libraries.count);
		dl : DynamicLibrary;
		if count_equal {
			dl = global_dynamic_libraries[0];
			path_with_suffix := tprint(ldl_data.fixed_test_path, dl_suffix);
			AssertEquals(ldl_data.fixed_test_path, dl.input_path_name);
			AssertEquals(abs_path, dl.abs_path_name);
			AssertEquals(true, dl.module_handle != null);
			AssertEquals(true, dl.ExternalRunOnce_proc_address != null);
			AssertEquals(true, dl.ExternalPerFrame_proc_address != null);
		} else {
			print("Sometimes this test fails due to dynamic library loading so try rerunning it before assuming it failed.\n");
			print("If this happens often, we can likely remove this test since we have it in unit tests anyways.\n");
		}

		abs_path_2 := get_absolute_path(ldl_data.test_path_2);
		if count_equal {
			dl_2 : DynamicLibrary = global_dynamic_libraries[1];
			path_with_suffix := tprint(ldl_data.test_path_2, dl_suffix);
			AssertEquals(ldl_data.test_path_2, dl_2.input_path_name);
			AssertEquals(abs_path_2, dl_2.abs_path_name);
			AssertEquals(true, dl_2.module_handle != null);
			AssertEquals(true, dl_2.ExternalRunOnce_proc_address != null);
		} else {
			print("Sometimes this test fails due to dynamic library loading so try rerunning it before assuming it failed.\n");
			print("If this happens often, we can likely remove this test since we have it in unit tests anyways.\n");
		}

		AssertEquals(0, perm.all_data.all_mspace_data[0].all_music_pts.count);

		run_test := MakeTerminalEvent(.run_dl_once, ldl_data.fixed_test_path);
		array_add(*perm.all_data.all_terminal_events, run_test);
	}
	case 2; {
		//TODO We could check this with a hot key on the previous frame but since we have not decided yet
		//I will just run the function and then check next frame
		count_equal := AssertEquals(2, global_dynamic_libraries.count);
		if count_equal {
			AssertEquals(2, perm.all_data.all_simple_synths.count);
			AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_lane_rows.count);
			AssertEquals(3, perm.all_data.all_mspace_data[0].all_music_pts.count);
		}

		run_test := MakeTerminalEvent(.run_dl_once, ldl_data.test_path_2);
		array_add(*perm.all_data.all_terminal_events, run_test);
	}
	case 3; {
		AssertEquals(2, perm.all_data.all_simple_synths.count);
		AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_lane_rows.count);
		AssertEquals(6, perm.all_data.all_mspace_data[0].all_music_pts.count);


		//Test start per frame
		run_test := MakeTerminalEvent(.start_dl_per_frame, ldl_data.fixed_test_path);
		array_add(*perm.all_data.all_terminal_events, run_test);		
	}
	case 4; {
		AssertEquals(true, global_dynamic_libraries[0].is_running_dl_per_frame);
		AssertEquals(true, global_dynamic_libraries[0].ExternalPerFrame_proc_address != null);

		//Test running per frame input
		DownUpThisFrame(#char "Q", .{ctrl_pressed=true}, game_input);
	}
	case 5; {
		count_equal := AssertEquals(7, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			AssertEquals(5, perm.all_data.all_mspace_data[0].all_music_pts[6].x_start);
			AssertEquals(6, perm.all_data.all_mspace_data[0].all_music_pts[6].x_end);
			AssertFloat64Equals(0, perm.all_data.all_mspace_data[0].all_music_pts[6].music_pt_float);
		}

		//Test running per frame data updated
		DownUpThisFrame(#char "Q", .{ctrl_pressed=true}, game_input);
	}
	case 6; {
		count_equal := AssertEquals(8, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			AssertEquals(6, perm.all_data.all_mspace_data[0].all_music_pts[7].x_start);
			AssertEquals(7, perm.all_data.all_mspace_data[0].all_music_pts[7].x_end);
			AssertFloat64Equals(1, perm.all_data.all_mspace_data[0].all_music_pts[7].music_pt_float);
		}


		//Test stop per frame
		run_test := MakeTerminalEvent(.stop_dl_per_frame, ldl_data.fixed_test_path);
		array_add(*perm.all_data.all_terminal_events, run_test);	
	}
	case 7; {
		AssertEquals(false, global_dynamic_libraries[0].is_running_dl_per_frame);
		AssertEquals(true, global_dynamic_libraries[0].ExternalPerFrame_proc_address != null);


		count_equal := AssertEquals(2, global_dynamic_libraries.count);
		if count_equal {
			RemoveDynamicLibrary(*global_dynamic_libraries[1]);
			RemoveDynamicLibrary(*global_dynamic_libraries[0]);
			AssertEquals(0, global_dynamic_libraries.count);
		}		
	}
	}

	ContinueTest(*perm.test_data);

} @ITest
// }
}

//TODO ExSample or MiniGame?
// Test_ExSample :: (
//TODO I can likely just remove this test now OR JUST move the MiniGame file in here as a string
Test_MiniGame :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	main_name :: "MiniGame";
	perm : *Persist = GetPermanentStorage(game_memory);
	if !perm.test_data.initialized_test {
		perm.test_data.initialized_test = true;

		//TODO Use InitAllData here once we remove this
		perm.all_data = InitAllData();
		ResetAllRendererData(renderer_data);

		SetupMusicAndRows(perm.all_data, TWO_ROWS);

		/*DOC : We can't open a file in a text op space yet, so we just load it and add it to the tabs here for now.
		TODO - We can open this file in the tab manually once that is possible to do.
		*/
		// exsample_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		//TODO should we load all test files or do it later?
		main_file, main_loaded := LoadTextFile(main_name, *perm.all_data.all_text_files);
		if main_loaded {
			//TODO Should we do this in LoadTextFile? I seem to forget to do it.
			// array_add(*perm.all_data.all_text_files, main_file);
		}
		library_file, library_loaded := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		if library_loaded {
			// array_add(*perm.all_data.all_text_files, library_file);
		}

		text_op := CreateTextOpSpace(.[main_file.id, library_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 6);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.open_op, main_name);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; DownUpInputMap(.TEXT_DEBUG_TOGGLE, game_input);
	case 2; DownUpInputMap(.TEXT_COMPILE, game_input);
	case 3; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AddWatchDataForTest(.["ia", "v2"], text_op);
		CodeBPForTestInFile(13, main_name, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		//TEST some simple variable test to make sure things are working
		//TODO Can remove this later once we test more complex functions and behaviors
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		cd := text_op.text_comp_data;
		c_frame := text_op.exec_info.debug_info.debug_call_stack[0];
		count_equals := AssertEquals(2, c_frame.frame_vars.count);
		if count_equals {
			v2_info, found_v2_info := GetTypeInfoStructByName("Vector2", cd.all_type_info_struct);
			AssertEquals(true, found_v2_info);

			v2_var := c_frame.frame_vars[0];
			AssertEquals("v2", v2_var.name);
			AssertEquals(TypeInfoTag.STRUCT, v2_var.t_info.type_enum);
			AssertEquals(*v2_info.info, v2_var.t_info);

			v2_watch := GetWatch("v2", text_op.watch_data_rows);
			AssertEquals("v2", v2_watch.name);
			AssertEquals("Vector2", v2_watch.type_str);

			fa_info, found_fa_info := GetArrayType(cd, *cd.int_type_info, .FIXED, 3);
			AssertEquals(true, found_fa_info);

			ia_var := c_frame.frame_vars[1];
			AssertEquals("ia", ia_var.name);
			AssertEquals(TypeInfoTag.ARRAY, ia_var.t_info.type_enum);
			AssertEquals(*fa_info.info, ia_var.t_info);

			ia_watch := GetWatch("ia", text_op.watch_data_rows);
			AssertEquals("ia", ia_watch.name);
			AssertEquals("[3] int", ia_watch.type_str);
		}

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		t_01 := tano.{0,0,0,1,0};
		tmp : [] Neume = GetTanoMusicPts(t_01, perm.all_data.all_mspace_data[0].all_music_pts, type=Neume);
		AssertFloat64Equals(0, tmp[0].svara);
		AssertFloat64Equals(0, tmp[0].x_start);
		AssertFloat64Equals(1, tmp[0].x_end);
		AssertFloat64Equals(4, tmp[1].svara);
		AssertFloat64Equals(0, tmp[1].x_start);
		AssertFloat64Equals(1, tmp[1].x_end);
		AssertFloat64Equals(7, tmp[2].svara);
		AssertFloat64Equals(0, tmp[2].x_start);
		AssertFloat64Equals(1, tmp[2].x_end);

		t_13 := tano.{0,0,1,3,0};
		tmp = GetTanoMusicPts(t_13, perm.all_data.all_mspace_data[0].all_music_pts, type=Neume);
		AssertFloat64Equals(0+8, tmp[0].svara);
		AssertFloat64Equals(1, tmp[0].x_start);
		AssertFloat64Equals(3, tmp[0].x_end);
		AssertFloat64Equals(4+8, tmp[1].svara);
		AssertFloat64Equals(1, tmp[1].x_start);
		AssertFloat64Equals(3, tmp[1].x_end);
		AssertFloat64Equals(7+8, tmp[2].svara);
		AssertFloat64Equals(1, tmp[2].x_start);
		AssertFloat64Equals(3, tmp[2].x_end);

		t_34 := tano.{0,0,3,4,0};
		tmp = GetTanoMusicPts(t_34, perm.all_data.all_mspace_data[0].all_music_pts, type=Neume);
		AssertFloat64Equals(0, tmp[0].svara);
		AssertFloat64Equals(3, tmp[0].x_start);
		AssertFloat64Equals(4, tmp[0].x_end);
		AssertFloat64Equals(4, tmp[1].svara);
		AssertFloat64Equals(3, tmp[1].x_start);
		AssertFloat64Equals(4, tmp[1].x_end);
		AssertFloat64Equals(7, tmp[2].svara);
		AssertFloat64Equals(3, tmp[2].x_start);
		AssertFloat64Equals(4, tmp[2].x_end);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_SimpleSynth :: (
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

		NEW_ROWS := TWO_ROWS;
		NEW_ROWS[0].row_system_type = .midi_pitch;
		SetupMusicAndRows(perm.all_data, NEW_ROWS);

		//TODO Should we make a function for this create?
		 synth : *SimpleSynth = array_add(*perm.all_data.all_simple_synths);
		synth.wave_type = OscWaveType.SINE;
		synth.envelope = MakeVolumeEnvelope();

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  #asm{tclear;}
  ia := int.[0,4,7];
  tano(0,0:1) ~= ia;
  tano(0,1:2) ~= ia;
  tano(0,1) += 8;
  tano(0,3) ~= ia;

  tano(0,4) ~= tano(0,0..4);
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 3);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_LoadTextOp :: (
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
		array_resize(*perm.test_data.all_sub_tests, 8);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	TEST_FILE_NAME :: "alisjdas90da90s8d0a9";
	OP_SPACE_NAME :: "test";
	if perm.test_data.sub_test_index == {
	case 0; {
		open_test := MakeTerminalEvent(.create_file, TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 1; {
		file_does_exist := file_exists(TEST_FILE_NAME);
		AssertEquals(true, file_does_exist);


		open_test := MakeTerminalEvent(.load_op, OP_SPACE_NAME, TEST_FILE_NAME);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 2; {
		AssertEquals(0, perm.all_data.all_closed_op_spaces.count);
		count_equals := AssertEquals(1, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_space := perm.all_data.all_open_op_spaces[0];
			AssertEquals(OP_SPACE_NAME, op_space.op_space_name);
			AssertEquals(OpSpaceExternalType.txt, op_space.op_space_external_type);
		}

		close_test := MakeTerminalEvent(.close_op, OP_SPACE_NAME);
		array_add(*perm.all_data.all_terminal_events, close_test);
	}
	case 3; {
		AssertEquals(0, perm.all_data.all_open_op_spaces.count);
		count_equals := AssertEquals(1, perm.all_data.all_closed_op_spaces.count);
		if count_equals {
			op_space := perm.all_data.all_closed_op_spaces[0];
			AssertEquals(OP_SPACE_NAME, op_space.op_space_name);
			AssertEquals(OpSpaceExternalType.txt, op_space.op_space_external_type);
		}

		close_test := MakeTerminalEvent(.open_op, OP_SPACE_NAME);
		array_add(*perm.all_data.all_terminal_events, close_test);
	}
	case 4; {
		AssertEquals(0, perm.all_data.all_closed_op_spaces.count);
		count_equals := AssertEquals(1, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_space := perm.all_data.all_open_op_spaces[0];
			AssertEquals(OP_SPACE_NAME, op_space.op_space_name);
			AssertEquals(OpSpaceExternalType.txt, op_space.op_space_external_type);
		}

		close_test := MakeTerminalEvent(.close_op, OP_SPACE_NAME);
		array_add(*perm.all_data.all_terminal_events, close_test);
	}
	case 5; {
		AssertEquals(4, renderer_data.all_render_groups.count);
		AssertEquals(1, renderer_data.free_op_space_render_groups.count);

		//Test : Check if loading after closing reopens the same space
		create_open_test := MakeTerminalEvent(.load_op, OP_SPACE_NAME);
		array_add(*perm.all_data.all_terminal_events, create_open_test);
	}
	case 6; {
		AssertEquals(4, renderer_data.all_render_groups.count);
		AssertEquals(0, renderer_data.free_op_space_render_groups.count);

		AssertEquals(0, perm.all_data.all_closed_op_spaces.count);
		count_equals := AssertEquals(1, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_space := perm.all_data.all_open_op_spaces[0];
			AssertEquals(OP_SPACE_NAME, op_space.op_space_name);
			AssertEquals(OpSpaceExternalType.txt, op_space.op_space_external_type);
		}
	}
	case 7; {
		file_is_deleted := file_delete(TEST_FILE_NAME);
		AssertEquals(true, file_is_deleted);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO Remove this test once we remove setup music data completely
//We now set these in runtime settings and in the row data directly
#if 0 {
Test_SetupMusic :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
#load "c_load/Library";
main :: () {
  smd : SetupMusicData;
  smd.row_size = 24;
  smd.memory_units_per_second = 1.4;
  smd.bpm = 90.0;
  #asm{ setup_music smd; }
}
DONE);
		//TODO FROM HERE can make a unit test that checks to see if all the Library struct and functions are create properly.
		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 5);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		AssertEquals(24, perm.all_data.global_rules.row_size);
		//TODO I think I want to remove bpm here
		AssertFloat64Equals(90.0, perm.all_data.audio_timing.bpm);
		AssertFloat64Equals(1.4, perm.all_data.game_audio_play.memory_units_per_second);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest
}

Test_CreateMSpace :: (
	test_name : string,
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput) 
{
	perm : *Persist = GetPermanentStorage(game_memory);
	perm.all_data = InitAllData();

	//Defaults to mspace_id = 0
	CreateMusicRow(TWO_ROWS[0], perm.all_data);
	AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_lane_rows.count);
	AssertEquals(1, perm.all_data.all_mspace_data[0].all_section_to_row.count);
	AssertEquals("", perm.all_data.all_mspace_data[0].mspace_name);
	AssertEquals(perm.all_data.runtime_settings.default_tano_x_unit_width, 
		perm.all_data.all_mspace_data[0].tano_x_unit_width);

	gcmd : GetOrCreateMSpaceData;
	gcmd.mspace_name = "test";
	mspace_1 := GetOrCreateMusicSpace(gcmd, perm.all_data.runtime_settings, *perm.all_data.all_mspace_data,
		*perm.all_data.free_mspace_data_pool);

	count_equals := AssertEquals(2, perm.all_data.all_mspace_data.count);
	if count_equals {
		for TWO_ROWS {
			crd : CreateRowData = it;
			crd.mspace_id = mspace_1.mspace_id;
			CreateMusicRow(crd, perm.all_data);
		}
		AssertEquals(2, perm.all_data.all_mspace_data[1].all_music_lane_rows.count);
		AssertEquals(2, perm.all_data.all_mspace_data[1].all_section_to_row.count);
		AssertEquals(gcmd.mspace_name, perm.all_data.all_mspace_data[1].mspace_name);
		AssertEquals(perm.all_data.runtime_settings.default_tano_x_unit_width,
			perm.all_data.all_mspace_data[1].tano_x_unit_width);
	}

	gcmd_2 : GetOrCreateMSpaceData;
	gcmd_2.mspace_name = "test2";
	mspace_2 := GetOrCreateMusicSpace(gcmd_2, perm.all_data.runtime_settings, *perm.all_data.all_mspace_data,
		*perm.all_data.free_mspace_data_pool);

	count_equals = AssertEquals(3, perm.all_data.all_mspace_data.count);
	if count_equals {
		THREE_ROWS :: CreateRowData.[
		.{row_section_data=.[.{x_length=12}], row_system_type=.internal_pitch},
		.{row_section_data=.[.{x_length=12}], row_system_type=.internal_pitch},
		.{row_section_data=.[.{x_length=12}], row_system_type=.internal_pitch},
		];
		for THREE_ROWS {
			crd : CreateRowData = it;
			crd.mspace_id = mspace_2.mspace_id;
			CreateMusicRow(crd, perm.all_data);
		}
		AssertEquals(3, perm.all_data.all_mspace_data[2].all_music_lane_rows.count);
		AssertEquals(3, perm.all_data.all_mspace_data[2].all_section_to_row.count);
		AssertEquals(gcmd_2.mspace_name, perm.all_data.all_mspace_data[2].mspace_name);
		AssertEquals(perm.all_data.runtime_settings.default_tano_x_unit_width,
			perm.all_data.all_mspace_data[2].tano_x_unit_width);
	}

	//TEST : We delete and recreate the last mspace to make sure it is working
	delete : DeleteMSpaceData;
	delete.mspace_id = mspace_1.mspace_id;
	success, msg := DeleteMusicSpace(delete, *perm.all_data.all_mspace_data, *perm.all_data.free_mspace_data_pool);
	AssertEquals(true, success);
	count_equals = AssertEquals(2, perm.all_data.all_mspace_data.count);
	AssertEquals(1, perm.all_data.free_mspace_data_pool.count);

	//TEST : Create a new one after deleting 
	new_mspace := GetOrCreateMusicSpace(gcmd, perm.all_data.runtime_settings, *perm.all_data.all_mspace_data,
		*perm.all_data.free_mspace_data_pool);
	count_equals = AssertEquals(3, perm.all_data.all_mspace_data.count);
	AssertEquals(0, perm.all_data.free_mspace_data_pool.count);
	if count_equals {
		//tEST Make sure we maintain the order after creating the new one
		AssertEquals(0, perm.all_data.all_mspace_data[0].mspace_id);
		AssertEquals(2, perm.all_data.all_mspace_data[1].mspace_id);
		AssertEquals(3, perm.all_data.all_mspace_data[2].mspace_id);

		AssertEquals(0, perm.all_data.all_mspace_data[2].all_music_lane_rows.count);
		AssertEquals(0, perm.all_data.all_mspace_data[2].all_section_to_row.count);
		AssertEquals(gcmd.mspace_name, perm.all_data.all_mspace_data[2].mspace_name);
		AssertEquals(perm.all_data.runtime_settings.default_tano_x_unit_width,
			perm.all_data.all_mspace_data[2].tano_x_unit_width);

		for TWO_ROWS {
			crd : CreateRowData = it;
			crd.mspace_id = new_mspace.mspace_id;
			CreateMusicRow(crd, perm.all_data);
		}
		AssertEquals(2, perm.all_data.all_mspace_data[2].all_music_lane_rows.count);
		AssertEquals(2, perm.all_data.all_mspace_data[2].all_section_to_row.count);
	}

	// perm.all_data.render_mspace_id = 1;
// 
	CreateManyMusicPtsInMemory(float64.[0,4], 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);
	CreateManyMusicPtsInMemory(float64.[0,7], 0, 1, 3, *perm.all_data.all_mspace_data[0].all_music_pts);
	CreateManyMusicPtsInMemory(float64.[0,9], 0, 3, 6, *perm.all_data.all_mspace_data[0].all_music_pts);

	CreateManyMusicPtsInMemory(float64.[0,1], 0, 0, 1, *perm.all_data.all_mspace_data[1].all_music_pts);
	CreateManyMusicPtsInMemory(float64.[0,2], 0, 1, 3, *perm.all_data.all_mspace_data[1].all_music_pts);
	CreateManyMusicPtsInMemory(float64.[0,3], 0, 3, 6, *perm.all_data.all_mspace_data[1].all_music_pts);

} @ITest

Test_MSpaceAudio :: (
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

		//Defaults to mspace_id = 0
		CreateMusicRow(TWO_ROWS[0], perm.all_data);
		AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_lane_rows.count);
		AssertEquals(1, perm.all_data.all_mspace_data[0].all_section_to_row.count);
		AssertEquals("", perm.all_data.all_mspace_data[0].mspace_name);
		AssertEquals(perm.all_data.runtime_settings.default_tano_x_unit_width, 
			perm.all_data.all_mspace_data[0].tano_x_unit_width);

		gcmd : GetOrCreateMSpaceData;
		gcmd.mspace_name = "test";
		mspace_1 := GetOrCreateMusicSpace(gcmd, perm.all_data.runtime_settings, *perm.all_data.all_mspace_data,
			*perm.all_data.free_mspace_data_pool);

		count_equals := AssertEquals(2, perm.all_data.all_mspace_data.count);
		if count_equals {
			for TWO_ROWS {
				crd : CreateRowData = it;
				crd.mspace_id = mspace_1.mspace_id;
				CreateMusicRow(crd, perm.all_data);
			}
			AssertEquals(2, perm.all_data.all_mspace_data[1].all_music_lane_rows.count);
			AssertEquals(2, perm.all_data.all_mspace_data[1].all_section_to_row.count);
			AssertEquals(gcmd.mspace_name, perm.all_data.all_mspace_data[1].mspace_name);
			AssertEquals(perm.all_data.runtime_settings.default_tano_x_unit_width,
				perm.all_data.all_mspace_data[1].tano_x_unit_width);
		}

		CreateManyMusicPtsInMemory(float64.[0,4], 0, 0, 1, *perm.all_data.all_mspace_data[0].all_music_pts);
		CreateManyMusicPtsInMemory(float64.[0,7], 0, 1, 3, *perm.all_data.all_mspace_data[0].all_music_pts);
		CreateManyMusicPtsInMemory(float64.[0,9], 0, 3, 6, *perm.all_data.all_mspace_data[0].all_music_pts);

		CreateManyMusicPtsInMemory(float64.[0,1], 0, 0, 1, *perm.all_data.all_mspace_data[1].all_music_pts);
		CreateManyMusicPtsInMemory(float64.[0,2], 0, 1, 3, *perm.all_data.all_mspace_data[1].all_music_pts);
		CreateManyMusicPtsInMemory(float64.[0,3], 0, 3, 6, *perm.all_data.all_mspace_data[1].all_music_pts);

		array_resize(*perm.test_data.all_sub_tests, 21+1);
	}

	default_base_cam : Camera2D = GetRenderMSpace(perm.all_data).mspace_cam;

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	//TODO FROM HERE right a few audio tests to make sure
	//looping is working and also with mouse clicks
	//and silent loops (maybe add an extra mspace as well)
	//and then update create row to new asm model
	//so we can then generate asm lib all automatically
	if perm.test_data.sub_test_index == {
	case 0; {
		umd : UpdateMSpaceData;
		umd.mspace_id = 0;
		umd.update_mspace_audio_row_size = true;
		umd.set_fixed_audio_row_size = true;
		umd.mspace_audio_row_size = 1;
		UpdateMusicSpace(umd, perm.all_data.runtime_settings, *perm.all_data.all_mspace_data);
		mspace_0 := *perm.all_data.all_mspace_data[0];
		AssertEquals(umd.set_fixed_audio_row_size, mspace_0.is_fixed_audio_row_size);
		AssertEquals(umd.mspace_audio_row_size, mspace_0.mspace_audio_row_size);

		umd.mspace_id = 1;
		umd.mspace_audio_row_size = 3;
		UpdateMusicSpace(umd, perm.all_data.runtime_settings, *perm.all_data.all_mspace_data);
		mspace_1 := *perm.all_data.all_mspace_data[1];
		AssertEquals(umd.set_fixed_audio_row_size, mspace_1.is_fixed_audio_row_size);
		AssertEquals(umd.mspace_audio_row_size, mspace_1.mspace_audio_row_size);

		//TEST mouse click works even if we are over and it should set to the audio row size
		row_0 : MusicLaneRow = mspace_0.all_music_lane_rows[0];
		play_pos_x : float = GetPlayPosWorldX(row_0, 2.1, perm.all_data.global_rules.memory_unit_width);
		play_pos_y : float = 0.5 * (row_0.row_world_base_start.y + row_0.row_height);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{play_pos_x,play_pos_y}, default_base_cam);
		//TODO USE THIS again ONCE THE jai-Input bug gets fixed. Details at GLOBAL_MOVE_INSTANTLY code in thegame_base.
		// DownUpThisFrame(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 1; {
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.audio_mspace_id);
		AssertFloat64Equals(cast(float64) perm.all_data.all_mspace_data[0].mspace_audio_row_size, perm.all_data.game_audio_play.float_x_memory);

		//TEST if we press play then the next frame we should be at the next mspace
		DownUpInputMap(.PLAY_PAUSE_MUSIC, game_input);
	}
	case 2; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);

		DownUpInputMap(.PLAY_PAUSE_MUSIC, game_input);
	}
	case 3; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);
		AssertEquals(AudioPlayState.PAUSE, perm.all_data.game_audio_play.play_state);

		DownUpInputMap(.NEXT_MUSIC_SPACE, game_input);
	}
	case 4; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST pressing withing the row bounds size lets us play from there
		row_0 : MusicLaneRow = perm.all_data.all_mspace_data[1].all_music_lane_rows[0];
		play_pos_x : float = GetPlayPosWorldX(row_0, 1.9, perm.all_data.global_rules.memory_unit_width);
		play_pos_y : float = 0.5 * (row_0.row_world_base_start.y + row_0.row_height);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{play_pos_x,play_pos_y}, default_base_cam);
		// DownUpThisFrame(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 5; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertFloat64Equals(1, perm.all_data.game_audio_play.float_x_memory);

		DownUpInputMap(.PLAY_PAUSE_MUSIC, game_input);
	}
	case 6; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);
		AssertEquals(true, 1 < perm.all_data.game_audio_play.float_x_memory && 2 > perm.all_data.game_audio_play.float_x_memory);

		//TEST that stopping music brings us back to the current audio mspace
		DownUpInputMap(.STOP_MUSIC, game_input);
	}
	case 7; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.STOP, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST play music and clicking somewhere else should bring us there directly
		DownUpInputMap(.PLAY_PAUSE_MUSIC, game_input);
	}
	case 8; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);
		AssertEquals(true, 0 <= perm.all_data.game_audio_play.float_x_memory && 1 >= perm.all_data.game_audio_play.float_x_memory);

		//TEST play music and clicking somewhere else should bring us there directly and continue playing
		row_0 : MusicLaneRow = perm.all_data.all_mspace_data[1].all_music_lane_rows[0];
		play_pos_x : float = GetPlayPosWorldX(row_0, 2.1, perm.all_data.global_rules.memory_unit_width);
		play_pos_y : float = 0.5 * (row_0.row_world_base_start.y + row_0.row_height);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{play_pos_x,play_pos_y}, default_base_cam);
		// DownUpThisFrame(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 9; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(2, perm.all_data.game_audio_play.float_x_memory);

		//TEST play music and clicking somewhere else should bring us there directly and continue playing
		DownUpInputMap(.STOP_MUSIC, game_input);
	}
	case 10; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.STOP, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST play music and clicking after bounds should bring us back to previous mspace wrap around
		DownUpInputMap(.PLAY_PAUSE_MUSIC, game_input);
	}
	case 11; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST play music and clicking in a different mspace should bring play to new mspace
		row_0 : MusicLaneRow = perm.all_data.all_mspace_data[1].all_music_lane_rows[0];
		play_pos_x : float = GetPlayPosWorldX(row_0, 1.9, perm.all_data.global_rules.memory_unit_width);
		play_pos_y : float = 0.5 * (row_0.row_world_base_start.y + row_0.row_height);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{play_pos_x,play_pos_y}, default_base_cam);
		// DownUpThisFrame(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 12; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(1, perm.all_data.game_audio_play.float_x_memory);

		//TEST play music and clicking in a different mspace should bring play to new mspace
		DownUpInputMap(.STOP_MUSIC, game_input);
	}
	case 13; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.STOP, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST clicking in a different mspace should bring play to new mspace while not playing
		DownUpInputMap(.PREVIOUS_MUSIC_SPACE, game_input);
	}
	case 14; {
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.STOP, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST clicking in a different mspace should bring play to new mspace while not playing
		//State should be pause so we play the current notes from the new position
		row_0 : MusicLaneRow = perm.all_data.all_mspace_data[1].all_music_lane_rows[0];
		play_pos_x : float = GetPlayPosWorldX(row_0, 0.5, perm.all_data.global_rules.memory_unit_width);
		play_pos_y : float = 0.5 * (row_0.row_world_base_start.y + row_0.row_height);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{play_pos_x,play_pos_y}, default_base_cam);
		// DownUpThisFrame(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 15; {
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PAUSE, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST clicking end of mspace when the next one is empty should bring us back on the same frame
		DownUpInputMap(.NEXT_MUSIC_SPACE, game_input);
	}
	case 16; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PAUSE, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST clicking end of mspace when the next one is empty should bring us back on the same frame
		row_0 : MusicLaneRow = perm.all_data.all_mspace_data[1].all_music_lane_rows[0];
		play_pos_x : float = GetPlayPosWorldX(row_0, 0.5, perm.all_data.global_rules.memory_unit_width);
		play_pos_y : float = 0.5 * (row_0.row_world_base_start.y + row_0.row_height);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{play_pos_x,play_pos_y}, default_base_cam);
		// DownUpThisFrame(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 17; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PAUSE, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		//TEST clicking end of mspace when the next one is empty should bring us back on the same frame
		perm.all_data.all_mspace_data[0].mspace_audio_row_size = 0;
		DownUpInputMap(.PLAY_PAUSE_MUSIC, game_input);
	}
	case 18; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);
		AssertEquals(true, perm.all_data.game_audio_play.float_x_memory > 0);

		//TEST clicking end of mspace when the next one is empty should bring us back to this mspace on the next frame
		//since we have to set the cursor to the end of mspace and then 
		//skip the empty mspace and then come back to this one all on the next frame
		row_0 : MusicLaneRow = perm.all_data.all_mspace_data[1].all_music_lane_rows[0];
		play_pos_x : float = GetPlayPosWorldX(row_0, 5.5, perm.all_data.global_rules.memory_unit_width);
		play_pos_y : float = 0.5 * (row_0.row_world_base_start.y + row_0.row_height);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{play_pos_x,play_pos_y}, default_base_cam);
		// DownUpThisFrame(.MOUSE_BUTTON_LEFT, .{ctrl_pressed=true}, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 19; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(cast(float64) perm.all_data.all_mspace_data[1].mspace_audio_row_size, perm.all_data.game_audio_play.float_x_memory);
	}
	case 20; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.PLAY, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);

		DownUpInputMap(.STOP_MUSIC, game_input);
	}
	case 21; {
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.audio_mspace_id);
		AssertEquals(AudioPlayState.STOP, perm.all_data.game_audio_play.play_state);
		AssertFloat64Equals(0, perm.all_data.game_audio_play.float_x_memory);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_FixedOpSpace :: (
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

		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
#string DONE
Empty text file for testing.
DONE);

		gcmd : GetOrCreateMSpaceData;
		gcmd.mspace_name = "test";
		mspace_1 := GetOrCreateMusicSpace(gcmd, perm.all_data.runtime_settings, *perm.all_data.all_mspace_data,
			*perm.all_data.free_mspace_data_pool);
		AssertEquals(2, perm.all_data.all_mspace_data.count);
	
		array_resize(*perm.test_data.all_sub_tests, 26+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		DownUpInputMap(.TERMINAL_TOGGLE, game_input);
	}
	case 1; {
		AssertEquals(1, perm.all_data.all_chosen_entities.count);
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.render_mspace_id);
		term_op := *perm.all_data.all_open_op_spaces[0];
		term_op.fixed_op_type = .FIXED_TO_MSPACE;
		term_op.fixed_mspace_id = perm.all_data.all_mspace_data[0].mspace_id;

		//TEST Move to another music space and then click with mouse to make sure we unselect it and don't continue hovering/selecting this op space
		DownUpInputMap(.NEXT_MUSIC_SPACE, game_input);
	}
	case 2; {
		AssertEquals(1, perm.all_data.all_chosen_entities.count);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);

		//TEST This should unselect the previous op space since we are in a different music space
		game_input.mouse_cam = Vector2F.{0,0};
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	}
	case 3; {
		AssertEquals(0, perm.all_data.all_chosen_entities.count);
		AssertEquals(perm.all_data.all_mspace_data[1].mspace_id, perm.all_data.render_mspace_id);

		DownUpInputMap(.PREVIOUS_MUSIC_SPACE, game_input);
	}
	case 4; {
		AssertEquals(0, perm.all_data.all_chosen_entities.count);
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.render_mspace_id);
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_cam.world_pos, Vector2F.{0,0});
		AssertEquals(perm.all_data.all_open_op_spaces[0].world_offset, Vector2F.{0,0});

		//TEST moving the mspace camera should not move it since it's not fixed to camera
		AddPressKeyboard(#char "D", .DOWN_THIS_FRAME, game_input);
	}
	case 14; AddPressKeyboard(#char "D", .UP_THIS_FRAME, game_input);
	case 15; {
		AssertEquals(true, perm.all_data.all_mspace_data[0].mspace_cam.world_pos.x > 0);
		AssertEquals(perm.all_data.all_open_op_spaces[0].world_offset, Vector2F.{0,0});
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.render_mspace_id);

		term_op := *perm.all_data.all_open_op_spaces[0];
		open_test := MakeTerminalEvent(.goto, goto_type_names[GoToTermType.op_space], term_op.op_space_name);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 16; {
		AssertEquals(0, perm.all_data.all_chosen_entities.count);
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_cam.world_pos, Vector2F.{0,0});
		AssertEquals(perm.all_data.all_open_op_spaces[0].world_offset, Vector2F.{0,0});
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_id, perm.all_data.render_mspace_id);

		//TEST FIXED TO CAMERA should move the op space with the mspace camera
		term_op := *perm.all_data.all_open_op_spaces[0];
		term_op.fixed_op_type = .FIXED_TO_CAMERA;
		AddPressKeyboard(#char "D", .DOWN_THIS_FRAME, game_input);
	}
	case 25; AddPressKeyboard(#char "D", .UP_THIS_FRAME, game_input);
	case 26; {
		AssertEquals(true, perm.all_data.all_mspace_data[0].mspace_cam.world_pos.x > 0);
		AssertEquals(perm.all_data.all_mspace_data[0].mspace_cam.world_pos,
			perm.all_data.all_open_op_spaces[0].world_offset);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_Zooming :: (
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

		for TWO_ROWS CreateMusicRow(it, perm.all_data);

	//TODO Can open a text file to test that we don't scroll on global zoom
	#if 0 {
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
#string DONE
Empty text file for testing.
DONE);
	}

		cosd : CreateOpSpaceData;
		cosd.op_space_external_type = OpSpaceExternalType.space_2d;
		cosd.op_space_name = "test";
		op_space : OperationSpace = CreateClosedOpSpace(cosd,
			*perm.all_data.all_closed_op_spaces, 
			*perm.all_data.all_op_space_spec_data, 
			*perm.all_data.all_op_spec_data_3D);
		count_equal := AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
		op_spec_data : *OpSpaceSpecData;
		if count_equal {
			op_spec_data = *perm.all_data.all_op_space_spec_data[0];
		}
		circle : *CircleSpace = CreateCircleInOpSpace(.{}, op_spec_data, 
			perm.all_data.all_tuning_systems, perm.all_data.all_tuning_pitches);
	
		array_resize(*perm.test_data.all_sub_tests, 35+1);
	} 


	//TODO FROM HERE remove GetDefaultBaseCam2D since we don't use that anymore and replace with this
	//We can make a function GetRenderMSpaceCam
	render_mspace, found_render_mspace := ArrayFindFirstConstByNameId(perm.all_data.all_mspace_data, 
		perm.all_data.render_mspace_id, "mspace_id");
	AssertEquals(true, found_render_mspace);
	default_base_cam : Camera2D;
	if found_render_mspace {
		default_base_cam = render_mspace.mspace_cam;
	}


	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		DownUpInputMap(.TERMINAL_TOGGLE, game_input);
	}
	case 1; {
		open_test := MakeTerminalEvent(.open_op, "test");
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 2; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_2D := perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		//TEST That global zoom with mouse scroll does not trigger op space zoom and also the other way around
		AddPressKeyboard(.CTRL, .DOWN_THIS_FRAME, game_input);
		game_input.mouse_wheel = 1;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 3; {
		AssertEquals(true, renderer_data.default_pixels_per_square < renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_2D := perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		//TEST That op zoom with mouse scroll does not trigger op space zoom and also the other way around
		game_input.mouse_wheel = -1;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 4; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_2D := perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		//TEST That op zoom with mouse scroll does not trigger op space zoom and also the other way around
		game_input.mouse_wheel = -2;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 5; {
		AssertEquals(true, renderer_data.default_pixels_per_square > renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_2D := perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		//TEST That op zoom with mouse scroll does not trigger op space zoom and also the other way around
		game_input.mouse_wheel = +2;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 6; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_2D := perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AddPressKeyboard(.CTRL, .UP_THIS_FRAME, game_input);
		//TEST That op zoom with mouse scroll does not trigger op space zoom and also the other way around
		AddPressKeyboard(.ALT, .DOWN_THIS_FRAME, game_input);
		game_input.mouse_wheel = 1;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 7; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_2D := perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(true, 1.0 < op_2D.render_groups.scissor_group.zoom_factor);
		}

		//TEST That op zoom with mouse scroll does not trigger op space zoom and also the other way around
		game_input.mouse_wheel = -1;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 8; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_2D := perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		//TEST That op zoom with mouse scroll does not trigger op space zoom and also the other way around
		game_input.mouse_wheel = -2;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 9; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			op_2D := perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(true, 1.0 > op_2D.render_groups.scissor_group.zoom_factor);
		}

		//TEST That op zoom with mouse scroll does not trigger op space zoom and also the other way around
		game_input.mouse_wheel = +2;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 10; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AddPressKeyboard(.ALT, .UP_THIS_FRAME, game_input);

		AssertEquals(0.0, render_mspace.mspace_cam.world_pos.x);
		//TEST instantaneous global move then test instantaneous op space move
		//TODO USE THIS again ONCE THE jai-Input bug gets fixed. Details at GLOBAL_MOVE_INSTANTLY code in thegame_base.
		// DownUpInputMap(.GLOBAL_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
		cam_pos := op_2D.world_offset;
		cam_pos.x += op_2D.world_size.x + 1;
		game_input.mouse_cam = WorldSpaceToCameraSpace(cam_pos, default_base_cam);;
	}
	case 11; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(op_2D.world_size.x + 1, render_mspace.mspace_cam.world_pos.x);

		//TEST instantaneous op space move
		// DownUpInputMap(.GLOBAL_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{0,0}, default_base_cam);
	}
	case 12; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(0.0, render_mspace.mspace_cam.world_pos.x);

		AssertEquals(0.0, op_2D.op_2D_cam.world_pos.y);

		//TEST instantaneous op space move
		//TODO USE THIS again ONCE THE jai-Input bug gets fixed. Details at GLOBAL_MOVE_INSTANTLY code in thegame_base.
		// DownUpInputMap(.OP_SPACE_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.ALT, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
		cam_pos := op_2D.world_offset;
		cam_pos.y += 1;
		game_input.mouse_cam = WorldSpaceToCameraSpace(cam_pos, default_base_cam);
	}
	case 13; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(0.0, render_mspace.mspace_cam.world_pos.y);

		AssertEquals(1.0, op_2D.op_2D_cam.world_pos.y);

		//TEST instantaneous op space move
		// DownUpInputMap(.OP_SPACE_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.ALT, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
		cam_pos := op_2D.world_offset;
		cam_pos.y -= 1;
		game_input.mouse_cam = WorldSpaceToCameraSpace(cam_pos, default_base_cam);
	}
	case 14; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);

		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(0.0, render_mspace.mspace_cam.world_pos.y);

		AssertEquals(0.0, op_2D.op_2D_cam.world_pos.y);

		//TEST zoom and then move instantly on the same frame should affect the actual movement
		DownUpThisFrame(.ALT, game_input);
		game_input.mouse_wheel = 2;
		// DownUpInputMap(.OP_SPACE_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.ALT, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
		cam_pos := op_2D.world_offset + Vector2F.{1,1};
		game_input.mouse_cam = WorldSpaceToCameraSpace(cam_pos, default_base_cam);
	}
	case 15; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);

		//TODO this can be taken from settings if we ever add this there eventually
		//2*0.04 since the mouse wheel is 2
		default_zoom_speed : float = 1 + 2*0.04;
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			//TODO Can update this from settings if we add op space zoom speed to runtime settings eventually
			AssertEquals(default_zoom_speed, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(0.0, render_mspace.mspace_cam.world_pos.y);

		AssertEquals(Vector2F.{1/default_zoom_speed,1/default_zoom_speed}, op_2D.op_2D_cam.world_pos);

		//TEST zoom and then move instantly should affect the actual movement
		DownUpThisFrame(.ALT, game_input);
		game_input.mouse_wheel = -2;
		// DownUpInputMap(.OP_SPACE_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.ALT, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
		cam_pos := op_2D.world_offset + Vector2F.{-1/default_zoom_speed,-1/default_zoom_speed};
		game_input.mouse_cam = WorldSpaceToCameraSpace(cam_pos, default_base_cam);
	}
	case 16; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(0.0, render_mspace.mspace_cam.world_pos.y);

		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST global zoom and move instantly same frame
		//should not affect the movement since we update pixels per square directly
		DownUpThisFrame(.CTRL, game_input);
		game_input.mouse_wheel = 2;
		// DownUpInputMap(.GLOBAL_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
		cam_pos := op_2D.world_offset - op_2D.world_size - Vector2F.{1,1};
		game_input.mouse_cam = WorldSpaceToCameraSpace(cam_pos, default_base_cam);
	}
	case 17; {
		AssertEquals(true, renderer_data.default_pixels_per_square < renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		new_cam_pos := Vector2F.{0,0} - op_2D.world_size - Vector2F.{1,1};
		AssertEquals(new_cam_pos, render_mspace.mspace_cam.world_pos);
		AssertEquals(new_cam_pos, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST global zoom and move instantly same frame
		DownUpThisFrame(.CTRL, game_input);
		game_input.mouse_wheel = -2;
		// DownUpInputMap(.GLOBAL_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{0,0}, default_base_cam);
	}
	case 18; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

	}
	case 19; {
		RunSubTestNTimes(6, *perm.test_data);
		//TEST global zoom shortcut
		DownUpInputMap(.GLOBAL_ZOOM_IN, game_input);
	}
	case 20; {
		AssertEquals(renderer_data.default_pixels_per_square + 6*global_zoom_speed, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

	}
	case 21; {
		RunSubTestNTimes(10, *perm.test_data);
		//TEST global zoom shortcut
		DownUpInputMap(.GLOBAL_ZOOM_OUT, game_input);
	}
	case 22; {
		AssertEquals(renderer_data.default_pixels_per_square - (10-6)*global_zoom_speed, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(renderer_data.base_render_group.pixels_per_square, op_2D.render_groups.scissor_group.pixels_per_square);
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST zoom and then move instantly should affect the actual movement
		DownUpInputMap(.GLOBAL_ZOOM_RESET, game_input);
	}
	case 23; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST global zoom bounds with mouse wheel
		DownUpThisFrame(.CTRL, game_input);
		game_input.mouse_wheel = 100;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 24; {
		AssertEquals(global_zoom_pixel_max, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST global zoom bounds with mouse wheel
		DownUpThisFrame(.CTRL, game_input);
		game_input.mouse_wheel = -200;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 25; {
		AssertEquals(global_zoom_pixel_min, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST zoom and then move instantly should affect the actual movement
		DownUpInputMap(.GLOBAL_ZOOM_RESET, game_input);
	}
	case 26; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST op space zoom bounds with mouse wheel
		DownUpThisFrame(.ALT, game_input);
		game_input.mouse_wheel = 100;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 27; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(op_zoom_max_factor, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST op space zoom bounds with mouse wheel
		DownUpThisFrame(.ALT, game_input);
		game_input.mouse_wheel = -200;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 28; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(op_zoom_min_factor, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST op space zoom bounds with mouse wheel
		DownUpInputMap(.OP_SPACE_ZOOM_RESET, game_input);
	}
	case 29; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST op space cam movement with scroll wheel same frame
		DownUpThisFrame(#char "W", game_input);
		DownUpThisFrame(.ALT, game_input);
		game_input.mouse_wheel = +1;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 30; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0 + op_zoom_speed, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(true, op_2D.op_2D_cam.world_pos.y > 0);

		//TEST op space cam movement with scroll wheel same frame
		DownUpThisFrame(#char "S", game_input);
		DownUpThisFrame(.ALT, game_input);
		game_input.mouse_wheel = -1;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 31; {
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST op space zoom bounds with mouse wheel
		cam_pos := op_2D.world_offset + op_2D.world_size + Vector2F.{1,1};
		game_input.mouse_cam = WorldSpaceToCameraSpace(cam_pos, default_base_cam);
		DownUpThisFrame(.MOUSE_BUTTON_LEFT, game_input);
	}
	case 32; {
		AssertEquals(0, perm.all_data.all_chosen_entities.count);
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(Vector2F.{0,0}, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST global cam movement with scroll wheel same frame
		DownUpThisFrame(#char "W", game_input);
		DownUpThisFrame(.CTRL, game_input);
		game_input.mouse_wheel = +1;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 33; {
		AssertEquals(0, perm.all_data.all_chosen_entities.count);
		AssertEquals(renderer_data.default_pixels_per_square + global_zoom_speed, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(true, render_mspace.mspace_cam.world_pos.y > 0);
		AssertEquals(render_mspace.mspace_cam.world_pos, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST global cam movement with scroll wheel same frame
		DownUpThisFrame(#char "S", game_input);
		DownUpThisFrame(.CTRL, game_input);
		game_input.mouse_wheel = -1;
		game_input.mouse_cam = Vector2F.{0,0};
	}
	case 34; {
		AssertEquals(0, perm.all_data.all_chosen_entities.count);
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(true, render_mspace.mspace_cam.world_pos.y <= 0);
		AssertEquals(render_mspace.mspace_cam.world_pos, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST reset back to center with unchosen op space
		game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{0,0}, default_base_cam);
		// DownUpInputMap(.GLOBAL_MOVE_INSTANTLY, game_input);
		DownUpThisFrame(.CTRL, game_input);
		DownUpThisFrame(.MOUSE_BUTTON_RIGHT, game_input);
	}
	case 35; {
		AssertEquals(0, perm.all_data.all_chosen_entities.count);
		AssertEquals(renderer_data.default_pixels_per_square, renderer_data.base_render_group.pixels_per_square);
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		op_2D : OperationSpace;
		if count_equals {
			op_2D = perm.all_data.all_open_op_spaces[1];
			AssertEquals(1.0, op_2D.render_groups.scissor_group.zoom_factor);
			for perm.all_data.all_open_op_spaces {
				AssertEquals(renderer_data.base_render_group.pixels_per_square, it.render_groups.scissor_group.pixels_per_square);
			}
		}

		AssertEquals(Vector2F.{0,0}, render_mspace.mspace_cam.world_pos);
		AssertEquals(render_mspace.mspace_cam.world_pos, op_2D.world_offset);
		AssertEquals(Vector2F.{0,0}, op_2D.op_2D_cam.world_pos);

		//TEST global cam movement with scroll wheel same frame
		// game_input.mouse_cam = WorldSpaceToCameraSpace(Vector2F.{0,0}, default_base_cam);
		// DownUpInputMap(.GLOBAL_MOVE_INSTANTLY, game_input);
	}
	}
	//TODO SHOULD I SWITCH global zoom and instant move back to ctrl+shift to not confuse between ctrl and alt?
	//TODO FROM HERE just test zooming with shortcuts and also test min/max zoom with large mouse wheel scroll
	//THEN update default base cam function to use GetRenderMSpaceCam instead in tests
	//then start on mspace music points audio/rendering

	ContinueTest(*perm.test_data);

} @ITest

Test_CreateRow :: (
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
		//TODO FROM HERE Can likely call SetupMusic in here by default so we have basic music setup
		//and then it can be updated in the code whenever using the function below.
		perm.all_data = InitAllData();
		ResetAllRendererData(renderer_data);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
#load "c_load/Library";
main :: () {
  //TODO Implement struct literals
  rs : [2] RowSectionData;
  rs[0].linear_view = LinearPitchSpaceView.RATIO_PROPORTIONAL;
  rs[0].tuning_system_id = 0;
  rs[0].x_length = 12;
  rs[1].linear_view = LinearPitchSpaceView.RATIO_PROPORTIONAL;
  rs[1].tuning_system_id = 1;
  rs[1].x_length = 12;

  rd : AsmCreateRowData;
  rd.octave_height = 12.0;
  rd.row_height = 12.0;
  rd.muted_row = false;
  rd.row_sections = rs;
  rd.row_system_type = RowSystemType.internal_pitch;
  #asm{ create_row rd; }
}
DONE);
		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 5);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equals := AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_lane_rows.count);
		count_equals = AssertEquals(2, perm.all_data.all_mspace_data[0].all_section_to_row.count);
		if count_equals {
			row := perm.all_data.all_mspace_data[0].all_music_lane_rows[0];
			AssertFloat64Equals(12.0, row.octave_height);
			AssertFloat64Equals(12.0, row.row_height);
			AssertEquals(false, row.is_muted_row);
			AssertEquals(RowSystemType.internal_pitch, row.row_system_type);

			sect_0 := perm.all_data.all_mspace_data[0].all_section_to_row[0];
			AssertEquals(0, sect_0.row_id);
			AssertEquals(0, sect_0.dspace_id);
			AssertEquals(0, sect_0.start_x);
			AssertEquals(12, sect_0.end_x);
			AssertEquals(0, sect_0.tuning_system_id);

			sect_1 := perm.all_data.all_mspace_data[0].all_section_to_row[1];
			AssertEquals(0, sect_1.row_id);
			AssertEquals(1, sect_1.dspace_id);
			AssertEquals(12, sect_1.start_x);
			AssertEquals(24, sect_1.end_x);
			AssertEquals(1, sect_1.tuning_system_id);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_RowSynth :: (
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
		//TODO FROM HERE Can likely call SetupMusic in here by default so we have basic music setup
		//and then it can be updated in the code whenever using the function below.
		perm.all_data = InitAllData();
		ResetAllRendererData(renderer_data);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
#load "c_load/Library";
main :: () {
	//mspace_id 0 is the default mspace
	//This will clear all the rows and neumes in this mspace
	//which allows us to recreate them every time we run this code.
	clear_m0 : AsmClearMSpaceData;
	clear_m0.mspace_id = 0;
	#asm{ clear_mspace clear_m0; }

	synth : AsmGetOrCreateSimpleSynthData;
	synth.synth_name = "s0";
	#asm{ get_or_create_simple_synth synth; }
	update_synth : AsmUpdateSimpleSynthData;
	update_synth.update_wave_type = true;
	update_synth.wave_type = OscWaveType.SINE;
	//Volume is between 0-1 and is set for each music pt
	//so 0.1 for 3 values will be 0.3 overall
	//anything above 1 will be clipped and likely cause audible distortion
	update_synth.update_volume = true;
	update_synth.volume = 0.1;
	#asm{ update_simple_synth update_synth; }

	rs : RowSectionData;
	rs.tuning_system_id = 0;
	rs.x_length = 12;
	rd : AsmCreateRowData;
	rd.octave_height = 12.0;
	rd.row_height = 12.0;
	rd.muted_row = false;
	rd.row_sections = RowSectionData.[rs];
	rd.row_system_type = RowSystemType.internal_pitch;
	rd.row_system_id = synth.ret_synth_id;
	//Can use this to send the music pt value as midi pitch
	// rd.row_system_type = RowSystemType.midi_pitch;
	// rd.row_midi_data.midi_channel = 0;
	// rd.row_midi_data.midi_velocity = 100;
	#asm{ create_row rd; }

	tano(0,0..12) ~= int.[0,4,7];

	/*
	rd.row_system_id = synth.ret_synth_id;
	rd.row_sub_system_id = cast(int) SimpleSynthMessageType.VOLUME;
	//Can use right click knob and press link controller in fl studio 
	//to set midi channel and cc messages.
	//cc messages may not map directly to the music point values
	// rd.row_system_type = RowSystemType.midi_control_change;
	// rd.row_midi_data.midi_channel = 0;
	// rd.row_midi_data.midi_control_change = 0;
	#asm{ create_row rd; }

	for x : 0..11 {
		tano(1,x) ~= 0.15 * cast(float) x;
		//For midi cc message
		// tano(1,x) ~= 10*x;
	}
	*/
}
DONE);
		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 4+1);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equals := AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_lane_rows.count);
		count_equals = AssertEquals(1, perm.all_data.all_mspace_data[0].all_section_to_row.count);
		count_equals = AssertEquals(2, perm.all_data.all_simple_synths.count);
		if count_equals {
			synth := perm.all_data.all_simple_synths[1];
			AssertEquals("s0", synth.synth_name);
		}
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CreateTuning :: (
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
		//TODO FROM HERE Can likely call SetupMusic in here by default so we have basic music setup
		//and then it can be updated in the code whenever using the function below.
		perm.all_data = InitAllData();
		ResetAllRendererData(renderer_data);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
#load "c_load/Library";
main :: () {
	ct : AsmCreateTuningData;
	ct.create_tuning_type = CreateTuningType.EQUAL_TEMPERAMENT;
	ct.name = "Test ET";
	ct.short_name  = "tet";
	ct.compass_interval = 2.0;
	ct.point_count = 20;
	#asm{ create_tuning_system ct; }

	ct_r : AsmCreateTuningData;
	ct_r.create_tuning_type = CreateTuningType.RATIOS_FROM_START;
	ct_r.name = "Test Ratio";
	ct_r.short_name = "tra";
	ct_r.compass_interval = 2.0;
	ct_r.values = float64.[1, 1.11, 1.89];
	#asm{ create_tuning_system ct_r; }
}
DONE);
		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 4+1);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		eq_tuning : TuningSystem = perm.all_data.all_tuning_systems[perm.all_data.all_tuning_systems.count-2];
		AssertEquals("Test ET", eq_tuning.name);
		AssertEquals("tet", eq_tuning.short_name);
		AssertFloat64Equals(2.0, eq_tuning.compass_interval);
		AssertEquals(20, eq_tuning.music_pt_count);
		eq_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, eq_tuning.id, "tuning_system_id");
		AssertEquals(eq_tuning.music_pt_count, eq_pitches.count);

		ratio_tuning : TuningSystem = perm.all_data.all_tuning_systems[perm.all_data.all_tuning_systems.count-1];
		AssertEquals("Test Ratio", ratio_tuning.name);
		AssertEquals("tra", ratio_tuning.short_name);
		AssertFloat64Equals(2.0, ratio_tuning.compass_interval);
		AssertEquals(3, ratio_tuning.music_pt_count);
		ratio_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, ratio_tuning.id, "tuning_system_id");
		AssertEquals(ratio_tuning.music_pt_count, ratio_pitches.count);
		AssertEquals(0, ratio_pitches[0].music_pt_pos);
		AssertFloat64Equals(1.0, ratio_pitches[0].ratio_from_start);
		AssertEquals(1, ratio_pitches[1].music_pt_pos);
		AssertFloat64Equals(1.11, ratio_pitches[1].ratio_from_start);
		AssertEquals(2, ratio_pitches[2].music_pt_pos);
		AssertFloat64Equals(1.89, ratio_pitches[2].ratio_from_start);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CreateSpace :: (
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
		//TODO FROM HERE Can likely call SetupMusic in here by default so we have basic music setup
		//and then it can be updated in the code whenever using the function below.
		perm.all_data = InitAllData();
		ResetAllRendererData(renderer_data);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
#string DONE
#load "c_load/Library";
main :: () {
	csd : AsmOpSpaceData;
	csd.op_space_type = AsmOpSpaceType.space_2d;
	csd.op_space_name = "test_2d";
	#asm{ get_or_create_op_space csd; }

	id : int = csd.ret_op_space_id;

	cs : AsmCircleData;
	cs.op_space_id = csd.ret_op_space_id;
	cs.radius = 9.0;
	cs.repeating_interval_ratio = 2.0;
	cs.point_dim = Vector2.{0.6,0.6};
	#asm{ create_circle cs; }

	clear : AsmClearOpData;
	clear.op_space_id = csd.ret_op_space_id;
	#asm{ clear_op_space clear; }
}
DONE);

		//TODO We could just load_op now since we don't use the other tab
		//in this test. OR add an open_op_tab instruction
		//OR just call OpenFileTab from the test here to open other tabs
		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 7+1);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		CodeBPForTest(7, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equals := AssertEquals(1, perm.all_data.all_closed_op_spaces.count);
		if count_equals {
			space_2d := perm.all_data.all_closed_op_spaces[0];
			AssertEquals("test_2d", space_2d.op_space_name);
			AssertEquals(OpSpaceExternalType.space_2d, space_2d.op_space_external_type);
			AssertEquals(1, space_2d.id);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		count_equals := AssertEquals(4, text_op.text_comp_data.all_variables.count);
		if count_equals {
			id_var : VariableData = text_op.text_comp_data.all_variables[1];
			id_value : int = ComputeOperandInt(id_var.op, perm.all_data.all_register_memory, perm.all_data.ram_memory);
			AssertEquals(1, id_value);
		}

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 6; {
		open_test_2d := MakeTerminalEvent(.open_op, "test_2d");
		array_add(*perm.all_data.all_terminal_events, open_test_2d);
	}
	case 7; {
		count_equals := AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		if count_equals {
			AssertEquals(0, perm.all_data.all_open_op_spaces[0].id);
			AssertEquals(1, perm.all_data.all_open_op_spaces[1].id);

			//TEST That we cleared the op space so there should be no circle
			count_equals = AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
			if count_equals {
				AssertEquals(0, perm.all_data.all_op_space_spec_data[0].all_op_circle_spaces.count);
			}
		}		
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CodeCircle :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		cosd : CreateOpSpaceData;
		cosd.op_space_external_type = OpSpaceExternalType.space_2d;
		cosd.op_space_name = "test";
		op_space : OperationSpace = CreateClosedOpSpace(cosd,
			*perm.all_data.all_closed_op_spaces, 
			*perm.all_data.all_op_space_spec_data, 
			*perm.all_data.all_op_spec_data_3D);

		WriteFileString(text_file, sprint(
#string DONE
#load "c_load/Library";
main :: () {
  cs : AsmCircleData;
  cs.op_space_id = %;
  cs.radius = 9.0;
  cs.world_center = Vector2.{0,0};
  cs.rotate_theta = 1.570796;
  cs.point_dim = Vector2.{0.6,0.6};
  cs.is_clockwise = true;
  cs.repeating_interval_ratio = 2.0;
  cs.tuning_system_id = 0;
  cs.non_repeating = false;
  cs.start_note = 0;
  cs.is_sound_float = false;
  cs.inner_circle_mute = 0.;
  cs.no_base_points = false;
  #asm{ create_circle cs; }

  mc : AsmMapCircle;
  mc.dspace_id = cs.ret_dspace_id;
  mc.op_space_id = cs.op_space_id;
  mc.pitches = float64.[0,4.5,7];
  mc.draw_vl_type = DrawVLType.VL_LINE;
  #asm{ map_circle mc; }
}
DONE, op_space.id));
	
		array_resize(*perm.test_data.all_sub_tests, 8+1);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equals := AssertEquals(1, perm.all_data.all_closed_op_spaces.count);
		if count_equals {
			space_2d := perm.all_data.all_closed_op_spaces[0];
			AssertEquals("test", space_2d.op_space_name);
			AssertEquals(OpSpaceExternalType.space_2d, space_2d.op_space_external_type);
			AssertEquals(1, space_2d.id);
		}

		count_equals = AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
		op_spec_data : OpSpaceSpecData;
		if count_equals {
			op_spec_data = perm.all_data.all_op_space_spec_data[0];
		}

		count_equals = AssertEquals(1, op_spec_data.all_op_circle_spaces.count);
		if count_equals {
			cs := op_spec_data.all_op_circle_spaces[0];
			AssertFloat64Equals(9.0, cs.radius);
			AssertFloat64Equals(2.0, cs.repeating_interval_ratio);
			AssertEquals(true, cs.is_repeating);
			AssertEquals(false, cs.is_sound_float);

			//12 for circle base points and 3 for mapped points
			count_equals = AssertEquals(12+3, op_spec_data.ass.all_space_rects.count);
			if count_equals {
				//NOTE : We just check some consistent values here without checking specific values everywhere
				//so that we don't have to update things if they change later.
				for 0..11 {
					s_rect := op_spec_data.ass.all_space_rects[it];
					AssertEquals(it, s_rect.shape_id);
					AssertEquals(0, s_rect.dspace_id);
					AssertEquals(1, s_rect.op_space_id);
					AssertEquals(cs.base_shape_group, s_rect.dspace_shape_group);
					AssertEquals(cs.base_render_order, s_rect.render_order);
					AssertArrayEquals(float64.[cast(float64) it], s_rect.pitch_set);
					AssertEquals(tprint("%",it), s_rect.shape_text);
				}
				for 12..12+2 {
					s_rect := op_spec_data.ass.all_space_rects[it];
					AssertEquals(it, s_rect.shape_id);
					AssertEquals(0, s_rect.dspace_id);
					AssertEquals(1, s_rect.op_space_id);
					AssertEquals(0, s_rect.dspace_shape_group);
					AssertEquals(cs.base_render_order+2, s_rect.render_order);
				}
			}

			tuning_system := ArrayFindFirstByNameId(perm.all_data.all_tuning_systems, cs.tuning_system_id, "id");
			tuning_pitches := ArrayFindAllVarName(perm.all_data.all_tuning_pitches, tuning_system.id, "tuning_system_id");

			#if 0 {
			count_equals = AssertEquals(12+3, op_spec_data.ass.all_space_shape_values.count);
			if count_equals {
				for 0..11 {
					s_value := op_spec_data.ass.all_space_shape_values[it];
					AssertEquals(it, s_value.shape_id);
					frequency : float = MusicPtToFrequency(cast(float64)it, tuning_system, tuning_pitches);
					AssertFloatEquals(frequency, cast(float) s_value.float_value);
				}
				map_0 := op_spec_data.ass.all_space_shape_values[12];
				AssertEquals(12, map_0.shape_id);
				map_freq0 : float = MusicPtToFrequency(0, tuning_system, tuning_pitches);
				AssertFloatEquals(map_freq0, cast(float) map_0.float_value);					

				map_1 := op_spec_data.ass.all_space_shape_values[12+1];
				AssertEquals(12+1, map_1.shape_id);
				map_freq1 : float = MusicPtToFrequency(4.5, tuning_system, tuning_pitches);
				AssertFloatEquals(map_freq1, cast(float) map_1.float_value);					

				map_2 := op_spec_data.ass.all_space_shape_values[12+2];
				AssertEquals(12+2, map_2.shape_id);
				map_freq2 : float = MusicPtToFrequency(7, tuning_system, tuning_pitches);
				AssertFloatEquals(map_freq2, cast(float) map_2.float_value);					
			}
			}
		}
	}
	case 5; {
		open_circle := MakeTerminalEvent(.open_op, "test");
		array_add(*perm.all_data.all_terminal_events, open_circle);
	}
	case 6; {
		AssertEquals(2, perm.all_data.all_open_op_spaces.count);

		//TEST : Close the op spaces do see if freeing multiple render groups works
		array_add(*perm.all_data.all_terminal_events, MakeTerminalEvent(.close_op, TEST_TEXT_NAME));
		array_add(*perm.all_data.all_terminal_events, MakeTerminalEvent(.close_op, "test"));
	}
	case 7; {
		AssertEquals(8, renderer_data.all_render_groups.count);
		AssertEquals(0, renderer_data.open_op_space_render_groups.count);
		AssertEquals(2, renderer_data.free_op_space_render_groups.count);

		//TEST : Reopen the op spaces to make sure we reuse multiple render groups
		array_add(*perm.all_data.all_terminal_events, MakeTerminalEvent(.open_op, TEST_TEXT_NAME));
		array_add(*perm.all_data.all_terminal_events, MakeTerminalEvent(.open_op, "test"));
	}
	case 8; {
		AssertEquals(8, renderer_data.all_render_groups.count);
		AssertEquals(2, renderer_data.open_op_space_render_groups.count);
		AssertEquals(0, renderer_data.free_op_space_render_groups.count);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO FROM HERE remove the old shape value method
//generalize asm library gen and MAYBE thinkg of adding render order to shapes like circle and chord s2 and spiral
//so people can decide which one goes on top of what since now the render order is fixed just need to pass into asm
//then add spiral and circle to new data and also think of render order before doing rows
//ALSO should we updte asm 2d names with 2d at the end?
//then can also update the names for 3d (create_cs3->create_s3) AND add spiral or generalize asm data first
Test_CodeCS2 :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);

		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		cosd : CreateOpSpaceData;
		cosd.op_space_external_type = OpSpaceExternalType.space_2d;
		cosd.op_space_name = "test";
		op_space : OperationSpace = CreateClosedOpSpace(cosd,
			*perm.all_data.all_closed_op_spaces, 
			*perm.all_data.all_op_space_spec_data, 
			*perm.all_data.all_op_spec_data_3D);

//TODO We can pull this out into a file and use this string as a test and an example for 3d chord spaces
		WriteFileString(text_file,sprint(
#string DONE
#load "c_load/Library";
main :: () {
	cs2 : AsmChordS2Data;
	//The dspace id will be returned here
	// cs.dspace_id = 0;
	cs2.op_space_id = %;
	cs2.world_pos = Vector2.{0,0};
	cs2.scale_world_unit = 2.0;
   cs2.point_dim = Vector2.{0.7,0.7};
   cs2.lp_count = 12;
	cs2.tuning_system_id = 0;
	cs2.is_sound_float = false;
	cs2.vl_order_text = true;
	cs2.vl_order_color = true;
	cs2.osc_wave_type = OscWaveType.SAW;
	csf_array : [1] AsmCSFilter;
	csf_array[0].filter_type = ChordSpaceFilterType.ALL;
	// csf_array[0].filter_type = ChordSpaceFilterType.CHROMATIC;
	// csf_array[1].filter_type = ChordSpaceFilterType.IN_VALUE_SET;
	// csf_array[1].value_set = float64.[0,4];
	cs2.asm_cs_filters = csf_array;
	#asm{ create_cs2 cs2; }

	mc : MapChordS2Data;
	mc.dspace_id = cs2.ret_dspace_id;
	mc.op_space_id = cs2.op_space_id;
	//[6,9] and [7,10] work well here
	mc.vl_start_chord = float.[6,9];
	mc.vl_deltas = float.[
		-4,-3,
		+2,+2,
		+2,+2
	];
	#asm{ map_cs2 mc; }

	ag : AsmGeom2D;
	ag.op_space_id = cs2.op_space_id;
	//TODO When we add tuning system instructions we can grab that by name here for clarity
	ag.custom_audio_type = CustomAudioType.TUNING_SYSTEM;
	ag.tuning_system_id = 2;
	ag.osc_wave_type = OscWaveType.SAW;
	ag.collision_pos = Vector2.{10,0};
	ag.collision_dim = Vector2.{3,3};
	ag.show_collision = true;
	#asm{ create_custom_geometry ag; }

	//TODO FROM HERE just check this is working and add 2d text before generalizing asm output
	//and then do spiral and circles with new data and then move to rows
	shape : AsmShapeData;
	shape.op_space_id = cs2.op_space_id;
	shape.dspace_id = ag.ret_dspace_id;
	shape.pitch_set = float64.[0,8,14];
	shape.shape_text = "24-[0,8,14]";
	shape.color = Vector4.{0,1,0,1};
	shape.type = AsmShapeType.RECTANGLE;
	shape.rect_pos = Vector2.{10,0};
	shape.rect_dim = Vector2.{0.5,0.5};
	#asm{ create_shape shape; }

	//TODO Maybe these asm instructions should have 2d at the end like 3d for consistency
	txt : AsmText2D;
	txt.op_space_id = cs2.op_space_id;
	txt.text = "24eq";
	txt.op_pos = Vector2.{10,1};
	txt.color = Vector4.{0.95,0.95,0.95,1};
	#asm{ create_text txt; }
}
DONE, op_space.id));

	
		array_resize(*perm.test_data.all_sub_tests, 5+1);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equals := AssertEquals(1, perm.all_data.all_closed_op_spaces.count);
		op_2d : OperationSpace;
		if count_equals {
			op_2d = perm.all_data.all_closed_op_spaces[0];
			AssertEquals("test", op_2d.op_space_name);
			AssertEquals(OpSpaceExternalType.space_2d, op_2d.op_space_external_type);
		}

		count_equals = AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
		op_spec : OpSpaceSpecData;
		if count_equals {
			op_spec = perm.all_data.all_op_space_spec_data[0];
		}

		count_equals = AssertEquals(1, perm.all_data.all_cs2_points_2D.count);
		if count_equals {
			AssertEquals(12, perm.all_data.all_cs2_points_2D[0].lp_count);
			AssertEquals(85, perm.all_data.all_cs2_points_2D[0].chord_sp_2D.count);
		}

		count_equals = AssertEquals(1, op_spec.all_op_chord_s2.count);
		count_equals = AssertEquals(173, op_spec.ass.all_space_rects.count);
		if count_equals {
			AssertArrayEquals(float64.[0,8,14], peek(op_spec.ass.all_space_rects).pitch_set);
			AssertEquals("24-[0,8,14]", peek(op_spec.ass.all_space_rects).shape_text);
		}
		count_equals = AssertEquals(1, op_spec.ass.all_custom_geometries.count);
		if count_equals {
			AssertEquals(2, op_spec.ass.all_custom_geometries[0].tuning_system_id);
		}
		count_equals = AssertEquals(5, op_spec.ass.all_space_text.count);
		if count_equals {
			AssertEquals("24eq", peek(op_spec.ass.all_space_text).text);
			AssertEquals(Vector2F.{10,1}, peek(op_spec.ass.all_space_text).op_pos);
		}



		open_op := MakeTerminalEvent(.open_op, "test");
		array_add(*perm.all_data.all_terminal_events, open_op);
	}
	case 5; {
		AssertEquals(2, perm.all_data.all_open_op_spaces.count);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_CodeSpiral :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);

		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		cosd : CreateOpSpaceData;
		cosd.op_space_external_type = OpSpaceExternalType.space_2d;
		cosd.op_space_name = "test";
		op_space : OperationSpace = CreateClosedOpSpace(cosd,
			*perm.all_data.all_closed_op_spaces, 
			*perm.all_data.all_op_space_spec_data, 
			*perm.all_data.all_op_spec_data_3D);

//TODO We can pull this out into a file and use this string as a test and an example for 3d chord spaces
		WriteFileString(text_file,sprint(
#string DONE
#load "c_load/Library";
main :: () {
	//This can be put in a function for reuse and for different default spirals
	sp : AsmCreateSpiral;
	sp.op_space_id = %;
	sp.spiral_type = SpiralType.PROPER;
	sp.world_pos = Vector2.{0,0};
	sp.tuning_system_id = 0;
	//C3 TODO Put these as constants in the Library
	sp.pitch_zero_freq = 130.8128;
	sp.tuning_count = 12;
	sp.chord_count = 3;
	//TODO Put PI as constant in library and test
	sp.rotate = 0.5 * 3.14159265;
	sp.is_clockwise = true;
	sp.radius_size = 3.; // Use to adjust spiral_delta size going out
	sp.sr_factor = 1.5; // Use to adjust inner radius size (although it does effect overall spiral size as well)
	sp.is_in_out = true;
	sp.sound_float = false;
	sp.is_loop = true;
	sp.show_values = true;
	sp.point_dim = Vector2.{0.5,0.5};
	sp.osc_wave_type = OscWaveType.SAW;
	sp.base_chord = float64.[0,4,7];
	sp.base_index = 0;
	#asm{ create_spiral sp; }

	ms : AsmMapSpiral;
	ms.dspace_id = sp.ret_dspace_id;
	ms.op_space_id = sp.op_space_id;
	ms.draw_vl_lines = true;
	ms.map_chords = float64.[
		0,4,7,
		0+2,4+2,7+2,
		0+5,4+5,7+5,
		0,4,7
	];
	#asm{ map_spiral ms; }

	//TODO Can likely remove this for example code but good her efor testing
	// ag : AsmGeom2D;
	// ag.op_space_id = sp.op_space_id;
	// ag.custom_audio_type = CustomAudioType.TUNING_SYSTEM;
	// ag.tuning_system_id = 2;
	// ag.osc_wave_type = OscWaveType.SAW;
	// ag.collision_pos = Vector2.{11,0};
	// ag.collision_dim = Vector2.{3,3};
	// ag.show_collision = true;
	// #asm{ create_custom_geometry ag; }

	shape : AsmShapeData;
	shape.op_space_id = sp.op_space_id;
	shape.dspace_id = sp.ret_dspace_id;
	shape.render_order = 10;
	shape.pitch_set = float64.[0,8,14];
	shape.shape_text = "12-[0,8,14]";
	shape.color = Vector4.{0,1,0,1};
	shape.type = AsmShapeType.RECTANGLE;
	shape.rect_pos = Vector2.{11,0};
	shape.rect_dim = Vector2.{0.5,0.5};
	#asm{ create_shape shape; }
}
DONE, op_space.id));


	// //TODO Maybe these asm instructions should have 2d at the end like 3d for consistency
	// txt : AsmText2D;
	// txt.op_space_id = cs2.op_space_id;
	// txt.text = "24eq";
	// txt.op_pos = Vector2.{10,1};
	// txt.color = Vector4.{0.95,0.95,0.95,1};
	// #asm{ create_text txt; }

	
		array_resize(*perm.test_data.all_sub_tests, 5+1);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equals := AssertEquals(1, perm.all_data.all_closed_op_spaces.count);
		op_2d : OperationSpace;
		if count_equals {
			op_2d = perm.all_data.all_closed_op_spaces[0];
			AssertEquals("test", op_2d.op_space_name);
			AssertEquals(OpSpaceExternalType.space_2d, op_2d.op_space_external_type);
		}

		count_equals = AssertEquals(1, perm.all_data.all_op_space_spec_data.count);
		op_spec : OpSpaceSpecData;
		if count_equals {
			op_spec = perm.all_data.all_op_space_spec_data[0];
		}

		count_equals = AssertEquals(1, op_spec.all_op_spirals.count);
		if count_equals {
			AssertArrayEquals(float64.[0,4,7], op_spec.all_op_spirals[0].base_chord);
			AssertEquals(12, op_spec.all_op_spirals[0].tuning_count);
			AssertEquals(3, op_spec.all_op_spirals[0].chord_count);
		}
		count_equals = AssertEquals(17, op_spec.ass.all_space_rects.count);
		if count_equals {
			// AssertArrayEquals(float64.[0,8,14], peek(op_spec.ass.all_space_rects).pitch_set);
			// AssertEquals("24-[0,8,14]", peek(op_spec.ass.all_space_rects).shape_text);
		}
		count_equals = AssertEquals(12, op_spec.ass.all_space_text.count);
		if count_equals {
			// AssertEquals("24eq", peek(op_spec.ass.all_space_text).text);
			// AssertEquals(Vector2F.{10,1}, peek(op_spec.ass.all_space_text).op_pos);
		}



		open_op := MakeTerminalEvent(.open_op, "test");
		array_add(*perm.all_data.all_terminal_events, open_op);
	}
	case 5; {
		AssertEquals(2, perm.all_data.all_open_op_spaces.count);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_Code3D :: (
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

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);

		//TODO In case we want to see the library in the text editor since we can't do this in-game right now.
		load_file, load_success := LoadTextFile("c_load/Library", *perm.all_data.all_text_files);
		// if load_success array_add(*perm.all_data.all_text_files, load_file);
		text_op := CreateTextOpSpace(.[text_file.id, load_file.id], perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
		// text_op := CreateTextOpSpace(text_file.id, perm.text_editor_data, 
		// 	renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);

		cosd : CreateOpSpaceData;
		cosd.op_space_external_type = OpSpaceExternalType.space_3d;
		cosd.op_space_name = "test";
		op_space : OperationSpace = CreateClosedOpSpace(cosd,
			*perm.all_data.all_closed_op_spaces, 
			*perm.all_data.all_op_space_spec_data, 
			*perm.all_data.all_op_spec_data_3D);

//TODO We can pull this out into a file and use this string as a test and an example for 3d chord spaces
		WriteFileString(text_file,sprint(
#string DONE
#load "c_load/Library";
main :: () {
	cs3 : AsmSpace3Data;
	cs3.op_space_id = %;
	cs3.tuning_system_id = 0;
	cs3.higher_dim = 3;
	cs3.s3_cam_start_type = S3CamStartType.USER_SET;
	// cs3.cam_start_pos = Vector3.{0.,0.,0.};
	cs3.osc_wave_type = OscWaveType.SINE;
	cs3.set_3d_perspective = false;
	cs3.depth = 24.0;
	cs3.n = 1.0; 
	cs3.f = 240.0;

	//TODO Could make a test with this to check this with array literals and struct literal inside
	// csf : AsmCSFilter;
	// csf.filter_type = ChordSpaceFilterType.CHROMATIC;
	// cs3.asm_cs_filters = AsmCSFilter.[csf];
	//TODO This does not work because of struct member offset for non-direct struct like array or pointer dereference
	csf_array : [1] AsmCSFilter;
	csf_array[0].filter_type = ChordSpaceFilterType.CHROMATIC;
	cs3.asm_cs_filters = csf_array;

	#asm{ create_cs3 cs3; }


	mc : MapChordS3Data;
	mc.op_space_id = cs3.op_space_id;
	mc.vl_start_chord = float.[0,4,7];
	mc.vl_deltas = float.[
		0,-1,0,
		8,9,8
	];
	#asm{ map_cs3 mc; }

	ag : AsmGeom3D;
	ag.group_id = 1;
	ag.op_space_id = cs3.op_space_id;
	//TODO When we add tuning system instructions we can grab that by name here for clarity
	ag.tuning_system_id = 2;
	ag.osc_wave_type = OscWaveType.SAW;
	#asm{ create_custom_3D ag; }

	shape : AsmShape3D;
	shape.op_space_id = cs3.op_space_id;
	shape.group_id = ag.group_id;
	shape.rel_pos = Vector3.{0,20,30};
	shape.pitch_set = float.[0,8,14];
	shape.shape_text = "24-[0,8,14]";
	shape.scale_value = 0.8;
	shape.color = Vector4.{0,1,0,1};
	#asm{ create_shape_3D shape; }

	txt : AsmText3D;
	txt.op_space_id = cs3.op_space_id;
	txt.group_id = ag.group_id;
	txt.text = "24eq";
	txt.op_pos = Vector3.{0,23,30};
	#asm{ create_text_3D txt; }
}
DONE, op_space.id));
	
		array_resize(*perm.test_data.all_sub_tests, 5+1);
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
		// AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		// CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equals := AssertEquals(1, perm.all_data.all_closed_op_spaces.count);
		space_3d : OperationSpace;
		if count_equals {
			space_3d = perm.all_data.all_closed_op_spaces[0];
			AssertEquals("test", space_3d.op_space_name);
			AssertEquals(OpSpaceExternalType.space_3d, space_3d.op_space_external_type);
		}

		count_equals = AssertEquals(1, perm.all_data.all_op_spec_data_3D.count);
		op_3D : OpSpecData3D;
		if count_equals {
			op_3D = perm.all_data.all_op_spec_data_3D[0];
		}

		count_equals = AssertEquals(1, perm.all_data.all_chord_space_points.count);
		if count_equals {
			AssertEquals(12, perm.all_data.all_chord_space_points[0].tuning_system_count);
			AssertEquals(3, perm.all_data.all_chord_space_points[0].chord_dim);
			AssertEquals(364, perm.all_data.all_chord_space_points[0].chord_sp_3D.count);
		}

		count_equals = AssertEquals(1, op_3D.all_custom_geom_3D.count);
		if count_equals {
			AssertEquals(1, op_3D.all_custom_geom_3D[0].group_id);
			AssertEquals(OscWaveType.SAW, op_3D.all_custom_geom_3D[0].osc_wave_type);
			AssertEquals(2, op_3D.all_custom_geom_3D[0].tuning_system_id);
		}

		count_equals = AssertEquals(146, op_3D.all_op_space_points_3D.count);
		if count_equals {
			AssertEquals("24-[0,8,14]", peek(op_3D.all_op_space_points_3D).shape_text);
			AssertEquals(Vector3F.{0,20,30}, peek(op_3D.all_op_space_points_3D).rel_pos);
			AssertArrayEquals(float64.[0,8,14], peek(op_3D.all_op_space_points_3D).pitch_set);
			AssertEquals(0.8, peek(op_3D.all_op_space_points_3D).scale_value);
			AssertEquals(Vector4F.{0,1,0,1}, peek(op_3D.all_op_space_points_3D).color);
		}		

		
		count_equals = AssertEquals(4, op_3D.all_op_text_3D.count);
		if count_equals {
			AssertEquals("24eq", op_3D.all_op_text_3D[3].text);
			AssertEquals(Vector3F.{0,23,30}, op_3D.all_op_text_3D[3].op_pos);
		}


		open_circle := MakeTerminalEvent(.open_op, "test");
		array_add(*perm.all_data.all_terminal_events, open_circle);
	}
	case 5; {
		AssertEquals(2, perm.all_data.all_open_op_spaces.count);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

/*NOTE : Pointer and dereference tests in here to make sure values are being set correctly.
*/
Test_Pointer :: (
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
  x : int = 1;
  y : int = 5;
  xp : *int = *x;
  xp.* = 2;

  //TEST Pointer arithmetic  
  //yp == *y
  yp : *int = *x + 1;
  //xyp == *x
  xyp : *int = *y - 1;

  //TEST x1p == y (1 + *x so we make sure symmetric case to *x + 1 works)
  x1p : int = (1 + *x).*;

  //TEST Multi pointer
  xpp : **int = *xp;
  xpp.*.* = 3;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 9);
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
		AddWatchDataForTest(.["x", "y", "xp", "yp", "xyp", "x1p", "xpp", "*y", "*xp", "*xpp"], text_op);
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		//TODO Should likely also check the var_data in debug_info here to make sure pointer types are added properly.
		//Also could check type_str to make sure it's ok
		//TODO Could make a function to get by name and if we have multiple then we just get the 1st one.
		x_watch := text_op.watch_data_rows[0];
		AssertEquals("1", x_watch.value_str);

		y_watch := text_op.watch_data_rows[1];
		AssertEquals("5", y_watch.value_str);

		xp_watch := text_op.watch_data_rows[2];
		AssertEquals("0", xp_watch.value_str);


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		x_watch := text_op.watch_data_rows[0];
		AssertEquals("2", x_watch.value_str);


		CodeBPForTest(13, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 6; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
  		//yp : *int = *x + 1;
		sy_watch := GetWatch("*y", text_op.watch_data_rows);
		yp_watch := GetWatch("yp", text_op.watch_data_rows);
		AssertEquals(sy_watch.value_str, yp_watch.value_str);

  		//xyp : *int = *y - 1;
		xp_watch := GetWatch("xp", text_op.watch_data_rows);
		xyp_watch := GetWatch("xyp", text_op.watch_data_rows);
		AssertEquals(xp_watch.value_str, xyp_watch.value_str);

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 7; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		//x1p : int = (1 + *x).*;
		y_watch := GetWatch("y", text_op.watch_data_rows);
		x1p_watch := GetWatch("x1p", text_op.watch_data_rows);
		AssertEquals(y_watch.value_str, x1p_watch.value_str);		


		CodeBPForTest(18, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 8; {
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		x_watch := GetWatch("x", text_op.watch_data_rows);
		xpp_watch := GetWatch("xpp", text_op.watch_data_rows);
		sxp_watch := GetWatch("*xp", text_op.watch_data_rows);
		//TEST xpp.*.* = 3 which should set x to 3
		AssertEquals("3", x_watch.value_str);
		//TEST xpp == *xp
		AssertEquals(sxp_watch.value_str, xpp_watch.value_str);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoTilde :: (
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
  tano(0,0) ~= 0;
  tano(0,1) ~= tano(0,0) ~ 4;
  tano(0,2) ~= tano(0,1) ~ int.[7,11];
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
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
  		// tano(0,1) ~= tano(0,0) ~ 4;
		count_equal := AssertEquals(3, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(1., n0.x_start_float);
			AssertFloat64Equals(2., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(4., n1.music_pt_float);
			AssertFloat64Equals(1., n1.x_start_float);
			AssertFloat64Equals(2., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
  		// tano(0,2) ~= tano(0,1) ~ int.[7,11];
		count_equal := AssertEquals(7, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(2., n0.x_start_float);
			AssertFloat64Equals(3., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[4];
			AssertFloat64Equals(4., n1.music_pt_float);
			AssertFloat64Equals(2., n1.x_start_float);
			AssertFloat64Equals(3., n1.x_end_float);
			AssertEquals(0, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[5];
			AssertFloat64Equals(7., n2.music_pt_float);
			AssertFloat64Equals(2., n2.x_start_float);
			AssertFloat64Equals(3., n2.x_end_float);
			AssertEquals(0, n2.row_index);
			n3 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[6];
			AssertFloat64Equals(11., n3.music_pt_float);
			AssertFloat64Equals(2., n3.x_start_float);
			AssertFloat64Equals(3., n3.x_end_float);
			AssertEquals(0, n3.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoTEq :: (
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
  tano(0,0) ~= 4;
  tano(1,0:2) ~= 0;
  tano(0..1,2..4.5) ~= int.[7,11];

  tano(0,5) ~= tano(0..1,4.5..0);

  //TODO Do this in a separate test
  // tano(0,5) ~= 12 - tano(0,4.5..0);
  // tano(0,5) ~= 12 - tano(0,end..start);
  // tano(0,5) ~= 12 - (tano(0,end..start) % 12);
  // tano(1) ~= tano(0) + 4;
  //This could be retrograde whole row
  // tano(1) ~= tano(0,RG) + 4;
  //Could have a different symbol that maintains the rhythm with retrograde
  // tano(1) ~= tano(0,0<-10) + 4;
  //TODO Can add these once we implement the neume types in code
  // tano(0..1,3..6) ~= neume.[.{0,0,1,0}];
  // tano(0..1,3..6) ~= neume_x.[0,1,2];
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 8);
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
		CodeBPForTest(2, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			neume : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(4., neume.music_pt_float);
			AssertFloat64Equals(0., neume.x_start_float);
			AssertFloat64Equals(1., neume.x_end_float);
			AssertEquals(0, neume.row_index);
		}	

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			neume : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(0., neume.music_pt_float);
			AssertFloat64Equals(0., neume.x_start_float);
			AssertFloat64Equals(2., neume.x_end_float);
			AssertEquals(1, neume.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 6; {
		count_equal := AssertEquals(6, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(7., n1.music_pt_float);
			AssertFloat64Equals(2., n1.x_start_float);
			AssertFloat64Equals(4.5, n1.x_end_float);
			AssertEquals(0, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(11., n2.music_pt_float);
			AssertFloat64Equals(2., n2.x_start_float);
			AssertFloat64Equals(4.5, n2.x_end_float);
			AssertEquals(0, n2.row_index);
			n3 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[4];
			AssertFloat64Equals(7., n3.music_pt_float);
			AssertFloat64Equals(2., n3.x_start_float);
			AssertFloat64Equals(4.5, n3.x_end_float);
			AssertEquals(1, n3.row_index);
			n4 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[5];
			AssertFloat64Equals(11., n4.music_pt_float);
			AssertFloat64Equals(2., n4.x_start_float);
			AssertFloat64Equals(4.5, n4.x_end_float);
			AssertEquals(1, n4.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 7; {
		//UPDATE tmov failed test since we dont remove notes anymore
		//TODO FROM HERE add test here that searches for points in reverse
		//and then do tadd and also with reverse and then maybe do relative tanos before starting functions with tanos
		//TODO We could sort all_music_pts here to make sure it is in the right order
		//Could also search for neumes if that makes things easier.
		count_equal := AssertEquals(12, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[6];
			AssertFloat64Equals(4., n0.music_pt_float);
			AssertFloat64Equals(8.5, n0.x_start_float);
			AssertFloat64Equals(9.5, n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[7];
			AssertFloat64Equals(0., n1.music_pt_float);
			AssertFloat64Equals(7.5, n1.x_start_float);
			AssertFloat64Equals(9.5, n1.x_end_float);
			AssertEquals(1, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[8];
			AssertFloat64Equals(7., n2.music_pt_float);
			AssertFloat64Equals(5., n2.x_start_float);
			AssertFloat64Equals(7.5, n2.x_end_float);
			AssertEquals(0, n2.row_index);
			n3 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[9];
			AssertFloat64Equals(11., n3.music_pt_float);
			AssertFloat64Equals(5., n3.x_start_float);
			AssertFloat64Equals(7.5, n3.x_end_float);
			AssertEquals(0, n3.row_index);
			n4 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[10];
			AssertFloat64Equals(7., n4.music_pt_float);
			AssertFloat64Equals(5., n4.x_start_float);
			AssertFloat64Equals(7.5, n4.x_end_float);
			AssertEquals(1, n4.row_index);
			n5 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[11];
			AssertFloat64Equals(11., n5.music_pt_float);
			AssertFloat64Equals(5., n5.x_start_float);
			AssertFloat64Equals(7.5, n5.x_end_float);
			AssertEquals(1, n5.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoOpEqual :: (
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
  t0 := tano(0,0);
  t0 ~= int.[1,7];
  t0 += 1;
  t0 -= 1;
  t0 *= 2.0;
  t0 %= 11.0;
  x : float = 1.1;
  t0 /= x + 1.;
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
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
  		//t0 += 1;
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(2., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(8., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
  		//t0 -= 1;
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(1., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(7., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 6; {
  		//t0 *= 2.0;
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(2., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(14., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 7; {
  		//t0 %= 11.0;
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(2., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(3., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 8; {
		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 9; {
  		//t0 /= 2.1;
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(2/2.1, n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(3/2.1, n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoTAdd :: (
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
  tano(0,0) ~= int.[0,4];
  tano(0,1) ~= 5;
  tano(0,2) ~= tano(0,0..2) + 1;
  //Reverse tano with tadd test
  tano(1,0) ~= tano(0,2..0) + 1;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 7);
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
		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(3, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(4., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(5., n2.music_pt_float);
			AssertFloat64Equals(1., n2.x_start_float);
			AssertFloat64Equals(2., n2.x_end_float);
			AssertEquals(0, n2.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
		count_equal := AssertEquals(6, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(0+1., n0.music_pt_float);
			AssertFloat64Equals(2., n0.x_start_float);
			AssertFloat64Equals(3., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[4];
			AssertFloat64Equals(4+1., n1.music_pt_float);
			AssertFloat64Equals(2., n1.x_start_float);
			AssertFloat64Equals(3., n1.x_end_float);
			AssertEquals(0, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[5];
			AssertFloat64Equals(5+1., n2.music_pt_float);
			AssertFloat64Equals(3., n2.x_start_float);
			AssertFloat64Equals(4., n2.x_end_float);
			AssertEquals(0, n2.row_index);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 6; {
		//TODO We could sort all_music_pts here to make sure it is in the right order
		//Could also search for neumes if that makes things easier.
		count_equal := AssertEquals(9, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[6];
			AssertFloat64Equals(0+1., n0.music_pt_float);
			AssertFloat64Equals(1., n0.x_start_float);
			AssertFloat64Equals(2., n0.x_end_float);
			AssertEquals(1, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[7];
			AssertFloat64Equals(4+1., n1.music_pt_float);
			AssertFloat64Equals(1., n1.x_start_float);
			AssertFloat64Equals(2., n1.x_end_float);
			AssertEquals(1, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[8];
			AssertFloat64Equals(5+1., n2.music_pt_float);
			AssertFloat64Equals(0., n2.x_start_float);
			AssertFloat64Equals(1., n2.x_end_float);
			AssertEquals(1, n2.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

//TODO FROM HERE
//could integration test relative tanos before doing functions (check it works from each corner and negative)
//then do functions with tano and set/reset tbp on function call if we have tano as function argument
//then we add a neume struct and do neume arrays and function with neumes 
//then update debugger with tanos and functions and structs
//TODO ONCE WE HAVE TANO IN DEBUGGER THEN TEST DIFFERENT TANO CONFIGURATIONS like using a variable to create a tano
//and also all the different directions and just with rows and rel_tano and then check watch data directly.
Test_TanoTSub :: (
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

		SetupMusicAndRows(perm.all_data, CreateRowData.[
		.{row_section_data=.[.{x_length=12}],row_height=24},
		.{row_section_data=.[.{x_length=12}]},
		]);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  tano(0,0) ~= 1;
  tano(0,1) ~= 8;
  //inverse
  tano(0,2) ~= 12 - tano(0,0..2);
  //retrograde
  tano(0,4) ~= tano(0,2..0);
  //retrograde inverse
  tano(0,6) ~= 12 - tano(0,2..0);
  //transpose row down
  tano(1) ~= tano(0,0..2) - 4;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 7);
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
		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(4, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(1., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(8., n1.music_pt_float);
			AssertFloat64Equals(1., n1.x_start_float);
			AssertFloat64Equals(2., n1.x_end_float);
			AssertEquals(0, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(12-n0.music_pt_float, n2.music_pt_float);
			AssertFloat64Equals(2., n2.x_start_float);
			AssertFloat64Equals(3., n2.x_end_float);
			AssertEquals(0, n2.row_index);
			n3 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(12-n1.music_pt_float, n3.music_pt_float);
			AssertFloat64Equals(3., n3.x_start_float);
			AssertFloat64Equals(4., n3.x_end_float);
			AssertEquals(0, n3.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
		count_equal := AssertEquals(6, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			DefaultSortNeumes(perm.all_data.all_mspace_data[0].all_music_pts);
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[4];
			AssertFloat64Equals(8., n0.music_pt_float);
			AssertFloat64Equals(4., n0.x_start_float);
			AssertFloat64Equals(5., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[5];
			AssertFloat64Equals(1., n1.music_pt_float);
			AssertFloat64Equals(5., n1.x_start_float);
			AssertFloat64Equals(6., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 6; {
		count_equal := AssertEquals(8, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			DefaultSortNeumes(perm.all_data.all_mspace_data[0].all_music_pts);
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[6];
			AssertFloat64Equals(12-8., n0.music_pt_float);
			AssertFloat64Equals(6., n0.x_start_float);
			AssertFloat64Equals(7., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[7];
			AssertFloat64Equals(12-1., n1.music_pt_float);
			AssertFloat64Equals(7., n1.x_start_float);
			AssertFloat64Equals(8., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 7; {
		count_equal := AssertEquals(10, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[8];
			AssertFloat64Equals(1-4., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(1, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[9];
			AssertFloat64Equals(8-4., n1.music_pt_float);
			AssertFloat64Equals(1., n1.x_start_float);
			AssertFloat64Equals(2., n1.x_end_float);
			AssertEquals(1, n1.row_index);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoTMod :: (
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

		SetupMusicAndRows(perm.all_data, CreateRowData.[
		.{row_section_data=.[.{x_length=12}],row_height=24},
		.{row_section_data=.[.{x_length=12}]},
		]);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  tano(0,0) ~= 0;
  tano(0,0) ~= 16;
  tano(0,1) ~= tano(0,0) % 12;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 4);
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
		// text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		// CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(4, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(16., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(0, n2.music_pt_float);
			AssertFloat64Equals(1., n2.x_start_float);
			AssertFloat64Equals(2., n2.x_end_float);
			AssertEquals(0, n2.row_index);
			n3 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(4, n3.music_pt_float);
			AssertFloat64Equals(1., n3.x_start_float);
			AssertFloat64Equals(2., n3.x_end_float);
			AssertEquals(0, n3.row_index);
		}

		// DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoRow :: (
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

		SetupMusicAndRows(perm.all_data, CreateRowData.[
		.{row_section_data=.[.{x_length=12}],row_height=24},
		.{row_section_data=.[.{x_length=12}]},
		]);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  tano(0,0) ~= 0;
  tano(0,1) ~= 5;
  tano(1) ~= tano(0) + 1;
  tano(0,2) ~= tano(1..0) + 1;
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
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(4, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(4, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(5., n1.music_pt_float);
			AssertFloat64Equals(1., n1.x_start_float);
			AssertFloat64Equals(2., n1.x_end_float);
			AssertEquals(0, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(1., n2.music_pt_float);
			AssertFloat64Equals(0., n2.x_start_float);
			AssertFloat64Equals(1., n2.x_end_float);
			AssertEquals(1, n2.row_index);
			n3 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(6., n3.music_pt_float);
			AssertFloat64Equals(1., n3.x_start_float);
			AssertFloat64Equals(2., n3.x_end_float);
			AssertEquals(1, n3.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
		count_equal := AssertEquals(8, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[4];
			AssertFloat64Equals(1., n0.music_pt_float);
			AssertFloat64Equals(2., n0.x_start_float);
			AssertFloat64Equals(3., n0.x_end_float);
			AssertEquals(1, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[5];
			AssertFloat64Equals(6., n1.music_pt_float);
			AssertFloat64Equals(3., n1.x_start_float);
			AssertFloat64Equals(4., n1.x_end_float);
			AssertEquals(1, n1.row_index);
			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[6];
			AssertFloat64Equals(2, n2.music_pt_float);
			AssertFloat64Equals(2., n2.x_start_float);
			AssertFloat64Equals(3., n2.x_end_float);
			AssertEquals(0, n2.row_index);
			n3 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[7];
			AssertFloat64Equals(7, n3.music_pt_float);
			AssertFloat64Equals(3., n3.x_start_float);
			AssertFloat64Equals(4., n3.x_end_float);
			AssertEquals(0, n3.row_index);
		}


		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoRel :: (
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

		SetupMusicAndRows(perm.all_data, CreateRowData.[
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		]);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  t := tano(1,1);
  t(1,1) ~= 0; //0 at tano(2,2)
  t(-1,-1) ~= 1; //1 at tano(0,0)
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
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		CodeBPForTest(3, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(2., n0.x_start_float);
			AssertFloat64Equals(3., n0.x_end_float);
			AssertEquals(2, n0.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	case 5; {
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(1., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
		}

		DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoRelDir :: (
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

		SetupMusicAndRows(perm.all_data, CreateRowData.[
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		]);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
main :: () {
  t := tano(1..2,1..3);
  t1 := t(+,+);
  t1(-1,-1) ~= 0;

  t1 = t(-,+);
  t1(1,1) ~= 1;
  
  t1 = t(+,-);
  t1(1,1) ~= 2;
  
  t1 = t(-,-);
  t1(1,1) ~= 3;

  //TODO Maybe can use this instead of the above to test each direction
  // t1 := t(-,+);
  // t1 := t(-/+);
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 8);
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
		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		CodeBPForTest(9, *text_op.exec_info.debug_info, text_op.text_comp_data);
		CodeBPForTest(12, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
		}

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(1., n0.music_pt_float);
			AssertFloat64Equals(2., n0.x_start_float);
			AssertFloat64Equals(3., n0.x_end_float);
			AssertEquals(3, n0.row_index);
		}

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 6; {
		count_equal := AssertEquals(3, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(2., n0.music_pt_float);
			AssertFloat64Equals(4., n0.x_start_float);
			AssertFloat64Equals(5., n0.x_end_float);
			AssertEquals(2, n0.row_index);
		}

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 7; {
		count_equal := AssertEquals(4, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(3., n0.music_pt_float);
			AssertFloat64Equals(4., n0.x_start_float);
			AssertFloat64Equals(5., n0.x_end_float);
			AssertEquals(3, n0.row_index);
		}

		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoFuncInputOp :: (
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

		SetupMusicAndRows(perm.all_data, CreateRowData.[
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		]);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
foo :: (t : tano) {
  tano(1,0) ~= t;
}
main :: () {
  tano(0,0) ~= int.[1,8];
  foo(12 - tano(0,0));
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 5);
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
		// CodeBPForTest(5, *text_op.exec_info.debug_info, text_op.text_comp_data);
		// CodeBPForTest(9, *text_op.exec_info.debug_info, text_op.text_comp_data);
		// CodeBPForTest(12, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(4, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(12-1., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(1, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(12-8., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(1, n1.row_index);
		}

		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoFuncOp :: (
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

		SetupMusicAndRows(perm.all_data, CreateRowData.[
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		.{row_section_data=.[.{x_length=12}]},
		]);

		//TODO Should we just create generally in here? I guess this makes things consistent across tests.
		text_file := CreateTestTextFile(*ALL_NEXT_IDS, *perm.all_data.all_text_files);
		WriteFileString(text_file,
//TODO Could do sprint if needed to put things in here
#string DONE
foo :: (t : tano) -> tano {
  return t + 3;
}
main :: () {
  tano(0,0) ~= int.[1,8];
  tano(1,0) ~= foo(tano(0,0));
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 5);
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
		// CodeBPForTest(5, *text_op.exec_info.debug_info, text_op.text_comp_data);
		// CodeBPForTest(9, *text_op.exec_info.debug_info, text_op.text_comp_data);
		// CodeBPForTest(12, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(4, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(3+1., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(1, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(3+8., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(1, n1.row_index);
		}

		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoToArray :: (
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
  t0 := tano(0,0.0);
  t0 ~= int.[0,4];
  na : [] neume = t0;
  ia : [] int = t0;
  fa : [] float = t0;
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 5);
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
		// CodeBPForTest(5, *text_op.exec_info.debug_info, text_op.text_comp_data);
		// CodeBPForTest(9, *text_op.exec_info.debug_info, text_op.text_comp_data);
		// CodeBPForTest(12, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(2, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(4., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);
		}

		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);
} @ITest

//TODO Test neumes separately once we can check them in the debugger.
Test_TanoNeume :: (
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
  n : neume;
  n.svara = 1.5;
  n.x_end = 1.5;
  tano(0,0) ~= n;

  n1 : neume;
  n1.svara = 10.5;
  n1.x_end = 1.5;
  na : [2] neume = neume.[n,n1];
  tano(0,1) ~= na;

  tano(1..0,5..0) ~= n;
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
		text_op : *TextOpSpaceData = *perm.all_data.all_text_op_space_data[0];
		AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		n_var : Neume = GetMemValue(0, Neume, perm.all_data.ram_memory);
		AssertFloat64Equals(1.5, n_var.svara);
		AssertFloat64Equals(0., n_var.x_start);
		AssertFloat64Equals(1.5, n_var.x_end);
		AssertEquals(0, n_var.row);

		count_equal := AssertEquals(1, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(1.5, n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1.5, n0.x_end_float);
			AssertEquals(0, n0.row_index);
		}

		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 5; {
		cd := perm.all_data.all_text_op_space_data[0].text_comp_data;
		n1_var : Neume = GetMemValue(cd.all_type_info.neume_struct_info.runtime_size, 
			Neume, perm.all_data.ram_memory);
		AssertFloat64Equals(10.5, n1_var.svara);
		AssertFloat64Equals(0., n1_var.x_start);
		AssertFloat64Equals(1.5, n1_var.x_end);
		AssertEquals(0, n1_var.row);

		na0 : Neume = GetMemValue(2*cd.all_type_info.neume_struct_info.runtime_size, 
			Neume, perm.all_data.ram_memory);
		AssertFloat64Equals(1.5, na0.svara);
		AssertFloat64Equals(0., na0.x_start);
		AssertFloat64Equals(1.5, na0.x_end);
		AssertEquals(0, na0.row);
		na1 : Neume = GetMemValue(3*cd.all_type_info.neume_struct_info.runtime_size, 
			Neume, perm.all_data.ram_memory);
		AssertFloat64Equals(10.5, na1.svara);
		AssertFloat64Equals(0., na1.x_start);
		AssertFloat64Equals(1.5, na1.x_end);
		AssertEquals(0, na1.row);

		count_equal := AssertEquals(4, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(1.5, n0.music_pt_float);
			AssertFloat64Equals(1., n0.x_start_float);
			AssertFloat64Equals(2.5, n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(10.5, n1.music_pt_float);
			AssertFloat64Equals(1., n1.x_start_float);
			AssertFloat64Equals(2.5, n1.x_end_float);
			AssertEquals(0, n1.row_index);

			n_rev : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[3];
			AssertFloat64Equals(1.5, n_rev.music_pt_float);
			AssertFloat64Equals(3.5, n_rev.x_start_float);
			AssertFloat64Equals(5., n_rev.x_end_float);
			AssertEquals(1, n_rev.row_index);
		}

		// DownUpInputMap(.DEBUG_STEP_OVER, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_TanoFunc :: (
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
foo :: (t : tano, a : [2] int) {
  t ~= a;
}
f2 :: (t : tano, n : neume) {
  t ~= n;
}
main :: () {
  foo(tano(0,0), int.[0,6]);

  n : neume;
  n.svara = 4.;
  n.x_end = 1.5;
  f2(tano(0,1), n);
}
DONE);

		CreateTextOpSpace(text_file.id, perm.text_editor_data, 
			renderer_data.base_render_group.pixels_per_square, perm.all_data, renderer_data);
	
		array_resize(*perm.test_data.all_sub_tests, 5);
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
		// CodeBPForTest(6, *text_op.exec_info.debug_info, text_op.text_comp_data);
		AssertEquals(0, text_op.text_comp_data.comp_errors.all_compiler_errors.count);
		DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	case 4; {
		count_equal := AssertEquals(3, perm.all_data.all_mspace_data[0].all_music_pts.count);
		if count_equal {
			n0 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[0];
			AssertFloat64Equals(0., n0.music_pt_float);
			AssertFloat64Equals(0., n0.x_start_float);
			AssertFloat64Equals(1., n0.x_end_float);
			AssertEquals(0, n0.row_index);
			n1 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[1];
			AssertFloat64Equals(6., n1.music_pt_float);
			AssertFloat64Equals(0., n1.x_start_float);
			AssertFloat64Equals(1., n1.x_end_float);
			AssertEquals(0, n1.row_index);

			n2 : MusicPoint = perm.all_data.all_mspace_data[0].all_music_pts[2];
			AssertFloat64Equals(4., n2.music_pt_float);
			AssertFloat64Equals(1., n2.x_start_float);
			AssertFloat64Equals(2.5, n2.x_end_float);
			AssertEquals(0, n2.row_index);
		}

		// DownUpInputMap(.TEXT_RUN_CONTINUE, game_input);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

AssertTextSplitLine :: (test : TextSplitLine, tsl : TextSplitLine) {
	AssertTextCursor(test.cursor, tsl.cursor);
	AssertEquals(test.split_lines.count, tsl.split_lines.count, "split_lines.count");
	AssertEquals(test.viewable_lines_from_zero, tsl.viewable_lines_from_zero, "viewable_lines_from_zero");
	AssertEquals(test.line_char_count, tsl.line_char_count, "line_char_count");
}
AssertTerminalData :: (test : TerminalData, term : TerminalData) {
	AssertEquals(test.cmd_history_count, term.cmd_history_count, "cmd_history_count");
	AssertEquals(test.terminal_cmd_history.count, term.terminal_cmd_history.count, "terminal_cmd_history.count");
	AssertEquals(test.history_select_offset, term.history_select_offset, "history_select_offset");
	AssertEquals(test.next_cmd_history_index, term.next_cmd_history_index, "next_cmd_history_index");

	AssertEquals(test.terminal_cursor.char_point, term.terminal_cursor.char_point, "char_point");
	AssertEquals(test.terminal_cursor.cursor_line_char, term.terminal_cursor.cursor_line_char, "cursor_line_char");
	AssertEquals(test.terminal_cursor.cursor_is_selecting, term.terminal_cursor.cursor_is_selecting, "cursor_is_selecting");
	if test.terminal_cursor.cursor_is_selecting {
		AssertEquals(test.terminal_cursor.fixed_select_line_char, term.terminal_cursor.fixed_select_line_char, "fixed_select_line_char");
		AssertEquals(test.terminal_cursor.fixed_select_line_number, term.terminal_cursor.fixed_select_line_number, "fixed_select_line_number");		
	}

	AssertEquals(test.terminal_command_string.text_string, term.terminal_command_string.text_string);
	AssertEquals(test.terminal_start_cmd_string, term.terminal_start_cmd_string);
	test_cmd_string_with_start : string = tprint("%0%0", test.terminal_start_cmd_string, test.terminal_command_string.text_string);
	AssertEquals(test_cmd_string_with_start, term.cmd_string_with_start);
}

//Pulled these out so we can reuse for the text console
//TODO Should this go in the text tests?
TermTestData :: struct {
	test_term_op : TerminalOpSpaceData;
	test_td : TerminalData;
}
Test_Terminal :: (
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

		//Reset the terminal here so we can start from scratch
		//Should we put this in AllData?
		ResetTerminalData(*perm.terminal_data, perm.all_data.all_terminal_op_space_data);
		//This is set here to test_cmd_history circularity and we reset it at the end of the test
		perm.terminal_data.terminal_cmd_history.count = 5;

		perm.test_data.spec_data = New(TermTestData);
		array_resize(*perm.test_data.all_sub_tests, 94+1);
	}

	open_cmd :: "open_op test";
	close_cmd :: "close_op 0";
	two_line_cmd :: "this is a 2 line command to test 2 lines out in the terminal";
	three_line_cmd :: "even more text here to test a 3 line command and so we keep writing so that we can test three lines clearly right here";
	four_line_cmd :: "even more text here to test a 4 line command and so we keep writing so that we can test three lines clearly more test goes here yes yes yes  more text 4 lines commmand yes yes yes";
	clear_cmd :: "clear";

	//TODO Can get TerminalOpSpaceData here if we use that after
	// tt_data := cast(*TextTestData) perm.test_data.spec_data;
	// tt_op : *TextOpSpaceData = *tt_data.test_text_op;
	test_term_data := cast(*TermTestData) perm.test_data.spec_data;
	test_term_op : *TerminalOpSpaceData = *test_term_data.test_term_op;
	test_tsl : *TextSplitLine = *test_term_data.test_term_op.terminal_tsl;
	test_td : *TerminalData = *test_term_data.test_td;

	td : *TerminalData = *perm.terminal_data;
	term_op : *TerminalOpSpaceData;
	if perm.test_data.sub_test_index > 0 {
		AssertEquals(1, perm.all_data.all_terminal_op_space_data.count);
		term_op = *perm.all_data.all_terminal_op_space_data[0];
	}
	op_space : *OperationSpace;
	op_2D_cam : Camera2D;
	default_base_cam : Camera2D;
	if perm.all_data.all_open_op_spaces.count > 0 {
		op_space = *perm.all_data.all_open_op_spaces[0];
		op_2D_cam = op_space.op_2D_cam;
	}	
	default_base_cam = GetRenderMSpace(perm.all_data).mspace_cam;

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		DownUpInputMap(.TERMINAL_TOGGLE, game_input);

		test_tsl.split_lines.count = 4;
		test_tsl.viewable_lines_from_zero = 19;
		test_tsl.line_char_count = 59;

		test_td.terminal_cmd_history.count = 5;
		test_td.cmd_history_count = 1;
		test_td.next_cmd_history_index = 0;
		test_td.terminal_start_cmd_string = ">";
	}
	case 1; {
		AssertEquals(1, perm.all_data.all_open_op_spaces.count);
		AssertEquals(1, perm.all_data.all_terminal_op_space_data.count);
		//Check that we added the terminal char as split line
		count_equals := AssertEquals(1, term_op.terminal_tsl.split_lines.count);
		if count_equals {
			AssertEquals(td.terminal_start_cmd_string, term_op.terminal_tsl.split_lines[0].split_string);
			AssertEquals(0, term_op.terminal_tsl.split_lines[0].not_split_line_number);
			AssertTextCursor(test_tsl.cursor, term_op.terminal_tsl.cursor);
		}

		//Test a typical cmd
		cmd : string = tprint(open_cmd);
		AddTextInput(cmd, game_input);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
	}
	case 2; {
		AssertEquals(open_cmd, td.terminal_cmd_history[0]);
		AssertTerminalData(test_td, perm.terminal_data);

		DownUpThisFrame(.ENTER, game_input);

		test_td.cmd_history_count += 1;
		test_td.next_cmd_history_index += 1;
		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
	}
	case 3; {
		AssertEquals(tprint("-%", open_cmd), term_op.terminal_tsl.split_lines[0].split_string);
		AssertEquals(0, term_op.terminal_tsl.split_lines[0].not_split_line_number);
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test an empty terminal line
		//This should not add to the history and not change anything else other than the number of split lines
		DownUpThisFrame(.ENTER, game_input);
		test_tsl.split_lines.count += 2;
	}
	case 4; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test another cmd to makes sure it is added to the history
		AddTextInput(close_cmd, game_input);
		test_td.terminal_command_string.text_string = close_cmd;
		test_td.terminal_cursor.char_point = close_cmd.count;
		test_td.terminal_cursor.cursor_line_char = close_cmd.count;
	}
	case 5; {
		AssertEquals(close_cmd, td.terminal_cmd_history[1]);
		AssertTerminalData(test_td, perm.terminal_data);

		DownUpThisFrame(.ENTER, game_input);

		test_td.cmd_history_count += 1;
		test_td.next_cmd_history_index += 1;
		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
		test_tsl.split_lines.count += 3;
	}
	case 6; {
		AssertEquals(close_cmd, td.terminal_cmd_history[test_td.next_cmd_history_index-1]);
		AssertEquals("", td.terminal_cmd_history[test_td.next_cmd_history_index]);
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test another cmd to makes sure it is added to the history
		cmd : string = sprint(close_cmd);
		AddTextInput(cmd, game_input);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
	}
	case 7; {
		AssertEquals(close_cmd, td.terminal_cmd_history[2]);
		AssertTerminalData(test_td, perm.terminal_data);

		DownUpThisFrame(.ENTER, game_input);

		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
		//2 for the command and the empty line and then 1 for extra
		test_tsl.split_lines.count += 2+1;
	}
	case 8; {
		AssertEquals(close_cmd, td.terminal_cmd_history[td.next_cmd_history_index-1]);
		AssertEquals("", td.terminal_cmd_history[td.next_cmd_history_index]);
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test another cmd to makes sure it is added to the history
		cmd : string = sprint(two_line_cmd);
		AddTextInput(cmd, game_input);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
	}
	case 9; {
		AssertTerminalData(test_td, perm.terminal_data);

		DownUpThisFrame(.ENTER, game_input);

		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
		//2 for the command and the empty line and then 2 for extra line
		test_tsl.split_lines.count += 2+2;
		test_td.cmd_history_count += 1;
		test_td.next_cmd_history_index += 1;
	}
	case 10; {
		AssertEquals(two_line_cmd, td.terminal_cmd_history[td.next_cmd_history_index-1]);
		AssertEquals("", td.terminal_cmd_history[td.next_cmd_history_index]);
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling through cmd history before count is at max to make sure it works
		DownUpThisFrame(.ARROW_UP, game_input);
		test_td.history_select_offset += 1;

		cmd : string = sprint(two_line_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
	}
	case 11; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling through cmd history before count is at max to make sure it works
		DownUpThisFrame(.ARROW_UP, game_input);
		test_td.history_select_offset += 1;

		cmd : string = sprint(close_cmd);
		test_td.terminal_command_string.text_string = close_cmd;
		test_td.terminal_cursor.char_point = close_cmd.count;
		test_td.terminal_cursor.cursor_line_char = close_cmd.count;
	}
	case 12; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling through cmd history before count is at max to make sure it works
		DownUpThisFrame(.ARROW_UP, game_input);
		test_td.history_select_offset += 1;

		cmd : string = sprint(open_cmd);
		test_td.terminal_command_string.text_string = open_cmd;
		test_td.terminal_cursor.char_point = open_cmd.count;
		test_td.terminal_cursor.cursor_line_char = open_cmd.count;
	}
	case 13; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling one more time up should not do since we are at the last cmd history
		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 14; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling down history
		DownUpThisFrame(.ARROW_DOWN, game_input);
		test_td.history_select_offset -= 1;

		cmd : string = sprint(close_cmd);
		test_td.terminal_command_string.text_string = close_cmd;
		test_td.terminal_cursor.char_point = close_cmd.count;
		test_td.terminal_cursor.cursor_line_char = close_cmd.count;
	}
	case 15; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling down history
		DownUpThisFrame(.ARROW_DOWN, game_input);
		test_td.history_select_offset -= 1;

		cmd : string = sprint(two_line_cmd);
		test_td.terminal_command_string.text_string = two_line_cmd;
		test_td.terminal_cursor.char_point = two_line_cmd.count;
		test_td.terminal_cursor.cursor_line_char = two_line_cmd.count;
	}
	case 16; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling one more time bring us back to empty command 
		DownUpThisFrame(.ARROW_DOWN, game_input);
		test_td.history_select_offset -= 1;

		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
	}
	case 17; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling dow one more time does nothing since we are at the end
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 18; {
		AssertTerminalData(test_td, perm.terminal_data);

		//Test another cmd to makes sure it is added to the history
		cmd : string = sprint(three_line_cmd);
		AddTextInput(cmd, game_input);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
	}
	case 19; {
		AssertTerminalData(test_td, perm.terminal_data);

		DownUpThisFrame(.ENTER, game_input);

		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
		//2 for the command and the empty line and then 3 for extra line
		test_tsl.split_lines.count += 2+3;
		test_td.cmd_history_count += 1;
		test_td.next_cmd_history_index += 1;
		test_term_op.terminal_tsl.start_file_line_index += 1;
	}
	case 20; {
		AssertEquals(three_line_cmd, td.terminal_cmd_history[td.next_cmd_history_index-1]);
		AssertEquals("", td.terminal_cmd_history[td.next_cmd_history_index]);
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test another cmd to makes sure it is added to the history
		cmd : string = sprint(four_line_cmd);
		AddTextInput(cmd, game_input);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
	}
	case 21; {
		AssertTerminalData(test_td, perm.terminal_data);

		DownUpThisFrame(.ENTER, game_input);

		//TEST We shoudl wrap around the history now since we are adding a fifth
		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
		//2 for the command and the empty line and then 4 for extra line
		test_tsl.split_lines.count += 2+4;
		//This should not increase since we have wrapped around the terminal history
		// test_td.cmd_history_count += 1;
		test_td.next_cmd_history_index = 0;
		test_term_op.terminal_tsl.start_file_line_index += 6;
	}
	case 22; {
		AssertEquals(four_line_cmd, td.terminal_cmd_history[td.terminal_cmd_history.count-1]);
		AssertEquals("", td.terminal_cmd_history[td.next_cmd_history_index]);
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test a typical cmd
		cmd : string = tprint(open_cmd);
		AddTextInput(cmd, game_input);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
	}
	case 23; {
		AssertEquals(open_cmd, td.terminal_cmd_history[0]);
		AssertTerminalData(test_td, perm.terminal_data);

		DownUpThisFrame(.ENTER, game_input);

		//This should no longer change since we reached the max of 5
		// test_td.cmd_history_count += 1;
		test_td.next_cmd_history_index += 1;
		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
		test_tsl.split_lines.count += 3;
		test_tsl.start_file_line_index += 3;
	}
	case 24; {
		AssertEquals(open_cmd, td.terminal_cmd_history[td.next_cmd_history_index-1]);
		AssertEquals("", td.terminal_cmd_history[td.next_cmd_history_index]);
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test add a cmd so we scroll through history and make sure it is still here after
		cmd : string = tprint(two_line_cmd);
		AddTextInput(cmd, game_input);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		//Check that adjusting in the history has moved the lines
		test_tsl.start_file_line_index += 1;
		test_tsl.split_lines.count += 1;
	}
	case 25; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling through cmd history after count is at max to make sure it works
		DownUpThisFrame(.ARROW_UP, game_input);
		test_td.history_select_offset += 1;

		cmd : string = sprint(open_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		//Check that adjusting in the history has moved the lines
		test_tsl.split_lines.count -= 1;
	}
	case 26; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling through after history before count is at max to make sure it works
		DownUpThisFrame(.ARROW_UP, game_input);
		test_td.history_select_offset += 1;

		cmd : string = sprint(four_line_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		//Check that adjusting in the history has moved the lines
		test_tsl.start_file_line_index += 2;
		test_tsl.split_lines.count += 3;
	}
	case 27; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling through cmd history after count is at max to make sure it works
		DownUpThisFrame(.ARROW_UP, game_input);
		test_td.history_select_offset += 1;

		cmd : string = sprint(three_line_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		test_tsl.split_lines.count -= 1;
	}
	case 28; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling through cmd history after count is at max to make sure it works
		DownUpThisFrame(.ARROW_UP, game_input);
		test_td.history_select_offset += 1;

		cmd : string = sprint(two_line_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		test_tsl.split_lines.count -= 1;
	}
	case 29; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling through cmd history after count is at max to make sure it works
		//we are at max now so we should not be able to go further up history
		DownUpThisFrame(.ARROW_UP, game_input);
	}
	case 30; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling back through cmd history after count > max
		DownUpThisFrame(.ARROW_DOWN, game_input);
		test_td.history_select_offset -= 1;

		cmd : string = sprint(three_line_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		test_tsl.split_lines.count += 1;
	}
	case 31; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling back through cmd history after count > max
		DownUpThisFrame(.ARROW_DOWN, game_input);
		test_td.history_select_offset -= 1;

		cmd : string = sprint(four_line_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		test_tsl.split_lines.count += 1;
	}
	case 32; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling back through cmd history after count > max
		DownUpThisFrame(.ARROW_DOWN, game_input);
		test_td.history_select_offset -= 1;

		cmd : string = sprint(open_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		test_tsl.split_lines.count -= 3;
	}
	case 33; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling back through cmd history after count > max
		//we are back at top now so we should still have the two_line_cmd we added before history scrolling
		DownUpThisFrame(.ARROW_DOWN, game_input);
		test_td.history_select_offset -= 1;

		cmd : string = sprint(two_line_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		test_tsl.split_lines.count += 1;
	}
	case 34; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scrolling back through cmd history after count > max
		//should not go down anymore since we are at the max
		DownUpThisFrame(.ARROW_DOWN, game_input);
	}
	case 35; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST scroll down with keyboard twice to bring bottom line to bottom of terminal
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
	}
	case 36; DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
	case 37; {
		AssertTerminalData(test_td, perm.terminal_data);

		//Test that TerminalCmdCharPointToOpPos is accurate on line boundaries on first line and then second line boundary
		//and also test keyboard highlighting on boundaries
		for 0..1 DownUpThisFrame(.ARROW_LEFT, game_input);
		test_td.terminal_cursor.char_point -= 2;
		test_td.terminal_cursor.cursor_line_char -= 2;
	}
	case 38; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		AssertFloatEquals(term_op.terminal_tsl.x_start_left, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test that TerminalCmdCharPointToOpPos is accurate on line boundaries on first line and then second line boundary
		//and also test keyboard highlighting on boundaries
		//test here that we go up a line when moving across boundary
		DownUpThisFrame(.ARROW_LEFT, game_input);
		test_td.terminal_cursor.char_point -= 1;
		test_td.terminal_cursor.cursor_line_char -= 1;
	}
	case 39; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		line_x : float = term_op.terminal_tsl.x_start_left + (term_op.terminal_tsl.line_char_count-1)*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(line_x, op_pos.x);
		//-1 because we moved up the boundary from the previous test
		line_y : float = term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-1) * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test that TerminalCmdCharPointToOpPos highlighting across boundaries should also work
		DownUpThisFrame(.ARROW_RIGHT, .{shift_pressed=true}, game_input);
		test_td.terminal_cursor.cursor_is_selecting = true;
		test_td.terminal_cursor.fixed_select_char_point = test_td.terminal_cursor.char_point;
		test_td.terminal_cursor.fixed_select_line_char = test_td.terminal_cursor.cursor_line_char;
		test_td.terminal_cursor.char_point += 1;
		test_td.terminal_cursor.cursor_line_char += 1;
	}
	case 40; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		fixed_op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.fixed_select_char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		fixed_line_x : float = term_op.terminal_tsl.x_start_left + (term_op.terminal_tsl.line_char_count-1)*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(fixed_line_x, fixed_op_pos.x);
		//-1 because we moved up the boundary from the previous test
		fixed_line_y : float = term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-1) * term_op.terminal_tsl.line_height;
		AssertFloatEquals(fixed_line_y, fixed_op_pos.y);

		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		AssertFloatEquals(term_op.terminal_tsl.x_start_left, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test that TerminalCmdCharPointToOpPos highlighting across boundaries should also work
		DownUpThisFrame(.ARROW_RIGHT, .{shift_pressed=true}, game_input);
		test_td.terminal_cursor.char_point += 1;
		test_td.terminal_cursor.cursor_line_char += 1;
	}
	case 41; {
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		fixed_op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.fixed_select_char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		fixed_line_x : float = term_op.terminal_tsl.x_start_left + (term_op.terminal_tsl.line_char_count-1)*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(fixed_line_x, fixed_op_pos.x);
		//-1 because we moved up the boundary from the previous test
		fixed_line_y : float = term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-1) * term_op.terminal_tsl.line_height;
		AssertFloatEquals(fixed_line_y, fixed_op_pos.y);

		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		line_x : float = term_op.terminal_tsl.x_start_left + perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(line_x, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test character highlighting and text input should update to 3 lines and adjust boundaries
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		test_td.terminal_cursor.fixed_select_char_point = 0;
		test_td.terminal_cursor.fixed_select_line_char = 0;
		test_td.terminal_cursor.char_point = two_line_cmd.count;
		test_td.terminal_cursor.cursor_line_char = two_line_cmd.count;
		test_tsl.start_file_line_index -= 2;
	}
	case 42; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		fixed_op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.fixed_select_char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		//test that the start char here is after the terminal start cmd string
		fixed_line_x : float = term_op.terminal_tsl.x_start_left + td.terminal_start_cmd_string.count * perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(fixed_line_x, fixed_op_pos.x);
		fixed_line_y : float = term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-1) * term_op.terminal_tsl.line_height;
		AssertFloatEquals(fixed_line_y, fixed_op_pos.y);

		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		line_x : float = term_op.terminal_tsl.x_start_left + 2*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(line_x, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test character works on boundaries of the second line instead of first line from previous test
		AddTextInput(three_line_cmd, game_input);
		cmd : string = sprint(three_line_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.cursor_is_selecting = false;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;
		test_tsl.split_lines.count += 1;
		test_tsl.start_file_line_index += 1;
	}
	case 43; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		line_x : float = term_op.terminal_tsl.x_start_left + 1*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(line_x, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test that TerminalCmdCharPointToOpPos is accurate on line boundaries on first line and then second line boundary
		//and also test keyboard highlighting on boundaries
		DownUpThisFrame(.ARROW_LEFT, .{shift_pressed=true}, game_input);
		test_td.terminal_cursor.cursor_is_selecting = true;
		test_td.terminal_cursor.fixed_select_char_point = test_td.terminal_cursor.char_point;
		test_td.terminal_cursor.fixed_select_line_char = test_td.terminal_cursor.cursor_line_char;
		test_td.terminal_cursor.char_point -= 1;
		test_td.terminal_cursor.cursor_line_char -= 1;
	}
	case 44; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		fixed_op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.fixed_select_char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		fixed_line_x : float = term_op.terminal_tsl.x_start_left + 1*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(fixed_line_x, fixed_op_pos.x);
		fixed_line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(fixed_line_y, fixed_op_pos.y);

		//TEST That cursor is on bottom line for the boundary character
		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		AssertFloatEquals(term_op.terminal_tsl.x_start_left, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test that TerminalCmdCharPointToOpPos is accurate on line boundaries on first line and then second line boundary
		//and also test keyboard highlighting on boundaries
		//test here that we go up a line when moving across boundary
		DownUpThisFrame(.ARROW_LEFT, .{shift_pressed=true}, game_input);
		test_td.terminal_cursor.char_point -= 1;
		test_td.terminal_cursor.cursor_line_char -= 1;
	}
	case 45; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		fixed_op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.fixed_select_char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		fixed_line_x : float = term_op.terminal_tsl.x_start_left + 1*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(fixed_line_x, fixed_op_pos.x);
		fixed_line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(fixed_line_y, fixed_op_pos.y);

		//TEST That cursor is on bottom line for the boundary character
		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		line_x : float = term_op.terminal_tsl.x_start_left + (term_op.terminal_tsl.line_char_count-1)*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(line_x, op_pos.x);
		//-1 because we moved up the boundary from the previous test
		line_y : float = term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-1) * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test that TerminalCmdCharPointToOpPos highlighting across boundaries should also work
		for 0..term_op.terminal_tsl.line_char_count-1 DownUpThisFrame(.ARROW_LEFT, .{shift_pressed=true}, game_input);
		test_td.terminal_cursor.char_point -= term_op.terminal_tsl.line_char_count;
		test_td.terminal_cursor.cursor_line_char -= term_op.terminal_tsl.line_char_count;
	}
	case 46; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST That cursor is on bottom line for the boundary character
		fixed_op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.fixed_select_char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		fixed_line_x : float = term_op.terminal_tsl.x_start_left + 1*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(fixed_line_x, fixed_op_pos.x);
		//-1 because we moved up the boundary from the previous test
		fixed_line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(fixed_line_y, fixed_op_pos.y);

		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		line_x : float = term_op.terminal_tsl.x_start_left + (term_op.terminal_tsl.line_char_count-1)*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(line_x, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-2) * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test that TerminalCmdCharPointToOpPos highlighting across boundaries should also work
		for 0..2 DownUpThisFrame(.ARROW_RIGHT, game_input);
		test_td.terminal_cursor.cursor_is_selecting = false;
		test_td.terminal_cursor.char_point = three_line_cmd.count;
		test_td.terminal_cursor.cursor_line_char = three_line_cmd.count;
	}
	case 47; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		line_x : float = term_op.terminal_tsl.x_start_left + 1*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(line_x, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);

		//Test scroll with mouse wheel and then typing should bring us back to cmd
		game_input.mouse_cam = OpSpaceToCameraSpace(GetCenter(term_op.op_rect), op_space, op_2D_cam.world_pos, default_base_cam);
		game_input.mouse_wheel = 1;
		test_tsl.start_file_line_index -= 1;
	}
	case 48; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test scroll up wheel
		game_input.mouse_wheel = 10;
		test_tsl.start_file_line_index -= 10;
	}
	case 49; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test scroll down wheel
		game_input.mouse_wheel = -1;
		test_tsl.start_file_line_index += 1;
	}
	case 50; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test scroll down wheel
		game_input.mouse_wheel = -3;
		test_tsl.start_file_line_index += 3;
	}
	case 51; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test typing should bring us back to cmd at bottom
		AddTextInput("t", game_input);
		DownUpThisFrame(.BACKSPACE, game_input);
		test_tsl.start_file_line_index = 12;
	}
	case 52; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting the cmd and then mouse highlighting terminal output and the mouse highlighting with scrolling
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_tsl.cursor_left_mouse_holding = true;
		test_tsl.cursor_line_char = 1;
		test_tsl.cursor_line_number = 31;
	}
	case 53; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting to start of cmd
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-2) * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		test_tsl.cursor_is_selecting = true;
		test_tsl.fixed_select_line_char = test_tsl.cursor_line_char;
		test_tsl.fixed_select_line_number = test_tsl.cursor_line_number;
		test_tsl.cursor_line_char = (term_op.terminal_tsl.line_char_count/2)+1;
		test_tsl.cursor_line_number -= 2;
	}
	case 54; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting to start of cmd
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left,
			term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-2) * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 55; {
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);

		test_tsl.cursor_line_char = 0;
		test_tsl.cursor_left_mouse_holding = false;
	}
	case 56; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TEST copying with mouse highlighting works on cmd including the start cmd string
		DownUpInputMap(.TEXT_COPY, game_input);
	}
	case 57; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		cb_text : string = os_clipboard_get_text(,,temp);
		test_text : string = tprint("%0%0", td.terminal_start_cmd_string, three_line_cmd);
		AssertEquals(test_text, cb_text);
	}
	case 58; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting the cmd and then mouse highlighting terminal output and the mouse highlighting with scrolling
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_tsl.cursor_left_mouse_holding = true;
		test_tsl.cursor_line_char = 3;
		test_tsl.cursor_line_number = 31;
	}
	case 59; {
		//Test mouse highlighting with text scrolling with up mouse off screen
		op_mouse := Vector2F.{
			term_op.op_rect.min.x - 5*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);

		test_tsl.cursor_line_char = 0;
		test_tsl.cursor_line_number = 12;
	}
	case 60; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting with text scrolling with up mouse off screen
		line_count : int = 1;
		op_mouse := Vector2F.{
			term_op.op_rect.min.x - 5*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top + line_count * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);

		test_tsl.start_file_line_index -= line_count;
		test_tsl.cursor_line_number -= line_count;
	}
	case 61; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting with text scrolling with up mouse off screen
		line_count : int = 3;
		op_mouse := Vector2F.{
			term_op.op_rect.min.x - 5*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top + line_count * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);

		test_tsl.start_file_line_index -= line_count;
		test_tsl.cursor_line_number -= line_count;
	}
	case 62; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting with text scrolling with up mouse off screen
		line_count : int = 8;
		op_mouse := Vector2F.{
			term_op.op_rect.min.x - 5*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top + line_count * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);

		test_tsl.start_file_line_index -= line_count;
		test_tsl.cursor_line_number -= line_count;
	}
	case 63; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting with text scrolling with up mouse off screen
		//continuing scrolling up here should do nothing since we are at the end of the start lines
		line_count : int = 8;
		op_mouse := Vector2F.{
			term_op.op_rect.min.x - 5*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top + line_count * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 64; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		test_tsl.cursor_left_mouse_holding = false;
	}
	case 65; {
		//Test mouse highlighting from top to bottom
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - 1 * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_tsl.cursor_is_selecting = false;
		test_tsl.cursor_left_mouse_holding = true;
		test_tsl.cursor_line_char = 14;
		test_tsl.cursor_line_number = 1;
	}
	case 66; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting from top to bottom
		line_count : int = 3;
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - line_count * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		test_tsl.cursor_is_selecting = true;
		test_tsl.fixed_select_line_char = test_tsl.cursor_line_char;
		test_tsl.fixed_select_line_number = test_tsl.cursor_line_number;
		test_tsl.cursor_line_char = 1;
		test_tsl.cursor_line_number += (line_count-1);//-1 since we were already at 1 one previous test
	}
	case 67; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting from top to bottom with scrolling
		line_count : int = 0;
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero+line_count) * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		test_tsl.cursor_line_char = 0;
		test_tsl.cursor_line_number = 19;
	}
	case 68; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting from top to bottom with scrolling
		line_count : int = 1;
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero+line_count) * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		test_tsl.cursor_line_char = 30;
		test_tsl.cursor_line_number += line_count;
		test_tsl.start_file_line_index += line_count;
	}
	case 69; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting from top to bottom with scrolling
		line_count : int = 3;
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero+line_count) * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		test_tsl.cursor_line_char = 3;
		test_tsl.cursor_line_number += line_count;
		test_tsl.start_file_line_index += line_count;
	}
	case 70; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting from top to bottom with scrolling
		line_count : int = 8;
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero+line_count) * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		test_tsl.cursor_line_char = 1;
		test_tsl.cursor_line_number += line_count;
		test_tsl.start_file_line_index += line_count;
	}
	case 71; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting from top to bottom with scrolling should not go anywhere since we are at the bottom
		line_count : int = 5;
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero+line_count) * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
	}
	case 72; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		test_tsl.cursor_left_mouse_holding = false;
	}
	case 73; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting something in the middle to check its correct
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.1*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - 8 * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_tsl.cursor_left_mouse_holding = true;
		test_tsl.cursor_is_selecting = false;
		test_tsl.cursor_line_char = 0;
		test_tsl.cursor_line_number = 20;
	}
	case 74; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting text and back to same point should remove cursor selection
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.1*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - 12 * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);

		test_tsl.cursor_is_selecting = true;
		test_tsl.fixed_select_line_char = test_tsl.cursor_line_char;
		test_tsl.fixed_select_line_number = test_tsl.cursor_line_number;
		test_tsl.cursor_line_char = 0;
		test_tsl.cursor_line_number += 4;
	}
	case 75; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting text and back to same point should remove cursor selection
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.1*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - 8 * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);

		test_tsl.cursor_is_selecting = false;
		test_tsl.cursor_line_char = 0;
		test_tsl.cursor_line_number = 20;
	}
	case 76; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting something in the middle to check its correct
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.1*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - 12 * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);

		test_tsl.cursor_is_selecting = true;
		test_tsl.fixed_select_line_char = test_tsl.cursor_line_char;
		test_tsl.fixed_select_line_number = test_tsl.cursor_line_number;
		test_tsl.cursor_line_char = 0;
		test_tsl.cursor_line_number += 4;
	}
	case 77; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		

		//Test copying text in middle to see it is correct
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		DownUpInputMap(.TEXT_COPY, game_input);
		test_tsl.cursor_left_mouse_holding = false;
	}
	case 78; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		

		cb_text : string = os_clipboard_get_text(,,temp);
		test_text : string = tprint("-%\n", four_line_cmd);
		AssertEquals(test_text, cb_text);
	}
	case 79; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		
	}
	case 80; {
		//Test scroll up and down with keyboard and see that keyboard input puts the cmd line back in view
		RunSubTestNTimes(6, *perm.test_data);
		DownUpThisFrame(.ARROW_UP, .{ctrl_pressed=true}, game_input);
	}
	case 81; {
		test_tsl.start_file_line_index -= 6;

		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		
	}
	case 82; {
		RunSubTestNTimes(4, *perm.test_data);
		//Test scroll up and down with keyboard and see that keyboard input puts the cmd line back in view
		DownUpThisFrame(.ARROW_DOWN, .{ctrl_pressed=true}, game_input);
	}
	case 83; {
		test_tsl.start_file_line_index += 4;

		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);	
	}
	case 84; {
		//TEST that keyboard input without text input updates properly and undoes mouse highlighting selection
		//and moves the line bounds
		DownUpThisFrame(.HOME, game_input);	
		test_tsl.cursor_is_selecting = false;
		test_tsl.start_file_line_index += 2;
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;
	}
	case 85; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//TODO WE could write more extensive tests for terminal resizing but at least this checks that
		//it does change data and also that the cursor is in the write place on the next test since it should be shorter
		//but still valid with the viewable lines and line char count
		//Test resizing terminal still is correct with split lines
		op_space.world_size *= 0.9;
		ResizeTerminalOpSpace(term_op, op_space.world_size, renderer_data.base_render_group.pixels_per_square, 
			perm.text_editor_data, perm.terminal_data);
		test_tsl.start_file_line_index += 2;
		test_tsl.viewable_lines_from_zero -= 2;
		test_tsl.line_char_count -= 6;

		DownUpThisFrame(.END, game_input);
		for 0..13 DownUpThisFrame(.ARROW_LEFT, game_input);
		test_td.terminal_cursor.char_point = 104;
		test_td.terminal_cursor.cursor_line_char = 104;
	}
	case 86; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test the resize worked with thec cursor in a new position here based on updated
		op_pos : Vector2F = TerminalCmdCharPointToOpPos(td.terminal_cursor.char_point,
			perm.text_editor_data.code_font_1_char_width_world, term_op, td.*);
		//-1* because we are 1 char off the end
		line_x : float = term_op.terminal_tsl.x_start_left + (term_op.terminal_tsl.line_char_count-1)*perm.text_editor_data.code_font_1_char_width_world;
		AssertFloatEquals(line_x, op_pos.x);
		line_y : float = term_op.terminal_tsl.y_start_top - (term_op.terminal_tsl.viewable_lines_from_zero-1) * term_op.terminal_tsl.line_height;
		AssertFloatEquals(line_y, op_pos.y);
	}
	case 87; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting the cmd and then mouse highlighting terminal output and the mouse highlighting with scrolling
		op_mouse := Vector2F.{
			term_op.terminal_tsl.x_start_left + 0.5*term_op.terminal_tsl.line_char_count*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top - term_op.terminal_tsl.viewable_lines_from_zero * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);
		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
		test_tsl.cursor_left_mouse_holding = true;
		test_tsl.cursor_line_char = 13;
		test_tsl.cursor_line_number = 31;
	}
	case 88; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);

		//Test mouse highlighting with text scrolling with up mouse off screen
		line_count : int = 3;
		op_mouse := Vector2F.{
			term_op.op_rect.min.x - 5*perm.text_editor_data.code_font_1_char_width_world,
			term_op.terminal_tsl.y_start_top + line_count * term_op.terminal_tsl.line_height
		};
		game_input.mouse_cam = OpSpaceToCameraSpace(op_mouse, op_space, op_2D_cam.world_pos, default_base_cam);

		test_tsl.cursor_is_selecting = true;
		test_tsl.fixed_select_line_char = test_tsl.cursor_line_char;
		test_tsl.fixed_select_line_number = test_tsl.cursor_line_number;
		test_tsl.cursor_line_number = 11;
		test_tsl.cursor_line_char = 0;
		test_tsl.start_file_line_index -= line_count;
	}
	case 89; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);		
		test_tsl.cursor_left_mouse_holding = false;
	}
	case 90; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		

		AddPressKeyboard(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
		//test clear command works properly
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		test_tsl.cursor_is_selecting = false;
		test_tsl.start_file_line_index += 3;
	}
	case 91; {
		//note that clear command is not added to command history since it gets cleared
		AddTextInput(clear_cmd, game_input);
		// test_td.cmd_history_count += 1;
		// test_td.next_cmd_history_index += 1;
		cmd : string = sprint(clear_cmd);
		test_td.terminal_command_string.text_string = cmd;
		test_td.terminal_cursor.char_point = cmd.count;
		test_td.terminal_cursor.cursor_line_char = cmd.count;	
		test_tsl.split_lines.count -= 2;
	}
	case 92; {
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		

		DownUpThisFrame(.ENTER, game_input);
		test_tsl.cursor_line_number = 0;
		test_tsl.start_file_line_index = 0;
		test_tsl.char_point = 0;
		test_tsl.cursor_line_char = 0;
		test_td.terminal_command_string.text_string = "";
		test_td.terminal_cursor.char_point = 0;
		test_td.terminal_cursor.cursor_line_char = 0;	
		test_tsl.split_lines.count = 1;
	}
	case 93; {
		//TEST We should still have the first empty line on clearing
		AssertEquals(td.terminal_start_cmd_string, term_op.terminal_tsl.split_lines[0].split_string);
		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		
	}
	case 94; {
		//Reset the terminal at the end here so that it resets after this test
		//TODO Can remove this test case if we want to check terminal tests without it
		ResetTerminalData(td, perm.all_data.all_terminal_op_space_data);
		test_td.cmd_history_count = 1;
		test_td.terminal_cmd_history.count = td.cmd_history_max_count;
		test_td.next_cmd_history_index = 0;

		AssertTextSplitLine(test_tsl, term_op.terminal_tsl);
		AssertTerminalData(test_td, perm.terminal_data);		
	}
	}

	ContinueTest(*perm.test_data);
} @ITest

//TODO Can put this in text tests if we cleanup all the cursor assertions eventually
Test_InputMappings :: (
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
		perm.test_data.spec_data = New(GameInput);
		test_input := cast(*GameInput) perm.test_data.spec_data;
		test_input.game_input_mappings = CopyDefaultInputMappings();
		array_resize(*perm.test_data.all_sub_tests, 32+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	test_input := cast(*GameInput) perm.test_data.spec_data;

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
	default_base_cam : Camera2D = GetRenderMSpace(perm.all_data).mspace_cam;
	// ator : AllTextOpRects;	
	// top : TextOpPositions;
	if perm.all_data.all_open_op_spaces.count > 0 {
		op_space = perm.all_data.all_open_op_spaces[0];
		op_2D_cam = op_space.op_2D_cam;
		// top = ComputeTextOpPositions(text_op.ator, op_space, text_op, perm.text_editor_data);
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		//test that we start of with default values just in case to makes sure test setup is good
		AssertInputMappings(test_input.game_input_mappings, game_input.game_input_mappings);

		//delete this file just in case we still have it generated from another test
		file_is_deleted := file_delete(TEST_GENERATE_INPUT_MAPPING);
		generate_test := MakeTerminalEvent(.generate_input_mappings, "-default", TEST_GENERATE_INPUT_MAPPING);
		array_add(*perm.all_data.all_terminal_events, generate_test);
	}
	case 1; {
		AssertEquals(true, file_exists(TEST_GENERATE_INPUT_MAPPING));

		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, TEST_GENERATE_INPUT_MAPPING);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 2; {
		AssertEquals(1, perm.all_data.all_open_op_spaces.count);
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);

		//TEST update 2 input mappings and make sure they get updated properly in game input mappings
		//then we actually use one to see that it works with the new input mapping
		DownUpInputMap(.TEXT_FILE_FIND_TEXT_BAR, game_input);
	}
	case 3; {
		//Get the name in case we change the enum eventually
		toggle_terminal_name := INPUT_MAP_TYPE_NAMES[InputMapType.TERMINAL_TOGGLE];
		AddTextInput(toggle_terminal_name, game_input);
	}
	case 4; {
		DownUpThisFrame(.ENTER, game_input);
	}
	case 5; {
		DownUpThisFrame(.ESCAPE, game_input);
	}
	case 6; {
		for 0..2 DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.ARROW_LEFT, game_input);
		for 0..2 DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		AddTextInput("alt+shift+m", game_input);
	}
	case 7; {
		//TEST update 2 input mappings and make sure they get updated properly in game input mappings
		//then we actually use one to see that it works with the new input mapping
		DownUpInputMap(.TEXT_FILE_FIND_TEXT_BAR, game_input);
	}
	case 8; {
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		//Get the name in case we change the enum eventually
		text_debug_toggle_name := INPUT_MAP_TYPE_NAMES[InputMapType.TEXT_DEBUG_TOGGLE];
		AddTextInput(text_debug_toggle_name, game_input);
	}
	case 9; {
		DownUpThisFrame(.ENTER, game_input);
	}
	case 10; {
		DownUpThisFrame(.ESCAPE, game_input);
	}
	case 11; {
		for 0..2 DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.ARROW_LEFT, game_input);
		for 0..2 DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		AddTextInput("ctrl+alt+f2", game_input);
	}
	case 12; {
		DownUpInputMap(.TEXT_FILE_SAVE, game_input);
	}
	case 13; {
		set_test := MakeTerminalEvent(.set_input_mappings_file, TEST_GENERATE_INPUT_MAPPING);
		array_add(*perm.all_data.all_terminal_events, set_test);

		//Update both test input mapping now that we reloaded the file
		test_input.game_input_mappings[InputMapType.TERMINAL_TOGGLE].keyboard_maps[0].key_code = xx #char "M";
		test_input.game_input_mappings[InputMapType.TERMINAL_TOGGLE].keyboard_maps[0].modifier_flags = .{alt_pressed=true,shift_pressed=true};
		test_input.game_input_mappings[InputMapType.TEXT_DEBUG_TOGGLE].keyboard_maps[0].key_code = .F2;
		test_input.game_input_mappings[InputMapType.TEXT_DEBUG_TOGGLE].keyboard_maps[0].modifier_flags = .{alt_pressed=true,ctrl_pressed=true};
	}
	case 14; {
		AssertInputMappings(test_input.game_input_mappings, game_input.game_input_mappings);

		new_terminal_key_code : Input.Key_Code = test_input.game_input_mappings[InputMapType.TERMINAL_TOGGLE].keyboard_maps[0].key_code;
		new_terminal_modifiers : Input.Event.Modifier_Flags = test_input.game_input_mappings[InputMapType.TERMINAL_TOGGLE].keyboard_maps[0].modifier_flags;
		//Test that the new input mapping works. We test directly with keys instead of input map to make sure its working
		//without the input map.
		DownUpThisFrame(new_terminal_key_code, new_terminal_modifiers, game_input);
	}
	case 15; {
		AssertEquals(2, perm.all_data.all_open_op_spaces.count);
		AssertEquals(1, perm.all_data.all_terminal_op_space_data.count);
		term_op : *TerminalOpSpaceData = *perm.all_data.all_terminal_op_space_data[0];
		term_op_space : *OperationSpace = *perm.all_data.all_open_op_spaces[1];
		AssertEquals(term_op_space.id, term_op.op_space_id);

		close_test := MakeTerminalEvent(.close_op, term_op_space.op_space_name);
		array_add(*perm.all_data.all_terminal_events, close_test);
	}
	case 16; {
		AssertEquals(1, perm.all_data.all_open_op_spaces.count);
		AssertEquals(1, perm.all_data.all_closed_op_spaces.count);
		AssertEquals(1, perm.all_data.all_terminal_op_space_data.count);
		AssertEquals(perm.all_data.all_closed_op_spaces[0].id, perm.all_data.all_terminal_op_space_data[0].op_space_id);

		//Choose this directly here so we don't overuse to many other functions in a test for input mappings
		ChooseOpSpace(op_space, perm.all_data, renderer_data);
	}
	case 17; {
		AssertEquals(ExecutionMode.RUN, text_op.exec_info.exec_mode);

		new_debug_key_code : Input.Key_Code = test_input.game_input_mappings[InputMapType.TEXT_DEBUG_TOGGLE].keyboard_maps[0].key_code;
		new_debug_modifiers : Input.Event.Modifier_Flags = test_input.game_input_mappings[InputMapType.TEXT_DEBUG_TOGGLE].keyboard_maps[0].modifier_flags;
		//Test that the new input mapping works. We test directly with keys instead of input map to make sure its working
		//without the input map.
		DownUpThisFrame(new_debug_key_code, new_debug_modifiers, game_input);
	}
	case 18; {
		AssertEquals(ExecutionMode.DEBUG, text_op.exec_info.exec_mode);

		//TEST 2 input mappings for 1 command and then test invalid input mappings and invalid commads
		//and add the error outputs to the text console
		DownUpInputMap(.TEXT_FILE_FIND_TEXT_BAR, game_input);
	}
	case 19; {
		DownUpInputMap(.TEXT_SELECT_ALL, game_input);
		//Get the name in case we change the enum eventually
		text_debug_toggle_name := INPUT_MAP_TYPE_NAMES[InputMapType.TEXT_CONSOLE_TOGGLE];
		AddTextInput(text_debug_toggle_name, game_input);
	}
	case 20; {
		DownUpThisFrame(.ENTER, game_input);
	}
	case 21; {
		DownUpThisFrame(.ESCAPE, game_input);
	}
	case 22; {
		for 0..2 DownUpThisFrame(.ARROW_DOWN, game_input);
		//Test here that an uppercase character still works
		AddTextInput(", \"alt+shift+I\"", game_input);
	}
	case 23; {
		DownUpInputMap(.TEXT_FILE_SAVE, game_input);
	}
	case 24; {
		DownUpInputMap(.TEXT_FILE_UPDATE_DATA, game_input);

		//Update both test input mapping now that we reloaded the file
		new_maps := NewArray(2, KeyboardMap);
		new_maps[0] = test_input.game_input_mappings[InputMapType.TEXT_CONSOLE_TOGGLE].keyboard_maps[0];
		new_maps[1].key_code = xx #char "I";
		new_maps[1].modifier_flags = .{alt_pressed=true,shift_pressed=true};
		//NO need to free here since its all in the test alloc and will get cleared at the end of the test
		test_input.game_input_mappings[InputMapType.TEXT_CONSOLE_TOGGLE].keyboard_maps = new_maps;
	}
	case 25; {
		AssertInputMappings(test_input.game_input_mappings, game_input.game_input_mappings);
		AssertEquals(TextPaneType.DISASSEMBLY, text_op.l_bottom_pane_type);
		AssertEquals(true, text_op.console_tsl.split_lines.count > 0);
		AssertEquals(true, text_op.all_console_lines.count > 0);
		AssertEquals(true, text_op.console_dynamic_string.text_string.count > 0);

		new_console_key_code : Input.Key_Code = test_input.game_input_mappings[InputMapType.TEXT_CONSOLE_TOGGLE].keyboard_maps[1].key_code;
		new_console_modifiers : Input.Event.Modifier_Flags = test_input.game_input_mappings[InputMapType.TEXT_CONSOLE_TOGGLE].keyboard_maps[1].modifier_flags;
		//Test that the new input mapping works. We test directly with keys instead of input map to make sure its working
		//without the input map.
		DownUpThisFrame(new_console_key_code, new_console_modifiers, game_input);
	}
	case 26; {
		AssertEquals(TextPaneType.COMPILER_CONSOLE, text_op.l_bottom_pane_type);

		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 27; {
		//TEST invalid input mappings should not update the game input mappings
		//AND THEN ALSO test saving directly should output to text console
		for 0..1 DownUpThisFrame(.BACKSPACE, game_input);
	}
	case 28; {
		DownUpInputMap(.TEXT_FILE_UPDATE_DATA, game_input);
	}
	case 29; {
		AssertInputMappings(test_input.game_input_mappings, game_input.game_input_mappings);
		AssertEquals(true, text_op.console_tsl.split_lines.count > 0);
		AssertEquals(true, text_op.all_console_lines.count > 0);
		AssertEquals(true, text_op.console_dynamic_string.text_string.count > 0);
	}
	case 30; {
		//TEST GENERATE and then update to make sure we still have the same with the error before
		generate_test := MakeTerminalEvent(.generate_input_mappings, TEST_GENERATE_INPUT_MAPPING);
		array_add(*perm.all_data.all_terminal_events, generate_test);
		load_test := MakeTerminalEvent(.load_input_mappings);
		array_add(*perm.all_data.all_terminal_events, load_test);
	}
	case 31; {
		AssertInputMappings(test_input.game_input_mappings, game_input.game_input_mappings);
	}
	case 32; {
		file_is_deleted := file_delete(TEST_GENERATE_INPUT_MAPPING);
		AssertEquals(true, file_is_deleted);
	}
	}
	//TODO FROM HERE maybe should do default settings first so we can set that in here
	//and then test updating with console logs here for updating input maps from text op
	//should we update on save or separate hotkey (i think on save so it stays consistent)

	//TODO Should we add tests for settings conversion or is it ok since we will use dynamic libraries later?

	//TODO FROM HERE test updating font size to see if its ok with text op space and borders and terminals

	//TODO FROM HERE update test input mappings manually, we can either use find bar here to be conistent
	//or think of another way to keep the updating consistent
	//but maybe its best to do it that way since that is how people will use it in general to find a setting
	//and then update it from there, then also test invalid updates to make sure it does not update and then
	//we can output the error to the text op console or the text status bar.

	//TODO ALSO TRY AND PARSE A NONEXISTANT FILE to make sure that is working

	//TODO FROM HERE update input mappings in game and make sure it updates mappings on saving
	//opening the file should be the same as the text file
	//THEN TEST by checking data but also checking that the new input mapping actually works
	//maybe can do it for 2 input mappings
	//saving in game should update game mappings BUT saving externally maybe we don't do that for now
	//and just have a terminal command the reloads game inputs or just open the file and hit save
	//ALSO TEST invalid saving should save the file but not update the input mappings
	//ALSO See if we should add errors the the text op console split lines and then update name to text op console
	//instead of compiler console

	ContinueTest(*perm.test_data);

} @ITest

Test_RuntimeSettings :: (
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
		perm.test_data.spec_data = New(RuntimeSettingsData);
		array_resize(*perm.test_data.all_sub_tests, 20+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	test_settings := cast(*RuntimeSettingsData) perm.test_data.spec_data;

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
	default_base_cam : Camera2D = GetRenderMSpace(perm.all_data).mspace_cam;
	// ator : AllTextOpRects;	
	// top : TextOpPositions;
	if perm.all_data.all_open_op_spaces.count > 0 {
		op_space = perm.all_data.all_open_op_spaces[0];
		op_2D_cam = op_space.op_2D_cam;
		// top = ComputeTextOpPositions(text_op.ator, op_space, text_op, perm.text_editor_data);
	}

	if perm.test_data.sub_test_index == {
	case 0; {
		//delete this file just in case we still have it generated from another test
		file_is_deleted := file_delete(TEST_GENERATE_RUNTIME_SETTINGS);
		generate_test := MakeTerminalEvent(.generate_runtime_settings, "-default", TEST_GENERATE_RUNTIME_SETTINGS);
		array_add(*perm.all_data.all_terminal_events, generate_test);
	}
	case 1; {
		AssertEquals(true, file_exists(TEST_GENERATE_RUNTIME_SETTINGS));

		open_test := MakeTerminalEvent(.load_op, TEST_TEXT_NAME, TEST_GENERATE_RUNTIME_SETTINGS);
		array_add(*perm.all_data.all_terminal_events, open_test);
	}
	case 2; {
		AssertEquals(1, perm.all_data.all_open_op_spaces.count);
		AssertEquals(1, perm.all_data.all_text_op_space_data.count);
		AssertEquals(1, perm.all_data.all_text_files.count);

		//TEST This sets and loads the generated runtime settings file
		//so we are testing load here
		set_test := MakeTerminalEvent(.set_runtime_settings_file, TEST_GENERATE_RUNTIME_SETTINGS);
		array_add(*perm.all_data.all_terminal_events, set_test);
	}
	case 3; {
		AssertEquals(TEST_GENERATE_RUNTIME_SETTINGS, perm.all_data.runtime_settings_file_path);
		AssertRuntimeSettings(test_settings, perm.all_data.runtime_settings);

		//TEST update 2 settings and make sure they get updated properly in game settings
		DownUpInputMap(.TEXT_FILE_FIND_TEXT_BAR, game_input);
	}
	case 4; {
		AddTextInput("default_font_color", game_input);
	}
	case 5; {
		DownUpThisFrame(.ENTER, game_input);
	}
	case 6; {
		DownUpThisFrame(.ESCAPE, game_input);
	}
	case 7; {
		DownUpThisFrame(.END, game_input);
		DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		r_value : int = 1;
		test_settings.default_font_color.x = r_value / 255.0;
		AddTextInput(tprint("%,", r_value), game_input);

		DownUpThisFrame(.ARROW_DOWN, game_input);
		DownUpThisFrame(.ARROW_LEFT, .{ctrl_pressed=true, shift_pressed=true}, game_input);
		g_value : int = 25;
		test_settings.default_font_color.y = g_value / 255.0;
		AddTextInput(tprint("%,", g_value), game_input);
	}
	case 8; {
		DownUpInputMap(.TEXT_FILE_SAVE, game_input);
	}
	case 9; {
		//TEST load updated settings which should take no arguments
		set_test := MakeTerminalEvent(.load_runtime_settings);
		array_add(*perm.all_data.all_terminal_events, set_test);
	}
	case 10; {
		AssertRuntimeSettings(test_settings, perm.all_data.runtime_settings);

		//TEST loading invalid settings should not update settings
		//so we don't update test settings here
		for 0..2 DownUpThisFrame(.BACKSPACE, game_input);
		AddTextInput("22", game_input);
	}
	case 11; {
		DownUpInputMap(.TEXT_FILE_SAVE, game_input);
	}
	case 12; {
		//TEST load updated settings which should take no arguments
		load_test := MakeTerminalEvent(.load_runtime_settings);
		array_add(*perm.all_data.all_terminal_events, load_test);
	}
	case 13; {
		AssertRuntimeSettings(test_settings, perm.all_data.runtime_settings);

		//TEST load invalid with shortcut should print a text op console error
		//then can undo and check that it's good again then do same for input mappings
		DownUpInputMap(.TEXT_FILE_UPDATE_DATA, game_input);
	}
	case 14; {
		AssertRuntimeSettings(test_settings, perm.all_data.runtime_settings);
		AssertEquals(true, text_op.console_tsl.split_lines.count > 0);
		AssertEquals(true, text_op.all_console_lines.count > 0);
		AssertEquals(true, text_op.console_dynamic_string.text_string.count > 0);

		DownUpInputMap(.TEXT_CONSOLE_TOGGLE, game_input);
	}
	case 15; {
		AssertEquals(TextPaneType.COMPILER_CONSOLE, text_op.l_bottom_pane_type);

		DownUpInputMap(.TEXT_PANE, game_input);
	}
	case 16; {
		for 0..3 DownUpThisFrame(.BACKSPACE, game_input);
		// test_settings.terminal_start_pos.y = 3.14;
		// AddTextInput(tprint("%,", test_settings.terminal_start_pos.y), game_input);
	}
	case 17; {
		//TEST update valid with shortcut should print a text op console msg as well.
		DownUpInputMap(.TEXT_FILE_UPDATE_DATA, game_input);	
	}
	case 18; {
		AssertRuntimeSettings(test_settings, perm.all_data.runtime_settings);
		AssertEquals(true, text_op.console_tsl.split_lines.count > 0);
		AssertEquals(true, text_op.all_console_lines.count > 0);
		AssertEquals(true, text_op.console_dynamic_string.text_string.count > 0);

		//TEST generate with the updated settings should create it and then grab the correct ones
		generate_test := MakeTerminalEvent(.generate_runtime_settings, TEST_GENERATE_RUNTIME_SETTINGS);
		array_add(*perm.all_data.all_terminal_events, generate_test);
		load_test := MakeTerminalEvent(.load_runtime_settings);
		array_add(*perm.all_data.all_terminal_events, load_test);
	}
	case 19; {
		//TEST load updated settings which should take no arguments
		AssertRuntimeSettings(test_settings, perm.all_data.runtime_settings);
	}
	case 20; {
		file_is_deleted := file_delete(TEST_GENERATE_RUNTIME_SETTINGS);
		AssertEquals(true, file_is_deleted);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

Test_StartupSettings :: (
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
		array_resize(*perm.test_data.all_sub_tests, 2+1);
	} 

	wait_test := WaitTest(*perm.test_data);
	if wait_test return;

	if perm.test_data.sub_test_index == {
	case 0; {
		//delete this file just in case we still have it generated from another test
		file_is_deleted := file_delete(TEST_GENERATE_STARTUP_SETTINGS);
		generate_test := MakeTerminalEvent(.generate_startup_settings, "-default", TEST_GENERATE_STARTUP_SETTINGS);
		array_add(*perm.all_data.all_terminal_events, generate_test);
	}
	case 1; {
		AssertEquals(true, file_exists(TEST_GENERATE_STARTUP_SETTINGS));
		ssr : StartupSettingsReturn = ParseStartupSettingsFile(TEST_GENERATE_STARTUP_SETTINGS);
		AssertStructEquals(StartupSettingsData.{}, ssr.new_settings);
	}
	case 2; {
		file_is_deleted := file_delete(TEST_GENERATE_STARTUP_SETTINGS);
		AssertEquals(true, file_is_deleted);
	}
	}

	ContinueTest(*perm.test_data);

} @ITest

GeneratorsTest :: (
	perm : *Persist,
	renderer_data : *RendererData = null,
   audio_data : *AudioData = null,
   game_input : *GameInput = null)
{
	SetupTestProcedure("GeneratorsTest");

	//TODO Could separate out the tests from the loading above and then we can also call 
	//the tests in game as a form of verification for the player if they follow the rules closely.

	/*TODO This is hardcoded to 12-eq but if we had other tuning_systems, then we would
	have to compute the generators directly since it would change.
	*/
	tuning_size : int = perm.all_data.all_tuning_systems[0].music_pt_count;
	AssertEquals(tuning_size*4, perm.all_data.global_rules.row_size);

	for memory_index : 0..11
	{
		memory_music_pts : [] *MusicPoint = GetAllMemoryIndexMusicPtPointers(memory_index,
			perm.all_data.global_rules.row_size, perm.all_data.all_mspace_data[0].all_music_pts);
		AssertEquals(1, memory_music_pts.count);
		if memory_music_pts.count > 0 {
			AssertEquals(memory_index, memory_music_pts[0].music_pt_pos);
		}
	}	

	fourths : int = 0;
	for memory_index : 12..23
	{
		memory_music_pts : [] *MusicPoint = GetAllMemoryIndexMusicPtPointers(memory_index,
			perm.all_data.global_rules.row_size, perm.all_data.all_mspace_data[0].all_music_pts);
		AssertEquals(1, memory_music_pts.count);
		if memory_music_pts.count > 0 {
			AssertEquals(fourths, memory_music_pts[0].music_pt_pos);
			fourths = (fourths + 5) % tuning_size;
		}
	}	

	fifths : int = 0;
	for memory_index : 24..35
	{
		memory_music_pts : [] *MusicPoint = GetAllMemoryIndexMusicPtPointers(memory_index,
			perm.all_data.global_rules.row_size, perm.all_data.all_mspace_data[0].all_music_pts);
		AssertEquals(1, memory_music_pts.count);
		if memory_music_pts.count > 0 {
			AssertEquals(fifths, memory_music_pts[0].music_pt_pos);
			fifths = (fifths + 7) % 12;
		}
	}
}

/*Some Asm Test Utilities. Should we put these in a separate file?
*/
RunFrames :: inline (
	frames_to_run : int,
	game_memory : *GameMemory,
	renderer_data : *RendererData, 
    audio_data : *AudioData,
    game_input : *GameInput) 
{
	for 0..frames_to_run-1 {
		UpdateAndRenderBase(game_memory, renderer_data, audio_data, game_input);
		ResetAllRenderGroups(renderer_data);
	}
}
//End of as