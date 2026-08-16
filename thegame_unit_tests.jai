/*Having @UnitTest notes allows us to put unit tests anywhere which should help with modularity eventually.
We can put the instruction tests in thegame_code in other words and not have to import anything extra for it
and it will all get read in properly at compile-time for convenience. Everything can still get called here
but the tests can be next to the code their testing, especially for unit tests where this can get specific
but also should not require much setup in cases where we are just testing specific algorithms like with code.
*/

/*NOTE REMINDER : We could have a separate allocator for unit test and integration tests so we can
run unit tests without affecting other tests if needed.
*/
unit_test_alloc_pool : Flat_Pool;
//NOTE: We set unit_unit_test_alloc.data in UpdateAndRenderTest
unit_test_alloc := Allocator.{flat_pool_allocator_proc, null};

//TODO Where should we put this. We could have to pass it into all unit tests if we don't put it globally.
//Maybe we could... seems unnecessary though...
UNIT_TEST_RESULTS : TestResults = TestResults.{test_name="ALL_UNIT_TESTS"};
RunAllUnitTests :: () {
	print("\nUNIT TESTS\n");

	ResetTestResults(*UNIT_TEST_RESULTS);

	for 0..unit_test_functions.count-1 {
		RunUnitTestWithSetup(it);

		//We reset on next test, so we still have the information from assert test here.
		//TODO Should rename to CURRENT_TEST_RESULTS
		if CURRENT_TEST_RESULTS.fail_count == 0 {
			UNIT_TEST_RESULTS.pass_count += 1;
		} else {
			UNIT_TEST_RESULTS.fail_count += 1;
		}
	}

	LogTestResults(UNIT_TEST_RESULTS);

	//Reset separate unit test allocator for good measure here just in case
	reset(*unit_test_alloc_pool, true);
}

//TODO We could pass in *TestData into RunUnitTest and set TEST_FINISHED in here.
//Then we could also use other data if needed but I like having unit_tests with no input.
//Makes it clear that we are just running that function and everything is self contained.
//If we passed in TestData, we could then put the unit_test_alloc_pool in there and even the unit_test_alloc.
//I can do that if it seems better eventually.
RunUnitTest :: (test_name : string) {
	#if 0 {
	//TODO No need to generate hash table unless the tests get really slow or something
	test_index, found_test := table_find(*unit_test_hash_table, test_name);
	} else {
	found_test, test_index := array_find(unit_test_names, test_name);
	}

	if !found_test {
		print("Unit test % not found\n", test_name);
		return;
	}

	RunUnitTestWithSetup(test_index);
}

UnitTestFunction :: #type () -> ();
RunUnitTestWithSetup :: inline (test_index : int) {
	//TODO I think we need true here on the reset since all the tests are different anyways
	reset(*unit_test_alloc_pool, true);

	function_name : string = unit_test_function_names[test_index];
	ResetTestResults(function_name, *CURRENT_TEST_RESULTS);

	test_function : UnitTestFunction = unit_test_functions[test_index];
	//TODO FROM HERE Instead of passing this in here we could not so that then we could pass in
	//a context.allocator for things like logs. But maybe we can also add another allocator
	//specifically for test results so we can show them in-game instead of only in the console.
	test_function(,,unit_test_alloc);

	//TODO We could add the test results to a fail and pass array and then print all the failures
	//together at the end if that is helpful.
 	LogCurrentTestResults(CURRENT_TEST_RESULTS);
}

#if 0 {
unit_test_hash_table :: #run () -> Table(string,int) {
	t : Table(string, int);
	for unit_test_names table_add(*t, it, it_index);
	return t;
}();
}

//This is now compile-time generated with @UnitTest note. Leaving here just in case.
#if 0 {
unit_test_enum_count : int : #run enum_names(UnitTestName).count;
unit_test_names : [] string : #run enum_names(UnitTestName);
unit_test_enums : [] UnitTestName : #run enum_values_as_enum(UnitTestName);
UnitTestName :: enum {
	Lexer;
}
}

//TODO Should we report that this does not work even though it is run at compile time?
// all_unit_tests :: #run () -> [] UnitTestFunction {
// 	test_names : [] string = enum_names(UnitTestName);
// 	for name, name_index : test_names {
// 		value := #insert -> string {
//     		// return builder_string("Test_%", name);
// 			// print_to_builder(*default_builder, "Test_%", name);
// 			// return builder_to_string(*default_builder);
// 			return name;
// 		}
// 	}
// 	return unit_tests;
// }();

//TODO Could make this into a struct. ALSO expected struct could be some subset of the actual struct if needed.
//TODO Should we move these into thegame_test if we use them there as well?
TestInstr :: inline (expected_instr : MusicInstruction, actual_instr : MusicInstruction, instr_index : int = -1) {
	//TODO Could just print out the entire expected and actual instructions if that helps out with the index.
	instr_msg : string;
	if instr_index != -1 {
		instr_msg = sprint("instr_index=%",instr_index,,unit_test_alloc);
		//TODO This would work if we could convert an instruction to an asm string, so like a disassembly function.
		//TODO This would require a DISASSEMBLY function as well as if we had disassembly in the the debugger.
		// instr_msg = sprint("instr_index=%, expected=%,actual=%",instr_index,expected_instr,actual_instr,,unit_test_alloc);
		//TODO THEN USE PASSED AS af=.{print_error=passed} so we only print 1 error OR better yet we can return
		//the error and then print it all here so we print exactly what we want.
	}

	//TODO used failed here instead of printing out every single error. Pass it in as a flag and just print out 1 error
	passed : bool = AssertEquals(expected_instr.op_code, actual_instr.op_code, sprint("%",instr_msg,,unit_test_alloc));
	// passed : bool = AssertEquals(expected_instr.op_code, actual_instr.op_code, af=.{print_error=false});
	passed &&= AssertEquals(expected_instr.instr_type, actual_instr.instr_type, sprint("%",instr_msg,,unit_test_alloc));

	err : CPUError = ValidateMusicInstruction(actual_instr); 
	passed &&= AssertEquals(false, err.is_error, instr_msg);
	// passed &&= AssertEquals(false, err.is_error, af=.{print_error=false});

	for expected_op, op_index : expected_instr.operands {
		actual_op : MusicOperand = actual_instr.operands[op_index];
		passed &&= AssertEquals(expected_op.operand_type, actual_op.operand_type, sprint("%,op=%",instr_msg,op_index,,unit_test_alloc));
		// passed &&= AssertEquals(expected_op.operand_type, actual_op.operand_type, af=.{print_error=false});
		for expected_value, v_index : expected_op.values {
			actual_value : MusicOperandValue = actual_op.values[v_index];
			//TODO Put this back once we have dissasembler for outputting MusicInstructions
			if expected_value.type == {
			case .REGISTER;
				if expected_instr.instr_type == .FLOAT {
					passed &&= AssertFloat64Equals(expected_value.float_value, actual_value.float_value, sprint("%,op=%,v=%",instr_msg,op_index,v_index,,unit_test_alloc));
				} else if expected_instr.instr_type == .INTEGER {
					passed &&= AssertEquals(expected_value.int_value, actual_value.int_value, sprint("%,op=%,v=%",instr_msg,op_index,v_index,,unit_test_alloc));
				}
			case .FLOAT;
				passed &&= AssertFloat64Equals(expected_value.float_value, actual_value.float_value, sprint("%,op=%,v=%",instr_msg,op_index,v_index,,unit_test_alloc));
			case .INTEGER;
				passed &&= AssertEquals(expected_value.int_value, actual_value.int_value, sprint("%,op=%,v=%",instr_msg,op_index,v_index,,unit_test_alloc));
			}
			// passed &&= AssertEquals(expected_value.int_value, actual_value.int_value, af=.{print_error=false});
			passed &&= AssertEquals(expected_value.type, actual_value.type, sprint("%,op=%,v=%",instr_msg,op_index,v_index,,unit_test_alloc));
			// passed &&= AssertEquals(expected_value.type, actual_value.type, af=.{print_error=false});
		}
	}

	#if 0 {
	if !passed {
		//TODO Should this be log or print?
		error_location : string = TestLocationString();
		//TODO Convert instruction to asm eventually like a disassembler for better output
		log_error("%instr_index=%\n expected=%\n actual=%\n", error_location, instr_index, expected_instr, actual_instr);
	}
	}
}

TestManyVarDeclSameStack :: inline (actual : [] VariableData, expected : [] VariableData) -> pass : bool {
	count_equal : bool = AssertEquals(expected.count, actual.count);
	if !count_equal return false;

	expected[0].op = RamMem(.sbp,0);
	for 1..expected.count-1 {
		next_stack : int = expected[it-1].op.values[1].int_value + expected[it-1].t_info.runtime_size;
		expected[it].op = RamMem(.sbp, next_stack);
	}

	pass : bool = true;
	for 0..expected.count-1 {
		pass &&= TestVarDecl(expected[it], actual[it]);
	}
	return pass;
}

TestNextManyVarDecl :: inline (var_index : *int, all_vars : [] VariableData, expected : [] VariableData) -> pass : bool {
	actual : [] VariableData = array_view(all_vars, var_index.*, expected.count);
	var_index.* += expected.count;

	count_equal : bool = AssertEquals(expected.count, actual.count);
	if !count_equal return false;

	pass : bool = true;
	for 0..expected.count-1 {
		pass &&= TestVarDecl(expected[it], actual[it]);
	}
	return pass;
}

VarMsg :: inline (value_name : string, expected_name : string) -> string {
	msg : string = sprint(
		"expected_var = %.%", expected_name, value_name,, unit_test_alloc);
	return msg;
}
TestVarDecl :: inline (expected : VariableData, actual : VariableData) -> bool {
	// expected_name : string = sprint("expected_var = %", expected.name,, unit_test_alloc);
	pass : bool = AssertEquals(expected.scope_index, actual.scope_index, VarMsg("scope_index", expected.name));
	//TODO Could make these separate variables for easier debugging.
	// pass &&= AssertEquals(expected.function_id, actual.function_id, expected_name);
	pass &&= AssertEquals(expected.name, actual.name, VarMsg("name", expected.name));
	pass &&= AssertEquals(expected.t_info, actual.t_info, VarMsg("t_info", expected.name));
	pass &&= AssertEquals(expected.op.values[0].type, actual.op.values[0].type, VarMsg("op_0_type", expected.name));
	if expected.t_info != null && expected.t_info.type_enum == .FLOAT {
		pass &&= AssertFloat64Equals(expected.op.values[0].float_value, actual.op.values[0].float_value, VarMsg("op_0_float", expected.name));
	} else {
		pass &&= AssertEquals(expected.op.values[0].int_value, actual.op.values[0].int_value, VarMsg("op_0_int", expected.name));
	}
	pass &&= AssertEquals(expected.op.values[1].type, actual.op.values[1].type, VarMsg("op_1_type", expected.name));
	pass &&= AssertEquals(expected.op.values[1].int_value, actual.op.values[1].int_value, VarMsg("op_1_int", expected.name));
	return pass;
}

VarDecl :: inline (
	name : string, t_info : *TypeInfo, 
	op : MusicOperand = .{},
	//We put 1 as the default here since the global scope == 0
	scope_index : int = 1) 
-> VariableData 
{
	var : VariableData;
	var.name = name;
	var.t_info = t_info;
	var.scope_index = scope_index;
	var.op = op;
	return var;	
}


/*Because we need to linearize the binary tree into an array anyways, this makes sense
to do like this for node testing. If it works well, then we can also use to simplify
instruction and lexer testing directly.

TODO With TestNodes, we can remove this test if we don't need it anymore.
*/
TestNodeTokens :: inline (expected_tokens : [] LCodeToken, actual_nodes : [] *BinaryNode) {
	count_equal : bool = AssertEquals(expected_tokens.count, actual_nodes.count);
	if count_equal for expected_tokens {
		index_name : string = sprint("index = %", it_index,, unit_test_alloc);
		//TODO Could put it_index here in the test name so we know which token failed exactly
		AssertEquals(it.token_type, actual_nodes[it_index].value.token_type, index_name);
		//TODO Could check this based on token_type whether its int or float or token_string
		AssertEquals(it.int_value, actual_nodes[it_index].value.int_value, index_name);
	}
}

TestNodes :: inline (expected_nodes : [] BinaryNode, actual_nodes : [] *BinaryNode) {
	count_equal : bool = AssertEquals(expected_nodes.count, actual_nodes.count);
	if count_equal for expected_nodes {
		index_name : string = sprint("index = %", it_index,, unit_test_alloc);
		//TODO Could put it_index here in the test name so we know which token failed exactly
		AssertEquals(it.value.token_type, actual_nodes[it_index].value.token_type, index_name);
		//TODO Could check this based on token_type whether its int or float or token_string
		AssertEquals(it.value.int_value, actual_nodes[it_index].value.int_value, index_name);
		AssertEquals(it.code_ir.ir_type, actual_nodes[it_index].code_ir.ir_type, index_name);
	}
}


/*I did not end up using these becuase although it does remove failure if the counts are the not the same,
it is very unclear which instruction failed. I prefer knowing which instruction failed and exactly where
than having this loop where the failure logs were very unclear to me.
Leaving here for now in case we want to do something similar later but can remove later if not used.
TECHNICALLY you could print the index when 1 fails but that would require passing things around to the assertions
which seems dirtier than just calling directly. We could eg check the assertions in TestInstr and if it returns
false then we could log an error with the index... I guess if needed we can do that later.

IN GENERAL I prefer having very clear and simple tests that work than something more convoluted that works.
Easier for me to see whats failing and fix it is the whole point of testing anyways.

WE COULD PASS THE INDEX THROUGH TO TestInstr though TestManyInstr 
and set that in each assertion for example. That wouldnt be so bad.
ALSO the instruction count not being equal is much less likely than other errors.
*/
#if 0 {
/*Documentation : This test ensures that we do not get memory access violations if actual_mi is invalid.
It also tests a few of the instructions if possible to give us more information in the logs.
It ALSO ensures that the number of assertions remains consistent even if there are failures,
although maybe that does not matter so much.
*/
TestManyInstr2 :: inline (actual_mi : [] MusicInstruction, expected_mi : [] MusicInstruction) {
	AssertEquals(expected_mi.count, actual_mi.count);
	for expected_instr, expected_index : expected_mi {
		actual_instr : MusicInstruction = ---;
		if expected_index < actual_mi.count {
			actual_instr = actual_mi[expected_index];
		} 
		TestInstr(expected_instr, actual_instr);
	}
}
}
/*I am leaving this here as this is another way of checking which will stop the test if the counts do not match.
It is a valid way of doing it, but we get less info than the above. That may be desirable though and this would
be an easy way to change it if needed. Leaving this here as a reminder in case for later.
*/
TestManyInstr :: inline (actual_mi : [] MusicInstruction, expected_mi : [] MusicInstruction) {
	equal_count : bool = AssertEquals(expected_mi.count, actual_mi.count);
	if equal_count for expected_instr : expected_mi {
		TestInstr(expected_instr, actual_mi[it_index], it_index);
	}
}

//TODO Why do we need instr_count, why cant we just take it from expected_mi.count?
TestNextManyInstr :: inline (instr_index : *int, cd : *CompilationData, expected_mi : [] MusicInstruction) {
	actual_mi := array_view(cd.all_music_instructions, instr_index.*, expected_mi.count);
	instr_index.* += expected_mi.count;
	TestManyInstr(actual_mi, expected_mi);
}


/*TODO Can separate each test now which would be cleaner for output and data overall.
We would only have slightly more code but we could group somehow. 
So then just 1 test per function. Or at least 1 more specific class of tests per function.
*/
Test_CompilerAsm :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;
	
	cd = CompileCode(cs,
#string DONE
main :: () {
#asm {
mov <ax,10>, [bx+2];
mov <ax,0.125>, [bx+-1];
//TODO Should we have count and then data or data and then count?
// mov <ax,10>, .[bx,2];
// mov <ax,10>, int.[bx,2];
// mov <ax,10>, float.[bx,2];
// mov <ax,10>, .[2,bx];
// mov <ax,10>, int.[2,bx];
// mov <ax,10>, float.[2,bx];
}
}
DONE,,unit_test_alloc);
	AssertEquals(0, cd.main_function_instr_index);
	TestManyInstr(cd.all_music_instructions, .[
		MakeMI(.mov, MusicMem(RegDef.ax,10), RamMem(.bx,2)),
		MakeMI(.mov, MusicMem(RegDef.ax,0.125), RamMem(.bx,-1)),
		MakeMI(.exit),
	]);



	cd = CompileCode(cs,
#string DONE
main :: () {
#asm { 
mov [ax + -40], -10;
}
}
DONE,,unit_test_alloc);
	TestManyInstr(cd.all_music_instructions, .[
		MakeMI(.mov, RamMem(.ax,-40), Imm(-10)),
		MakeMI(.exit),
	]);



//TODO Multiple instruction creation test with different instructions
//And also lexer test, then cleanup Assembler stuff so we remove
//superfluous and move old LexerToken stuff into thegame_data.
	cd = CompileCode(cs,
#string DONE
main :: () {
#asm { 
mov bx, 0;
mov <ax,0>, bx;
mov <ax,1.5>, bx;
or <ax,0>, 4;
or <1,0>, <ax,0>, 7;
}
}
DONE,,unit_test_alloc);
	TestManyInstr(cd.all_music_instructions, .[
		MakeMI(.mov, RegMem(.bx), Imm(0)),
		MakeMI(.mov, MusicMem(RegDef.ax,0), RegMem(.bx)),
		MakeMI(.mov, MusicMem(RegDef.ax,1.5), RegMem(.bx)),
		MakeMI(.or, MusicMem(RegDef.ax,0), Imm(4)),
		MakeMI(.or, MusicMem(1,0), MusicMem(RegDef.ax,0), Imm(7)),
		MakeMI(.exit),
	]);




//TODO Once we return an error then we write tests with errors.
//TODO Could allow for munit[][] to also be a way to access rows
#if 0 {
	cd = CompileCode(cs,
#string DONE
main :: () { #asm { 
mov ax, -1;
mov ax, size_of(u8) * 2;
mov ax, <ax + bx*3>;
mov ax, <[ax],[sbp]>;
mov ax, <ax,sbp>;
mov ax, <[ax],[sbp]>;
mov ax, {<ax>,<sbp>};
and {[ax+bx*2+40],[sbp]}, <0,1,2,3>;
//For now we do negative like this until we allow 
//bracketed constant expressions
and <[ax + bx*2 + -40],[sbp]>, {0,1,2,3};
and <[ax],[sbp]>, { [0],1,2,3 };
}}
DONE,,unit_test_alloc);
}
} @UnitTest

Test_AsmOpCodeLabel :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	
	cd = CompileCode(cs,
#string DONE
main :: () { #asm { 
mov.f ax, 10.5;
add.f bx, ax, 1.1;
mov.f cx, -3.1;
}}
DONE,,unit_test_alloc);

	TestManyInstr(cd.all_music_instructions, .[
		MakeFloatInstr(.mov, RegMem(.ax), FImm(10.5)),
		MakeFloatInstr(.add, RegMem(.bx), RegMem(.ax), FImm(1.1)),
		MakeFloatInstr(.mov, RegMem(.cx), FImm(-3.1)),
		MakeMI(.exit),
	]);

} @UnitTest

//TODO Check this code works for outer scope var tests
//Then can do RamArray and I think (count,data) is good since it
//seems to be the convention and it does not technically seem to matter.
//Also can change later if needed, although maybe a bit annoyingly.
Test_AsmVar :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	v : int = 10;
	#asm {
		mov ax, v;
	}

	f : float = 3.14;
	#asm {
		mov.f bx, f;
	}

	pi : *int = *v;
	#asm {
		mov cx, pi;
	}

	//TODO Can also set enum type in asm as well.
}
DONE,,unit_test_alloc);

	pi_info, found_pi_info := GetTypeInfoPointer(*cd.int_type_info, cd);
	AssertEquals(true, found_pi_info);
	if !found_pi_info return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("v", *cd.int_type_info),
		VarDecl("f", *cd.float_type_info),
		VarDecl("pi", pi_info),
	]);
	if !vars_equal return;

	v_var := cd.all_variables[0];
	f_var := cd.all_variables[1];
	pi_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, v_var.op, Imm(10), Imm(8)),
		MakeMI(.mov, RegMem(.ax), RamMem(.sbp,0))
	]);

	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, f_var.op, FImm(3.14), Imm(8)),
		FloatInstr(.mov, RegMem(.bx), RamMem(.sbp,8))
	]);

	v_0, v_1 := GetMemoryAddressAsOperands(v_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//*v
		MakeMI(.add, pi_var.op, v_0, v_1),
		//Optimized out since this is pi_var.op = [sbp+16]
		//pi : *int = *v;
		// MakeMI(.mov, pi_var.op, RamMem(.sbp,16), Imm(pi_var.t_info.runtime_size)),
		MakeMI(.mov, RegMem(.cx), pi_var.op),

		MakeMI(.exit),
	]);

} @UnitTest

Test_AsmIntrinsic :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

//NOTE : This example just checks that the type for asm is RamMem
//in the intrinsic but does not actually work with the muscall.
	cd = CompileCode(cs,
#string DONE
TestI :: (n : neume) {
  #asm {
    muscall 0, n;
  }
}
main :: () {
  n : neume;
  n.svara = 12.;
  TestI(n);
}
DONE,,unit_test_alloc);

	intrinsic_func, found_intrinsic := ArrayFindFirstByNameId(cd.all_function_declarations, "TestI", "name");
	AssertEquals(true, found_intrinsic);
	if !found_intrinsic return;

	var_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("n", *cd.neume_struct_info, RamMem(.sbp,0)),
		VarDecl("n", *cd.neume_struct_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;

	n_var := cd.all_variables[0];
	p_n_var := cd.all_variables[1];

	//TODO Need to get after library file index once we move the function
	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		// muscall 0, n;
		MakeMI(.muscall, Imm(0), p_n_var.op),
		MakeMI(.ret),
	]);
	TestNextManyInstr(*instr_index, cd, .[
	  	//smd : SetupMusicData;
		MakeMI(.mset, n_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
	  	// n.svara = 12.0;
		MakeMI(.mov, n_var.op, FImm(12.0), Imm(cd.float_type_info.runtime_size)),
	]);

	stack_p : int = cd.neume_struct_info.runtime_size;
	next_stack_p : int = PRE_PROC_STACK_SIZE + stack_p;
	neume_arg_op := RamMem(.sbp,next_stack_p);
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,stack_p)),
		//Push on neume argument
		MakeMI(.mov, neume_arg_op, n_var.op, Imm(cd.neume_struct_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(0)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		MakeMI(.exit),
	]);

} @UnitTest

//TODO FROM HERE Add RamArray and then do this test
//Need to make sure pointers and .data is working before we implement this
//OR should we just allow this in code and not asm
//Can see when we use it what feels necessary
Test_AsmVarArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	arr : [3] int;
	c : int = arr.count;
	d : *int = arr.data;
	// tano[0][0] = arr;
	// for arr tano[0][it_index] = it;
	#asm {
		mov <0,0>, int.[c,d];
	}
}
DONE,,unit_test_alloc);

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.push, Imm(10), Imm(8)),
		MakeMI(.mov, RegMem(.ax), RamMem(.sbp,0))
	]);

} //@UnitTest

//TODO Can split these out into separate unit test functions so their easier to check and manage.
//Each test will have a several assertions likely. Can still group a few together if they are related.
Test_Compiler :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

//TODO We want this working with proper instruction creation
	cd = CompileCode(cs,
#string DONE
main :: () { #asm { 
mov ax, 1;
}}
DONE,,unit_test_alloc);

	//TODO This is a full test, good to have some of these for small cases but better to test large cases as
	//full integration tests and make sure all the output is good after doing small tests for these.
	//TODO These tests should be in a Test_CompilerParser because Test_Compiler should be just testing instructions.
	//Although this is part of the compiler.
	AssertEquals(4, cd.all_code_statements.count);
	node : *BinaryNode = cd.all_code_statements[0].top_node;
	AssertEquals(CodeTokenType.DOUBLE_COLON, node.value.token_type);
	AssertNotEquals(null, node.left);
	AssertEquals(CodeTokenType.IDENT, NoNull(node.left).value.token_type);
	AssertEquals("main", NoNull(node.left).value.token_string);
	AssertNotEquals(null, node.right);
	AssertEquals(cast(CodeTokenType) #char ")", NoNull(node.right).value.token_type);

	node = cd.all_code_statements[1].top_node;
	AssertEquals(cast(CodeTokenType) #char "#", node.value.token_type);
	AssertEquals(CodeDirective.asm, cast(CodeDirective) node.value.int_value);

	node = cd.all_code_statements[2].top_node;
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);

	node = cd.all_code_statements[3].top_node;
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);

	TestManyInstr(cd.all_music_instructions, .[
		MakeMI(.mov, RegMem(.ax), Imm(1)),
		MakeMI(.exit),
	]);




//TODO I think passing in unit_test_alloc whenever we need it is better
//so then we can also use an external allocator through context.allocator
//if needed for things like assertion logs and maybe other things.
	cd = CompileCode(cs,
#string DONE
main :: () {
	x : int = 0;
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(1, cd.all_function_declarations.count);
	if count_equal {
		AssertEquals("main", cd.all_function_declarations[0].name);
	}

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(8)),
		MakeMI(.exit),
	]);


//TODO This test is not working on creating an expression
//binary tree for "main :: ()"?!? It messes up CURRENT_TEST_RESULTS...
//Not sure why, everything else seems to be working...
//Even the one below runs... weird case maybe because we 
//just have a funtion call on a line, I did not consider that case yet
//now it works...
#if 1 {
	cd = CompileCode(cs,
#string DONE
foo :: (x : int) {
}
main :: () {
	foo(3);
}
DONE,,unit_test_alloc);
}


//TODO Removed this test as we are working on functions right now but we can put back once we do
//although I should have a separate test with all these cases anyways.
#if 0 {
	cd = CompileCode(cs,
#string DONE
foo :: (x : int) -> int {
	return x + 1;
}

main :: () {
	x : int = 0;
	y : int = foo(x);
}
DONE,,unit_test_alloc);

}

	/*TODO ALL THE TEST BELOW SHOULD BE USED TO TEST FOR PARSING AND INSTRUCTIONS
	Can make a Test_CompilerParser test and Test_CompilerInstr test to separate those
	for more complicated cases
	*/

	//TODO Remove this from this test since we should only compiling data
	cl := MakeCodeLexer();

//TODO Either we have functions parsed all separately in an array
//or we need to somehow put the contents of main function at the top
//of the assembly instructions.

	//Test if statement
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
main :: () {
	x : int = 2;
	x = x + 1;
	if x > 2 {
		x = 1;
	}
}
DONE,,unit_test_alloc);

	// CompileCodeTree(cl);

	//TODO Test assignment and expression
	//TODO Test else if and else
	//TODO while and for loop
	//TODO Then test rows
	// munit[0][0] = int.[0,4,7];
	//TODO Then functions
	//TODO structs? enums? 
	//TODO non-music arrays? do we need pointers then?


	//Test while loop
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
main :: () {
	x : int = 2;
	while x < 10 {
		x = x + 1;
	}
}
DONE,,unit_test_alloc);

	// CompileCodeTree(cl);


	//Test for loop
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
main :: () {
	x : int;
	for 0..10 {
		x = x + 1;
	}
}
DONE,,unit_test_alloc);

	// CompileCodeTree(cl);


	//TODO rows test with for loop
	//rows test
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
main :: () {
	// munit[0][0] = 5;
	munit[0][1] = int.[0,4,7];
}
DONE,,unit_test_alloc);

	// cd = CompileCodeTree(cl);


	//pointer test
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
main :: () {
	x : int = 1;
	y : *int = *x[0];
	*x.a
}
DONE,,unit_test_alloc);

	// CompileCodeTree(cl);

	//function call test
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
foo :: (x : int) -> int {
	y : int = x + 1;
	return y;
}
main :: () {
	i : int = foo(2);
}
DONE,,unit_test_alloc);

	// CompileCodeTree(cl);

	//multi-return function call test
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
foo :: (x : int) -> int, int {
	y : int = x + 1;
	return y, y+1;
}
main :: () {
	i,j := foo(2);
}
DONE,,unit_test_alloc);

	// CompileCodeTree(cl);
} @UnitTest

//TODO FROM HERE DEREFERENCE POINTER THEN STRUCT MEMBER POINTER
//LIKELY DO STRUCT MEMBER DEREFERENCE FIRST. Can do 
//auto-dereference for pointer struct member access later maybe.
//And struct member array access (likely have to implement
//arrays here can do fixed array and array view first)
//---> AND THEN ARRAY ACCESS FOR ARRAY AND POINTER
//Check if they have anything in common code-wise
//Then can check if it all works for functions.
//TODO Need to add CompilerError at some point so we can
//start building those up and stop having assertions everywhere.
//TODO Also eventually need to do heap memory and resizable array with that.
//That may include alloc, free and realloc instructions
//with a free list to reduce memory fragmentation.
//Can also try virtual addressing eventually to completely remove
//fragmentation but that may introduce other issues with pointers
//like having to update them and also that the pointers the user sees
//are not in fact the actual physical pointer addresses which may
//not matter ultimately with the debugger... not sure...
//TODO ALSO ADD ALL VARIABLES and add that to tests so we can
//make sure compilation variable info is correct
//and then later use that info for debug info in particular

Test_CompileBool :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	b : bool;
	bt : bool = true;
	bf : bool = false;
}
DONE,, unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("b", *cd.bool_type_info),
		VarDecl("bt", *cd.bool_type_info),
		VarDecl("bf", *cd.bool_type_info)
	]);
	if !vars_equal return;
	b_var := cd.all_variables[0];
	bt_var := cd.all_variables[1];
	bf_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//Initialize b : bool
		MakeMI(.mset, b_var.op, Imm(0), Imm(b_var.t_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//Initialize bt : bool = true
		MakeMI(.mov, bt_var.op, Imm(1), Imm(bt_var.t_info.runtime_size)),
		//Initialize bf : bool = false
		MakeMI(.mov, bf_var.op, Imm(0), Imm(bf_var.t_info.runtime_size)),
		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

//TODO FROM HERE write an integration making sure the
//values here are correct and also add a test for division
//and then do array access and for loops and ifs
Test_CompLogic :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
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
DONE,, unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("bt", *cd.bool_type_info),
		VarDecl("bf", *cd.bool_type_info),
		VarDecl("b", *cd.bool_type_info),
		VarDecl("i", *cd.int_type_info),
		VarDecl("x", *cd.int_type_info)
	]);
	if !vars_equal return;
	bt_var := cd.all_variables[0];
	bf_var := cd.all_variables[1];
	b_var := cd.all_variables[2];
	i_var := cd.all_variables[3];
	x_var := cd.all_variables[4];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//Initialize bt : bool = true
		MakeMI(.mov, bt_var.op, Imm(1), Imm(bt_var.t_info.runtime_size))
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//Initialize bf : bool = false
		MakeMI(.mov, bf_var.op, Imm(0), Imm(bf_var.t_info.runtime_size))
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//bt || bf
		MakeMI(.or, b_var.op, bt_var.op, bf_var.op),

		//bt && bf
		MakeMI(.and, AddOperandOffset(8, b_var.op), bt_var.op, bf_var.op),
		MakeMI(.mov, b_var.op, AddOperandOffset(8, b_var.op), Imm(cd.bool_type_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//Initialize i : int = 1
		MakeMI(.mov, i_var.op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		//Initialize x : int = 3
		MakeMI(.mov, x_var.op, Imm(3), Imm(cd.int_type_info.runtime_size))
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//i < x
		MakeMI(.clt, AddOperandOffset(8, x_var.op), i_var.op, x_var.op),
		MakeMI(.mov, b_var.op, AddOperandOffset(8, x_var.op), Imm(cd.bool_type_info.runtime_size)),

		//i <= x
		MakeMI(.clte, AddOperandOffset(8, x_var.op), i_var.op, x_var.op),
		MakeMI(.mov, b_var.op, AddOperandOffset(8, x_var.op), Imm(cd.bool_type_info.runtime_size)),

		//i > x
		MakeMI(.cgt, AddOperandOffset(8, x_var.op), i_var.op, x_var.op),
		MakeMI(.mov, b_var.op, AddOperandOffset(8, x_var.op), Imm(cd.bool_type_info.runtime_size)),

		//i >= x
		MakeMI(.cgte, AddOperandOffset(8, x_var.op), i_var.op, x_var.op),
		MakeMI(.mov, b_var.op, AddOperandOffset(8, x_var.op), Imm(cd.bool_type_info.runtime_size)),

		//i == x
		MakeMI(.ceq, AddOperandOffset(8, x_var.op), i_var.op, x_var.op),
		MakeMI(.mov, b_var.op, AddOperandOffset(8, x_var.op), Imm(cd.bool_type_info.runtime_size)),

		//i != x
		MakeMI(.cneq, AddOperandOffset(8, x_var.op), i_var.op, x_var.op),
		MakeMI(.mov, b_var.op, AddOperandOffset(8, x_var.op), Imm(cd.bool_type_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CompOpEquals :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
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
DONE,, unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("x", *cd.int_type_info),
		VarDecl("i", *cd.int_type_info),
		VarDecl("xf", *cd.float_type_info),
		VarDecl("f", *cd.float_type_info),
	]);
	if !vars_equal return;
	x_var := cd.all_variables[0];
	i_var := cd.all_variables[1];
	xf_var := cd.all_variables[2];
	f_var := cd.all_variables[3];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//x : int = 3;
		MakeMI(.mov, x_var.op, Imm(3), Imm(x_var.t_info.runtime_size)),
		//i : int = 0;
		MakeMI(.mov, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),
		//i += x;
		MakeMI(.add, i_var.op, x_var.op),
		//i -= 1;
		MakeMI(.sub, i_var.op, Imm(1)),
		//i /= 1;
		MakeMI(.div, i_var.op, Imm(2)),
		//i *= 4;
		MakeMI(.mul, i_var.op, Imm(4)),
		//i %= 4;
		MakeMI(.mod, i_var.op, Imm(4)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//xf : float = 3.0;
		MakeMI(.mov, xf_var.op, FImm(3), Imm(xf_var.t_info.runtime_size)),
		//f : float = 0;
		MakeMI(.mov, f_var.op, FImm(0), Imm(f_var.t_info.runtime_size)),
		//f += xf;
		MakeFloatInstr(.add, f_var.op, xf_var.op),
		//f -= 1;
		MakeFloatInstr(.sub, f_var.op, FImm(1)),
		//f /= 1;
		MakeFloatInstr(.div, f_var.op, FImm(2)),
		//f *= 4;
		MakeFloatInstr(.mul, f_var.op, FImm(4)),
		//f %= 4;
		MakeFloatInstr(.mod, f_var.op, FImm(4)),

		MakeMI(.exit)
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CompileFloat :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	f : float;
	x : float = 13.141;
	y : float = x;
}
DONE,, unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("f", *cd.float_type_info),
		VarDecl("x", *cd.float_type_info),
		VarDecl("y", *cd.float_type_info),
	]);
	if !vars_equal return;
	f_var := cd.all_variables[0];
	x_var := cd.all_variables[1];
	y_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//f : float;
		MakeMI(.mset, f_var.op, Imm(0), Imm(f_var.t_info.runtime_size)),
	]);

	//Note : .push does not need to be a float instruction since .push is just a .mov with single values
	//and so the MemoryValue is always moved anyways.
	TestNextManyInstr(*instr_index, cd, .[
		//x : float = 13.141;
		MakeMI(.mov, x_var.op, FImm(13.141), Imm(x_var.t_info.runtime_size))
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//y : float = x;
		MakeMI(.mov, y_var.op, x_var.op, Imm(x_var.t_info.runtime_size)),
		MakeMI(.exit)
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CompNeg :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : int = -10;
	i = --10;
	i = -++-++-10;

	f : float = -3.14;
	f = --3.14;

	x : int = 15;
	i = -x;
	i = --x;
	i = -+-+-x;
}
DONE,, unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", *cd.int_type_info),
		VarDecl("f", *cd.float_type_info),
		VarDecl("x", *cd.int_type_info),
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];
	f_var := cd.all_variables[1];
	x_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//i : int = -10;
		MakeMI(.mov, i_var.op, Imm(-10), Imm(cd.int_type_info.runtime_size)),
		//i = --10;
		MakeMI(.mov, i_var.op, Imm(10), Imm(cd.int_type_info.runtime_size)),
		//i = -++-++-10;
		MakeMI(.mov, i_var.op, Imm(-10), Imm(cd.int_type_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//f : float = -3.14;
		MakeMI(.mov, f_var.op, FImm(-3.14), Imm(cd.float_type_info.runtime_size)),
		//f = --3.14;
		MakeMI(.mov, f_var.op, FImm(3.14), Imm(cd.float_type_info.runtime_size)),
	]);

	stack_i : int = 24;
	TestNextManyInstr(*instr_index, cd, .[
		//f : float = -3.14;
		MakeMI(.mov, x_var.op, Imm(15), Imm(cd.int_type_info.runtime_size)),
		//i = -x;
		MakeMI(.sub, RamMem(.sbp,stack_i), Imm(0), x_var.op),
		MakeMI(.mov, i_var.op, RamMem(.sbp,stack_i), Imm(cd.int_type_info.runtime_size)),
		//i = --x;
		MakeMI(.sub, RamMem(.sbp,stack_i), Imm(0), x_var.op),
		MakeMI(.sub, RamMem(.sbp,stack_i+8), Imm(0), RamMem(.sbp,stack_i)),
		MakeMI(.mov, i_var.op, RamMem(.sbp,stack_i+8), Imm(cd.int_type_info.runtime_size)),
		//i = -+-+-x;
		MakeMI(.sub, RamMem(.sbp,stack_i), Imm(0), x_var.op),
		MakeMI(.sub, RamMem(.sbp,stack_i+8), Imm(0), RamMem(.sbp,stack_i)),
		MakeMI(.sub, RamMem(.sbp,stack_i+16), Imm(0), RamMem(.sbp,stack_i+8)),
		MakeMI(.mov, i_var.op, RamMem(.sbp,stack_i+16), Imm(cd.int_type_info.runtime_size)),

		MakeMI(.exit),
	]);


	AssertEquals(instr_index, cd.all_music_instructions.count);

//TODO Check that we fail for a negative invalid type here

} @UnitTest

Test_ParseString :: () {
	ptd := MakeParseTestData();

	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "s : string = \"test\";");
	/*
			   =
			/    \
		  :    "test"
		 / \
	   s  string
	*/
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "s")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_STRING, "string")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.STRING, "test")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

} @UnitTest

Test_CompileString :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	s1 := "test";
	s2 := "t2";
	cd = CompileCode(cs,
sprint(
#string DONE
main :: () {
	s : string = "%";
	sc : int = s.count;
	s_copy := s;

	t : test;
	t.s = "%";
}
test :: struct {
	s : string;
}
DONE, s1, s2,, unit_test_alloc)
,,unit_test_alloc);

	t_info, found_t_info := GetTypeInfoStructByName("test", cd.all_type_info_struct);
	AssertEquals(true, found_t_info);
	if !found_t_info return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("s", *cd.string_type_info),
		VarDecl("sc", *cd.int_type_info),
		VarDecl("s_copy", *cd.string_type_info),
		VarDecl("t", t_info),
	]);
	if !vars_equal return;
	s_var := cd.all_variables[0];
	sc_var := cd.all_variables[1];
	s_copy_var := cd.all_variables[2];
	t_var := cd.all_variables[3];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//s.count = 4
		MakeMI(.mov, RamMem(.sbp,0), Imm(s1.count), Imm(cd.int_type_info.runtime_size)),
		//alloc s.data
		//TODO We should not be storing constant strings on the heap since we will lose them
		//unless we store at the beginning of the heap and copy there at the beginning
		//and then access it with .const or .hp
		MakeMI(.alloc, Imm(s1.count), RamMem(.sbp,8)),

		MakeMI(.mov, RegMem(.ax), RamMem(.sbp,8), Imm(cd.void_pointer_type_info.runtime_size)),
		MakeMI(.const_mov, RamMem(.ax), Imm(0), Imm(s1.count)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//sc : int = s.count;
		MakeMI(.mov, sc_var.op, s_var.op, Imm(cd.int_type_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//s_copy := s;
		MakeMI(.mov, s_copy_var.op, s_var.op, Imm(cd.string_type_info.runtime_size)),
	]);

	stack_p : int;
	for cd.all_variables stack_p += it.t_info.runtime_size;
	t2_string_op := RamMem(.sbp, stack_p);
	t2_string_data_op := AddOperandOffset(8, t2_string_op);
	TestNextManyInstr(*instr_index, cd, .[
		//t : test;
		MakeMI(.mset, t_var.op, Imm(0), Imm(cd.string_type_info.runtime_size)),
		//"t2"
		MakeMI(.mov, t2_string_op, Imm(s2.count), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.alloc, Imm(s2.count), t2_string_data_op),
		MakeMI(.mov, RegMem(.ax), t2_string_data_op, Imm(cd.void_pointer_type_info.runtime_size)),
		MakeMI(.const_mov, RamMem(.ax), Imm(s1.count), Imm(s2.count)),
		//t.s = s;
		MakeMI(.mov, t_var.op, t2_string_op, Imm(cd.string_type_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CompFloatArithmetic :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	f : float;
	x : float = f + 1.5;
}
DONE,, unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("f", *cd.float_type_info),
		VarDecl("x", *cd.float_type_info),
	]);
	if !vars_equal return;
	f_var := cd.all_variables[0];
	x_var := cd.all_variables[1];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//f : float;
		MakeMI(.mset, f_var.op, Imm(0), Imm(f_var.t_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//x : float = f + 1.5;
		MakeFloatInstr(.add, x_var.op, f_var.op, FImm(1.5)),
		//Optimized out
		// MakeMI(.mov, x_var.op, RegMem(.ax), Imm(x_var.t_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_Inline :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : int;
	if i == 0 i = 1;
	for 1..10 if i == 0 while i < 1 i = 1;
}
DONE,, unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", *cd.int_type_info, scope_index=1),
		VarDecl("it", *cd.int_type_info, scope_index=2)
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];
	it_var := cd.all_variables[1];

	instr_index : int = 0;
	//i : int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//if i == 0
		MakeMI(.ceq, RamMem(.sbp,8), i_var.op, Imm(0)),
		MakeMI(.fjmp, Imm(instr_index+3), RamMem(.sbp,8)),
		//i = 1
		MakeMI(.mov, i_var.op, Imm(1), Imm(i_var.t_info.runtime_size)),
	]);

	//To reset the scope till the for loop. So the last reset will reset till i_var instead
	reset_scope_int : int = i_var.t_info.runtime_size+it_var.t_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//for 1..10
		MakeMI(.clte, RegMem(.ax), it_var.op, Imm(10)),
		MakeMI(.fjmp, Imm(instr_index+10), RegMem(.ax)),

		//if i == 0
		MakeMI(.ceq, RamMem(.sbp,16), i_var.op, Imm(0)),
		MakeMI(.fjmp, Imm(instr_index+8), RamMem(.sbp,16)),

		//while i < 1
		MakeMI(.clt, RamMem(.sbp,24), i_var.op, Imm(1)),
		MakeMI(.fjmp, Imm(instr_index+8), RamMem(.sbp,24)),

		//i = 1
		MakeMI(.mov, i_var.op, Imm(1), Imm(i_var.t_info.runtime_size)),

		//End while scope
		MakeMI(.jmp, Imm(instr_index+4)),

		//post for loop instructions
		MakeMI(.add, it_var.op, Imm(1)),
		MakeMI(.jmp, Imm(instr_index)),

		MakeMI(.exit),
	]);


	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_MultiControl :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : int;
	for x : 1..10 if i == 0 while i < 1 {
		i = x;
	}

	//Bit of a complicated unit test. Good to have, might not be fun to update later...
	a : [2] int;
	if i == 1 for < x,y : a {
		i = y;
		i = 0;
	}
}
DONE,, unit_test_alloc);

	var_index : int;
	vars_equal : bool = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("i", *cd.int_type_info, RamMem(.sbp,0), 1),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,8), 2),
		VarDecl("a", cd.all_type_info_array[0], RamMem(.sbp,8), 1),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,32), 3),
		VarDecl("y", *cd.int_type_info, RamMem(.sbp,40), 3),
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];
	x_var := cd.all_variables[1];
	a_var := cd.all_variables[2];
	it_rev_var := cd.all_variables[3];
	index_rev_var := cd.all_variables[4];


	instr_index : int = 0;
	//i : int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),
	]);

	reset_scope_int : int = i_var.t_info.runtime_size+x_var.t_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//for x : 0..10
		MakeMI(.clte, RegMem(.ax), x_var.op, Imm(10)),
		MakeMI(.fjmp, Imm(instr_index+10), RegMem(.ax)),

		//if i == 0
		MakeMI(.ceq, RamMem(.sbp,16), i_var.op, Imm(0)),
		MakeMI(.fjmp, Imm(instr_index+8), RamMem(.sbp,16)),

		//while i < 1
		MakeMI(.clt, RamMem(.sbp,24), i_var.op, Imm(1)),
		MakeMI(.fjmp, Imm(instr_index+8), RamMem(.sbp,24)),

		//i = 1
		MakeMI(.mov, i_var.op, x_var.op, Imm(i_var.t_info.runtime_size)),

		//End while scope
		MakeMI(.jmp, Imm(instr_index+4)),

		//post for loop instructions
		MakeMI(.add, x_var.op, Imm(1)),
		MakeMI(.jmp, Imm(instr_index)),
	]);


	//a : [2] int;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, a_var.op, Imm(0), Imm(a_var.t_info.runtime_size)),
	]);

	//TODO Could add scope checks to this as well.
	TestNextManyInstr(*instr_index, cd, .[
		//if i == 0
		MakeMI(.ceq, RamMem(.sbp,24), i_var.op, Imm(1)),
		MakeMI(.fjmp, Imm(instr_index+12), RamMem(.sbp,24)),

		//for < x,y : a {}
		//< for loop setup instruction
		MakeMI(.sub, index_rev_var.op, Imm(cd.all_type_info_array[0].array_count), Imm(1)),
		//For loop top instructions
		MakeMI(.cgte, RegMem(.ax), index_rev_var.op, Imm(0)),
		MakeMI(.fjmp, Imm(instr_index + 12), RegMem(.ax)),
		MakeMI(.mul, RegMem(.ax), index_rev_var.op, Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, RegMem(.ax), a_var.op, RegMem(.ax)),
		MakeMI(.mov, it_rev_var.op, RamMem(.ax), Imm(cd.all_type_info_array[0].element_type.runtime_size)),			

		//i = y
		MakeMI(.mov, i_var.op, index_rev_var.op, Imm(i_var.t_info.runtime_size)),
		//i = 0
		MakeMI(.mov, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),

		//Close rev for loop
		MakeMI(.sub, index_rev_var.op, Imm(1)),
		// MakeMI(.sub, it_rev_var.op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.jmp, Imm(instr_index + 3)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_IfElseInline :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : int;
	if i == 0 i = 0;
	else if i == 2 i = 1;
	else i = 2;
}
DONE,, unit_test_alloc);

	scope_count := AssertEquals(5, cd.all_scope_data.count);
	if_scope : ScopeData;
	else_if_scope : ScopeData;
	else_scope : ScopeData;
	if scope_count {
		//0 and 1 are global and main scope
		if_scope = cd.all_scope_data[2];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, if_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_IF, if_scope.scope_token.token_type);

		else_if_scope = cd.all_scope_data[3];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, else_if_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_ELSE, else_if_scope.scope_token.token_type);

		else_scope = cd.all_scope_data[4];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, else_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_ELSE, else_scope.scope_token.token_type);
	}

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", *cd.int_type_info)]);
	if !vars_equal return;
	i_var := cd.all_variables[0];

	instr_index : int = 0;
	//i : int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),
	]);

	AssertEquals(instr_index+2, if_scope.start_instr_index);
	AssertEquals(instr_index+3, if_scope.end_instr_index);
	//if i == 0 i = 0;
	end_if_index : int = cd.all_music_instructions.count-1;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.ceq, RamMem(.sbp,8), i_var.op, Imm(0)),
		MakeMI(.fjmp, Imm(instr_index+4), RamMem(.sbp,8)),
		MakeMI(.mov, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),
		MakeMI(.jmp, Imm(end_if_index)),
	]);

	AssertEquals(instr_index+2, else_if_scope.start_instr_index);
	AssertEquals(instr_index+3, else_if_scope.end_instr_index);
	//else if i == 2 i = 1;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.ceq, RamMem(.sbp,8), i_var.op, Imm(2)),
		MakeMI(.fjmp, Imm(instr_index+4), RamMem(.sbp,8)),
		MakeMI(.mov, i_var.op, Imm(1), Imm(i_var.t_info.runtime_size)),
		MakeMI(.jmp, Imm(end_if_index)),
	]);

	AssertEquals(instr_index, else_scope.start_instr_index);
	AssertEquals(instr_index, else_scope.end_instr_index);
	//else i = 2;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, i_var.op, Imm(2), Imm(i_var.t_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

//TODO Also test inline statements
//Then also do tests with code in the scope to make sure
//that works even just 1 line maybe also with variable assignment
Test_IfElse :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : int;
	if i == 0 {}
	else if i == 2 {}
	else {}
}
DONE,, unit_test_alloc);

	//TODO PULL THIS OUT And have a separate scope test just for scopes
	//so we can have them all in one place.
	//Can test inline scopes in a separate one or in inline statements.
	//This way we have a clean scope test that more or less just tests scopes.
	//TODO I am putting this test here for convenience but maybe we should have a separate test for scope
	//Or we could put these down so that we can adjust the instr_index based on where the instructions
	//are being checked. I think a separate test might be best. ALSO need to check scope for all control scopes.
	scope_count := AssertEquals(4, cd.all_scope_data.count);
	if_scope : ScopeData;
	else_if_scope : ScopeData;
	if scope_count {
		//0 and 1 are global and main scope
		if_scope = cd.all_scope_data[2];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, if_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_IF, if_scope.scope_token.token_type);

		else_if_scope = cd.all_scope_data[3];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, else_if_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_ELSE, else_if_scope.scope_token.token_type);

		//NOTE : We don't add the else scope when it is empty because
		//there are no asm instructions so this could cause issues
		//if we have a scope right after the else as the scopes would overlap
		//eg if {} else {} for x {}
		// else_scope := cd.all_scope_data[4];
	}

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", *cd.int_type_info)]);
	if !vars_equal return;
	i_var := cd.all_variables[0];

	instr_index : int = 0;
	//i : int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),
	]);

	AssertEquals(instr_index+2, if_scope.start_instr_index);
	AssertEquals(instr_index+2, if_scope.end_instr_index);
	if_end_index : int = cd.all_music_instructions.count-1;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.ceq, RamMem(.sbp,8), i_var.op, Imm(0)),
		MakeMI(.fjmp, Imm(4), RamMem(.sbp,8)),
		MakeMI(.jmp, Imm(if_end_index)),
	]);

	AssertEquals(instr_index+2, else_if_scope.start_instr_index);
	AssertEquals(instr_index+2, else_if_scope.end_instr_index);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.ceq, RamMem(.sbp,8), i_var.op, Imm(2)),
		MakeMI(.fjmp, Imm(7), RamMem(.sbp,8)),
		MakeMI(.jmp, Imm(if_end_index)),
	]);

	//TODO Leaving this separate to remind us that we have no else scope
	TestNextManyInstr(*instr_index, cd, .[

		MakeMI(.exit),
	]);


	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_WhileLoop :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : int;
	while i < 10 {}
}
DONE,, unit_test_alloc);

	scope_count := AssertEquals(3, cd.all_scope_data.count);
	while_scope : ScopeData;
	if scope_count {
		while_scope = cd.all_scope_data[2];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, while_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_WHILE, while_scope.scope_token.token_type);
	}

	vars_equal : bool;
	vars_equal = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", *cd.int_type_info)
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];

	instr_index : int = 0;
	//i : int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),
	]);

	//Empty while scope is 3 instructions
	AssertEquals(instr_index, while_scope.start_instr_index);
	AssertEquals(instr_index+2, while_scope.end_instr_index);
	//start scope while i < 10
	loop_start_index := instr_index;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.clt, RamMem(.sbp,8), i_var.op, Imm(10)),
		MakeMI(.fjmp, Imm(4), RamMem(.sbp,8)),
		//End while scope
		MakeMI(.jmp, Imm(loop_start_index)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);
	
} @UnitTest

//TODO Also test 2d loops
//TODO Also maybe test some failure cases with Parser errors
//and CompilerError
Test_ForLoopRange :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {
	for 1..10 {}
	for < 1..10 {}

	a : int = 1;
	b : int = 5;
	for x : a..b {}


	// for y : 0..1 for x : 0..10 {
	// 	tano[y+1,x] = tano[y,x] + 4;
	// }
	/*
	IDEA Could have tano[0,a..b] be a MusicSection
	so we could create it as a struct but also loop over it
	for t, t_index : tano[0,a..b]
	as a multi loop for each note of each section
	for t:tano[r,a..b] for t
	and then with row something like
	BUT A ROW IS A SECTION tano[0,0..row.count-1]
	for r:0..5 for t:tano[r,a..b] for t
	BUT COULD ALSO DO
	for x:0..5 for t:tano[0,x] for t
	SO ADDING THE RANGE for tano[r1..r2,x1..x2] would be more
	like adding nested loops which is possible and may be worth it eventually
	*/
}
DONE,, unit_test_alloc);

	scope_count := AssertEquals(5, cd.all_scope_data.count);
	for_scope : ScopeData;
	for_rev_scope : ScopeData;
	for_var_scope : ScopeData;
	if scope_count {
		//0 and 1 are global and main scope
		for_scope = cd.all_scope_data[2];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);

		for_rev_scope = cd.all_scope_data[3];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, for_rev_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_FOR, for_rev_scope.scope_token.token_type);

		for_var_scope = cd.all_scope_data[4];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, for_var_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_FOR, for_var_scope.scope_token.token_type);
	}

	vars_equal : bool;
	var_index : int;
	vars_equal = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("it", *cd.int_type_info, RamMem(.sbp,0), 2),
		VarDecl("it", *cd.int_type_info, RamMem(.sbp,0), 2),
		VarDecl("a", *cd.int_type_info, RamMem(.sbp,0), 1),
		VarDecl("b", *cd.int_type_info, RamMem(.sbp,8), 1),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,16), 2)
	]);
	if !vars_equal return;
	it_var := cd.all_variables[0];
	it_rev_var := cd.all_variables[1];
	a_var := cd.all_variables[2];
	b_var := cd.all_variables[3];
	x_var := cd.all_variables[4];

	instr_index : int = 0;

	AssertEquals(instr_index, for_scope.start_instr_index);
	AssertEquals(instr_index+3, for_scope.end_instr_index);
	//TODO Should we make a function to check for loops for this?
	//starting loop instructions
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.clte, RegMem(.ax), it_var.op, Imm(10)),
		MakeMI(.fjmp, Imm(instr_index+4), RegMem(.ax)),
		//post loop instructions
		MakeMI(.add, it_var.op, Imm(1)),
		MakeMI(.jmp, Imm(0)),
	]);

	AssertEquals(instr_index, for_rev_scope.start_instr_index);
	AssertEquals(instr_index+3, for_rev_scope.end_instr_index);
	//TODO Can split the pre and post instrs if we want to test instructions in between the loop
	//Reverse loop for < 1..10 {}
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.cgte, RegMem(.ax), it_rev_var.op, Imm(1)),
		MakeMI(.fjmp, Imm(instr_index+4), RegMem(.ax)),
		//post loop instructions
		MakeMI(.sub, it_rev_var.op, Imm(1)),
		MakeMI(.jmp, Imm(4)),
	]);


	TestNextManyInstr(*instr_index, cd, .[
		//a : int = 1;
		MakeMI(.mov, a_var.op, Imm(1), Imm(8)),
		//b : int = 5;
		MakeMI(.mov, b_var.op, Imm(5), Imm(8)),
	]);

	AssertEquals(instr_index, for_var_scope.start_instr_index);
	AssertEquals(instr_index+3, for_var_scope.end_instr_index);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.clte, RegMem(.ax), x_var.op, b_var.op),
		MakeMI(.fjmp, Imm(instr_index+4), RegMem(.ax)),
		//post loop instructions
		MakeMI(.add, x_var.op, Imm(1)),
		MakeMI(.jmp, Imm(instr_index)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

//TODO Need to account for having variables that are not in functions
//Then also update stack vars to all do push before functions.
//What about #asm for scope on if/for/while and maybe also functions
//so that functions with asm can be intrinsics
/*TODO I THINK IF A VARIABLE IS NOT IN A FUNCTION THEN THERE SHOULD BE NO CODE ASSOCIATED TO IT.
WE WOULD JUST SET THE VALUE AT COMPILE TIME AND THEN CAN SET IT IN A SCOPE IF IT IS NOT CONSTANT.
YES This way we can declare variables on GLOBAL SCOPE and then set them in functions.
Can check this on the second pass for example.
*/
Test_GlobalScope :: () {
	cs : CompileSettings;
	cd : *CompilationData;

/*TODO Should we only allow constant declarations for
global variables or also non-constant values?
*/
	cd = CompileCode(cs,
#string DONE
i : int;
main :: () {
}
x : int = 1;
DONE,, unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", *cd.int_type_info, scope_index=0),
		VarDecl("x", *cd.int_type_info, scope_index=0)
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];
	x_var := cd.all_variables[1];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//Initialize i : int
		MakeMI(.mset, i_var.op, Imm(0), Imm(i_var.t_info.runtime_size)),

		MakeMI(.exit),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//x : int = 1
		MakeMI(.mov, x_var.op, Imm(1), Imm(x_var.t_info.runtime_size)),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

/*TODO I think maybe best to split out all these tests since
we should do them for array view and resizable array eventually
as well for each for loop possibility once we implement all those as well.
So Maybe 1 test for fixed and 1 for view and 1 for resizable.
Maybe 1 for music if we allow that in for loop eventually
although maybe best to just have them convert it to array

Can also check everything is set properly through parser with ForLoopData
*/
Test_ForLoopArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;

//TODO Maybe it's better to separate all these cases out so
//we can more easily manage the tests. Especially once we do this
//for each version and each array type.
	cd = CompileCode(cs,
#string DONE
main :: () {
	a : [2] int;
	for a {}
	for < a {}
	for * a {}
	for * < a {}

	//Array view with named variables
	v : [] int = a;
	for val,idx : v {}
	//TODO inverse with vars
	// for < val,idx : v {}
	//TODO Could also add for loop pointer tests here
	//to make sure that's working once we implement it
}
DONE,, unit_test_alloc);

	scope_count := AssertEquals(7, cd.all_scope_data.count);
	for_scope : ScopeData;
	for_rev_scope : ScopeData;
	for_p_scope : ScopeData;
	for_p_rev_scope : ScopeData;
	for_var_scope : ScopeData;
	if scope_count {
		//0 and 1 are global and main scope
		for_scope = cd.all_scope_data[2];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, for_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_FOR, for_scope.scope_token.token_type);

		for_rev_scope = cd.all_scope_data[3];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, for_rev_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_FOR, for_rev_scope.scope_token.token_type);

		for_p_scope = cd.all_scope_data[4];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, for_p_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_FOR, for_p_scope.scope_token.token_type);

		for_p_rev_scope = cd.all_scope_data[5];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, for_p_rev_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_FOR, for_p_rev_scope.scope_token.token_type);

		for_var_scope = cd.all_scope_data[6];
		AssertEquals(ScopeDataType.CONTROL_SCOPE, for_var_scope.scope_type);
		AssertEquals(CodeTokenType.KEYWORD_FOR, for_var_scope.scope_token.token_type);
	}

	int_p_t_info, found_int_p := GetTypeInfoPointer(*cd.int_type_info, cd);
	AssertEquals(true, found_int_p);

	var_index : int;
	vars_equal : bool = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("a", cd.all_type_info_array[0], RamMem(.sbp,0), 1),
		VarDecl("it", *cd.int_type_info, RamMem(.sbp,16), 2),
		VarDecl("it_index", *cd.int_type_info, RamMem(.sbp,24), 2),
		VarDecl("it", *cd.int_type_info, RamMem(.sbp,16), 2),
		VarDecl("it_index", *cd.int_type_info, RamMem(.sbp,24), 2),
		VarDecl("it", int_p_t_info, RamMem(.sbp,16), 2),
		VarDecl("it_index", *cd.int_type_info, RamMem(.sbp,24), 2),
		VarDecl("it", int_p_t_info, RamMem(.sbp,16), 2),
		VarDecl("it_index", *cd.int_type_info, RamMem(.sbp,24), 2),
		VarDecl("v", cd.all_type_info_array[1], RamMem(.sbp,16), 1),
		VarDecl("val", *cd.int_type_info, RamMem(.sbp,32), 2),
		VarDecl("idx", *cd.int_type_info, RamMem(.sbp,40), 2)
	]);
	if !vars_equal return;
	a_var := cd.all_variables[0];
	it_var := cd.all_variables[1];
	it_index_var := cd.all_variables[2];
	it_rev_var := cd.all_variables[3];
	index_rev_var := cd.all_variables[4];
	it_p_var := cd.all_variables[5];
	index_p_var := cd.all_variables[6];
	it_p_rev_var := cd.all_variables[7];
	index_p_rev_var := cd.all_variables[8];
	v_var := cd.all_variables[9];
	val_var := cd.all_variables[10];
	idx_var := cd.all_variables[11];

	a_t_info : *TypeInfoArray = cd.all_type_info_array[0];

	//TODO Test loop array, and loop pointer array
	//should we try with array view as well?
	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//Initialize a : [2] int
		MakeMI(.mset, a_var.op, Imm(0), Imm(a_var.t_info.runtime_size)),
	]);

	//Empty for array loops are 8 instructions [start,end] inclusive
	AssertEquals(instr_index, for_scope.start_instr_index);
	AssertEquals(instr_index+7, for_scope.end_instr_index);
	//for a {}
	TestNextManyInstr(*instr_index, cd, .[
		//initialize it_index
		MakeMI(.mov, it_index_var.op, Imm(0), Imm(it_index_var.t_info.runtime_size)),
		//top loop instructions
		MakeMI(.clt, RegMem(.ax), it_index_var.op, Imm(a_t_info.array_count)),
		MakeMI(.fjmp, Imm(instr_index+8), RegMem(.ax)),
		//get value based on it_index
		MakeMI(.mul, RegMem(.ax), it_index_var.op, Imm(a_t_info.element_type.runtime_size)),
		MakeMI(.add, RegMem(.ax), a_var.op, RegMem(.ax)),
		MakeMI(.mov, it_var.op, RamMem(.ax), Imm(a_t_info.element_type.runtime_size)),			

		//loop bottom instructions
		MakeMI(.add, it_index_var.op, Imm(1)),
		// MakeMI(.add, it_var.op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.jmp, Imm(instr_index+1)),
	]);

	//Empty for < array loops are 8 instructions
	AssertEquals(instr_index, for_rev_scope.start_instr_index);
	AssertEquals(instr_index+7, for_rev_scope.end_instr_index);
	//for < a {}
	TestNextManyInstr(*instr_index, cd, .[
		//pre loop instructions to setup reverse it and it_index
		//so that they start from a.count-1
		MakeMI(.sub, index_rev_var.op, Imm(cd.all_type_info_array[0].array_count), Imm(1)),
		//loop top instructions
		MakeMI(.cgte, RegMem(.ax), index_rev_var.op, Imm(0)),
		MakeMI(.fjmp, Imm(instr_index+8), RegMem(.ax)),
		//get value based on it_index
		MakeMI(.mul, RegMem(.ax), it_index_var.op, Imm(a_t_info.element_type.runtime_size)),
		MakeMI(.add, RegMem(.ax), a_var.op, RegMem(.ax)),
		MakeMI(.mov, it_var.op, RamMem(.ax), Imm(a_t_info.element_type.runtime_size)),
		//loop bottom instructions
		MakeMI(.sub, it_index_var.op, Imm(1)),
		MakeMI(.jmp, Imm(instr_index+1)),
	]);

	a_op_0, a_op_1 := GetMemoryAddressAsOperands(a_var.op);
	//Empty for pointer fixed array loops are 8 instructions [start,end] inclusive
	AssertEquals(instr_index, for_p_scope.start_instr_index);
	AssertEquals(instr_index+7, for_p_scope.end_instr_index);
	//for * a {}
	TestNextManyInstr(*instr_index, cd, .[
		//initialize it_index
		MakeMI(.mov, index_p_var.op, Imm(0), Imm(index_p_var.t_info.runtime_size)),
		//top loop instructions
		MakeMI(.clt, RegMem(.ax), index_p_var.op, Imm(a_t_info.array_count)),
		MakeMI(.fjmp, Imm(instr_index+8), RegMem(.ax)),
		//get value based on it_index (since it's a pointer we store directly)
		MakeMI(.add, RegMem(.ax), a_op_0, a_op_1),
		MakeMI(.mul, RegMem(.bx), index_p_var.op, Imm(a_t_info.element_type.runtime_size)),
		MakeMI(.add, it_p_var.op, RegMem(.ax), RegMem(.bx)),
		//loop bottom instructions
		MakeMI(.add, index_p_var.op, Imm(1)),
		MakeMI(.jmp, Imm(instr_index+1)),
	]);

	//Empty for * < fixed array loops are 8 instructions [start,end] inclusive
	AssertEquals(instr_index, for_p_rev_scope.start_instr_index);
	AssertEquals(instr_index+7, for_p_rev_scope.end_instr_index);
	//for * < a {}
	TestNextManyInstr(*instr_index, cd, .[
		//initialize it_index
		MakeMI(.sub, index_p_rev_var.op, Imm(cd.all_type_info_array[0].array_count), Imm(1)),
		//top loop instructions
		MakeMI(.cgte, RegMem(.ax), index_p_rev_var.op, Imm(0)),
		MakeMI(.fjmp, Imm(instr_index+8), RegMem(.ax)),
		//get value based on it_index (since it's a pointer we store directly)
		MakeMI(.add, RegMem(.ax), a_op_0, a_op_1),
		MakeMI(.mul, RegMem(.bx), index_p_rev_var.op, Imm(a_t_info.element_type.runtime_size)),
		MakeMI(.add, it_p_rev_var.op, RegMem(.ax), RegMem(.bx)),
		//loop bottom instructions
		MakeMI(.sub, index_p_rev_var.op, Imm(1)),
		MakeMI(.jmp, Imm(instr_index+1)),
	]);

	//v : [] int = a;
	v_data_op := AddOperandOffset(8, v_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//v.count = a.count
		MakeMI(.mov, v_var.op, Imm(cd.all_type_info_array[0].array_count), Imm(cd.int_type_info.runtime_size)),
		//v.data = a.data
		MakeMI(.add, v_data_op, a_op_0, a_op_1),
	]);

	//Empty for array loops are 8 instructions
	AssertEquals(instr_index, for_var_scope.start_instr_index);
	AssertEquals(instr_index+7, for_var_scope.end_instr_index);
	//for val,idx : v {}
	TestNextManyInstr(*instr_index, cd, .[
		//loop setup var instructions
		MakeMI(.mov, idx_var.op, Imm(0), Imm(idx_var.t_info.runtime_size)),
		//top loop instructions
		MakeMI(.clt, RegMem(.ax), idx_var.op, v_var.op),
		MakeMI(.fjmp, Imm(instr_index+8), RegMem(.ax)),
		//get value based on it_index
		MakeMI(.mul, RegMem(.ax), idx_var.op, Imm(a_t_info.element_type.runtime_size)),
		MakeMI(.add, RegMem(.ax), v_data_op, RegMem(.ax)),
		MakeMI(.mov, val_var.op, RamMem(.ax), Imm(a_t_info.element_type.runtime_size)),
		//bottom loop instructions
		MakeMI(.add, idx_var.op, Imm(1)),
		MakeMI(.jmp, Imm(instr_index+1)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

#if 0 {
/*TODO need to implemennt mov and arithmetic with RAM_ARRAY before we can do this i think
*/
Test_ForLoopTano :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {
	//TODO Should we have a version that goes through rows
	//or maybe a section if we have that as a struct too
	// for tano[0][0..10] {
	// for tano[0,0..10] {
	// for tano[x+1][y+2] {
	for tano[x+1,y+2] {
	}
}
DONE,, unit_test_alloc);


} @UnitTest
}

Test_CompilePointer :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	x : int = 5;
	xp : *int = null;
	xp = *x;
	dp : int = xp.*;
}
DONE,, unit_test_alloc);

	count_equal = AssertEquals(1, cd.all_function_declarations.count);
	if count_equal {
		AssertEquals("main", cd.all_function_declarations[0].name);
	}

	//TODO Should we store these basic pointer types?
	int_pointer_type : *TypeInfoPointer;
	for cd.all_type_info_pointer if it.pointer_to == *cd.int_type_info {
		int_pointer_type = it;
		break;
	}
	var_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("xp", int_pointer_type, RamMem(.sbp,8)),
		VarDecl("dp", *cd.int_type_info, RamMem(.sbp,16))
	]);
	if !vars_equal return;
	x_var := cd.all_variables[0];
	xp_var := cd.all_variables[1];
	dp_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//Set x : int = 5
		MakeMI(.mov, x_var.op, Imm(5), Imm(8)),
		//Assign xp : *int = null
		MakeMI(.mov, xp_var.op, NULL_POINTER_OP, Imm(8)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//Get address of *x
		MakeMI(.add, RamMem(.sbp,16), RegMem(.sbp), Imm(0)),
		//Assign xp = *x
		MakeMI(.mov, xp_var.op, RamMem(.sbp,16), Imm(8)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//Dereference xp.* (we reuse .ax here so this checks that "=" frees .ax register)
		MakeMI(.mov, dp_var.op, xp_var.op, Imm(8)),
		//Assign dp : int = xp.*
		MakeMI(.mov, RegMem(.r0), dp_var.op, Imm(8)),
		MakeMI(.mov, dp_var.op, RamMem(.r0), Imm(8)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest;

//TODO FROM HERE Pointer/dereference integration tests.
//Also could do ops on stack instead of register before struct
//here to cleanup that as well.
//Then start on structs and structs with pointers.
/*NOTE : These are tests for special deref cases.
  They should work but maybe we won't use them much.
  Normal deref cases are in Test_MultiPointer.
*/
Test_Deref :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	x : int = 5;
	x1 : int = 2;
	//NOTE : This should be the value in x1.
	x1p : int = (*x + 1).*;
}
DONE,, unit_test_alloc);
	
	var_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("x1", *cd.int_type_info, RamMem(.sbp,8)),
		VarDecl("x1p", *cd.int_type_info, RamMem(.sbp,16)),
		// VarDecl("xpp", *int_p2_type.info, RamMem(.sbp,24)),
	]);
	if !vars_equal return;
	x_var := cd.all_variables[0];
	x1_var := cd.all_variables[1];
	x1p_var := cd.all_variables[2];
	// xpp_var := cd.all_variables[3];

	AssertEquals(OperandValueType.REGISTER, x_var.op.values[0].type);
	x_opv0 := RegMem(cast(RegDef) x_var.op.values[0].int_value);
	AssertEquals(OperandValueType.INTEGER, x_var.op.values[1].type);
	x_opv1 := Imm(x_var.op.values[1].int_value);

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//x : int = 5;
		MakeMI(.mov, x_var.op, Imm(5), Imm(x_var.t_info.runtime_size)),
		//x1 : int = 2;
		MakeMI(.mov, x1_var.op, Imm(2), Imm(x1_var.t_info.runtime_size)),
		//*x
		MakeMI(.add, RamMem(.sbp,16), x_opv0, x_opv1),
		//*x + 1
		MakeMI(.mul, RamMem(.sbp,24), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.add, RamMem(.sbp,24), RamMem(.sbp,16), RamMem(.sbp,24)),
		//(*x+1).*
		MakeMI(.mov, RamMem(.sbp,32), RamMem(.sbp,24), Imm(8)),
		// x1p : int = (*x+1).*;
		MakeMI(.mov, RegMem(.r0), RamMem(.sbp,32), Imm(x1p_var.t_info.runtime_size)),
		MakeMI(.mov, x1p_var.op, RamMem(.r0), Imm(x1p_var.t_info.runtime_size)),

		MakeMI(.exit)
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);



/*NOTE : We don't allow this right now. IT is confusing,
  I never use it, and I think that it was just a C shorthand
  optimization convenience. WE can do this on the RHS in any case
  We could set deref to always be L_VALUE and then this would work
  but since pointer arithmetic is always R_VALUE then
  it does not work. We could also check if pointer in
  pointer arithmetic is L_VALUE and set it to that
  but I still find it confusing.
  This way also provides some preventtion from accessing 
  incorrect memory that we should not change.
*/
	reset(*unit_test_alloc_pool, true);
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {	
  x : int = 5;
  (*x + 1).* = 10;
}
DONE,, unit_test_alloc);
	AssertEquals(1, cd.comp_errors.all_compiler_errors.count);

/*TEST error for dereferencing a non-pointer value
*/
	reset(*unit_test_alloc_pool, true);
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {	
  x : int = 5;
  x.* = 10;
}
DONE,, unit_test_alloc);
	AssertEquals(1, cd.comp_errors.all_compiler_errors.count);


} @UnitTest

Test_MultiPointer :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	xpn : **int;

	x : int = 5;
	//TODO Maybe we can remove single poitner and put it in dereference
	xp : *int = *x;
	xpp : **int = **x;

	xp.* = 1;
	xpp.*.* = 2;

	xp.* = xpp.*.*;
	xpp.* = xp;
}
DONE,, unit_test_alloc);

	count_equal = AssertEquals(1, cd.all_function_declarations.count);
	if count_equal {
		AssertEquals("main", cd.all_function_declarations[0].name);
	}

	//TODO Should we store these basic pointer types?
	int_p_type : *TypeInfoPointer;
	int_p2_type : *TypeInfoPointer;
	for cd.all_type_info_pointer if it.pointer_to.type_enum == .POINTER {
		p_type := cast(*TypeInfoPointer) it.pointer_to;
		if p_type.pointer_to == *cd.int_type_info {
			int_p_type = p_type;
			int_p2_type = it;
			break;
		}
	}
	var_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("xpn", int_p2_type, RamMem(.sbp,0)),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,8)),
		//store *x before this at [sbp,16]
		VarDecl("xp", *int_p_type.info, RamMem(.sbp,16)),
		//store 2 pointers **x before this at [sbp,24] and [sbp,32]
		VarDecl("xpp", *int_p2_type.info, RamMem(.sbp,24)),
	]);
	if !vars_equal return;
	xpn_var := cd.all_variables[0];
	x_var := cd.all_variables[1];
	xp_var := cd.all_variables[2];
	xpp_var := cd.all_variables[3];

	AssertEquals(OperandValueType.REGISTER, x_var.op.values[0].type);
	x_opv0 := RegMem(cast(RegDef) x_var.op.values[0].int_value);
	AssertEquals(OperandValueType.INTEGER, x_var.op.values[1].type);
	x_opv1 := Imm(x_var.op.values[1].int_value);

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//xpp : **int;
		MakeMI(.mov, xpn_var.op, NULL_POINTER_OP, Imm(xpn_var.t_info.runtime_size)),
		//x : int = 5;
		MakeMI(.mov, x_var.op, Imm(5), Imm(x_var.t_info.runtime_size)),
		//*x
		MakeMI(.add, RamMem(.sbp,16), x_opv0, x_opv1),
		//Optimized out since this is xp_var = [sbp+16]
		//xp : *int = *x;
		// MakeMI(.mov, xp_var.op, RamMem(.sbp,16), Imm(xp_var.t_info.runtime_size)),
		//*x
		MakeMI(.add, RamMem(.sbp,24), x_opv0, x_opv1),
		//**x
		MakeMI(.add, RamMem(.sbp,32), RegMem(.sbp), Imm(24)),
		// xpp : **int = **x;
		MakeMI(.mov, xpp_var.op, RamMem(.sbp,32), Imm(xpp_var.t_info.runtime_size)),
	]);

	deref_op := AddOperandOffset(8, xpp_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//xp.*
		MakeMI(.mov, deref_op, xp_var.op, Imm(8)),
		//xp.* = 1;
		MakeMI(.mov, RegMem(.r0), deref_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(1), Imm(8)),

	]);

	TestNextManyInstr(*instr_index, cd, .[
		//xpp.*
		MakeMI(.mov, deref_op, xpp_var.op, Imm(8)),
		//xpp.*.*
		MakeMI(.mov, RegMem(.r0), deref_op, Imm(8)),
		MakeMI(.mov, deref_op, RamMem(.r0), Imm(8)),
		//xpp.*.* = 2;
		MakeMI(.mov, RegMem(.r0), deref_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(2), Imm(8)),
	]);

	l_deref_op := AddOperandOffset(8, deref_op);
	TestNextManyInstr(*instr_index, cd, .[
		//RHS xpp.*
		MakeMI(.mov, deref_op, xpp_var.op, Imm(8)),
		//RHS xpp.*.*
		MakeMI(.mov, RegMem(.r0), deref_op, Imm(8)),
		MakeMI(.mov, deref_op, RamMem(.r0), Imm(8)),
		//LHS xp.*
		MakeMI(.mov, l_deref_op, xp_var.op, Imm(8)),
		//xp.* = xpp.*.*;
		MakeMI(.mov, RegMem(.r0), deref_op, Imm(8)),
		MakeMI(.mov, RegMem(.r1), l_deref_op, Imm(8)),
		MakeMI(.mov, RamMem(.r1), RamMem(.r0), Imm(8)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//xpp.*
		MakeMI(.mov, deref_op, xpp_var.op, Imm(8)),
		//xpp.* = xp;
		MakeMI(.mov, RegMem(.r0), deref_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), xp_var.op, Imm(8)),
		
		MakeMI(.exit),
	]);

	//Let's make sure all the registers are reusable now
	for reusable_start_reg_index..reusable_end_reg_index {
		AssertEquals(true, cd.all_registers[it].is_available);
	}

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_PointerArithmetic :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	x : int;
	y : *int = *x + 2;
	y = 3 + *x;
	y = *x - 1;

	xpp : **int = *y + x;

	//TODO Maybe we don't allow LHS pointer arithmetic for now.
	//It is very confusing for me and the coder.
	// (y + 1) = *x + 4;
	//Pointer arithmetic with dereferencing on LHS and RHS
	//This is not allowed now but should be tested if we do allow it
	//to make sure that the registers are ok which they should bein any case.
	//xpp : **int;
	//(xpp.* + 1) = *(x + 1);
}
DONE,, unit_test_alloc);

	//TODO We could make this a function to fetch pointer by base type
	int_p_type : *TypeInfoPointer;
	int_p2_type : *TypeInfoPointer;
	for cd.all_type_info_pointer if it.pointer_to.type_enum == .POINTER {
		p_type := cast(*TypeInfoPointer) it.pointer_to;
		if p_type.pointer_to == *cd.int_type_info {
			int_p_type = p_type;
			int_p2_type = it;
			break;
		}
	}
	var_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("y", *int_p_type.info, RamMem(.sbp,8)),
		VarDecl("xpp", *int_p2_type.info, RamMem(.sbp,16)),
	]);
	if !vars_equal return;
	x_var := cd.all_variables[0];
	y_var := cd.all_variables[1];
	xpp_var := cd.all_variables[2];

	AssertEquals(OperandValueType.REGISTER, x_var.op.values[0].type);
	x_opv0 := RegMem(cast(RegDef) x_var.op.values[0].int_value);
	AssertEquals(OperandValueType.INTEGER, x_var.op.values[1].type);
	x_opv1 := Imm(x_var.op.values[1].int_value);

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//x : int = 5;
		MakeMI(.mset, x_var.op, Imm(0), Imm(x_var.t_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//*x
		MakeMI(.add, RamMem(.sbp,8), x_opv0, x_opv1),
		//*x + 2
		MakeMI(.mul, RamMem(.sbp,16), Imm(2), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.add, RamMem(.sbp,16), y_var.op, RamMem(.sbp,16)),
		//y = *x + 2;
		MakeMI(.mov, y_var.op, RamMem(.sbp,16), Imm(y_var.t_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//*x
		MakeMI(.add, RamMem(.sbp,16), x_opv0, x_opv1),
		//3 + *x
		MakeMI(.mul, RamMem(.sbp,24), Imm(3), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.add, RamMem(.sbp,24), RamMem(.sbp,16), RamMem(.sbp,24)),
		//y = 3 + *x;
		MakeMI(.mov, y_var.op, RamMem(.sbp,24), Imm(y_var.t_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//*x
		MakeMI(.add, RamMem(.sbp,16), x_opv0, x_opv1),
		//*x - 1
		MakeMI(.mul, RamMem(.sbp,24), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.sub, RamMem(.sbp,24), RamMem(.sbp,16), RamMem(.sbp,24)),
		//y = *x - 1;
		MakeMI(.mov, y_var.op, RamMem(.sbp,24), Imm(y_var.t_info.runtime_size)),
	]);


	AssertEquals(OperandValueType.REGISTER, y_var.op.values[0].type);
	y_opv0 := RegMem(cast(RegDef) y_var.op.values[0].int_value);
	AssertEquals(OperandValueType.INTEGER, y_var.op.values[1].type);
	y_opv1 := Imm(y_var.op.values[1].int_value);
	TestNextManyInstr(*instr_index, cd, .[
		//*y
		MakeMI(.add, RamMem(.sbp,16), y_opv0, y_opv1),
		//*y + x
		MakeMI(.mul, RamMem(.sbp,24), x_var.op, Imm(int_p_type.runtime_size)),
		MakeMI(.add, RamMem(.sbp,24), RamMem(.sbp,16), RamMem(.sbp,24)),
		//xpp : **int = y + x;
		MakeMI(.mov, xpp_var.op, RamMem(.sbp,24), Imm(y_var.t_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);


	//TEST : Cannot do 1 - pointer value. Only pointer - 1 is valid
	//since we know we are subtracting from a pointer then.
	reset(*unit_test_alloc_pool, true);
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	x : int;
	y : *int = 1 - *x;
}
DONE,, unit_test_alloc);
	AssertEquals(1, cd.comp_errors.all_compiler_errors.count);

} @UnitTest

Test_ColonEquals :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
  //Base type tests
  x := 1;
  f := 3.14;
  c := x + 1;

  //pointer test
  y := *x;

  //array literal tests
  a := int.[0,1];
  fa := float.[0.,1.];

  //tano test
  t := tano(0,0.);
}
DONE,, unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_type_info_array.count);
	if !count_equal return;
	i_info : *TypeInfoArray;
	f_info : *TypeInfoArray;
	if count_equal {
		i_info = cd.all_type_info_array[0];
		f_info = cd.all_type_info_array[1];
	}

	int_p_type_info := GetTypeInfoPointer(*cd.int_type_info, cd);
	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("x", *cd.int_type_info),
		VarDecl("f", *cd.float_type_info),
		VarDecl("c", *cd.int_type_info),
		VarDecl("y", int_p_type_info),
		VarDecl("a", i_info),
		VarDecl("fa", f_info),
		VarDecl("t", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	x_var := cd.all_variables[0];
	f_var := cd.all_variables[1];
	c_var := cd.all_variables[2];
	y_var := cd.all_variables[3];
	a_var := cd.all_variables[4];
	fa_var := cd.all_variables[5];
	t_var := cd.all_variables[6];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//x := 1;
		MakeMI(.mov, x_var.op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		//f := 3.14;
		MakeMI(.mov, f_var.op, FImm(3.14), Imm(cd.float_type_info.runtime_size)),
		//c := x + 1;
		MakeMI(.add, c_var.op, x_var.op, Imm(1)),
	]);

	x_0, x_1 := GetMemoryAddressAsOperands(x_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//y := *x;
		MakeMI(.add, y_var.op, x_0, x_1),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//a := int.[0,1];
		MakeMI(.mov, a_var.op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8,a_var.op), Imm(1), Imm(cd.int_type_info.runtime_size)),
		//fa := float.[0.,1.];
		MakeMI(.mov, fa_var.op, FImm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8,fa_var.op), FImm(1), Imm(cd.float_type_info.runtime_size)),
	]);

	// t := tano(0,0.);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, AddOperandOffset(0, t_var.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8, t_var.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(16, t_var.op), FImm(0), Imm(cd.float_type_info.runtime_size)),
		MakeFloatInstr(.add, AddOperandOffset(24, t_var.op), AddOperandOffset(16, t_var.op), FImm(1)),
		MakeMI(.mov, AddOperandOffset(32, t_var.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest


//TODO FROM HERE Split out "=" to LHS and RHS
//then maybe test function with struct and then
//start on editor or just start on editor debugging

//TODO Then update function declarations to be parsed differently with "," above or 
//make sure it works and also generate TypeInfoProcedure and then use that wherever it is more convenient to use
//Finish that with CreateStackVarData on second pass and also
//use argument_types and return_types everywhere now and then test
//with multiple inputs and output functions
//TODO IMPORTANT DONT NEED BYTE_OFFSET_FROM_SBP DURING FUNCTION CALL
//some cases like calling function inside function call (eg foo(x+1,foo2(1)))
//to make sure and maybe some arithemtic and also calling a function inside another function as well
//then test push_all_stack_reg and pop_all_stack_reg and also Test_CompileFunc for multi input and return functions
//should we do function pointers after or wait till later

//TODO Multi return value and empty tests
//Only functions can have multiple values, so no lists other than that.
//Can also start on operator + just so the structure is there and then
//finish operator overloads later since we are doing functions now.
//Could also wait until later if we have more info but might be bets now
//since it's fresh in mind.
//Then just just implement TypeInfoProcedure before doing float and asm.
//Can do function pointers later or with them if we feel like it.
Test_CompileFunc :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
foo :: (x : int) -> int {
	return x + 1;
}
main :: () {
	x : int = foo(1);
	y : int = foo2(x,4);
	//TODO Test function inside function
	// z : int = foo2(foo(y),1);
}
//This tests that we can declare a function after it is called
foo2 :: (x : int, y : int) -> int {
	return x + y;
}
DONE,,unit_test_alloc);

	//TODO FROM HERE Test starting from "(" and then write unit tests
	//then do multiple inputs and multiple returns
	//and then also do no inputs / some returns and some inputs / not returns
	//and an empty call. Could make each test separate unit test for clarity

	count_equal = AssertEquals(3, cd.all_function_declarations.count);
	if !count_equal return;
	foo_decl := cd.all_function_declarations[0];
	AssertEquals("foo", foo_decl.name);
	AssertEquals("main", cd.all_function_declarations[1].name);
	foo2_decl := cd.all_function_declarations[2];
	AssertEquals("foo2", foo2_decl.name);
	//TODO Can make a function to Test an Array so we test count first
	//and then we pass in a TestEquals function or use ==
	count_equal = AssertEquals(3, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[0].function_id);
		AssertEquals("x", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);

		AssertEquals(cd.all_function_declarations[2].id, cd.all_function_arguments[1].function_id);
		AssertEquals("x", cd.all_function_arguments[1].name);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_arguments[1].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[1].var_bytes_from_sbp);

		AssertEquals(cd.all_function_declarations[2].id, cd.all_function_arguments[2].function_id);
		AssertEquals("y", cd.all_function_arguments[2].name);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_arguments[2].t_info.type_enum);
		AssertEquals(8, cd.all_function_arguments[2].var_bytes_from_sbp);
	}

	count_equal = AssertEquals(2, cd.all_function_return_variables.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_return_variables[0].function_id);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_return_variables[0].t_info.type_enum);
		AssertEquals(cd.all_function_declarations[2].id, cd.all_function_return_variables[1].function_id);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_return_variables[1].t_info.type_enum);
	}

	scope_count := AssertEquals(4, cd.all_scope_data.count);
	foo_scope : ScopeData;
	main_scope : ScopeData;
	foo2_scope : ScopeData;
	if scope_count {
		AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
		AssertEquals(0, cd.all_scope_data[0].start_instr_index);
		AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

		foo_scope = cd.all_scope_data[1];
		AssertEquals(foo_scope.function_id, cd.all_function_declarations[0].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);

		main_scope = cd.all_scope_data[2];
		AssertEquals(main_scope.function_id, cd.all_function_declarations[1].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);

		foo2_scope = cd.all_scope_data[3];
		AssertEquals(foo2_scope.function_id, cd.all_function_declarations[2].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo2_scope.scope_type);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//x in foo
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		//x in main
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		//y in main
		VarDecl("y", *cd.int_type_info, RamMem(.sbp,8)),
		//x in foo2
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		//y in foo2
		VarDecl("y", *cd.int_type_info, RamMem(.sbp,8)),
	]);
	if !vars_equal return;
	x_foo_var := cd.all_variables[0];
	x_main_var := cd.all_variables[1];
	y_main_var := cd.all_variables[2];

	instr_index : int = 0;
	start_foo_instr_index : int = instr_index;
	//foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Input at ax = [sbp,0] + 1
		MakeMI(.add, RamMem(.sbp,8), x_foo_var.op, Imm(1)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-x_main_var.t_info.runtime_size), 
			RamMem(.sbp,8), 
			Imm(x_main_var.t_info.runtime_size)),
		MakeMI(.ret),
	]);

	if scope_count {
		AssertEquals(start_foo_instr_index, foo_scope.start_instr_index);
		AssertEquals(instr_index-1, foo_scope.end_instr_index);
	}

	//main function
	AssertEquals(instr_index, cd.main_function_instr_index);

	//Add return values + PRE_PROC_STACK_SIZE here, so we could add return values from function_declaration
	//TODO Could make this a function to get next stack size based on return variable
	next_stack_p : int = PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == foo_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	//foo(1)
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,8)),
		//Push on integer 1 argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), Imm(1), Imm(8)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(8)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(0)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),
	]);

	//No need for any instructions here since the function return is already set to the same place as x
	//x : int = foo(1)
	// TestNextManyInstr(*instr_index, cd, .[
		// MakeMI(.mov, RegMem(.scp), Imm(0)),
		// MakeMI(.add, RegMem(.scp), RegMem(.sbp), Imm(0)),
		// MakeMI(.mov, x_main_var.op, RamMem(.sbp,0), Imm(8)),
	// ]);

	next_stack_p = x_main_var.t_info.runtime_size;
	next_stack_p += PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == foo2_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	//foo2(x,4)
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,16)),
		//Push on integer x argument (8 bytes so we pass by value)
		MakeMI(.mov, RamMem(.sbp,next_stack_p), RamMem(.sbp,0), Imm(8)),
		//Push on integer 4 argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p+8), Imm(4), Imm(8)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(15)),
		//call foo2 
		MakeMI(.call, Imm(17)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),
	]);

	//No need for any instructions here since the function return is already set to the same place as y
	//y : int = foo2(x,4)
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.exit),
	]);

	if scope_count {
		AssertEquals(cd.main_function_instr_index, main_scope.start_instr_index);
		AssertEquals(instr_index-1, main_scope.end_instr_index);
	}

	foo2_instr_index : int = instr_index;
	//foo2 :: (x : int, y : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Input at ax = [sbp,0] + [sbp,8]
		MakeMI(.add, RamMem(.sbp,16), RamMem(.sbp,0), RamMem(.sbp,8)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-y_main_var.t_info.runtime_size), 
			RamMem(.sbp,16), 
			Imm(y_main_var.t_info.runtime_size)),
		MakeMI(.ret),
	]);

	if scope_count {
		AssertEquals(foo2_instr_index, foo2_scope.start_instr_index);
		AssertEquals(instr_index-1, foo2_scope.end_instr_index);
	}

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CompFuncInFunc :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
foo :: (x : int) -> int {
	return x + 1;
}
main :: () {
	x : int = foo2(1);
}
foo2 :: (x : int) -> int {
	return x + foo(x);
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(3, cd.all_function_declarations.count);
	if !count_equal return;
	foo_decl := cd.all_function_declarations[0];
	AssertEquals("foo", foo_decl.name);
	AssertEquals("main", cd.all_function_declarations[1].name);
	foo2_decl := cd.all_function_declarations[2];
	AssertEquals("foo2", foo2_decl.name);
	//TODO Can make a function to Test an Array so we test count first
	//and then we pass in a TestEquals function or use ==
	count_equal = AssertEquals(2, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(foo_decl.id, cd.all_function_arguments[0].function_id);
		AssertEquals("x", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);

		AssertEquals(foo2_decl.id, cd.all_function_arguments[1].function_id);
		AssertEquals("x", cd.all_function_arguments[1].name);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_arguments[1].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[1].var_bytes_from_sbp);
	}

	count_equal = AssertEquals(2, cd.all_function_return_variables.count);
	if count_equal {
		AssertEquals(foo_decl.id, cd.all_function_return_variables[0].function_id);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_return_variables[0].t_info.type_enum);

		AssertEquals(foo2_decl.id, cd.all_function_return_variables[1].function_id);
		AssertEquals(TypeInfoTag.INTEGER, cd.all_function_return_variables[1].t_info.type_enum);
	}

	scope_count := AssertEquals(4, cd.all_scope_data.count);
	foo_scope : ScopeData;
	main_scope : ScopeData;
	foo2_scope : ScopeData;
	if scope_count {
		AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
		AssertEquals(0, cd.all_scope_data[0].start_instr_index);
		AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

		foo_scope = cd.all_scope_data[1];
		AssertEquals(foo_scope.function_id, cd.all_function_declarations[0].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);

		main_scope = cd.all_scope_data[2];
		AssertEquals(main_scope.function_id, cd.all_function_declarations[1].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);

		foo2_scope = cd.all_scope_data[3];
		AssertEquals(foo2_scope.function_id, cd.all_function_declarations[2].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo2_scope.scope_type);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//x in foo
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		//x in main
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		//x in foo2
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	x_foo_var := cd.all_variables[0];
	x_main_var := cd.all_variables[1];
	x_f2_var := cd.all_variables[2];


	instr_index : int = 0;
	start_foo_instr_index : int = instr_index;
	//foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Input at ax = [sbp,0] + 1
		MakeMI(.add, RamMem(.sbp,8), x_foo_var.op, Imm(1)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-x_main_var.t_info.runtime_size), 
			RamMem(.sbp,8), 
			Imm(x_main_var.t_info.runtime_size)),
		MakeMI(.ret),
	]);

	if scope_count {
		AssertEquals(start_foo_instr_index, foo_scope.start_instr_index);
		AssertEquals(instr_index-1, foo_scope.end_instr_index);
	}

	//main function
	AssertEquals(instr_index, cd.main_function_instr_index);

	//Add return values + PRE_PROC_STACK_SIZE here, so we could add return values from function_declaration
	//TODO Could make this a function to get next stack size based on return variable
	next_stack_p : int = PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == foo_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	//foo2(1)
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,8)),
		//Push on integer 1 argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), Imm(1), Imm(8)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(8)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(foo2_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		//end of main function
		MakeMI(.exit),
	]);

	if scope_count {
		AssertEquals(cd.main_function_instr_index, main_scope.start_instr_index);
		AssertEquals(instr_index-1, main_scope.end_instr_index);
	}

	//Store vars for the next function call on the next stack
	//We already have the f2 x argument on the stack
	second_stack_p : int = x_f2_var.t_info.runtime_size;
	foo_return_op := RamMem(.sbp,second_stack_p);
	for cd.all_function_return_variables if it.function_id == foo_decl.id {
		second_stack_p += it.t_info.runtime_size;
	}
	f_stack_push_pos : int = second_stack_p;
	//Add the stack for foo call which is in f2 
	second_stack_p += PRE_PROC_STACK_SIZE;
	foo2_instr_index : int = instr_index;
	//foo2 :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//foo(x)
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,f_stack_push_pos)),
		//Push on integer x argument
		MakeMI(.mov, RamMem(.sbp,second_stack_p), x_foo_var.op, Imm(8)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(second_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(foo_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),


		//Input at x + foo(x)
		MakeMI(.add, RamMem(.sbp,16), x_foo_var.op, foo_return_op),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-x_main_var.t_info.runtime_size), 
			RamMem(.sbp,16), 
			Imm(x_main_var.t_info.runtime_size)),
		MakeMI(.ret),
	]);

	if scope_count {
		AssertEquals(foo2_instr_index, foo2_scope.start_instr_index);
		AssertEquals(instr_index-1, foo2_scope.end_instr_index);
	}

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_FuncWithPointer :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
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
DONE,,unit_test_alloc);

	count_equal = AssertEquals(3, cd.all_function_declarations.count);
	if !count_equal return;
	foo_decl := cd.all_function_declarations[1];
	AssertEquals("foo", foo_decl.name);
	f2_decl := cd.all_function_declarations[2];
	AssertEquals("f2", f2_decl.name);

	count_equal = AssertEquals(2, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[1].id, cd.all_function_arguments[0].function_id);
		AssertEquals("xp", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.POINTER, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);


		AssertEquals(cd.all_function_declarations[2].id, cd.all_function_arguments[1].function_id);
		AssertEquals("xpp", cd.all_function_arguments[1].name);
		AssertEquals(TypeInfoTag.POINTER, cd.all_function_arguments[1].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[1].var_bytes_from_sbp);
	}

	AssertEquals(0, cd.all_function_return_variables.count);

	scope_count := AssertEquals(4, cd.all_scope_data.count);
	foo_scope : ScopeData;
	main_scope : ScopeData;
	f2_scope : ScopeData;
	if scope_count {
		AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
		AssertEquals(0, cd.all_scope_data[0].start_instr_index);
		AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

		main_scope = cd.all_scope_data[1];
		AssertEquals(main_scope.function_id, cd.all_function_declarations[0].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);

		foo_scope = cd.all_scope_data[2];
		AssertEquals(foo_scope.function_id, foo_decl.id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);

		f2_scope = cd.all_scope_data[3];
		AssertEquals(f2_scope.function_id, f2_decl.id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, f2_scope.scope_type);
	}

	int_p_t_info, found_t_info := GetTypeInfoPointer(*cd.int_type_info, cd);
	AssertEquals(true, found_t_info);
	if !found_t_info return;
	p2_t_info, found_p2_info := GetTypeInfoPointer(int_p_t_info, cd);
	AssertEquals(true, found_p2_info);
	if !found_p2_info return;

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//x in main
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		//x in foo
		VarDecl("xp", int_p_t_info, RamMem(.sbp,0)),
		//x in f2
		VarDecl("xpp", p2_t_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	x_main_var := cd.all_variables[0];
	xp_var := cd.all_variables[1];
	xpp_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//x : int = 3;
		MakeMI(.mov, x_main_var.op, Imm(3), Imm(x_main_var.t_info.runtime_size)),
	]);

	xp_op := AddOperandOffset(8, x_main_var.op);
	x_0_op, x_1_op := GetMemoryAddressAsOperands(x_main_var.op);
	reg_pos : int = 16;
	next_stack_p : int = reg_pos + PRE_PROC_STACK_SIZE;
	//foo(*x)
	TestNextManyInstr(*instr_index, cd, .[
		//*x
		MakeMI(.add, xp_op, x_0_op, x_1_op),

		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,reg_pos)),
		//Push on integer 1 argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), xp_op, Imm(cd.void_pointer_type_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+6)),
		//call foo 
		MakeMI(.call, Imm(foo_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),
	]);

	xp2_op := AddOperandOffset(8, xp_var.op);
	xp2_0, xp2_1 := GetMemoryAddressAsOperands(xp2_op);
	xpp2_op := AddOperandOffset(8, xp2_op);
	reg_op := AddOperandOffset(8, xpp2_op);
	f2_stack : int = reg_op.values[1].int_value + PRE_PROC_STACK_SIZE;
	//foo(**x)
	TestNextManyInstr(*instr_index, cd, .[
		//**x
		MakeMI(.add, xp2_op, x_0_op, x_1_op),
		MakeMI(.add, xpp2_op, xp2_0, xp2_1),

		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, reg_op),
		//Push on integer 1 argument
		MakeMI(.mov, RamMem(.sbp,f2_stack), xpp2_op, Imm(cd.void_pointer_type_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(f2_stack)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+7)),
		//call foo 
		MakeMI(.call, Imm(f2_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		MakeMI(.exit),
	]);


	start_foo_instr_index : int = instr_index;
	//foo :: (x : *int)
	TestNextManyInstr(*instr_index, cd, .[
		//x.*
		MakeMI(.mov, RamMem(.sbp,8), xp_var.op, Imm(xp_var.t_info.runtime_size)),
		//x.* = 10;
		MakeMI(.mov, RegMem(.r0), RamMem(.sbp,8), Imm(xp_var.t_info.runtime_size)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	if scope_count {
		AssertEquals(start_foo_instr_index, foo_scope.start_instr_index);
		AssertEquals(instr_index-1, foo_scope.end_instr_index);
	}

	f2_instr_index : int = instr_index;
	//f2 :: (x : **int)
	TestNextManyInstr(*instr_index, cd, .[
		//xpp.*
		MakeMI(.mov, RamMem(.sbp,8), xpp_var.op, Imm(xpp_var.t_info.runtime_size)),
		//xpp.*.*
		MakeMI(.mov, RegMem(.r0), RamMem(.sbp,8), Imm(xpp_var.t_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), RamMem(.r0), Imm(xpp_var.t_info.runtime_size)),
		//xpp.*.* = 10;
		MakeMI(.mov, RegMem(.r0), RamMem(.sbp,8), Imm(xpp_var.t_info.runtime_size)),
		MakeMI(.mov, RamMem(.r0), Imm(20), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

	if scope_count {
		AssertEquals(f2_instr_index, f2_scope.start_instr_index);
		AssertEquals(instr_index-1, f2_scope.end_instr_index);
	}

} @UnitTest

//TODO FROM HERE make an integration test with this
//and with double pointer for completeness (could add double pointer her etoo)
//then do same for func with array (fixed -> view in func)
//and then func with struct (and also struct in struct probably)

//TODO FROM HERE REMEMBER debug function call should stop after pop_all_stack_reg
//need to update tests to account for that
//THEN MAYBE removing watch data on error or change in type
//before we move on to #load
Test_FuncWithArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
  fa : [2] int = int.[0,1];
  f2(fa);
  //TODO Eventually we can auto-cast the array
  //but it's annoying because we have to check each array type
  //since we could possibly have the same function with different fixed array or array view.
  av : [] int = fa;
  foo(av);
  //TODO Could implement this casting eventually
  // foo(cast([] int) fa);
}
foo :: (a : [] int) {
  a[1] = 2;
}
f2 :: (a : [2] int) {
  a[1] = 3;
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(3, cd.all_function_declarations.count);
	if !count_equal return;
	foo_decl := cd.all_function_declarations[1];
	AssertEquals("foo", foo_decl.name);
	f2_decl := cd.all_function_declarations[2];
	AssertEquals("f2", f2_decl.name);

	fa_info, found_fa_info := GetArrayType(cd, *cd.int_type_info, .FIXED, 2);
	AssertEquals(true, found_fa_info);
	if !found_fa_info return;
	view_info, found_view_info := GetArrayType(cd, *cd.int_type_info, .VIEW);
	AssertEquals(true, found_view_info);
	if !found_view_info return;

	count_equal = AssertEquals(2, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[1].id, cd.all_function_arguments[0].function_id);
		AssertEquals("a", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.ARRAY, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(*view_info.info, cd.all_function_arguments[0].t_info);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);


		AssertEquals(cd.all_function_declarations[2].id, cd.all_function_arguments[1].function_id);
		AssertEquals("a", cd.all_function_arguments[1].name);
		AssertEquals(TypeInfoTag.ARRAY, cd.all_function_arguments[1].t_info.type_enum);
		AssertEquals(*fa_info.info, cd.all_function_arguments[1].t_info);
		AssertEquals(0, cd.all_function_arguments[1].var_bytes_from_sbp);
	}

	AssertEquals(0, cd.all_function_return_variables.count);

	scope_count := AssertEquals(4, cd.all_scope_data.count);
	foo_scope : ScopeData;
	main_scope : ScopeData;
	f2_scope : ScopeData;
	if scope_count {
		AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
		AssertEquals(0, cd.all_scope_data[0].start_instr_index);
		AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

		main_scope = cd.all_scope_data[1];
		AssertEquals(main_scope.function_id, cd.all_function_declarations[0].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);

		foo_scope = cd.all_scope_data[2];
		AssertEquals(foo_scope.function_id, foo_decl.id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);

		f2_scope = cd.all_scope_data[3];
		AssertEquals(f2_scope.function_id, f2_decl.id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, f2_scope.scope_type);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("fa", *fa_info.info, RamMem(.sbp,0)),
		VarDecl("av", *view_info.info, RamMem(.sbp,fa_info.runtime_size)),
		VarDecl("a", *view_info.info, RamMem(.sbp,0)),
		VarDecl("a", *fa_info.info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	fa_var := cd.all_variables[0];
	av_var := cd.all_variables[1];
	a_foo_var := cd.all_variables[2];
	a_f2_var := cd.all_variables[3];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//fa := int.[0,4];
		MakeMI(.mov, fa_var.op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8,fa_var.op), Imm(1), Imm(cd.int_type_info.runtime_size)),
	]);

	// xp_op := AddOperandOffset(8, x_main_var.op);
	// x_0_op, x_1_op := GetMemoryAddressAsOperands(x_main_var.op);
	reg_op := AddOperandOffset(fa_var.t_info.runtime_size, fa_var.op);
	next_stack_p : int = reg_op.values[1].int_value + PRE_PROC_STACK_SIZE;
	//f2(fa)
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, reg_op),
		MakeMI(.mov, RamMem(.sbp,next_stack_p), fa_var.op, Imm(fa_var.t_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo 
		MakeMI(.call, Imm(f2_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),
	]);

	fa_0, fa_1 := GetMemoryAddressAsOperands(fa_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//av : [] int = fa;
		//count
		MakeMI(.mov, av_var.op, Imm(fa_info.array_count), Imm(cd.int_type_info.runtime_size)),
		//data
		MakeMI(.add, AddOperandOffset(8,av_var.op), fa_0, fa_1),
	]);

	// xp_op := AddOperandOffset(8, x_main_var.op);
	// x_0_op, x_1_op := GetMemoryAddressAsOperands(x_main_var.op);
	foo_reg_op := AddOperandOffset(av_var.t_info.runtime_size, av_var.op);
	foo_stack_p : int = foo_reg_op.values[1].int_value + PRE_PROC_STACK_SIZE;
	//foo(av)
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, foo_reg_op),
		//Push on integer 1 argument
		MakeMI(.mov, RamMem(.sbp,foo_stack_p), av_var.op, Imm(av_var.t_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(foo_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo 
		MakeMI(.call, Imm(foo_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		MakeMI(.exit),
	]);


	start_foo_instr_index : int = instr_index;
	array_data_op : MusicOperand = AddOperandOffset(8, a_foo_var.op);
	array_access_op : MusicOperand = AddOperandOffset(a_foo_var.t_info.runtime_size, a_foo_var.op);
	a_0, a_1 := GetMemoryAddressAsOperands(a_foo_var.op);
	//foo :: (a : [] int)
	TestNextManyInstr(*instr_index, cd, .[
		//a[1]
		MakeMI(.add, RegMem(.ax), a_0, a_1),
		MakeMI(.add, RegMem(.ax), Imm(8)),
		MakeMI(.mov, array_access_op, RamMem(.ax)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(fa_info.element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//a[1] = 1;
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(cd.void_pointer_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.r0), Imm(2), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	if scope_count {
		AssertEquals(start_foo_instr_index, foo_scope.start_instr_index);
		AssertEquals(instr_index-1, foo_scope.end_instr_index);
	}

	f2_instr_index : int = instr_index;
	a_f2_0, a_f2_1 := GetMemoryAddressAsOperands(a_f2_var.op);
	f2_access_op : MusicOperand = AddOperandOffset(a_f2_var.t_info.runtime_size, a_f2_var.op);
	//f2 :: (a : [2] int)
	TestNextManyInstr(*instr_index, cd, .[
		//a[1]
		MakeMI(.add, f2_access_op, a_f2_0, a_f2_1),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(fa_info.element_type.runtime_size)),
		MakeMI(.add, f2_access_op, RegMem(.ax)),
		//a[1] = 3;
		MakeMI(.mov, RegMem(.r0), f2_access_op, Imm(cd.void_pointer_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.r0), Imm(3), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

	if scope_count {
		AssertEquals(f2_instr_index, f2_scope.start_instr_index);
		AssertEquals(instr_index-1, f2_scope.end_instr_index);
	}

} @UnitTest

/*simple test for struct in functions
TODO need to do more elaborate tests with struct pointers in functions and updating
and also struct in struct with functions and also struct literals once we implement that.
*/
Test_FuncWithStruct :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
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
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	if !count_equal return;
	foo_decl := cd.all_function_declarations[1];
	AssertEquals("foo", foo_decl.name);

	v2_info, found_v2_info := GetTypeInfoStructByName("V2", cd.all_type_info_struct);
	AssertEquals(true, found_v2_info);
	if !found_v2_info return;
	AssertEquals(16, v2_info.runtime_size);
	AssertEquals("V2", v2_info.name);
	AssertEquals(TypeInfoTag.STRUCT, v2_info.type_enum);

	count_equal = AssertEquals(1, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[1].id, cd.all_function_arguments[0].function_id);
		AssertEquals("v", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.STRUCT, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(*v2_info.info, cd.all_function_arguments[0].t_info);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);
	}

	count_equal = AssertEquals(1, cd.all_function_return_variables.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[1].id, cd.all_function_return_variables[0].function_id);
		AssertEquals(TypeInfoTag.STRUCT, cd.all_function_return_variables[0].t_info.type_enum);
		AssertEquals(*v2_info.info, cd.all_function_return_variables[0].t_info);
		AssertEquals(v2_info.runtime_size, cd.all_function_return_variables[0].var_bytes_from_sbp);
	}

	scope_count := AssertEquals(3, cd.all_scope_data.count);
	foo_scope : ScopeData;
	main_scope : ScopeData;
	if scope_count {
		AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
		AssertEquals(0, cd.all_scope_data[0].start_instr_index);
		AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

		main_scope = cd.all_scope_data[1];
		AssertEquals(main_scope.function_id, cd.all_function_declarations[0].id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);

		foo_scope = cd.all_scope_data[2];
		AssertEquals(foo_scope.function_id, foo_decl.id);
		AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("v", *v2_info.info, RamMem(.sbp,0)),
		VarDecl("v0", *v2_info.info, RamMem(.sbp,v2_info.runtime_size)),
		VarDecl("v", *v2_info.info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	v_var := cd.all_variables[0];
	v0_var := cd.all_variables[1];
	v_foo_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		// v : V2;
		MakeMI(.mset, v_var.op, Imm(0), Imm(v2_info.runtime_size)),
	   // v.x = 1;
		MakeMI(.mov, v_var.op, FImm(1), Imm(cd.float_type_info.runtime_size)),
	]);

	//Set the reg after v_var and after return v2 values
	return_op := AddOperandOffset(v_var.t_info.runtime_size, v_var.op);
	reg_op := AddOperandOffset(foo_decl.t_info_proc.return_types[0].runtime_size, return_op);
	next_stack_p : int = reg_op.values[1].int_value + PRE_PROC_STACK_SIZE;
	//foo(v)
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, reg_op),
		MakeMI(.mov, RamMem(.sbp,next_stack_p), v_var.op, Imm(v_var.t_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo 
		MakeMI(.call, Imm(foo_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

  		//NOTE: This is optimized out because we have not set v0 yet, so we put the return vars before the function
  		//stack push reg and then when we come back, they are the same op so it gets removed. Nice!
  		//v0 := foo(v);
		// MakeMI(.mov, v_var.op, return_op, Imm(v2_info.runtime_size)),

		MakeMI(.exit),
	]);

	start_foo_instr_index : int = instr_index;
	//foo :: (v : V2) -> V2
	TestNextManyInstr(*instr_index, cd, .[
		//return v;
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-v_foo_var.t_info.runtime_size), 
			v_foo_var.op, 
			Imm(v_foo_var.t_info.runtime_size)),
		MakeMI(.ret),
	]);

	if scope_count {
		AssertEquals(start_foo_instr_index, foo_scope.start_instr_index);
		AssertEquals(instr_index-1, foo_scope.end_instr_index);
	}

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

/*TODO Do we really want multi-return value? It complicates
things but I guess we can focus on single return for now
and just have multi implemented and continue or remove it later if needed.

I am removing this for now. Ultimately I do want to have multi return but it is too confusing
to keep track of until we know 1 return functions work properly.
Multi return only from functions is the right solution and it is setup to work with both node parsing
and also for function evaluation. So I would just have to go back in and check that it works in general.
But first lets make sure 1 value return functions work and then ill add multi-return functions later.
*/
#if 0 {
Test_MultiReturn :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
foo :: (x : int, y : int) -> int, int {
	return x+1,y+1;
}
main :: () {
	x,y := foo(1,2);
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	if count_equal {
		AssertEquals("foo", cd.all_function_declarations[0].name);
		AssertEquals("main", cd.all_function_declarations[1].name);
		//TODO Can make a function to Test an Array so we test count first
		//and then we pass in a TestEquals function or use ==
		count_equal = AssertEquals(2, cd.all_function_arguments.count);
		if count_equal {
			AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[0].function_id);
			AssertEquals("x", cd.all_function_arguments[0].name);
			AssertEquals(TypeInfoTag.INTEGER, cd.all_function_arguments[0].t_info.type_enum);
			AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);

			AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[1].function_id);
			AssertEquals("y", cd.all_function_arguments[1].name);
			AssertEquals(TypeInfoTag.INTEGER, cd.all_function_arguments[1].t_info.type_enum);
			AssertEquals(8, cd.all_function_arguments[1].var_bytes_from_sbp);
		}

		count_equal = AssertEquals(2, cd.all_function_return_variables.count);
		if count_equal {
			AssertEquals(cd.all_function_declarations[0].id, cd.all_function_return_variables[0].function_id);
			AssertEquals(TypeInfoTag.INTEGER, cd.all_function_return_variables[0].t_info.type_enum);
			AssertEquals(cd.all_function_declarations[0].id, cd.all_function_return_variables[1].function_id);
			AssertEquals(TypeInfoTag.INTEGER, cd.all_function_return_variables[1].t_info.type_enum);
		}
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//in foo
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0), 1),
		VarDecl("y", *cd.int_type_info, RamMem(.sbp,8), 1),
		//in main
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0), 1),
		VarDecl("y", *cd.int_type_info, RamMem(.sbp,8), 1),
	]);
	if !vars_equal return;
	x_foo_var := cd.all_variables[0];
	y_foo_var := cd.all_variables[1];
	x_main_var := cd.all_variables[2];
	y_main_var := cd.all_variables[3];



	instr_index : int = 0;
	//foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Input at ax = [sbp,0] + 1
		MakeMI(.add, RegMem(.ax), RamMem(.sbp,0), Imm(1)),
		MakeMI(.add, RegMem(.bx), RamMem(.sbp,8), Imm(1)),

		//Return value address stored [sbp,16] and moved to cx
		MakeMI(.mov, RegMem(.cx), RamMem(.sbp,16)),
		//[cx] is where in memory we are pointing to
		MakeMI(.mov, RamMem(.cx), RegMem(.ax), Imm(8)),

		//2nd return value address stored [sbp,24] and moved to cx
		//NOTE : We free .ax above since we are done using it.
		//This is in fact the most efficient way here... interesting... it works...
		MakeMI(.mov, RegMem(.ax), RamMem(.sbp,24)),
		//[cx] is where in memory we are pointing to
		MakeMI(.mov, RamMem(.ax), RegMem(.bx), Imm(8)),
		MakeMI(.jmp, RamMem(.sbp, -8)),
	]);

	//foo(1,2)
	foo_call : int = instr_index;
	TestNextManyInstr(*instr_index, cd, .[
		//push x return int value before new stack
		MakeMI(.mset, RamMem(.scp), Imm(0), Imm(8)),
		MakeMI(.add, RegMem(.scp), Imm(8)),
		//push y return int value before new stack
		MakeMI(.mset, RamMem(.scp), Imm(0), Imm(8)),
		MakeMI(.add, RegMem(.scp), Imm(8)),
		//Push previous function values stack here for the new function
		MakeMI(.push_all_stack_reg),
		//Push where we need to jmp back to
		MakeMI(.add, RegMem(.ax), RegMem(.ip), Imm(foo_call+15)),
		MakeMI(.push, RegMem(.ax), Imm(8)),
		//Reset the .sbp for the new stack
		MakeMI(.mov, RegMem(.sbp), RegMem(.scp)),
		//Push on integer 1 argument
		MakeMI(.push, Imm(1), Imm(8)),
		//Push on integer 2 argument
		MakeMI(.push, Imm(2), Imm(8)),
		//Push on return pointer to *x
		MakeMI(.add, RegMem(.ax), RegMem(.sbp), Imm(0)),
		MakeMI(.push, RegMem(.ax), Imm(8)),
		//Push on return pointer to *y
		MakeMI(.add, RegMem(.ax), RegMem(.sbp), Imm(8)),
		MakeMI(.push, RegMem(.ax), Imm(8)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(0)),
		//Reload the previous stack (skip over last value for jmp call return)
		MakeMI(.sub, RegMem(.scp), RegMem(.sbp), Imm(8)),
		MakeMI(.pop_all_stack_reg),
	]);

	//x,y := foo(1,2)
	TestNextManyInstr(*instr_index, cd, .[
		// MakeMI(.mov, RegMem(.scp), Imm(0)),
		MakeMI(.add, RegMem(.scp), RegMem(.sbp), Imm(0)),
		MakeMI(.push, RamMem(.sbp,0), Imm(8)),
		MakeMI(.push, RamMem(.sbp,8), Imm(8)),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest
}


Test_CompileStruct :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	//TODO Test with pointer dereference in struct
	//maybe should be doing pointer variables first

	//TODO Also test with a struct that contains a struct
	//so we can try s.a.b for example

	cd = CompileCode(cs,
#string DONE
Test :: struct {
	x : int;
	y : int;
	p : *int;
	//TODO Could do floats in a spearate struct test below
	// z : float;
}
main :: () {
	t : Test;
	t.x = 1;
	t.y = 2;
	t.p = *t.x;
	//TODO Need to have a test where we have a pointer to a struct
	//and then something like t.p.*.a. It should work but worth testing
	t.y = t.p.*;

	t2 : Test = t;
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(cd.all_type_info_struct.count, 1);
	s_info : TypeInfoStruct;
	if count_equal {
		s_info = cd.all_type_info_struct[0];
		AssertEquals(TypeInfoTag.STRUCT, s_info.type_enum);
		AssertEquals("Test", s_info.name);
		AssertEquals(24, s_info.runtime_size);
		AssertEquals(18, s_info.last_token_index);

		//TODO Could make this a function if we reuse. Also we will likely add some later
		//for example for String struct and for Resizable_Array struct
		// created_struct_members := array_view(cd.all_type_info_struct_members, cd.user_struct_member_start, 3);
		// count_equal = AssertEquals(3, created_struct_members.count);
		// if count_equal {
			m0 : TypeInfoStructMember = s_info.struct_members[0];
			AssertEquals(TypeInfoTag.INTEGER, m0.t_info.type_enum);
			AssertEquals("x", m0.name);
			AssertEquals(0, m0.offset_in_bytes);
			AssertEquals(8, m0.t_info.runtime_size);

			m1 : TypeInfoStructMember = s_info.struct_members[1];
			AssertEquals(TypeInfoTag.INTEGER, m1.t_info.type_enum);
			AssertEquals("y", m1.name);
			AssertEquals(8, m1.offset_in_bytes);
			AssertEquals(8, m1.t_info.runtime_size);

			m2 : TypeInfoStructMember = s_info.struct_members[2];
			AssertEquals(TypeInfoTag.POINTER, m2.t_info.type_enum);
			AssertEquals("p", m2.name);
			AssertEquals(16, m2.offset_in_bytes);
			AssertEquals(8, m2.t_info.runtime_size);
		// }
	}

	var_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("t", cd.all_type_info_struct[0], RamMem(.sbp,0)),
		VarDecl("t2", cd.all_type_info_struct[0], RamMem(.sbp,24)),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];
	t2_var := cd.all_variables[1];

	//NOTE : Putting here for clarity to show what we are setting after the t variable.
	after_t_op := t2_var.op;
	TestManyInstr(cd.all_music_instructions, .[
		//Initialize t variable
		MakeMI(.mset, t_var.op, Imm(0), Imm(s_info.runtime_size)),
		//Set x member
		MakeMI(.mov, RamMem(.sbp,0), Imm(1), Imm(8)),
		//Set y member
		MakeMI(.mov, RamMem(.sbp,8), Imm(2), Imm(8)),

		//Get address *x
		MakeMI(.add, after_t_op, RegMem(.sbp), Imm(0)),
		//Assign t.p = *x
		MakeMI(.mov, RamMem(.sbp,16), after_t_op, Imm(8)),

		//Get p.* dereference
		MakeMI(.mov, after_t_op, RamMem(.sbp,16), Imm(8)),
		//Assign t.y = t.p.*
		MakeMI(.mov, RegMem(.r0), after_t_op, Imm(8)),
		MakeMI(.mov, RamMem(.sbp,8), RamMem(.r0), Imm(8)),

		//Initialize and set t2
		MakeMI(.mov, t2_var.op, RamMem(.sbp,0), Imm(s_info.runtime_size)),
		MakeMI(.exit),
	]);

		//TODO Update tests to also include float
		//TODO Should likely to some simpler float tests before using floats with structs and functions
		// TestInstr(MakeMI(.mov, RamMem(.sbp,8), FImm(1.0), Imm(8)), cd.all_music_instructions[1]);


	/*Actually we do want to store all variable information for debug builds
	so that we can allow the debugger to access variable by name for example.
	*/
	//TODO We reset the stack at the end of function.
	//Maybe we should have an all variables array for testing
	//and also later to store global variables...
	//TODO Another way to test this is by directly passing in to
	//DFSPostOrder(VisitStatementNode) and preload data if we want
	//to test structs and then check cd.variable_stack. Variables are not
	//used outside functions so it does not really make sense to store them outside.
	#if 0 {
	count_equal = AssertEquals(1, cd.variable_stack.count);
	if count_equal {
		var := cd.variable_stack[0];
		AssertEquals("t", var.name);
		AssertEquals(TypeInfoTag.STRUCT, var.t_info.type_enum);
		AssertEquals(16, var.t_info.runtime_size);
		AssertEquals(0, var.rel_stack_byte);

		AssertEquals(16, cd.function_byte_offset_from_sbp);
	}
	}
} @UnitTest

Test_OutOfOrder :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {}
Foo :: (t : Test) {}
Test :: struct {}
DONE,,unit_test_alloc);

	count_equal := AssertEquals(cd.all_type_info_struct.count, 1);
	s_info : *TypeInfoStruct;
	if count_equal {
		s_info = cd.all_type_info_struct[0];
		AssertEquals(TypeInfoTag.STRUCT, s_info.type_enum);
		AssertEquals("Test", s_info.name);
		AssertEquals(0, s_info.runtime_size);
	}

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	if count_equal {
		AssertEquals("main", cd.all_function_declarations[0].name);
		AssertEquals("Foo", cd.all_function_declarations[1].name);

		count_equal = AssertEquals(1, cd.all_function_arguments.count);
		if count_equal {
			AssertEquals(cd.all_function_declarations[1].id, cd.all_function_arguments[0].function_id);
			AssertEquals("t", cd.all_function_arguments[0].name);
			AssertEquals(cast(*TypeInfo) s_info, cd.all_function_arguments[0].t_info);
			AssertEquals(TypeInfoTag.STRUCT, cd.all_function_arguments[0].t_info.type_enum);
			AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);
		}
	}

	// AssertEquals(0, cd.all_music_instructions.count);

} @UnitTest

Test_ParseEnum :: () {
	ptd := MakeParseTestData();

	/*
		 ::
	  /    \
	Test   enum
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test :: enum { test_0; }");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "Test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_ENUM, "enum")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(CodeTokenType.IDENT, node.value.token_type);
	AssertEquals("test_0", node.value.token_string);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);



	/*
		   ::
	   /      \
	test_0     10
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	//NOTE : Jai allows negative enum values so we do the same.
	//Maybe we shouldn't as it requires the negative parsing as extra
	//but maybe it will be useful for someone down the line.
	LexCodeTokens(*ptd.cd.lexer, "Test :: enum { test_0 :: 10; test_1 :: -2;}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "Test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_ENUM, "enum")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);

	node = ParseExpression(ptd.cd, S64_MIN);
	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "test_0")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 10)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

	node = ParseExpression(ptd.cd, S64_MIN);
	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "test_1")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);

} @UnitTest
/*DOC : Remember that enums are just integers in memory
and we lose the enum concept at runtime. 
THEREFORE we can have enum values that are not in the enum range
and this is still valid. This is also how jai behaves.
*/
Test_CompileEnum :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
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
DONE,,unit_test_alloc);

	count_equal = AssertEquals(cd.all_type_info_enum.count, 2);
	if !count_equal return;
	test_info : *TypeInfoEnum = cd.all_type_info_enum[0];;
	AssertEquals(TypeInfoTag.ENUM, test_info.type_enum);
	AssertEquals(8, test_info.runtime_size);
	AssertEquals("Test", test_info.name);
	count_equal = AssertEquals(3, test_info.names.count);	
	if !count_equal return;
	AssertEquals("test_0", test_info.names[0]);
	AssertEquals("test_1", test_info.names[1]);
	AssertEquals("test_2", test_info.names[2]);
	count_equal = AssertEquals(3, test_info.values.count);
	if !count_equal return;
	AssertEquals(0, test_info.values[0]);
	AssertEquals(1, test_info.values[1]);
	AssertEquals(2, test_info.values[2]);


	t2_info : *TypeInfoEnum = cd.all_type_info_enum[1];;
	AssertEquals(TypeInfoTag.ENUM, t2_info.type_enum);
	AssertEquals(8, t2_info.runtime_size);
	AssertEquals("T2", t2_info.name);
	count_equal = AssertEquals(3, t2_info.names.count);	
	if !count_equal return;
	AssertEquals("test_0", t2_info.names[0]);
	AssertEquals("test_1", t2_info.names[1]);
	AssertEquals("test_2", t2_info.names[2]);
	count_equal = AssertEquals(3, t2_info.values.count);
	if !count_equal return;
	AssertEquals(1, t2_info.values[0]);
	AssertEquals(-10, t2_info.values[1]);
	AssertEquals(24, t2_info.values[2]);


	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t", test_info),
		VarDecl("t2", t2_info),
		VarDecl("t3", t2_info),
		VarDecl("i", *cd.int_type_info),
		VarDecl("e", t2_info),
		VarDecl("e2", test_info),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];
	t2_var := cd.all_variables[1];
	t3_var := cd.all_variables[2];
	i_var := cd.all_variables[3];
	e_var := cd.all_variables[4];
	e2_var := cd.all_variables[5];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//t : Test;
		MakeMI(.mset, t_var.op, Imm(0), Imm(test_info.runtime_size)),
  		// t = Test.test_1;
		MakeMI(.mov, t_var.op, Imm(1), Imm(test_info.runtime_size)),
		// t2 := T2.test_1;
		MakeMI(.mov, t2_var.op, Imm(-10), Imm(t2_info.runtime_size)),
		// t3 := t2;
		MakeMI(.mov, t3_var.op, t2_var.op, Imm(t2_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		// i := cast(int) t2;
		MakeMI(.mov, i_var.op, t2_var.op, Imm(cd.int_type_info.runtime_size)),
		// e := cast(T2) -10;
		MakeMI(.mov, e_var.op, Imm(-10), Imm(t2_info.runtime_size)),
  		// e2 := cast(Test) 3;
		MakeMI(.mov, e2_var.op, Imm(3), Imm(test_info.runtime_size)),

		MakeMI(.exit),
	]);


	AssertEquals(instr_index, cd.all_music_instructions.count);


//TEST INVALID cannot auto cast integer to enum
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
Test :: enum {
	test_0;
	test_1;
	test_2;
}
main :: () {
	t : Test = 3;
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//TEST INVALID cannot auto cast enum to integer
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
Test :: enum {
	test_0;
	test_1;
	test_2;
}
main :: () {
	i : int = Test.test_1;
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


//TEST Invalid float value on enum
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
Test :: enum {
	test_0 :: 3.1;
}
main :: () {}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//TEST Invalid identifier name test instead of Test
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
Test :: enum {
	test_0;
}
main :: () {
  t := test.test_0;
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//TEST Invalid identifier value on enum
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
Test :: enum {
	test_0 :: SOME_IDENTIFIER;
}
main :: () {}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//TEST Invalid single colon
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
Test :: enum {
	test_0 : SOME_IDENTIFIER;
}
main :: () {}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


//TEST INVALID cannot have some values set and some not set
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
Test :: enum {
	test_0 :: 2;
	test_1;
	test_2 :: -2;
}
main :: () {}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


} @UnitTest

Test_ParseConstant :: () {
	ptd := MakeParseTestData();

	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x :: 1;");
	/*
		  ::
		 /  \
		x    1
	*/
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x :: -1;");
	/*
		  ::
		 /  \
		x    -
		      \
		       1
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);




	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "b :: true;");


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x :: y + 1;");
	/*
		  ::
		 /  \
		x    +
		    / \
		   y   1
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : int : y + 1;");
	/*
		    :
		 /    \
		:      +
	  / \	   / \
	 x	 int y   1
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);




	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "b :: true;");
	/*
		  ::
		 /  \
		b   true
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "b")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_TRUE, "true")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	//TODO This works but I don't know if I want to allow it.
	//Maybe just bool and int with "::" anyways so we can use
	//for fixed arrays and #if but no need for anything else.
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : float : 3.1;");
	/*
			  :
		   /   \
		  :     3.1
		 / \
	   x  float
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 3.1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	//TODO This works just in case but this won't be allowed anyways.
	//Only need to use ":=" for any other types on global which would
	//result in the same thing with variabels on the first stack anyways.
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : *int : 2;");
	/*
			  :
		   /   \
		  :     2
		 / \
	   x   *
	        \
	        int
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


} @UnitTest
Test_CompileConstant :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
x :: 10;
b :: true;
y : int : 2;
pi : float : 3.14159;
main :: () {}
DONE,,unit_test_alloc);

	var_index : int = 0;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("x", *cd.int_type_info, Imm(10), 0),
		VarDecl("b", *cd.bool_type_info, Imm(1), 0),
		VarDecl("y", *cd.int_type_info, Imm(2), 0),
		VarDecl("pi", *cd.float_type_info, FImm(3.14159), 0),
	]);
	if !vars_equal return;
	x_foo_var := cd.all_variables[0];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

	#if 0 {
	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//v : *void;
		MakeMI(.mset, RamMem(.scp), Imm(0), Imm(v_var.t_info.runtime_size)),
		MakeMI(.add, RegMem(.scp), Imm(v_var.t_info.runtime_size)),
		//i : * int = cast(*int) v;
		MakeMI(.push, v_var.op, Imm(i_var.t_info.runtime_size)),
	]);
	}

} @UnitTest


//TODO Decided to remove this but will leave here as a reminder
#if 0 {
Test_ParseUnaryAngle :: () {
	ptd := MakeParseTestData();

	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "<x,y>");
	/*
		<
		 \
		  ,
		 / \
	   x   y
	*/
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "<"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "<x,(x>y)>");
	/*
	    <
		  \
		   ,    
		  / \
	    x   (
          / \
         f2  <
            / \
           x   y
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "<"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		// BNode(LCToken(.IDENT, "f2")), NULL_NODE, NULL_NODE,
		// BNode(LCToken(#char "<"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

} //@UnitTest
}

/*
	tano(x,y) = int.[0,4,7];
	tano[x][y] = int.[0,4,7];
	tano(x,y..y1) = int.[0,4,7];
	tano[x][y..y1] = int.[0,4,7];
	tano(x,y..z) = int.[0,4,7];
	tano(x,y,z) = int.[0,4,7];
	tano(x,y..y+c) = int.[0,4,7];
	tano(x,y..y+c) = int.[0,4,7];
	tano(x,y,y+c) = int.[0,4,7];
	// tano(x,y)..z = int.[0,4,7];

	s1 := tano[x,y];
	s1 := tano(x,y);
	s1 : tano;
	ts : sect = tano(x,y..y1);
	ts2 : sect = tano[x][y..y1];
	ts ~= ts2;

	s1[0,0] = s1[0,2]; 
	s1(0,0) = s1(0,2);

	tano[x][y] = int.[0,4,7];

	tano(x) = int.[0,4,7];
	tano[x] = int.[0,4,7];

	tano(x,y,z) = int.[0,4,7];
	tano[x][y][z] = int.[0,4,7];
*/
/*TODO could do something like this to copy many rows
and do operations on many rows for convenience
and then copy over the row range
trows :: struct {
	t : tano;
	end_row : int;
}
operator + :: (tr : trows, i : int) -> trows {
	for tr.row..tr.end_row {
		neg_row : int = tr.row - it - 1; 
		tano(neg_row) = tano(tr.row,y0..y1) + 1;
		// tano(neg_row,0,tr.count) = tano(tr.row,y0..y1) + 1;
	}
}
then here we could do
tr1 := tano(r0..r1,x0..x1);
tr0 := tr1 + 1;
*/
Test_CompTano :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
  tano(r,x) = int.[0,4,7];

  //TODO With count (note length)
  // tano(r,x,c) = int.[0,4,7];
  // tano(r:rc,x:xl) = int.[0,4,7];
  // tano(r,x,.[c0,c1,c2]) = int.[0,4,7];
  // tano(r,x,c0) = 0;
  // tano(r,x,c1) = 4;
  // tano(r,x,c2) = 7;
  //TODO With x range (note length)
  // tano(r,x0..x1) = int.[0,4,7];
  // tano(r,x0->x1) = tano(r,y0<-y1);
  // tano(r,x0..x1) = tano(r,y0);
  // tano(r,x0) = tano(r,y0..y1);
  // tano(r,x0) = tano(r0..r1,x0..x1);
  //TODO Maybe ROW_RANGE is just a convenience and not part of the type...? 
  //can have a .set_row_range instruction to set it and then 
  //set it back. This would be more efficient for copying
  //and doing operations on multiple rows.
  // tano(r0..r1) = int.[0,4,7];
  // tano(r) = tano(r0..r1);
  // tano(r) = tano(r0..r1) + 1;
  // tano(r0..r1) = tano(r) + 1;
  // tano(r) = tano(r0)..tano(r1);
  // tano(r0..r1) = tano(r,y0..y1);
  // for r0..r1 tano(it,y2) = tano(r,y0..y1) + 1;
  // tano(r0..r1,y2) = tano(r,y0..y1) + 1;
  //TODO clear and mov I think
  // tano(r,x) := int.[0,4,7];
  //OR clear and mov?
  // tano(r,x) ~= int.[0,4,7];
  //Then this could be clear.
  // ~tano(r,x);
  //Could use
  // t0 := tano(r,x);
  // t1 : tano;
  //TODO could set t1 = (-1,0), so we set temp in row (-1)
  // t1 := tano(r,x) + 1;
  // t1 = t0;
  // t1 .= t0;
  //to set it as a struct.
  //tano(r..r+10) = tano(0..10);
  //for 0..10 tano(r+it) = tano(it);
}
DONE,,unit_test_alloc);

	#if 0 {
	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("a", cast(*TypeInfo) view_info),
	]);
	if !vars_equal return;
	a_var := cd.all_variables[0];


	//TODO Can remove instr_index and just use expected_mi.count in TestNextManyInstr
	instr_index : int = 0;
	//push 0,3,7 on stack
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(3), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(7), Imm(8)),
	]);

	//TODO CAN MAKE A FUNCTION FOR THIS SPECIFIC CHECK SINCE WE WILL LIKELY REUSE IT
	//a : [] int = int.[0,3,7]
	a_count_op := a_var.op;
	a_data_op := AddOperandOffset(8, a_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RamMem(.sbp, 16), RamMem(.sbp,0), Imm(fixed_info.runtime_size)),
		//a.count
		MakeMI(.mov, a_var.op, Imm(fixed_info.array_count), Imm(cd.int_type_info.runtime_size)),
		//a.data
		MakeMI(.add, a_data_op, RegMem(.sbp), Imm(16)),

		// MakeMI(.push, Imm(fixed_info.array_count)),
		// MakeMI(.add, RamMem(.scp), RegMem(.sbp), Imm(0)),
		// MakeMI(.add, RegMem(.scp), Imm(8)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);	
	}
} //@UnitTest

//TODO Fix this test once we update music mem now.
//Will comment out since we will just redo it anyways.
Test_CompMusicMem :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	//TODO Should these be functions or preload?
	//Probably just functions would be more flexible overall.
	//Need to create the muscalls to CreateRow. Can likely
	//reuse the code from the asm create data.
	// CreateRow();
	// CreateRows();

	//Check fixed and array view here
	//TODO Also try doing music_memory = music_memory
	a : [] int = int.[0,3,7];
	munit[0][2] = a;
	// musica[0][2] = a;
	// muse[0][2] = a;
	// mrow[0][2] = a;

	// tano[0][0] = 11;
	// tymo[0][0] = 11;
	// blow[0][0] = 11;
	// mUsIc[0][0] = 11;
	//TODO Finish testing this instruction and also
	//finish the Test_CompileArray test refactor with new 
	//testing functions
	munit[0][0] = 11;
	munit[0][1] = int.[0,3,7];
	//TODO Maybe allowing all of these is best and we can just
	//start with <x,y> and tano(x,y) and gradually add the rest
	//like also relative offset from a specific tano.
	// <x,y> = int.[0,3,7];
	// [x,y] = int.[0,3,7];
	// (x,y) = int.[0,3,7];
	// t(x,y) = int.[0,3,7];
	// tano(x,y) = int.[0,3,7];
	// tano[x][y] = int.[0,3,7];
	// Tano(x,y) = int.[0,3,7];
	// tano<x,y> = int.[0,3,7];
	// Copy(<x,y>, <a,b>, 10);
	// tano(x,y..y1) = int.[0,3,7];
	// tano[x][y..y1] = int.[0,3,7];
	//TODO Maybe we can add something like this later.
	//It does look/feel good.
	//LIKELY SHOULD ADD THIS AS IT IS BEING USED LATER WITH PEOPLE.
	//Can just do basic syntax and then update/add to it later based on usage.
	// <a,b..b1> += 1;
	// for b..b1 <a,it> += 1;
	// <a,b,b1> += 1;
	// <a,b..row> += 1; //Maybe this for entire row
	// <a> += 1; //Maybe this for entire row
	// <1> = <0>;
	// <10> = <0..3> + 1;
	//TODO We could allow just 1 range in this case at compile-time
	//to avoid having to check if the sizes are the same and avoid errors
	//and can be on either side for convenience, but not both
	// <a,b> = <x,y..y1> + 1;
	// <a,b> = <x,y..y1>;
	// <a,b..b1> = <x,y>;
	//The range would only be usable in certain cases
	//WE CANNOT DO OBVIOUSLY
	//<a,b> = <x,y..y1> + <z,w>;

	//Maybe this could be a clear and then equals
	// mrow[0][2] ~= a;
	// mrow[0][2] ~~= a;
	// mrow[0][2] .= a;
	//Then this would be just a clear
	// ~mrow[0][2];
	// ~~mrow[0][2];

	//TODO These could be relative to the starting point
	//so then we can have sections
	// r1 : MRow = tano[1];
	// tano[0][1] = tano[0][0] + int.[1,-1];
	// r2 : MRow = munit[2];
	// r2 : MUnit = munit[2][0];
	// r2 : tano = munit[2][0];
	// r2[0][1] / int.[0,1,2];
	//This is contrary motion for 2 dimensions
	// r2[0][1] + int.[1,-1];

	//TODO implement integer array literals
	//Maybe do CompilerErrors first? 
	//Also range syntax for music memory
	//can likely just store them in memory instead of NODE_VALUE_LIST
	//and also do CompilerError now so we can add those as we go along.
	/*TODO How do we want to process arrays with music memory?
	I think just use array views. So if we find a fixed array
	with an op with music_mem then just add a array view to
	the stack and reference that and then we can always assume
	that the first value is count and then the array can be
	accessed through the .data pointer. This would immediately
	work with array views and resizable arrays.
	Right now all array literals create an array view but the
	above would be a more general solution. So let's see how the code
	plays out as we implement music memory. Can change it after
	if it seems reasonable to only add array views with music memory
	and not with all array literal.
	*/
	// munit[0][0] = int.[0,4,7];
	// munit[0][0] := int.[0,3,7];
	// Length(munit[0][0], 10);
	// munit[0][0].count OR munit[0][0].dim

	/*Should we have just music[x][y] or munit and mrow
	we don't need one if we don't allow accessing music
	with absolute values isntead of row-relative
	*/

	//TODO This could be copy row
	// for 0..2 mrow[it+10] = mrow[it];
	//This could be absolute values instead of row-relative values
	//so it would depend on the current row_size
	// munit[1] = munit[0];

	/*We need shift and rotate because we can't just loop over
	them since they will overlap and delete info.
	*/
	//These would be the same (shift right by 10)
	//TODO Could require ranges on both sides so that it is very
	//clear that we are dealing with ranges... not sure...
	// munit[1][20..9] = munit[0][0..9];
	// munit[1][x..9] = munit[0][y..9];
	// munit[0][0..9] >>= 10;

	//TODO Could also allow empty range to show it is a range
	//Do we want range to be explicit or just allow a start value.
	//Then it's unclear if we're moving a range or a single unit.
	// munit[1][x..] = munit[0][y..9];
	//TODO ",," can be for add to range
	// munit[1][x.+.9] = munit[0][0.+.9];
	// munit[1][x.:9] = munit[0][0.:9];
	// munit[1][x,,9] = munit[0][0,,9];
	// munit[1][x..x+9] = munit[0][0..9];

	//These would be the same (rotate right by 10)
	// munit[0][0] = munit[0][0..9] >>> 3;
	// munit[0][0..9] >>>= 3;
}
DONE,,unit_test_alloc);

	//TODO We should have a fixed array here
	#if 1 {
	count_equal = AssertEquals(2, cd.all_type_info_array.count);
	fixed_info : *TypeInfoArray;
	view_info : *TypeInfoArray;
	if count_equal {
		fixed_info = cd.all_type_info_array[0];
		AssertEquals(TypeInfoTag.ARRAY, fixed_info.type_enum);
		AssertEquals(8*3, fixed_info.runtime_size);
		AssertEquals(ArrayInfoType.FIXED, fixed_info.array_type);
		AssertEquals(3, fixed_info.array_count);
		AssertEquals(*cd.int_type_info, fixed_info.element_type);
		AssertEquals(TypeInfoTag.INTEGER, fixed_info.element_type.type_enum);
		AssertEquals(8, fixed_info.element_type.runtime_size);

		view_info = cd.all_type_info_array[1];
		AssertEquals(TypeInfoTag.ARRAY, view_info.type_enum);
		AssertEquals(cd.array_view_struct_info.runtime_size, view_info.runtime_size);
		AssertEquals(ArrayInfoType.VIEW, view_info.array_type);
		AssertEquals(-1, view_info.array_count);
		AssertEquals(*cd.int_type_info, view_info.element_type);
		AssertEquals(TypeInfoTag.INTEGER, view_info.element_type.type_enum);
		AssertEquals(8, view_info.element_type.runtime_size);
	}
	}

	

	//munit[0][0] = 11
	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, MusicMem(0,0), Imm(11))]);


	array_size : int = 3*8;
	minor_instr := MusicInstruction.[
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(3), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(7), Imm(8)),
	];
	//0,3,7
	TestNextManyInstr(*instr_index, cd, minor_instr);

	//int.[0,3,7] array view
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, RegMem(.ax), RegMem(.sbp), Imm(0))]);

	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, MusicMem(0,1), RamArray(fixed_info.array_count,RegDef.ax))]);

	//push 0,3,7 on stack for var a : [] int = int.[0,3,7]
	TestNextManyInstr(*instr_index, cd, minor_instr);

	count_equal = AssertEquals(1, cd.all_variables.count);
	if !count_equal return;
	vars_equal := TestVarDecl(VarDecl("a", view_info, RamMem(.sbp,fixed_info.runtime_size)), cd.all_variables[0]);
	if !vars_equal return;
	a_var := cd.all_variables[0];

	//initialize a : [] int = int.[0,3,7]
	a_count_op := a_var.op;
	a_data_op := AddOperandOffset(8, a_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.push, Imm(fixed_info.array_count)),
		MakeMI(.add, RamMem(.scp), RegMem(.sbp), Imm(0)),
		MakeMI(.add, RegMem(.scp), Imm(8))
	]);


	//munit[0][2] = a;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RegMem(.ax), a_count_op),
		MakeMI(.mov, RegMem(.bx), a_data_op),
		MakeMI(.mov, MusicMem(0,2), RamArray(RegDef.ax,RegDef.bx)),

		MakeMI(.exit),
	]);


	AssertEquals(instr_index, cd.all_music_instructions.count);

} //@UnitTest

Test_CompArrayLiteral :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	a : [] int = int.[0,3,7];
	fa : [2] int = int.[0,1];
	c : [] int = fa;
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(3, cd.all_type_info_array.count);
	view_info : *TypeInfoArray;
	fixed_info : *TypeInfoArray;
	f2_info : *TypeInfoArray;
	if count_equal {
		view_info = cd.all_type_info_array[1];
		AssertEquals(TypeInfoTag.ARRAY, view_info.type_enum);
		AssertEquals(16, view_info.runtime_size);
		AssertEquals(ArrayInfoType.VIEW, view_info.array_type);
		AssertEquals(-1, view_info.array_count);
		AssertEquals(*cd.int_type_info, view_info.element_type);
		AssertEquals(TypeInfoTag.INTEGER, view_info.element_type.type_enum);
		AssertEquals(8, view_info.element_type.runtime_size);

		fixed_info = cd.all_type_info_array[0];
		AssertEquals(TypeInfoTag.ARRAY, fixed_info.type_enum);
		AssertEquals(8*3, fixed_info.runtime_size);
		AssertEquals(ArrayInfoType.FIXED, fixed_info.array_type);
		AssertEquals(3, fixed_info.array_count);
		AssertEquals(*cd.int_type_info, fixed_info.element_type);
		AssertEquals(TypeInfoTag.INTEGER, fixed_info.element_type.type_enum);
		AssertEquals(8, fixed_info.element_type.runtime_size);

		f2_info = cd.all_type_info_array[2];
		AssertEquals(TypeInfoTag.ARRAY, f2_info.type_enum);
		AssertEquals(8*2, f2_info.runtime_size);
		AssertEquals(ArrayInfoType.FIXED, f2_info.array_type);
		AssertEquals(2, f2_info.array_count);
		AssertEquals(*cd.int_type_info, f2_info.element_type);
		AssertEquals(TypeInfoTag.INTEGER, f2_info.element_type.type_enum);
		AssertEquals(8, f2_info.element_type.runtime_size);
	}

	fa_pos : int = 40;
	c_pos : int = fa_pos + f2_info.runtime_size;
	v_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*v_index, cd.all_variables, .[
		VarDecl("a", view_info, RamMem(.sbp,0)),
		VarDecl("fa", f2_info, RamMem(.sbp,fa_pos)),
		VarDecl("c", view_info, RamMem(.sbp,c_pos))
	]);
	if !vars_equal return;
	a_var := cd.all_variables[0];
	fa_var := cd.all_variables[1];
	c_var := cd.all_variables[2];


	//TODO Can remove instr_index and just use expected_mi.count in TestNextManyInstr
	instr_index : int = 0;
	//TODO CAN MAKE A FUNCTION FOR THIS SPECIFIC CHECK SINCE WE WILL LIKELY REUSE IT
	//a : [] int = int.[0,3,7]
	a_count_op := a_var.op;
	a_data_op := AddOperandOffset(8, a_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//push 0,3,7 on stack
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(3), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(7), Imm(8)),

		//Copy the array literal after the a_var from wherever it was.
		//We don't know where the array literal could be on the stack so we need to do it this way.
		MakeMI(.mov, RamMem(.sbp, 16), RamMem(.sbp,0), Imm(fixed_info.runtime_size)),
		//a.count
		MakeMI(.mov, a_var.op, Imm(fixed_info.array_count), Imm(cd.int_type_info.runtime_size)),
		//a.data
		MakeMI(.add, a_data_op, RegMem(.sbp), Imm(16)),
	]);

	//Want to makes sure that fa_var is after 3*8(array literal) + 16(fixed array)
	//since fa_var == second array literal int.[0,1]
	fa_0, fa_1 := GetMemoryAddressAsOperands(fa_var.op);
	AssertEquals(fa_pos, fa_1.int_value);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RamMem(.sbp,fa_pos+0), Imm(0), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,fa_pos+8), Imm(1), Imm(8)),

		//Copy the array literal after fa_var
		//NOTE : We optimize this out since it copies to the same place
		//and we check that fa_var.op_values[1] is in the right palce on the stack above.
		// MakeMI(.mov, RamMem(.sbp,fa_pos), RamMem(.sbp,fa_pos), Imm(f2_info.runtime_size)),
	]);

	c_0, c_1 := GetMemoryAddressAsOperands(c_var.op);
	AssertEquals(c_pos, c_1.int_value);
	TestNextManyInstr(*instr_index, cd, .[
		//c.count
		MakeMI(.mov, c_var.op, Imm(f2_info.array_count), Imm(cd.int_type_info.runtime_size)),
		//c.data
		MakeMI(.add, AddOperandOffset(8,c_var.op), fa_0, fa_1),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CompArrayLiteralFloat :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	a : [] float = float.[0.,3.,7.];
	fa := float.[0.,1.];
	c : [] float = fa;
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(3, cd.all_type_info_array.count);
	view_info : *TypeInfoArray;
	fixed_info : *TypeInfoArray;
	f2_info : *TypeInfoArray;
	if count_equal {
		view_info = cd.all_type_info_array[1];
		AssertEquals(TypeInfoTag.ARRAY, view_info.type_enum);
		AssertEquals(16, view_info.runtime_size);
		AssertEquals(ArrayInfoType.VIEW, view_info.array_type);
		AssertEquals(-1, view_info.array_count);
		AssertEquals(*cd.float_type_info, view_info.element_type);
		AssertEquals(TypeInfoTag.FLOAT, view_info.element_type.type_enum);
		AssertEquals(8, view_info.element_type.runtime_size);

		fixed_info = cd.all_type_info_array[0];
		AssertEquals(TypeInfoTag.ARRAY, fixed_info.type_enum);
		AssertEquals(8*3, fixed_info.runtime_size);
		AssertEquals(ArrayInfoType.FIXED, fixed_info.array_type);
		AssertEquals(3, fixed_info.array_count);
		AssertEquals(*cd.float_type_info, fixed_info.element_type);
		AssertEquals(TypeInfoTag.FLOAT, fixed_info.element_type.type_enum);
		AssertEquals(8, fixed_info.element_type.runtime_size);

		f2_info = cd.all_type_info_array[2];
		AssertEquals(TypeInfoTag.ARRAY, f2_info.type_enum);
		AssertEquals(8*2, f2_info.runtime_size);
		AssertEquals(ArrayInfoType.FIXED, f2_info.array_type);
		AssertEquals(2, f2_info.array_count);
		AssertEquals(*cd.float_type_info, f2_info.element_type);
		AssertEquals(TypeInfoTag.FLOAT, f2_info.element_type.type_enum);
		AssertEquals(8, f2_info.element_type.runtime_size);
	}

	fa_pos : int = 40;
	c_pos : int = fa_pos + f2_info.runtime_size;
	v_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*v_index, cd.all_variables, .[
		VarDecl("a", view_info, RamMem(.sbp,0)),
		VarDecl("fa", f2_info, RamMem(.sbp,fa_pos)),
		VarDecl("c", view_info, RamMem(.sbp,c_pos))
	]);
	if !vars_equal return;
	a_var := cd.all_variables[0];
	fa_var := cd.all_variables[1];
	c_var := cd.all_variables[2];


	//TODO Can remove instr_index and just use expected_mi.count in TestNextManyInstr
	instr_index : int = 0;
	//TODO CAN MAKE A FUNCTION FOR THIS SPECIFIC CHECK SINCE WE WILL LIKELY REUSE IT
	//a : [] int = int.[0,3,7]
	a_count_op := a_var.op;
	a_data_op := AddOperandOffset(8, a_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//push 0,3,7 on stack
		MakeMI(.mov, RamMem(.sbp,0), FImm(0), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,8), FImm(3), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,16), FImm(7), Imm(8)),

		//Copy the array literal after the a_var from wherever it was.
		//We don't know where the array literal could be on the stack so we need to do it this way.
		MakeMI(.mov, RamMem(.sbp, 16), RamMem(.sbp,0), Imm(fixed_info.runtime_size)),
		//a.count
		MakeMI(.mov, a_var.op, Imm(fixed_info.array_count), Imm(cd.int_type_info.runtime_size)),
		//a.data
		MakeMI(.add, a_data_op, RegMem(.sbp), Imm(16)),
	]);

	//Want to makes sure that fa_var is after 3*8(array literal) + 16(fixed array)
	//since fa_var == second array literal int.[0,1]
	fa_0, fa_1 := GetMemoryAddressAsOperands(fa_var.op);
	AssertEquals(fa_pos, fa_1.int_value);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RamMem(.sbp,fa_pos+0), FImm(0), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,fa_pos+8), FImm(1), Imm(8)),

		//Copy the array literal after fa_var
		//NOTE : We optimize this out since it copies to the same place
		//and we check that fa_var.op_values[1] is in the right palce on the stack above.
		// MakeMI(.mov, RamMem(.sbp,fa_pos), RamMem(.sbp,fa_pos), Imm(f2_info.runtime_size)),
	]);

	c_0, c_1 := GetMemoryAddressAsOperands(c_var.op);
	AssertEquals(c_pos, c_1.int_value);
	TestNextManyInstr(*instr_index, cd, .[
		//c.count
		MakeMI(.mov, c_var.op, Imm(f2_info.array_count), Imm(cd.int_type_info.runtime_size)),
		//c.data
		MakeMI(.add, AddOperandOffset(8,c_var.op), fa_0, fa_1),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CompArrayLiteralAutocast :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	fa : [] float = float.[0,4,7];
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_type_info_array.count);
	view_info : *TypeInfoArray;
	fixed_info : *TypeInfoArray;
	if count_equal {
		view_info = cd.all_type_info_array[1];
		AssertEquals(TypeInfoTag.ARRAY, view_info.type_enum);
		AssertEquals(16, view_info.runtime_size);
		AssertEquals(ArrayInfoType.VIEW, view_info.array_type);
		AssertEquals(-1, view_info.array_count);
		AssertEquals(*cd.float_type_info, view_info.element_type);
		AssertEquals(TypeInfoTag.FLOAT, view_info.element_type.type_enum);
		AssertEquals(8, view_info.element_type.runtime_size);

		fixed_info = cd.all_type_info_array[0];
		AssertEquals(TypeInfoTag.ARRAY, fixed_info.type_enum);
		AssertEquals(8*3, fixed_info.runtime_size);
		AssertEquals(ArrayInfoType.FIXED, fixed_info.array_type);
		AssertEquals(3, fixed_info.array_count);
		AssertEquals(*cd.float_type_info, fixed_info.element_type);
		AssertEquals(TypeInfoTag.FLOAT, fixed_info.element_type.type_enum);
		AssertEquals(8, fixed_info.element_type.runtime_size);
	}

	v_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*v_index, cd.all_variables, .[
		VarDecl("fa", view_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	fa_var := cd.all_variables[0];

	//TODO Can remove instr_index and just use expected_mi.count in TestNextManyInstr
	instr_index : int = 0;
	//TODO CAN MAKE A FUNCTION FOR THIS SPECIFIC CHECK SINCE WE WILL LIKELY REUSE IT
	//a : [] int = int.[0,3,7]
	fa_count_op := fa_var.op;
	fa_data_op := AddOperandOffset(8, fa_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//push 0,3,7 on stack
		MakeMI(.itof, RamMem(.sbp,0), Imm(0)),
		MakeMI(.itof, RamMem(.sbp,8), Imm(4)),
		MakeMI(.itof, RamMem(.sbp,16), Imm(7)),

		//Copy the array literal after the fa_var from wherever it was.
		//We don't know where the array literal could be on the stack so we need to do it this way.
		MakeMI(.mov, RamMem(.sbp, 16), RamMem(.sbp,0), Imm(fixed_info.runtime_size)),
		//a.count
		MakeMI(.mov, fa_var.op, Imm(fixed_info.array_count), Imm(cd.int_type_info.runtime_size)),
		//a.data
		MakeMI(.add, fa_data_op, RegMem(.sbp), Imm(16)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

/*TODO We never did test for something like
b : [4] int = int.[0,1,2,3];
I think this would duplicate the fixed array right now
or maybe note even work should test
*/
#if 0 {
Test_FixedArrayLiteral :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	cd = CompileCode(cs,
#string DONE
main :: () {
	b : [4] int = int.[0,1,2,3];
}
DONE,,unit_test_alloc);
} @UnitTest
}

//TODO Make CompileArrayErrors
//eg trying to do a : [] int = b when b was not declared yet.
#if 1 {
Test_CompileArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	//Fixed array
	fa : [4] int;
	fc : int = fa.count;
	fa[1] = 10;
	fa.data[1] = 10;
	fi : int = fa[1];
	fi = fa.data[1];

	//TODO FROM HERE check array view and also update dereference
	//and then cleanup "[" code and maybe move with other operators OR NOT if it's to different right now
	//then fix MultiArray and then check struct "." and music mem
	//Array view
	a : [] int = fa;
	c : int = a.count;
	a[1] = 10;
	a.data[1] = 10; //Should be the same as above
	i : int = a[1];
	i = a.data[1];

	/*
	add ax sbp (b - stack offset for that var)
	add ax 8
	mul bx (1-var) (runtime_size of element type)
	add ax bx
	op = [ax]
	Then multi-dimensional array would do the same thing
	except we start from [ax] so only add 8
	So need to check that 2nd op is .NONE or not basically
	and that would work for heap memory as well i think
	*/
	// d : *int = b.data;
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_type_info_array.count);
	if count_equal {
		fixed_info := cd.all_type_info_array[0];
		AssertEquals(TypeInfoTag.ARRAY, fixed_info.type_enum);
		AssertEquals(32, fixed_info.runtime_size);
		AssertEquals(ArrayInfoType.FIXED, fixed_info.array_type);
		AssertEquals(4, fixed_info.array_count);
		AssertEquals(*cd.int_type_info, fixed_info.element_type);
		AssertEquals(TypeInfoTag.INTEGER, fixed_info.element_type.type_enum);
		AssertEquals(8, fixed_info.element_type.runtime_size);

		//TODO Put this back once we finish the array assignment code.
		view_info := cd.all_type_info_array[1];
		AssertEquals(TypeInfoTag.ARRAY, view_info.type_enum);
		AssertEquals(16, view_info.runtime_size);
		AssertEquals(ArrayInfoType.VIEW, view_info.array_type);
		AssertEquals(-1, view_info.array_count);
		AssertEquals(*cd.int_type_info, view_info.element_type);
		AssertEquals(TypeInfoTag.INTEGER, view_info.element_type.type_enum);
		AssertEquals(8, view_info.element_type.runtime_size);
	}

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("fa", cd.all_type_info_array[0]),
		VarDecl("fc", *cd.int_type_info),
		VarDecl("fi", *cd.int_type_info),
		VarDecl("a", cd.all_type_info_array[1]),
		VarDecl("c", *cd.int_type_info),
		VarDecl("i", *cd.int_type_info),
	]);

	if !vars_equal return;

	fa_var := cd.all_variables[0];
	fc_var := cd.all_variables[1];
	fi_var := cd.all_variables[2];
	a_var := cd.all_variables[3];
	c_var := cd.all_variables[4];
	i_var := cd.all_variables[5];


	//TODO We could pull some of these groups out if we reuse certain instruction sets
	//since then that would be consistent with the compiler as well. Let's see over time.
	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//Initialize fa : [4] int
		MakeMI(.mset, fa_var.op, Imm(0), Imm(fa_var.t_info.runtime_size)),
		//fc : int = b.count (fixed array count)
		MakeMI(.mov, fc_var.op, Imm(4), Imm(8)),
	]);

	array_access_op : MusicOperand = AddOperandOffset(8, fc_var.op);
	fa_op0, fa_op1 := GetMemoryAddressAsOperands(fa_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//fa[1]
		MakeMI(.add, array_access_op, fa_op0, fa_op1),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//fa[1] = 10;
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(cd.int_type_info.runtime_size)),
	]);

	array_data_op : MusicOperand = AddOperandOffset(8, fc_var.op);
	array_access_op = AddOperandOffset(8, array_data_op);
	TestNextManyInstr(*instr_index, cd, .[
		//fa.data
		MakeMI(.add, array_data_op, fa_op0, fa_op1),
		//fa.data[1]
		MakeMI(.mov, array_access_op, array_data_op, Imm(8)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//fa.data[1] = 10
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(cd.int_type_info.runtime_size)),
	]);

	array_access_op = AddOperandOffset(8, fc_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//fa[1]
		MakeMI(.add, array_access_op, fa_op0, fa_op1),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//fi : int = fa[1];
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, fi_var.op, RamMem(.r0), Imm(cd.int_type_info.runtime_size)),
	]);

	array_data_op = AddOperandOffset(8, fi_var.op);
	array_access_op = AddOperandOffset(8, array_data_op);
	TestNextManyInstr(*instr_index, cd, .[
		//fa.data
		MakeMI(.add, array_data_op, fa_op0, fa_op1),
		//fa.data[1]
		MakeMI(.mov, array_access_op, array_data_op, Imm(8)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//fi = fa.data[1];
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, fi_var.op, RamMem(.r0), Imm(cd.int_type_info.runtime_size)),
	]);

	a_data_op := AddOperandOffset(8, a_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//Initialize a : [] int = fa;
		//a.count = fa.count
		MakeMI(.mov, a_var.op, Imm(cd.all_type_info_array[0].array_count), Imm(cd.int_type_info.runtime_size)),
		//a.data = fa.data
		MakeMI(.add, a_data_op, fa_op0, fa_op1),
		//c : int = a.count;
		MakeMI(.mov, c_var.op, a_var.op, Imm(cd.int_type_info.runtime_size)),
	]);

	//a[1] is on stack right after c_var
	array_access_op = AddOperandOffset(8, c_var.op);
	a_0, a_1 := GetMemoryAddressAsOperands(a_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//a[1]
		MakeMI(.add, RegMem(.ax), a_0, a_1),
		MakeMI(.add, RegMem(.ax), Imm(8)),
		MakeMI(.mov, array_access_op, RamMem(.ax)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//a.data[1] = 10;
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(cd.int_type_info.runtime_size)),
	]);

	//a.data[1] is on stack right after c_var
	array_access_op = AddOperandOffset(8, c_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//a.data[1]
		MakeMI(.mov, array_access_op, a_data_op, Imm(8)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[1].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//a.data[1] = 10;
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(cd.int_type_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//a[1]
		MakeMI(.add, RegMem(.ax), a_0, a_1),
		MakeMI(.add, RegMem(.ax), Imm(8)),
		MakeMI(.mov, array_access_op, RamMem(.ax)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[1].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//i : int = a[1];
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, i_var.op, RamMem(.r0), Imm(cd.int_type_info.runtime_size)),
	]);

	array_access_op = AddOperandOffset(8, i_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//a.data[1]
		MakeMI(.mov, array_access_op, a_data_op, Imm(8)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[1].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//i = a.data[1];
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, i_var.op, RamMem(.r0), Imm(cd.int_type_info.runtime_size)),
	]);

	AssertEquals(cd.all_music_instructions.count-1, instr_index);

} @UnitTest
}

//TODO Decided to just do this in tests to not have to update the instructions later
#if 0 {
Test_CompArrayAccess :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	ta : [2] Test;
	ta[0].x = 5;

	test2 : [1] T2;
	test2[0].arr[1] = ta[0].x;

	// fa : [] int = NewArray(int, 4);
	// ap : *[] int = *fa;
	// ap.*[0] = 3;
}
Test :: struct {
	x : int;
}
T2 :: struct {
	arr : [2] int;
}
DONE,,unit_test_alloc);

	print(cd.disassembly);

	test_info, found_test_info := GetTypeInfoStructByName("Test", cd.all_type_info_struct);
	count_equal = AssertEquals(true, found_test_info);
	if !count_equal return;

	t2_info, found_t2_info := GetTypeInfoStructByName("T2", cd.all_type_info_struct);
	count_equal = AssertEquals(true, found_t2_info);
	if !count_equal return;

	//[2] int from T2 struct, [4] int, [2] Test and [1] T2
	count_equal = AssertEquals(3, cd.all_type_info_array.count);
	if count_equal {
		t2_array := cd.all_type_info_array[2];
		AssertEquals(TypeInfoTag.ARRAY, t2_array.type_enum);
		AssertEquals(t2_info.runtime_size, t2_array.runtime_size);
		AssertEquals(ArrayInfoType.FIXED, t2_array.array_type);
		AssertEquals(1, t2_array.array_count);
		AssertEquals(*t2_info.info, t2_array.element_type);
		AssertEquals(TypeInfoTag.STRUCT, t2_array.element_type.type_enum);
		AssertEquals(t2_info.runtime_size, t2_array.element_type.runtime_size);
	}

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("ta", cd.all_type_info_array[1]),
		VarDecl("test2", cd.all_type_info_array[2]),
	]);

	if !vars_equal return;

	ta_var := cd.all_variables[0];
	test2_var := cd.all_variables[1];


	//TODO We could pull some of these groups out if we reuse certain instruction sets
	//since then that would be consistent with the compiler as well. Let's see over time.
	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//Initialize fa : [4] int
		MakeMI(.mset, ta_var.op, Imm(0), Imm(ta_var.t_info.runtime_size)),
	]);

	#if 0 {
	array_access_op : MusicOperand = AddOperandOffset(8, fc_var.op);
	fa_op0, fa_op1 := GetMemoryAddressAsOperands(fa_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//fa[0] = 2;
		MakeMI(.add, array_access_op, fa_op0, fa_op1),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//fa[1] = fa[0];
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(cd.int_type_info.runtime_size)),
	]);

	array_data_op : MusicOperand = AddOperandOffset(8, fc_var.op);
	array_access_op = AddOperandOffset(8, array_data_op);
	TestNextManyInstr(*instr_index, cd, .[
		//fa.data
		MakeMI(.add, array_data_op, fa_op0, fa_op1),
		//fa.data[1]
		MakeMI(.mov, array_access_op, array_data_op, Imm(8)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//fa.data[1] = 10
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(cd.int_type_info.runtime_size)),
	]);

	array_access_op = AddOperandOffset(8, fc_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		//fa[1]
		MakeMI(.add, array_access_op, fa_op0, fa_op1),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//fi : int = fa[1];
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, fi_var.op, RamMem(.r0), Imm(cd.int_type_info.runtime_size)),
	]);

	array_data_op = AddOperandOffset(8, fi_var.op);
	array_access_op = AddOperandOffset(8, array_data_op);
	TestNextManyInstr(*instr_index, cd, .[
		//fa.data
		MakeMI(.add, array_data_op, fa_op0, fa_op1),
		//fa.data[1]
		MakeMI(.mov, array_access_op, array_data_op, Imm(8)),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(cd.all_type_info_array[0].element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//fi = fa.data[1];
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, fi_var.op, RamMem(.r0), Imm(cd.int_type_info.runtime_size)),
	]);
	AssertEquals(cd.all_music_instructions.count-1, instr_index);
	}


} @UnitTest
}

//TODO FROM HERE do autocasting (int->float) 
//OR start on spaces maybe start with circle 
//and then update with shapes a bit before starting on 3d shapes
Test_CompStructLiteral :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	n := neume.{7.,2,0.,1.};
	ne := neume.{};
	t := tano.{0,x_end=2.};
	t2 := tano.{row_end=1,mspace_start=1};

	test := Test.{10,3.1};
	test2 := Test.{x=2};
	teste := Test.{};

	//Test autocast here (could make separate test here)
	t_auto := tano.{0,x_end=2};
	n_auto := neume.{4,0,0,1};
	test_auto := Test.{y=3};
}
Test :: struct {
	x : int;
	y : float;
}
DONE,,unit_test_alloc);

	test_info, found_test_info := GetTypeInfoStructByName("Test", cd.all_type_info_struct);
	AssertEquals(true, found_test_info);
	if !found_test_info return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("n", *cd.neume_struct_info),
		VarDecl("ne", *cd.neume_struct_info),
		VarDecl("t", *cd.tano_struct_info),
		VarDecl("t2", *cd.tano_struct_info),

		VarDecl("test", test_info),
		VarDecl("test2", test_info),
		VarDecl("teste", test_info),

		VarDecl("t_auto", *cd.tano_struct_info),
		VarDecl("n_auto", *cd.neume_struct_info),
		VarDecl("test_auto", test_info),
	]);
	if !vars_equal return;
	n_var := cd.all_variables[0];
	ne_var := cd.all_variables[1];
	t_var := cd.all_variables[2];
	t2_var := cd.all_variables[3];
	test_var := cd.all_variables[4];
	test2_var := cd.all_variables[5];
	teste_var := cd.all_variables[6];
	t_auto_var := cd.all_variables[7];
	n_auto_var := cd.all_variables[8];
	test_auto_var := cd.all_variables[9];

	instr_index : int = 0;
	nms := cd.neume_struct_info.struct_members;
	//n := neume.{7.,2,0.,1.};
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, n_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		//push 0,3,7 on stack
		MakeMI(.mov, AddOperandOffset(nms[0].offset_in_bytes, n_var.op), 
			FImm(7.), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(nms[1].offset_in_bytes, n_var.op), 
			Imm(2), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(nms[2].offset_in_bytes, n_var.op), 
			FImm(0.), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(nms[3].offset_in_bytes, n_var.op), 
			FImm(1.), Imm(cd.float_type_info.runtime_size)),
	]);

	//ne := neume.{};
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, ne_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
	]);

	//t := tano.{0,x_end=2.};
	tms := cd.tano_struct_info.struct_members;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, t_var.op, Imm(0), Imm(cd.tano_struct_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(tms[0].offset_in_bytes, t_var.op), 
			Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(tms[3].offset_in_bytes, t_var.op), 
			FImm(2.), Imm(cd.float_type_info.runtime_size)),
	]);

	//t2 := tano.{row_end=1,mspace_start=1};
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, t2_var.op, Imm(0), Imm(cd.tano_struct_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(tms[1].offset_in_bytes, t2_var.op), 
			Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(tms[4].offset_in_bytes, t2_var.op), 
			Imm(1), Imm(cd.int_type_info.runtime_size)),
	]);

	//test := Test.{10,3.1};
	testms := test_info.struct_members;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, test_var.op, Imm(0), Imm(test_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(testms[0].offset_in_bytes, test_var.op), 
			Imm(10), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(testms[1].offset_in_bytes, test_var.op), 
			FImm(3.1), Imm(cd.float_type_info.runtime_size)),
	]);

	//test2 := Test.{x=2};
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, test2_var.op, Imm(0), Imm(test_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(testms[0].offset_in_bytes, test2_var.op), 
			Imm(2), Imm(cd.int_type_info.runtime_size)),
	]);

	//teste := Test.{};
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, teste_var.op, Imm(0), Imm(test_info.runtime_size)),
	]);

	//t_auto := tano.{0,x_end=2};
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, t_auto_var.op, Imm(0), Imm(cd.tano_struct_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(tms[0].offset_in_bytes, t_auto_var.op), 
			Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(tms[3].offset_in_bytes, t_auto_var.op), 
			Imm(2)),
	]);

	//n_auto := neume.{4,0,0,1};
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, n_auto_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(nms[0].offset_in_bytes, n_auto_var.op), 
			Imm(4)),
		MakeMI(.mov, AddOperandOffset(nms[1].offset_in_bytes, n_auto_var.op), 
			Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(nms[2].offset_in_bytes, n_auto_var.op), 
			Imm(0)),
		MakeMI(.itof, AddOperandOffset(nms[3].offset_in_bytes, n_auto_var.op), 
			Imm(1)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, test_auto_var.op, Imm(0), Imm(test_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(testms[1].offset_in_bytes, test_auto_var.op), 
			Imm(3)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);




	//Test failure cases
//INVALID not enough values provided in this struct literal
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	t := tano.{0,1};
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//INVALID invalid struct member type for row_start (float instead of int)
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	t := tano.{3.1,4,0.,1.,0};
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//INVALID non-assignment after assignment
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	n := neume.{x_end=2., 3};
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//INVALID variable neume does not have error var
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	n := neume.{error=2};
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//INVALID =,
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	n := neume.{svara=,};
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//Invalid no value after x_start= assignment
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	n := neume.{x_start=};
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//Invalid neither side (this fails in the parse due to invalid unary op)
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	n := neume.{=};
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//Invalid neither side (this fails in the parses due to invalid unary op)
//We have another test for that in Test_ParseStruct
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	n := neume.{,};
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


} @UnitTest

Test_ParseCast :: () {
	ptd := MakeParseTestData();

	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "cast(int) f+1");
	/*
			   +
			/    \
		 cast    1
		 / \
	  int  f
	*/
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "f")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "cast(int) (f + 1) - 2");
	/*
				-
		   /    \
		 cast    2
		 / \
	  int  +
         / \
        f   1
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .BINARY_OP),
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "f")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "1 + i * cast(int) f");
	/*
		  +
		/   \
	  1     *
	       / \
         i  cast
            /  \
          int   f
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "f")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "1 + cast(float) i * f");
	/*
		  +
		/   \
	  1     *
	       / \
       cast  f
       /  \
    float  i
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .BINARY_OP),
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "f")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "cast(int) (1 + cast(float) (i * f))");
	/*
		cast
	  /	 \
	int	  +
			/   \
		  1     cast
   		    /  \
   		 float  *
   		      /   \
   		     i     f
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "f")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "i : *int = cast(*int) v;");
	/*
			    =
			/      \
		  :       cast
		 / \      /  \
	   i   *    *    v
	        \    \
	        int  int
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "v")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "fl := cast(float) i;");
	/*
		  :=
		/    \
	  fl    cast
	        /  \
        float  i
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.COLON_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "fl")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "cast([] int) fa");
	/*
		 cast
		 / \
	   [   fa
	  / \  
	int  ]
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "fa")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "cast([] int) fa");
	/*
		 cast
		 / \
	   [   fa
	  / \  
	int  ]
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "fa")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "a := cast([] int) fa");
	/*
		 :=
      /   \
	  a	 cast
			 / \
		   [   fa
		  / \  
		int  ]
	*/
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.COLON_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_CAST, "cast"), .UNARY_OP),
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "fa")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

} @UnitTest

Test_CompileCast :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
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

	//TODO bool <-> int casting here once we do that
}
DONE,,unit_test_alloc);

	fixed_info, found_fixed_info := GetArrayType(cd, *cd.int_type_info, .FIXED, 2);
	AssertEquals(true, found_fixed_info);
	if !found_fixed_info return;
	int_array_info, found_int_array_info := GetArrayType(cd, *cd.int_type_info, .VIEW);
	AssertEquals(true, found_int_array_info);
	if !found_int_array_info return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("v", cd.void_pointer_type_info),
		VarDecl("i", cd.all_type_info_pointer[1]),

		VarDecl("i1", *cd.int_type_info),
		VarDecl("f1", *cd.float_type_info),

		VarDecl("f2", *cd.float_type_info),
		VarDecl("i2", *cd.int_type_info),

		VarDecl("a", fixed_info),
		VarDecl("ac", int_array_info),
	]);
	if !vars_equal return;
	v_var := cd.all_variables[0];
	i_var := cd.all_variables[1];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//v : *void;
		MakeMI(.mov, v_var.op, NULL_POINTER_OP, Imm(v_var.t_info.runtime_size)),
		//i : * int = cast(*int) v;
		MakeMI(.mov, i_var.op, v_var.op, Imm(i_var.t_info.runtime_size)),
	]);

	i1_var := cd.all_variables[2];
	f1_var := cd.all_variables[3];
	TestNextManyInstr(*instr_index, cd, .[
		//i1 : int = 10;
		MakeMI(.mov, i1_var.op, Imm(10), Imm(i1_var.t_info.runtime_size)),
		//cast(float) i1;
		MakeMI(.itof, f1_var.op, i1_var.op),
		//NOTE : Optimized out since we are moving to the same place
		//f1 : float = cast(float) i1;
		// MakeMI(.mov, f1_var.op, f1_var.op, Imm(f1_var.t_info.runtime_size)),
	]);

	f2_var := cd.all_variables[4];
	i2_var := cd.all_variables[5];
	TestNextManyInstr(*instr_index, cd, .[
		//f2 : float = 3.14159;
		MakeMI(.mov, f2_var.op, FImm(3.14159), Imm(f2_var.t_info.runtime_size)),
		//cast(int) f2;
		MakeMI(.ftoi, i2_var.op, f2_var.op),
		//NOTE : Optimized out since we are moving to the same place
		//i2 : int = cast(int) f2;
		// MakeMI(.mov, i2_var.op, i2_var.op, Imm(i2_var.t_info.runtime_size)),
	]);

	a_var := cd.all_variables[6];
	ac_var := cd.all_variables[7];
	//a := int.[0,1];
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, a_var.op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8, a_var.op), Imm(1), Imm(cd.int_type_info.runtime_size)),
		//NOTE : We optimize this out since it copies to the same place
		// MakeMI(.mov, RamMem(.sbp,fa_pos), RamMem(.sbp,fa_pos), Imm(f2_info.runtime_size)),
	]);
	a_0, a_1 := GetMemoryAddressAsOperands(a_var.op);
	//ac := cast([] int) a;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, ac_var.op, Imm(fixed_info.array_count), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.add, AddOperandOffset(8, ac_var.op), a_0, a_1),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

//Parse test in Test_ParseFunc (can move here if needed)
Test_CompileSizeOf :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : int = size_of(int);
	p : int = size_of(*float);
	a : int = size_of([] int);
	a2 : int = size_of([5] int);
	//TODO Can add tests here with expressions later
	//once we do ops to make sure it's working with 
	//binary and unary ops as well although it should
	//be the same as functions so if that works it should be good.
}
DONE,,unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", *cd.int_type_info),
		VarDecl("p", *cd.int_type_info),
		VarDecl("a", *cd.int_type_info),
		VarDecl("a2", *cd.int_type_info),
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];
	p_var := cd.all_variables[1];
	a_var := cd.all_variables[2];
	a2_var := cd.all_variables[3];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//i : int = size_of(int);
		MakeMI(.mov, i_var.op, Imm(cd.int_type_info.runtime_size), Imm(i_var.t_info.runtime_size)),
		// p : int = size_of(*float);
		MakeMI(.mov, p_var.op, Imm(cd.all_type_info_pointer[2].runtime_size), Imm(p_var.t_info.runtime_size)),
		//TODO We create array types in order but we could fetch by element type if needed.
		//a : int = size_of([] int);
		MakeMI(.mov, a_var.op, Imm(cd.all_type_info_array[0].runtime_size), Imm(a_var.t_info.runtime_size)),
		//a2 : int = size_of([2] int);
		MakeMI(.mov, a2_var.op, Imm(cd.all_type_info_array[1].runtime_size), Imm(a2_var.t_info.runtime_size)),
	]);

	//Test failure case
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	i : int = size_of();
}
DONE,,unit_test_alloc);
	//TODO Can check more explicit if we systematize this eventually.
	//> 0 errors means failure anyways so it's good in any case.
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
} @UnitTest

//Parse test in Test_ParseFunc (can move here if needed)
Test_CompileNew :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : *int = New(int);
	af : *[] float = New([] float);
}
DONE,,unit_test_alloc);

	float_array_type := cd.all_type_info_array[0];
	float_array_pointer_type : *TypeInfoPointer;
	for cd.all_type_info_pointer if it.pointer_to.type_enum == .ARRAY {
		float_array_pointer_type = it;
	}
	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", cd.all_type_info_pointer[1]),
		VarDecl("af", float_array_pointer_type),
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];
	af_var := cd.all_variables[1];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//New(int)
		MakeMI(.alloc, Imm(cd.int_type_info.runtime_size), i_var.op),
		//NOTE : Optimized out since we are moving to the same place
		//i : *int = New(int);
		// MakeMI(.mov, i_var.op, i_var.op, Imm(i_var.t_info.runtime_size)),

		//New([] float)
		MakeMI(.alloc, Imm(float_array_type.runtime_size), af_var.op),
		//NOTE : Optimized out since we are moving to the same place
		//af_var : *[] float = New([] float);
		// MakeMI(.mov, af_var.op, af_var.op, Imm(af_var.t_info.runtime_size)),
	]);


	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	x : float = 5.0;
	f : *float = New(x);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

} @UnitTest

//Parse test in Test_ParseFunc (can move here if needed)
Test_CompileNewArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	i : [] int = NewArray(10, int);
}
DONE,,unit_test_alloc);

	int_array_type := cd.all_type_info_array[0];
	float_array_pointer_type : *TypeInfoPointer;
	for cd.all_type_info_pointer if it.pointer_to.type_enum == .ARRAY {
		float_array_pointer_type = it;
	}
	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("i", int_array_type),
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//NewArray(10,int)
		MakeMI(.mov, RamMem(.sbp,0), Imm(10), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mul, RamMem(.sbp,8), Imm(int_array_type.element_type.runtime_size), Imm(10)),
		MakeMI(.alloc, RamMem(.sbp,8), RamMem(.sbp,8)),
		//NOTE : Optimized out since we are moving to the same place
		//i : [] int = NewArray(10,int);
		// MakeMI(.mov, i_var.op, i_var.op, Imm(i_var.t_info.runtime_size)),
	]);

	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


} @UnitTest

Test_CompileHeapArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	data : *int;
	#asm {alloc 16, data;}
	a : [] int;
	a.count = 2;
	a.data = data;

	// a : [] int;
	// a.count = 10;
	// a.data = cast(*int) alloc(a.count * size_of(int));

	// n : int = 10;
	//TODO I think adding this function as a special case
	//in the compiler is better than [n] syntax.
	// a : [] int = NewArray(10, int);
	// a : [] int = new [10] int;
	// a : [n] int;

	// New()
	// n : *int = cast(*int) alloc(size_of(int));
	// n : *int = new int;
	// n : *int = New(int);
}
DONE,,unit_test_alloc);
// //Array view access
// a[1] = 10;
// a.data[1] = 10; //Should be the same as above
// i : int = a[1];
// i = a.data[1];

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("data", cd.all_type_info_pointer[1]),
		VarDecl("a", cd.all_type_info_array[0]),
	]);
	if !vars_equal return;
	data_var := cd.all_variables[0];
	a_var := cd.all_variables[1];
	a_var_data_op := AddOperandOffset(8, a_var.op);

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//data : *int;
		MakeMI(.mov, data_var.op, NULL_POINTER_OP, Imm(data_var.t_info.runtime_size)),
		//alloc 16, data
		MakeMI(.alloc, Imm(16), data_var.op),
		//a : [] int;
		MakeMI(.mset, a_var.op, Imm(0), Imm(a_var.t_info.runtime_size)),
		//a.count = 2;
		MakeMI(.mov, a_var.op, Imm(2), Imm(8)),
		//a.count = data;
		MakeMI(.mov, a_var_data_op, data_var.op, Imm(8))
	]);
} @UnitTest

//TODO Need to add heap before we can test this
//I think this needs to be a struct since we don't have compile-time metaprogramming
/*ResizableArray/ResizeArray/DynamicArray... something shorter?
ResizableArray :: struct {
	count : int;
	data : *void;
	allocated : int;
	element_size : int;
}
//Actual function
NewResizableArray()
array_add()
array_insert()
array_unordered_remove()
array_ordered_remove()
peek()
pop()
...
all basic functions

ACTUALLY maybe not and just use [..] and store element_size at compile-time
then we can make some functions like in jai to use it in general.
*/
Test_NewResizableArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

//TODO We can add array_add here and test that out
//when we do functions.
	cd = CompileCode(cs,
#string DONE
main :: () {
	na : [..] float = NewResizableArray(10,float);
}
DONE,,unit_test_alloc);

	float_array_type := cd.all_type_info_array[0];
	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("na", float_array_type),
	]);
	if !vars_equal return;
	na_var := cd.all_variables[0];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//NewResizableArray(10,float)
		//na.count
		MakeMI(.mov, RamMem(.sbp,0), Imm(10), Imm(cd.int_type_info.runtime_size)),
		//na.data
		MakeMI(.mul, RamMem(.sbp,8), Imm(float_array_type.element_type.runtime_size), Imm(10)),
		MakeMI(.alloc, RamMem(.sbp,8), RamMem(.sbp,8)),
		//na.allocated
		MakeMI(.mul, RamMem(.sbp,16), Imm(2), Imm(10)),
		//na.element_size
		MakeMI(.mov, RamMem(.sbp,24), Imm(float_array_type.element_type.runtime_size), Imm(cd.int_type_info.runtime_size)),
		//NOTE : Optimized out since we are moving to the same place
		//i : [] int = NewArray(10,int);
		// MakeMI(.mov, na_var.op, na_var.op, Imm(na_var.t_info.runtime_size)),
	]);

	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewResizableArray(float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewResizableArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


//TEST NewResizable should be unidentified if not used as a function
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f := NewResizableArray;
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

} @UnitTest

//TODO Test multi-arrays in struct and functions as well.
//TODO DO 3D and 4D test for good measure eventually.
//TODO Also do resizable multi-arrays and array view once we implement that with the heap.
//TODO I MIGHT JUST REMOVE multi-dimensional arrays and just have arrays of structs instead
Test_CompileMultiArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	f : [3][3] int;
	f[1][2] = 10;
	f[1].data[2] = 10;

	t : int = f[1][2];
	t = f[1].data[2];

	t = f[1].count;

	f_1 : [3] int = f[1];

	//TODO Test this as it's not working right now for *[3] int
	// d : *[3] int = f[1].data;
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_type_info_array.count);
	if !count_equal return;

	dim1_info : *TypeInfoArray = cd.all_type_info_array[0];
	AssertEquals(TypeInfoTag.ARRAY, dim1_info.type_enum);
	AssertEquals(24, dim1_info.runtime_size);
	AssertEquals(ArrayInfoType.FIXED, dim1_info.array_type);
	AssertEquals(3, dim1_info.array_count);
	AssertEquals(*cd.int_type_info, dim1_info.element_type);
	AssertEquals(TypeInfoTag.INTEGER, dim1_info.element_type.type_enum);
	AssertEquals(8, dim1_info.element_type.runtime_size);

	dim2_info : *TypeInfoArray = cd.all_type_info_array[1];
	AssertEquals(TypeInfoTag.ARRAY, dim2_info.type_enum);
	AssertEquals(24*3, dim2_info.runtime_size);
	AssertEquals(ArrayInfoType.FIXED, dim2_info.array_type);
	AssertEquals(3, dim2_info.array_count);
	AssertEquals(*dim1_info.info, dim2_info.element_type);


	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("f", cd.all_type_info_array[1]),
		VarDecl("t", *cd.int_type_info),
		VarDecl("f_1", cd.all_type_info_array[0])
	]);

	if !vars_equal return;

	f_var := cd.all_variables[0];
	t_var := cd.all_variables[1];
	f_1_var := cd.all_variables[2];

	//Initialize f : [3][3] int
	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, f_var.op, Imm(0), Imm(f_var.t_info.runtime_size)),
	]);

	array_access_op := AddOperandOffset(f_var.t_info.runtime_size, f_var.op);
	//f[1]
	f_1_expected := MusicInstruction.[
		MakeMI(.add, array_access_op, ValueToOp(f_var.op.values[0]), ValueToOp(f_var.op.values[1])),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(dim2_info.element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax))
	];
	TestNextManyInstr(*instr_index, cd, f_1_expected);

	//f[1][2] = 10
	f_1_2_assign_instr := MusicInstruction.[
		//f[1][2]
		// MakeMI(.add, RegMem(.ax), RegMem(.ax), Imm(0)),
		MakeMI(.mul, RegMem(.ax), Imm(2), Imm(dim1_info.element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//f[1][2] = 10
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(8)),
	];
	f_1_2_bin_access := array_view(f_1_2_assign_instr,0,3);
	TestNextManyInstr(*instr_index, cd, f_1_2_assign_instr);

	//f[1]
	TestNextManyInstr(*instr_index, cd, f_1_expected);

	//f[1].data[2] = 10
	TestNextManyInstr(*instr_index, cd, f_1_2_assign_instr);

	//f[1]
	TestNextManyInstr(*instr_index, cd, f_1_expected);

	//f[1][2]
	TestNextManyInstr(*instr_index, cd, f_1_2_bin_access);

	//t = f[1][2]
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, t_var.op, RamMem(.r0), Imm(dim1_info.element_type.runtime_size))
	]);

	//NOTE : Need to + 8 here since we set the t : int variable
	array_access_op = AddOperandOffset(8, array_access_op);
	//f[1]
	f_1_expected = MusicInstruction.[
		MakeMI(.add, array_access_op, ValueToOp(f_var.op.values[0]), ValueToOp(f_var.op.values[1])),
		MakeMI(.mul, RegMem(.ax), Imm(1), Imm(dim2_info.element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax))
	];
	//f[1]
	TestNextManyInstr(*instr_index, cd, f_1_expected);

	f_1_2_assign_instr = MusicInstruction.[
		//f[1][2]
		// MakeMI(.add, RegMem(.ax), RegMem(.ax), Imm(0)),
		MakeMI(.mul, RegMem(.ax), Imm(2), Imm(dim1_info.element_type.runtime_size)),
		MakeMI(.add, array_access_op, RegMem(.ax)),
		//f[1][2] = 10
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, RamMem(.r0), Imm(10), Imm(8)),
	];
	f_1_2_bin_access = array_view(f_1_2_assign_instr,0,3);
	//f[1].data[2]
	TestNextManyInstr(*instr_index, cd, f_1_2_bin_access);

	t_assign_instr := MusicInstruction.[
		MakeMI(.mov, t_var.op, RamMem(.r0), Imm(dim1_info.element_type.runtime_size))
	];
	//t = f[1].data[2]
	TestNextManyInstr(*instr_index, cd, t_assign_instr);


	//TODO TECHNICALLY f[1].count doesn't need these for
	//fixed arrays because we only need the integer value
	//which is known at compile-time.
	//f[1]
	TestNextManyInstr(*instr_index, cd, f_1_expected);

	//t = f[1].count
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, t_var.op, Imm(dim1_info.array_count), Imm(t_var.t_info.runtime_size))
	]);

	//f[1]
	TestNextManyInstr(*instr_index, cd, f_1_expected);

	//assign f_1 = f[1]
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RegMem(.r0), array_access_op, Imm(8)),
		MakeMI(.mov, f_1_var.op, RamMem(.r0), Imm(f_1_var.t_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

/*TODO FROM HERE add neumes and then neumes with functions
and then add "~" and "+=" ops before doing ui
then do larger test like this one before ui
so we can make sure ui still works after and then
can do more specific ui tests
*/
Test_NeumeComp :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
  n : neume;
  n.svara = 10.5;
  n.row = 0;
  n.x_start = 0.0;
  n.x_end = 2.0;

  //TODO FROM HERE do pointers and then neumes and tanos in functions
  //and then ops with neumes and arrays and then arrays in functions before ui
  np : *neume = *n;

  //TODO Struct literals
  // n := neume.{10.5,0,0.,2.};
}
DONE,,unit_test_alloc);

	comp_fail : bool = cd.comp_errors.all_compiler_errors.count > 0;
	AssertEquals(false, comp_fail);
	if comp_fail return;

	np_info, found_np_info := GetTypeInfoPointer(*cd.neume_struct_info, cd);
	AssertEquals(true, found_np_info);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("n", *cd.neume_struct_info),
		VarDecl("np", np_info),
	]);
	if !vars_equal return;
	n_var := cd.all_variables[0];
	np_var := cd.all_variables[1];


	n_0, n_1 := GetMemoryAddressAsOperands(n_var.op);
	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//n : neume;
		MakeMI(.mset, n_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.mov, n_var.op, FImm(10.5), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8,n_var.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(16,n_var.op), FImm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(24,n_var.op), FImm(2), Imm(cd.float_type_info.runtime_size)),

  		//np : *neume = *n;
		MakeMI(.add, np_var.op, n_0, n_1),

		MakeMI(.exit),
	]);

	AssertEquals(cd.all_music_instructions.count, instr_index);

//Test no float rows
#if 0 {
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	t : tano = tano(10.0);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
}

} @UnitTest

Test_NeumeArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
  n : neume;
  n.svara = 10.5;
  n.x_end = 2.0;

  n1 : neume;
  n1.svara = 4.3;
  n1.x_end = 3.0;

  na : [2] neume = neume.[n,n1];
  t0 := tano(0,0.0);
  t0 ~= na;

  //TODO Can test with struct literals once we implement that
  // na : [2] neume = neume.[neume.{},neume.{}];
}
DONE,,unit_test_alloc);

	comp_fail : bool = cd.comp_errors.all_compiler_errors.count > 0;
	AssertEquals(false, comp_fail);
	if comp_fail return;

	na_type, found_na_type := GetArrayType(cd, *cd.neume_struct_info, ArrayInfoType.FIXED, 2);
	AssertEquals(true, found_na_type);
	if !found_na_type return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("n", *cd.neume_struct_info),
		VarDecl("n1", *cd.neume_struct_info),
		VarDecl("na", na_type),
		VarDecl("t0", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	n_var := cd.all_variables[0];
	n1_var := cd.all_variables[1];
	na_var := cd.all_variables[2];
	t0_var := cd.all_variables[3];


	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//n : neume;
		MakeMI(.mset, n_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.mov, n_var.op, FImm(10.5), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(24,n_var.op), FImm(2), Imm(cd.float_type_info.runtime_size)),

		//n1 : neume;
		MakeMI(.mset, n1_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.mov, n1_var.op, FImm(4.3), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(24,n1_var.op), FImm(3.0), Imm(cd.float_type_info.runtime_size)),

  		//na : [2] neume = neume.[n,n1];
		MakeMI(.mov, na_var.op, n_var.op, Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(cd.neume_struct_info.runtime_size,na_var.op), n1_var.op, Imm(cd.neume_struct_info.runtime_size)),
	]);

	na_0, na_1 := GetMemoryAddressAsOperands(na_var.op);
	t_ofs := GetTanoOpOffsets(t0_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, t_ofs.row_start_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.row_end_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.x_start_op, FImm(0), Imm(cd.float_type_info.runtime_size)),
		MakeFloatInstr(.add, t_ofs.x_end_op, t_ofs.x_start_op, FImm(1)),
		MakeMI(.mov, t_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		MakeMI(.add, RegMem(.ax), na_0, na_1),
		MakeMI(.tmov, t0_var.op, RamArray(2,RegDef.ax), ImmEnum(TMovArrayType.NEUME)),

		MakeMI(.exit),
	]);

	AssertEquals(cd.all_music_instructions.count, instr_index);

} @UnitTest

//TODO FROM HERE do an integration test for this
//and then continue on tano ops "~" and "+="
Test_TanoToArrayComp :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
  t0 := tano(0,0.0);
  t0 ~= int.[0,4];
  na : [] neume = t0;
  ia : [] int = t0;
  fa : [] float = t0;
}
DONE,,unit_test_alloc);

	comp_fail : bool = cd.comp_errors.all_compiler_errors.count > 0;
	AssertEquals(false, comp_fail);
	if comp_fail return;

	na_type, found_na_type := GetArrayType(cd, *cd.neume_struct_info, ArrayInfoType.VIEW);
	ia_type, found_ia_type := GetArrayType(cd, *cd.int_type_info, ArrayInfoType.VIEW);
	fa_type, found_fa_type := GetArrayType(cd, *cd.float_type_info, ArrayInfoType.VIEW);
	if !(found_na_type && found_ia_type && found_fa_type) return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t0", *cd.tano_struct_info),
		VarDecl("na", na_type),
		VarDecl("ia", ia_type),
		VarDecl("fa", fa_type),
	]);
	if !vars_equal return;
	t0_var := cd.all_variables[0];
	na_var := cd.all_variables[1];
	ia_var := cd.all_variables[2];
	fa_var := cd.all_variables[3];


	instr_index : int = 0;
	na_0, na_1 := GetMemoryAddressAsOperands(na_var.op);
	t_ofs := GetTanoOpOffsets(t0_var.op);
	arr_op := RamMem(.sbp,40);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, t_ofs.row_start_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.row_end_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.x_start_op, FImm(0), Imm(cd.float_type_info.runtime_size)),
		MakeFloatInstr(.add, t_ofs.x_end_op, t_ofs.x_start_op, FImm(1)),
		MakeMI(.mov, t_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		MakeMI(.mov, arr_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8,arr_op), Imm(4), Imm(cd.int_type_info.runtime_size)),

		MakeMI(.add, RegMem(.ax), RegMem(.sbp), Imm(40)),
		MakeMI(.tmov, t0_var.op, RamArray(2,RegDef.ax)),
	]);

  	//na : [] neume = t0;
	na_settings_op := RamMem(.sbp,40);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, AddOperandOffset(24,na_settings_op), ImmEnum(TMovArrayType.NEUME), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.tmov, RamArray(0,0), t0_var.op, na_settings_op),
		MakeMI(.mov, na_var.op, na_settings_op, Imm(cd.array_view_struct_info.runtime_size)),
	]);

  	//ia : [] int = t0;
	ia_settings_op := ia_var.op;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, AddOperandOffset(24,ia_settings_op), ImmEnum(TMovArrayType.DEFAULT), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.tmov, RamArray(0,0), t0_var.op, ia_settings_op),
		MakeMI(.mov, ia_var.op, ia_settings_op, Imm(cd.array_view_struct_info.runtime_size)),
	]);

  	//fa : [] float = t0;
	fa_settings_op := fa_var.op;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, AddOperandOffset(24,fa_settings_op), ImmEnum(TMovArrayType.DEFAULT), Imm(cd.int_type_info.runtime_size)),
		MakeFloatInstr(.tmov, RamArray(0,0), t0_var.op, fa_settings_op),
		MakeMI(.mov, fa_var.op, fa_settings_op, Imm(cd.array_view_struct_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(cd.all_music_instructions.count, instr_index);

} @UnitTest

//TODO Write a test for relative tanos
Test_TanoComp :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	t : tano = tano(1,10);
	t1 : tano = tano(0..1,1.0..5);
	t2 : tano = tano(1:2,10:5);
	t3 : tano = tano(3..1,10:5.0);

	x : int = 5;
	t4 : tano = tano(x,x..10.0);
	// tp : *tano = *t4;

	//TODO Can do a float test here too once it works
	// f : float = 1.0;
	// t5 : tano = tano(x,f..f+1);

	//TODO Test some mspace variations
	//Maybe make a different test for this
	//TODO Can test all combinations later with x, row and mspace
	t5 : tano = tano(0,0.0,1);
	// t6 : tano = tano(0,0.0,0..1);
	// t7 : tano = tano(0,0.0,0:5);
	// t8 : tano = tano(0,0,,2);
	// t9 : tano = tano(,,3);

	//TODO FROM HERE continue on this "~=" operator and move the .tmov code and then write tests
	//can also do some more tests here
	// t2 ~= t1;
	// t3 ~= t1 ~ t2;
	// tano(0,0:10) ~= int.[0,4,7];
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) + 1;
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) ~ 
	//    (tano(1,0:5) ~ int.[0,3,7]);
	// t2 = t1;
	// t2 '= t1;
	// t2 #= t1;
	// t2 @= t1;
	// t2 $= t1;
}
DONE,,unit_test_alloc);

	comp_fail : bool = cd.comp_errors.all_compiler_errors.count > 0;
	AssertEquals(false, comp_fail);
	if comp_fail return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t", *cd.tano_struct_info),
		VarDecl("t1", *cd.tano_struct_info),
		VarDecl("t2", *cd.tano_struct_info),
		VarDecl("t3", *cd.tano_struct_info),
		VarDecl("x", *cd.int_type_info),
		VarDecl("t4", *cd.tano_struct_info),
		VarDecl("t5", *cd.tano_struct_info),
		// VarDecl("t6", *cd.tano_struct_info),
		// VarDecl("t7", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];
	t1 := cd.all_variables[1];
	t2 := cd.all_variables[2];
	t3 := cd.all_variables[3];
	x_var := cd.all_variables[4];
	t4 := cd.all_variables[5];
	t5 := cd.all_variables[6];
	// t6 := cd.all_variables[7];
	// t7 := cd.all_variables[8];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//tano(1,10)
		MakeMI(.mov, RamMem(.sbp,0), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(10), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,16), RamMem(.sbp,16)),
		MakeFloatInstr(.add, RamMem(.sbp,24), RamMem(.sbp,16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp,40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0..1,1.0..5)
		MakeMI(.mov, AddOperandOffset(0 , t1.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8 , t1.op), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(16, t1.op), FImm(1.0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(24, t1.op), Imm(5), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(24, t1.op), AddOperandOffset(24, t1.op)),
		MakeMI(.mov, AddOperandOffset(32, t1.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(40, t1.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(1:2,10:5)
		MakeMI(.mov, AddOperandOffset(0 , t2.op), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.add, AddOperandOffset(8 , t2.op), t2.op, Imm(2)),
		MakeMI(.mov, AddOperandOffset(16, t2.op), Imm(10), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(16, t2.op), AddOperandOffset(16, t2.op)),
		MakeMI(.mov, RegMem(.ax), Imm(5), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.itof, RegMem(.ax), RegMem(.ax)),
		MakeFloatInstr(.add, AddOperandOffset(24, t2.op), AddOperandOffset(16, t2.op), RegMem(.ax)),
		MakeMI(.mov, AddOperandOffset(32, t2.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(40, t2.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(3..1,10:5.0)
		MakeMI(.mov, AddOperandOffset(0 , t3.op), Imm(3), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8 , t3.op), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(16, t3.op), Imm(10), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(16, t3.op), AddOperandOffset(16, t3.op)),
		MakeFloatInstr(.add, AddOperandOffset(24, t3.op), AddOperandOffset(16, t3.op), FImm(5.0)),
		MakeMI(.mov, AddOperandOffset(32, t3.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(40, t3.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//x : int = 5;
		MakeMI(.mov, x_var.op, Imm(5), Imm(cd.int_type_info.runtime_size)),

		//tano(x,x..10.0)
		MakeMI(.mov, AddOperandOffset(0 , t4.op), x_var.op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8 , t4.op), x_var.op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(16, t4.op), x_var.op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(16, t4.op), AddOperandOffset(16, t4.op)),
		MakeMI(.mov, AddOperandOffset(24, t4.op), FImm(10.0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(32, t4.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(40, t4.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		// t5 : tano = tano(0,0.0,1);
		MakeMI(.mov, AddOperandOffset(0, t5.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8, t5.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(16, t5.op), FImm(0), Imm(cd.float_type_info.runtime_size)),
		MakeFloatInstr(.add, AddOperandOffset(24, t5.op), AddOperandOffset(16, t5.op), FImm(1)),
		MakeMI(.mov, AddOperandOffset(32, t5.op), Imm(1), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(40, t5.op), Imm(1), Imm(cd.int_type_info.runtime_size)),

		//TODO Can remove these if we don't allow mspace_end ultimately
		// t6 : tano = tano(0,0.0,0..1);
		// MakeMI(.mov, AddOperandOffset(0, t6.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(8, t6.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(16, t6.op), FImm(0), Imm(cd.float_type_info.runtime_size)),
		// MakeFloatInstr(.add, AddOperandOffset(24, t6.op), AddOperandOffset(16, t6.op), FImm(1)),
		// MakeMI(.mov, AddOperandOffset(32, t6.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(40, t6.op), Imm(1), Imm(cd.int_type_info.runtime_size)),

		// t7 : tano = tano(0,0.0,0:5);
		// MakeMI(.mov, AddOperandOffset(0, t7.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(8, t7.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, AddOperandOffset(16, t7.op), FImm(0), Imm(cd.float_type_info.runtime_size)),
		// MakeFloatInstr(.add, AddOperandOffset(24, t7.op), AddOperandOffset(16, t7.op), FImm(1)),
		// MakeMI(.mov, AddOperandOffset(32, t7.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.add, AddOperandOffset(40, t7.op), AddOperandOffset(32, t7.op), Imm(5)),

		MakeMI(.exit),
	]);


//Test no float rows
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	t : tano = tano(10.0);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

#if 0 {
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
}

} @UnitTest

//TODO Likely test relative tanos more thoroughly eventually 
//but really it's just an x and row add so this covers both cases
//and also it is the same add for each corner since that just depends
//on the direction of the x and row of the t_rel on the left 
Test_TanoRel :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	t := tano(1,1);
	t(1,1) ~= 0;

	t1 : tano = t(-1,-1);
	t1 ~= 7;
}
DONE,,unit_test_alloc);

	comp_fail : bool = cd.comp_errors.all_compiler_errors.count > 0;
	AssertEquals(false, comp_fail);
	if comp_fail return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t", *cd.tano_struct_info),
		VarDecl("t1", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];
	t1_var := cd.all_variables[1];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//t : tano = tano(1,1);
		MakeMI(.mov, RamMem(.sbp,0), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,16), RamMem(.sbp,16)),
		MakeFloatInstr(.add, RamMem(.sbp,24), RamMem(.sbp,16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	]);

	rel_t : int = t_var.t_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//t(1,1);
		MakeMI(.mov, RamMem(.sbp,rel_t+0), Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,rel_t+8), Imm(1), Imm(cd.int_type_info.runtime_size)),
		//Add t_var x_start offset to both rel_t x
		MakeMI(.add, RamMem(.sbp,rel_t+0), t_var.op),
		MakeMI(.add, RamMem(.sbp,rel_t+8), t_var.op),

		MakeMI(.mov, RamMem(.sbp,rel_t+16), Imm(1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,rel_t+16), RamMem(.sbp,rel_t+16)),
		MakeFloatInstr(.add, RamMem(.sbp,rel_t+24), RamMem(.sbp,rel_t+16), FImm(1)),
		//Add t_var row offset to both rel_t row
		MakeFloatInstr(.add, RamMem(.sbp,rel_t+16), AddOperandOffset(16,t_var.op)),
		MakeFloatInstr(.add, RamMem(.sbp,rel_t+24), AddOperandOffset(16,t_var.op)),

		MakeMI(.mov, RamMem(.sbp,rel_t+32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		MakeMI(.mov, RegMem(.ax), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.tmov, RamMem(.sbp,rel_t), RegMem(.ax)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//t1 := t(-1,-1);
		MakeMI(.mov, t1_var.op, Imm(-1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8,t1_var.op), Imm(-1), Imm(cd.int_type_info.runtime_size)),
		//Add x_start offset
		MakeMI(.add, t1_var.op, t_var.op),
		MakeMI(.add, AddOperandOffset(8,t1_var.op), t_var.op),

		MakeMI(.mov, AddOperandOffset(16,t1_var.op), Imm(-1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, AddOperandOffset(16,t1_var.op), AddOperandOffset(16,t1_var.op)),
		MakeFloatInstr(.add, AddOperandOffset(24,t1_var.op), AddOperandOffset(16,t1_var.op), FImm(1)),
		//Add row offset
		MakeFloatInstr(.add, AddOperandOffset(16,t1_var.op), AddOperandOffset(16,t_var.op)),
		MakeFloatInstr(.add, AddOperandOffset(24,t1_var.op), AddOperandOffset(16,t_var.op)),

		MakeMI(.mov, AddOperandOffset(32,t1_var.op), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//t1 ~= 7;
		MakeMI(.mov, RegMem(.ax), Imm(7), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.tmov, t1_var.op, RegMem(.ax)),

		MakeMI(.exit)
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_TanoRelDir :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
  t := tano(0..1,0.0..1.0);
  t1 := t(+,+);
  t2 := t(-,+);
  t3 := t(+,-);
  t4 := t(-,-);

  //TODO We could also do it this way if that makes more sense.
  // t1 := t(+/+);
  // t1 := t(-/+);
  // t1 := t(+/-);
  // t1 := t(-/-);
}
DONE,,unit_test_alloc);

	comp_fail : bool = cd.comp_errors.all_compiler_errors.count > 0;
	AssertEquals(false, comp_fail);
	if comp_fail return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t", *cd.tano_struct_info),
		VarDecl("t1", *cd.tano_struct_info),
		VarDecl("t2", *cd.tano_struct_info),
		VarDecl("t3", *cd.tano_struct_info),
		VarDecl("t4", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];
	t1_var := cd.all_variables[1];
	t2_var := cd.all_variables[2];
	t3_var := cd.all_variables[3];
	t4_var := cd.all_variables[4];

	t_ofs := GetTanoOpOffsets(t_var.op);
	t2_ofs := GetTanoOpOffsets(t2_var.op);
	t3_ofs := GetTanoOpOffsets(t3_var.op);
	t4_ofs := GetTanoOpOffsets(t4_var.op);

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//t : tano = tano(0..1,0.0..1.0);
		MakeMI(.mov, t_ofs.row_start_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.row_end_op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.x_start_op, FImm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.x_end_op, FImm(1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	]);

	rel_t : int = t_var.t_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		// t1 := t(+,+);
		MakeMI(.mov, t1_var.op, t_var.op, Imm(cd.tano_struct_info.runtime_size)),

		//t2 := t(-,+);
		MakeMI(.mov, t2_var.op, t_var.op, Imm(cd.tano_struct_info.runtime_size)),
		MakeMI(.mov, t2_ofs.row_start_op, t_ofs.row_end_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t2_ofs.row_end_op, t_ofs.row_start_op, Imm(cd.int_type_info.runtime_size)),
		//NOTE : The t2 mov here is optimized out since we are pushing to the same place

		//t3 := t(-,+);
		MakeMI(.mov, t3_var.op, t_var.op, Imm(cd.tano_struct_info.runtime_size)),
		MakeMI(.mov, t3_ofs.x_start_op, t_ofs.x_end_op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, t3_ofs.x_end_op, t_ofs.x_start_op, Imm(cd.float_type_info.runtime_size)),

		//t4 := t(-,-);
		MakeMI(.mov, t4_var.op, t_var.op, Imm(cd.tano_struct_info.runtime_size)),
		MakeMI(.mov, t4_ofs.row_start_op, t_ofs.row_end_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t4_ofs.row_end_op, t_ofs.row_start_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t4_ofs.x_start_op, t_ofs.x_end_op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, t4_ofs.x_end_op, t_ofs.x_start_op, Imm(cd.float_type_info.runtime_size)),

		MakeMI(.exit)	
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_TanoNeg :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
  t := -tano(0..1,0.0..2.0);
  t = --t;
}
DONE,,unit_test_alloc);

	comp_fail : bool = cd.comp_errors.all_compiler_errors.count > 0;
	AssertEquals(false, comp_fail);
	if comp_fail return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];

	t_ofs := GetTanoOpOffsets(t_var.op);
	neg_op := RamMem(.sbp, t_var.t_info.runtime_size);
	neg_ofs := GetTanoOpOffsets(neg_op);

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0..1,0.0..2.0);
		MakeMI(.mov, t_ofs.row_start_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.row_end_op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.x_start_op, FImm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.x_end_op, FImm(2), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, t_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//negate : -tano(0..1,0.0..2.0);
		MakeMI(.mov, neg_ofs.row_start_op, t_ofs.row_end_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, neg_ofs.row_end_op, t_ofs.row_start_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, neg_ofs.x_start_op, t_ofs.x_end_op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, neg_ofs.x_end_op, t_ofs.x_start_op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, neg_ofs.mspace_op, t_ofs.mspace_op, Imm(cd.int_type_info.runtime_size)),

		//t := -tano(0..1,0.0..2.0);
		MakeMI(.mov, t_var.op, neg_op, Imm(cd.tano_struct_info.runtime_size)),
	]);

	neg2_op := RamMem(.sbp, 2*t_var.t_info.runtime_size);
	neg2_ofs := GetTanoOpOffsets(neg2_op);
	TestNextManyInstr(*instr_index, cd, .[
		//-t;
		MakeMI(.mov, neg_ofs.row_start_op, t_ofs.row_end_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, neg_ofs.row_end_op, t_ofs.row_start_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, neg_ofs.x_start_op, t_ofs.x_end_op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, neg_ofs.x_end_op, t_ofs.x_start_op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, neg_ofs.mspace_op, t_ofs.mspace_op, Imm(cd.int_type_info.runtime_size)),

		//--t;
		MakeMI(.mov, neg2_ofs.row_start_op, neg_ofs.row_end_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, neg2_ofs.row_end_op, neg_ofs.row_start_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, neg2_ofs.x_start_op, neg_ofs.x_end_op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, neg2_ofs.x_end_op, neg_ofs.x_start_op, Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, neg2_ofs.mspace_op, neg_ofs.mspace_op, Imm(cd.int_type_info.runtime_size)),

		//t = --t;
		MakeMI(.mov, t_var.op, neg2_op, Imm(cd.tano_struct_info.runtime_size)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_TanoTEq :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	//TODO FROM HERE implement these tests
	//maybe write test names in alphabetic order
	tano(0,0) ~= 0;
	tano(0,0) ~= 4.0;
	tano(0,1) ~= tano(0,0);

	t : tano = tano(0,2);
	t ~= tano(0,1);
	

	//TODO FROM HERE Need to add mspace_index to tano
	//and then update these to set them either with input
	//or with default registers if we don't put it
	// CopyRows(tano(0), 1, tano(10), 0, 5);
	// tano(0,10,,1) ~= tano(10:5,0:10,,0);
	// tano(0,10,mi=1) ~= tano(10:5,0:10,mi=0);
	// tano(0,,1) ~= tano(10:5,,0);
	// tano(0,mi=1) ~= tano(10:5,mi=0);
	//TODO This seems good for specifying music space
	//TODO Could a set a default not length as well somewhere
	//either in a register or somewhere else?
	// tano(0,0,-1) ~= tano(0,1);
	//TODO This could also be a possibility which would translate to jai with operator overloads
	// tano(0,1,10,15,-1) ~= tano(0,1);


	//TODO Maybe add ~ binary op to a different test
	// t2 ~= t1;
	// t3 ~= t1 ~ t2;
	// tano(0,0:10) ~= int.[0,4,7];
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) + 1;
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) ~ 
	//    (tano(1,0:5) ~ int.[0,3,7]);
}
DONE,,unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0)
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,16), RamMem(.sbp,16)),
		MakeFloatInstr(.add, RamMem(.sbp,24), RamMem(.sbp,16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp, 32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp, 40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0,0) ~= 0;
		MakeMI(.mov, RegMem(.ax), Imm(0), Imm(8)),
		MakeMI(.tmov, RamMem(.sbp,0), RegMem(.ax)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0)
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,16), RamMem(.sbp,16)),
		MakeFloatInstr(.add, RamMem(.sbp,24), RamMem(.sbp,16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp, 32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp, 40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0,0) ~= 4.0;
		MakeFloatInstr(.mov, RegMem(.ax), FImm(4.0), Imm(cd.float_type_info.runtime_size)),
		MakeFloatInstr(.tmov, RamMem(.sbp,0), RegMem(.ax)),
	]);

	t_size : int = t_var.t_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0)
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,16), RamMem(.sbp,16)),
		MakeFloatInstr(.add, RamMem(.sbp,24), RamMem(.sbp,16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp, 32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp, 40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0,1)
		MakeMI(.mov, RamMem(.sbp,t_size+0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,t_size+8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,t_size+16), Imm(1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,t_size+16), RamMem(.sbp,t_size+16)),
		MakeFloatInstr(.add, RamMem(.sbp,t_size+24), RamMem(.sbp,t_size+16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,t_size+32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp,t_size+40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		// tano(1,0) ~= tano(0,0);
		MakeMI(.tmov, RamMem(.sbp,t_size), RamMem(.sbp,0)),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,2)
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(2), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,16), RamMem(.sbp,16)),
		MakeFloatInstr(.add, RamMem(.sbp,24), RamMem(.sbp,16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp, 32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp, 40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		// t : tano = tano(0,2);
		//Optimized out since we are moving to the same place
		// MakeMI(.mov, RamMem(.sbp,32), RamMem(.sbp,0)),

		//tano(0,1)
		MakeMI(.mov, RamMem(.sbp,t_size+0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,t_size+8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,t_size+16), Imm(1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,t_size+16), RamMem(.sbp,t_size+16)),
		MakeFloatInstr(.add, RamMem(.sbp,t_size+24), RamMem(.sbp,t_size+16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,t_size+32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp,t_size+40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//t ~= tano(0,1);
		MakeMI(.tmov, RamMem(.sbp,0), RamMem(.sbp,t_size+0)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);


//TODO could test that ~= should not work with other types on LHS
#if 0 {
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
}

} @UnitTest

//TODO Test from array = tano
Test_TanoTEqArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	tano(0,0) ~= int.[0,4,11];

	a : [2] int = int.[0,2];
	tano(0,1) ~= a;

	av : [] int = a;
	tano(0,2) ~= av;

	//TODO Test float and neume arrays for each case above
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(3, cd.all_type_info_array.count);
	if !count_equal return;
	f3_info : *TypeInfoArray = cd.all_type_info_array[0];
	f2_info : *TypeInfoArray = cd.all_type_info_array[1];
	view_info : *TypeInfoArray = cd.all_type_info_array[2];

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("a", f2_info),
		VarDecl("av", view_info),
	]);
	if !vars_equal return;
	a_var := cd.all_variables[0];
	av_var := cd.all_variables[1];

	instr_index : int = 0;
	//Size of the fixed array int.[0,4,11]
	fa : int = 24;
	TestNextManyInstr(*instr_index, cd, .[
		//int.[7,11]
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(4), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(11), Imm(cd.int_type_info.runtime_size)),

		//tano(0,0)
		MakeMI(.mov, RamMem(.sbp,fa+0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,fa+8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,fa+16), Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,fa+16), RamMem(.sbp,fa+16)),
		MakeFloatInstr(.add, RamMem(.sbp,fa+24), RamMem(.sbp,fa+16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,fa+32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0,0) ~= int.[7,11];
		MakeMI(.add, RegMem(.ax), RegMem(.sbp), Imm(0)),
		MakeMI(.tmov, RamMem(.sbp,fa), RamArray(3,RegDef.ax)),
	]);

	a_0, a_1 := GetMemoryAddressAsOperands(a_var.op);
	AssertEquals(0, a_1.int_value);
	av_pos : int = a_var.t_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//a : [2] int = int.[0,2];
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(8)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(2), Imm(8)),

		//tano(0,1)
		MakeMI(.mov, RamMem(.sbp,av_pos+0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,av_pos+8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,av_pos+16), Imm(1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,av_pos+16), RamMem(.sbp,av_pos+16)),
		MakeFloatInstr(.add, RamMem(.sbp,av_pos+24), RamMem(.sbp,av_pos+16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,av_pos+32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0,1) ~= a;
		MakeMI(.add, RegMem(.ax), a_0, a_1),
		MakeMI(.tmov, RamMem(.sbp,av_pos), RamArray(2,RegDef.ax)),
	]);

	av_0, av_1 := GetMemoryAddressAsOperands(av_var.op);
	AssertEquals(av_pos, av_1.int_value);
	p_pos : int = av_pos + av_var.t_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//av.count
		MakeMI(.mov, av_var.op, Imm(f2_info.array_count), Imm(cd.int_type_info.runtime_size)),
		//av.data
		MakeMI(.add, AddOperandOffset(8,av_var.op), a_0, a_1),

		//tano(0,1)
		MakeMI(.mov, RamMem(.sbp,p_pos+0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,p_pos+8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,p_pos+16), Imm(2), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,p_pos+16), RamMem(.sbp,p_pos+16)),
		MakeFloatInstr(.add, RamMem(.sbp,p_pos+24), RamMem(.sbp,p_pos+16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,p_pos+32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0,1) ~= a;
		//ax = a.count
		MakeMI(.mov, RegMem(.ax), av_var.op, Imm(cd.int_type_info.runtime_size)),
		//bx = a.data
		MakeMI(.mov, RegMem(.bx), AddOperandOffset(8,av_var.op), Imm(cd.void_pointer_type_info.runtime_size)),
		MakeMI(.tmov, RamMem(.sbp,p_pos), RamArray(RegDef.ax,RegDef.bx)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);


//TODO could test that ~= should not work with other types on LHS
#if 0 {
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
}

} @UnitTest

TanoIntIntTestInstr :: (
	op : MusicOperand, 
	row_op : MusicOperand,
	x_start_op : MusicOperand,
	cd : *CompilationData) 
-> [] MusicInstruction 
{
	op_ofs := GetTanoOpOffsets(op);
	arr := NewArray(6, MusicInstruction, false);
	arr[0] = MakeMI(.mov, op_ofs.row_start_op, row_op, Imm(cd.int_type_info.runtime_size));
	arr[1] = MakeMI(.mov, op_ofs.row_end_op, row_op, Imm(cd.int_type_info.runtime_size));
	arr[2] = MakeMI(.mov, op_ofs.x_start_op, x_start_op, Imm(cd.float_type_info.runtime_size));
	arr[3] = MakeMI(.itof, op_ofs.x_start_op, op_ofs.x_start_op);
	arr[4] = MakeFloatInstr(.add, op_ofs.x_end_op, op_ofs.x_start_op, FImm(1));
	arr[5] = MakeMI(.mov, op_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size));
	// MakeMI(.mov, RamMem(.sbp, 40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	return arr;
}

Test_TanoTilde :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	tano(0,1) ~= tano(0,0) ~ 4;
	tano(0,2) ~= 4.0 ~ tano(0,0);
	tano(0,3) ~= tano(0,0) ~ tano(0,2);

	//TODO Maybe add ~ binary op to a different test
	// t2 ~= t1;
	// t3 ~= t1 ~ t2;
	// tano(0,0:10) ~= int.[0,4,7];
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) + 1;
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) ~ 
	//    (tano(1,0:5) ~ int.[0,3,7]);
}
DONE,,unit_test_alloc);

	#if 0 {
	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];
	}

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(RamMem(.sbp,0), Imm(0), Imm(0), cd));

	s1 : int = 40;
	TestNextManyInstr(*instr_index, cd, 
		TanoStackTestInstr(RamMem(.sbp,s1), RamMem(.sbp,0), cd)
	);
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0) ~ 4.0;
		MakeMI(.mov, RegMem(.ax), Imm(4)),
		MakeMI(.tmov, RamMem(.sbp,s1), RegMem(.ax)),
	]);

	//tano(0,0) ~ 4.0;
	s2 : int = s1 + cd.tano_struct_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(RamMem(.sbp,s2), Imm(0), Imm(1), cd));
	//tano(0,1) = tano(0,0) ~ 4.0;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, RamMem(.sbp,s2), RamMem(.sbp,s1)),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),
	]);


	TestNextManyInstr(*instr_index, cd,
		TanoIntIntTestInstr(RamMem(.sbp,0), Imm(0), Imm(0), cd));
	TestNextManyInstr(*instr_index, cd, 
		TanoStackTestInstr(RamMem(.sbp,s1), RamMem(.sbp,0), cd));
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,1) = 4.0 ~ tano(0,0);
		MakeMI(.mov, RegMem(.ax), FImm(4)),
		MakeFloatInstr(.tmov, RamMem(.sbp,s1), RegMem(.ax)),
	]);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(RamMem(.sbp,s2), Imm(0), Imm(2), cd));
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, RamMem(.sbp,s2), RamMem(.sbp,s1)),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),
	]);

	//tano(0,0)
	TestNextManyInstr(*instr_index, cd,
		TanoIntIntTestInstr(RamMem(.sbp,0), Imm(0), Imm(0), cd));
	//tano(0,2)
	TestNextManyInstr(*instr_index, cd,
		TanoIntIntTestInstr(RamMem(.sbp,s1), Imm(0), Imm(2), cd));
	//tano(0,0) ~ tano(0,2);
	TestNextManyInstr(*instr_index, cd,
		TanoStackTestInstr(RamMem(.sbp,s2), RamMem(.sbp,0), cd));
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, RamMem(.sbp,s2), RamMem(.sbp,s1), ImmEnum(TMovRamType.TANO)),
	]);

	s3 : int = s2 + cd.tano_struct_info.runtime_size;
	//tano(0,3)
	TestNextManyInstr(*instr_index, cd,
		TanoIntIntTestInstr(RamMem(.sbp,s3), Imm(0), Imm(3), cd));
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, RamMem(.sbp,s3), RamMem(.sbp,s2)),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),
		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

//TODO could test that ~= should not work with other types on LHS
#if 0 {
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
}

} @UnitTest

Test_TanoTildeArray :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	tano(0,1) ~= tano(0,0) ~ int.[7,11];
	tano(0,2) ~= float.[1.,2.] ~ tano(0,0);
	//TODO Also neume arrays maybe can test that with neumes

	//TODO Also do neumes in a separate case
	//can instantiate neume without struct literal for now
	// tano(0,4) ~= tano(0,1) ~ neume.{};

	//TODO Maybe add ~ binary op to a different test
	// t2 ~= t1;
	// t3 ~= t1 ~ t2;
	// tano(0,0:10) ~= int.[0,4,7];
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) + 1;
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) ~ 
	//    (tano(1,0:5) ~ int.[0,3,7]);
}
DONE,,unit_test_alloc);

	#if 0 {
	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];
	}

	instr_index : int = 0;
	//tano(0,0);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(RamMem(.sbp,0), Imm(0), Imm(0), cd));
	s1 : int = cd.tano_struct_info.runtime_size;
	//int.[7,11]
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RamMem(.sbp,s1), Imm(7), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,s1+8), Imm(11), Imm(cd.int_type_info.runtime_size)),
	]);

	s2 : int = s1 + 2*cd.int_type_info.runtime_size;
	//tano(0,0) ~ int.[7,11];
	TestNextManyInstr(*instr_index, cd, 
		TanoStackTestInstr(RamMem(.sbp,s2), RamMem(.sbp,0), cd));
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, RegMem(.ax), RegMem(.sbp), Imm(s1)),
		MakeMI(.tmov, RamMem(.sbp,s2), RamArray(2,RegDef.ax), ImmEnum(TMovArrayType.DEFAULT)),
	]);

	s3 : int = s2 + cd.tano_struct_info.runtime_size;
	//tano(0,1);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(RamMem(.sbp,s3), Imm(0), Imm(1), cd));
	//tano(0,1) = tano(0,0) ~ int.[7,11];
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, RamMem(.sbp,s3), RamMem(.sbp,s2)),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),
	]);

	//tano(0,2) ~= float.[1.,2.] ~ tano(0,1);
	//int.[7,11]
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RamMem(.sbp,0), FImm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), FImm(2), Imm(cd.int_type_info.runtime_size)),
	]);
	//tano(0,0);
	s1 = 2*cd.int_type_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(RamMem(.sbp,s1), Imm(0), Imm(0), cd));

	s2 = s1 + cd.tano_struct_info.runtime_size;
	//tano(0,0) ~ int.[7,11];
	TestNextManyInstr(*instr_index, cd, 
		TanoStackTestInstr(RamMem(.sbp,s2), RamMem(.sbp,s1), cd));
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, RegMem(.ax), RegMem(.sbp), Imm(0)),
		MakeMI(.tmov, RamMem(.sbp,s2), RamArray(2,RegDef.ax), ImmEnum(TMovArrayType.DEFAULT)),
	]);

	s3 = s2 + cd.tano_struct_info.runtime_size;
	//tano(0,2);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(RamMem(.sbp,s3), Imm(0), Imm(2), cd));
	//tano(0,2) = tano(0,0) ~ int.[7,11];
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, RamMem(.sbp,s3), RamMem(.sbp,s2)),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

//TODO could test that ~= should not work with other types on LHS
#if 0 {
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
}

} @UnitTest

Test_TanoTildeNeume :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	n : neume;
	n.svara = 1.;
	t0 := tano(0,0);
	t0 ~= n;
	t1 := tano(0,1);
	t1 ~= t0 ~ n;

	n1 : neume;
	n1.svara = 2.;
	na : [2] neume = neume.[n,n1];
	tano(0,2) ~= t0 ~ na;

	//TODO Could allow for directional ops later for easier
	//neume memory management. Something like this I think would work
	// <~ and ~> would be move neumes in place
	// ~+ and ~-, ... would be add/sub/op in place
	//So na would go into t0 here
	// tano(0,2) ~= t0 <~ na;
	// t0 goes into tano(1,0) and then we add 1 to tano(1,0) permanently, 
	// not temporarily like with t + 1 and we only 1 tano with arithmetic
	//operations so it just does the right one there.
	// (tano(1,0) <~ t0) ~+ 1;
	//Ultimately this would allow us to do something like this without any extra constructs.
	// ta : [] tano = tano.[
	// 	tano(1,0) ~+ 1, 
	// 	(tano(2,0) <~ tano(0,0)) ~+ 2,
	// ];

	//TODO Maybe add ~ binary op to a different test
	// t2 ~= t1;
	// t3 ~= t1 ~ t2;
	// tano(0,0:10) ~= int.[0,4,7];
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) + 1;
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) ~ 
	//    (tano(1,0:5) ~ int.[0,3,7]);
}
DONE,,unit_test_alloc);

	na_type, found_na_type := GetArrayType(cd, *cd.neume_struct_info, ArrayInfoType.FIXED, 2);
	AssertEquals(true, found_na_type);
	if !found_na_type return;

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("n", *cd.neume_struct_info),
		VarDecl("t0", *cd.tano_struct_info),
		VarDecl("t1", *cd.tano_struct_info),
		VarDecl("n1", *cd.neume_struct_info),
		VarDecl("na", na_type),
	]);
	if !vars_equal return;
	n_var := cd.all_variables[0];
	t0_var := cd.all_variables[1];
	t1_var := cd.all_variables[2];
	n1_var := cd.all_variables[3];
	na_var := cd.all_variables[4];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//n : neume;
		MakeMI(.mset, n_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.mov, n_var.op, FImm(1.), Imm(cd.float_type_info.runtime_size)),
	]);

	// s1 : int = cd.neume_struct_info.runtime_size;
	//t0 := tano(0,0);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(t0_var.op, Imm(0), Imm(0), cd));
	//t0 ~= n;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, t0_var.op, n_var.op, ImmEnum(TMovRamType.NEUME)),
	]);

	//t1 := tano(0,1);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(t1_var.op, Imm(0), Imm(1), cd));
	//t0 ~ n;
	stack_op := AddOperandOffset(cd.tano_struct_info.runtime_size, t1_var.op);
	TestNextManyInstr(*instr_index, cd, 
		TanoStackTestInstr(stack_op, t0_var.op, cd));
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, stack_op, n_var.op, ImmEnum(TMovArrayType.NEUME)),
	]);
	// t1 ~= t0 ~ n;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, t1_var.op, stack_op),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),
	]);

	//n1 : neume;
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mset, n1_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.mov, n1_var.op, FImm(2.), Imm(cd.float_type_info.runtime_size)),
	]);

	//na : [2] neume = neume.[n,n1];
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, na_var.op, n_var.op, Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(cd.neume_struct_info.runtime_size,na_var.op), n1_var.op, Imm(cd.neume_struct_info.runtime_size)),
	]);

	//t0 ~ na;
	s2_op := AddOperandOffset(na_type.runtime_size, na_var.op);
	TestNextManyInstr(*instr_index, cd, 
		TanoStackTestInstr(s2_op, t0_var.op, cd));
	na_0, na_1 := GetMemoryAddressAsOperands(na_var.op);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, RegMem(.ax), na_0, na_1),
		MakeMI(.tmov, s2_op, RamArray(2,RegDef.ax), ImmEnum(TMovArrayType.NEUME)),
	]);
	//tano(0,2);
	t2_op := AddOperandOffset(cd.tano_struct_info.runtime_size, s2_op);
	TestNextManyInstr(*instr_index, cd,
		TanoIntIntTestInstr(t2_op, Imm(0), Imm(2), cd));
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, t2_op, s2_op),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_TanoOpEqual :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	t0 := tano(0,0);
	t0 += 1;
	t0 -= 1;
	t0 *= 1;
	t0 /= 1;
	t0 %= 12.0;
}
DONE,,unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("t0", *cd.tano_struct_info),
	]);
	if !vars_equal return;
	t0_var := cd.all_variables[0];

	instr_index : int = 0;
	//t0 := tano(0,0);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(t0_var.op, Imm(0), Imm(0), cd));

	TestNextManyInstr(*instr_index, cd, .[
		// t0 += 1;
		MakeMI(.mov, RegMem(.ax), Imm(1)),
		MakeMI(.tadd, t0_var.op, RegMem(.ax)),

		// t0 -= 1;
		MakeMI(.mov, RegMem(.ax), Imm(1)),
		MakeMI(.tsub, t0_var.op, RegMem(.ax)),

		// t0 *= 1;
		MakeMI(.mov, RegMem(.ax), Imm(1)),
		MakeMI(.tmul, t0_var.op, RegMem(.ax)),

		// t0 /= 1;
		MakeMI(.mov, RegMem(.ax), Imm(1)),
		MakeMI(.tdiv, t0_var.op, RegMem(.ax)),

		// t0 %= 12.0;
		MakeMI(.mov, RegMem(.ax), FImm(12.)),
		MakeFloatInstr(.tmod, t0_var.op, RegMem(.ax)),

		MakeMI(.exit),
	]);	

	AssertEquals(instr_index, cd.all_music_instructions.count);


	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	n : neume;
	tano(0,0) += n;
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

} @UnitTest

Test_OpError :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
  //t0 is not defined so it should throw an error.
  tano(0,0) ~= t0;
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

} @UnitTest

Test_FuncError :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

//Invalid input since t DNE so is not r or l value
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
foo :: (i : int) {
	x := i;
}
main :: () {
	foo(t);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//Invalid argument float when functiont takes int
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
foo :: (i : int) {
	x := i;
}
main :: () {
	f : float = 2.5;
	foo(f);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


//TEST Same name and arg types
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
foo :: (i : int, y : float) {
}
foo :: (i : int, n : float) {
}
main :: () {
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


//TEST Same name and arg types
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
foo :: (i : int) -> int {
	return 0;
}
foo :: (i : int) -> float {
	return 1.;
}
main :: () {
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


} @UnitTest

//TODO FROM HERE finish this test with absolute value on diff
//and then try an integration test with ~= with reverse and 
//also reverse with tano + 1 before doing array literals and then functions.
//TODO Also possibly remove mspace_end for now.
Test_TanoTAdd :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	tano(0,1) ~= tano(0,0) + 1;
	//TODO FROM HERE Write unit test for this and 
	//probably place in another test and do all at once.
	// tano(0,1) += 1;

	//TODO Can make ~+ another default operation if needed later.
	//Or leave it there for ppl to create their own.
	// tano(0,1) ~= tano(0,0) ~+ 1;
	// tano(0,1) ~+= 1;

	//TODO This could be adding 1 to row
	//and if it's float it could be adding 1 to x
	//and then an array of 2 ints or 2 floats
	//could be adding to start and end for example
	// t := tano(0,0) + 1;

	//TODO Maybe add ~ binary op to a different test
	// t2 ~= t1;
	// t3 ~= t1 ~ t2;
	// tano(0,0:10) ~= int.[0,4,7];
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) + 1;
	// tano(1,0) ~= (tano(0,0:5) ~ int.[0,4,7]) ~ 
	//    (tano(1,0:5) ~ int.[0,3,7]);
}
DONE,,unit_test_alloc);

	// vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		// VarDecl("t", *cd.tano_struct_info),
	// ]);
	// if !vars_equal return;
	// t_var := cd.all_variables[0];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0)
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,16), RamMem(.sbp,16)),
		MakeFloatInstr(.add, RamMem(.sbp,24), RamMem(.sbp,16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp,40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	]);

	tano_s : int = cd.tano_struct_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, 
		TanoStackTestInstr(RamMem(.sbp,tano_s), RamMem(.sbp,0), cd)
	);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RegMem(.ax), Imm(1)),
		MakeMI(.tadd, RamMem(.sbp,tano_s), RegMem(.ax)),
	]);

	tano_1 : int = tano_s+cd.tano_struct_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,1)
		MakeMI(.mov, RamMem(.sbp,tano_1+0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,tano_1+8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,tano_1+16), Imm(1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,tano_1+16), RamMem(.sbp,tano_1+16)),
		MakeFloatInstr(.add, RamMem(.sbp,tano_1+24), RamMem(.sbp,tano_1+16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,tano_1+32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp,tano_1+40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0,1) ~= tano(0,0) + 1;
		MakeMI(.tmov, RamMem(.sbp,tano_1), RamMem(.sbp,tano_s)),
		//reset tsp and tbp only gets reset on a function call
		//if we have tano as arguments.
		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);


//TODO could test that ~= should not work with other types on LHS
#if 0 {
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
}

} @UnitTest

Test_TanoTSub :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	tano(0,1) ~= 12 - tano(0,0);
	//TODO We can just make a function for this and use this input
	// t01 := tano(0,1);
	// #asm{tsub 12, t01;}
	//Instead of this use asm like above with a function
	// 12 -= tano(0,1);
}
DONE,,unit_test_alloc);

	// vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		// VarDecl("t", *cd.tano_struct_info),
	// ]);
	// if !vars_equal return;
	// t_var := cd.all_variables[0];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0)
		MakeMI(.mov, RamMem(.sbp,0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,16), Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,16), RamMem(.sbp,16)),
		MakeFloatInstr(.add, RamMem(.sbp,24), RamMem(.sbp,16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp,40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	]);

	tano_s : int = cd.tano_struct_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//Create tano on tano_stack for tadd
		MakeMI(.mov, RamMem(.sbp,tano_s), RamMem(.sbp,0), Imm(cd.tano_struct_info.runtime_size)),
		//Move next row_start on tano_stack
		MakeMI(.mov, RamMem(.sbp,tano_s), RegMem(.tsp)),
		//to_row_end = abs(from_row_diff)
		MakeMI(.sub, RegMem(.ax), RamMem(.sbp,8), RamMem(.sbp,0)),
		MakeMI(.abs, RegMem(.ax), RegMem(.ax)),
		MakeMI(.add, RamMem(.sbp,tano_s+8), RamMem(.sbp,tano_s), RegMem(.ax)),
		//update the tsp tano_stack_pointer
		MakeMI(.add, RegMem(.tsp), RegMem(.ax)),
		MakeMI(.add, RegMem(.tsp), Imm(1)),
		//x starts at 0 always so we don't have any offset on tano_stack
		MakeFloatInstr(.mov, RamMem(.sbp,tano_s+16), FImm(0)),
		//to_x_end = abs(from_x_diff)
		MakeFloatInstr(.sub, RegMem(.ax), RamMem(.sbp,24), RamMem(.sbp,16)),
		MakeFloatInstr(.abs, RegMem(.ax), RegMem(.ax)),
		MakeFloatInstr(.add, RamMem(.sbp,tano_s+24), RamMem(.sbp,tano_s+16), RegMem(.ax)),
		//Set the mspace_index
		MakeMI(.mov, RamMem(.sbp,tano_s+32), Imm(TANO_STACK_MSPACE)),
		// MakeMI(.mov, RamMem(.sbp,tano_s+40), Imm(TANO_STACK_MSPACE)),
		//Move the music pts over (from_tano maintains the x/row direction)
		//tano_stack = tano(0,0) + 1
		MakeMI(.tmov, RamMem(.sbp,tano_s), RamMem(.sbp,0)),
		MakeMI(.mov, RegMem(.ax), Imm(12)),
		MakeMI(.tsub, RegMem(.ax), RamMem(.sbp,tano_s)),
	]);

	tano_1 : int = tano_s+cd.tano_struct_info.runtime_size;
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,1)
		MakeMI(.mov, RamMem(.sbp,tano_1+0), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,tano_1+8), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, RamMem(.sbp,tano_1+16), Imm(1), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, RamMem(.sbp,tano_1+16), RamMem(.sbp,tano_1+16)),
		MakeFloatInstr(.add, RamMem(.sbp,tano_1+24), RamMem(.sbp,tano_1+16), FImm(1)),
		MakeMI(.mov, RamMem(.sbp,tano_1+32), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
		// MakeMI(.mov, RamMem(.sbp,tano_1+40), RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(0,1) ~= 12 - tano(0,0);
		MakeMI(.tmov, RamMem(.sbp,tano_1), RamMem(.sbp,tano_s)),
		//reset tsp and tbp only gets reset on a function call
		//if we have tano as arguments.
		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);


//TODO could test that ~= should not work with other types on LHS
#if 0 {
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {
	f : [] float = NewArray(3.1,float);
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);
}

} @UnitTest

//TODO Maybe can have 1 simpler unit test that just adds a neume
//to a tano in a function with an int or float as second arg
//ALSO do a test with 
Test_TanoFuncOp :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
foo :: (t : tano) -> tano {
  return t + 1;
}
main :: () {
  tano(1,0) ~= foo(tano(0,0));
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	if !count_equal return;
	AssertEquals("foo", cd.all_function_declarations[0].name);
	AssertEquals("main", cd.all_function_declarations[1].name);
	count_equal = AssertEquals(1, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[0].function_id);
		AssertEquals("t", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.TANO, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);
	}

	count_equal = AssertEquals(1, cd.all_function_return_variables.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_return_variables[0].function_id);
		AssertEquals(TypeInfoTag.TANO, cd.all_function_return_variables[0].t_info.type_enum);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//t in foo
		VarDecl("t", *cd.tano_struct_info, RamMem(.sbp,0)),
		//t in main
		// VarDecl("t", *cd.tano_struct_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	t_foo_var := cd.all_variables[0];
	// t_main_var := cd.all_variables[1];


	scope_count := AssertEquals(3, cd.all_scope_data.count);
	if !scope_count return;
	AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
	AssertEquals(0, cd.all_scope_data[0].start_instr_index);
	AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

	foo_scope : ScopeData = cd.all_scope_data[1];
	AssertEquals(foo_scope.function_id, cd.all_function_declarations[0].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);

	main_scope : ScopeData = cd.all_scope_data[2];
	AssertEquals(main_scope.function_id, cd.all_function_declarations[1].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);


	t_stack_op := RamMem(.sbp, cd.tano_struct_info.runtime_size);
	t_stack_ofs := GetTanoOpOffsets(t_stack_op);
	t_foo_ofs := GetTanoOpOffsets(t_foo_var.op);

	instr_index : int = 0;
	// start_foo_instr_index : int = instr_index;
	//foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Create tano on tano_stack for tadd
		MakeMI(.mov, t_stack_op, t_foo_var.op, Imm(cd.tano_struct_info.runtime_size)),
		//Move next row_start on tano_stack
		MakeMI(.mov, t_stack_ofs.row_start_op, RegMem(.tsp)),
		//to_row_end = abs(from_row_diff)
		MakeMI(.sub, RegMem(.ax), t_foo_ofs.row_end_op, t_foo_ofs.row_start_op),
		MakeMI(.abs, RegMem(.ax), RegMem(.ax)),
		MakeMI(.add, t_stack_ofs.row_end_op, t_stack_ofs.row_start_op, RegMem(.ax)),
		//update the tsp tano_stack_pointer
		MakeMI(.add, RegMem(.tsp), RegMem(.ax)),
		MakeMI(.add, RegMem(.tsp), Imm(1)),
		//x starts at 0 always so we don't have any offset on tano_stack
		MakeFloatInstr(.mov, t_stack_ofs.x_start_op, FImm(0)),
		//to_x_end = abs(from_x_diff)
		MakeFloatInstr(.sub, RegMem(.ax), t_foo_ofs.x_end_op, t_foo_ofs.x_start_op),
		MakeFloatInstr(.abs, RegMem(.ax), RegMem(.ax)),
		MakeFloatInstr(.add, t_stack_ofs.x_end_op, t_stack_ofs.x_start_op, RegMem(.ax)),
		//Set the mspace_index
		MakeMI(.mov, t_stack_ofs.mspace_op, Imm(TANO_STACK_MSPACE)),
		// MakeMI(.mov, RamMem(.sbp,tano_s+40), Imm(TANO_STACK_MSPACE)),
		//Move the music pts over (from_tano maintains the x/row direction)
		//tano_stack = tano(0,0) + 1
		MakeMI(.tmov, t_stack_op, t_foo_var.op),
		MakeMI(.mov, RegMem(.ax), Imm(1)),
		MakeMI(.tadd, t_stack_op, RegMem(.ax)),

		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.tano_struct_info.runtime_size), 
			t_stack_op, 
			Imm(cd.tano_struct_info.runtime_size)),
		MakeMI(.ret),
	]);

	// AssertEquals(start_foo_instr_index, foo_scope.start_instr_index);
	// AssertEquals(instr_index-1, foo_scope.end_instr_index);

	//main function
	AssertEquals(instr_index, cd.main_function_instr_index);

	t0_op := RamMem(.sbp,0);
	t_main_ofs := GetTanoOpOffsets(t0_op);
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0)
		MakeMI(.mov, t_main_ofs.row_start_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_main_ofs.row_end_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_main_ofs.x_start_op, Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, t_main_ofs.x_start_op, t_main_ofs.x_start_op),
		MakeFloatInstr(.add, t_main_ofs.x_end_op, t_main_ofs.x_start_op, FImm(1)),
		MakeMI(.mov, t_main_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	]);

	stack_p : int = 2*cd.tano_struct_info.runtime_size;
	next_stack_p : int = PRE_PROC_STACK_SIZE + stack_p;
	//foo(tano(0,0))
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,stack_p)),
		//Push on tano argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), t0_op, Imm(cd.tano_struct_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(0)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),
	]);

	foo_return_op := RamMem(.sbp, cd.tano_struct_info.runtime_size);
	//tano(1,0) goes after tano(0,0) AND also the return of foo
	t1_op := RamMem(.sbp,2*cd.tano_struct_info.runtime_size);
	t1_ofs := GetTanoOpOffsets(t1_op);
	TestNextManyInstr(*instr_index, cd, .[
		//tano(1,0)
		MakeMI(.mov, t1_ofs.row_start_op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t1_ofs.row_end_op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t1_ofs.x_start_op, Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, t1_ofs.x_start_op, t1_ofs.x_start_op),
		MakeFloatInstr(.add, t1_ofs.x_end_op, t1_ofs.x_start_op, FImm(1)),
		MakeMI(.mov, t1_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(1,0) ~= foo(tano(0,0));
		MakeMI(.tmov, t1_op, foo_return_op),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

/*TODO FROM HERE try updating stack .sbp before args (maybe or maybe not if it actually works)
write integration tests for these unit tests and then do neumes with tanos and then functions
also maybe a unit test with "foo :: (t : tano, i : int)"
*/
/*DOC : This tests that we set the tbp on the function call
since we've place things on the tano stack in a function input argument

So technically it is all this just for checking the tbp instruction
gets added on the function call maybe doing
"foo(-tano(0,0))" would be clearer and less test code instead
*/
Test_TanoFuncInputOp :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
foo :: (t : tano) {
  tano(1,0) ~= t;
}
main :: () {
  foo(12 - tano(0,0));
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	if !count_equal return;
	AssertEquals("foo", cd.all_function_declarations[0].name);
	AssertEquals("main", cd.all_function_declarations[1].name);
	count_equal = AssertEquals(1, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[0].function_id);
		AssertEquals("t", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.TANO, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//t in foo
		VarDecl("t", *cd.tano_struct_info, RamMem(.sbp,0)),
		//t in main
		// VarDecl("t", *cd.tano_struct_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	t_foo_var := cd.all_variables[0];
	// t_main_var := cd.all_variables[1];

	t_foo_ofs := GetTanoOpOffsets(t_foo_var.op);

	scope_count := AssertEquals(3, cd.all_scope_data.count);
	if !scope_count return;
	AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
	AssertEquals(0, cd.all_scope_data[0].start_instr_index);
	AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

	foo_scope : ScopeData = cd.all_scope_data[1];
	AssertEquals(foo_scope.function_id, cd.all_function_declarations[0].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);


	instr_index : int = 0;
	t1_op := RamMem(.sbp,cd.tano_struct_info.runtime_size);
	t1_ofs := GetTanoOpOffsets(t1_op);
	TestNextManyInstr(*instr_index, cd, .[
		//tano(1,0)
		MakeMI(.mov, t1_ofs.row_start_op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t1_ofs.row_end_op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t1_ofs.x_start_op, Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, t1_ofs.x_start_op, t1_ofs.x_start_op),
		MakeFloatInstr(.add, t1_ofs.x_end_op, t1_ofs.x_start_op, FImm(1)),
		MakeMI(.mov, t1_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(1,0) ~= t;
		MakeMI(.tmov, t1_op, t_foo_var.op),

		MakeMI(.ret),
	]);

	t0_op := RamMem(.sbp,0);
	t0_ofs := GetTanoOpOffsets(t0_op);
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0)
		MakeMI(.mov, t0_ofs.row_start_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t0_ofs.row_end_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t0_ofs.x_start_op, Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, t0_ofs.x_start_op, t0_ofs.x_start_op),
		MakeFloatInstr(.add, t0_ofs.x_end_op, t0_ofs.x_start_op, FImm(1)),
		MakeMI(.mov, t0_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	]);

	t_stack_op := RamMem(.sbp, cd.tano_struct_info.runtime_size);
	t_stack_ofs := GetTanoOpOffsets(t_stack_op);

	// start_foo_instr_index : int = instr_index;
	//foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Create tano on tano_stack for tadd
		MakeMI(.mov, t_stack_op, t0_op, Imm(cd.tano_struct_info.runtime_size)),
		//Move next row_start on tano_stack
		MakeMI(.mov, t_stack_ofs.row_start_op, RegMem(.tsp)),
		//to_row_end = abs(from_row_diff)
		MakeMI(.sub, RegMem(.ax), t_foo_ofs.row_end_op, t_foo_ofs.row_start_op),
		MakeMI(.abs, RegMem(.ax), RegMem(.ax)),
		MakeMI(.add, t_stack_ofs.row_end_op, t_stack_ofs.row_start_op, RegMem(.ax)),
		//update the tsp tano_stack_pointer
		MakeMI(.add, RegMem(.tsp), RegMem(.ax)),
		MakeMI(.add, RegMem(.tsp), Imm(1)),
		//x starts at 0 always so we don't have any offset on tano_stack
		MakeFloatInstr(.mov, t_stack_ofs.x_start_op, FImm(0)),
		//to_x_end = abs(from_x_diff)
		MakeFloatInstr(.sub, RegMem(.ax), t_foo_ofs.x_end_op, t_foo_ofs.x_start_op),
		MakeFloatInstr(.abs, RegMem(.ax), RegMem(.ax)),
		MakeFloatInstr(.add, t_stack_ofs.x_end_op, t_stack_ofs.x_start_op, RegMem(.ax)),
		//Set the mspace_index
		MakeMI(.mov, t_stack_ofs.mspace_op, Imm(TANO_STACK_MSPACE)),
		// MakeMI(.mov, RamMem(.sbp,tano_s+40), Imm(TANO_STACK_MSPACE)),
		//Move the music pts over (from_tano maintains the x/row direction)
		//tano_stack = tano(0,0) + 1
		MakeMI(.tmov, t_stack_op, t0_op),
		MakeMI(.mov, RegMem(.ax), Imm(12)),
		MakeMI(.tsub, RegMem(.ax), t_stack_op),
	]);

	//2 tanos, 1 for tano(0,0) and 1 for "12 - tano(0,0)"
	stack_p : int = 2*cd.tano_struct_info.runtime_size;
	next_stack_p : int = PRE_PROC_STACK_SIZE + stack_p;
	//foo(tano(0,0))
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,stack_p)),
		//Push on tano argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), t_stack_op, Imm(cd.tano_struct_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Reset .tbp for the new stack since we have a tano op as input arg
		MakeMI(.mov, RegMem(.tbp), RegMem(.tsp)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+6)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(0)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		MakeMI(.tclear, Imm(-1), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);
	
} @UnitTest

/*TODO ADD THIS AS A TEST
once we have "~" then use this a full test
could add a neume as well to set
*/
Test_TanoFunc :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
foo :: (t : tano) -> tano {
  return t + 1;
}
main :: () {
  tano(1,0) ~= foo(tano(0,0) + 1) ~ foo(tano(1,1) - 1);
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	if !count_equal return;
	AssertEquals("foo", cd.all_function_declarations[0].name);
	AssertEquals("main", cd.all_function_declarations[1].name);
	count_equal = AssertEquals(1, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[0].function_id);
		AssertEquals("t", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.TANO, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);
	}

	count_equal = AssertEquals(1, cd.all_function_return_variables.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_return_variables[0].function_id);
		AssertEquals(TypeInfoTag.TANO, cd.all_function_return_variables[0].t_info.type_enum);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//t in foo
		VarDecl("t", *cd.tano_struct_info, RamMem(.sbp,0)),
		//t in main
		// VarDecl("t", *cd.tano_struct_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	t_foo_var := cd.all_variables[0];
	// t_main_var := cd.all_variables[1];


	scope_count := AssertEquals(3, cd.all_scope_data.count);
	if !scope_count return;
	AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
	AssertEquals(0, cd.all_scope_data[0].start_instr_index);
	AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

	foo_scope : ScopeData = cd.all_scope_data[1];
	AssertEquals(foo_scope.function_id, cd.all_function_declarations[0].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);

	main_scope : ScopeData = cd.all_scope_data[2];
	AssertEquals(main_scope.function_id, cd.all_function_declarations[1].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);


	t_stack_op := RamMem(.sbp, cd.tano_struct_info.runtime_size);
	t_stack_ofs := GetTanoOpOffsets(t_stack_op);
	t_foo_ofs := GetTanoOpOffsets(t_foo_var.op);

	instr_index : int = 0;
	// start_foo_instr_index : int = instr_index;
	//foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Create tano on tano_stack for tadd
		MakeMI(.mov, t_stack_op, t_foo_var.op, Imm(cd.tano_struct_info.runtime_size)),
		//Move next row_start on tano_stack
		MakeMI(.mov, t_stack_ofs.row_start_op, RegMem(.tsp)),
		//to_row_end = abs(from_row_diff)
		MakeMI(.sub, RegMem(.ax), t_foo_ofs.row_end_op, t_foo_ofs.row_start_op),
		MakeMI(.abs, RegMem(.ax), RegMem(.ax)),
		MakeMI(.add, t_stack_ofs.row_end_op, t_stack_ofs.row_start_op, RegMem(.ax)),
		//update the tsp tano_stack_pointer
		MakeMI(.add, RegMem(.tsp), RegMem(.ax)),
		MakeMI(.add, RegMem(.tsp), Imm(1)),
		//x starts at 0 always so we don't have any offset on tano_stack
		MakeFloatInstr(.mov, t_stack_ofs.x_start_op, FImm(0)),
		//to_x_end = abs(from_x_diff)
		MakeFloatInstr(.sub, RegMem(.ax), t_foo_ofs.x_end_op, t_foo_ofs.x_start_op),
		MakeFloatInstr(.abs, RegMem(.ax), RegMem(.ax)),
		MakeFloatInstr(.add, t_stack_ofs.x_end_op, t_stack_ofs.x_start_op, RegMem(.ax)),
		//Set the mspace_index
		MakeMI(.mov, t_stack_ofs.mspace_op, Imm(TANO_STACK_MSPACE)),
		// MakeMI(.mov, RamMem(.sbp,tano_s+40), Imm(TANO_STACK_MSPACE)),
		//Move the music pts over (from_tano maintains the x/row direction)
		//tano_stack = tano(0,0) + 1
		MakeMI(.tmov, t_stack_op, t_foo_var.op),
		MakeMI(.mov, RegMem(.ax), Imm(1)),
		MakeMI(.tadd, t_stack_op, RegMem(.ax)),

		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.tano_struct_info.runtime_size), 
			t_stack_op, 
			Imm(cd.tano_struct_info.runtime_size)),
		MakeMI(.ret),
	]);

	// AssertEquals(start_foo_instr_index, foo_scope.start_instr_index);
	// AssertEquals(instr_index-1, foo_scope.end_instr_index);

	//main function
	AssertEquals(instr_index, cd.main_function_instr_index);

	t0_op := RamMem(.sbp,0);
	t_main_ofs := GetTanoOpOffsets(t0_op);
	TestNextManyInstr(*instr_index, cd, .[
		//tano(0,0)
		MakeMI(.mov, t_main_ofs.row_start_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_main_ofs.row_end_op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t_main_ofs.x_start_op, Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, t_main_ofs.x_start_op, t_main_ofs.x_start_op),
		MakeFloatInstr(.add, t_main_ofs.x_end_op, t_main_ofs.x_start_op, FImm(1)),
		MakeMI(.mov, t_main_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),
	]);

	stack_p : int = 2*cd.tano_struct_info.runtime_size;
	next_stack_p : int = PRE_PROC_STACK_SIZE + stack_p;
	//foo(tano(0,0))
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,stack_p)),
		//Push on tano argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), t0_op, Imm(cd.tano_struct_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(0)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),
	]);

	foo_return_op := RamMem(.sbp, cd.tano_struct_info.runtime_size);
	//tano(1,0) goes after tano(0,0) AND also the return of foo
	t1_op := RamMem(.sbp,2*cd.tano_struct_info.runtime_size);
	t1_ofs := GetTanoOpOffsets(t1_op);
	TestNextManyInstr(*instr_index, cd, .[
		//tano(1,0)
		MakeMI(.mov, t1_ofs.row_start_op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t1_ofs.row_end_op, Imm(1), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, t1_ofs.x_start_op, Imm(0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.itof, t1_ofs.x_start_op, t1_ofs.x_start_op),
		MakeFloatInstr(.add, t1_ofs.x_end_op, t1_ofs.x_start_op, FImm(1)),
		MakeMI(.mov, t1_ofs.mspace_op, RegMem(.dfms), Imm(cd.int_type_info.runtime_size)),

		//tano(1,0) ~= foo(tano(0,0));
		MakeMI(.tmov, t1_op, foo_return_op),

		MakeMI(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp)),
		MakeMI(.mov, RegMem(.tsp), RegMem(.tbp)),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

}

Test_TanoNeumeFunc :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
foo :: (t : tano, n : neume) {
  t ~= n;
}
main :: () {
  n : neume;
  n.svara = 1.;
  n.x_end = 1.5;
  foo(tano(0,0), n);
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	if !count_equal return;
	AssertEquals("foo", cd.all_function_declarations[0].name);
	AssertEquals("main", cd.all_function_declarations[1].name);
	count_equal = AssertEquals(2, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[0].function_id);
		AssertEquals("t", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.TANO, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);

		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[1].function_id);
		AssertEquals("n", cd.all_function_arguments[1].name);
		AssertEquals(TypeInfoTag.NEUME, cd.all_function_arguments[1].t_info.type_enum);
		AssertEquals(cd.tano_struct_info.runtime_size, cd.all_function_arguments[1].var_bytes_from_sbp);
	}
	AssertEquals(0, cd.all_function_return_variables.count);

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//t in foo
		VarDecl("t", *cd.tano_struct_info, RamMem(.sbp,0)),
		//n in foo
		VarDecl("n", *cd.neume_struct_info, RamMem(.sbp,cd.tano_struct_info.runtime_size)),
		//n in main
		VarDecl("n", *cd.neume_struct_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	t_foo_var := cd.all_variables[0];
	n_foo_var := cd.all_variables[1];
	n_main_var := cd.all_variables[2];


	scope_count := AssertEquals(3, cd.all_scope_data.count);
	if !scope_count return;
	AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
	AssertEquals(0, cd.all_scope_data[0].start_instr_index);
	AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

	foo_scope : ScopeData = cd.all_scope_data[1];
	AssertEquals(foo_scope.function_id, cd.all_function_declarations[0].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);

	main_scope : ScopeData = cd.all_scope_data[2];
	AssertEquals(main_scope.function_id, cd.all_function_declarations[1].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);

	// t_stack_op := RamMem(.sbp, cd.tano_struct_info.runtime_size);
	// t_stack_ofs := GetTanoOpOffsets(t_stack_op);
	// t_foo_ofs := GetTanoOpOffsets(t_foo_var.op);

	instr_index : int = 0;
	AssertEquals(instr_index, foo_scope.start_instr_index);
	//foo :: (t : tano, n : neume) {
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.tmov, t_foo_var.op, n_foo_var.op, ImmEnum(TMovRamType.NEUME)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index-1, foo_scope.end_instr_index);

	//main function
	AssertEquals(instr_index, cd.main_function_instr_index);

	TestNextManyInstr(*instr_index, cd, .[
		//n : neume;
		MakeMI(.mset, n_main_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		MakeMI(.mov, n_main_var.op, FImm(1.), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(24,n_main_var.op), FImm(1.5), Imm(cd.float_type_info.runtime_size)),
	]);

	t0_op := RamMem(.sbp,n_main_var.t_info.runtime_size);
	// t_main_ofs := GetTanoOpOffsets(t0_op);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(t0_op, Imm(0), Imm(0), cd));

	stack_p : int = cd.neume_struct_info.runtime_size + cd.tano_struct_info.runtime_size;
	next_stack_p : int = PRE_PROC_STACK_SIZE + stack_p;
	tano_arg_op := RamMem(.sbp,next_stack_p);
	neume_arg_op := AddOperandOffset(cd.tano_struct_info.runtime_size, tano_arg_op);
	//foo(tano(0,0), n)
	//TODO Can likely make a function for this to generate instructions for a function call
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,stack_p)),
		//Push on tano argument
		MakeMI(.mov, tano_arg_op, t0_op, Imm(cd.tano_struct_info.runtime_size)),
		//Push on neume argument
		MakeMI(.mov, neume_arg_op, n_main_var.op, Imm(cd.neume_struct_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+6)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(0)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_TanoArrayFunc :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
foo :: (t : tano, a : [2] int) {
  t ~= a;
}
main :: () {
  arr := int.[0,6];
  foo(tano(0,0), arr);
}
DONE,,unit_test_alloc);

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	if !count_equal return;
	AssertEquals("foo", cd.all_function_declarations[0].name);
	AssertEquals("main", cd.all_function_declarations[1].name);
	count_equal = AssertEquals(2, cd.all_function_arguments.count);
	if count_equal {
		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[0].function_id);
		AssertEquals("t", cd.all_function_arguments[0].name);
		AssertEquals(TypeInfoTag.TANO, cd.all_function_arguments[0].t_info.type_enum);
		AssertEquals(0, cd.all_function_arguments[0].var_bytes_from_sbp);

		AssertEquals(cd.all_function_declarations[0].id, cd.all_function_arguments[1].function_id);
		AssertEquals("a", cd.all_function_arguments[1].name);
		AssertEquals(TypeInfoTag.ARRAY, cd.all_function_arguments[1].t_info.type_enum);
		AssertEquals(cd.tano_struct_info.runtime_size, cd.all_function_arguments[1].var_bytes_from_sbp);
	}
	AssertEquals(0, cd.all_function_return_variables.count);

	arr_type, found_arr_type := GetArrayType(cd, *cd.int_type_info, ArrayInfoType.FIXED, 2);
	AssertEquals(true, found_arr_type);
	if !found_arr_type return;

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		//t in foo
		VarDecl("t", *cd.tano_struct_info, RamMem(.sbp,0)),
		//a in foo
		VarDecl("a", arr_type, RamMem(.sbp,cd.tano_struct_info.runtime_size)),
		//arr in main
		VarDecl("arr", arr_type, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	t_var := cd.all_variables[0];
	a_var := cd.all_variables[1];
	arr_var := cd.all_variables[2];


	scope_count := AssertEquals(3, cd.all_scope_data.count);
	if !scope_count return;
	AssertEquals(ScopeDataType.GLOBAL_SCOPE, cd.all_scope_data[0].scope_type);
	AssertEquals(0, cd.all_scope_data[0].start_instr_index);
	AssertEquals(cd.all_music_instructions.count-1, cd.all_scope_data[0].end_instr_index);

	foo_scope : ScopeData = cd.all_scope_data[1];
	AssertEquals(foo_scope.function_id, cd.all_function_declarations[0].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, foo_scope.scope_type);

	main_scope : ScopeData = cd.all_scope_data[2];
	AssertEquals(main_scope.function_id, cd.all_function_declarations[1].id);
	AssertEquals(ScopeDataType.FUNCTION_SCOPE, main_scope.scope_type);

	// t_stack_op := RamMem(.sbp, cd.tano_struct_info.runtime_size);
	// t_stack_ofs := GetTanoOpOffsets(t_stack_op);
	// t_foo_ofs := GetTanoOpOffsets(t_foo_var.op);

	instr_index : int = 0;
	AssertEquals(instr_index, foo_scope.start_instr_index);
	a_0, a_1 := GetMemoryAddressAsOperands(a_var.op);
	//foo :: (t : tano, a : [2] int) {
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, RegMem(.ax), a_0, a_1),
		MakeMI(.tmov, t_var.op, RamArray(2,RegDef.ax)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index-1, foo_scope.end_instr_index);

	//main function
	AssertEquals(instr_index, cd.main_function_instr_index);

	TestNextManyInstr(*instr_index, cd, .[
		// arr := int.[0,6];
		MakeMI(.mov, arr_var.op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(cd.int_type_info.runtime_size,arr_var.op), Imm(6), Imm(cd.int_type_info.runtime_size)),
	]);

	t0_op := RamMem(.sbp,arr_var.t_info.runtime_size);
	// t_main_ofs := GetTanoOpOffsets(t0_op);
	TestNextManyInstr(*instr_index, cd, 
		TanoIntIntTestInstr(t0_op, Imm(0), Imm(0), cd));

	stack_p : int = arr_type.runtime_size + cd.tano_struct_info.runtime_size;
	next_stack_p : int = PRE_PROC_STACK_SIZE + stack_p;
	tano_arg_op := RamMem(.sbp,next_stack_p);
	a_arg_op := AddOperandOffset(cd.tano_struct_info.runtime_size, tano_arg_op);
	//foo(tano(0,0), n)
	//TODO Can likely make a function for this to generate instructions for a function call
	TestNextManyInstr(*instr_index, cd, .[
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,stack_p)),
		//Push on tano argument
		MakeMI(.mov, tano_arg_op, t0_op, Imm(cd.tano_struct_info.runtime_size)),
		//Push on [2] int argument
		MakeMI(.mov, a_arg_op, arr_var.op, Imm(arr_type.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+6)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(0)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

ParseTestData :: struct {
	ordered_nodes : [..] *BinaryNode;
	expected_tokens : [] LCodeToken;
	expected_nodes : [] BinaryNode;
	cl : CodeLexer;
	cd : *CompilationData;

}
MakeParseTestData :: inline () -> ParseTestData {
	ptd : ParseTestData;
	ptd.ordered_nodes.allocator = unit_test_alloc;
	ptd.cd = MakeCompilationData(,,unit_test_alloc);
	return ptd;
}

Test_Void :: () {
	//TODO Should we separate parsing tests from compiler tests? It seems natural to put them in the same place.
	ptd := MakeParseTestData();
	/* v : void;
		 : 
	   / \
	  v  void
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "v : void;");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSIn(node, *ptd.ordered_nodes, GetOrderedNodes);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "v")),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_VOID, "void"))
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

	/* vp : *void = *v;
		   =
		  / \
		 :   *
	   / \   \
	  vp  *   v
	       \
	      void
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "vp : *void = *v;");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSIn(node, *ptd.ordered_nodes, GetOrderedNodes);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "vp")),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(#char "*"), .UNARY_OP),
		BNode(LCToken(.DATA_TYPE_VOID, "void")),
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char "*"), .UNARY_OP),
		BNode(LCToken(.IDENT, "v")),
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);



	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	/*NOTE : Creating a void variable is undefined behavior.
	So creating a pointer to a void variable is undefined.
	This is just here for testing purposes to show myself it's behavior.
	*/
	v : void;
	vp : *void = *v;
}
DONE,,unit_test_alloc);

	v_index : int = 0;
	vars_equal : bool = TestNextManyVarDecl(*v_index, cd.all_variables, .[
		VarDecl("v", *cd.void_type_info, RamMem(.sbp,0)),
		VarDecl("vp", cd.void_pointer_type_info, RamMem(.sbp,0))
	]);
	if !vars_equal return;
	v_var := cd.all_variables[0];
	vp_var := cd.all_variables[1];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//v : void
		MakeMI(.mset, v_var.op, Imm(0), Imm(v_var.t_info.runtime_size)),
	]);

	//NOTE : Because void is size 0, we store *v at [sbp,0] and vp at [sbp,8]
	TestNextManyInstr(*instr_index, cd, .[
		//*v
		MakeMI(.add, RamMem(.sbp,0), RegMem(.sbp), Imm(0)),
		//Optimized out since vp_var == [sbp+0]
		//vp : *void = *v
		// MakeMI(.mov, vp_var.op, RamMem(.sbp,0), Imm(vp_var.t_info.runtime_size))
	]);

} @UnitTest

//TODO Then do alloc with *void could do asm first and then cast(*int) implement cast and size_of
//and then likely implement NewArray and New at compile time in compiler for convenience (implement cast first)
//then do string specific asm in the heap for convenience.
//TODO null pointer initial set to RamMem(-1) maybe
Test_AsmAlloc :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	size : int = 8;
	v : *void;
	#asm {
		alloc size, v;
	}

	i : *int;
	#asm {
		alloc 16, i;
	}
}
DONE,,unit_test_alloc);

	vars_equal : bool = TestManyVarDeclSameStack(cd.all_variables, .[
		VarDecl("size", *cd.int_type_info),
		VarDecl("v", cd.void_pointer_type_info),
		VarDecl("i", cd.all_type_info_pointer[1])
	]);
	if !vars_equal return;
	size_var := cd.all_variables[0];
	v_var := cd.all_variables[1];
	i_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//size : int = 8;
		MakeMI(.mov, size_var.op, Imm(8), Imm(size_var.t_info.runtime_size)),
		//v : *void;
		MakeMI(.mov, v_var.op, NULL_POINTER_OP, Imm(v_var.t_info.runtime_size)),
		//alloc size, v
		MakeMI(.alloc, size_var.op, v_var.op),
	]);

	TestNextManyInstr(*instr_index, cd, .[
		//i : *int;
		MakeMI(.mov, i_var.op, NULL_POINTER_OP, Imm(i_var.t_info.runtime_size)),
		//alloc 16, i
		MakeMI(.alloc, Imm(16), i_var.op),

		MakeMI(.exit),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_AsmErrors :: () {
	cs : CompileSettings;
	cd : *CompilationData;

	//Invalid 4 operands > 3 max
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () { #asm {
add 0, 1, 2, 3;
}}
DONE,,unit_test_alloc);
	AssertEquals(1, cd.comp_errors.all_compiler_errors.count);

	//Invalid ream memory
	//TODO We could reset before compilations if it's too much unit_test_alloc memory.
	reset(*unit_test_alloc_pool, true);
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () { #asm {
mov [0+1+2], 3;
}}
DONE,,unit_test_alloc);
	AssertEquals(1, cd.comp_errors.all_compiler_errors.count);

	//Invalid music memory
	reset(*unit_test_alloc_pool, true);
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () { #asm {
mov <0,1,2>, 3;
}}
DONE,,unit_test_alloc);
	AssertEquals(1, cd.comp_errors.all_compiler_errors.count);

	//Invalid instruction mov operand_0 cannot be integer
	reset(*unit_test_alloc_pool, true);
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () { #asm {
mov 0, 1;
}}
DONE,,unit_test_alloc);
	AssertEquals(1, cd.comp_errors.all_compiler_errors.count);


} @UnitTest

Test_UntestedParse :: () {
	cd := MakeCompilationData(,,unit_test_alloc);
	bin : *BinaryNode;

	//TODO Can we leave this test to check different
	//expression evaluation?
	// LexCodeTokens(*cd.lexer, "2 * (3+4)");
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "2 * (4+x[0])");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);


	ResetCodeLexer(*cd.lexer);
	// LexCodeTokens(*cd.lexer, "x[(y[0]+2)*3]");
	LexCodeTokens(*cd.lexer, "x[3*(y[0][1]+2)]");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);

	//TODO Write tests for this crazy case.
	ResetCodeLexer(*cd.lexer);
	// LexCodeTokens(*cd.lexer, "x[(y[0]+2)*3]");
	LexCodeTokens(*cd.lexer, "a[0] = 2 * (3 + x[3*(y[0][1]+2)]);");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);


	//Test Declaration
	//TODO Do we want ':=' to be a new token or do we want it to
	//be parsed differently on the tree.
	// LexCodeTokens(*cd.lexer, "x := 2");
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "x : int = 2;");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);


	//TODO Error cases
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "x = 2 + ;");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);


	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "(x+1)+(y*2)");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);


	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, 
#string DONE
if 3 > x[0] {
}
DONE,,unit_test_alloc);
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);



	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, 
#string DONE
if x > 2 {
	x = 1;
	if y < 2 {
		
	}
}
DONE,,unit_test_alloc);
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);

	/* y : *int = *x; 
		     {
		 /      \
	   if        ;
	    \      /  \
	    <     =    }
	   / \   / \    \
	  x   2  x  1    {
	   	           /  \
	   	         else  }
	   	           \
	   	           if
	   	            \
	   	            <
	   	           / \
	   	          x   3
	*/      
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, 
#string DONE
if x > 2 {
	x = 1;
} else if x > 3 {
}
DONE,,unit_test_alloc);
/*TODO Cases to test
if x > 2 {
}
if x > 2 {
	x = 2;
}
if x > 2 {
	x = 2;
} else if x > 3 {
	x = 3;
}
*/
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);


	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, 
#string DONE
if x == 1 x > 2;
DONE,,unit_test_alloc);
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);


	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, 
#string DONE
while x < 2 {	
}
DONE,,unit_test_alloc);
// for x,y : array {
// }
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);



	//Test Assignment
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "x = 2");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);



	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "if 3 > 2");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);



	ResetCodeLexer(*cd.lexer);
	// LexCodeTokens(*cd.lexer, "munit[0][1] = int.[0,1];");
	LexCodeTokens(*cd.lexer, "munit[0][1] = .[0,1];");
	// LexCodeTokens(*cd.lexer, "x = 2;");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);



	ResetCodeLexer(*cd.lexer);
	// LexCodeTokens(*cd.lexer, "DATA_MUNIT0][1] = int.[0,1];");
	LexCodeTokens(*cd.lexer, "x = int.[int.[0,1],int.[2,3]];");
	// LexCodeTokens(*cd.lexer, "x = 2;");
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);


/*TODO FROM HERE Start on function and with inputs and
  return values and then function call instruction output.
  What about return keyword?
  Then should we do a pre-pass for function declarations?
  I think we need it to do function calls in the right order
  so we can have functions anywhere.
  Then consider linearizing the input.
  Then start writing some code!
  Can test with tonality permutations to see what else we need to add.
  Then we can do float and bool types and then enums
  and then possibly add structs if needed.
  ALSO IMPLEMENT ERROR RETURN from tree traversal so 
  we can have a generalized one and build it up slowly
  since error reporting is important and how the user
  interacts with the language.
*/


//TODO Make separate tests for each of these cases once we have
//decided if we keep the ast or linearize each statement.
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
// foo :: () {
// foo :: () -> int {
// foo :: (x : int) {
// foo :: (x : int) -> int {
foo :: (x : int, y : int) -> int {
	// y : int = x + 1;
	// return y;
}
DONE,,unit_test_alloc);
// for x,y : array {
// }
	bin  = ParseExpression(cd, S64_MIN);
	// cd   = DFSPost(bin);
	print("");
}

/*TODO Can we generalize this to test for valid value for specific sub expressions?
We would need like a recursive test... hmmm... interesting.
Could write code that parses an ascii tree and generates a tree that can be validated
on directly from the ascii like we have below. This is interesting because then we could
even use that as a way of making music by converting the ascii tree directly to some instructions.
*/
Test_ParseStatement :: () {
	node : *BinaryNode;
	cd := MakeCompilationData(,,unit_test_alloc);
	LexCodeTokens(*cd.lexer, "if x == 2 x = 1;");

	/*
		if
		 \
		 ==
		 / \
	   x   2
	*/
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(CodeTokenType.KEYWORD_IF, node.value.token_type);
	AssertEquals(CodeTokenType.IS_EQUAL, node.right.value.token_type);
	AssertEquals(CodeTokenType.IDENT, node.right.left.value.token_type);
	AssertEquals("x", node.right.left.value.token_string);
	AssertEquals(CodeTokenType.INTEGER, node.right.right.value.token_type);
	AssertEquals(2, node.right.right.value.int_value);

	/*
		  =
		 / \
	   x   1
	*/
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "=", node.value.token_type);
	AssertEquals(CodeTokenType.IDENT, node.left.value.token_type);
	AssertEquals("x", node.left.value.token_string);
	AssertEquals(CodeTokenType.INTEGER, node.right.value.token_type);
	AssertEquals(1, node.right.value.int_value);

	AssertEquals(cast(CodeTokenType) #char ";", cd.lexer.lexer_tokens[cd.lexer.next_index].token_type);
} @UnitTest

/*TODO We could have function for reused groups of nodes tested like a variable declaration or function declaration
which then gets tested for a specific thing like 'x : int' which is used in variable and function declaration
*/
/*Specifically to test parsing of function related code. This code does not have to be correct
since we are just checking the tree structure.

TODO Can make some tree parsing code in ascii and then generate trees and then post order
and then compare them directly. This would simplify testing trees a lot i think.
Would have to genericize the BinaryTree data though so we could have a different value
for this tree to store the connections with / and \
*/
Test_ParseFunc :: () {
	//I decided to recreate each time so that each test is fresh.
	//We have multiple tests in this file but they should each be treated
	//like separate test cases so each run should be fresh. I increased the 
	//allocator to accomodate this but can also use the normal pool instead
	//of Flat_Pool eventually so it can grow in size if needed since we free anyways.
	//OR we can also reset the pool instead of freeing if we want to run a bunch of tests.
	cd : *CompilationData = MakeCompilationData(,,unit_test_alloc);
	node : *BinaryNode;

	ordered_nodes : [..] *BinaryNode;
	ordered_nodes.allocator = unit_test_alloc;
	expected_tokens : [] LCodeToken;
	expected_nodes : [] BinaryNode;

	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "main :: () {}");

	//TODO Could make a function that specifically tests parsing a function declaration
	node = ParseExpression(cd, S64_MIN);

	/*TODO Could make a test that parses the tree and generates tokens directly from there
		::
	  /  \
	main  )
	*/
	//TODO Do we want to use function here or just struct literal? Struct literal would require name change.
	//Also may not use if we make the ascii tree parsing code then can compare directly.
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "main")),
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(#char ")"))];
	TestNodes(expected_nodes, ordered_nodes);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);




	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer,
#string DONE
foo :: () {}
main :: () {}
DONE,,unit_test_alloc);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(CodeTokenType.DOUBLE_COLON, node.value.token_type);
	AssertNotEquals(null, node.left);
	AssertEquals(CodeTokenType.IDENT, NoNull(node.left).value.token_type);
	AssertEquals("foo", NoNull(node.left).value.token_string);
	AssertNotEquals(null, node.right);
	AssertEquals(cast(CodeTokenType) #char ")", NoNull(node.right).value.token_type);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(CodeTokenType.DOUBLE_COLON, node.value.token_type);
	AssertNotEquals(null, node.left);
	AssertEquals(CodeTokenType.IDENT, NoNull(node.left).value.token_type);
	AssertEquals("main", NoNull(node.left).value.token_string);
	AssertNotEquals(null, node.right);
	AssertEquals(cast(CodeTokenType) #char ")", NoNull(node.right).value.token_type);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);


	

	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "foo :: (x : int)");

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(CodeTokenType.DOUBLE_COLON, node.value.token_type);
	AssertNotEquals(null, node.left);
	AssertEquals(CodeTokenType.IDENT, NoNull(node.left).value.token_type);
	AssertEquals("foo", NoNull(node.left).value.token_string);
	
	TestVarDecl(node.right, "x", CodeTokenType.DATA_TYPE_INT);


	//TODO Could make an ascii tree parser to generate directly from the tree
	/*
			  ::
		  /      \
		foo        ,
		     /          \
			 ,            = 
	     /   \         / \
	    :      =      :   6.0
	   / \    / \    / \
	  z int  :   5  y  float
	        / \
	       x  int
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "foo :: (z : int, x : int = 5, y : float = 6.0)");
	node = ParseExpression(cd, S64_MIN);

	//TODO The tests getting this long makes me want to parse the ascii... but still then we'd have to test that.
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "foo")), 
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "z")), 
		BNode(LCToken(#char ":"), .BINARY_OP), 
		BNode(LCToken(.DATA_TYPE_INT, "int")), 
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), 
		BNode(LCToken(#char ":"), .BINARY_OP), 
		BNode(LCToken(.DATA_TYPE_INT, "int")), 
		BNode(LCToken(#char "="), .BINARY_OP), 
		BNode(LCToken(.INTEGER, 5)),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), 
		BNode(LCToken(#char ":"), .BINARY_OP), 
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")),
		BNode(LCToken(#char "="), .BINARY_OP), 
		BNode(LCToken(.FLOAT, 6.0))];
	TestNodes(expected_nodes, ordered_nodes);


	/*
			  (
		  /    \
		foo      ,
		      /     \
	 		  ,       =
	      /   \    / \
	   1.0     =  y  6.0
	          / \
	         x   5
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "foo(1.0, x = 5, y = 6.0)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "foo")), 
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.FLOAT, 1.0)),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), 
		BNode(LCToken(#char "="), .BINARY_OP), 
		BNode(LCToken(.INTEGER, 5)),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), 
		BNode(LCToken(#char "="), .BINARY_OP), 
		BNode(LCToken(.FLOAT, 6.0))];
	TestNodes(expected_nodes, ordered_nodes);


	/*  
	      ::
       /    \
	  foo	    ->
	   	  /	 \
	   	 :	    int
	   	/ \
	     x  int
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "foo :: (x : int) -> int");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);


	/*  
	      ::
       /    \
	  foo	     ->
	   	  /	   \
          ,        ,
        /   \     / \
		 :	     :  int int
		/ \    / \
	  x  int y  int
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "foo :: (x : int, y : int) -> (int, int)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);


	/*
   	    :=
   	  /    \ 
   	 ,      (
   	/ \    / \ 
     x   y foo  ,
               / \
              x   y
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "x,y := foo(x,y);");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "x")),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")),
		BNode(LCToken(.COLON_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), 
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "y"))
	];
	TestNodes(expected_nodes, ordered_nodes);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);
	
	/*
			  (
			/	  \
	size_of     )
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "size_of()");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_SIZE_OF, "size_of")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
			  (
			/	  \
	size_of    int
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "size_of(int)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_SIZE_OF, "size_of")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);


	/*
			  (
			/	  \
	size_of     [
				 /   \
		    float   ]
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "size_of([] float)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_SIZE_OF, "size_of")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);


	/*
			  (
			/	  \
	size_of     *
				     \
		          float
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "size_of(*float)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_SIZE_OF, "size_of")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);


	/*
			      =
	  	   /           \
	  	  :     	       (
	   /	 \         /	  \
	  i     *      New   AStruct
	         \
	       AStruct
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "i : *AStruct = New(AStruct);");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.IDENT, "AStruct")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEW, "New")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "AStruct")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");



	/*
			     =
	  	   /        \
	  	  :     	    (
	   /	 \      /	 \
	  af     *   New     [
	         \         /   \
	          [      float  ]
	         /  \
	     float   ]
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "af : *[] float = New([] float);");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "af")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEW, "New")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");

	/*	   
			-
	   /     \
	  1       (
	        /	 \
	      foo     x
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "foo(x) - 1");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .BINARY_OP),
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
	      -
	    /   \
	   1     (
		     /  \
	 	   foo   +
	 	        / \
	 	       x   1
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "1 - foo(x+1)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);



} @UnitTest

Test_ParseReturn :: () {
	ptd := MakeParseTestData();

	/*TEST empty return statement
		return
	*/	
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "return;");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_RETURN, "return"), .UNARY_OP), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


	/*
		return
		    \
		     +
		    / \
		   x   1
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "return x+1;");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_RETURN, "return"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


	/*
		return
		    \
		     ,
		    / \
		   x   y
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "return x,y;");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_RETURN, "return"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");

	/*
		return
		     \
		      (
		    /   \
		  foo    ,
		       /   \
		      +     y
		    /   \
		   x     1
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "return foo(x+1,y);");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_RETURN, "return"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


} @UnitTest

//TODO FROM HERE could add a few more parsing (single op or function pointer) but it should be fine
//then add a test for declaration an operator overload and then implement using it and add a test
//and then do integration tests for 1 or operator overloads before doing #load
Test_ParseOperator :: () {
	ptd := MakeParseTestData();

	/*
		     ::
		  /     \
    operator   )
		  \       
		   +      
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "operator + :: () {}");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.KEYWORD_OPERATOR, "operator"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "+")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/*
		     ::
		  /      \
    operator    ->
		 \      /    \   
		 +=    ,      neume
		     /   \
			 :      :
		  /  \    /  \
		 i   int  n   neume
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "operator += :: (i : int, n : neume) -> neume {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.KEYWORD_OPERATOR, "operator"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.PLUS_EQUALS)), NULL_NODE, NULL_NODE,

		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "n")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/*
		     ::
		  /      \
    operator    ->
		 \      /    \   
		  -    :      neume
		     /   \
			 f      ->
		          /  \
		         int int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "operator - :: (f : (int) -> int) -> neume {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.KEYWORD_OPERATOR, "operator"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "-")), NULL_NODE, NULL_NODE,

		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "f")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	//TEST Invalid operand ++ where we don't find a DOUBLE_COLON after single + operator
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "operator ++ :: (i : int, n : neume) -> neume {}");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(true, ptd.cd.comp_errors.all_compiler_errors.count > 0);
	array_reset_keeping_memory(*ptd.cd.comp_errors.all_compiler_errors);

	//TEST Invalid operand single operator :
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "operator : :: () {}");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(true, ptd.cd.comp_errors.all_compiler_errors.count > 0);
	array_reset_keeping_memory(*ptd.cd.comp_errors.all_compiler_errors);


	//TEST Invalid operand since we are using an identifier identifier
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "operator TEST :: (i : int, n : neume) -> neume {}");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(true, ptd.cd.comp_errors.all_compiler_errors.count > 0);
	array_reset_keeping_memory(*ptd.cd.comp_errors.all_compiler_errors);

} @UnitTest
//TODO FROM HERE could make a more complicated operator overload unit test and then
//continue with an integration tests and maybe look over operator overload code again with some 
//error cases before moving on to #load
//TODO Could add a test with operator overloads and a struct
//probably best to have both tests for completeness
Test_CompOperator :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
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
DONE,,unit_test_alloc);

	//NOTE : First type is main type () -> ()
	count_equal = AssertEquals(3, cd.all_type_info_procedure.count);
	op_type : *TypeInfoProcedure;
	unary_op_type : *TypeInfoProcedure;
	if count_equal {
		op_type = cd.all_type_info_procedure[1];
		AssertEquals(2, op_type.argument_types.count);
		AssertEquals(*cd.int_type_info, op_type.argument_types[0]);
		AssertEquals(*cd.neume_struct_info.info, op_type.argument_types[1]);
		AssertEquals(1, op_type.return_types.count);
		AssertEquals(*cd.int_type_info, op_type.return_types[0]);

		unary_op_type = cd.all_type_info_procedure[2];
		AssertEquals(1, unary_op_type.argument_types.count);
		AssertEquals(*cd.neume_struct_info.info, unary_op_type.argument_types[0]);
		AssertEquals(1, unary_op_type.return_types.count);
		AssertEquals(*cd.int_type_info, unary_op_type.return_types[0]);
	}

	count_equal = AssertEquals(3, cd.all_function_declarations.count);
	op_decl : FunctionDeclaration;
	unary_op_decl : FunctionDeclaration;
	if count_equal {
		op_decl = cd.all_function_declarations[1];
		AssertEquals(op_type, op_decl.t_info_proc);

		unary_op_decl = cd.all_function_declarations[2];
		AssertEquals(unary_op_type, unary_op_decl.t_info_proc);
	}

	neume_int_size := cd.neume_struct_info.runtime_size+cd.int_type_info.runtime_size;

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("n", *cd.neume_struct_info, RamMem(.sbp,0)),
		VarDecl("i", *cd.int_type_info, RamMem(.sbp,cd.neume_struct_info.runtime_size)),
		VarDecl("ni", *cd.int_type_info, RamMem(.sbp,neume_int_size)),
		VarDecl("ti", *cd.int_type_info, RamMem(.sbp,neume_int_size + cd.int_type_info.runtime_size)),
		//operator + args
		VarDecl("i", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("n", *cd.neume_struct_info, RamMem(.sbp,8)),
		//operator - args
		VarDecl("n", *cd.neume_struct_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	n_var := cd.all_variables[0];
	i_var := cd.all_variables[1];
	ni_var := cd.all_variables[2];
	ti_var := cd.all_variables[3];
	i_foo_var := cd.all_variables[4];
	n_foo_var := cd.all_variables[5];
	n_unary_var := cd.all_variables[6];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//n : neume;
		MakeMI(.mset, n_var.op, Imm(0), Imm(cd.neume_struct_info.runtime_size)),
		//i : int = 3;
		MakeMI(.mov, i_var.op, Imm(3), Imm(cd.int_type_info.runtime_size)),
	]);

	next_stack_p : int = neume_int_size + PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == op_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	TestNextManyInstr(*instr_index, cd, .[
		//ni := i + n;
		MakeMI(.push_all_stack_reg, AddOperandOffset(8, ni_var.op)),
		MakeMI(.mov, RamMem(.sbp,next_stack_p), i_var.op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8,RamMem(.sbp,next_stack_p)), n_var.op, Imm(cd.neume_struct_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+6)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(op_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),
	]);

	unary_stack_p : int = neume_int_size + ni_var.t_info.runtime_size + PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == unary_op_decl.id {
		unary_stack_p += it.t_info.runtime_size;
	}
	TestNextManyInstr(*instr_index, cd, .[
		//ti := -n;
		MakeMI(.push_all_stack_reg, AddOperandOffset(8, ti_var.op)),
		MakeMI(.mov, RamMem(.sbp,unary_stack_p), n_var.op, Imm(cd.neume_struct_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(unary_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(unary_op_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		MakeMI(.exit),
	]);


	//operator + :: (i : int, n : neume) -> neume
	return_op := RamMem(.sbp,neume_int_size);
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, return_op, i_foo_var.op, Imm(1)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.int_type_info.runtime_size),
			return_op,
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	//operator - :: (n : neume) -> int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.int_type_info.runtime_size),
			Imm(5),
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);


//TEST Empty operator overload should be an error
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {}
operator + :: () {}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//TEST Invalid operator overload should be an error
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {}
operator ++ :: (i : int, n : neume) -> neume {}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


//TEST ident operator overload should be an error
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {}
operator TEST :: () {}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


} @UnitTest

Test_ParseFuncPointer :: () {
	ptd := MakeParseTestData();

	/*
			->
		 /   \
		,    int
	  / \
	int int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "(int,int) -> int");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*
			->
		 /   \
		,     )
	  / \
	int int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "(int,int) -> ()");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*
			->
		 /     \
		,       ->
	  / \     /  \
	int int  int int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "(int,int) -> ((int) -> int)");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,

		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*
		 :
	  /   \
	 x		->
		 /   \
		)     )
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : () -> ();");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


	/*
		 :
	  /   \
	 x		->
		 /   \
		)     int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : () -> int;");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


	/*
		 :
	  /   \
	 x		 )
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : ();");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");

	/*
		 :
	  /   \
	 x		 ,
	     /  \
	    int  int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : (int, int);");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


	/*  
	      ::
       /    \
    foo       :
    	      /  \
    	   sort    ->
    	         /   \
    	        )     )
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (sort : () -> ()) {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		// BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		//sort : () -> ()
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		// BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		//return int
		// BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");

	/*  
	      ::
       /    \
    foo      -> 
            /   \
   	     :     int
    	   /  \
    	sort    )
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (sort : ()) -> int {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		//sort : () -> ()
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE,
		// BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		// BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		// BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		//return int
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");

	/*  
	       ::
       /     \
    foo        -> 
             /    \
             ,    int
          /    \
    		:	     :
    	 /  \     /  \
    	i  int  sort  ->
    	             /   \
    	            )     int
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (i : int, sort : () -> int) -> int {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		//i : int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		//sort : () -> int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		//return int
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");

	/*  
	      ::
       /    \
    foo      -> 
            /   \
   	     :     int
    	   /  \
    	sort    ->
    	      /   \
    	     )     )
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (sort : () -> ()) -> int {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		//sort : () -> ()
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE,
		//return int
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/*  
	      ::
       /    \
	  foo	    ->
	   	  /	 \
	       :     int
	      /  \
	   sort    ->
	         /   \
	        ,    int
	      /   \
	    int   int
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (sort : (int,int) -> int) -> int {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		//sort : (int,int) -> int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		//return int
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/*  
	      ::
       /    \
	  foo	    ->
	   	  /	 \
	       :     int
	      /  \
	    sort     ->
	         /        \
	        ,          [
	      /   \      /   \
	     *      [   int   ]
	      \    /  \
	     void int  +
	              / \
	             3   1
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (sort : (*void, [3+1] int) -> [] int) -> int {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		//sort : (*void, [3+1] int) -> [] int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE, 
		BNode(LCToken(.DATA_TYPE_VOID, "void")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 3)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		//return int
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/* TEST FUNCTION POINTER INSIDE FUNCTION POINTER
	      ::
       /    \
	  foo	    ->
	   	  /	 \
	       :     int
	      /  \
	    sort     ->
	         /        \
	        ,          [
	      /   \      /   \
	    int     ->   int   2
	           /   \
	           ,    *
	        /    \    \  
	        *      [   int
	         \    /  \
	         int int  ]
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (sort : (int, (*int,[] int) -> *int) -> [2] int) -> int {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		//sort : (int, (**int,[] int) -> *int)) -> [] int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		//return int
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");



	/*  
	      ::
       /    \
	  foo	     ->
	   	  /	   \
          ,        int
        /    \     
		 :	      :
		/ \     / \
	  a   [  sort  ->
	     / \      /  \
	    int ]     ,  int
	             / \
	           int  int
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (a : [] int, sort : (int,int) -> int) -> int {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		//a : [] int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		//sort : (int,int) -> int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		//return int
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/*  
	       ::
       /     \
	  foo	     ->
	   	   /	   \
           ,       int
        /      \     
		 :	        :
		/ \     /    \
	  a   [  sort    ->
	     / \      /      \
	    int ]    ,         , 
	            / \      /   \
	          int  int  int int
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (a : [] int, sort : (int,int) -> (int,int)) -> (int,int) {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		//a : [] int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		//sort : (int,int) -> (int,int)
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		//return (int,int)
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/* TEST FUNCTION POINTER AS RETURN VALUE AND ARGS
	      ::
       /    \
	  foo	      ->
	   	  /	     \
	       :          ->
	      /  \       /  \
	   sort    ->   int  int
	         /   \
	        ,    int
	      /   \
	    int   int
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (sort : (int,int) -> int) -> ((int) -> int) {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		//sort : (int,int) -> int
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "sort")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		//return (int) -> int
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/* TEST FUNCTION POINTER AS RETURN VALUE
	       ::
       /     \
	  foo	     ->
	   	  /	   \
	       :        ->
	      / \      /   \
	     x  int   ,     *
	            /    \    \
	         float    [    int
	                 /  \
	              int    ]
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: (x : int) -> ((float,[] int) -> *int) {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),

		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		//return function pointer
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");

	/* TEST FUNCTION POINTER AS RETURN VALUE AND ARGS
	      ::
       /    \
	  foo	      ->
	   	  /	     \
	       )          ->
	      	        /  \
	   			   int  int
	*/
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "foo :: () -> ((int) -> int) {}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ")")), NULL_NODE, NULL_NODE, 
		//return (int) -> int
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "{");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char "}");


	/*
		 :
     /   \
	 x	   ->
		 /   \
		,    int
	  / \
	int int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : (int,int) -> int;");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");

	/*
			 =
        /   \
		 :    Foo
     /   \
	 x	   ->
		 /   \
	  int    int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : (int) -> (int) = Foo;");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "Foo")), NULL_NODE, NULL_NODE, 
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


	/*
	      =
       /   \
		 :    Foo
     /   \
	 x	     ->
		 /        \
		 ,           ,
	  /   \       /    \
	 *       [   neume   [
	  \    /   \        /  \
	   *  neume ]     int   2
	    \
	    int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "x : (**int,[] neume) -> (neume, [2] int) = Foo;");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "Foo")), NULL_NODE, NULL_NODE, 
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


} @UnitTest

Test_CompFuncPointer :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	fp : (int) -> (int);
	fp = Foo;

	fp2 : (int) -> (int) = Foo;
	fp2 = fp;

	fp3 := Foo;

	fp4 := fp3;
}
Foo :: (x : int) -> int {
	return x + 1;
}
DONE,,unit_test_alloc);

	//NOTE : First type is main type () -> ()
	count_equal = AssertEquals(2, cd.all_type_info_procedure.count);
	fp_type : *TypeInfoProcedure;
	if count_equal {
		fp_type = cd.all_type_info_procedure[1];
		AssertEquals(1, fp_type.argument_types.count);
		AssertEquals(*cd.int_type_info, fp_type.argument_types[0]);
		AssertEquals(1, fp_type.return_types.count);
		AssertEquals(*cd.int_type_info, fp_type.return_types[0]);
	}

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	foo_decl : FunctionDeclaration;
	if count_equal {
		foo_decl = cd.all_function_declarations[1];
		AssertEquals(fp_type, foo_decl.t_info_proc);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("fp", *fp_type.info, RamMem(.sbp,0)),
		VarDecl("fp2", *fp_type.info, RamMem(.sbp,8)),
		VarDecl("fp3", *fp_type.info, RamMem(.sbp,16)),
		VarDecl("fp4", *fp_type.info, RamMem(.sbp,24)),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	fp_var := cd.all_variables[0];
	fp2_var := cd.all_variables[1];
	fp3_var := cd.all_variables[2];
	fp4_var := cd.all_variables[3];
	x_foo_var := cd.all_variables[4];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		// fp : (int) -> (int);
		MakeMI(.mset, fp_var.op, Imm(0), Imm(fp_var.t_info.runtime_size)),
		// fp = foo;
		MakeMI(.mov, fp_var.op, Imm(foo_decl.start_instr_index), Imm(fp_var.t_info.runtime_size)),

		// fp2 : (int) -> (int) = foo;
		MakeMI(.mov, fp2_var.op, Imm(foo_decl.start_instr_index), Imm(fp2_var.t_info.runtime_size)),
		// fp2 = fp;
		MakeMI(.mov, fp2_var.op, fp_var.op, Imm(fp2_var.t_info.runtime_size)),

		// fp3 := foo;
		MakeMI(.mov, fp3_var.op, Imm(foo_decl.start_instr_index), Imm(fp3_var.t_info.runtime_size)),

		// fp4 := fp3;
		MakeMI(.mov, fp4_var.op, fp3_var.op, Imm(fp4_var.t_info.runtime_size)),

		MakeMI(.exit),
	]);


	start_foo_instr_index : int = instr_index;
	//foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Input at ax = [sbp,0] + 1
		MakeMI(.add, RamMem(.sbp,8), x_foo_var.op, Imm(1)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.int_type_info.runtime_size),
			RamMem(.sbp,8), 
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

//TODO FROM HERE 
//SHOULD WE Test function pointers as args and return values.
//Can we reuse the code from FUNCTION_NAME assignment to check for function overloads?
//THEN function pointer calls
//Then also write an integration test for function pointers
//This will set us up for making a sorting algorithm later.
//DOCUMENT FUNCTION POINTERS HERE OR IN FUNCTION CALL
//SOMEWHERE AND START DOCUMENTING EACH FEATURE
//Just write as much info as possible so we remember details
//when we come bakc if needed
Test_CompFuncPointerArgs :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	x := PFunc(Foo);
	y : int = Apply(2, Foo);
}
Foo :: (x : int) -> int {
	return x + 1;
}
PFunc :: (fp : (int) -> int) -> int {
	return fp(1);
}
Apply :: (i : int, fp : (int) -> int) -> int {
	ri : int = fp(i);
	return ri;
}
DONE,,unit_test_alloc);

	//NOTE : First type is main type () -> ()
	count_equal = AssertEquals(4, cd.all_type_info_procedure.count);
	foo_type : *TypeInfoProcedure;
	pfunc_type : *TypeInfoProcedure;
	apply_type : *TypeInfoProcedure;
	if count_equal {
		foo_type = cd.all_type_info_procedure[1];
		AssertEquals(1, foo_type.argument_types.count);
		AssertEquals(*cd.int_type_info, foo_type.argument_types[0]);
		AssertEquals(1, foo_type.return_types.count);
		AssertEquals(*cd.int_type_info, foo_type.return_types[0]);

		pfunc_type = cd.all_type_info_procedure[2];
		AssertEquals(1, pfunc_type.argument_types.count);
		AssertEquals(cast(*TypeInfo) foo_type, pfunc_type.argument_types[0]);
		AssertEquals(1, pfunc_type.return_types.count);
		AssertEquals(*cd.int_type_info, pfunc_type.return_types[0]);

		apply_type = cd.all_type_info_procedure[3];
		AssertEquals(2, apply_type.argument_types.count);
		AssertEquals(*cd.int_type_info, apply_type.argument_types[0]);
		AssertEquals(cast(*TypeInfo) foo_type, apply_type.argument_types[1]);
		AssertEquals(1, apply_type.return_types.count);
		AssertEquals(*cd.int_type_info, apply_type.return_types[0]);
	}

	count_equal = AssertEquals(4, cd.all_function_declarations.count);
	foo_decl : FunctionDeclaration;
	pfunc_decl : FunctionDeclaration;
	apply_decl : FunctionDeclaration;
	if count_equal {
		foo_decl = cd.all_function_declarations[1];
		AssertEquals(foo_type, foo_decl.t_info_proc);

		pfunc_decl = cd.all_function_declarations[2];
		AssertEquals(pfunc_type, pfunc_decl.t_info_proc);

		apply_decl = cd.all_function_declarations[3];
		AssertEquals(apply_type, apply_decl.t_info_proc);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("y", *cd.int_type_info, RamMem(.sbp,8)),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("fp", *foo_type.info, RamMem(.sbp,0)),
		VarDecl("i", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("fp", *foo_type.info, RamMem(.sbp,8)),
	]);
	if !vars_equal return;
	x_var := cd.all_variables[0];
	y_var := cd.all_variables[1];
	x_foo_var := cd.all_variables[2];
	fp_foo_var := cd.all_variables[3];
	i_apply_var := cd.all_variables[4];
	fp_apply_var := cd.all_variables[5];

	instr_index : int = 0;
	foo_op := RamMem(.sbp,0);
	//We add 8 for the initially stored value for Foo
	next_stack_p : int = 8 + PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == pfunc_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	TestNextManyInstr(*instr_index, cd, .[
		//Foo store in memory so it can be set later in out of order instrs
		MakeMI(.mov, foo_op, Imm(foo_decl.start_instr_index), Imm(cd.void_pointer_type_info.runtime_size)),

		//Pointer(Foo)
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,16)),
		//Push on integer 1 argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), foo_op, Imm(8)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(6)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(pfunc_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		// x := Pointer(Foo);
		MakeMI(.mov, x_var.op, RamMem(.sbp,8), Imm(cd.int_type_info.runtime_size)),
	]);

	foo_op = RamMem(.sbp,8);
	//We add 8 for the initially stored value for Foo
	next_stack_p = 8 + x_var.t_info.runtime_size + PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == apply_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	return_op := RamMem(.sbp,16);
	TestNextManyInstr(*instr_index, cd, .[
		//Foo store in memory so it can be set later in out of order instrs
		MakeMI(.mov, foo_op, Imm(foo_decl.start_instr_index), Imm(cd.void_pointer_type_info.runtime_size)),

		//Apply(2, Foo)
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, AddOperandOffset(8, return_op)),
		//Push on integer 2 argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), Imm(2), Imm(apply_type.argument_types[0].runtime_size)),
		//Push on integer 1 argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p+8), foo_op, Imm(apply_type.argument_types[1].runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+7)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(apply_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		// y : int = Apply(2, Foo);
		MakeMI(.mov, y_var.op, return_op, Imm(cd.int_type_info.runtime_size)),

		//end of main function
		MakeMI(.exit),
	]);

	//Foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, RamMem(.sbp,8), x_foo_var.op, Imm(1)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.int_type_info.runtime_size),
			RamMem(.sbp,8), 
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	//PFunc :: (fp : (int) -> int) -> int
	pfunc_stack_p : int = fp_foo_var.t_info.runtime_size;
	pfunc_return_op := RamMem(.sbp,pfunc_stack_p);
	for cd.all_function_return_variables if it.function_id == pfunc_decl.id {
		pfunc_stack_p += it.t_info.runtime_size;
	}
	f_stack_push_pos : int = pfunc_stack_p;
	//Add the stack for foo call which is in f2 
	pfunc_stack_p += PRE_PROC_STACK_SIZE;
	//PFunc :: (fp : (int) -> int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		//Set the function pointer so we still have it when we make the call
		MakeMI(.mov, RegMem(.foop), fp_foo_var.op, Imm(fp_foo_var.t_info.runtime_size)),
		//fp(1)
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,f_stack_push_pos)),
		//Push on integer x argument
		MakeMI(.mov, RamMem(.sbp,pfunc_stack_p), Imm(1), Imm(foo_type.argument_types[0].runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(pfunc_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+6)),
		//call foo with instruction index = 0
		MakeMI(.call, RegMem(.foop)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),


		//return fp(1);
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-fp_foo_var.t_info.runtime_size), 
			pfunc_return_op,
			Imm(pfunc_type.return_types[0].runtime_size)),
		MakeMI(.ret),
	]);

	//Apply :: (i : int, fp : (int) -> int) -> int
	apply_stack_p : int;
	for cd.all_function_arguments if it.function_id == apply_decl.id {
		apply_stack_p += it.t_info.runtime_size;
	}
	fp_return_op := RamMem(.sbp,apply_stack_p);
	for cd.all_function_return_variables if it.function_id == apply_decl.id {
		apply_stack_p += it.t_info.runtime_size;
	}
	apply_stack_push_pos : int = apply_stack_p;
	//Add the stack for foo call which is in f2 
	apply_stack_p += PRE_PROC_STACK_SIZE;
	//PFunc :: (fp : (int) -> int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, RegMem(.foop), fp_apply_var.op, Imm(fp_apply_var.t_info.runtime_size)),
		//ri : int = fp(i);
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, RamMem(.sbp,apply_stack_push_pos)),
		//Push on integer x argument
		MakeMI(.mov, RamMem(.sbp,apply_stack_p), i_apply_var.op, Imm(foo_type.argument_types[0].runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(apply_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+6)),
		//call foo with instruction index = 0
		MakeMI(.call, RegMem(.foop)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		//return ri;
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.int_type_info.runtime_size), 
			fp_return_op,
			Imm(apply_type.return_types[0].runtime_size)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CompFuncPointerRet :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
main :: () {
	pr : (int) -> int = PRet();
	// p2 := PRet2();
}
Foo :: (x : int) -> int {
	return x + 1;
}
PRet :: () -> ((int) -> int) {
	return Foo;
}
//TODO Can add this as a test as well.
// PRet2 :: () -> ((int) -> int) {
// 	f := Foo;
// 	return f;
// }
DONE,,unit_test_alloc);

	//NOTE : First type is main type () -> ()
	count_equal = AssertEquals(3, cd.all_type_info_procedure.count);
	foo_type : *TypeInfoProcedure;
	pret_type : *TypeInfoProcedure;
	if count_equal {
		foo_type = cd.all_type_info_procedure[1];
		AssertEquals(1, foo_type.argument_types.count);
		AssertEquals(*cd.int_type_info, foo_type.argument_types[0]);
		AssertEquals(1, foo_type.return_types.count);
		AssertEquals(*cd.int_type_info, foo_type.return_types[0]);

		pret_type = cd.all_type_info_procedure[2];
		AssertEquals(0, pret_type.argument_types.count);
		AssertEquals(1, pret_type.return_types.count);
		AssertEquals(cast(*TypeInfo) foo_type, pret_type.return_types[0]);
	}

	count_equal = AssertEquals(3, cd.all_function_declarations.count);
	foo_decl : FunctionDeclaration;
	pret_decl : FunctionDeclaration;
	if count_equal {
		foo_decl = cd.all_function_declarations[1];
		AssertEquals(foo_type, foo_decl.t_info_proc);

		pret_decl = cd.all_function_declarations[2];
		AssertEquals(pret_type, pret_decl.t_info_proc);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("pr", *foo_type.info, RamMem(.sbp,0)),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	pr_var := cd.all_variables[0];
	x_foo_var := cd.all_variables[1];

	instr_index : int = 0;
	return_op := RamMem(.sbp,0);
	next_stack_p : int = PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == pret_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	TestNextManyInstr(*instr_index, cd, .[
		//PRet()
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, AddOperandOffset(foo_type.return_types[0].runtime_size, return_op)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(4)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(pret_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		//Optimized out since we copy to the same place
		// pr : (int) -> int = PRet()
		// MakeMI(.mov, pr_var.op, return_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.exit),
	]);

	//Foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, RamMem(.sbp,8), x_foo_var.op, Imm(1)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.int_type_info.runtime_size),
			RamMem(.sbp,8), 
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	//PRet :: () -> ((int) -> int)
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-foo_type.runtime_size),
			Imm(foo_decl.start_instr_index), 
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_ParseDirectiveType :: () {
	ptd := MakeParseTestData();

	/*
		   ::
		  /   \
		int2  #type
		        \
		        int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "int2 :: #type int;");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "int2")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "#", cast(int) CodeDirective.type), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*
		   ::
		  /   \
		int2  #type
		        \
		        ->
		       /  \
		     int   int
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "ip :: #type (int) -> int");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.DOUBLE_COLON), .BINARY_OP),
		BNode(LCToken(.IDENT, "ip")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "#", cast(int) CodeDirective.type), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.RIGHT_ARROW), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

} @UnitTest
Test_DirectiveType :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
int2 :: #type int;
main :: () {
	i : int2 = 5;
	pr : ip = PRet();
}
//Test out of order type here since we use it in main before this declaration
ip :: #type (int) -> int;
Foo :: (x : int) -> int {
	return x + 1;
}
PRet :: () -> ip {
	return Foo;
}
DONE,,unit_test_alloc);

	//NOTE : First type is main type () -> ()
	count_equal = AssertEquals(3, cd.all_type_info_procedure.count);
	foo_type : *TypeInfoProcedure;
	pret_type : *TypeInfoProcedure;
	if count_equal {
		foo_type = cd.all_type_info_procedure[1];
		AssertEquals(1, foo_type.argument_types.count);
		AssertEquals(*cd.int_type_info, foo_type.argument_types[0]);
		AssertEquals(1, foo_type.return_types.count);
		AssertEquals(*cd.int_type_info, foo_type.return_types[0]);

		pret_type = cd.all_type_info_procedure[2];
		AssertEquals(0, pret_type.argument_types.count);
		AssertEquals(1, pret_type.return_types.count);
		AssertEquals(cast(*TypeInfo) foo_type, pret_type.return_types[0]);
	}

	count_equal = AssertEquals(3, cd.all_function_declarations.count);
	foo_decl : FunctionDeclaration;
	pret_decl : FunctionDeclaration;
	if count_equal {
		foo_decl = cd.all_function_declarations[1];
		AssertEquals(foo_type, foo_decl.t_info_proc);

		pret_decl = cd.all_function_declarations[2];
		AssertEquals(pret_type, pret_decl.t_info_proc);
	}

	count_equal = AssertEquals(2, cd.all_directive_type_names.count);
	if count_equal {
		AssertEquals("int2", cd.all_directive_type_names[0].name);
		AssertEquals(*cd.int_type_info, cd.all_directive_type_names[0].t_info);

		AssertEquals("ip", cd.all_directive_type_names[1].name);
		AssertEquals(cast(*TypeInfo) foo_type, cd.all_directive_type_names[1].t_info);
	}


	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("i", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("pr", *foo_type.info, RamMem(.sbp,8)),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	i_var := cd.all_variables[0];
	pr_var := cd.all_variables[1];
	x_foo_var := cd.all_variables[2];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		// i : int2 = 5;
		MakeMI(.mov, i_var.op, Imm(5), Imm(cd.int_type_info.runtime_size)),
	]);

	return_op := RamMem(.sbp,8);
	next_stack_p : int = i_var.t_info.runtime_size + PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == pret_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	TestNextManyInstr(*instr_index, cd, .[
		//PRet()
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, AddOperandOffset(foo_type.return_types[0].runtime_size, return_op)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+4)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(pret_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		//Optimized out since we copy to the same place
		// pr : (int) -> int = PRet()
		// MakeMI(.mov, pr_var.op, return_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.exit),
	]);

	//Foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, RamMem(.sbp,8), x_foo_var.op, Imm(1)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.int_type_info.runtime_size),
			RamMem(.sbp,8), 
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	//PRet :: () -> ((int) -> int)
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-foo_type.runtime_size),
			Imm(foo_decl.start_instr_index), 
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);


//TEST Type with same name should return and error.
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
ip :: #type int;
ip :: #type float;
main :: () {
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

//TEST Type with same name as struct should return and error.
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
ip :: #type int;
ip :: struct {};
main :: () {
}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);


} @UnitTest

Test_ParseDirectiveLoad :: () {
	ptd := MakeParseTestData();

	/*
		#load
		    \
		  "Basic"
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "#load \"Basic\";");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "#", cast(int) CodeDirective.load), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.STRING, "Basic")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

} @UnitTest
Test_DirectiveLoad :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
#load "c_test/utest";
main :: () {
  v : V2;
  x := Foo(0);
}
DONE,,unit_test_alloc);

	v2_info, found_v2_info := GetTypeInfoStructByName("V2", cd.all_type_info_struct);
	AssertEquals(true, found_v2_info);
	if !found_v2_info return;
	AssertEquals(16, v2_info.runtime_size);
	AssertEquals("V2", v2_info.name);
	AssertEquals(TypeInfoTag.STRUCT, v2_info.type_enum);
	v2_x_info, found_x_info := GetStructMember("x", v2_info);
	AssertEquals(true, found_x_info);
	if !found_x_info return;
	AssertEquals(cd.float_type_info.runtime_size, v2_x_info.t_info.runtime_size);
	AssertEquals("x", v2_x_info.name);
	AssertEquals(TypeInfoTag.FLOAT, v2_x_info.t_info.type_enum);
	AssertEquals(0, v2_x_info.offset_in_bytes);
	v2_y_info, found_y_info := GetStructMember("y", v2_info);
	AssertEquals(true, found_y_info);
	if !found_y_info return;
	AssertEquals(cd.float_type_info.runtime_size, v2_y_info.t_info.runtime_size);
	AssertEquals("y", v2_y_info.name);
	AssertEquals(TypeInfoTag.FLOAT, v2_y_info.t_info.type_enum);
	AssertEquals(8, v2_y_info.offset_in_bytes);

	//NOTE : First type is main type () -> ()
	count_equal = AssertEquals(2, cd.all_type_info_procedure.count);
	foo_type : *TypeInfoProcedure;
	if count_equal {
		foo_type = cd.all_type_info_procedure[1];
		AssertEquals(1, foo_type.argument_types.count);
		AssertEquals(*cd.int_type_info, foo_type.argument_types[0]);
		AssertEquals(1, foo_type.return_types.count);
		AssertEquals(*cd.int_type_info, foo_type.return_types[0]);
	}

	count_equal = AssertEquals(2, cd.all_function_declarations.count);
	foo_decl : FunctionDeclaration;
	if count_equal {
		foo_decl = cd.all_function_declarations[1];
		AssertEquals(foo_type, foo_decl.t_info_proc);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("v", *v2_info.info, RamMem(.sbp,0)),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,v2_info.runtime_size)),
		VarDecl("x", *cd.int_type_info, RamMem(.sbp,0)),
		VarDecl("y", *cd.int_type_info, RamMem(.sbp,8)),
	]);
	if !vars_equal return;
	v_var := cd.all_variables[0];
	x_var := cd.all_variables[1];
	x_foo_var := cd.all_variables[2];
	y_foo_var := cd.all_variables[3];

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		// v : V2;
		MakeMI(.mset, v_var.op, Imm(0), Imm(v2_info.runtime_size)),
	]);

	return_op := RamMem(.sbp,v_var.t_info.runtime_size);
	next_stack_p : int = v_var.t_info.runtime_size + PRE_PROC_STACK_SIZE;
	for cd.all_function_return_variables if it.function_id == foo_decl.id {
		next_stack_p += it.t_info.runtime_size;
	}
	TestNextManyInstr(*instr_index, cd, .[
		//Foo(0)
		//Push all reg values on (including sbp and scp) so we can get them back after
		MakeMI(.push_all_stack_reg, AddOperandOffset(foo_type.return_types[0].runtime_size, return_op)),
		//Push on integer 0 argument
		MakeMI(.mov, RamMem(.sbp,next_stack_p), Imm(0), Imm(cd.int_type_info.runtime_size)),
		//Reset the .sbp for the new stack
		MakeMI(.add, RegMem(.sbp), RegMem(.sbp), Imm(next_stack_p)),
		//Push where we need to jmp back to
		MakeMI(.mov, PROC_RETURN_OP, Imm(instr_index+5)),
		//call foo with instruction index = 0
		MakeMI(.call, Imm(foo_decl.start_instr_index)),
		//Reload all values from previous satck so we get back our last sbp and scp here too.
		MakeMI(.pop_all_stack_reg, PREVIOUS_SBP_OP),

		//Return optimized out since we copy to the same place
		// MakeMI(.mov, pr_var.op, return_op, Imm(cd.int_type_info.runtime_size)),
		MakeMI(.exit),
	]);

	//Foo :: (x : int) -> int
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.add, y_foo_var.op, x_foo_var.op, Imm(1)),
		MakeMI(.mov, 
			RamMem(.sbp,-PRE_PROC_STACK_SIZE-cd.int_type_info.runtime_size),
			y_foo_var.op, 
			Imm(cd.int_type_info.runtime_size)),
		MakeMI(.ret),
	]);

	AssertEquals(instr_index, cd.all_music_instructions.count);


//TEST 2 same loads should error.
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
#load "c_load/utest";
#load "./c_load/utest";
main :: () {}
DONE,,unit_test_alloc);
	AssertEquals(true, cd.comp_errors.all_compiler_errors.count > 0);

} @UnitTest

/*DOC : This test is here to test each part of the Library so we have 1 extensive
test of pulling in various things through a load to make sure that is working.
As we add things to the library, we can check if they are compiled correctly here.
*/
Test_LoadLibrary :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equals : bool;

//TODO Is it worth putting a call for each library function and data here? Not sure it does anything more than
//having this test + integration test that actually runs the code of checking.
	cd = CompileCode(cs,
#string DONE
#load "c_load/Library";
main :: () {}
DONE,,unit_test_alloc);

	op_space_type_enum, found_op_space_type_enum := GetTypeInfoEnumByName("AsmOpSpaceType", cd.all_type_info_enum);
	AssertEquals(true, found_op_space_type_enum);
	if !found_op_space_type_enum return;
	AssertEquals("space_2d", op_space_type_enum.names[0]);
	AssertEquals(0, op_space_type_enum.values[0]);
	AssertEquals("space_3d", op_space_type_enum.names[1]);
	AssertEquals(1, op_space_type_enum.values[1]);

	/*TODO REMINDER : I think we can add struct members to struct info and then start using that
	and gradually remove the old way which should not be too hard over time.
	OR we can add them all at the end of compilation to use externally but internally we still use array
	and then maybe swap them out later.
	*/
	//TODO Maybe this test makes me want to put struct members into the type info struct now.
	v2_info, found_v2_info := GetTypeInfoStructByName("Vector2", cd.all_type_info_struct);
	AssertEquals(true, found_v2_info);
	if !found_v2_info return;
	AssertEquals(16, v2_info.runtime_size);
	AssertEquals("Vector2", v2_info.name);
	AssertEquals(TypeInfoTag.STRUCT, v2_info.type_enum);
	count_equals = AssertEquals(2, v2_info.struct_members.count);
	if !count_equals return;
	v2_x_info := v2_info.struct_members[0];
	AssertEquals(cd.float_type_info.runtime_size, v2_x_info.t_info.runtime_size);
	AssertEquals("x", v2_x_info.name);
	AssertEquals(TypeInfoTag.FLOAT, v2_x_info.t_info.type_enum);
	AssertEquals(0, v2_x_info.offset_in_bytes);
	v2_y_info := v2_info.struct_members[1];
	AssertEquals(cd.float_type_info.runtime_size, v2_y_info.t_info.runtime_size);
	AssertEquals("y", v2_y_info.name);
	AssertEquals(TypeInfoTag.FLOAT, v2_y_info.t_info.type_enum);
	AssertEquals(8, v2_y_info.offset_in_bytes);

	//TODO Can likeley remove this test once we remove this setup data
	#if 0 {
	smd_info, found_smd_info := GetTypeInfoStructByName("SetupMusicData", cd.all_type_info_struct);
	AssertEquals(true, found_smd_info);
	if !found_smd_info return;
	//TODO This could really work if we use the Library structs in common with jai and game.
	//Can't really use the code becuase of asm and tano functionality.
	AssertEquals(size_of(SetupMusicData), smd_info.runtime_size);
	AssertEquals("SetupMusicData", smd_info.name);
	AssertEquals(TypeInfoTag.STRUCT, smd_info.type_enum);
	count_equals = AssertEquals(3, smd_info.struct_members.count);
	if !count_equals return;	
	row_size_info := smd_info.struct_members[0];
	AssertEquals(cd.float_type_info.runtime_size, row_size_info.t_info.runtime_size);
	AssertEquals("row_size", row_size_info.name);
	AssertEquals(TypeInfoTag.INTEGER, row_size_info.t_info.type_enum);
	AssertEquals(0, row_size_info.offset_in_bytes);
	mem_units_info := smd_info.struct_members[1];
	AssertEquals(cd.float_type_info.runtime_size, mem_units_info.t_info.runtime_size);
	AssertEquals("memory_units_per_second", mem_units_info.name);
	AssertEquals(TypeInfoTag.FLOAT, mem_units_info.t_info.type_enum);
	AssertEquals(8, mem_units_info.offset_in_bytes);
	bpm_info := smd_info.struct_members[2];
	AssertEquals(cd.float_type_info.runtime_size, bpm_info.t_info.runtime_size);
	AssertEquals("bpm", bpm_info.name);
	AssertEquals(TypeInfoTag.FLOAT, bpm_info.t_info.type_enum);
	AssertEquals(16, bpm_info.offset_in_bytes);
	}

	row_section_info, found_row_section_info := GetTypeInfoStructByName("RowSectionData", cd.all_type_info_struct);
	AssertEquals(true, found_row_section_info);
	if !found_row_section_info return;
	//TODO This could really work if we use the Library structs in common with jai and game.
	//Can't really use the code becuase of asm and tano functionality.
	AssertEquals(size_of(RowSectionData), row_section_info.runtime_size);
	AssertEquals("RowSectionData", row_section_info.name);
	AssertEquals(TypeInfoTag.STRUCT, row_section_info.type_enum);
	count_equals = AssertEquals(3, row_section_info.struct_members.count);
	if !count_equals return;
	linear_view_info := row_section_info.struct_members[0];
	AssertEquals(cd.int_type_info.runtime_size, linear_view_info.t_info.runtime_size);
	AssertEquals("linear_view", linear_view_info.name);
	AssertEquals(TypeInfoTag.ENUM, linear_view_info.t_info.type_enum);
	AssertEquals(0, linear_view_info.offset_in_bytes);
	tuning_system_info := row_section_info.struct_members[1];
	AssertEquals(cd.int_type_info.runtime_size, tuning_system_info.t_info.runtime_size);
	AssertEquals("tuning_system_id", tuning_system_info.name);
	AssertEquals(TypeInfoTag.INTEGER, tuning_system_info.t_info.type_enum);
	AssertEquals(8, tuning_system_info.offset_in_bytes);
	x_length_info := row_section_info.struct_members[2];
	AssertEquals(cd.int_type_info.runtime_size, x_length_info.t_info.runtime_size);
	AssertEquals("x_length", x_length_info.name);
	AssertEquals(TypeInfoTag.INTEGER, x_length_info.t_info.type_enum);
	AssertEquals(16, x_length_info.offset_in_bytes);

	row_section_ptr, found_row_section_ptr := GetTypeInfoPointer(row_section_info, cd);
	AssertEquals(true, found_row_section_ptr);
	if !found_row_section_ptr return;

	row_data_info, found_row_data_info := GetTypeInfoStructByName("AsmCreateRowData", cd.all_type_info_struct);
	AssertEquals(true, found_row_data_info);
	if !found_row_data_info return;
	AssertEquals(size_of(AsmCreateRowData), row_data_info.runtime_size);
	AssertEquals("AsmCreateRowData", row_data_info.name);
	AssertEquals(TypeInfoTag.STRUCT, row_data_info.type_enum);
	count_equals = AssertEquals(9, row_data_info.struct_members.count);
	if !count_equals return;	
	octave_info := row_data_info.struct_members[0];
	AssertEquals(cd.float_type_info.runtime_size, octave_info.t_info.runtime_size);
	AssertEquals("octave_height", octave_info.name);
	AssertEquals(TypeInfoTag.FLOAT, octave_info.t_info.type_enum);
	AssertEquals(0, octave_info.offset_in_bytes);
	row_height_info := row_data_info.struct_members[1];
	AssertEquals(cd.float_type_info.runtime_size, row_height_info.t_info.runtime_size);
	AssertEquals("row_height", row_height_info.name);
	AssertEquals(TypeInfoTag.FLOAT, row_height_info.t_info.type_enum);
	AssertEquals(8, row_height_info.offset_in_bytes);
	row_base_pt := row_data_info.struct_members[2];
	AssertEquals(cd.float_type_info.runtime_size, row_base_pt.t_info.runtime_size);
	AssertEquals("row_base_pt", row_base_pt.name);
	AssertEquals(TypeInfoTag.FLOAT, row_base_pt.t_info.type_enum);
	AssertEquals(16, row_base_pt.offset_in_bytes);
	sound_on_info := row_data_info.struct_members[3];
	AssertEquals(cd.float_type_info.runtime_size, sound_on_info.t_info.runtime_size);
	AssertEquals("muted_row", sound_on_info.name);
	AssertEquals(TypeInfoTag.BOOL, sound_on_info.t_info.type_enum);
	AssertEquals(24, sound_on_info.offset_in_bytes);
	row_system_type_info := row_data_info.struct_members[4];
	AssertEquals(cd.float_type_info.runtime_size, row_system_type_info.t_info.runtime_size);
	AssertEquals("row_system_type", row_system_type_info.name);
	AssertEquals(TypeInfoTag.ENUM, row_system_type_info.t_info.type_enum);
	AssertEquals(32, row_system_type_info.offset_in_bytes);
	row_system_id_info := row_data_info.struct_members[5];
	AssertEquals(cd.int_type_info.runtime_size, row_system_id_info.t_info.runtime_size);
	AssertEquals("row_system_id", row_system_id_info.name);
	AssertEquals(TypeInfoTag.INTEGER, row_system_id_info.t_info.type_enum);
	AssertEquals(40, row_system_id_info.offset_in_bytes);
	row_sub_system_id_info := row_data_info.struct_members[6];
	AssertEquals(cd.int_type_info.runtime_size, row_sub_system_id_info.t_info.runtime_size);
	AssertEquals("row_sub_system_id", row_sub_system_id_info.name);
	AssertEquals(TypeInfoTag.INTEGER, row_sub_system_id_info.t_info.type_enum);
	AssertEquals(48, row_sub_system_id_info.offset_in_bytes);
	section_count_info := row_data_info.struct_members[7];
	AssertEquals(cd.all_type_info_array[0].runtime_size, section_count_info.t_info.runtime_size);
	AssertEquals("row_sections", section_count_info.name);
	AssertEquals(TypeInfoTag.ARRAY, section_count_info.t_info.type_enum);
	AssertEquals(56, section_count_info.offset_in_bytes);
	asm_midi_info, found_asm_midi_info := GetTypeInfoStructByName("AsmRowMidiData", cd.all_type_info_struct);
	asm_midi_member_info := row_data_info.struct_members[8];
	AssertEquals(asm_midi_info.runtime_size, asm_midi_member_info.t_info.runtime_size);
	AssertEquals("row_midi_data", asm_midi_member_info.name);
	AssertEquals(TypeInfoTag.STRUCT, asm_midi_member_info.t_info.type_enum);
	AssertEquals(72, asm_midi_member_info.offset_in_bytes);

	create_space_info, found_create_space_info := GetTypeInfoStructByName("AsmOpSpaceData", cd.all_type_info_struct);
	AssertEquals(true, found_create_space_info);
	if !found_create_space_info return;
	//TODO This could really work if we use the Library structs in common with jai and game.
	//Can't really use the code becuase of asm and tano functionality.
	AssertEquals(size_of(AsmOpSpaceData), create_space_info.runtime_size);
	AssertEquals("AsmOpSpaceData", create_space_info.name);
	AssertEquals(TypeInfoTag.STRUCT, create_space_info.type_enum);
	count_equals = AssertEquals(3, create_space_info.struct_members.count);
	if !count_equals return;
	op_space_id_info := create_space_info.struct_members[0];
	AssertEquals(cd.int_type_info.runtime_size, op_space_id_info.t_info.runtime_size);
	AssertEquals("ret_op_space_id", op_space_id_info.name);
	AssertEquals(TypeInfoTag.INTEGER, op_space_id_info.t_info.type_enum);
	AssertEquals(0, op_space_id_info.offset_in_bytes);
	op_space_type_info := create_space_info.struct_members[1];
	AssertEquals(cd.int_type_info.runtime_size, op_space_type_info.t_info.runtime_size);
	AssertEquals("op_space_type", op_space_type_info.name);
	AssertEquals(TypeInfoTag.ENUM, op_space_type_info.t_info.type_enum);
	AssertEquals(*op_space_type_enum.info, op_space_type_info.t_info);
	AssertEquals(8, op_space_type_info.offset_in_bytes);
	op_space_name_info := create_space_info.struct_members[2];
	AssertEquals(cd.string_type_info.runtime_size, op_space_name_info.t_info.runtime_size);
	AssertEquals("op_space_name", op_space_name_info.name);
	AssertEquals(TypeInfoTag.STRING, op_space_name_info.t_info.type_enum);
	AssertEquals(16, op_space_name_info.offset_in_bytes);

	create_circle_info, found_create_circle_info := GetTypeInfoStructByName("AsmCircleData", cd.all_type_info_struct);
	AssertEquals(true, found_create_circle_info);
	if !found_create_circle_info return;
	//DOC : This is a good check that ensures that we update the library in game library struct when we update
	//the actual game struct below.
	AssertEquals(size_of(AsmCircleData), create_circle_info.runtime_size);
	AssertEquals("AsmCircleData", create_circle_info.name);
	AssertEquals(TypeInfoTag.STRUCT, create_circle_info.type_enum);
	count_equals = AssertEquals(true, create_circle_info.struct_members.count > 2);
	if !count_equals return;
	ret_dspace_id_info := create_circle_info.struct_members[0];
	AssertEquals(cd.int_type_info.runtime_size, ret_dspace_id_info.t_info.runtime_size);
	AssertEquals("ret_dspace_id", ret_dspace_id_info.name);
	AssertEquals(TypeInfoTag.INTEGER, ret_dspace_id_info.t_info.type_enum);
	AssertEquals(0, ret_dspace_id_info.offset_in_bytes);
	circle_radius_info := create_circle_info.struct_members[1];
	AssertEquals(cd.float_type_info.runtime_size, circle_radius_info.t_info.runtime_size);
	AssertEquals("radius", circle_radius_info.name);
	AssertEquals(TypeInfoTag.FLOAT, circle_radius_info.t_info.type_enum);
	AssertEquals(8, circle_radius_info.offset_in_bytes);
	//TODO I am only doing the first 2 struct members here because we might change the rest to vectors
	//and remove values and don't want test to arbitrarily fail.

	map_circle_info, found_map_circle_info := GetTypeInfoStructByName("AsmMapCircle", cd.all_type_info_struct);
	AssertEquals(true, found_map_circle_info);
	if !found_map_circle_info return;
	AssertEquals(size_of(AsmMapCircle), map_circle_info.runtime_size);
	AssertEquals("AsmMapCircle", map_circle_info.name);
	AssertEquals(TypeInfoTag.STRUCT, map_circle_info.type_enum);
	count_equals = AssertEquals(5, map_circle_info.struct_members.count);
	if !count_equals return;
	circle_dspace_info := map_circle_info.struct_members[0];
	AssertEquals(cd.int_type_info.runtime_size, circle_dspace_info.t_info.runtime_size);
	AssertEquals("dspace_id", circle_dspace_info.name);
	AssertEquals(TypeInfoTag.INTEGER, circle_dspace_info.t_info.type_enum);
	AssertEquals(0, circle_dspace_info.offset_in_bytes);
	circle_op_space_info := map_circle_info.struct_members[1];
	AssertEquals(cd.int_type_info.runtime_size, circle_op_space_info.t_info.runtime_size);
	AssertEquals("op_space_id", circle_op_space_info.name);
	AssertEquals(TypeInfoTag.INTEGER, circle_op_space_info.t_info.type_enum);
	AssertEquals(8, circle_op_space_info.offset_in_bytes);
	circle_shape_group_info := map_circle_info.struct_members[2];
	AssertEquals(cd.int_type_info.runtime_size, circle_shape_group_info.t_info.runtime_size);
	AssertEquals("dspace_shape_group", circle_shape_group_info.name);
	AssertEquals(TypeInfoTag.INTEGER, circle_shape_group_info.t_info.type_enum);
	AssertEquals(16, circle_shape_group_info.offset_in_bytes);
	circle_points_info := map_circle_info.struct_members[3];
	circle_points_array_type := cast(*TypeInfoArray) circle_points_info.t_info;
	float_view_info, found_float_view_info := GetArrayType(cd, *cd.float_type_info, .VIEW);
	AssertEquals(true, found_float_view_info);
	if !found_float_view_info return;
	AssertEquals(float_view_info.runtime_size, circle_points_info.t_info.runtime_size);
	AssertEquals("pitches", circle_points_info.name);
	AssertEquals(TypeInfoTag.ARRAY, circle_points_info.t_info.type_enum);
	AssertEquals(TypeInfoTag.FLOAT, circle_points_array_type.element_type.type_enum);
	AssertEquals(24, circle_points_info.offset_in_bytes);
	circle_draw_vl_info := map_circle_info.struct_members[4];
	circle_draw_vl_enum_type := cast(*TypeInfoEnum) circle_draw_vl_info.t_info;
	AssertEquals("DrawVLType", circle_draw_vl_enum_type.name);
	AssertEquals(cd.int_type_info.runtime_size, circle_draw_vl_info.t_info.runtime_size);
	AssertEquals("draw_vl_type", circle_draw_vl_info.name);
	AssertEquals(TypeInfoTag.ENUM, circle_draw_vl_info.t_info.type_enum);
	AssertEquals(40, circle_draw_vl_info.offset_in_bytes);


	draw_vl_info, found_draw_vl_enum := GetTypeInfoEnumByName("DrawVLType", cd.all_type_info_enum);
	AssertEquals(true, found_draw_vl_enum);
	if !found_draw_vl_enum return;
	AssertEquals("NONE", draw_vl_info.names[0]);
	AssertEquals(0, draw_vl_info.values[0]);
	AssertEquals("VL_LINE", draw_vl_info.names[1]);
	AssertEquals(1, draw_vl_info.values[1]);
	AssertEquals("VL_ARROW", draw_vl_info.names[2]);
	AssertEquals(2, draw_vl_info.values[2]);


	//NOTE : First type is main type () -> ()
	count_equals = AssertEquals(1, cd.all_type_info_procedure.count);
	setup_music_type : *TypeInfoProcedure;
	if count_equals {
		// setup_music_type = cd.all_type_info_procedure[1];
		// AssertEquals(1, setup_music_type.argument_types.count);
		// AssertEquals(*smd_info.info, setup_music_type.argument_types[0]);
		// AssertEquals(0, setup_music_type.return_types.count);
	}

	count_equals = AssertEquals(1, cd.all_function_declarations.count);
	setup_music_decl : FunctionDeclaration;
	if count_equals {
		// setup_music_decl = cd.all_function_declarations[1];
		// AssertEquals(setup_music_type, setup_music_decl.t_info_proc);
		//NOTE : Leaving names out in case we decide to change them later. Can add back when final.
		// AssertEquals("SetupMusic", setup_music_decl.name);
	}

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		// VarDecl("smd", smd_info, RamMem(.sbp,0)),
	]);
	if !vars_equal return;
	// smd_var := cd.all_variables[0];

	instr_index : int = 0;
	//empty main function
	TestNextManyInstr(*instr_index, cd, .[
		MakeMI(.exit),
	]);

	//TODO Leaving some code here for when we add a function back to the library
	// SetupMusic :: (smd : SetupMusicData) {
	//   #asm{ muscall 4, smd; }
	// }
	// TestNextManyInstr(*instr_index, cd, .[
	// 	MakeMI(.muscall, Imm(cast(int) MusCallType.setup_music), smd_var.op),
	// 	MakeMI(.ret),
	// ]);

	//Commenting this check out so we don't fail right away when adding new things to library.
	//We can uncomment them if we want to remind us to test new Library functions and data here.
	// AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

Test_CreateRow :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	cd = CompileCode(cs,
#string DONE
#load "c_load/Library";
main :: () {
//TODO Can set this as a fixed array and test a fixed array with struct here for asm compiler test
  rs : RowSectionData;
  rs.linear_view = LinearPitchSpaceView.RATIO_PROPORTIONAL;
  rs.tuning_system_id = 0;
  rs.x_length = 12;

  rd : AsmCreateRowData;
  rd.octave_height = 12.0;
  rd.row_height = 12.0;
  rd.muted_row = false;
  rd.row_system_type = RowSystemType.internal_pitch;
  rd.row_sections = RowSectionData.[rs];
  #asm{ create_row rd; }
}
DONE,,unit_test_alloc);

	// print("%\n", cd.disassembly);

	row_data_info, found_row_data_info := GetTypeInfoStructByName("AsmCreateRowData", cd.all_type_info_struct);
	AssertEquals(true, found_row_data_info);
	if !found_row_data_info return;

	row_section_info, found_row_section_info := GetTypeInfoStructByName("RowSectionData", cd.all_type_info_struct);
	AssertEquals(true, found_row_section_info);
	if !found_row_section_info return;

	row_audio_info, found_row_audio_info := GetTypeInfoEnumByName("RowSystemType", cd.all_type_info_enum);
	AssertEquals(true, found_row_audio_info);
	if !found_row_audio_info return;	

	// rs_type, found_rs_type := GetArrayType(cd, *row_section_info.info, ArrayInfoType.FIXED, 1);
	// AssertEquals(true, found_rs_type);
	// if !found_rs_type return;

	var_index : int;
	vars_equal := TestNextManyVarDecl(*var_index, cd.all_variables, .[
		VarDecl("rs", row_section_info, RamMem(.sbp,0)),
		VarDecl("rd", row_data_info, RamMem(.sbp,row_section_info.runtime_size)),
	]);
	if !vars_equal return;
	rs_var := cd.all_variables[0];
	rd_var := cd.all_variables[1];

	rs_0, rs_1 := GetMemoryAddressAsOperands(rs_var.op);

	stack_p : int = rs_var.t_info.runtime_size + rd_var.t_info.runtime_size;

	instr_index : int = 0;
	TestNextManyInstr(*instr_index, cd, .[
		//rs : RowSectionData;
		MakeMI(.mset, rs_var.op, Imm(0), Imm(row_section_info.runtime_size)),
		//TODO Could grab the struct member info directly and use that for offsets here instead.
		MakeMI(.mov, rs_var.op, Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8, rs_var.op), Imm(0), Imm(cd.int_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(16, rs_var.op), Imm(12), Imm(cd.int_type_info.runtime_size)),

		//rd : RowData;
		MakeMI(.mset, rd_var.op, Imm(0), Imm(row_data_info.runtime_size)),
		MakeMI(.mov, rd_var.op, FImm(12.0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(8, rd_var.op), FImm(12.0), Imm(cd.float_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(24, rd_var.op), Imm(cast(int) false), Imm(cd.bool_type_info.runtime_size)),
		MakeMI(.mov, AddOperandOffset(32, rd_var.op), ImmEnum(RowSystemType.internal_pitch), Imm(row_audio_info.runtime_size)),
		//row_sections fixed array added to stack
		MakeMI(.mov, RamMem(.sbp,stack_p), rs_var.op, Imm(rs_var.t_info.runtime_size)),
		//TODO REDUNDANT INSTRUCTION NEED TO CHECK WHY AND OPTIMIZE OUT
		MakeMI(.mov, RamMem(.sbp,stack_p), RamMem(.sbp,stack_p), Imm(rs_var.t_info.runtime_size)),
		//row_sections.count
		MakeMI(.mov, AddOperandOffset(56, rd_var.op), Imm(1), Imm(cd.int_type_info.runtime_size)),
		//row_sections.data
		MakeMI(.add, AddOperandOffset(64, rd_var.op), RegMem(.sbp), Imm(stack_p)),

		MakeMI(.create_row, rd_var.op),

		MakeMI(.exit),
	]);

	//Commenting this check out so we don't fail right away when adding new things to library.
	//We can uncomment them if we want to remind us to test new Library functions and data here.
	// AssertEquals(instr_index, cd.all_music_instructions.count);

} @UnitTest

//TODO CAn move all array parsing tests in here so we can see them all in 1 place. 
//There are some in Test_Parser right now.
//Also can separate this into Test_ParseArrayType and Test_ParseArrayData or something but maybe that's not necessary.
Test_ParseArray :: () {
	ptd := MakeParseTestData();

	/*
	  	  :     	    
	   /	 \   
	  af     * 
	         \
	          [
	        /   \
	     float   ]
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "af : *[] float;");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "af")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");

	/*
	  	  :     	    
	   /	 \   
	  af     * 
	         \
	          [
	        /   \
	     float   +
	            / \
	           2   10
	*/	
	array_reset_keeping_memory(*ptd.cd.lexer.lexer_tokens);
	LexCodeTokens(*ptd.cd.lexer, "af : *[2+10] float;");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "af")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 10)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");

	/*
            [
           / \
          [   1
         / \
     munit  +
           / \
          x   y
	*/	
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "munit[x+y][1]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "["), .BINARY_OP), 
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.DATA_MUNIT, "munit")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*
			  +
		  /    \
		 [      [
		/ \    / \
	  x   0  x   1
		      
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "x[0] + x[1]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	//Array Declaration Test
	/*
			  [
         /   \
		  *  	  +
		   \	  / \
		  int  1   3
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "[1+3] *int");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 3)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);



	/*
		  [
		 / \
	float	 ]
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "[] float");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);



	/*
				 [	
   			/ \
   		  [  ..
   		 / \
   		[   2
   	  / \
   	int  ]
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "[..][2][] int");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DOUBLE_DOT)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);



	/*
         .[
        /  \
      int   ]
	*/	
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "int.[];");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	//Test Here to make sure we close the [] brackets properly
	//and can still continue parsing properly.
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(node.value.token_type, #char ";");


	/*
         .[
        /  \
      int   ,
           / \
          ,   2
         / \
        0   1
	*/	
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "int.[0,1,2]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*
	    +
     /   \
    x    .[
        /   \
      int     ,
             / \
            ,   2
         /    \
        +      +
       / \    / \
      0   y  1   z
	*/	
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "x + int.[0+y,1/z,2]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,

		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),

		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,

		BNode(LCToken(#char "/"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,

		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*
          =
        /    \
       :      .[
      / \    /   \
     a   [  int   ,
        / \      / \
      int  ]    ,   7
               / \
              0   3 
	*/	
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "a : [] int = int.[0,3,7];");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .DATA_TYPE_INFO),
		BNode(LCToken(.DATA_TYPE_INT, "int")),  NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")),  NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 3)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 7)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);



	/*
         .[
        /   \
      int    ,
      	  /   \
         .[	   .[
        / \    / \
      int  , int  ,
          / \    / \
         +   1  ,   4
        / \    / \
       x   y  2   3
	*/	
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "int.[int.[x+y,1],int.[2,3,4]]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 3)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 4)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/* s.x[a[0]]
		  .
		 / \
		s   [
		   / \
		  x   [
		     / \
		    a   0
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "s.x[a[0]]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "."), .BINARY_OP),
		BNode(LCToken(.IDENT, "s")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*
     .[
      \
       ,
      / \
     0   1
	*/	
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, ".[0,1]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.ARRAY_LITERAL), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*TEST struct literal inside array literal inside struct literal
		      .[
			 /    \
		 other      ,
		        /     \
             .[       .[
           /    \    /   \
         int     ]  int   ,
                         /  \
                         0   1
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "other.[int.[], int.[0,1]]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		//neume.[]
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "other")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		//int.[]
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
		//int.[] with values
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*TEST struct literal inside array literal inside struct literal
		      .[
			 /    \
		 neume      ,
		        /     \
             .{       .{
           /    \    /   \
       neume     ,  neume  }
              /   \
             ,     1.0
           /   \
          ,     0.0
        /   \
      1.0    2
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "neume.[neume.{1.0,2,0.0,1.0}, neume.{}]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		//neume.[]
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.FLOAT, 1.0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 0.0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 1.0)), NULL_NODE, NULL_NODE,
		//neume.{}
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*TEST struct literal inside array literal inside struct literal
		      .[
			 /     \
		 test      .{
				   /    \
				test     }
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "test.[test.{}]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		//test.[]
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		//test.{}
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*TEST struct literal inside array literal inside struct literal
		      .[
			 /     \
		 test       ,
		        /      \
           .{        .{  
          /  \     /    \
        test  } test        ,
                        /      \
                       .[       .{
                     /   \    /     \
                  int     1  other   ,
                                   /  \
                                 1.0   .[
                                      /   \
                                     a2    ]
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "test.[test.{}, test.{int.[1],other.{1.0, a2.[]}}]");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		//test.[]
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		//test.{}
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,
		//test.{} with values
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "other")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.FLOAT, 1.0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "a2")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "]")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

} @UnitTest

Test_ParseStruct :: () {
	ptd := MakeParseTestData();

	/*
		.
	  / \
	 x   a
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "x.a");
	node := ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "."), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*
		     .
			 / \
			.   b
		  / \
		 x   a
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "x.a.b");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(#char "."), .BINARY_OP),
		BNode(LCToken(#char "."), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "b")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/*
		     .{
			 /   \
		 Test    }
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "Test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*
		     .{
			 /   \
		 Test    ,
				 /   \
            ,    "test"
          /   \
         0    1.3
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{0,1.3,\"test\"}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "Test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 1.3)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.STRING, "test")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*
		     .{
			 /   \
		 Test    ,
				 /    \
            ,      =
         /    \   /  \
        =      =  s   "test"
       / \   /   \
      x   + test  1.3
         / \
        y   1
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{x=y+1,test=1.3,s=\"test\"}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "Test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 1.3)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(.IDENT, "s")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.STRING, "test")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*
		     .{
			 /    \
		 Test      ,
				 /      \
            ,        =
         /    \     /  \
        x      +   s   .{
        	    /  \     /   \
            y   1.3  t     }
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{x,y+1.3,s=t.{}}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "Test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 1.3)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(.IDENT, "s")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "t")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*TEST array literal inside struct literal
		     .{
			 /   \
		 Test    ,
				 /   \
            0    .[
                /   \
            float    ,
                   /   \
                 1.2   3.4
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{0,float.[1.2,3.4]}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "Test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.FLOAT, 1.2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 3.4)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*TEST struct literal inside array literal inside struct literal
		      .{
			 /    \
		 Test     ,
		        /   \
             .[    0
           /    \
       neume      ,
              /      \
            .{         .{
           /  \      /    \
        neume  ,   neume   }
              /  \
             ,     1.0
           /   \
          ,     0.0
        /   \
      1.0    2
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{neume.[neume.{1.0,2,0.0,1.0}, neume.{}], 0}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "Test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		//neume.[]
		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		//neume.{} with values
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.FLOAT, 1.0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 0.0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 1.0)), NULL_NODE, NULL_NODE,
		//neume.{}
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.KEYWORD_NEUME, "neume")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,

		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/*TEST struct literal inside array literal inside struct literal
		      .[
			 /     \
		 test       ,
		        /      \
           .{        .{  
          /  \     /    \
        test  } test        ,
                        /      \
                       .[       .{
                     /   \    /     \
                  int     1  other   ,
                                   /  \
                                 1.0   .[
                                      /   \
                                     a2    ]
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	// LexCodeTokens(*ptd.cd.lexer, "test.[test.{1}, test.{1}]");
	LexCodeTokens(*ptd.cd.lexer, "test.{}, test.{}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		//test.[]
		// BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		// BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		//test.{}
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		// BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,
		//test.{}
		BNode(LCToken(.STRUCT_LITERAL), .BINARY_OP),
		BNode(LCToken(.IDENT, "test")), NULL_NODE, NULL_NODE,
		// BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	/* TODO I am testing this case but if we don't do struct literal inference
	   then we can likely remove this eventually altogether.
	     .{
		    \
	        }
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, ".{}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.STRUCT_LITERAL), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "}")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);

	/* TODO I am testing this case but if we don't do struct literal inference
	   then we can likely remove this eventually altogether.
	     .{
	     	 \
		     ,
 		   /   \
        ,    "test"
      /   \
    0    1.3
	*/
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, ".{0,1.3,\"test\"}");
	node = ParseExpression(ptd.cd, S64_MIN);

	array_reset_keeping_memory(*ptd.ordered_nodes);
	DFSPreWithNull(node, *ptd.ordered_nodes, GetOrderedNodesWithNull);
	ptd.expected_nodes = BinaryNode.[
		BNode(LCToken(.STRUCT_LITERAL), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 1.3)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.STRING, "test")), NULL_NODE, NULL_NODE,
	];
	TestNodes(ptd.expected_nodes, ptd.ordered_nodes);


	//ERROR TEST CASES
	// INVALID UNARY COMMA
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{,x}");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(1, ptd.cd.comp_errors.all_compiler_errors.count);
	array_reset_keeping_memory(*ptd.cd.comp_errors.all_compiler_errors);

	//INVALID UNARY EQUALS
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{=x}");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(1, ptd.cd.comp_errors.all_compiler_errors.count);
	array_reset_keeping_memory(*ptd.cd.comp_errors.all_compiler_errors);


	// INVALID NO VALUE AFTER COMMA
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{x=,}");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(1, ptd.cd.comp_errors.all_compiler_errors.count);
	array_reset_keeping_memory(*ptd.cd.comp_errors.all_compiler_errors);


	//TODO This should fail with the compiler since "}" will not have a type
	#if 0 {
	// INVALID NO VALUE AFTER COMMA
	ResetCodeLexer(*ptd.cd.lexer);
	LexCodeTokens(*ptd.cd.lexer, "Test.{x,}");
	node = ParseExpression(ptd.cd, S64_MIN);
	AssertEquals(1, ptd.cd.comp_errors.all_compiler_errors.count);
	array_reset_keeping_memory(*ptd.cd.comp_errors.all_compiler_errors);
	}

} @UnitTest

//TODO Can replace data_type here with something else once we have full data types.
//TODO IS this NoNull really better. Then well have a bunch of errors when really there's only 1.
//In this case we see all the tests that failed. In the other one we only see 1...
TestVarDecl :: inline (node : *BinaryNode, name : string, data_type : CodeTokenType) {
	AssertNotEquals(null, node);
	no_null := NoNull(node);
	AssertEquals(cast(CodeTokenType) #char ":", no_null.value.token_type);

	AssertNotEquals(null, no_null.left);	
	no_null_left := NoNull(no_null.left);
	AssertEquals(CodeTokenType.IDENT, no_null_left.value.token_type);
	AssertEquals(name, no_null_left.value.token_string);

	AssertNotEquals(null, no_null.right);
	AssertEquals(data_type, NoNull(no_null.right).value.token_type);
}

//TODO Move all the array parsing tests in here or make a few
//array parsing tests if needed. Or do we want all parsing in the same
//function?
//TODO MAYBE MAKING THE TESTING TREE PARSE WOULD BE A GOOD IDEA NOW?
//OR MAYBE WHEN WE CHANGE THE ":" structure for declarations?

/*TODO Technically to verify a tree uniqueness, we would have to do in and post order traversal.
This is an argument for making the ascii parse, so that then we could parse it both ways for each
and compare both post and in order traversal
Check dfs below to see that we need post and in order traversals.
https://en.wikipedia.org/wiki/Tree_traversal
*/

//TODO Add assertion testing.
Test_Parser :: () {
	ordered_nodes : [..] *BinaryNode;
	ordered_nodes.allocator = unit_test_alloc;
	expected_tokens : [] LCodeToken;
	expected_nodes : [] BinaryNode;

	//TODO Could Separate these out into separate functions
	//TODO Should test this expression in Test_Lexer first and then use here
	//so we can tell the difference between a lexer and a parser error.
	/*
	     >
	    / \
  	   1   +
  	      / \
  	     +   9
  	    / \
  	   3   *
  	      / \
  	     5   7
	*/
	cd := MakeCompilationData(,,unit_test_alloc);
	node : *BinaryNode;
	LexCodeTokens(*cd.lexer, "1 > 3 + 5 * 7 + 9");
	// LexCodeTokens(*cd.lexer, "1 > 5 * 7 + 9");
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(#char ">", cast(int) node.value.token_type);

	AssertEquals(CodeTokenType.INTEGER, node.left.value.token_type);
	AssertEquals(1, node.left.value.int_value);
	AssertEquals(#char "+", cast(int) node.right.value.token_type);

	AssertEquals(#char "+", cast(int) node.right.left.value.token_type);
	AssertEquals(CodeTokenType.INTEGER, node.right.right.value.token_type);
	AssertEquals(9, node.right.right.value.int_value);

	AssertEquals(CodeTokenType.INTEGER, node.right.left.left.value.token_type);
	AssertEquals(3, node.right.left.left.value.int_value);
	AssertEquals(#char "*", cast(int) node.right.left.right.value.token_type);

	AssertEquals(CodeTokenType.INTEGER, node.right.left.right.left.value.token_type);
	AssertEquals(5, node.right.left.right.left.value.int_value);
	AssertEquals(CodeTokenType.INTEGER, node.right.left.right.right.value.token_type);
	AssertEquals(7, node.right.left.right.right.value.int_value);




	/*
            *
           / \
          +   2
         / \
        x   3
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "(x+3)*2");
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "*", node.value.token_type);

	AssertEquals(CodeTokenType.INTEGER, node.right.value.token_type);
	AssertEquals(2, node.right.value.int_value);
	AssertEquals(cast(CodeTokenType) #char "+", node.left.value.token_type);

	AssertEquals(CodeTokenType.IDENT, node.left.left.value.token_type);
	AssertEquals("x", node.left.left.value.token_string);
	AssertEquals(CodeTokenType.INTEGER, node.left.right.value.token_type);
	AssertEquals(3, node.left.right.value.int_value);




	/*
            >
           / \
          1   +
             / \
            2   y
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "1 > (2 + y)");
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ">", node.value.token_type);

	AssertEquals(CodeTokenType.INTEGER, node.left.value.token_type);
	AssertEquals(1, node.left.value.int_value);
	AssertEquals(cast(CodeTokenType) #char "+", node.right.value.token_type);

	AssertEquals(CodeTokenType.INTEGER, node.right.left.value.token_type);
	AssertEquals(2, node.right.left.value.int_value);
	AssertEquals(CodeTokenType.IDENT, node.right.right.value.token_type);
	AssertEquals("y", node.right.right.value.token_string);



	//TODO Can write tests for all of these eventually
	// LexCodeTokens(*cd.lexer, "foo(x+1,2*(y+2))");
	// LexCodeTokens(*cd.lexer, "foo((y+2),x)");
	// LexCodeTokens(*cd.lexer, "foo(2*(y+2),x)");
	// LexCodeTokens(*cd.lexer, "foo(y,x)");
	// LexCodeTokens(*cd.lexer, "foo(x)");
	// LexCodeTokens(*cd.lexer, "f1(f2(x),f3(x))");
	// LexCodeTokens(*cd.lexer, "a[f1(x)]");
	/*
            [
           / \
          [   1
         / \
        a   0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "a[0][1]");
	node = ParseExpression(cd, S64_MIN);
	#if 0 {
	AssertEquals(cast(CodeTokenType) #char "[", node.value.token_type);

	AssertEquals(cast(CodeTokenType) #char "[", node.left.value.token_type);
	AssertEquals(CodeTokenType.INTEGER, node.right.value.token_type);
	AssertEquals(1, node.right.value.int_value);

	AssertEquals(CodeTokenType.IDENT, node.left.left.value.token_type);
	AssertEquals("a", node.left.left.value.token_string);
	AssertEquals(CodeTokenType.INTEGER, node.left.right.value.token_type);
	AssertEquals(0, node.left.right.value.int_value);
	}




	/*
            (
           / \
         foo  +
             / \
            x   1
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "foo(x+1)");
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "(", node.value.token_type);

	AssertEquals(CodeTokenType.IDENT, node.left.value.token_type);
	AssertEquals("foo", node.left.value.token_string);
	AssertEquals(cast(CodeTokenType) #char "+", node.right.value.token_type);

	AssertEquals(CodeTokenType.IDENT, node.right.left.value.token_type);
	AssertEquals("x", node.right.left.value.token_string);
	AssertEquals(CodeTokenType.INTEGER, node.right.right.value.token_type);
	AssertEquals(1, node.right.right.value.int_value);



	/*
   	    =
   	   / \ 
   	  :   true
   	/  \   
     b  bool
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "b : bool = true;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "b")),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_BOOL, "bool")),
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TRUE, "true"))
		];
	TestNodes(expected_nodes, ordered_nodes);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

} @UnitTest

Test_ParseOps :: () {
	ordered_nodes : [..] *BinaryNode;
	ordered_nodes.allocator = unit_test_alloc;
	expected_nodes : [] BinaryNode;
	cd := MakeCompilationData(,,unit_test_alloc);
	node : *BinaryNode;

	/*
   	    :=
   	   / \ 
   	  y   +
   	     / \ 
          x   1
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "y := x + 1;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "y")),
		BNode(LCToken(.COLON_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")),
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1))
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

	/*
   	   %
	     / \   
	    x   12
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "x % 12");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "%"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 12)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
	   -
       \   
        1
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "-1");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
	   -
       \   
        +
         \
          -
           \
            x
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "-+-x");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "+"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
	      -
       /  \   
      y    +
            \
             -
              \
               x
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "y-+-x");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
			  =
       /      \
      :        -
     / \      /  \
    i  int   y    -
                  \
                   -
                    \
                    +
                     \
                      +
                       \
                       -
                       \
                       +
                       \
                       -
                       \
                       x
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "i : int = y - --++-+-x;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "-"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "+"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "+"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "+"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	not_null : bool = AssertEquals(true, node != null);
	if not_null {
		AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);
	}

	/*
	    -
     /  \   
    1   (
       /  \
     foo   0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "1-foo(0)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
	    -
        \   
        (
       /  \
     foo   0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "-foo(0)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);



	/*
	   +=
     /  \   
    x    1
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "x += 1;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.PLUS_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

	/*
	   %=
     /  \   
    x    12.
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "x %= 12.;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.MOD_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 12.)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	/*
	   -=
     /  \   
    x    +
        / \
       y   1
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "x -= y + 1;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.MINUS_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	/*
	   <=
     /  \   
    i    2
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "i <= 2");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.LESS_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
	   =
	 /   \
	b    <=
       /  \   
      i    2
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "b = i <= x;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(.IDENT, "b")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.LESS_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	// node = ParseExpression(cd, S64_MIN);
	// AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


} @UnitTest

Test_ParsePointer :: () {
	ordered_nodes : [..] *BinaryNode;
	ordered_nodes.allocator = unit_test_alloc;
	expected_nodes : [] BinaryNode;
	cd := MakeCompilationData(,,unit_test_alloc);
	node : *BinaryNode;


	/* ***x
		*
		 \
		  *
		   \
		    *
		     \
		      x
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "***x");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/* ***int
		*
		 \
		  *
		   \
		    *
		     \
		      int
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "***int");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/* p : **int = **i;
		   =
		 /   \
		:     *
	  / \	    \
    p	  *     *
		   \     \
		    *     i
		     \
		     int
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "p : **int = **i;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "p")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.IDENT, "i")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	//TODO These tests should be more concise for prices examples like separate x[0] as one test
	//and then *x as another. And then also have some aggregate tests like this one.
	/* *x[0]
		*
		 \
		  [
		 / \
		x   0
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "*x[0]");
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.IDENT, "p")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);


	/* *x[y+1].a 
		     *
		      \
			    .
			   / \
		     [   a
		    / \
		   x   +
		      / \
           y   1
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "*x[y+1].a");
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "."), .BINARY_OP),
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);




	//TODO Test once we remove adding the ; with new linearized data format.
	//TODO Do we want ; on top of tree or no?
	//Can see if we split up tree into statements and declarations
	//instead of one giant nodeary tree like we have now
	/* y : *int = *x
		     =
		  /     \
		 :       +
	   / \     / \
	  y   *    *  1
	       \    \
	       int   x
	*/
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "y : *int = *x + 1;");
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,

		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(#char "*"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(true, node != null);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	/*
   	      +
   	     / \
   	    .   1
   	   / \ 
   	 .*   a
   	 /
      x
	*/	
	ResetCodeLexer(*cd.lexer);
	// LexCodeTokens(*cd.lexer, "x.*.a + y.*.b");
	LexCodeTokens(*cd.lexer, "x.*.a + 1");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(#char "."), .BINARY_OP),
		BNode(LCToken(.POSTFIX_DEREFERENCE), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE, 
		NULL_NODE,
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
   	    .
   	   / \ 
   	  t   .*
   	      /
   	     p
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "t.p.*");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "."), .BINARY_OP),
		BNode(LCToken(.IDENT, "t")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.POSTFIX_DEREFERENCE), .BINARY_OP),
		BNode(LCToken(.IDENT, "p")), NULL_NODE, NULL_NODE,
		NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
   	    +
   	   / \ 
   	  .*  .
   	 /   / \
   	.*  .*  .*
     /   /   /
    p   p   a
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "p.*.* + p.*.a.*");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.POSTFIX_DEREFERENCE), .BINARY_OP),
		BNode(LCToken(.POSTFIX_DEREFERENCE), .BINARY_OP),
		BNode(LCToken(.IDENT, "p")), NULL_NODE, NULL_NODE,
		NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "."), .BINARY_OP),
		BNode(LCToken(.POSTFIX_DEREFERENCE), .BINARY_OP),
		BNode(LCToken(.IDENT, "p")), NULL_NODE, NULL_NODE,
		NULL_NODE,
		BNode(LCToken(.POSTFIX_DEREFERENCE), .BINARY_OP),
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,		
		NULL_NODE
	];
	TestNodes(expected_nodes, ordered_nodes);


	/*
   	    [
   	   / \ 
   	  .*  p
   	 /    
   	t    
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "t.*[p]");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.POSTFIX_DEREFERENCE), .BINARY_OP),
		BNode(LCToken(.IDENT, "t")), NULL_NODE, NULL_NODE,
		NULL_NODE,
		BNode(LCToken(.IDENT, "p")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

} @UnitTest

//TODO Add tests for if and while here as well.
//Can add inline statements here or separate test as well.
Test_ParseControl :: () {
	cd := MakeCompilationData(,,unit_test_alloc);
	node : *BinaryNode;

	ordered_nodes : [..] *BinaryNode;
	ordered_nodes.allocator = unit_test_alloc;
	expected_nodes : [] BinaryNode;

	//TODO Should add for loop parsing test for < and * too
	//and then check ForLoopData is set properly
	/*
   	   for
	        \
		     ..
		   /   \
	     +     (
	    / \   /  \
	   [   1 foo  ,
	  / \        / \
    x   0      +   b
              / \
             a   2
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "for x[0]+1..foo(a+2,b) {}");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_FOR, "for"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DOUBLE_DOT), .BINARY_OP),
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(#char "["), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.IDENT, "foo")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "b")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	AssertEquals(1, cd.all_for_loop_data.count);
	array_reset_keeping_memory(*cd.all_for_loop_data);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);


	//TODO Should add for loop parsing test for < and * too
	//and then check ForLoopData is set properly
	/*
   	   for
	        \
		     ..
		   /   \
	     +     *
	    / \   /  \
	   x   y 2    a
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "for x+y..2*a {}");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_FOR, "for"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.DOUBLE_DOT), .BINARY_OP),
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "*"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 2)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	AssertEquals(1, cd.all_for_loop_data.count);
	array_reset_keeping_memory(*cd.all_for_loop_data);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);


	/*
   	   for
	        \
		      a
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "for * < x,y : a {}");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_FOR, "for"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(.IDENT, "a")), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	count_equals := AssertEquals(1, cd.all_for_loop_data.count);
	if count_equals {
		AssertEquals(true, cd.all_for_loop_data[0].is_reverse);
		AssertEquals(true, cd.all_for_loop_data[0].is_pointer);
		AssertEquals("x", cd.all_for_loop_data[0].value_name);
		AssertEquals("y", cd.all_for_loop_data[0].index_name);
	}
	array_reset_keeping_memory(*cd.all_for_loop_data);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);


	/*
	     if
	       \
           ==
          /  \
         x    0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "if x == 0 {} else if x < 1 {} else {}");
	
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_IF, "if"), .UNARY_OP),
		BNode(LCToken(.IDENT, "x")),
		BNode(LCToken(.IS_EQUAL), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)),
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);

	/*
	   else
        \
	     if
	       \
           <
          /  \
         x    1
	*/	
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_ELSE, "else"), .UNARY_OP),
		BNode(LCToken(.KEYWORD_IF, "if"), .UNARY_OP),
		BNode(LCToken(.IDENT, "x")),
		BNode(LCToken(#char "<"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)),
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);

	node = ParseExpression(cd, S64_MIN);
	AssertEquals(CodeTokenType.KEYWORD_ELSE, node.value.token_type);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "{", node.value.token_type);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char "}", node.value.token_type);


	//Inline control structures (old structure, keeping here for remembering)
	//Now we split up the control structures per control statement
	/*			   while
				/         \
	       if           <
	    /     \        /  \
     for      ==     y    2
       \     /  \
        a   x    0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "for < x,y : a if x == 0 while y < 2 z = 3;");
	
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_FOR, "for"), .UNARY_OP),
		BNode(LCToken(.IDENT, "a")),
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*			   
	   if           
	     \
        ==
       /  \
      x    0
	*/	
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_IF, "if"), .UNARY_OP),
		BNode(LCToken(.IDENT, "x")),
		BNode(LCToken(.IS_EQUAL), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)),
	];
	TestNodes(expected_nodes, ordered_nodes);

	/* 
		while
	     \
	      <
	     /  \
       y    2
	*/	
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_WHILE, "while"), .UNARY_OP),
		BNode(LCToken(.IDENT, "y")),
		BNode(LCToken(#char "<"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 2)),
	];
	TestNodes(expected_nodes, ordered_nodes);

	//Parse the z=3 inline statement and then check for ";"
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.IDENT, "z")),
		BNode(LCToken(#char "="), .BINARY_OP),
		BNode(LCToken(.INTEGER, 3)),
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);


	/*
	       if
	    /     \
     for      ==
       \     /  \
        ..  x    0
       /  \
      0   10
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "for 0..10 if x == 0");
	
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_FOR, "for"), .UNARY_OP),
		BNode(LCToken(.INTEGER, 0)),
		BNode(LCToken(.DOUBLE_DOT), .BINARY_OP),
		BNode(LCToken(.INTEGER, 10)),
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
		if
		  \
   	  ==
   	 /  \
   	x    0
	*/
	node = ParseExpression(cd, S64_MIN);
	array_reset_keeping_memory(*ordered_nodes);
	DFSIn(node, *ordered_nodes, GetOrderedNodes);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.KEYWORD_IF, "if"), .UNARY_OP),
		BNode(LCToken(.IDENT, "x")),
		BNode(LCToken(.IS_EQUAL), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)),
	];
	TestNodes(expected_nodes, ordered_nodes);


} @UnitTest

Test_ParseTano :: () {
	cd := MakeCompilationData(,,unit_test_alloc);
	node : *BinaryNode;

	ordered_nodes : [..] *BinaryNode;
	ordered_nodes.allocator = unit_test_alloc;
	expected_nodes : [] BinaryNode;

	/*
		       (
		     /    \
	    tano      ,
	          /      \
	         :        .. 
	        / \      /   \
          0   x   10.0   +
                        / \
                       f   1
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "tano(0:x,10.0..f+1)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DOUBLE_DOT), .BINARY_OP),
		BNode(LCToken(.FLOAT, 10.0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "f")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
			   =		  
       /         \  
		:           (
  	 /   \  	    /    \
	t    tano  tano     ,
	                 /     \
	                :       .. 
	               / \     /   \
                 0   x  10.0   +
                              / \
                             f   1
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "t : tano = tano(0:x,10.0..f+1);");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "="), .BINARY_OP),

		//LHS
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "t")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,

		//RHS
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.DOUBLE_DOT), .BINARY_OP),
		BNode(LCToken(.FLOAT, 10.0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(.IDENT, "f")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
		        ~=
		     /       \
		    (         (
		   /  \     /   \
	   tano   ,  tano     ,
	         / \       /     \    
	        0   x     ..      :
	                 /  \    / \
	                1    x  y   5.0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "tano(0,x) ~= tano(1..x,y:5.0);");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.TILDE_EQUALS), .BINARY_OP),

		//LHS
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,

		//RHS
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.DOUBLE_DOT), .BINARY_OP),
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.IDENT, "x")), NULL_NODE, NULL_NODE,

		BNode(LCToken(#char ":"), .BINARY_OP),
		BNode(LCToken(.IDENT, "y")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 5.0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
		           ~=
		     /          \
		    (            -       
		   /  \       /    \       
	   tano   ,     12     ( 
	         / \         /    \    
	        0   1      tano    ,
	                          / \
	                         0   0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "tano(0,1) ~= 12 - tano(0,0);");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.TILDE_EQUALS), .BINARY_OP),

		//LHS
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,

		//RHS
		BNode(LCToken(#char "-"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 12)), NULL_NODE, NULL_NODE,

		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);


	/*
		           ~=
		     /            \
		    (              %       
		   /  \         /    \       
	   tano   ,        (     12
	         / \     /    \    
	        0   1  tano    ,
	                      / \
	                     0   0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "tano(0,1) ~= tano(0,0) % 12;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.TILDE_EQUALS), .BINARY_OP),

		//LHS
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,

		//RHS
		BNode(LCToken(#char "%"), .BINARY_OP),

		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,

		BNode(LCToken(.INTEGER, 12)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
		   -
		    \
		    (           
		   /  \ 
	   tano   ,     
	         / \    
	        0   0     
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "-tano(0,0)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "-"), .UNARY_OP), NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
		    (           
		   /  \ 
	   tano  +,+     
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "tano(+,+)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.ADD_COMMA_ADD)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
			:=
        /   \
		 t     (           
		      /  \ 
	      tano  +,+     
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "t := tano(+,-);");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.COLON_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "t")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.ADD_COMMA_SUB)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

	/*
			:=
        /   \
       t     +
            /  \
		     (    1         
		    /  \ 
	    tano  -,+     
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "t := tano(-,+) + 1;");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.COLON_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "t")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "+"), .BINARY_OP),
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.SUB_COMMA_ADD)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 1)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);

	/*
			:=
        /   \
		 t     -
		      /  \
		 	  12 	 (
		         /  \ 
	         tano  -,-
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "t := 12 - tano(-,-);");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(.COLON_EQUALS), .BINARY_OP),
		BNode(LCToken(.IDENT, "t")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "-"), .BINARY_OP),
		BNode(LCToken(.INTEGER, 12)), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(.SUB_COMMA_SUB)), NULL_NODE, NULL_NODE,

	];
	TestNodes(expected_nodes, ordered_nodes);
	node = ParseExpression(cd, S64_MIN);
	AssertEquals(cast(CodeTokenType) #char ";", node.value.token_type);




	/*
			   ~
        /      \
		  (       .[
		/  \      /  \
	tano	 ,	  int   ,
		  /  \       /  \ 
	    0    0     7   11
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "tano(0,0) ~ int.[7,11]");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "~"), .BINARY_OP),
		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,

		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_INT, "int")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 7)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 11)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);

	/*
			 ~
       /    \
	  .[       (
	  /  \    /  \
 float  ,  tano  ,
	    /  \     / \
	   1.  2.   0   0
	*/	
	ResetCodeLexer(*cd.lexer);
	LexCodeTokens(*cd.lexer, "float.[1.,2.] ~ tano(0,0)");
	node = ParseExpression(cd, S64_MIN);

	array_reset_keeping_memory(*ordered_nodes);
	DFSPreWithNull(node, *ordered_nodes, GetOrderedNodesWithNull);
	expected_nodes = BinaryNode.[
		BNode(LCToken(#char "~"), .BINARY_OP),

		BNode(LCToken(.ARRAY_LITERAL), .BINARY_OP),
		BNode(LCToken(.DATA_TYPE_FLOAT, "float")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.FLOAT, 1.0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.FLOAT, 2.0)), NULL_NODE, NULL_NODE,

		BNode(LCToken(#char "("), .BINARY_OP),
		BNode(LCToken(.KEYWORD_TANO, "tano")), NULL_NODE, NULL_NODE,
		BNode(LCToken(#char ","), .BINARY_OP),
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
		BNode(LCToken(.INTEGER, 0)), NULL_NODE, NULL_NODE,
	];
	TestNodes(expected_nodes, ordered_nodes);


} @UnitTest

//TODO Could have a few separate lexer tests if that is useful.
Test_Lexer :: () {
	cl := MakeCodeLexer();


	LexCodeTokens(*cl, "10.05");
	AssertEquals(1, cl.lexer_tokens.count);
	lt := cl.lexer_tokens;
	TestToken(lt[0], .FLOAT, 10.05, 5);


	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "9645");
	AssertEquals(1, cl.lexer_tokens.count);
	lt = cl.lexer_tokens;
	TestToken(lt[0], .INTEGER, 9645, 4);


	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "x : int = 10;");
	AssertEquals(6, cl.lexer_tokens.count);
	lt = cl.lexer_tokens;
	TestToken(lt[0], .IDENT, "x");
	TestToken(lt[1], #char ":");
	TestToken(lt[2], .DATA_TYPE_INT);
	TestToken(lt[3],  #char "=");
	TestToken(lt[4], .INTEGER, 10, 2);
	TestToken(lt[5], #char ";");



	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "x : float = 3.14159;");
	AssertEquals(6, cl.lexer_tokens.count);
	lt = cl.lexer_tokens;
	TestToken(lt[0], .IDENT, "x");
	TestToken(lt[1], #char ":");
	TestToken(lt[2], .DATA_TYPE_FLOAT);
	TestToken(lt[3],  #char "=");
	TestToken(lt[4], .FLOAT, 3.14159, 7);
	TestToken(lt[5], #char ";");




	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "munit[x][0]");
	AssertEquals(7, cl.lexer_tokens.count);
	lt = cl.lexer_tokens;
	TestToken(lt[0], .DATA_MUNIT);
	TestToken(lt[1], #char "[");
	TestToken(lt[2], .IDENT, "x");
	TestToken(lt[3],  #char "]");
	TestToken(lt[4],  #char "[");
	TestToken(lt[5], .INTEGER, 0, 1);
	TestToken(lt[6], #char "]");


	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "int.[x,10]");
	AssertEquals(6, cl.lexer_tokens.count);
	lt = cl.lexer_tokens;
	TestToken(lt[0], .DATA_TYPE_INT);
	TestToken(lt[1], .ARRAY_LITERAL);
	TestToken(lt[2], .IDENT, "x");
	TestToken(lt[3],  #char ",");
	TestToken(lt[4], .INTEGER, 10, 2);
	TestToken(lt[5], #char "]");


	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "#asm");
	AssertEquals(1, cl.lexer_tokens.count);
	lt = cl.lexer_tokens;
	TestToken(lt[0], #char "#", cast(int) CodeDirective.asm);


	ResetCodeLexer(*cl);
	LexCodeTokens(*cl,
#string DONE
main :: () {
#asm {
mov ax, 1;
}
}
DONE,,unit_test_alloc);

	TestManyTokens(cl.lexer_tokens, .[
		LCToken(.IDENT, "main"),
		LCToken(.DOUBLE_COLON),
		LCToken(#char "("),
		LCToken(#char ")"),
		LCToken(#char "{"),
		LCToken(#char "#", cast(int) CodeDirective.asm),
		LCToken(#char "{"),
		LCToken(.IDENT, "mov"),
		LCToken(.IDENT, "ax"),
		LCToken(#char ","),
		LCToken(.INTEGER, 1),
		LCToken( #char ";"),
		LCToken( #char "}"),
		LCToken( #char "}")
	]);

	/*
	x : int = 2;
	if x == 2 {
	
	}
	
	mov rbp+0 2
	ceq x 2

	if x == 2 then y += 1;
	*/

	/*for x : munit[0][0] {
		y : int = 3;
	}
	*/
	#if 0 {
	//Regul

	//TODO Could do each one
	// "munit[0][0] = int.[x,x+4,x+7];"
	// "mem[0][0] = int.[];"
	// "lane[0][0] = int.[];"

	// Foo :: (i : int) {

	// }
	}
} @UnitTest

Test_LexString :: () {
	cl := MakeCodeLexer();

	LexCodeTokens(*cl, "\"test a string\"");
	AssertEquals(1, cl.lexer_tokens.count);
	lt := cl.lexer_tokens;
	TestToken(lt[0], .STRING, "test a string");

	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "\"test with newline\n\"");
	AssertEquals(1, cl.lexer_tokens.count);
	lt = cl.lexer_tokens;
	TestToken(lt[0], .STRING, "test with newline\n");

	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "\"test no end quote");
	AssertEquals(1, cl.lexer_errors.all_compiler_errors.count);

} @UnitTest

Test_LexBracket :: () {
	cl := MakeCodeLexer();

	LexCodeTokens(*cl, "main :: () {#asm{}");
	AssertEquals(1, cl.lexer_errors.all_compiler_errors.count);
	AssertEquals(1, cl.bracket_stack.count);

	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "main :: ( {#asm{}}");
	AssertEquals(1, cl.lexer_errors.all_compiler_errors.count);
	AssertEquals(1, cl.bracket_stack.count);

	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "main :: () #asm{}}");
	AssertEquals(1, cl.lexer_errors.all_compiler_errors.count);

	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "main :: () { #asm { [ } }");
	AssertEquals(1, cl.lexer_errors.all_compiler_errors.count);
	AssertEquals(2, cl.bracket_stack.count);

} @UnitTest

Test_LexComments :: () {
	cl := MakeCodeLexer();

	//TEST : Nested block comments should work
	LexCodeTokens(*cl, "main :: () {/*test/* 2 */*/}");
	AssertEquals(6, cl.lexer_tokens.count);
	AssertEquals(CodeTokenType.IDENT, cl.lexer_tokens[0].token_type);
	AssertEquals(CodeTokenType.DOUBLE_COLON, cl.lexer_tokens[1].token_type);
	AssertEquals(cast(CodeTokenType) (#char "("), cl.lexer_tokens[2].token_type);
	AssertEquals(cast(CodeTokenType) (#char ")"), cl.lexer_tokens[3].token_type);
	AssertEquals(cast(CodeTokenType) (#char "{"), cl.lexer_tokens[4].token_type);
	AssertEquals(cast(CodeTokenType) (#char "}"), cl.lexer_tokens[5].token_type);
	AssertEquals(0, cl.bracket_stack.count);

	//TEST : Comment within block comment should work
	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "main :: () {/*test //2 */}");
	AssertEquals(6, cl.lexer_tokens.count);
	AssertEquals(0, cl.bracket_stack.count);

	//TEST : Comment within block comment should work
	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "main :: () {/*test //2 */}");
	AssertEquals(6, cl.lexer_tokens.count);
	AssertEquals(0, cl.bracket_stack.count);

	//TEST : This should error out out since we don't close the block comment
	ResetCodeLexer(*cl);
	LexCodeTokens(*cl, "main :: () {/*test}");
	AssertEquals(1, cl.lexer_errors.all_compiler_errors.count);
	AssertEquals(1, cl.bracket_stack.count);

	//TEST : This should error out out since we don't open the bracket
	//NOTE THIS ERRORS OUT in the compiler and is tested below in Test_CompileComments
	// ResetCodeLexer(*cl);
	// LexCodeTokens(*cl, "main :: () {test*/}");
	// AssertEquals(1, cl.lexer_errors.all_compiler_errors.count);
	// AssertEquals(1, cl.bracket_stack.count);


} @UnitTest

Test_CompileComments :: () {
	cs : CompileSettings;
	cd : *CompilationData;
	count_equal : bool;

	//TEST compile nested block comments should work
	cd = CompileCode(.{print_errors_to_console=false},
#string DONE
main :: () {	
  /*
  x : int = 5;
  /*(*x + 1).* */= 10;
  */
}
DONE,, unit_test_alloc);
	AssertEquals(0, cd.comp_errors.all_compiler_errors.count);

	//TEST Regular comment should work
	reset(*unit_test_alloc_pool, true);
	cd = CompileCode(cs,
#string DONE
//regular comment
main :: () {
}
DONE,, unit_test_alloc);
	AssertEquals(0, cd.comp_errors.all_compiler_errors.count);

	//TEST Should fail because only have close block comment
	reset(*unit_test_alloc_pool, true);
	cd = CompileCode(cs,
#string DONE
main :: () {
	*/
}
DONE,, unit_test_alloc);
	AssertEquals(1, cd.comp_errors.all_compiler_errors.count);


} @UnitTest

/*TODO Could also allow testing with an array. This is pretty clear for now though.
This should simplify all lexer tests now.
*/
TestToken :: inline (token : LCodeToken, expected_type : CodeTokenType, expected_value : string) {
	TestToken(token, expected_type, .{token_string=expected_value}, expected_value.count);
}
TestToken :: inline (token : LCodeToken, expected_type : CodeTokenType, expected_value : int, length : int = 0) {
	TestToken(token, expected_type, .{int_value=expected_value}, length);
}
TestToken :: inline (token : LCodeToken, expected_type : CodeTokenType, expected_value : float64, length : int = 0) {
	TestToken(token, expected_type, .{float_value=expected_value}, length);
}
//TODO We could also just pass in an expected_token
TestToken :: inline (
	actual : LCodeToken, 
	expected_type : CodeTokenType, 
	expected_value : TokenValue = TokenValue.{},
	expected_length : int = 0) 
{
	expected : LCodeToken;
	expected.token_type = expected_type;
	expected.value = expected_value;
	expected.token_length = expected_length;
	TestToken(actual, expected);
}

TestToken :: inline (
	actual : LCodeToken,
	expected : LCodeToken)
{
	AssertEquals(expected.token_type, actual.token_type);
	//TODO Can remove this if causing problems. Will use later for compiler error output.
	if expected.token_length > 0 AssertEquals(expected.token_length, actual.token_length);
	if expected.token_type == {
	case .FLOAT; 
		AssertFloat64Equals(expected.value.float_value, actual.float_value);
	case #char "#"; #through;
	case .INTEGER;
		AssertEquals(expected.value.int_value, actual.int_value);
	case .STRING; #through;
	case .IDENT;
		AssertEquals(expected.value.token_string, actual.token_string);
	}
}

TestManyTokens :: inline (actual_tokens : [] LCodeToken, expected_tokens : [] LCodeToken) {
	equal_count : bool = AssertEquals(expected_tokens.count, actual_tokens.count);
	if equal_count for expected_token : expected_tokens {
		TestToken(actual_tokens[it_index], expected_token);
	}
}

//TODO test some invalid instructions with errors
//and that the error is correct. We could have an error enum
//for translation later...
//TODO Could have a test for ValidateOperandTypes instead here
//but it is good to have a few here for testing it through instruction execution.
/*This could be replace with a specific test for ValidateMusicOperand
and ValidateMusicInstruction if needed or when those errors are stabilized.
Right now this way allows 
*/
Test_CPUError :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	ci : MusicInstruction;
	err : CPUError;

	//TODO We can check for error message strings here if we pull out and generalize the messages

	ci = Instr(.mov, RegMem(.ax), RamMem(-10), d=ad);
	err = ExecMInstr(ci, ad);
	AssertEquals(true, err.is_error);

	ci = Instr(.mov, RegMem(.ax), RamMem(ad.ram_memory.bytes.count), d=ad);
	err = ExecMInstr(ci, ad);
	AssertEquals(true, err.is_error);

	ci = Instr(.mov, MusicMem(0,-1), Imm(1), d=ad);
	err = ExecMInstr(ci, ad);
	AssertEquals(true, err.is_error);

	row_size : int = ad.global_rules.row_size;
	row_count : int = ad.all_mspace_data[0].all_music_lane_rows.count;

	ci = Instr(.mov, MusicMem(0,row_size * row_count), Imm(1), d=ad);
	err = ExecMInstr(ci, ad);
	AssertEquals(true, err.is_error);

	ci = Instr(.mov, MusicMem(row_count, row_size), Imm(1), d=ad);
	err = ExecMInstr(ci, ad);
	AssertEquals(true, err.is_error);

	ci = Instr(.mov, MusicMem(-1, -1), Imm(1), d=ad);
	err = ExecMInstr(ci, ad);
	AssertEquals(true, err.is_error);
} @UnitTest

//Not sure how many tests I want in here in case we change some instructions
//later to have more cases. Just good to have so we run through the function
//and make sure it's working as intended for a few cases.
Test_ValidInstr :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);

	ci := Instr(.mov, Imm(1), Imm(1), d=ad);
	err := ValidateMusicInstruction(ci);
	AssertEquals(true, err.is_error);

	ci = Instr(.and, RamMem(0,1), MusicMem(0,0), d=ad);
	err = ValidateMusicInstruction(ci);
	AssertEquals(true, err.is_error);

	ci = Instr(.rol, Imm(0), d=ad);
	err = ValidateMusicInstruction(ci);
	AssertEquals(true, err.is_error);

	ci = Instr(.tjmp, MusicMem(0,0), d=ad);
	err = ValidateMusicInstruction(ci);
	AssertEquals(true, err.is_error);

} @UnitTest

Test_Mov :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	ci : MusicInstruction;

	//TODO Should do tests here for errors as well and start returning
	//appropriate error values.

	//TODO Do a test for each possible single instruction case scenario.
	//Can use @ITest for scenarios where we change multiple datas.

	//Register and int tests
	i1 : int = 789;
	ci = Instr(.mov, RegMem(.ax), Imm(i1), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(i1, ad.all_register_memory[RegDef.ax].int_value);

	ci = Instr(.mov, RegMem(.bx), RegMem(.ax), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(i1, ad.all_register_memory[RegDef.bx].int_value);


	//Register and float tests
	f1 : float64 = 3.14159;
	ci = Instr(.mov, RegMem(.ax), FImm(f1), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(f1, ad.all_register_memory[RegDef.ax].float_value);

	ci = Instr(.mov, RegMem(.bx), RegMem(.ax), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(f1, ad.all_register_memory[RegDef.bx].float_value);

	//TODO Could do this directly with the assembler once its tested.
	// MInstr("mov [0] %");
	//Having both methods is best though

	//RamMem Tests
	t2 : int = 3;
	ci = Instr(.mov, RamMem(0), Imm(t2), d=ad);
	ExecMInstr(ci, ad);
	//TODO Need a function here, check remedy to see if memcpy or casting yields better asm.
	//They are all similary so make a fetch function here that can also check the bounds possibly
	//and can fetch by a passed in compile-time type.
	AssertEquals(t2, GetMemValue(0, int, ad.ram_memory));

	//TODO Where should we put the 8. Maybe keep a default size in AllData.
	ci = Instr(.mov, RamMem(8), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(t2, GetMemValue(8, int, ad.ram_memory));

	//RamMem with addition tests
	ci = Instr(.mov, RegMem(.cmu), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, RamMem(.cmu,16), RamMem(.cmu,8), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(t2, GetMemValue(16, int, ad.ram_memory));


	//Ram float tests
	f2 : float64 = 2.71828;
	ci = Instr(.mov, RamMem(0), FImm(f2), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(f2, GetMemValue(0, float64, ad.ram_memory));

	ci = Instr(.mov, RamMem(8), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(f2, GetMemValue(8, float64, ad.ram_memory));

	ci = Instr(.mov, RamMem(16), RamMem(0), Imm(16), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(f2, GetMemValue(16, float64, ad.ram_memory));
	AssertFloat64Equals(f2, GetMemValue(24, float64, ad.ram_memory));
} @UnitTest

Test_MovMusic :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	//TODO Should we allow array types in asm... I think so for flexibility for now and ease.
	//Also for set operations we would need to.
	ci = Instr(.mov, MusicMem(0,0), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,0), Imm(4), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,0), Imm(7), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,4,7], GetAllMusicPtPosByPosition(0,0,ad.all_mspace_data[0].all_music_pts));


	ci = Instr(.mov, MusicMem(0,1), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	//TODO Do we want to make a separate function. Should we just do MInstr and CreateFloatInstr?
	ci = FInstr(.mov, MusicMem(0,1), FImm(5.5), d=ad);
	ci = FInstr(.mov, MusicMem(0,1), FImm(5.5), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,1), Imm(9), d=ad);
	ExecMInstr(ci, ad);

	AssertArrayEquals(float64.[0,5.5,9], GetAllMusicPtFloat(0,1,ad.all_mspace_data[0].all_music_pts));


	ci = Instr(.mov, MusicMem(0,2), MusicMem(0,0), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,4,7], GetAllMusicPtFloat(0,2,ad.all_mspace_data[0].all_music_pts));

	//TODO mov_size with float range do we want up to and not including or including?
	ci = Instr(.mov, MusicMem(0,3), MusicMem(0,1), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,5.5,9], GetAllMusicPtFloat(0,3,ad.all_mspace_data[0].all_music_pts));
	AssertArrayEquals(float64.[0,4,7], GetAllMusicPtFloat(0,4,ad.all_mspace_data[0].all_music_pts));

	ci = Instr(.mov, MusicMem(0,5), MusicMem(0,4), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,4,7], GetAllMusicPtFloat(0,5,ad.all_mspace_data[0].all_music_pts));
	AssertArrayEquals(float64.[], GetAllMusicPtFloat(0,6,ad.all_mspace_data[0].all_music_pts));


	a_int := int.[0,3,7,11];
	c1, d1 := PushRAMArray(a_int, *ad.ram_memory);
	ci = Instr(.mov, MusicMem(0,6), RamArray(c1,d1), d=ad);
	ExecMInstr(ci, ad);
	//TODO Eventually we might remove this int get since music_pts may
	//only have float since we can round to int with a float64
	AssertArrayEquals(a_int, GetAllMusicPtPosByPosition(0,6,ad.all_mspace_data[0].all_music_pts));

	a_float := float64.[0.5,3.5,7.1,11.2];
	c2, d2 := PushRAMArray(a_float, *ad.ram_memory);
	ci = FInstr(.mov, MusicMem(0,7), RamArray(c2,d2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(a_float, GetAllMusicPtFloat(0,7,ad.all_mspace_data[0].all_music_pts));

} @UnitTest

Test_MovMusicXFloat :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	ci = Instr(.mov, MusicMem(0,0.5), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,0.5), Imm(4), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,0.5), Imm(7), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[], GetAllMusicPtFloat(0,0,ad.all_mspace_data[0].all_music_pts));
	AssertArrayEquals(float64.[0,4,7], GetAllMusicPtFloat(0,0.5,ad.all_mspace_data[0].all_music_pts));

	ci = FInstr(.mov, RamMem(0), FImm(0.5), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.mov, MusicMem(0,1.75), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.mov, RegMem(.ax), FImm(5.5), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.mov, MusicMem(0,1.75), RegMem(.ax), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0.5,5.5], GetAllMusicPtFloat(0,1.75,ad.all_mspace_data[0].all_music_pts));

	
	ci = Instr(.mov, MusicMem(0,4.5), MusicMem(0,0.5), FImm(1.5), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,4,7], GetAllMusicPtFloat(0,4.5,ad.all_mspace_data[0].all_music_pts));
	AssertArrayEquals(float64.[0.5,5.5], GetAllMusicPtFloat(0,5.75,ad.all_mspace_data[0].all_music_pts));

} @UnitTest

Test_ConstMov :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	ad.comp_data = MakeCompilationData();
	ci : MusicInstruction;

	test_string : string = "test";
	test_address : int = AddConstantMemory(test_string.data, test_string.count, 
		*ad.comp_data.constant_memory);

	ci = Instr(.const_mov, RamMem(0), Imm(test_address), Imm(test_string.count), d=ad);
	ExecMInstr(ci, ad);
	ram_string : string;
	ram_string.data = GetMemPtr(0, u8, ad.ram_memory);
	ram_string.count = test_string.count;
	AssertEquals(test_string, ram_string);

	second_ram_address : int = 16;
	second_test : string = "second";
	second_address : int = AddConstantMemory(second_test.data, second_test.count, 
		*ad.comp_data.constant_memory);

	ci = Instr(.const_mov, RamMem(second_ram_address), Imm(second_address), Imm(second_test.count), d=ad);
	ExecMInstr(ci, ad);
	ram_string.data = GetMemPtr(second_ram_address, u8, ad.ram_memory);
	ram_string.count = second_test.count;
	AssertEquals(second_test, ram_string);

} @UnitTest


Test_TMov :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	t0 := tano.{x_start=0,x_end=1};
	t0_address := PushRAMValue(t0, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(t0_address), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.tmov, RamMem(t0_address), Imm(4), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.tmov, RamMem(t0_address), Imm(7), d=ad);
	ExecMInstr(ci, ad);

	AssertArrayEquals(float64.[0,4,7], GetAllMusicPtFloat(t0.row_start,t0.x_start,ad.all_mspace_data[0].all_music_pts));
	t0_music_pts := GetAllMusicPtPosByPosition(t0.row_start, t0.x_start, ad.all_mspace_data[0].all_music_pts, MusicPoint);
	for t0_music_pts {
		AssertEquals(t0.row_start, it.row_index);
		AssertEquals(t0.row_end, it.row_index);
		AssertFloat64Equals(t0.x_start, it.x_start_float);
		AssertFloat64Equals(t0.x_end, it.x_end_float);
	}

	t1 := tano.{x_start=1.75,x_end=2.25};
	t1_address := PushRAMValue(t1, *ad.ram_memory);
	ci = FInstr(.tmov, RamMem(t1_address), FImm(0.5), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.mov, RegMem(.ax), FImm(5.5), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.tmov, RamMem(t1_address), RegMem(.ax), d=ad);
	ExecMInstr(ci, ad);

	AssertArrayEquals(float64.[0.5,5.5], GetAllMusicPtFloat(t1.row_start,t1.x_start,ad.all_mspace_data[0].all_music_pts));
	t1_music_pts := GetAllMusicPtPosByPosition(t1.row_start, t1.x_start, ad.all_mspace_data[0].all_music_pts, MusicPoint);
	for t1_music_pts {
		AssertEquals(t1.row_start, it.row_index);
		AssertEquals(t1.row_end, it.row_index);
		AssertFloat64Equals(t1.x_start, it.x_start_float);
		AssertFloat64Equals(t1.x_end, it.x_end_float);
	}



	t2 := tano.{x_start=6,x_end=7};
	t2_address := PushRAMValue(t2, *ad.ram_memory);
	a_int := int.[0,3,7,11];
	c1, d1 := PushRAMArray(a_int, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(t2_address), RamArray(c1,d1), d=ad);
	ExecMInstr(ci, ad);
	t2_music_pts := GetAllMusicPtPosByPosition(t2.row_start, t2.x_start, ad.all_mspace_data[0].all_music_pts, MusicPoint);
	for t2_music_pts {
		AssertFloat64Equals(cast(float64) a_int[it_index], it.music_pt_float);
		AssertEquals(t2.row_start, it.row_index);
		AssertEquals(t2.row_end, it.row_index);
		AssertFloat64Equals(t2.x_start, it.x_start_float);
		AssertFloat64Equals(t2.x_end, it.x_end_float);
	}

	t3 := tano.{x_start=7,x_end=8};
	t3_address := PushRAMValue(t3, *ad.ram_memory);
	a_float := float64.[0.5,3.5,7.1,11.2];
	c2, d2 := PushRAMArray(a_float, *ad.ram_memory);
	ci = FInstr(.tmov, RamMem(t3_address), RamArray(c2,d2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(a_float, GetAllMusicPtFloat(t3.row_start,t3.x_start,ad.all_mspace_data[0].all_music_pts));
	t3_music_pts := GetAllMusicPtPosByPosition(t3.row_start, t3.x_start, ad.all_mspace_data[0].all_music_pts, MusicPoint);
	for t3_music_pts {
		AssertEquals(t3.row_start, it.row_index);
		AssertEquals(t3.row_end, it.row_index);
		AssertFloat64Equals(t3.x_start, it.x_start_float);
		AssertFloat64Equals(t3.x_end, it.x_end_float);
	}

	extra_a := float64.[12.7,13.14];
	c3, d3 := PushRAMArray(extra_a, *ad.ram_memory);
	ci = FInstr(.tmov, RamMem(t3_address), RamArray(c3,d3), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0.5,3.5,7.1,11.2,12.7,13.14], GetAllMusicPtFloat(t3.row_start,t3.x_start,ad.all_mspace_data[0].all_music_pts));
	t3_music_pts = GetAllMusicPtPosByPosition(t3.row_start, t3.x_start, ad.all_mspace_data[0].all_music_pts, MusicPoint);
	for t3_music_pts {
		AssertEquals(t3.row_start, it.row_index);
		AssertEquals(t3.row_end, it.row_index);
		AssertFloat64Equals(t3.x_start, it.x_start_float);
		AssertFloat64Equals(t3.x_end, it.x_end_float);
	}




	t4 := tano.{x_start=8,x_end=9};
	t4_address := PushRAMValue(t4, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(t4_address), RamMem(t2_address), d=ad);
	ExecMInstr(ci, ad);
	t4_music_pts := GetAllMusicPtPosByPosition(t4.row_start, t4.x_start, ad.all_mspace_data[0].all_music_pts, MusicPoint);
	for t4_music_pts {
		AssertFloat64Equals(cast(float64) a_int[it_index], it.music_pt_float);
		AssertEquals(t4.row_start, it.row_index);
		AssertEquals(t4.row_end, it.row_index);
		AssertFloat64Equals(t4.x_start, it.x_start_float);
		AssertFloat64Equals(t4.x_end, it.x_end_float);
	}



	//TODO Could make a separate test for TMovMSpace if we need more cases later
	//Right now it is just for the stack so we leave it here
	t_mspace := tano.{0,0,3,4,1};
	tm_address := PushRAMValue(t_mspace, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(tm_address), RamMem(t2_address), d=ad);
	ExecMInstr(ci, ad);
	tm_neumes := GetAllMusicPtPosByPosition(0, 1, ad.tano_stack_music_pts, MusicPoint);
	AssertEquals(0, tm_neumes.count);
	tm_neumes = GetAllMusicPtPosByPosition(t_mspace.row_start, t_mspace.x_start, ad.tano_stack_music_pts, MusicPoint);
	for tm_neumes {
		AssertFloat64Equals(cast(float64) a_int[it_index], it.music_pt_float);
		AssertEquals(t_mspace.row_start, it.row_index);
		AssertEquals(t_mspace.row_end, it.row_index);
		AssertFloat64Equals(t_mspace.x_start, it.x_start_float);
		AssertFloat64Equals(t_mspace.x_end, it.x_end_float);
	}

} @UnitTest

//TODO Could put this other tests for tmov and tmov array if that is clearer
Test_TMovNeume :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	t0 := tano.{x_start=0,x_end=5};
	t0_address := PushRAMValue(t0, *ad.ram_memory);
	n0 := Neume.{4,0,0,2};
	n0_address := PushRAMValue(n0, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(t0_address), RamMem(n0_address), ImmEnum(TMovRamType.NEUME), d=ad);
	ExecMInstr(ci, ad);

	count_equal := AssertEquals(1, ad.all_mspace_data[0].all_music_pts.count);
	if !count_equal return;
	mp0 := ad.all_mspace_data[0].all_music_pts[0];
	AssertFloat64Equals(n0.svara, mp0.music_pt_float);
	AssertEquals(n0.row, mp0.row_index);
	AssertFloat64Equals(n0.x_start, mp0.x_start_float);
	AssertFloat64Equals(n0.x_end, mp0.x_end_float);


	neume_array := Neume.[.{0,0,1,2},.{4.5,0,2,4}];
	c3, d3 := PushRAMArray(neume_array, *ad.ram_memory);
	ci = FInstr(.tmov, RamMem(t0_address), RamArray(c3,d3), ImmEnum(TMovArrayType.NEUME), d=ad);
	ExecMInstr(ci, ad);

	count_equal = AssertEquals(3, ad.all_mspace_data[0].all_music_pts.count);
	if !count_equal return;
	mp1 := ad.all_mspace_data[0].all_music_pts[1];
	AssertFloat64Equals(neume_array[0].svara, mp1.music_pt_float);
	AssertEquals(neume_array[0].row, mp1.row_index);
	AssertFloat64Equals(neume_array[0].x_start, mp1.x_start_float);
	AssertFloat64Equals(neume_array[0].x_end, mp1.x_end_float);
	mp2 := ad.all_mspace_data[0].all_music_pts[2];
	AssertFloat64Equals(neume_array[1].svara, mp2.music_pt_float);
	AssertEquals(neume_array[1].row, mp2.row_index);
	AssertFloat64Equals(neume_array[1].x_start, mp2.x_start_float);
	AssertFloat64Equals(neume_array[1].x_end, mp2.x_end_float);


	//Reverse tano and check we are placing neumes starting from x_start > x_end and row_start > row_end
	t_rev := tano.{row_start=1,row_end=0,x_start=5,x_end=0};
	t_rev_address := PushRAMValue(t_rev, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(t_rev_address), RamMem(n0_address), ImmEnum(TMovRamType.NEUME), d=ad);
	ExecMInstr(ci, ad);

	count_equal = AssertEquals(4, ad.all_mspace_data[0].all_music_pts.count);
	if !count_equal return;
	mp_rev_0 := ad.all_mspace_data[0].all_music_pts[3];
	AssertFloat64Equals(n0.svara, mp_rev_0.music_pt_float);
	AssertEquals(t_rev.row_start, mp_rev_0.row_index);
	AssertFloat64Equals(t_rev.x_start-n0.x_end, mp_rev_0.x_start_float);
	AssertFloat64Equals(t_rev.x_start, mp_rev_0.x_end_float);

	ci = FInstr(.tmov, RamMem(t_rev_address), RamArray(c3,d3), ImmEnum(TMovArrayType.NEUME), d=ad);
	ExecMInstr(ci, ad);

	count_equal = AssertEquals(6, ad.all_mspace_data[0].all_music_pts.count);
	if !count_equal return;
	mp_rev_a1 := ad.all_mspace_data[0].all_music_pts[4];
	AssertFloat64Equals(neume_array[0].svara, mp_rev_a1.music_pt_float);
	AssertEquals(t_rev.row_start, mp_rev_a1.row_index);
	AssertFloat64Equals(t_rev.x_start-neume_array[0].x_end, mp_rev_a1.x_start_float);
	AssertFloat64Equals(t_rev.x_start-neume_array[0].x_start, mp_rev_a1.x_end_float);
	mp_rev_a2 := ad.all_mspace_data[0].all_music_pts[5];
	AssertFloat64Equals(neume_array[1].svara, mp_rev_a2.music_pt_float);
	AssertEquals(t_rev.row_start, mp_rev_a2.row_index);
	AssertFloat64Equals(t_rev.x_start-neume_array[1].x_end, mp_rev_a2.x_start_float);
	AssertFloat64Equals(t_rev.x_start-neume_array[1].x_start, mp_rev_a2.x_end_float);




	//TEST tano to neume array
	ta_settings : TanoToArraySettings;
	ta_settings.return_array_type = .NEUME;
	ta_settings_address := PushRAMValue(ta_settings, *ad.ram_memory);

	heap_address := ad.all_register_memory[RegDef.hcp].int_value;

	// neume_tano := MakeTano(0,0,cast(float64)f_start_x,cast(float64)(f_end_x+1));
	// neume_tano_address := PushRAMValue(neume_tano, *ad.ram_memory);
	//NOTE : The instruciton type here is what makes the return array float
	ci = CreateFloatInstr(.tmov, RamArray(0,0), RamMem(t0_address), RamMem(ta_settings_address), d=ad);
	ExecMInstr(ci, ad);

	na_count : int = GetMemValue(ta_settings_address, int,ad.ram_memory);
	AssertEquals(3, na_count);
	na_data : int = GetMemValue(ta_settings_address+8, int,ad.ram_memory);
	AssertEquals(heap_address, na_data);

	na_0 : Neume = GetMemValue(heap_address, Neume,ad.ram_memory);
	AssertFloat64Equals(n0.svara, na_0.svara);
	AssertEquals(n0.row, na_0.row);
	AssertFloat64Equals(n0.x_start, na_0.x_start);
	AssertFloat64Equals(n0.x_end, na_0.x_end);
	na_1 : Neume = GetMemValue(heap_address + size_of(Neume), Neume,ad.ram_memory);
	AssertFloat64Equals(neume_array[0].svara, na_1.svara);
	AssertEquals(neume_array[0].row, na_1.row);
	AssertFloat64Equals(neume_array[0].x_start, na_1.x_start);
	AssertFloat64Equals(neume_array[0].x_end, na_1.x_end);
	na_2 : Neume = GetMemValue(heap_address + 2*size_of(Neume), Neume,ad.ram_memory);
	AssertFloat64Equals(neume_array[1].svara, na_2.svara);
	AssertEquals(neume_array[1].row, na_2.row);
	AssertFloat64Equals(neume_array[1].x_start, na_2.x_start);
	AssertFloat64Equals(neume_array[1].x_end, na_2.x_end);

} @UnitTest

//TODO Continue this test a bit once we have base unit tests
//for TMovMusicPt working
Test_TMovRev :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	melody := int.[0,4,7];
	for 0..melody.count-1 {
		ci = Instr(.mov, MusicMem(0,it), Imm(melody[it]), d=ad);
		ExecMInstr(ci, ad);		
	}

	//TODO Could make functions for this MakeTano with different inputs
	t0 := tano.{row_start=0,row_end=0,x_start=0,x_end=3};
	t0_address := PushRAMValue(t0, *ad.ram_memory);
	trev := tano.{row_start=1,row_end=1,x_start=3,x_end=0};
	trev_address := PushRAMValue(trev, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(trev_address), RamMem(t0_address), d=ad);
	ExecMInstr(ci, ad);

	trev_music_pts := GetTanoMusicPts(trev, ad.all_mspace_data[0].all_music_pts, .X_REVERSE);
	AssertEquals(melody.count, trev_music_pts.count);
	for trev_music_pts {
		AssertFloat64Equals(it.music_pt_float, cast(float64) melody[it_index]);
		AssertEquals(it.row_index, trev.row_start);
		AssertFloat64Equals(it.x_start_float, trev.x_start - it_index - 1);
		AssertFloat64Equals(it.x_end_float, trev.x_end - it_index);
	}

	//TODO Check forward and reverse for multiple rows as well.

} //@UnitTest

Test_TMovMusicPt :: () {
	//TODO Could make functions for this MakeTano with different inputs
	from_tano := tano.{row_start=0,row_end=0,x_start=0,x_end=3};
	to_tano := tano.{0,0,6,9,0};
	mp := MakeMusicPoint(4.0,0,0,3);

	new_mp := TMovMusicPt(mp, from_tano, to_tano);
	AssertFloat64Equals(mp.music_pt_float, new_mp.music_pt_float);
	AssertEquals(to_tano.row_start, new_mp.row_index);
	AssertFloat64Equals(to_tano.x_start, new_mp.x_start_float);
	AssertFloat64Equals(to_tano.x_end, new_mp.x_end_float);

	//X Reverse
	mp = MakeMusicPoint(4.0,0,0,2);
	//TODO Could make a function for this RevXTano()
	to_tano = tano.{0,0,9,6,0};
	new_mp = TMovMusicPt(mp, from_tano, to_tano);
	AssertFloat64Equals(mp.music_pt_float, new_mp.music_pt_float);
	AssertEquals(to_tano.row_start, new_mp.row_index);
	AssertFloat64Equals(to_tano.x_start-Length(mp), new_mp.x_start_float);
	AssertFloat64Equals(to_tano.x_start, new_mp.x_end_float);


	//Multiple rows
	mp = MakeMusicPoint(4.0,1,1,5);
	//TODO Could make a function for this RevXTano()
	to_tano = tano.{0,0,6,9,0};
	new_mp = TMovMusicPt(mp, from_tano, to_tano);
	AssertFloat64Equals(mp.music_pt_float, new_mp.music_pt_float);
	AssertEquals(mp.row_index, new_mp.row_index);
	new_x_start : float64 = to_tano.x_start + mp.x_start_float;
	AssertFloat64Equals(new_x_start, new_mp.x_start_float);
	AssertFloat64Equals(new_x_start+Length(mp), new_mp.x_end_float);


	//Multiple rows reverse
	from_tano = tano.{0,0,0,3,0};
	mp = MakeMusicPoint(10.0,0,1,2);
	//TODO Could make a function for this RevRowTano()
	to_tano = tano.{2,0,6,9,0};
	new_mp = TMovMusicPt(mp, from_tano, to_tano);
	AssertFloat64Equals(mp.music_pt_float, new_mp.music_pt_float);
	AssertEquals(to_tano.row_start, new_mp.row_index);
	new_x_start = to_tano.x_start + mp.x_start_float;
	AssertFloat64Equals(new_x_start, new_mp.x_start_float);
	AssertFloat64Equals(new_x_start+Length(mp), new_mp.x_end_float);


	//TODO Multiple rows reverse and x reverse
	from_tano = tano.{0,0,0,3,0};
	mp = MakeMusicPoint(10.0,0,1,2);
	//TODO Could make a function for this RevRowTano()
	to_tano = tano.{2,0,6,9,0};
	new_mp = TMovMusicPt(mp, from_tano, to_tano);
	AssertFloat64Equals(mp.music_pt_float, new_mp.music_pt_float);
	AssertEquals(to_tano.row_start, new_mp.row_index);
	new_x_start = to_tano.x_start + mp.x_start_float;
	AssertFloat64Equals(new_x_start, new_mp.x_start_float);
	AssertFloat64Equals(new_x_start+Length(mp), new_mp.x_end_float);


	//from_tano offset
	from_tano = tano.{row_start=3,row_end=4,x_start=10,x_end=20};
	x_start_offset : float64 = 1;
	x_end_offset : float64 = 2.5;
	row_offset : int = 1;
	mp = MakeMusicPoint(4.0, from_tano.row_start+row_offset,
		from_tano.x_start+x_start_offset,
		from_tano.x_start+x_end_offset);
	to_tano = tano.{0,1,0,5,0};

	new_mp = TMovMusicPt(mp, from_tano, to_tano);
	AssertFloat64Equals(mp.music_pt_float, new_mp.music_pt_float);
	AssertEquals(to_tano.row_start+row_offset, new_mp.row_index);
	AssertFloat64Equals(to_tano.x_start+x_start_offset, new_mp.x_start_float);
	AssertFloat64Equals(to_tano.x_start+x_end_offset, new_mp.x_end_float);


	//from_tano reverse x offset
	from_tano = tano.{row_start=3,row_end=4,x_start=20,x_end=10};
	x_start_offset = 1;
	mp_length : float64 = 1.5;
	row_offset = 1;
	mp = MakeMusicPoint(4.0, from_tano.row_start+row_offset,
		//start > end
		from_tano.x_start-x_start_offset-mp_length,
		from_tano.x_start-x_start_offset);
	to_tano = tano.{0,1,0,5,0};

	new_mp = TMovMusicPt(mp, from_tano, to_tano);
	AssertFloat64Equals(mp.music_pt_float, new_mp.music_pt_float);
	AssertEquals(to_tano.row_start+row_offset, new_mp.row_index);
	AssertFloat64Equals(to_tano.x_start+x_start_offset, new_mp.x_start_float);
	AssertFloat64Equals(to_tano.x_start+x_start_offset+mp_length, new_mp.x_end_float);

	//from_tano reverse x and row test
	from_tano = tano.{row_start=6,row_end=3,x_start=20,x_end=10};
	x_start_offset = 1;
	mp_length = 1.5;
	row_offset = 2;
	mp = MakeMusicPoint(4.0, from_tano.row_start-row_offset,
		//start > end
		from_tano.x_start-x_start_offset-mp_length,
		from_tano.x_start-x_start_offset);
	to_tano = tano.{0,3,0,5,0};

	new_mp = TMovMusicPt(mp, from_tano, to_tano);
	AssertFloat64Equals(mp.music_pt_float, new_mp.music_pt_float);
	AssertEquals(to_tano.row_start+row_offset, new_mp.row_index);
	AssertFloat64Equals(to_tano.x_start+x_start_offset, new_mp.x_start_float);
	AssertFloat64Equals(to_tano.x_start+x_start_offset+mp_length, new_mp.x_end_float);

} @UnitTest

Test_TArith :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	t0 := tano.{x_start=0,x_end=1};
	t0_address := PushRAMValue(t0, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(t0_address), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.tmov, RamMem(t0_address), Imm(4), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.tmov, RamMem(t0_address), Imm(7), d=ad);
	ExecMInstr(ci, ad);


	ci = Instr(.mov, RegMem(.ax), Imm(1), d=ad);
	ci = Instr(.tadd, RamMem(t0_address), Imm(1), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[1,5,8], GetAllMusicPtFloat(t0.row_start,t0.x_start,ad.all_mspace_data[0].all_music_pts));

	ci = Instr(.tsub, Imm(12), RamMem(t0_address), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[11,7,4], GetAllMusicPtFloat(t0.row_start,t0.x_start,ad.all_mspace_data[0].all_music_pts));

	ci = Instr(.tmul, RamMem(t0_address), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[22,14,8], GetAllMusicPtFloat(t0.row_start,t0.x_start,ad.all_mspace_data[0].all_music_pts));

	ci = Instr(.tmul, Imm(2), RamMem(t0_address), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[44,28,16], GetAllMusicPtFloat(t0.row_start,t0.x_start,ad.all_mspace_data[0].all_music_pts));

	ci = Instr(.tdiv, RamMem(t0_address), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[22,14,8], GetAllMusicPtFloat(t0.row_start,t0.x_start,ad.all_mspace_data[0].all_music_pts));

	ci = Instr(.tmod, RamMem(t0_address), Imm(10), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[2,4,8], GetAllMusicPtFloat(t0.row_start,t0.x_start,ad.all_mspace_data[0].all_music_pts));


	a1 := int.[0,3,7];
	c1, d1 := PushRAMArray(a1, *ad.ram_memory);
	t1 := MakeTano(1,1,1,2);
	t1_address := PushRAMValue(t1, *ad.ram_memory);
	ci = Instr(.tmov, RamMem(t1_address), RamArray(c1,d1), d=ad);
	ExecMInstr(ci, ad);


	//Multi-row / multi-x test
	t2 := MakeTano(0,1,0,2);
	t2_address := PushRAMValue(t2, *ad.ram_memory);
	ci = Instr(.tadd, RamMem(t2_address), Imm(1), d=ad);
	ExecMInstr(ci, ad);
	t_mps := GetTanoMusicPts(t2, ad.all_mspace_data[0].all_music_pts);
	count_equals := AssertEquals(6, t_mps.count);
	if count_equals {
		AssertFloat64Equals(3, t_mps[0].music_pt_float);
		AssertFloat64Equals(0, t_mps[0].x_start_float);
		AssertEquals(0, t_mps[0].row_index);

		AssertFloat64Equals(5, t_mps[1].music_pt_float);
		AssertFloat64Equals(0, t_mps[1].x_start_float);
		AssertEquals(0, t_mps[1].row_index);

		AssertFloat64Equals(9, t_mps[2].music_pt_float);
		AssertFloat64Equals(0, t_mps[2].x_start_float);
		AssertEquals(0, t_mps[2].row_index);

		AssertFloat64Equals(1, t_mps[3].music_pt_float);
		AssertFloat64Equals(1, t_mps[3].x_start_float);
		AssertEquals(1, t_mps[3].row_index);

		AssertFloat64Equals(4, t_mps[4].music_pt_float);
		AssertFloat64Equals(1, t_mps[4].x_start_float);
		AssertEquals(1, t_mps[4].row_index);

		AssertFloat64Equals(8, t_mps[5].music_pt_float);
		AssertFloat64Equals(1, t_mps[5].x_start_float);
		AssertEquals(1, t_mps[5].row_index);
	}

} @UnitTest

//TODO FROM HERE write tests for .tshr and .trol before
//going back to add code.
//Can also implement return arrays to go array = tano
//We already have tano = array
Test_TShift :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	ci = Instr(.mov, MusicMem(0,0), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,1), Imm(4), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,2), Imm(7), d=ad);
	ExecMInstr(ci, ad);


	t0 := tano.{0,0,0,3,0};
	t0_address := PushRAMValue(t0, *ad.ram_memory);
	ci = Instr(.tshr, RamMem(t0_address), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(0, ad.all_mspace_data[0].all_music_pts[0].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[0].row_index);
	AssertFloat64Equals(2, ad.all_mspace_data[0].all_music_pts[0].x_start_float);
	AssertFloat64Equals(3, ad.all_mspace_data[0].all_music_pts[0].x_end_float);

	AssertFloat64Equals(4, ad.all_mspace_data[0].all_music_pts[1].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[1].row_index);
	AssertFloat64Equals(3, ad.all_mspace_data[0].all_music_pts[1].x_start_float);
	AssertFloat64Equals(4, ad.all_mspace_data[0].all_music_pts[1].x_end_float);

	AssertFloat64Equals(7, ad.all_mspace_data[0].all_music_pts[2].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[2].row_index);
	AssertFloat64Equals(4, ad.all_mspace_data[0].all_music_pts[2].x_start_float);
	AssertFloat64Equals(5, ad.all_mspace_data[0].all_music_pts[2].x_end_float);


	t1 := MakeTano(0,0,0,5);
	t1_address := PushRAMValue(t1, *ad.ram_memory);
	ci = Instr(.tshl, RamMem(t1_address), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(0, ad.all_mspace_data[0].all_music_pts[0].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[0].row_index);
	AssertFloat64Equals(0, ad.all_mspace_data[0].all_music_pts[0].x_start_float);
	AssertFloat64Equals(1, ad.all_mspace_data[0].all_music_pts[0].x_end_float);

	AssertFloat64Equals(4, ad.all_mspace_data[0].all_music_pts[1].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[1].row_index);
	AssertFloat64Equals(1, ad.all_mspace_data[0].all_music_pts[1].x_start_float);
	AssertFloat64Equals(2, ad.all_mspace_data[0].all_music_pts[1].x_end_float);

	AssertFloat64Equals(7, ad.all_mspace_data[0].all_music_pts[2].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[2].row_index);
	AssertFloat64Equals(2, ad.all_mspace_data[0].all_music_pts[2].x_start_float);
	AssertFloat64Equals(3, ad.all_mspace_data[0].all_music_pts[2].x_end_float);


	//Reminder : t0 = tano.{0,0,0,3};
	ci = Instr(.tror, RamMem(t0_address), Imm(1), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(0, ad.all_mspace_data[0].all_music_pts[0].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[0].row_index);
	AssertFloat64Equals(1, ad.all_mspace_data[0].all_music_pts[0].x_start_float);
	AssertFloat64Equals(2, ad.all_mspace_data[0].all_music_pts[0].x_end_float);

	AssertFloat64Equals(4, ad.all_mspace_data[0].all_music_pts[1].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[1].row_index);
	AssertFloat64Equals(2, ad.all_mspace_data[0].all_music_pts[1].x_start_float);
	AssertFloat64Equals(3, ad.all_mspace_data[0].all_music_pts[1].x_end_float);

	AssertFloat64Equals(7, ad.all_mspace_data[0].all_music_pts[2].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[2].row_index);
	AssertFloat64Equals(0, ad.all_mspace_data[0].all_music_pts[2].x_start_float);
	AssertFloat64Equals(1, ad.all_mspace_data[0].all_music_pts[2].x_end_float);


	//Reminder : t0 = tano.{0,0,0,3};
	ci = Instr(.trol, RamMem(t0_address), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(0, ad.all_mspace_data[0].all_music_pts[0].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[0].row_index);
	AssertFloat64Equals(2, ad.all_mspace_data[0].all_music_pts[0].x_start_float);
	AssertFloat64Equals(3, ad.all_mspace_data[0].all_music_pts[0].x_end_float);

	AssertFloat64Equals(4, ad.all_mspace_data[0].all_music_pts[1].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[1].row_index);
	AssertFloat64Equals(0, ad.all_mspace_data[0].all_music_pts[1].x_start_float);
	AssertFloat64Equals(1, ad.all_mspace_data[0].all_music_pts[1].x_end_float);

	AssertFloat64Equals(7, ad.all_mspace_data[0].all_music_pts[2].music_pt_float);
	AssertEquals(0, ad.all_mspace_data[0].all_music_pts[2].row_index);
	AssertFloat64Equals(1, ad.all_mspace_data[0].all_music_pts[2].x_start_float);
	AssertFloat64Equals(2, ad.all_mspace_data[0].all_music_pts[2].x_end_float);

} @UnitTest

//TODO Should we rename this Test_TMovToArray?
Test_TanoToArray :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	//TEST tano to int array
	chord := int.[0,4,7];
	ci = Instr(.mov, MusicMem(0,0), Imm(chord[0]), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,1), Imm(chord[1]), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,2), Imm(chord[2]), d=ad);
	ExecMInstr(ci, ad);

	//NOTE : We push this on directly now for convenience since we move the array after anyways
	//Leaving here in case we want to remember that we could do it this way and push more values on the stack later if needed.
	//Push on the return array
	// array_count_address := PushRAMValue(0, *ad.ram_memory);
	// array_data_address := PushRAMValue(0, *ad.ram_memory);

	//Push on TanoToArraySettings for the tano to array instruction
	t2a_settings : TanoToArraySettings;
	// t2a_settings.return_address = 0;
	t2a_settings.return_array_type = .DEFAULT;
	settings_address := PushRAMValue(t2a_settings, *ad.ram_memory);

	from_tano := MakeTano(0,0,0,3);
	tano_address := PushRAMValue(from_tano, *ad.ram_memory);
	ci = Instr(.tmov, RamArray(0,0), RamMem(tano_address), RamMem(settings_address), d=ad);
	ExecMInstr(ci, ad);

	array_count : int = GetMemValue(settings_address, int,ad.ram_memory);
	AssertEquals(3, array_count);

	array_data : int = GetMemValue(settings_address+8, int,ad.ram_memory);
	hsp_value : int = ad.all_register_memory[RegDef.hsp].int_value;
	AssertEquals(hsp_value, array_data);

	chord_0 : int = GetMemValue(hsp_value, int,ad.ram_memory);
	AssertEquals(chord[0], chord_0);
	chord_1 : int = GetMemValue(hsp_value + size_of(int), int,ad.ram_memory);
	AssertEquals(chord[1], chord_1);
	chord_2 : int = GetMemValue(hsp_value + 2*size_of(int), int,ad.ram_memory);
	AssertEquals(chord[2], chord_2);

	

	//TEST tano to float array
	chord_f := float64.[0.5,12.6,7.1];
	f_start_x : int = 5;
	f_end_x : int = 7;
	for f_start_x..f_end_x {
		chord_value : float64 = chord_f[it-f_start_x];
		ci = CreateFloatInstr(.mov, MusicMem(0,it), FImm(chord_value), d=ad);
		ExecMInstr(ci, ad);
	}

	//NOTE : We push this on directly now for convenience since we move the array after anyways
	//Leaving here in case we want to remember that we could do it this way and push more values on the stack later if needed.
	//Push on the return array
	// fa_count_address := PushRAMValue(0, *ad.ram_memory);
	// fa_data_address := PushRAMValue(0, *ad.ram_memory);

	//Push on TanoToArraySettings for the tano to array instruction
	float_settings : TanoToArraySettings;
	// float_settings.return_address = fa_count_address;
	float_settings.return_array_type = .DEFAULT;
	float_settings_address := PushRAMValue(float_settings, *ad.ram_memory);

	float_heap_address := ad.all_register_memory[RegDef.hcp].int_value;

	float_tano := MakeTano(0,0,cast(float64)f_start_x,cast(float64)(f_end_x+1));
	float_tano_address := PushRAMValue(float_tano, *ad.ram_memory);
	//NOTE : The instruciton type here is what makes the return array float
	ci = CreateFloatInstr(.tmov, RamArray(0,0), RamMem(float_tano_address), RamMem(float_settings_address), d=ad);
	ExecMInstr(ci, ad);

	fa_count : int = GetMemValue(float_settings_address, int,ad.ram_memory);
	AssertEquals(3, fa_count);
	fa_data : int = GetMemValue(float_settings_address+8, int,ad.ram_memory);
	AssertEquals(float_heap_address, fa_data);

	cf_0 : float64 = GetMemValue(float_heap_address, float64,ad.ram_memory);
	AssertFloat64Equals(chord_f[0], cf_0);
	cf_1 : float64 = GetMemValue(float_heap_address + size_of(float64), float64,ad.ram_memory);
	AssertFloat64Equals(chord_f[1], cf_1);
	cf_2 : float64 = GetMemValue(float_heap_address + 2*size_of(float64), float64,ad.ram_memory);
	AssertFloat64Equals(chord_f[2], cf_2);

} @UnitTest

//TODO Should I split this up for each operation. What if we add floating point instructions separately?
Test_Arithmetic :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	ci : MusicInstruction;

	//TODO More 2 operand tests and also MUSIC_MEMORY tests
	ci = Instr(.add, RegMem(.amu), Imm(1), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.amu].int_value);

	ci = Instr(.add, RegMem(.amu), RegMem(.amu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(2, ad.all_register_memory[RegDef.amu].int_value);

	ci = Instr(.add, RegMem(.bmu), RegMem(.amu), Imm(25), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(27, ad.all_register_memory[RegDef.bmu].int_value);

	ci = Instr(.sub, RegMem(.cmu), RegMem(.bmu), RegMem(.amu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(25, ad.all_register_memory[RegDef.cmu].int_value);

	ci = Instr(.add, RamMem(0), Imm(1000), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1000, GetMemValue(0,int,ad.ram_memory));

	ci = Instr(.sub, RamMem(8), RamMem(0), RegMem(.bmu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(973, GetMemValue(8,int,ad.ram_memory));

	ci = Instr(.mul, RamMem(16), RamMem(0), RamMem(8), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(973000, GetMemValue(16,int,ad.ram_memory));

	ci = Instr(.add, RamMem(24), RegMem(.amu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(2, GetMemValue(24,int,ad.ram_memory));

	//TEST 2 op integer division ( 8 / 2 == 4)
	ci = Instr(.div, RamMem(32), Imm(8), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(4, GetMemValue(32,int,ad.ram_memory));

	//TEST 1 op integer division ( 4 / amu(2) == 2)
	ci = Instr(.div, RamMem(32), RegMem(.amu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(2, GetMemValue(32,int,ad.ram_memory));

	//TEST float division (4/2 == 2)
	ci = FInstr(.div, RamMem(32), FImm(4), FImm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(2, GetMemValue(32,float64,ad.ram_memory));

	//TEST float division (2/2 == 1)
	ci = FInstr(.div, RamMem(32), FImm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(1, GetMemValue(32,float64,ad.ram_memory));

} @UnitTest


//TODO Should probably test each arithmetic operation here and all 3 cases for each.
//Maybe we should make a test for each operation in this case since its 3 large cases per operation.
Test_ArithmeticMusic :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	//TODO Should probably split these up into cases so we can specifically write what each one does.
	ci = Instr(.mov, MusicMem(0,0), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,0), Imm(4), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,0), Imm(7), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,4,7], GetAllMusicPtPosByPosition(0,0,ad.all_mspace_data[0].all_music_pts));

	ci = Instr(.add, MusicMem(0,1), MusicMem(0,0), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[2,6,9], GetAllMusicPtPosByPosition(0,1,ad.all_mspace_data[0].all_music_pts));

	ci = Instr(.add, MusicMem(0,0), MusicMem(0,0), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,4,7,2,6,9], GetAllMusicPtPosByPosition(0,0,ad.all_mspace_data[0].all_music_pts));

	//This test currently ignores the Imm(2) so we just add 1. Do we want that? 
	//I think so, it makes more sense than adding the values and then adding that to music_mem which would be 2 instructions.
	ci = Instr(.add, MusicMem(0,0), Imm(1), Imm(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[1,5,8,3,7,10], GetAllMusicPtPosByPosition(0,0,ad.all_mspace_data[0].all_music_pts));


	ci = FInstr(.mov, MusicMem(0,6), FImm(0.5), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.mov, MusicMem(0,6), FImm(4.5), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.mov, MusicMem(0,6), FImm(7.5), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0.5,4.5,7.5], GetAllMusicPtFloat(0,6,ad.all_mspace_data[0].all_music_pts));

	ci = FInstr(.add, MusicMem(0,7), MusicMem(0,6), FImm(2.0), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[2.5,6.5,9.5], GetAllMusicPtFloat(0,7,ad.all_mspace_data[0].all_music_pts));

	ci = FInstr(.add, MusicMem(0,6), FImm(2.0), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[2.5,6.5,9.5], GetAllMusicPtFloat(0,6,ad.all_mspace_data[0].all_music_pts));

	ci = FInstr(.add, MusicMem(0,6), MusicMem(0,6), FImm(2.0), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[2.5,6.5,9.5,4.5,8.5,11.5], GetAllMusicPtFloat(0,6,ad.all_mspace_data[0].all_music_pts));



	ci = Instr(.mov, MusicMem(0,3), Imm(12), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,3), Imm(12+3), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,3), Imm(12+7), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mod, MusicMem(0,3), Imm(12), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,3,7], GetAllMusicPtPosByPosition(0,3,ad.all_mspace_data[0].all_music_pts), "mod test");

	ci = Instr(.mov, MusicMem(0,4.5), Imm(12), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,4.5), Imm(12+3), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(0,4.5), Imm(12+7), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.sub, MusicMem(0,4.5), Imm(12), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,3,7], GetAllMusicPtPosByPosition(0,4.5,ad.all_mspace_data[0].all_music_pts), "sub test");

} @UnitTest

Test_Logical :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	//TODO test new shift and rotate

	//TODO More 2 operand tests and also MUSIC_MEMORY tests
	ci = Instr(.mov, RegMem(.amu), Immediate(1), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, RegMem(.bmu), Immediate(1), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.and, RamMem(0), RegMem(.amu), RegMem(.bmu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(0,int,ad.ram_memory));

	ci = Instr(.or, RamMem(8), RamMem(8), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(8,int,ad.ram_memory));

	ci = Instr(.mov, RegMem(.cmu), Immediate(12), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.not, RegMem(.cmu), RegMem(.bmu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(0, ad.all_register_memory[RegDef.cmu].int_value);

	ci = Instr(.xor, RegMem(.dmu), RegMem(.bmu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.dmu].int_value);

	ci = Instr(.mov, RamMem(16), Immediate(1), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.and, RamMem(16), RamMem(8), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(16,int,ad.ram_memory));

	ci = Instr(.mov, RegMem(.amu), Immediate(1), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, RegMem(.bmu), Immediate(1), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.shl, RamMem(0), RegMem(.amu), RegMem(.bmu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(2, GetMemValue(0,int,ad.ram_memory));

	ci = Instr(.and, RamMem(0), RegMem(.amu), RegMem(.bmu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(0,int,ad.ram_memory));

	ci = Instr(.or, RamMem(0), RegMem(.amu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(0,int,ad.ram_memory));

	ci = Instr(.xor, RamMem(0), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(0, GetMemValue(0,int,ad.ram_memory));

} @UnitTest

Test_ShiftMusic :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	smd := SetupMusicData.{memory_units_per_second = 2.0};
	SetupMusicAndRows(ad, TWO_ROWS);

	//TODO Be more explicit about these tests. Could write detailed notes,
	//but also could separate tests into many functions so that each test case is clearer.
	ci = Instr(.mov, MusicMem(0,0), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.shr, MusicMem(0,0), Immediate(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0], GetAllMusicPtPosByPosition(0,2,ad.all_mspace_data[0].all_music_pts), "shr test");

	ci = Instr(.mov, MusicMem(1,0), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, MusicMem(1,1), Immediate(5), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.shr, MusicMem(1,0), Immediate(2), Immediate(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0], GetAllMusicPtPosByPosition(1,2,ad.all_mspace_data[0].all_music_pts), "shr range_test");
	AssertArrayEquals(int.[5], GetAllMusicPtPosByPosition(1,3,ad.all_mspace_data[0].all_music_pts), "shr range_test");

	ci = Instr(.mov, MusicMem(0,11), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.shl, MusicMem(0,11), Immediate(2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0], GetAllMusicPtPosByPosition(0,9,ad.all_mspace_data[0].all_music_pts), "shl test");

	ci = Instr(.mov, MusicMem(1,6), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	//TODO Could update stack_p and heap_p from another struct hat raps the RamMEmory since I don't thinke we use that.
	lower_index : int = PushRAMValues(6, 9, r=*ad.ram_memory);
	ci = Instr(.ror, MusicMem(1,6), Immediate(3), RamMem(lower_index), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0], GetAllMusicPtPosByPosition(1,6,ad.all_mspace_data[0].all_music_pts), "ror test");

	ci = Instr(.mov, MusicMem(1,11), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	lower_index = PushRAMValues(8, 11, r=*ad.ram_memory);
	ci = Instr(.rol, MusicMem(1,11), Immediate(4), RamMem(lower_index), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0], GetAllMusicPtPosByPosition(1,10,ad.all_mspace_data[0].all_music_pts), "rol test");

} @UnitTest


Test_LogicalMusic :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	//3 operand instructions
	ci = Instr(.mov, MusicMem(0,0), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.or, MusicMem(0,1), MusicMem(0,0), Immediate(4), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,4], GetAllMusicPtPosByPosition(0,1,ad.all_mspace_data[0].all_music_pts), "logicm or 3 op");

	// i1 : int = PushRAMArrayAndCount(int.[7,11], *ad.ram_memory);
	c1, d1 := PushRAMArray(int.[7,11], *ad.ram_memory);
	ci = Instr(.or, MusicMem(0,2), MusicMem(0,1), RamArray(c1,d1), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,4,7,11], GetAllMusicPtPosByPosition(0,2,ad.all_mspace_data[0].all_music_pts), "logicm array 3 op");

	c2, d2 := PushRAMArray(int.[0,4,7], *ad.ram_memory);
	ci = Instr(.and, MusicMem(0,3), MusicMem(0,2), RamArray(c2,d2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,4,7], GetAllMusicPtPosByPosition(0,3,ad.all_mspace_data[0].all_music_pts), "logicm and 3 op");

	ci = Instr(.xor, MusicMem(0,4), MusicMem(0,2), MusicMem(0,1), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[7,11], GetAllMusicPtPosByPosition(0,4,ad.all_mspace_data[0].all_music_pts), "logicm xor 3 op");

	//2 operand instructions
	ci = Instr(.or, MusicMem(0,1), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.mov, RegMem(.ax), Immediate(4), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.or, MusicMem(0,1), RegMem(.ax), d=ad);
	ExecMInstr(ci, ad);

	// i3 : int = PushRAMArrayAndCount(int.[7,11], *ad.ram_memory);
	c3, d3 := PushRAMArray(int.[7,11], *ad.ram_memory);
	ci = Instr(.or, MusicMem(0,1), RamArray(c3,d3), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,4,7,11], GetAllMusicPtPosByPosition(0,1,ad.all_mspace_data[0].all_music_pts), "logicm or 2 op");

	ci = Instr(.mov, MusicMem(1,1), MusicMem(0,1), d=ad);
	ExecMInstr(ci, ad);

	// i4 : int = PushRAMArrayAndCount(int.[0,11], *ad.ram_memory);
	c4, d4 := PushRAMArray(int.[0,11], *ad.ram_memory);
	ci = Instr(.and, MusicMem(1,1), RamArray(c4,d4), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[0,11], GetAllMusicPtPosByPosition(1,1,ad.all_mspace_data[0].all_music_pts), "logicm and 2 op");

	ci = Instr(.mov, MusicMem(1,2.4), MusicMem(0,1), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.xor, MusicMem(1,2.4), MusicMem(1,1), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(int.[4,7], GetAllMusicPtPosByPosition(1,2.4,ad.all_mspace_data[0].all_music_pts), "logicm xor 2 op");

} @UnitTest

Test_LogicalMusicFloat :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);
	SetupMusicAndRows(ad, TWO_ROWS);

	//3 operand instructions
	ci = FInstr(.mov, MusicMem(0,0), FImm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.or, MusicMem(0,1), MusicMem(0,0), FImm(4), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,4], GetAllMusicPtFloat(0,1,ad.all_mspace_data[0].all_music_pts), "logicm or 3 op");

	// i1 : int = PushRAMArrayAndCount(float64.[7.5,11.5], *ad.ram_memory);
	c1, d1 := PushRAMArray(float64.[7.5,11.5], *ad.ram_memory);
	ci = FInstr(.or, MusicMem(0,2), MusicMem(0,1), RamArray(c1,d1), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,4,7.5,11.5], GetAllMusicPtFloat(0,2,ad.all_mspace_data[0].all_music_pts), "logicm array 3 op");

	// i2 : int = PushRAMArrayAndCount(float64.[0,4,7.5], *ad.ram_memory);
	c2, d2 := PushRAMArray(float64.[0,4,7.5], *ad.ram_memory);
	ci = FInstr(.and, MusicMem(0,3), MusicMem(0,2), RamArray(c2,d2), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,4,7.5], GetAllMusicPtFloat(0,3,ad.all_mspace_data[0].all_music_pts), "logicm and 3 op");

	ci = FInstr(.xor, MusicMem(0,4), MusicMem(0,2), MusicMem(0,1), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[7.5,11.5], GetAllMusicPtFloat(0,4,ad.all_mspace_data[0].all_music_pts), "logicm xor 3 op");

	//2 operand instructions
	ci = FInstr(.mov, MusicMem(1,0), FImm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.mov, RegMem(.ax), FImm(4.5), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.or, MusicMem(1,0), RegMem(.ax), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,4.5], GetAllMusicPtFloat(1,0,ad.all_mspace_data[0].all_music_pts), "logicm or 2 op");

	// i3 : int = PushRAMArrayAndCount(float64.[7.25,11.25], *ad.ram_memory);
	c3, d3 := PushRAMArray(float64.[7.25,11.25], *ad.ram_memory);
	ci = FInstr(.or, MusicMem(1,0), RamArray(c3,d3), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,4.5,7.25,11.25], GetAllMusicPtFloat(1,0,ad.all_mspace_data[0].all_music_pts), "logicm or 2 op");

	ci = FInstr(.mov, MusicMem(1,1), MusicMem(1,0), d=ad);
	ExecMInstr(ci, ad);

	// i4 : int = PushRAMArrayAndCount(float64.[0,11.25], *ad.ram_memory);
	c4, d4 := PushRAMArray(float64.[0,11.25], *ad.ram_memory);
	ci = FInstr(.and, MusicMem(1,1), RamArray(c4,d4), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[0,11.25], GetAllMusicPtFloat(1,1,ad.all_mspace_data[0].all_music_pts), "logicm and 2 op");

	ci = FInstr(.mov, MusicMem(1,2), MusicMem(1,0), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.xor, MusicMem(1,2), MusicMem(1,1), d=ad);
	ExecMInstr(ci, ad);
	AssertArrayEquals(float64.[4.5,7.25], GetAllMusicPtFloat(1,2,ad.all_mspace_data[0].all_music_pts), "logicm xor 2 op");

} @UnitTest

Test_Compare :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	ci = Instr(.mov, RegMem(.amu), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.clte, RegMem(.bmu), RegMem(.amu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.bmu].int_value);

	ci = Instr(.clt, RamMem(0), RegMem(.amu), RegMem(.bmu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(0,int,ad.ram_memory));

	ci = Instr(.mov, RegMem(.cmu), Immediate(123), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.cgt, RamMem(8), RegMem(.cmu), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(8,int,ad.ram_memory));

	ci = Instr(.ceq, RamMem(16), RamMem(8), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(16,int,ad.ram_memory));

	ci = Instr(.cneq, RamMem(24), RamMem(16), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(24,int,ad.ram_memory));

	ci = Instr(.cgte, RegMem(.dmu), Immediate(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.dmu].int_value);

	ci = Instr(.cneq, RegMem(.emu), RamMem(24), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.emu].int_value);

} @UnitTest

Test_Branch :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	//Create some dummy instructions to make sure the branch does not fail
	for 0..19 {
		Instr(.mov, RegMem(.ax), Imm(0), d=ad);
	}

	ci = Instr(.jmp, Imm(20), d=ad);
	err := ExecMInstr(ci, ad);	
	AssertEquals(false, err.is_error);

	//19 + 2 (added here and above) = 21 so we should fail
	ci = Instr(.jmp, Imm(22), d=ad);
	err = ExecMInstr(ci, ad);	
	AssertEquals(true, err.is_error);

	ci = Instr(.ceq, RegMem(.ax), RegMem(.ax), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.ax].int_value);
	ci = Instr(.tjmp, Imm(10), RegMem(.ax), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(10, ad.all_register_memory[RegDef.pc].int_value);

	ci = Instr(.mov, RegMem(.bx), Imm(5), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.ceq, RamMem(0), RegMem(.ax), Imm(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(0, GetMemValue(0,int,ad.ram_memory));
	ci = Instr(.fjmp, RegMem(.bx), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(5, ad.all_register_memory[RegDef.pc].int_value);

	ci = Instr(.mov, RamMem(8), Imm(10), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.jmp, RamMem(8), d=ad);
	ExecMInstr(ci, ad);	
	AssertEquals(10, ad.all_register_memory[RegDef.pc].int_value);

	ci = Instr(.call, Imm(19), d=ad);
	ExecMInstr(ci, ad);	
	AssertEquals(19, ad.all_register_memory[RegDef.pc].int_value);

	ci = Instr(.jmp, Imm(-10), d=ad);
	err = ExecMInstr(ci, ad);	
	AssertEquals(true, err.is_error);

} @UnitTest;

TwoValueTest :: struct {
	x : int;
	y : int;
}

Test_PushPop :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	x : int = 66;
	ci = Instr(.push, Imm(x), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(8, ad.all_register_memory[RegDef.scp].int_value);
	AssertEquals(x, GetMemValue(0,int,ad.ram_memory));

	f : float64 = 54.3;
	ci = FInstr(.mov, RegMem(.ax), FImm(f), d=ad);
	ExecMInstr(ci, ad);
	ci = Instr(.push, RegMem(.ax), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(16, ad.all_register_memory[RegDef.scp].int_value);
	AssertFloat64Equals(f, GetMemValue(8,float64,ad.ram_memory));

	ci = Instr(.pop, RegMem(.bx), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(8, ad.all_register_memory[RegDef.scp].int_value);
	AssertFloat64Equals(f, ad.all_register_memory[RegDef.bx].float_value);

	//TODO Do we really want this multi_value push/pop or just allow multi_value for the mov
	//it feels confusing and unnecessary... but maybe if we have special push and pop debugging info.
	tvt := TwoValueTest.{10,20};
	SetRAMValue(200, tvt, *ad.ram_memory);
	ci = Instr(.push, RamMem(200), Imm(size_of(TwoValueTest)), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(24, ad.all_register_memory[RegDef.scp].int_value);
	AssertEquals(tvt.x, GetMemValue(8,int,ad.ram_memory));
	AssertEquals(tvt.y, GetMemValue(16,int,ad.ram_memory));

	ci = Instr(.pop, RamMem(100), Imm(size_of(TwoValueTest)), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(8, ad.all_register_memory[RegDef.scp].int_value);
	AssertEquals(tvt.x, GetMemValue(100,int,ad.ram_memory));
	AssertEquals(tvt.y, GetMemValue(108,int,ad.ram_memory));

} @UnitTest

Test_CompareFloat :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	ci = FInstr(.mov, RegMem(.amu), FImm(0), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.clte, RegMem(.bmu), RegMem(.amu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.bmu].int_value);

	ci = FInstr(.clt, RamMem(0), RegMem(.amu), RegMem(.bmu), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(0,int,ad.ram_memory));

	ci = FInstr(.mov, RegMem(.cmu), FImm(123.0), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.cgt, RamMem(8), RegMem(.cmu), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(8,int,ad.ram_memory));

	ci = FInstr(.mov, RamMem(0), RegMem(.cmu), d=ad);
	ExecMInstr(ci, ad);	
	ci = FInstr(.ceq, RamMem(16), RegMem(.cmu), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(16,int,ad.ram_memory));

	ci = FInstr(.mov, RamMem(16), FImm(10.5), d=ad);
	ExecMInstr(ci, ad);
	ci = FInstr(.cneq, RamMem(24), RamMem(16), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, GetMemValue(24,int,ad.ram_memory));

	ci = FInstr(.cgte, RegMem(.dmu), FImm(-20.0), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.dmu].int_value);

	ci = FInstr(.cneq, RegMem(.emu), RamMem(16), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(1, ad.all_register_memory[RegDef.emu].int_value);
	
} @UnitTest

//TODO add changeable ram size
Test_Alloc :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	start_heap : int = ad.all_register_memory[RegDef.hsp].int_value;
	sbp_value : int = ad.all_register_memory[RegDef.sbp].int_value;
	offset : int = 0;
	size : int = 10;
	ci = Instr(.alloc, Imm(size), RamMem(.sbp,offset), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(start_heap, GetMemValue(sbp_value+offset, int, ad.ram_memory));
	AssertEquals(start_heap+size, ad.all_register_memory[RegDef.hcp].int_value);
} @UnitTest

Test_SPrint :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	//Input string
	test_string := "% test % end %";
	s_count, s_data := PushRAMString(test_string, *ad.ram_memory);
	string_address : int = PushRAMCountData(s_count, s_data, *ad.ram_memory);

	//Actual string
	args := string.["start", "input", "end"];
	args_string_address := NewArray(args.count, int,,unit_test_alloc);
	for args {
		arg_count, arg_data := PushRAMString(it, *ad.ram_memory);
		args_string_address[it_index] = arg_data;
	}

	//string_array_values
	string_array_start : int = ad.ram_memory.stack_p;
	for args {
		PushRAMCountData(it.count, args_string_address[it_index], *ad.ram_memory);
	}

	//string array
	arg_array_address : int = PushRAMCountData(args.count, string_array_start, *ad.ram_memory);

	start_heap_address : int = ad.all_register_memory[RegDef.hcp].int_value;
	return_address : int = ad.ram_memory.stack_p;
	ci = Instr(.s_print, RamMem(string_address), RamMem(arg_array_address), RamMem(return_address), d=ad);
	ExecMInstr(ci, ad);

	args_any := NewArray(args.count, Any,,unit_test_alloc);
	for args args_any[it_index] = it;
	expected_string : string = sprint(test_string, ..args_any,,unit_test_alloc);
	//TODO Check that the string is correct as well
	new_string_count : int = GetMemValue(return_address, int, ad.ram_memory);
	AssertEquals(expected_string.count, new_string_count);

	new_string_data : int = GetMemValue(return_address+8, int, ad.ram_memory);
	AssertEquals(start_heap_address, new_string_data);

	actual_string : string;
	actual_string.count = new_string_count;
	actual_string.data = GetMemory(new_string_data, new_string_count, ad.ram_memory);
	AssertEquals(expected_string, actual_string);


	//TODO Can add tests where data is out of memory if needed
	//This test shows that missing return_address is invalid.
	ci = Instr(.s_print, RamMem(string_address), RamMem(arg_array_address), d=ad);
	err := ExecMInstr(ci, ad);
	AssertEquals(true, err.is_error);

} @UnitTest

Test_itof :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	iv : int = 10;
	ci = Instr(.itof, RegMem(.ax), Imm(iv), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(cast(float64) iv, ad.all_register_memory[RegDef.ax].float_value);

	fv : float64 = 13.1456;
	ci = Instr(.ftoi, RamMem(0), FImm(fv), d=ad);
	ExecMInstr(ci, ad);
	AssertEquals(cast(int) fv, GetMemValue(0, int, ad.ram_memory));

	ci = Instr(.itof, RamMem(8), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	AssertFloat64Equals(cast(float64) (cast(int) fv), GetMemValue(8, float64, ad.ram_memory));
} @UnitTest

/*
THIS passing in RamMemory and document that we take the address
it's fine because pop and push are always called with stack and not any other 
way but we could update push/pop instr and check the documentation
if we do need to use it again
*/
//NOTE : We test push_all_stack_reg and pop_all_stack_reg in here since we have to push before popping.
/*DOC : push_all_stack_reg and pop_all_stack_reg use the address
passed in to operand_0 in order to know where to push and pop.
So it takes a RamMem but does not push at the value there but instead
uses ComputeRAMLocation to get the address of the sum of the 2 values.
This makes more sense in this case for now but we can change it later if needed.
*/
Test_PushAllReg :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	new_sbp : int = 8;
	ad.all_register_memory[RegDef.sbp].int_value = new_sbp;
	push_scp : int = 16;
	ad.all_register_memory[RegDef.scp].int_value = push_scp;
	store_ip : int = 10;
	ad.all_register_memory[RegDef.ir].int_value = store_ip;

	non_stack_memory := array_view(ad.all_register_memory, non_stack_start_reg_index);
	for * non_stack_memory {
		it.int_value = it_index;
	}

	//Copy the original registers so we can check for pop_all_stack_reg after
	original_reg : [] MemoryValue = array_copy(ad.all_register_memory);

	push_stack_op := RamMem(.sbp,8);
	ci = Instr(.push_all_stack_reg, push_stack_op, d=ad);
	ExecMInstr(ci, ad);

	//Check that values that may have changed are correct
	AssertEquals(store_ip, ad.all_register_memory[RegDef.ir].int_value);

	// new_scp : int = push_scp + STACK_REG_SIZE;
	// AssertEquals(new_scp, ad.all_register_memory[RegDef.scp].int_value);

	ram_p : int = push_scp;
	AssertEquals(new_sbp, GetMemValue(ram_p, int, ad.ram_memory));
	ram_p += size_of(MemoryValue);
	AssertEquals(push_scp, GetMemValue(ram_p, int, ad.ram_memory));

	//Start ram_p at the new .ax reg to check memory which is this amount above the .scp reg (in case we remove .sep reg eventually)
	ram_p = push_scp + (non_stack_start_reg_index - push_pop_start_reg_index) * size_of(MemoryValue);
	for non_stack_memory {
		ram_int : int = GetMemValue(ram_p, int, ad.ram_memory);
		AssertEquals(it.int_value, ram_int);
		ram_p += size_of(MemoryValue);
	}


	//Update the registers so we make sure they change back after
	sbp_increment : int = 8;
	push_stack_op.values[1].int_value -= sbp_increment;
	#if 1 {
	//NOTE : This way ensures we update all registers to make sure
	//they all get changed back on the pop
	for push_pop_start_reg_index..reg_def_enums.count-1 {
		ad.all_register_memory[it].int_value += sbp_increment;
	}	
	} else {
	//TODO Can remove this old way if the above way keeps working
	ad.all_register_memory[RegDef.sbp].int_value += sbp_increment;
	//We need to decrease the push_stack_op so we grab from the same place.
	//Doing this makes sure that the sbp also gets set back
	ad.all_register_memory[RegDef.scp].int_value += 16;
	ad.all_register_memory[RegDef.tbp].int_value += 16;
	for * non_stack_memory {
		it.int_value += 5;
	}
	}



	ci = Instr(.pop_all_stack_reg, push_stack_op, d=ad);
	ExecMInstr(ci, ad);

	for ad.all_register_memory {
		AssertEquals(it.int_value, original_reg[it_index].int_value);
	}

} @UnitTest

Test_CreateSpace :: () {
	ci : MusicInstruction;
	ad : *AllData = InitAllData(,,unit_test_alloc);

	//TODO Could make this a functino to make AsmOpSpaceData on the stack
	PushAsmOpSpaceData("test", *ad.ram_memory);

	ci = Instr(.muscall, Imm(cast(int) MusCallType.create_space), RamMem(0), d=ad);
	ExecMInstr(ci, ad);
	count_equals := AssertEquals(1, ad.all_closed_op_spaces.count);
	if count_equals {
		AssertEquals(0, ad.all_closed_op_spaces[0].id);
		AssertEquals(OpSpaceExternalType.space_2d, ad.all_closed_op_spaces[0].op_space_external_type);
		AssertEquals("test", ad.all_closed_op_spaces[0].op_space_name);
	}

} @UnitTest

// Test_GetNextNonMutedMSpace :: () {
Test_nonmute :: () {
	all_mspace_data : [..] MusicSpaceData;
	m0 := array_add(*all_mspace_data);
	m0.mspace_audio_row_size = 0;
	m1 := array_add(*all_mspace_data);
	m1.mspace_audio_row_size = 0;
	m2 := array_add(*all_mspace_data);
	m2.mspace_audio_row_size = 0;

	//Test all muted mspace should return all muted
	next_mspace_index, all_muted := GetNextNonMutedMSpace(1, all_mspace_data);
	AssertEquals(true, all_muted);
	AssertEquals(1, next_mspace_index);

	//Test the start index mspace is not muted so we should get it back but not all muted
	m0.mspace_audio_row_size = 0;
	m1.mspace_audio_row_size = 1;
	m2.mspace_audio_row_size = 0;
	next_mspace_index, all_muted = GetNextNonMutedMSpace(1, all_mspace_data);
	AssertEquals(false, all_muted);
	AssertEquals(1, next_mspace_index);


	//Test that we get m0 back as a wraparound from 1
	m0.mspace_audio_row_size = 1;
	m1.mspace_audio_row_size = 1;
	m2.mspace_audio_row_size = 0;
	next_mspace_index, all_muted = GetNextNonMutedMSpace(1, all_mspace_data);
	AssertEquals(false, all_muted);
	AssertEquals(0, next_mspace_index);

	//Test that we get m2 back from 1
	m0.mspace_audio_row_size = 0;
	m1.mspace_audio_row_size = 0;
	m2.mspace_audio_row_size = 1;
	next_mspace_index, all_muted = GetNextNonMutedMSpace(1, all_mspace_data);
	AssertEquals(false, all_muted);
	AssertEquals(2, next_mspace_index);

	//Test that we get m2 back from 1
	m0.mspace_audio_row_size = 1;
	m1.mspace_audio_row_size = 0;
	m2.mspace_audio_row_size = 1;
	next_mspace_index, all_muted = GetNextNonMutedMSpace(0, all_mspace_data);
	AssertEquals(false, all_muted);
	AssertEquals(2, next_mspace_index);
	next_mspace_index, all_muted = GetNextNonMutedMSpace(2, all_mspace_data);
	AssertEquals(false, all_muted);
	AssertEquals(0, next_mspace_index);

} @UnitTest

//TODO Could pass in params if we want to change them for
//for radius, point_count, pos_x and pos_y
PushCreateCircle :: inline (
	ram_mem : *RAMMemory,
	op_space_id : int = 0,
	radius : float64 = 4.0,
	point_count : int = 12,
	pos_x : float64 = 0,
	pos_y : float64 = 0)
{
	geometry_data := PushStruct(CreateGeometryData, ram_mem);
	geometry_data.op_dspace_type = OpDSpaceType.OLD_CIRCLE;
	geometry_data.op_space_id = op_space_id;
	geometry_data.pos_x = 0;
	geometry_data.pos_y = 0;

	circle_address : int = ram_mem.stack_p;
	circle_data := PushStruct(CreateCircleData, ram_mem);
	circle_data.radius = 4.0;
	circle_data.point_count = 12;

	geometry_data.data_address = circle_address;
}

Test_Disassembler :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);

	//Test mov
	Instr(.mov, RegMem(.bx), Imm(5), d=ad);
	Instr(.mov, RegMem(.ax), RamMem(-10), d=ad);
	Instr(.mov, RegMem(.cx), RamMem(.sbp,5), d=ad);
	Instr(.mov, MusicMem(0,-1), Imm(1), Imm(8), d=ad);
	actual : string = Disassembler(ad.all_music_instructions,,unit_test_alloc);
	expected : string = 
#string DONE
mov bx, 5;
mov ax, [-10];
mov cx, [sbp+5];
mov <0,-1>, 1, 8;
DONE;
	AssertEquals(actual, expected);

	//Test arithmetic music
	array_reset_keeping_memory(*ad.all_music_instructions);

	Instr(.add, MusicMem(1,7.2), MusicMem(RegDef.dx,6), Imm(3), d=ad);
	FInstr(.add, MusicMem(RegDef.ax,6), FImm(3.14), d=ad);
	FInstr(.mul, RamMem(.sbp,.ax), FImm(2.0), d=ad);
	actual = Disassembler(ad.all_music_instructions,,unit_test_alloc);
	expected = 
#string DONE
add <1,7.2>, <dx,6>, 3;
add.f <ax,6>, 3.14;
mul.f [sbp+ax], 2.0;
DONE;
	AssertEquals(actual, expected);



	//Test logical
	array_reset_keeping_memory(*ad.all_music_instructions);

	FInstr(.or, MusicMem(0,1), MusicMem(0,0), FImm(4), d=ad);
	FInstr(.and, MusicMem(0,2), MusicMem(0,1), RamArray(2,RegDef.ax), d=ad);
	Instr(.xor, MusicMem(RegDef.ax,RegDef.bx), MusicMem(0,2), MusicMem(0,1), d=ad);
	actual = Disassembler(ad.all_music_instructions,,unit_test_alloc);
	expected = 
#string DONE
or.f <0,1>, <0,0>, 4.0;
and.f <0,2>, <0,1>, .[2,ax];
xor <ax,bx>, <0,2>, <0,1>;
DONE;
	AssertEquals(actual, expected);



	//Test muscall
	array_reset_keeping_memory(*ad.all_music_instructions);

	Instr(.muscall, ImmEnum(MusCallType.create_space), RamMem(.scp), d=ad);
	Instr(.muscall, ImmEnum(MusCallType.map_cs3), RamMem(.sbp,8), d=ad);
	Instr(.muscall, RegMem(.ax), RamMem(16), d=ad);
	Instr(.muscall, RamMem(.sbp,0), RamMem(.sbp,-8), d=ad);
	actual = Disassembler(ad.all_music_instructions,,unit_test_alloc);
	expected = 
#string DONE
muscall create_space, [scp];
muscall map_cs3, [sbp+8];
muscall ax, [16];
muscall [sbp+0], [sbp-8];
DONE;
	AssertEquals(actual, expected);


} @UnitTest

//TODO FROM HERE COULD make similar integration tests for breakpoints so then
//we can test out all the input functionality and also so
//we can check ourselves if everything seems good afterwards in game.
//Could do the same for watch data
//OR we start on compiling code and functions and then do stack window
Test_Breakpoint :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	// ad.comp_alloc.proc = flat_pool_allocator_proc;
	// ad.comp_alloc.data = *ad.comp_pool;

	//TODO Can reset comp_alloc here to compile without new memory
	// reset(ad.comp_pool);
	ad.comp_data = CompileCode(.{}, 
#string DONE
main :: () { #asm {
   mov ax, 1;
   mov [0], 0;
   mov.f [1], 4.5;
   mov [2], 7;
   mov.f [3], 10.5;
 
   mov bx, 4;
   sub ax, 7;
 
   add ax, 2;
   mov [bx+2], 7;
 
   add bx, 2;
}
  x : int = 1;

  x = x + 1;

}
DONE,,unit_test_alloc);
	//TODO Should not have to do this.
	//OR Maybe we should since we don't have a text file here
	ad.all_music_instructions = ad.comp_data.all_music_instructions;

	exec_info : ExecutionInfo;
	exec_info.exec_mode = .DEBUG;
	//TODO Could make this START_DEBUGGING if that helps later
	bp0 : *DebugBreakpoint = array_add(*exec_info.debug_info.break_points);
	bp0.bp_type = .BP_CODE;
	bp0.asm_index = 0;
	d_line := GetDebugLineAsm(bp0.asm_index, ad.comp_data);
	bp0.end_asm_index = d_line.end_asm_index;
	bp0.line_number = d_line.line_number;

	bp1 := array_add(*exec_info.debug_info.break_points);
	bp1.bp_type = .BP_CODE;
	bp1.asm_index = 6;
	d_line = GetDebugLineAsm(bp1.asm_index, ad.comp_data);
	bp1.end_asm_index = d_line.end_asm_index;
	bp1.line_number = d_line.line_number;

	bp_asm := array_add(*exec_info.debug_info.break_points);
	bp_asm.bp_type = .BP_ASM;
	bp_asm.asm_index = 10;
	d_line = GetDebugLineAsm(bp_asm.asm_index, ad.comp_data);
	bp_asm.end_asm_index = d_line.end_asm_index;
	bp_asm.line_number = d_line.line_number;

	exec_info.debug_info.debug_control = .CONTINUE;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .IS_DEBUG_STOP);
	AssertEquals(bp0.asm_index, ad.all_register_memory[RegDef.pc].int_value);
	stop_d_line := GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
	AssertEquals(bp0.line_number, stop_d_line.line_number);


	exec_info.debug_info.debug_control = .STEP_OVER;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .IS_DEBUG_STOP);
	AssertEquals(bp0.asm_index+1, ad.all_register_memory[RegDef.pc].int_value);
	stop_d_line = GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
	AssertEquals(bp0.line_number+1, stop_d_line.line_number);


	exec_info.debug_info.debug_control = .CONTINUE;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .IS_DEBUG_STOP);
	AssertEquals(bp1.asm_index, ad.all_register_memory[RegDef.pc].int_value);
	stop_d_line = GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
	AssertEquals(bp1.line_number, stop_d_line.line_number);


	exec_info.debug_info.debug_control = .ASM_STEP_OVER;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .IS_DEBUG_STOP);
	AssertEquals(bp1.asm_index+1, ad.all_register_memory[RegDef.pc].int_value);
	stop_d_line = GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
	AssertEquals(bp1.line_number+2, stop_d_line.line_number);


	exec_info.debug_info.debug_control = .CONTINUE;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .IS_DEBUG_STOP);
	AssertEquals(bp_asm.asm_index, ad.all_register_memory[RegDef.pc].int_value);
	stop_d_line = GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
	AssertEquals(bp_asm.line_number, stop_d_line.line_number);

	exec_info.debug_info.debug_control = .STEP_OVER;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .IS_DEBUG_STOP);
	AssertEquals(bp_asm.asm_index+1, ad.all_register_memory[RegDef.pc].int_value);
	stop_d_line = GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
	AssertEquals(bp_asm.line_number+2, stop_d_line.line_number);

	exec_info.debug_info.debug_control = .STEP_OVER;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .IS_DEBUG_STOP);
	AssertEquals(ad.comp_data.all_music_instructions.count-1, ad.all_register_memory[RegDef.pc].int_value);

	//This executes the halt instruction
	exec_info.debug_info.debug_control = .STEP_OVER;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .NOT_RUNNING);
	AssertEquals(ad.comp_data.all_music_instructions.count, ad.all_register_memory[RegDef.pc].int_value);


	//RESET and make sure we stop at bp0 again
	exec_info.debug_info.debug_control = .CONTINUE;
	ExecuteManyInstructions(*exec_info, ad);
	AssertEquals(exec_info.exec_state, .IS_DEBUG_STOP);
	AssertEquals(bp0.asm_index, ad.all_register_memory[RegDef.pc].int_value);
	stop_d_line = GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
	AssertEquals(bp0.line_number, stop_d_line.line_number);

} @UnitTest

Test_CircleBuffer :: () {
	circle_buffer := NewArray(6, int);
	circle_bytes : [] u8 = ToByteArray(circle_buffer);

	write_buffer := NewArray(4, int);
	for * write_buffer it.* = it_index;
	for 0..write_buffer.count-1 {
		AssertEquals(it, write_buffer[it]);
	}
	write_bytes : [] u8 = ToByteArray(write_buffer);

	write_cursor : int = 0;
	//Test write to circle buffer without going over end
	WriteBytesToCircleBuffer(write_bytes, circle_bytes, *write_cursor);
	AssertEquals(write_buffer.count * size_of(int), write_cursor);
	AssertEquals(write_buffer[0], circle_buffer[0]);
	AssertEquals(write_buffer[1], circle_buffer[1]);
	AssertEquals(write_buffer[2], circle_buffer[2]);
	AssertEquals(write_buffer[3], circle_buffer[3]);
	AssertEquals(0, circle_buffer[4]);
	AssertEquals(0, circle_buffer[5]);

	//Test write to circle buffer with going over end
	WriteBytesToCircleBuffer(write_bytes, circle_bytes, *write_cursor);
	AssertEquals(((2*write_buffer.count)%circle_buffer.count) * size_of(int), write_cursor);
	AssertEquals(write_buffer[0], circle_buffer[4]);
	AssertEquals(write_buffer[1], circle_buffer[5]);
	AssertEquals(write_buffer[2], circle_buffer[0]);
	AssertEquals(write_buffer[3], circle_buffer[1]);
	AssertEquals(write_buffer[2], circle_buffer[2]);
	AssertEquals(write_buffer[3], circle_buffer[3]);

	WriteBytesToCircleBuffer(write_bytes, circle_bytes, *write_cursor);
	AssertEquals(((3*write_buffer.count)%circle_buffer.count) * size_of(int), write_cursor);
	AssertEquals(write_buffer[0], circle_buffer[2]);
	AssertEquals(write_buffer[1], circle_buffer[3]);
	AssertEquals(write_buffer[2], circle_buffer[4]);
	AssertEquals(write_buffer[3], circle_buffer[5]);
	AssertEquals(write_buffer[2], circle_buffer[0]);
	AssertEquals(write_buffer[3], circle_buffer[1]);



	read_buffer := NewArray(4, int);
	read_bytes : [] u8 = ToByteArray(read_buffer);

	read_cursor : int = 0;
	//Test read from circle buffer without going over end
	ReadBytesFromCircleBuffer(read_bytes, circle_bytes, *read_cursor);
	AssertEquals(read_buffer.count * size_of(int), read_cursor);
	AssertEquals(circle_buffer[0], read_buffer[0]);
	AssertEquals(circle_buffer[1], read_buffer[1]);
	AssertEquals(circle_buffer[2], read_buffer[2]);
	AssertEquals(circle_buffer[3], read_buffer[3]);

	//Test read from circle buffer where we go over the end
	ReadBytesFromCircleBuffer(read_bytes, circle_bytes, *read_cursor);
	AssertEquals(((2*read_buffer.count) % circle_buffer.count) * size_of(int), read_cursor);
	AssertEquals(circle_buffer[4], read_buffer[0]);
	AssertEquals(circle_buffer[5], read_buffer[1]);
	AssertEquals(circle_buffer[0], read_buffer[2]);
	AssertEquals(circle_buffer[1], read_buffer[3]);


	//Make sure circle buffer contents have not changed after reading
	AssertEquals(write_buffer[0], circle_buffer[2]);
	AssertEquals(write_buffer[1], circle_buffer[3]);
	AssertEquals(write_buffer[2], circle_buffer[4]);
	AssertEquals(write_buffer[3], circle_buffer[5]);
	AssertEquals(write_buffer[2], circle_buffer[0]);
	AssertEquals(write_buffer[3], circle_buffer[1]);

} @UnitTest

//TODO Do we need a test for CreateDebugCallFrame?
Test_CreateDebugCallFrame :: () {

} //@UnitTest

//TODO This is the kind of test we can likely put with the external update and dynamic library functions.
//Maybe if we pull those functions out of the platform layer then I can put this test together with them.
TEST_DL_PATH_NAME :: #run sprint("%/test/test_dl", CODE_DLS_DIR_NAME);
TEST_DL_2_PATH_NAME :: #run sprint("%/test/test_dl_2", CODE_DLS_DIR_NAME);
Test_LoadDL :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	// SetupMusicAndRows(ad, TWO_ROWS);

	//NOTE : These will all be stored with unit_test_alloc by default.
	// cmd_file_name : string = TEST_DL_PATH_NAME;
	// no_ext_path_name : string = sprint("%/%", CODE_DLS_DIR_NAME, cmd_file_name);
	rel_path_name : string = sprint("%.%", TEST_DL_PATH_NAME, dl_suffix);
	use_path_name : string = sprint("%_use.%", TEST_DL_PATH_NAME, dl_suffix);
	lock_path_name : string = sprint("%_lock.tmp", TEST_DL_PATH_NAME);
	abs_path_name : string = get_absolute_path(rel_path_name);

	command_strings := string.[jai_cmd, BUILD_DL_NAME, "-import_dir", "./", "-", TEST_DL_PATH_NAME];

	test_file_exists := file_exists(rel_path_name);
	//TODO we could compile it if it does not exist if that helps
	//run command is at the bottom of this test.
	if !test_file_exists {
		cmd_success := run_command(.. command_strings, capture_and_return_output=true);
		if cmd_success.type != Process_Result_Type.EXITED {
			AssertEquals(true, test_file_exists);
			print("Need to compile % to run this test.\n", rel_path_name);
			return;
		}
	}

	/*NOTE : We test the way we would call it in game here so the first call is not loaded yet so
	TEST 1) FetchDynamicLibrary calls CreateDynamicLibrary
	2) FetchDynamicLibrary calls ReloadDynamicLibrary
	*/
	success, msg := FetchDynamicLibrary(rel_path_name);
	AssertEquals(true, success);

	old_write_time : Apollo_Time;
	count_equal := AssertEquals(1, global_dynamic_libraries.count);
	if count_equal {
		dl := global_dynamic_libraries[0];
		AssertEquals(TEST_DL_PATH_NAME, dl.no_ext_path_name);
		AssertEquals(rel_path_name, dl.input_path_name);
		AssertEquals(use_path_name, dl.use_input_path_name);
		AssertEquals(lock_path_name, dl.lock_file_name);
		AssertEquals(abs_path_name, dl.abs_path_name);
		AssertEquals(true, dl.module_handle != null);
		AssertEquals(true, dl.ExternalRunOnce_proc_address != null);

		old_write_time = dl.last_write_time;
	}

	//TEST 2) FetchDynamicLibrary calls ReloadDynamicLibrary
	success, msg = FetchDynamicLibrary(rel_path_name);
	AssertEquals(true, success);
	count_equal = AssertEquals(1, global_dynamic_libraries.count);
	if count_equal {
		dl := global_dynamic_libraries[0];
		AssertEquals(old_write_time, dl.last_write_time);
	}

	//TEST 3) Call reload with recompiling the dynamic library
	//This will have the same effect as above but we call the function directly to test the enum and 
	//because why not have a direct test for this function since we will likely call it in-game for automatic hot reloading.
	#if 0 {
	euf := *ad.all_external_update_files[0];
	reload_state, reload_msg := ReloadDynamicLibrary(euf);
	AssertEquals(ReloadState.NO_CHANGE, reload_state);
	count_equal = AssertEquals(1, global_dynamic_libraries.count);
	if count_equal {
		dl := global_dynamic_libraries[0];
		AssertEquals(old_write_time, dl.last_write_time);
		AssertEquals(no_ext_path_name, dl.no_ext_path_name);
		AssertEquals(rel_path_name, dl.input_path_name);
		AssertEquals(use_path_name, dl.use_input_path_name);
		AssertEquals(lock_path_name, dl.lock_file_name);
		AssertEquals(abs_path_name, dl.abs_path_name);
		AssertEquals(true, dl.module_handle != null);
		AssertEquals(true, dl.ExternalRunOnce_proc_address != null);

		AssertEquals(1, ad.all_external_update_files.count);
		AssertEquals(abs_path_name, euf.abs_path_name);
		AssertEquals(euf.ExternalRunOnce, dl.ExternalRunOnce_proc_address);
	}
	}

	//NOTE : Can remove this reloading test if we have issues recompiling a file but its good to have here
	//so that we can make sure the reloading with build_external_level.jai is working properly.
	//Removed for now since this test is way too flaky and usually works when I call it alone.
	//Maybe I can run it separately once in a while later since this does an actual compilation.
	#if 0{
	cmd_success := run_command(.. command_strings, capture_and_return_output=true);
	//The command above mutes the cmd line compile output. To see it, we can just use the default below.
	// cmd_success := run_command(.. command_strings);
	AssertEquals(Process_Result_Type.EXITED, cmd_success.type);
	if success {
		count_equal = AssertEquals(1, global_dynamic_libraries.count);
		if count_equal {
			dl := *global_dynamic_libraries[0];
			//NOTE : We explicitly test Reload here but in general we should only call FetchDynamicLibrary
			reload_state, reload_msg := ReloadDynamicLibrary(dl);
			AssertEquals(ReloadState.RELOADED, reload_state);
			AssertEquals(true, old_write_time != dl.last_write_time);
			AssertEquals(no_ext_path_name, dl.no_ext_path_name);
			AssertEquals(rel_path_name, dl.input_path_name);
			AssertEquals(use_path_name, dl.use_input_path_name);
			AssertEquals(lock_path_name, dl.lock_file_name);
			AssertEquals(abs_path_name, dl.abs_path_name);
			AssertEquals(true, dl.module_handle != null);
			AssertEquals(true, dl.ExternalRunOnce_proc_address != null);



			rm_success, rm_msg := RemoveDynamicLibrary(dl);
			AssertEquals(true, rm_success);
			AssertEquals(0, global_dynamic_libraries.count);
		}		
	}
	}


	//TEST non existant file
	success, msg = FetchDynamicLibrary("NON_EXISTANT_FILE");
	AssertEquals(false, success);

} @UnitTest


Test_StringCharCount :: () {
	empty_char_count : int = StringCharCount("\t", "");
	AssertEquals(0, empty_char_count);

	invalid_char_count : int = StringCharCount("\t", string.{-1,null});
	AssertEquals(0, invalid_char_count);

	one_char : int = StringCharCount("\t", "\t");
	AssertEquals(1, one_char);

	three_chars : int = StringCharCount("\t", "\t\t\t");
	AssertEquals(3, three_chars);

	more_chars : int = StringCharCount("\t", "\tBUNCH OF \t\tTEXT HERE \t WITH TABS\t\t");
	AssertEquals(6, more_chars);

	new_line_count : int = StringCharCount("\n",
#string DONE
TESTING A LARGER
WITH LINES
TEXT HERE
DONE);
	AssertEquals(3, new_line_count);

	multi_line_chars : int = StringCharCount("T",
#string DONE
TESTING A LARGER
WITH LINES
TEXT HERE
DONE);
	AssertEquals(5, multi_line_chars);


} @UnitTest

Test_CharCountWithTabInString :: () {
	empty_char_count : int = CharCountWithTabInString("", 0, 10);
	AssertEquals(0, empty_char_count);

	empty_char_count = CharCountWithTabInString(string.{0,null}, 0, 10);
	AssertEquals(0, empty_char_count);

	empty_char_count = CharCountWithTabInString(string.{-1,null}, 0, 10);
	AssertEquals(0, empty_char_count);

	ts := "test string";
	without_tab : int = CharCountWithTabInString(ts, 0, ts.count);
	AssertEquals(ts.count, without_tab);

	tab_s := "\ttest \t string\t";
	with_tabs : int = CharCountWithTabInString(tab_s, 0, tab_s.count);
	AssertEquals(tab_s.count + 3, with_tabs);

	tab_s_2 := "\t\ttest more\t\t\tstuff string\t\t";
	AssertEquals(tab_s_2.count + 7, CharCountWithTabInString(tab_s_2, 0, tab_s_2.count));
	AssertEquals(5 + 2, CharCountWithTabInString(tab_s_2, 0, 5));
	AssertEquals(0, CharCountWithTabInString(tab_s_2, 0, 0));

} @UnitTest

//DOC : Test to make sure highlighted rect is properly cut off from bottom and top since we will use this function
//generally for all highlighting now in text editor and single line and terminal
Test_HighlightedLineRect :: () {
	height_diff : float = 0.05;
	char_count : int = 10;
	unit_length : float = 1.0;
	rect : Rectangle2 = HighlightedLineRect(char_count, unit_length, Vector2F.{0,0}, unit_length, height_diff);
	test_rect : Rectangle2 = RectMinDim(.{0,0.05}, .{char_count*unit_length,1.-2.*height_diff});
	AssertFloatEquals(test_rect.min.x, rect.min.x);
	AssertFloatEquals(test_rect.min.y, rect.min.y);
	AssertFloatEquals(test_rect.max.x, rect.max.x);
	AssertFloatEquals(test_rect.max.y, rect.max.y);
} @UnitTest

AssertTextCursor :: inline (test_cursor : TextCursor, cursor : TextCursor) {
	AssertEquals(test_cursor.char_point, cursor.char_point, "char_point");
	AssertEquals(test_cursor.cursor_line_char, cursor.cursor_line_char, "cursor_line_char");
	AssertEquals(test_cursor.cursor_line_number, cursor.cursor_line_number, "cursor_line_number");
	AssertEquals(test_cursor.start_file_line_index, cursor.start_file_line_index, "start_file_line_index");
	AssertEquals(test_cursor.end_file_line_index, cursor.end_file_line_index, "end_file_line_index");
	AssertEquals(test_cursor.left_char_bound, cursor.left_char_bound, "left_char_bound");
	AssertEquals(test_cursor.right_char_bound, cursor.right_char_bound, "right_char_bound");

	AssertEquals(test_cursor.cursor_left_mouse_holding, cursor.cursor_left_mouse_holding, "cursor_left_mouse_holding");
	AssertEquals(test_cursor.cursor_is_selecting, cursor.cursor_is_selecting, "cursor_is_selecting");
	if test_cursor.cursor_is_selecting {
		AssertEquals(test_cursor.fixed_select_char_point, cursor.fixed_select_char_point, "fixed_select_char_point");
		AssertEquals(test_cursor.fixed_select_line_char, cursor.fixed_select_line_char, "fixed_select_line_char");
		AssertEquals(test_cursor.fixed_select_line_number, cursor.fixed_select_line_number, "fixed_select_line_number");		
	}
}

CURSOR_TEST_TEXT :: 
#string DONE
V2 :: struct {
  x : float;
  y : float;
}
main :: () {
	//Comment for the left and right char bound diff test over here








	Foo();
}




Foo :: (x : int) -> int {
  y := x + 1;
  return y;
}

DONE;
Test_MoveCursorToLineAndLineChar :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	text_file := CreateTestTextFile(*ALL_NEXT_IDS, *ad.all_text_files);
	WriteFileString(text_file, CURSOR_TEST_TEXT);

	cursor : TextCursor;
	cursor.left_char_bound = 0;
	cursor.right_char_bound = 10;
	cursor.start_file_line_index = 0;
	cursor.end_file_line_index = 10;

	test_cursor : TextCursor = cursor;

	MoveCursorToLineAndLineChar(0, 0, *cursor, text_file.file_string);
	AssertTextCursor(test_cursor, cursor);

	MoveCursorToLineAndLineChar(5, 7, *cursor, text_file.file_string);
	test_cursor.cursor_line_number = 5;
	test_cursor.cursor_line_char = 7;
	test_cursor.char_point = 63;
	AssertTextCursor(test_cursor, cursor);

	//TEST going over line bounds on right side should fix itself
	MoveCursorToLineAndLineChar(5, 70, *cursor, text_file.file_string);
	test_cursor.cursor_line_number = 5;
	test_cursor.cursor_line_char = 64;
	test_cursor.char_point = 120;
	AssertTextCursor(test_cursor, cursor);

	//TEST going over line bounds should not update bounds and line char shoudl adjust itself
	MoveCursorToLineAndLineChar(11, -5, *cursor, text_file.file_string);
	test_cursor.cursor_line_number = 11;
	test_cursor.cursor_line_char = 0;
	test_cursor.char_point = 126;
	AssertTextCursor(test_cursor, cursor);

	//TEST going over file loc shoudl bound us back
	MoveCursorToLineAndLineChar(text_file.file_loc.count + 10, 3, *cursor, text_file.file_string);
	test_cursor.cursor_line_number = text_file.file_loc.count-1;
	test_cursor.cursor_line_char = 0;
	test_cursor.char_point = text_file.file_string.text_string.count;
	AssertTextCursor(test_cursor, cursor);

	//TEST selected cursor should not move fixed select point
	cursor.fixed_select_line_number = 4;
	cursor.fixed_select_line_char = 12;
	cursor.fixed_select_char_point = 55;
	cursor.cursor_is_selecting = true;
	test_cursor = cursor;
	MoveCursorToLineAndLineChar(text_file.file_loc.count + 10, 3, *cursor, text_file.file_string);
	AssertTextCursor(test_cursor, cursor);

	//TEST fixed select is over right char bound should fixed select and not move cursor or bounds
	cursor.fixed_select_line_number = 5;
	cursor.fixed_select_line_char = 70;
	cursor.fixed_select_char_point = 123;
	MoveCursorToLineAndLineChar(text_file.file_loc.count + 10, 3, *cursor, text_file.file_string);
	test_cursor.cursor_is_selecting = true;
	test_cursor.fixed_select_line_number = 5;
	test_cursor.fixed_select_line_char = 64;
	test_cursor.fixed_select_char_point = 120;
	AssertTextCursor(test_cursor, cursor);

	//TEST fixed select is over right char bound and line bound
	cursor.fixed_select_line_number = text_file.file_loc.count + 50;
	cursor.fixed_select_line_char = 70;
	cursor.fixed_select_char_point = 123;
	MoveCursorToLineAndLineChar(0, 0, *cursor, text_file.file_string);
	test_cursor.cursor_is_selecting = true;
	test_cursor.char_point = 0;
	test_cursor.cursor_line_number = 0;
	test_cursor.cursor_line_char = 0;
	test_cursor.fixed_select_line_number = text_file.file_loc.count-1;
	test_cursor.fixed_select_line_char = 0;
	test_cursor.fixed_select_char_point = text_file.file_string.text_string.count;
	AssertTextCursor(test_cursor, cursor);

	//TEST fixed and cursor are out of bounds so we go to end of file and selection is cancelled
	cursor.fixed_select_line_number = text_file.file_loc.count + 50;
	cursor.fixed_select_line_char = 70;
	cursor.fixed_select_char_point = 123;
	MoveCursorToLineAndLineChar(text_file.file_loc.count + 10, 3, *cursor, text_file.file_string);
	test_cursor.cursor_is_selecting = false;
	test_cursor.char_point = text_file.file_string.text_string.count;
	test_cursor.cursor_line_number = text_file.file_loc.count-1;
	test_cursor.cursor_line_char = 0;
	test_cursor.fixed_select_line_number = text_file.file_loc.count-1;
	test_cursor.fixed_select_line_char = 0;
	test_cursor.fixed_select_char_point = text_file.file_string.text_string.count;
	AssertTextCursor(test_cursor, cursor);


	//TEST For single line file string
	single_fs : FileString = CreateTestSingleLineFileString();

	//TEST single line just cursor out of bounds
	s_cursor : TextCursor;
	s_cursor.left_char_bound = 0;
	s_cursor.right_char_bound = 10;
	test_cursor = s_cursor;
	MoveCursorToLineAndLineChar(10, 12, *s_cursor, single_fs, single_line=true);
	test_cursor.char_point = 10;
	test_cursor.cursor_line_char = 10;
	AssertTextCursor(test_cursor, s_cursor);

	//TEST with selection out of bounds
	s_cursor.cursor_is_selecting = true;
	s_cursor.fixed_select_line_char = 25;
	MoveCursorToLineAndLineChar(10, 12, *s_cursor, single_fs, single_line=true);
	test_cursor.cursor_is_selecting = false;
	test_cursor.char_point = 10;
	test_cursor.cursor_line_char = 10;
	test_cursor.fixed_select_line_number = 10;
	test_cursor.fixed_select_line_char = 10;
	AssertTextCursor(test_cursor, s_cursor);

	//TEST with selectino in bounds nothing changes
	s_cursor.cursor_is_selecting = true;
	s_cursor.fixed_select_line_char = 2;
	MoveCursorToLineAndLineChar(10, 8, *s_cursor, single_fs, single_line=true);
	test_cursor.cursor_is_selecting = true;
	test_cursor.char_point = 8;
	test_cursor.cursor_line_char = 8;
	test_cursor.cursor_line_number = 0;
	test_cursor.fixed_select_char_point = 2;
	test_cursor.fixed_select_line_char = 2;
	test_cursor.fixed_select_line_number = 0;
	AssertTextCursor(test_cursor, s_cursor);

} @UnitTest

CreateTestSingleLineFileString :: inline () -> FileString {
	single_fs : FileString;
	cfsd : CreateFileStringData;
	cfsd.total_allocated_bytes = 10;
	InitFileString(*single_fs, cfsd);
	s_string : string = "0000000000"; //10 zeros
	memcpy(single_fs.text_string.data, s_string.data, single_fs.total_allocated_bytes);
	single_fs.text_string.count = single_fs.total_allocated_bytes;
	return single_fs;
}

Test_MoveCursorToCharPoint :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	text_file := CreateTestTextFile(*ALL_NEXT_IDS, *ad.all_text_files);
	WriteFileString(text_file, CURSOR_TEST_TEXT);

	cursor : TextCursor;
	cursor.left_char_bound = 0;
	cursor.right_char_bound = 10;
	cursor.start_file_line_index = 0;
	cursor.end_file_line_index = 10;

	test_cursor : TextCursor = cursor;

	//TEST normal move cursor to char point should work
	MoveCursorToCharPoint(0, *cursor, text_file.file_string, reset_cursor=true);
	AssertTextCursor(test_cursor, cursor);

	MoveCursorToCharPoint(50, *cursor, text_file.file_string, reset_cursor=true);
	test_cursor.cursor_line_number = 4;
	test_cursor.cursor_line_char = 7;
	test_cursor.char_point = 50;
	AssertTextCursor(test_cursor, cursor);

	//TEST move left char bound by default
	MoveCursorToCharPoint(89, *cursor, text_file.file_string, reset_cursor=true);
	test_cursor.cursor_line_number = 5;
	test_cursor.cursor_line_char = 33;
	test_cursor.char_point = 89;
	test_cursor.left_char_bound += 24;
	test_cursor.right_char_bound += 24;
	AssertTextCursor(test_cursor, cursor);


	//TEST move line index by default center_line by default
	MoveCursorToCharPoint(130, *cursor, text_file.file_string, reset_cursor=true);
	test_cursor.cursor_line_number = 14;
	test_cursor.cursor_line_char = 1;
	test_cursor.char_point = 130;
	test_cursor.left_char_bound = 0;
	test_cursor.right_char_bound = 10;
	test_cursor.start_file_line_index += 9;
	test_cursor.end_file_line_index += 9;
	AssertTextCursor(test_cursor, cursor);


	//TEST go over the max file string text count
	MoveCursorToCharPoint(200, *cursor, text_file.file_string, reset_cursor=true);
	test_cursor.cursor_line_number = 25;
	test_cursor.cursor_line_char = 0;
	test_cursor.char_point = 198;
	test_cursor.left_char_bound = 0;
	test_cursor.right_char_bound = 10;
	test_cursor.start_file_line_index += 11;
	test_cursor.end_file_line_index += 11;
	AssertTextCursor(test_cursor, cursor);


	//TEST single line test
	single_fs : FileString = CreateTestSingleLineFileString();

	//TEST single line just cursor out of bounds
	s_cursor : TextCursor;
	s_cursor.left_char_bound = 0;
	s_cursor.right_char_bound = 10;
	test_cursor = s_cursor;
	MoveCursorToCharPoint(12, *s_cursor, single_fs, single_line=true, reset_cursor=true);
	test_cursor.char_point = 10;
	test_cursor.cursor_line_char = 10;
	AssertTextCursor(test_cursor, s_cursor);

	//TEST in bounds single line file string
	s_cursor.left_char_bound = 0;
	s_cursor.right_char_bound = 10;
	MoveCursorToCharPoint(5, *s_cursor, single_fs, single_line=true, reset_cursor=true);
	test_cursor.char_point = 5;
	test_cursor.cursor_line_char = 5;
	AssertTextCursor(test_cursor, s_cursor);

	s_cursor.left_char_bound = 0;
	s_cursor.right_char_bound = 10;
	MoveCursorToCharPoint(0, *s_cursor, single_fs, single_line=true, reset_cursor=true);
	test_cursor.char_point = 0;
	test_cursor.cursor_line_char = 0;
	AssertTextCursor(test_cursor, s_cursor);

} @UnitTest

Test_LineNumberOfCharPoint :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	text_file := CreateTestTextFile(*ALL_NEXT_IDS, *ad.all_text_files);
	WriteFileString(text_file, CURSOR_TEST_TEXT);

	//TEST normal line number
	line_number : int = LineNumberOfCharPoint(50, text_file.file_string.file_loc);
	AssertEquals(4, line_number);

	line_number = LineNumberOfCharPoint(105, text_file.file_string.file_loc);
	AssertEquals(5, line_number);

	line_number = LineNumberOfCharPoint(0, text_file.file_string.file_loc);
	AssertEquals(0, line_number);

	//TEST empty file_loc should give 0
	line_number = LineNumberOfCharPoint(0, .[""]);
	AssertEquals(0, line_number);

	line_number = LineNumberOfCharPoint(10, .[""]);
	AssertEquals(0, line_number);

	//TEST over the char point should return the last line
	line_number = LineNumberOfCharPoint(200, text_file.file_string.file_loc);
	AssertEquals(25, line_number);

	//WE MADE THIS an assertion so we avoid issues with files without file_loc
	//TEST empty file loc
	// line_number = LineNumberOfCharPoint(50, .[]);
	// AssertEquals(-1, line_number);

} @UnitTest

Test_StartCharPointOfLineNumber :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	text_file := CreateTestTextFile(*ALL_NEXT_IDS, *ad.all_text_files);
	WriteFileString(text_file, CURSOR_TEST_TEXT);

	//TEST normal line number
	slcp : int = StartCharPointOfLineNumber(0, text_file.file_string);
	AssertEquals(0, slcp);

	slcp = StartCharPointOfLineNumber(5, text_file.file_string);
	AssertEquals(56, slcp);

	slcp = StartCharPointOfLineNumber(20, text_file.file_string);
	AssertEquals(143, slcp);

	slcp = StartCharPointOfLineNumber(24, text_file.file_string);
	AssertEquals(text_file.file_string.text_string.count-1, slcp);

	//TEST line number eof
	slcp = StartCharPointOfLineNumber(25, text_file.file_string);
	AssertEquals(text_file.file_string.text_string.count, slcp);

	//TEST line number out of bounds
	slcp = StartCharPointOfLineNumber(26, text_file.file_string);
	AssertEquals(text_file.file_string.text_string.count, slcp);

	//TEST line number out of bounds
	slcp = StartCharPointOfLineNumber(100, text_file.file_string);
	AssertEquals(text_file.file_string.text_string.count, slcp);

	//TEST line number out of bounds
	slcp = StartCharPointOfLineNumber(-1, text_file.file_string);
	AssertEquals(0, slcp);

} @UnitTest

Test_SelectText :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	text_file := CreateTestTextFile(*ALL_NEXT_IDS, *ad.all_text_files);
	WriteFileString(text_file, CURSOR_TEST_TEXT);

	cursor : TextCursor;
	cursor.left_char_bound = 0;
	cursor.right_char_bound = 10;
	cursor.start_file_line_index = 0;
	cursor.end_file_line_index = 10;

	test_cursor : TextCursor = cursor;

	//TEST normal move cursor to char point should work
	SelectText(0, 14, *cursor, text_file.file_string);
	test_cursor.cursor_is_selecting = true;
	test_cursor.char_point = 14;
	test_cursor.cursor_line_char = 14;
	test_cursor.fixed_select_char_point = 0;
	test_cursor.fixed_select_line_char = 0;
	test_cursor.fixed_select_line_number = 0;
	test_cursor.left_char_bound += 4;
	test_cursor.right_char_bound += 4;
	AssertTextCursor(test_cursor, cursor);

	//TEST multi-line select
	SelectText(15, 41, *cursor, text_file.file_string);
	test_cursor.char_point = 41;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 3;
	test_cursor.cursor_is_selecting = true;
	test_cursor.fixed_select_char_point = 15;
	test_cursor.fixed_select_line_char = 0;
	test_cursor.fixed_select_line_number = 1;
	test_cursor.left_char_bound = 0;
	test_cursor.right_char_bound = 10;
	AssertTextCursor(test_cursor, cursor);

	//TEST end char point out of bounds shoudl get clamped
	//and line and end index should change
	SelectText(147, 200, *cursor, text_file.file_string);
	test_cursor.char_point = 198;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 25;
	test_cursor.cursor_is_selecting = true;
	test_cursor.fixed_select_char_point = 147;
	test_cursor.fixed_select_line_char = 4;
	test_cursor.fixed_select_line_number = 20;
	test_cursor.left_char_bound = 0;
	test_cursor.right_char_bound = 10;
	test_cursor.start_file_line_index += 20;
	test_cursor.end_file_line_index += 20;
	AssertTextCursor(test_cursor, cursor);

	//TEST start and end char point out of bounds shoudl get clamped
	//and then no selection so we do nothing
	SelectText(200, 210, *cursor, text_file.file_string);
	AssertTextCursor(test_cursor, cursor);

	//TEST start > end does nothing
	SelectText(15, 10, *cursor, text_file.file_string);
	AssertTextCursor(test_cursor, cursor);

	//TEST start == end does nothing
	SelectText(15, 15, *cursor, text_file.file_string);
	AssertTextCursor(test_cursor, cursor);


	//TEST single line test
	single_fs : FileString = CreateTestSingleLineFileString();

	//TEST single line just regular selection
	s_cursor : TextCursor;
	s_cursor.left_char_bound = 0;
	s_cursor.right_char_bound = 10;
	test_cursor = s_cursor;
	SelectText(0, 5, *s_cursor, single_fs, single_line=true);
	test_cursor.cursor_is_selecting = true;
	test_cursor.char_point = 5;
	test_cursor.cursor_line_char = 5;
	test_cursor.fixed_select_char_point = 0;
	test_cursor.fixed_select_line_char = 0;
	AssertTextCursor(test_cursor, s_cursor);

	//TEST single line cursor out of bounds
	SelectText(1, 12, *s_cursor, single_fs, single_line=true);
	test_cursor.cursor_is_selecting = true;
	test_cursor.char_point = 10;
	test_cursor.cursor_line_char = 10;
	test_cursor.fixed_select_char_point = 1;
	test_cursor.fixed_select_line_char = 1;
	AssertTextCursor(test_cursor, s_cursor);

	//TEST both out of bounds so nothing happens
	SelectText(12, 21, *s_cursor, single_fs, single_line=true);
	AssertTextCursor(test_cursor, s_cursor);

	//TEST == does nothing
	SelectText(5, 5, *s_cursor, single_fs, single_line=true);
	AssertTextCursor(test_cursor, s_cursor);

	//TEST start > end does nothing
	SelectText(6, 5, *s_cursor, single_fs, single_line=true);
	AssertTextCursor(test_cursor, s_cursor);


} @UnitTest

Test_MoveToLine :: () {
	ad : *AllData = InitAllData(,,unit_test_alloc);
	text_file := CreateTestTextFile(*ALL_NEXT_IDS, *ad.all_text_files);
	WriteFileString(text_file, CURSOR_TEST_TEXT);

	cursor : TextCursor;
	cursor.left_char_bound = 0;
	cursor.right_char_bound = 10;
	cursor.start_file_line_index = 0;
	cursor.end_file_line_index = 10;

	test_cursor : TextCursor = cursor;

	//TEST normal move to line
	MoveToLine(0, text_file.file_string, *cursor);
	AssertTextCursor(test_cursor, cursor);

	//TEST adjust bounds back when we move line
	cursor.left_char_bound = 5;
	cursor.right_char_bound = 15;
	MoveToLine(4, text_file.file_string, *cursor);
	test_cursor.char_point = 43;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 4;
	test_cursor.left_char_bound = 0;
	test_cursor.right_char_bound = 10;
	AssertTextCursor(test_cursor, cursor);

	//TEST Should move bounds in center
	MoveToLine(15, text_file.file_string, *cursor);
	test_cursor.char_point = 137;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 15;
	test_cursor.start_file_line_index = 10;
	test_cursor.end_file_line_index = 20;
	AssertTextCursor(test_cursor, cursor);

	//TEST out of bounds
	MoveToLine(26, text_file.file_string, *cursor);
	test_cursor.char_point = 198;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 25;
	test_cursor.start_file_line_index = 20;
	test_cursor.end_file_line_index = 30;
	AssertTextCursor(test_cursor, cursor);

	//TEST out of bounds
	MoveToLine(30, text_file.file_string, *cursor);
	test_cursor.char_point = 198;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 25;
	test_cursor.start_file_line_index = 20;
	test_cursor.end_file_line_index = 30;
	AssertTextCursor(test_cursor, cursor);

	//TEST out of bounds
	MoveToLine(-1, text_file.file_string, *cursor);
	test_cursor.char_point = 0;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 0;
	test_cursor.start_file_line_index = 0;
	test_cursor.end_file_line_index = 10;
	AssertTextCursor(test_cursor, cursor);


	//TEST out of bounds center line == false
	MoveToLine(26, text_file.file_string, *cursor, center_line=false);
	test_cursor.char_point = 198;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 25;
	test_cursor.start_file_line_index = 15;
	test_cursor.end_file_line_index = 25;
	AssertTextCursor(test_cursor, cursor);


	//TEST dont move cursor
	MoveToLine(6, text_file.file_string, *cursor, move_cursor=false);
	test_cursor.start_file_line_index = 1;
	test_cursor.end_file_line_index = 11;
	AssertTextCursor(test_cursor, cursor);


	//TEST reset selection if we move cursor
	cursor.cursor_is_selecting = true;
	MoveToLine(6, text_file.file_string, *cursor);
	test_cursor.cursor_is_selecting = false;
	test_cursor.char_point = 121;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 6;
	test_cursor.start_file_line_index = 1;
	test_cursor.end_file_line_index = 11;
	AssertTextCursor(test_cursor, cursor);


	//TEST dont touch selection if we don't move cursor
	cursor.cursor_is_selecting = true;
	MoveToLine(16, text_file.file_string, *cursor, move_cursor=false);
	test_cursor.cursor_is_selecting = true;
	test_cursor.char_point = 121;
	test_cursor.cursor_line_char = 0;
	test_cursor.cursor_line_number = 6;
	test_cursor.start_file_line_index = 11;
	test_cursor.end_file_line_index = 21;
	AssertTextCursor(test_cursor, cursor);


} @UnitTest

//TODO unit test dynamic string and also set text op console message although we do integration test so maybe no need
Test_DynamicString :: () {
	ds : DynamicString;
	test_allocated : int = 3;
	string_count : int = 0;
	InitDynamicString(*ds, test_allocated);
	AssertNotEquals(null, ds.text_string.data);
	AssertEquals(string_count, ds.text_string.count);
	AssertEquals(test_allocated, ds.total_allocated_bytes);

	MaybeResizeDynamicString(2, *ds);
	AssertEquals(test_allocated, ds.total_allocated_bytes);
	AssertEquals(string_count, ds.text_string.count);

	previous_data : *u8 = ds.text_string.data;
	MaybeResizeDynamicString(4, *ds);
	AssertNotEquals(previous_data, ds.text_string.data);
	AssertEquals(string_count, ds.text_string.count);
	test_allocated = 8;
	AssertEquals(test_allocated, ds.total_allocated_bytes);

	//test should not increase size
	first_string : string = "test";
	string_count = first_string.count;
	SetDynamicStringFromStart(first_string, *ds);
	AssertEquals(string_count, ds.text_string.count);
	AssertEquals(first_string, ds.text_string);
	AssertEquals(test_allocated, ds.total_allocated_bytes);

	//test should increase size
	previous_data = ds.text_string.data;
	second_string := "update allocated";
	string_count = second_string.count;
	test_allocated = 2*second_string.count;
	SetDynamicStringFromStart(second_string, *ds);
	AssertNotEquals(previous_data, ds.text_string.data);
	AssertEquals(string_count, ds.text_string.count);
	AssertEquals(second_string, ds.text_string);
	AssertEquals(test_allocated, ds.total_allocated_bytes);

	//test should not increase size
	third_string := " more";
	test_string := sprint("%0%0", second_string, third_string);
	string_count = test_string.count;
	AddDynamicString(third_string, *ds);
	AssertEquals(test_string, ds.text_string);
	AssertEquals(string_count, ds.text_string.count);
	AssertEquals(test_allocated, ds.total_allocated_bytes);

	//test should increase size
	previous_data = ds.text_string.data;
	fourth_string := " increase size";
	test_string = sprint("%0%0%0", second_string, third_string, fourth_string);
	string_count = test_string.count;
	test_allocated = 2*test_string.count;
	AddDynamicString(fourth_string, *ds);
	AssertNotEquals(previous_data, ds.text_string.data);
	AssertEquals(string_count, ds.text_string.count);
	AssertEquals(test_string, ds.text_string);
	AssertEquals(test_allocated, ds.total_allocated_bytes);

	//test a large resize to make sure free is working
	large_ds : DynamicString;
	before_resize : int = Kilobyte(50);
	InitDynamicString(*large_ds, before_resize);
	AssertNotEquals(null, large_ds.text_string.data);
	AssertEquals(0, large_ds.text_string.count);
	AssertEquals(before_resize, large_ds.total_allocated_bytes);
	previous_data = large_ds.text_string.data;
	after_resize : int = Kilobyte(100);
	MaybeResizeDynamicString(after_resize, *large_ds);
	AssertNotEquals(previous_data, large_ds.text_string.data);
	AssertEquals(0, large_ds.text_string.count);
	AssertEquals(2*after_resize, large_ds.total_allocated_bytes);

} @UnitTest

Test_CharPointToSplitLines :: () {
// Test_cpss :: () {
	tsl : TextSplitLine;
	tsl.line_char_count = 5;
	//TODO Write a test for this to test edge cases if we have only 1 line and such as a reminder
	sb : String_Builder;
	text_string : string = "01234\n012345678";
	split_string : [] string = String.split(text_string, "\n");
	AddSplitStringByLines(split_string[0], *tsl);

	selc : StartEndLineChar = CharPointToSplitSelc(0, 2, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(0, selc.end_line);
	AssertEquals(1, selc.end_line_char);

	//test going to last char
	selc = CharPointToSplitSelc(0, 4, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(0, selc.end_line);
	AssertEquals(3, selc.end_line_char);

	//test going to new line should not increment line and go to last char
	selc = CharPointToSplitSelc(0, 5, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(0, selc.end_line);
	AssertEquals(4, selc.end_line_char);

	//test going passed last char by more
	selc = CharPointToSplitSelc(0, 10, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(1, selc.end_line);
	AssertEquals(0, selc.end_line_char);

	//test start char going past leaves everything at 0
	selc = CharPointToSplitSelc(10, 5, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(0, selc.end_line);
	AssertEquals(0, selc.end_line_char);

	//test negative value
	selc = CharPointToSplitSelc(-1, 5, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(0, selc.end_line);
	AssertEquals(0, selc.end_line_char);

	//test 0 char count value
	selc = CharPointToSplitSelc(0, 0, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(0, selc.end_line);
	AssertEquals(0, selc.end_line_char);

	//test negative char count value
	selc = CharPointToSplitSelc(0, -1, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(0, selc.end_line);
	AssertEquals(0, selc.end_line_char);

	//Write a test for this to test edge cases if we have only 1 line and such as a reminder
	//not this adds as a new line so we have two \n from before to go voer
	AddSplitStringByLines(split_string[1], *tsl);

	//test make sure this highlights properly over multiple lines
	selc = CharPointToSplitSelc(3, 10, text_string, tsl);
	AssertEquals(0, selc.start_line);
	AssertEquals(3, selc.start_line_char);
	AssertEquals(3, selc.end_line);
	AssertEquals(1, selc.end_line_char);

	//test bounds to last char if we highlight over the end with multiple lines
	selc = CharPointToSplitSelc(6, 13, text_string, tsl);
	AssertEquals(2, selc.start_line);
	AssertEquals(0, selc.start_line_char);
	AssertEquals(3, selc.end_line);
	AssertEquals(3, selc.end_line_char);

} @UnitTest

Test_AddSplitLines :: () {
	tsl : TextSplitLine;
	tsl.line_char_count = 5;
	//TEST that we get an empty line when we add the boundary here since the next character we add should be on the next line
	//this is a convention since we want the cursor on the next line instead of the previous line simply as convention
	add_string := "01234";
	AddSplitStringByLines(add_string, *tsl);
	AssertEquals(2, tsl.split_lines.count);
	AssertEquals(add_string, tsl.split_lines[0].split_string);
	AssertEquals(0, tsl.split_lines[0].not_split_line_number);
	AssertEquals("", tsl.split_lines[1].split_string);
	AssertEquals(0, tsl.split_lines[1].not_split_line_number);

	//test that adding multiple lines keeps the same not split line and split properly based on line char count
	next_string := "012345678";
	AddSplitStringByLines(next_string, *tsl);
	AssertEquals(4, tsl.split_lines.count);
	AssertEquals(add_string, tsl.split_lines[2].split_string);
	AssertEquals(1, tsl.split_lines[2].not_split_line_number);
	AssertEquals("5678", tsl.split_lines[3].split_string);
	AssertEquals(1, tsl.split_lines[3].not_split_line_number);

} @UnitTest


AssertRuntimeSettings :: inline (test : RuntimeSettingsData, value : RuntimeSettingsData) {
	#insert #run AssertStruct(RuntimeSettingsData, "test", "value");
}
TEST_GENERATE_RUNTIME_SETTINGS :: "test_settings/test_generate_runtime_settings";
TEST_MISSING_RUNTIME_SETTINGS :: "test_settings/missing_runtime_settings";
TEST_INVALID_RUNTIME_SETTINGS :: "test_settings/invalid_runtime_settings";
Test_RuntimeSettings :: () {
	test_text_files : [..] TextFile;
	//I think this is done by default, but just in case...
	test_text_files.allocator = unit_test_alloc;

	file_is_deleted := file_delete(TEST_GENERATE_RUNTIME_SETTINGS);

	generate_success : bool = GenerateRuntimeSettingsFile(RuntimeSettingsData.{}, TEST_GENERATE_RUNTIME_SETTINGS);
	AssertEquals(true, generate_success);
	generate_file_exists : bool = file_exists(TEST_GENERATE_RUNTIME_SETTINGS);
	AssertEquals(true, generate_file_exists);

	rsr : RuntimeSettingsReturn = 
		ParseRuntimeSettingsFile(*test_text_files, TEST_GENERATE_RUNTIME_SETTINGS);
	AssertEquals(true, rsr.success);
	AssertEquals(0, rsr.error_msg.count);
	AssertRuntimeSettings(.{}, rsr.new_settings);

	//TEST Parse Missing settings should set to default
	missing : RuntimeSettingsReturn = 
		ParseRuntimeSettingsFile(*test_text_files, TEST_MISSING_RUNTIME_SETTINGS);
	AssertEquals(true, missing.success);
	AssertEquals(0, missing.error_msg.count);
	check_missing : RuntimeSettingsData;
	check_missing.default_font_size = 20;
	check_missing.default_font_color.r = 2/255.0;
	check_missing.default_font_color.g = 3/255.0;
	check_missing.default_font_color.b = 4/255.0;
	check_missing.default_font_color.a = 0.6;
	AssertRuntimeSettings(check_missing, missing.new_settings);


	//TEST Invalid settings should return invalid and default
	invalid : RuntimeSettingsReturn = 
		ParseRuntimeSettingsFile(*test_text_files, TEST_INVALID_RUNTIME_SETTINGS);
	AssertEquals(false, invalid.success);
	AssertEquals(true, invalid.error_msg.count > 0);

	//NOTE : 


	file_is_deleted = file_delete(TEST_GENERATE_RUNTIME_SETTINGS);
	AssertEquals(true, file_is_deleted);

} @UnitTest

TEST_GENERATE_STARTUP_SETTINGS :: "test_settings/test_generate_startup_settings";
Test_StartupSettings :: () {
	file_is_deleted := file_delete(TEST_GENERATE_STARTUP_SETTINGS);

	generate_success : bool = GenerateStartupSettingsFile(StartupSettingsData.{}, TEST_GENERATE_STARTUP_SETTINGS);
	AssertEquals(true, generate_success);
	generate_file_exists : bool = file_exists(TEST_GENERATE_STARTUP_SETTINGS);
	AssertEquals(true, generate_file_exists);

	rsr : StartupSettingsReturn = ParseStartupSettingsFile(TEST_GENERATE_STARTUP_SETTINGS);
	AssertEquals(true, rsr.success);
	AssertEquals(0, rsr.error_msg.count);
	AssertStructEquals(StartupSettingsData.{}, rsr.new_settings);

	file_is_deleted = file_delete(TEST_GENERATE_STARTUP_SETTINGS);
	AssertEquals(true, file_is_deleted);

} @UnitTest

TEST_GENERATE_INPUT_MAPPING :: "test_settings/test_generate_input";
TEST_MISSING_INPUT_MAPPINGS :: "test_settings/test_missing_input_mappings";
TEST_INVALID_INPUT_MAPPINGS :: "test_settings/invalid_input_mappings";
TEST_INVALID_JSON :: "test_settings/invalid_json";
Test_InputMappings :: () {
	//DOC : Delete the files here just in case they were leftover from a failed test before.
	//Otherwise we would read them in during this test and not generate them properly.
	file_is_deleted := file_delete(TEST_GENERATE_INPUT_MAPPING);
	file_is_deleted = file_delete(TEST_MISSING_INPUT_MAPPINGS);

	test_text_files : [..] TextFile;
	//I think this is done by default, but just in case...
	test_text_files.allocator = unit_test_alloc;

	test_game_input : GameInput;
	//TEST setup game input with defaults since we have no file
	//NOTE : This prints out a message that the file could not be opened which is good since we have not generated the file yet
	SetupGameInputMappings(*test_game_input, *test_text_files, TEST_GENERATE_INPUT_MAPPING);
	for default_im : DEFAULT_INPUT_MAPPINGS {
		test_im : InputMapping = test_game_input.game_input_mappings[it_index];
		AssertEquals(default_im.input_map_type, test_im.input_map_type);
		AssertEquals(default_im.keyboard_maps.count, test_im.keyboard_maps.count);
		for default_key : default_im.keyboard_maps {
			AssertEquals(default_key.key_code, test_im.keyboard_maps[it_index].key_code);
			AssertEquals(default_key.modifier_flags.packed, test_im.keyboard_maps[it_index].modifier_flags.packed);
		}
	}

	//TEST generated and read in that all is valid
	generate_success : bool = GenerateInputMappingsFile(DEFAULT_INPUT_MAPPINGS, TEST_GENERATE_INPUT_MAPPING);
	AssertEquals(true, generate_success);
	generate_file_exists : bool = file_exists(TEST_GENERATE_INPUT_MAPPING);
	AssertEquals(true, generate_file_exists);

	pimr : ParsedInputMappingReturn = 
		ParseInputMappingsFile(*test_text_files, TEST_GENERATE_INPUT_MAPPING);
	AssertEquals(true, pimr.success);
	AssertEquals(0, pimr.error_msg.count);
	AssertEquals(DEFAULT_INPUT_MAPPINGS.count, pimr.parsed_input_mappings.count);
	for DEFAULT_INPUT_MAPPINGS {
		AssertEquals(INPUT_MAP_TYPE_NAMES[it_index], pimr.parsed_input_mappings[it_index].command);
		AssertEquals(it.keyboard_maps.count, pimr.parsed_input_mappings[it_index].keyboard_keys.count);
	}

	//TEST validate generated default input mappings
	valid, error_msg := ValidateParsedInputMappings(pimr.parsed_input_mappings);
	AssertEquals(true, valid);
	AssertEquals(0, error_msg.count);

	//TEST update the parsed settings, push them to see
	updated_keys := string.["ctrl+alt+shift+d", "f4"];
	for * pimr.parsed_input_mappings {
		it.keyboard_keys = updated_keys;
	}

	update_key_maps : [2] KeyboardMap;
	update_key_maps[0].key_code = #char "D";
	update_key_maps[0].modifier_flags.shift_pressed = true;
	update_key_maps[0].modifier_flags.alt_pressed = true;
	update_key_maps[0].modifier_flags.ctrl_pressed = true;
	update_key_maps[1].key_code = .F4;
	AssertInputMappingUpdated :: inline (update_key_maps : [] KeyboardMap, test_game_input : GameInput) {
		for test_im : test_game_input.game_input_mappings {
			AssertEquals(INPUT_MAP_TYPE_ENUMS[it_index], test_im.input_map_type);
			AssertEquals(updated_keys.count, test_im.keyboard_maps.count);
			for update_key_maps {
				AssertEquals(it.key_code, test_im.keyboard_maps[it_index].key_code);
				AssertEquals(it.modifier_flags.packed, test_im.keyboard_maps[it_index].modifier_flags.packed);
			}
		}
	}

	//they changed and then generate file with update input mappings
	//test update game input mappings with default
	valid, error_msg = UpdateGameInputMappings(pimr.parsed_input_mappings, *test_game_input);
	AssertEquals(true, valid);
	AssertEquals("", error_msg);

	//TEST removing some parsed input mappings to see that it does not update them
	pimr.parsed_input_mappings.count -= 3;
	valid, error_msg = UpdateGameInputMappings(pimr.parsed_input_mappings, *test_game_input);
	AssertEquals(true, valid);
	AssertEquals("", error_msg);
	AssertInputMappingUpdated(update_key_maps, test_game_input);
	pimr.parsed_input_mappings.count += 3;

	//TEST update to make invalid keyboard_keys and commands and then check that we did not update the game input
	//note that we test ValidateParsedInputMappings in here since it fails
	//we test invalid keycode here and also missing keycode
	invalid_keys := string.["invalid", "ctrl+alt"];
	for * pimr.parsed_input_mappings {
		it.keyboard_keys = invalid_keys;
	}
	valid, error_msg = UpdateGameInputMappings(pimr.parsed_input_mappings, *test_game_input);
	AssertEquals(false, valid);
	im_errors : [] string = String.split(error_msg, "\n");
	AssertEquals(2*pimr.parsed_input_mappings.count, im_errors.count-1); //-1 because split returns empty string at the end if no remainder
	AssertInputMappingUpdated(update_key_maps, test_game_input);

	//TEST can only have 1 key_code per command
	invalid_2_key_codes := string.["ctrl+shift+d+f3"];
	for * pimr.parsed_input_mappings {
		it.keyboard_keys = invalid_2_key_codes;
	}
	valid, error_msg = UpdateGameInputMappings(pimr.parsed_input_mappings, *test_game_input);
	AssertEquals(false, valid);
	im_errors = String.split(error_msg, "\n");
	AssertEquals(pimr.parsed_input_mappings.count, im_errors.count-1); //-1 because split returns empty string at the end if no remainder
	AssertInputMappingUpdated(update_key_maps, test_game_input);


	invalid_command : string = "INVALID_COMMAND";
	for * pimr.parsed_input_mappings {
		it.command = invalid_command;
		it.keyboard_keys = updated_keys;
	}
	//note that we test ValidateParsedInputMappings in here since it fails
	valid, error_msg = UpdateGameInputMappings(pimr.parsed_input_mappings, *test_game_input);
	AssertEquals(false, valid);
	im_errors = String.split(error_msg, "\n");
	AssertEquals(pimr.parsed_input_mappings.count, im_errors.count-1); //-1 because split returns empty string at the end if no remainder
	AssertInputMappingUpdated(update_key_maps, test_game_input);
	for * pimr.parsed_input_mappings {
		it.command = INPUT_MAP_TYPE_NAMES[it_index];
	}

	file_is_deleted = file_delete(TEST_GENERATE_INPUT_MAPPING);
	AssertEquals(true, file_is_deleted);

	//TEST parsing with invalid name but valid json so we make sure it does not update
	//it will parse but not update
	pimr = ParseInputMappingsFile(*test_text_files, TEST_INVALID_INPUT_MAPPINGS);
	AssertEquals(true, pimr.success);
	valid, error_msg = UpdateGameInputMappings(pimr.parsed_input_mappings, *test_game_input);
	AssertEquals(false, valid);
	im_errors = String.split(error_msg, "\n");
	AssertEquals(1, im_errors.count-1); //-1 because split returns empty string at the end if no remainder

	//TEST invalid json, this is just missing a comma but we assume jaison does it's job otherwise
	pimr = ParseInputMappingsFile(*test_text_files, TEST_INVALID_JSON);
	AssertEquals(false, pimr.success);
	AssertEquals(true, pimr.error_msg.count > 0);


	//TODO Test input mappings file with mostly missing settings
	//should update the settings we have but also keep all the old settings
	missing_inputs : [3] InputMapping;
	missing_inputs[0].input_map_type = .TEXT_DEBUG_TOGGLE;
	missing_inputs[0].keyboard_maps = .[.{xx #char "M", .{ctrl_pressed=true}}];
	missing_inputs[1].input_map_type = .TEXT_DISASM_TOGGLE;
	missing_inputs[1].keyboard_maps = .[.{.ENTER, .{}}];
	missing_inputs[2].input_map_type = .DEBUG_WATCH_EDIT;
	missing_inputs[2].keyboard_maps = .[.{.BACKSPACE, .{alt_pressed=true}}];

	generate_success = GenerateInputMappingsFile(missing_inputs, TEST_MISSING_INPUT_MAPPINGS);
	AssertEquals(true, generate_success);
	input_missing_file_exists : bool = file_exists(TEST_MISSING_INPUT_MAPPINGS);
	AssertEquals(true, input_missing_file_exists);

	pimr = ParseInputMappingsFile(*test_text_files, TEST_MISSING_INPUT_MAPPINGS);
	AssertEquals(true, pimr.success);
	AssertEquals(0, pimr.error_msg.count);
	AssertEquals(missing_inputs.count, pimr.parsed_input_mappings.count);
	valid, error_msg = UpdateGameInputMappings(pimr.parsed_input_mappings, *test_game_input);
	AssertEquals(true, valid);
	AssertEquals("", error_msg);

	for test_im : test_game_input.game_input_mappings {
		//Skipping over missing inputs
		for missing_inputs if test_im.input_map_type == it.input_map_type {
			continue test_im;
		}

		//Test that old input are still the updated ones
		AssertEquals(INPUT_MAP_TYPE_ENUMS[it_index], test_im.input_map_type);
		AssertEquals(updated_keys.count, test_im.keyboard_maps.count);
		for update_key_maps {
			AssertEquals(it.key_code, test_im.keyboard_maps[it_index].key_code);
			AssertEquals(it.modifier_flags.packed, test_im.keyboard_maps[it_index].modifier_flags.packed);
		}
	}
	for missing_i : missing_inputs {
		game_im : InputMapping = test_game_input.game_input_mappings[missing_i.input_map_type];
		AssertEquals(missing_i.input_map_type, game_im.input_map_type);
		AssertEquals(missing_i.keyboard_maps.count, game_im.keyboard_maps.count);
		for missing_i.keyboard_maps {
			AssertEquals(it.key_code, game_im.keyboard_maps[it_index].key_code);
			AssertEquals(it.modifier_flags.packed, game_im.keyboard_maps[it_index].modifier_flags.packed);
		}
	}

	file_is_deleted = file_delete(TEST_MISSING_INPUT_MAPPINGS);
	AssertEquals(true, file_is_deleted);

} @UnitTest

AssertInputMappings :: inline (
	test_inputs : [] InputMapping,
	game_inputs : [] InputMapping)
{
	count_equal := AssertEquals(test_inputs.count, game_inputs.count);
	if !count_equal return;
	for test_im : test_inputs {
		game_im : InputMapping = game_inputs[test_im.input_map_type];
		AssertEquals(test_im.input_map_type, game_im.input_map_type);
		AssertEquals(test_im.keyboard_maps.count, game_im.keyboard_maps.count);
		for test_im.keyboard_maps {
			AssertEquals(it.key_code, game_im.keyboard_maps[it_index].key_code);
			AssertEquals(it.modifier_flags.packed, game_im.keyboard_maps[it_index].modifier_flags.packed);
		}
	}
}