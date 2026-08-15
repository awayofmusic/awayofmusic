/*DOC : Currently this is used for text op_space but maybe it can be used for all op space data over time.
I am not sure how well that works overall because op space are connected to everything but let's see
and then we can separate files as needed maybe even by op space type eventually.
*/

/*Calculation logic
This is for watch_pool_max_size which is used for the binary tree
expressions use in the watch window rows.

  20 nodes per 100 char and we allow 
  watch_name_string_max_size = 1kb so 1000 chars
  so 20 nodes * (1000/100) (ie 10 * 100chars = 1000chars)
  then 20*(1000/100) * size_of(BinaryNode) = 32000 bytes = 32kb
  5 * 32kb = 160kb (5 is safety factor)
  6 * 32kb = 192kb (6 safety factor)
  10 * 32kb = 320kb (10 safety factor)

  since watch_name_string_max_size <= 1kb
  then lets say we have 1 letter chars and 1 char binary ops
  so that would be 500 letter chars and 500 binary ops
  so 1000 nodes = 1000 * size_of(BinaryNode)
  size_of(BinaryNode) = 160 bytes at time of this note writing
  160bytes * 1000 = 160 000 bytes = 160kb

  SO we use 6 safety factor to have slightly higher than max
  theoretical limit just in case.
  NOTE : We could use 10 or more later if we need to add more things to this pool
  in case we include more data in each watch window row later.

  Interesting precise data transfer range
  1kb string -> 0-160kb binary nodes

  Technically if we used different BinaryNode(data) then we could
  reduce the size of the nodes since we don't need all the info that
  we need from the compiler. BUT then we would also have to possibly
  rewrite ParseExpression which is not worth it imo.

Logic for watch_name_string_max_size
	I tested some of my longer debug watch window lines and they
	were all < 100 chars. so I did 10x and 1000 chars seems reasonable
	for 1 debug window row. If not, this way we can easily multiply to
	2 or 3 kb which would automatically increase the size of watch_pool_max_size

NOTE : We store the string in watch_pool so needs to be greater than max technically
ACTUALLY we don't store the string in watch_pool anymore but will still leave greate
for general resilience
*/
//TODO We could just use Kilobytes(200) but current one is slightly less, why not.
// watch_pool_size : int = Kilobytes(200);
// watch_pool_size : int = 5*20*10*size_of(BinaryNode);
//Making this constant and using below, this way if increase the max
//watch_name_string_max_size it will automatically increase the size
//of the watch_pool_max_size which corresponds to it with this calculation.
//TODO Could pull this out and make it a global constant.
//Having it in here allows us to change it per MusicSpace eventually
//and then we can set it at runtime if we want more. Could also update the max
//if we reach max... but then we'd have to update all the strings...
//Will leave it for now but if constant is fine later, then pull this out.
//OR we pull it out now and then can put it in later... put it near WatchData if we pull it out
watch_name_string_max_size : int : #run Kilobytes(1);
watch_pool_max_size : int :
	6*20*(watch_name_string_max_size/100)*size_of(BinaryNode);
// watch_pool_max_size : int :
// 	10*20*(watch_name_string_max_size/100)*size_of(BinaryNode);
//We could also put this in a struct like below if that helps for some reason... or not
// using WATCH_DATA_SETTINGS := WatchDataSettings.{};
// WatchDataSettings :: struct {
// 	watch_name_string_max_size : int : #run Kilobytes(1);
// 	watch_pool_max_size : int :
// 		6*20*(watch_name_string_max_size/100)*size_of(BinaryNode);
// }
TEST_MY_SIMPLE_POOL :: true;
WatchData :: struct {
	//TODO Change to name_str, or watch_name or full_name now with display_name
	name : string;
	display_name : string;
	//TODO can store value and type here instead and just store
	//error in the value string and set is_error so we know but
	//maybe that is even unnecessary overall since we just print
	//the message out at that point.
	value_str : string;
	type_str : string;

	is_error : bool;

	/*DOC : This keeps track of dropdowns so we know what rows to indent
	and by how much and also where to remove until since we would only
	remove rows below this one with watch_indent > than this one.
	If we hit one that is <= this one then it is at the same level and we don't remove it. 
	If watch_indent != 0, then we cannot edit the name.
	*/
	watch_indent : int;
	//TODO We can remove both of these now since we just do it in the rendering loop
	// top_index : int;
	// rel_top_index : int;
	// drop_data : [] WatchData;

	/*TODO ACTUALLY we can but asm_op in union with (node,watch_pool)
	size_of(MusicOperand)=40

	size_of(*BinaryNode)=8
	size_of(Flat_Pool)=40

	size_of(Resizable_Array)=40

	With union itll be 48 bytes so we only waste 8 bytes
	when we have the ASM_OPERAND instead of adding a constant 40 bytes.
	*/
	//TODO Technically we can store this in *BinaryNode and put
	//that in watch_pool but we can't parse it normally since
	//it is asm syntax which is different from code expression.
	//So we separate for clarity and to avoid weird issues.
	//This takes up more memory in favor of clarity and reduced potential errors.
	//Use this if we have ASM_OPERAND
	// union {
	// struct {
	// 	asm_op : MusicOperand;
	// 	t_info : *TypeInfo;
	// }
	// struct {
		node : *BinaryNode;
		//NOTE : We store the name and the expression nodes in the watch_pool here.
		//This makes sense because the expression binary nodes are dependent on the
		//watch_name, so when we edit the watch name we always want to edit the binary nodes.
		//IF we can update the expression without updating the name,
		//then I could split it for that case but that does not happen now.
		/*TODO REMINDER : Eventually we will not need this since the CompilationData should have a pool/resizable_array for 
		expression nodes and can reset that and then we can just do it with watch_cd. The problem right now
		is that the Compiler uses that and I want to store all the nodes for now but likely will just have 
		1 allocator and reset it whenever we get a new expression. Then the compiler will do the same since
		we don't want anything stored after the statement is parsed. If we want to store more then we can
		store it in the given allocator for tests and such to verify expressions/statements after but that maybe
		be unnecessary as well so we will see.
		NOTE : This is a test of MySimplePool, so we leave Flat_Pool in case it does not work but MySimplePool
		can allocate data from another allocate but it cannot be freed or anything
		*/
		#if TEST_MY_SIMPLE_POOL watch_pool : MySimplePool;
		else watch_pool : Flat_Pool;
		//TODO We can create this on the stack
		//with *watch_pool and flat_pool_allocator_proc
		// watch_alloc : Allocator;
	// }
	// }
}
/*I am leaving both cases for now as I Am not sure which one I want.
It makes more sense in my head to keep the watch_name data separate so that
we don't make any weird mistakes with it later in case we have to
add more data to the watch pool but I will leave both cases here for now just in case.
*/
KEEP_WATCH_NAME_IN_WATCH_POOL :: false;
/*TODO AllData variables used are constant so technically we can pull it out
but I will leave it in case we make those variables not constant eventually.
*/
MakeWatchData :: inline () -> WatchData {
	wd : WatchData;
	//MEMORY LEAK Also this creates a pool that does uses it's own allocator so that
	//needs to be reused eventually. Right now it's global in-game but not in tests
	//We could reuse it in test though or free it at the end.
	//ALSO We could make our own allocator and just get memory from the text op space allocator
	//and make a very simple allocator that uses that memory and can be reset easily
	#if TEST_MY_SIMPLE_POOL {
	InitMySimplePool(*wd.watch_pool, watch_pool_max_size);
	} else {
	init(*wd.watch_pool, watch_pool_max_size);
	}
	//TODO If we do not allocate the watch_name in the watch_pool, then
	//we just need to do alloc_string here and in ResetWatchData
	//I think we can use the external allocator for TextOpSpaceData 
	#if KEEP_WATCH_NAME_IN_WATCH_POOL {
	wd.name.data = cast(*u8) get(*wd.watch_pool, watch_name_string_max_size);
	// wd.name.data = alloc_string(watch_name_string_max_size);
	//string count = 0 from initialization
	wd.name.count = 0;
	} else {
	//Since we reuse the watch_data forever, we only need to alloc this once.
	//We use the default allocator and then leave it here forever.
	wd.name = alloc_string(watch_name_string_max_size);
	wd.name.count = 0;		
	}
	//Since we reuse watch_data, we allocate this once and forget about it.
	wd.value_str = alloc_string(watch_name_string_max_size);
	wd.value_str.count = 0;
	wd.type_str = alloc_string(watch_name_string_max_size);
	wd.type_str.count = 0;

	return wd;
}
IsWatchDroppable :: inline (wd : WatchData) -> bool {
	is_droppable : bool = wd.node != null && wd.node.code_ir.t_info != null &&
		AllOrEquals(wd.node.code_ir.t_info.type_enum,
		.[.ARRAY,.STRUCT,.NEUME,.TANO]);
	return is_droppable;
}
IsDroppedRow :: inline (wd : WatchData) -> bool {
	is_drop_row : bool = wd.watch_indent > 0;
	return is_drop_row;
}
/*NOTE : This is a convenience function for tests. Maybe we can put it in
thegame_test instead of here. Maybe the allocators will change later and also
the in-game functionality is different but we can always set the watch
data with the in game actions as well.

TODO Maybe we need to pass in an allocator eventually.
*/
AddWatchDataForTest :: inline (
	watch_names : [] string,
	text_op : *TextOpSpaceData)
{
	for watch_names {
		last_wd : *WatchData = peek_pointer(text_op.watch_data_rows);
		SetWatchName(last_wd, it);

		//TODO We could do evaluation as compile-time if needed but its just 1 line loop
		//and sometimes we don't want to evaluate since we want the test to check if it's being evaluated in-game properly.

		AddWatchData(text_op);
	}
}
/*DOCU : We do the same thing as DebugCallFrame and store the pool directly in this array
  so when we get a new value we just increment count and if we need a new one then we create it.
  This way we don't have to put anything anywhere else and we don't need to reset any allocators for
  storing the nodes.

  TODO Should we make a StackPool and also use that for debug_call_stack and anything else with same structure?
  We could but the MakeWatchData and ResetWatchData in here are still unique.
  We could pass them in even at compile-time but let's see if/how we use this pattern before doing that.
  ALSO to remove it is unique since we call array_ordered_remove_by_index but
  maybe would call something different for a different StackPool

DOCU : We reset on delete so everything in watch_data_pool is already reset and we can just grab it.
*/
AddWatchData :: inline (
	text_op : *TextOpSpaceData) 
-> *WatchData 
{
	watch_data : *WatchData = array_add(*text_op.watch_data_rows);
	#if 1 {
	watch_data.* = PopOrMakeWatchData(text_op);
	} else {
	//TODO Remove this if above works and we actually reuse it
	if text_op.watch_data_pool.count > 0 {
		watch_data.* = pop(*text_op.watch_data_pool);
	} else {
		watch_data.* = MakeWatchData();
	}
	}
	return watch_data;
}
PopOrMakeWatchData :: inline (text_op : *TextOpSpaceData) -> WatchData {
	watch_data : WatchData;
	if text_op.watch_data_pool.count > 0 {
		watch_data = pop(*text_op.watch_data_pool);
		//TODO Could reset the name here instead of delete if that is better
		//in terms of adding/removing watch datas.
		ResetWatchData(*watch_data, reset_name=true);
	} else {
		watch_data = MakeWatchData();
	}
	return watch_data;
}
//TODO For batch removal we can have a different function
//that moves a bunch over to pool at once.
RemoveWatchData :: inline (i : int, text_op : *TextOpSpaceData) {
	watch_data : WatchData = text_op.watch_data_rows[i];
	//TODO Can do this when we add so we can do a memcpy here
	//directly for bulk removal
	// ResetWatchData(*watch_data, reset_name=true);
	array_add(*text_op.watch_data_pool, watch_data);

	//TODO Can do this with a memcpy for efficiency
	//OR DO BATCH REMOVAL OF WATCH DATA WITH memcpy instead
	array_ordered_remove_by_index(*text_op.watch_data_rows, i);
}
RemoveWatchRowRange :: inline (start_index : int, r_count : int, text_op : *TextOpSpaceData) {
	//We return here if we have no rows or to prevent deletion of the last row
	if r_count <= 0 || 
		start_index == text_op.watch_data_rows.count-1 
	{
		return;
	}
	end_index : int = start_index + r_count;
	//We check less than rows.count-1 so we don't remove last row
	assert(start_index >= 0 && start_index < text_op.watch_data_rows.count-1);
	assert(end_index >= 0 && end_index < text_op.watch_data_rows.count);

	//TODO Can easily optimize this now with a memcpy for efficiency
	//and just do 1 memcpy to the pool and then memcpy the other watch rows back in place in the array.
	for 1..r_count {
		RemoveWatchData(start_index, text_op);
	}

	//sanity check to make sure we always have 1 extra row for input
	assert(text_op.watch_data_rows.count >= 1);
}
//TODO Can use this if needed. It is just the logic to check if in sub-row which we only use to get sub row count right now.
IsWatchSubRow :: inline (sub_index : int, text_op : *TextOpSpaceData, watch_indent : int) -> bool {
	in_sub_row : bool = 
		sub_index < text_op.watch_data_rows.count-1 &&
		text_op.watch_data_rows[sub_index].watch_indent > watch_indent;
	return in_sub_row;
}
GetSubRowCount :: inline (row_index : int, text_op : *TextOpSpaceData, watch_indent : int) -> int {
	start_index : int = row_index + 1;
	count : int = 0;
	while IsWatchSubRow(start_index+count, text_op, watch_indent) {
		count += 1;
	}		
	return count;
}
RemoveWatchSubRows :: inline (row_index : int, text_op : *TextOpSpaceData, watch_indent : int) {
	//We return here to prevent deletion of the last row
	if row_index == text_op.watch_data_rows.count-1 return;
	assert(row_index >= 0 && row_index < text_op.watch_data_rows.count-1);
	count : int = GetSubRowCount(row_index, text_op, watch_indent);
	if count > 0 {
		sub_start_index : int = row_index + 1;
		RemoveWatchRowRange(sub_start_index, count, text_op);
	}
}
//NOTE : We reset and then grab data since the watch_name_string
//is stored at the beginning of the pool we grab it again there.
//The expression depends on watch_name string so it makes sense to store it in the same place.
//Whenever we update the watch_name we want to also update the expression nodes.
//IF we can update the expression without updating the name,
//then I could split up the data for the name and the expression nodes 
//but that does not happen now.
ResetWatchData :: inline (wd : *WatchData, $reset_name : bool = false) {
	wd.node = null;
	//TODO Not sure we need a memset here but just in case to avoid issues with binary tree.
	#if TEST_MY_SIMPLE_POOL {
	ResetMySimplePool(*wd.watch_pool);
	} else {
	reset(*wd.watch_pool, true);
	}
	//TODO If we split string from watch_pool memory, then we don't have to get here.
	#if reset_name {
		#if KEEP_WATCH_NAME_IN_WATCH_POOL {
		wd.name.data = cast(*u8) get(*wd.watch_pool, watch_name_string_max_size);
		wd.name.count = 0;
		} else {
		wd.name.count = 0;
		wd.display_name.count = 0;	
		wd.watch_indent = 0;	
		// wd.rel_top_index = 0;
		}
	}
	//TODO We should just have value and type here instead of error
	// ResetWatchError(wd);
	wd.is_error = false;
	wd.value_str.count = 0;	
	wd.type_str.count = 0;
}
// ResetWatchError :: inline (wd : *WatchData) {
// 	wd.is_error = false;
// 	wd.error_msg.count = 0;	
// }
//TODO Could just pass in watch_name_string_max_size instead of the *AllData
SetWatchError :: inline (wd : *WatchData, err_msg : string) {
	wd.is_error = true;
	SetWatchValue(wd, err_msg);
}
//TODO We could make this meta and get the struct names but since it's
//only 3 cases right now I will leave it. We also might change between functions eventually.
//I don't want to generalize to string copy function because then i think it
//makes it more prone to error on what the max size is long term.
SetWatchName :: inline (wd : *WatchData, name : string) {
	s_count : int = name.count;
	if name.count > watch_name_string_max_size {
		s_count = watch_name_string_max_size;
	}
	memcpy(wd.name.data, name.data, s_count);
	wd.name.count = s_count;	
	//By default this is name and we can set it externally if needed.
	wd.display_name = wd.name;
}
SetWatchValue :: inline (wd : *WatchData, value : string) {
	s_count : int = value.count;
	if value.count > watch_name_string_max_size {
		s_count = watch_name_string_max_size;
	}
	memcpy(wd.value_str.data, value.data, s_count);
	wd.value_str.count = s_count;
}
SetWatchType :: inline (wd : *WatchData, type : string) {
	s_count : int = type.count;
	if type.count > watch_name_string_max_size {
		s_count = watch_name_string_max_size;
	}
	memcpy(wd.type_str.data, type.data, s_count);
	wd.type_str.count = s_count;
}
/*TODO I think this needs a text_file_id passed in. We could have selected_text_op in all_data as well.
But I think passing it in is more flexible so we can do multiple things at once later if needed.
Technically this only needs the compilation data and the execution info because it only needs registers and ram
TODO Write some simple tests here for cases in VisitWatchNodes

NOTES
	- This only gets called while were in debug mode so we don't have to check that in here and can assume
	that there is some ram or registers associated to the text_op space or executable that is running.
*/
EvaluateWatchData :: inline (
	watch_index : int,
	text_op : *TextOpSpaceData,
	all_data : *AllData, 
	reset_data : bool) 
{
	watch_data : *WatchData = *text_op.watch_data_rows[watch_index];
	watch_cd : *CompilationData = text_op.watch_cd;

	//TODO We avoid evluating something without a name since this should never happen since only
	//the last row should be empty and we should always be skipping over that row or filtering it out.
	//TODO We could make this an if and log the error as well and return to avoid crashing here.
	assert(watch_data.name.count > 0);
	if reset_data {
		//We have to reset here so we can recompute the expression nodes in watch_pool
		//We don't reset the name because we need to parse based on the name
		ResetWatchData(watch_data, reset_name=false);
		ResetCodeLexer(*watch_cd.lexer);
		//TODO We reset them all for good measure but we could just do the ones we need. 
		#insert #run SetResizableArrays(CompilationData, 
		"array_reset_keeping_memory(*watch_cd.%);\n");

		//NOTE : Technically this can't happen because we put the old string back for empty watch_rows
		//OR we could delete them, but just in case so we don't evaluate unnecessarily.
		if watch_data.name.count == 0 return;

		//TODO ALSO check that lexer_tokens.count > 0 ie empty string
		LexCodeTokens(*watch_cd.lexer, watch_data.name,,temp);
		if watch_cd.lexer.lexer_errors.all_compiler_errors.count > 0 {
			SetWatchError(watch_data, watch_cd.lexer.lexer_errors.all_compiler_errors[0].msg);
			return;
		}

		//TODO I Like the idea of making my own allocator here which uses memory directly
		//TextOpSpaceData allocator. Maybe something like a SimplePool that just increments
		//a size until a max size and then we can reset it. Kind of like a resizable array but
		//more general and simple. We need that instead of resizable array
		//because the nodes cant change position once their made. Although if we have a max
		//number of nodes, then technically we could just use that but we use ParseExpression
		//and that uses New, so maybe a SimplePool is the best and then set the alloc here.
		watch_alloc : Allocator;
		#if TEST_MY_SIMPLE_POOL watch_alloc.proc = MySimpleAllocProc;
		else watch_alloc.proc = flat_pool_allocator_proc;
		//TODO Debug from here why this is not working.
		watch_alloc.data = *watch_data.watch_pool;
		//NOTE : watch_alloc is used for MakeBinaryNode BUT if we have errors
		//then the error string will be stored in watch_alloc.
		//This is ok since we reset it afterwards once this is a valid row.
		watch_data.node = ParseExpression(watch_cd,S64_MIN,,watch_alloc);
		if watch_cd.comp_errors.all_compiler_errors.count > 0 {
			//TODO We take the first error here. I think that's fine.
			//Maybe we could just write "Invalid expression" if this does not makes sense.
			SetWatchError(watch_data, watch_cd.comp_errors.all_compiler_errors[0].msg);
			return;									
		}
	}

	prev_type : *TypeInfo = watch_data.node.code_ir.t_info;
	//TODO Should we just pass this in as a pointer to keep the *T for DFSPost
	// vwd := VisitWatchData.{watch_data,*all_data}; 
	//TODO Should we make this a function or is this enough here.
	//We need to reset because if we had an error then it will remain an error so we clear that here in case we don't.
	watch_data.is_error = false;
	DFSPost(watch_data.node, VisitWatchData.{watch_data,text_op,all_data}, VisitWatchNodes);

	/*DOC : If we have an error or different type then we remove all the sub/indent watch data.
	TODO We can do particular cases like leave it if it changes from array view to fixed array but for now this is fine
	or if the struct is the same size or something but maybe that is more prone to errors so maybe we just leave like this.
	*/
	remove_sub_rows : bool = 
		//NOTE : This prevents the need to check on the loop but we still do for resilience (that might hide errors though... hmmm...)
		watch_index < text_op.watch_data_rows.count-1 && //creating new watch data
		watch_data.watch_indent == 0 && //is not a sub row
		(watch_data.is_error || 
			(prev_type != null && prev_type != watch_data.node.code_ir.t_info));
	if remove_sub_rows {
		RemoveWatchSubRows(watch_index, text_op, 0);
	}

	//TODO Should we do this in ComputeWatchValueAndType? There is more flexibily if we do it in the function
	//such as setting type_str before the error so we don't have the type on an error msg.
	// if watch_data.is_error return;
	ComputeWatchValueAndType(watch_data, text_op, all_data);
}
/*DOC : We set the highlighted_name_index to whatever is in the watch edit and then update the rows
appropriately based on what is highlighted and also reset the cursor.

TODO WE COULD generalize this and pass in a watch_index but then we would have to separate that out
and still use this one here to make sure that we update the highlighted_name_index properly
depending on if we are at the bottom of the watch rows or not, since if we are at the bottom we need to add another watch row.
*/
SetHighlightedWatchToWatchEditAndEvaluate :: inline (
	text_op : *TextOpSpaceData,
	all_data : *AllData)
-> added_watch_data : bool
{
	added_watch_data : bool = false;
	text_op.is_watch_editing = false;

	//TODO Could delete if text_string.count == 0 but this feels better and we don't lose the name by mistake.
	if text_op.edit_watch_name.text_string.count > 0 {
		edit_watch : *WatchData = *text_op.watch_data_rows[text_op.highlighted_name_index];

		//Sanity check : These 2 are the same total_size 1Kb so they should never watch_name_string_max_size.
		//This should be checked in UpdateFileStringAtCursor to not exceed max.
		assert(text_op.edit_watch_name.text_string.count <= watch_name_string_max_size);
		assert(edit_watch.name.data != null); //Sanity check can remove later if needed.
		//TODO Can reuse this function once we allow values to be added to watch window from text editor.
		SetWatchName(edit_watch, text_op.edit_watch_name.text_string);

		//NOTE : We check the count in the outer if, otherwise we don't update.
		//If we want to clear on empty then we would have to check differently.
		if text_op.exec_info.exec_state == .IS_DEBUG_STOP {
			assert(text_op.exec_info.exec_mode == .DEBUG);//sanity check
			//We reset_data here because we updated the name so we need to parse the name expression again
			EvaluateWatchData(text_op.highlighted_name_index, text_op, all_data, reset_data=true);

			//TODO Can remove old one if this works well with sub rows
			#if 1 {
			RemoveWatchSubRows(text_op.highlighted_name_index, text_op, 0);
			} else {
			//TODO Could make this a function to remove all drop down since we reuse it here and on delete.
			next_index : int = text_op.highlighted_name_index + 1;
			//TODO Technically we don't need this first check since the last row is always watch_indent == 0
			//but we leave it here for now for resilience. We could remove with a memcpy as well
			//and store them all in the pool with a memcpy as well.
			while next_index < text_op.watch_data_rows.count-1
				&& text_op.watch_data_rows[next_index].watch_indent > 0
			{
				RemoveWatchData(next_index, text_op);
			}
			}
		}

		if text_op.highlighted_name_index == text_op.watch_data_rows.count-1 {
			AddWatchData(text_op);
			//NOTE : We do this externally now BUT if we don't need to move
			//the index with enter, then we can just remove this return value anyways
			added_watch_data = true;
			//TODO Maybe it feels better to always have it go down instead of only when we are on the last watch_name?
			// if IsKeyboardPress(.ENTER, .DOWN_THIS_FRAME, game_input) {
			// 	//If it's an arrow key we move it down below later in any case.
			// 	text_op.highlighted_name_index += 1;
			// }
		}
	}

	text_op.edit_watch_name.text_string.count = 0;
	ResetTextCursor(*text_op.watch_cursor);

	return added_watch_data;
}

//TODO Maybe we should do this in EvaluateWatchData so we can double check everytime we
//update or run code in case we change type or variable then we would close the dropdown.
//TODO We should have a criteria to check if this is drop-downable (ie STRUCT or ARRAY or NEUME)
DropWatchRow :: inline (
	watch_row_index : int,
	text_op : *TextOpSpaceData,
	all_data : *AllData)
{
	watch_data : WatchData = text_op.watch_data_rows[watch_row_index];
	if IsWatchDroppable(watch_data) {
		next_index : int = watch_row_index + 1;
		is_dropped : bool = next_index < text_op.watch_data_rows.count &&
			watch_data.watch_indent < text_op.watch_data_rows[next_index].watch_indent;
		if is_dropped {
			//Remove all the sub watches with watch_index STRICTLY GREATER THAN top_wd_indent.
			//Anything <= is at the same level or higher so we stop there.
			#if 1 {
			RemoveWatchSubRows(watch_row_index, text_op, watch_data.watch_indent);
			} else {
			while next_index < text_op.watch_data_rows.count &&
					text_op.watch_data_rows[next_index].watch_indent > watch_data.watch_indent
			{
				//TODO Instead of removing each one we can memcpy it to the pool by range
				//and then mempcy the other ones over for efficiency.
				RemoveWatchData(next_index, text_op);
				//NOTE : Since we remove an element from watch_data_rows, no need to increment here.
				// next_index += 1;
			}
			}
		} 
		//TODO Could just put an else here but this is explicit.
		else if !is_dropped {
			//TODO Should we just make this the same as struct and then output array with count like in remedy
			if watch_data.node.code_ir.t_info.type_enum == .ARRAY {
				a_type := cast(*TypeInfoArray) watch_data.node.code_ir.t_info;
				array_watch_count : int;
				if a_type.array_type == {
				case .FIXED;
					array_watch_count = a_type.array_count;
				case .VIEW;
					count_address : int = ComputeRAMLocation(watch_data.node.code_ir.op, all_data.all_register_memory, all_data.ram_memory);
					array_watch_count = GetMemValue(count_address, int, all_data.ram_memory);
				}
				//TODO What should the default max be? We need to get the "," node as well
				MAX_A_COUNT :: 20;
				array_watch_count = min(MAX_A_COUNT, array_watch_count);
				//TODO FROM HERE add rows for each array value, this can be limited by a "," value
				//which maybe we can set in WatchData or it'll be in the node?
				//TODO We could have a hard limit here of 100 or take from the "," but maybe
				//the "," setting can be set after parsing the nodes. Reuse the "," evaluator here
				//so we have to update it to just take ",".
				//TODO Could do a AddManyWatchData and pass in the string so we can reuse it for array and struct
				//and possibly anything else later.
				for 0..array_watch_count-1 {
					//TODO Can likely do this more efficiently by memcpying them all at once.
					//So it would just be 2 memcpys (or array_resize) instead of n inserts
					new_wd : WatchData = PopOrMakeWatchData(text_op);
					new_wd.watch_indent = watch_data.watch_indent + 1;
					//NOTE : we keep relative to top index so then if we move rows, this does not need to change.
					//TODO We can rel_top_index this now since we just do it in the render loop
					// new_wd.rel_top_index = next_index - text_op.highlighted_name_index;
					// array_index_str : string = tprint("%[%]", watch_data.node.value.token_string, it);
					array_index_str : string = tprint("%[%]", watch_data.name, it);
					SetWatchName(*new_wd, array_index_str);

					// display_count : int = array_index_str.count - watch_data.node.value.token_string.count;
					// new_wd.display_name = String.slice(new_wd.name, watch_data.node.value.token_string.count, display_count);
					//NOTE : We grab the [%] from the name string above, which comes after the watch_data.name
					display_count : int = array_index_str.count - watch_data.name.count;
					new_wd.display_name = String.slice(new_wd.name, watch_data.name.count, display_count);
					//TODO Doing an array_reserve and memcpy beforehand then we could just set these without
					//having to move all of them over every time.
					array_insert_at(*text_op.watch_data_rows, new_wd, next_index);
					EvaluateWatchData(next_index, text_op, all_data, reset_data=true);
					next_index += 1;
				}
			}
			else if AllOrEquals(watch_data.node.code_ir.t_info.type_enum, STRUCT_TYPE_INTERNAL) {
				//TODO Should we just make these structs? Could also put these in an array
				//TODO I think we should just store struct members in TypeInfoStruct instead
				s_type := cast(*TypeInfoStruct) watch_data.node.code_ir.t_info;
				// for all_data.comp_data.all_type_info_struct_members if it.struct_id == s_type.id {
				for s_type.struct_members {
					//TODO Can likely do this more efficiently by memcpying them all at once.
					//So it would just be 2 memcpys (or array_resize) instead of n inserts
					new_wd : WatchData = PopOrMakeWatchData(text_op);
					new_wd.watch_indent = watch_data.watch_indent + 1;
					// new_wd.rel_top_index = next_index - text_op.highlighted_name_index;
					// array_index_str : string = tprint("%.%", watch_data.node.value.token_string, it.name);
					array_index_str : string = tprint("%.%", watch_data.name, it.name);
					SetWatchName(*new_wd, array_index_str);

					new_wd.display_name = it.name;
					//TODO We can grab the display_name from the name string here if that is more persistent.
					//This keeps the string as a view on the name whereas the above grabs the string from the struct member directly.
					// display_count : int = array_index_str.count - watch_data.name.count - 1;
					// new_wd.display_name = String.slice(new_wd.name, watch_data.name.count+1, display_count);
					// display_count : int = array_index_str.count - watch_data.node.value.token_string.count - 1;
					// new_wd.display_name = String.slice(new_wd.name, watch_data.node.value.token_string.count+1, display_count);
					//TODO Doing an array_reserve and memcpy beforehand then we could just set these without
					//having to move all of them over every time.
					array_insert_at(*text_op.watch_data_rows, new_wd, next_index);
					EvaluateWatchData(next_index, text_op, all_data, reset_data=true);
					next_index += 1;
				}	
			}
		}
	}
}

DebugWatchEditNameMode :: inline (
	watch_data : WatchData,
	text_op : *TextOpSpaceData) 
{
	//NOTE : If we are watch_editing and mouse_watch_index == text_op.highlighted_name_index
	//then we stop above to move the cursor around with cursor_left_mouse_holding
	if watch_data.name.count > 0 && !watch_data.is_error {
		memcpy(text_op.edit_watch_name.text_string.data, watch_data.name.data, watch_data.name.count);
		text_op.edit_watch_name.text_string.count = watch_data.name.count;

		//Set the cursor to highlight the text if we double click and there is already text
		text_op.watch_cursor.cursor_is_selecting = true;
		text_op.watch_cursor.fixed_select_char_point = 0;
		text_op.watch_cursor.fixed_select_line_char = 0;
		text_op.watch_cursor.char_point = watch_data.name.count;
		text_op.watch_cursor.cursor_line_char = watch_data.name.count;

		if text_op.edit_watch_name.text_string.count > text_op.watch_cursor.right_char_bound {
			char_bound_diff : int = text_op.watch_cursor.right_char_bound - text_op.watch_cursor.left_char_bound;
			text_op.watch_cursor.left_char_bound = text_op.edit_watch_name.text_string.count - char_bound_diff;
			text_op.watch_cursor.right_char_bound = text_op.edit_watch_name.text_string.count;
		}
	} else {
		//We do this in SetHighlightedWatchToWatchEditAndEvaluate but we do here again for resilience
		ResetTextCursor(*text_op.watch_cursor);
	}
	text_op.is_watch_editing = true;
}

GetCallFrame :: inline (debug_info : *DebugInfo) -> *DebugCallFrame {
	c_frame : *DebugCallFrame = peek_pointer(debug_info.debug_call_stack);
	if debug_info.chose_other_call_frame {
		//sanity check
		assert(debug_info.selected_call_frame_index < debug_info.debug_call_stack.count);
		c_frame = *debug_info.debug_call_stack[debug_info.selected_call_frame_index];
	}
	return c_frame;
}

//TODO Write tests for this function once it works on more types.
ComputeWatchValueAndType :: inline (watch_data : *WatchData, text_op : *TextOpSpaceData, all_data : *AllData) {
	//We set this before because even if we have an error we want to reset the type_str but
	//since we store the error msg in the value_str, we don't want to reset that if we have an error.
	watch_data.type_str.count = 0;
	//TODO Should we do this here or externally? Doing it here gives us a bit more flexibility on when 
	//to set/reset things like the type_str above.
	if watch_data.is_error return;

	// assert(!watch_data.is_error);
	//Sanity check, this should not happen if we don't have an error.
	assert(watch_data.node != null);
	//Sanity check, this should always be set if we have a node. Even if it just defaults to int i think.
	assert(watch_data.node.code_ir.t_info != null);

	//TODO Should we reset value and type here?
	watch_data.value_str.count = 0;

	watch_type : *TypeInfo = watch_data.node.code_ir.t_info;
	watch_op : MusicOperand = watch_data.node.code_ir.op;
	debug_info : *DebugInfo = *text_op.exec_info.debug_info;
	c_frame : *DebugCallFrame = GetCallFrame(debug_info);
	value_string : string;	
	if watch_op.operand_type == {
	case MusicOperandType.MUSIC_MEMORY; {
		//TODO Can make this similar to an array of floats with a dropdown of floats instead of this
		//Although we could have both so you can see the first few in the window.
		row_index, x_index := MusicMemRowAndXIndex(watch_op, debug_info.debug_all_registers, all_data.global_rules.row_size);
		music_pt_floats : [] float64 = GetAllMusicPtFloat(row_index, x_index, all_data.all_mspace_data[0].all_music_pts);

	   sb: String_Builder;
	   sb.allocator = temp;
		append(*sb, "[");
		for music_pt_floats {
			if it_index != 0 append(*sb, ",");
			print_to_builder(*sb, "%", formatFloat(it),,temp);
		}
		append(*sb, "]");
		value_string = builder_to_string(*sb,,temp);
	}
	case MusicOperandType.RAM_MEMORY; {
		//TODO add the sub_tree names/values when we click and compute the strings when we click
		//the dropdown or update the name field.
		//TODO Check type here. If struct/array then we do a drop_down menu with a stack of where we were 
		//and a sub_watch array and each SubWatch would have a sub_watch array as well and the stack would
		//be how for down we've gone or something along those lines.
		//Then gradually add debugging info like struct/array sub-trees with array pointer switch
		//and stack while we start writing some code.
		if watch_data.node.value.token_type == #char "*" {
			//This is a debug pointer that has no memory since we are checkking in the watch window only,
			// so we just grab the RAMLocation and set it.
			//TODO Does it make more sense to do this in VisitWatchNodes and set the op to Imm(ram_address)?
			//I think this is clearer but maybe not if we see something different later.
			ram_address : int = ComputeRAMLocation(watch_op, debug_info.debug_all_registers, all_data.ram_memory);
			bounds_err : CPUError = MemoryInBounds(all_data.ram_memory, ram_address, watch_type.runtime_size);
			if bounds_err.is_error {
				//TODO Could set the bounds_err.msg here.
				value_string = "memory out of bounds";
			} else {
				//TODO Should we put a special symbol for addresses or is the type column enough?
				value_string = tprint("%", ram_address);
			}
		}
		else if AllOrEquals(watch_data.node.code_ir.t_info.type_enum, STRUCT_TYPE_INTERNAL) {
			//TODO Should we set this to the first value or make an "{x,y}" preview string
			value_string = "drop(struct)";
			// ram_address : int = ComputeRAMLocation(watch_op, debug_info.debug_all_registers, all_data.ram_memory);
			// mv, err := GetMemValue(ram_address, watch_data.node.code_ir.t_info, all_data.ram_memory);
		} 
		else if watch_data.node.code_ir.t_info.type_enum == .ARRAY {
			//TODO Should we set this to the first few values like "[x,y,z]" preview string
			value_string = "drop(array)";
			// ram_address : int = ComputeRAMLocation(watch_op, debug_info.debug_all_registers, all_data.ram_memory);
			// mv, err := GetMemValue(ram_address, watch_data.node.code_ir.t_info, all_data.ram_memory);
		}
		else {
			ram_address : int = ComputeRAMLocation(watch_op, debug_info.debug_all_registers, all_data.ram_memory);
			mv, err := GetMemValue(ram_address, MemoryValue, all_data.ram_memory);
			if err.is_error {
				value_string = "invalid ram";
			} else {
				//TODO Do this based on type now which we compute before from string_split or value type
				//and then store in t_info. So WatchValue should be based on t_info and not a string directly here anymore.
				value_string = WatchValue(mv, watch_data.node.code_ir.t_info);
			}
		}
	}
	case MusicOperandType.REGISTER;
		reg_index : int = watch_op.values[0].int_value;
		//TODO Do this based on type now which we compute before from string_split or value type
		//and then store in t_info. So WatchValue should be based on t_info and not a string directly here anymore.
		value_string = WatchValue(debug_info.debug_all_registers[reg_index], watch_data.node.code_ir.t_info);
	case MusicOperandType.INTEGER;
		value_string = tprint("%", watch_op.values[0].int_value);
	case MusicOperandType.FLOAT;
		value_string = tprint("%", formatFloat(watch_op.values[0].float_value));
	case;
		value_string = "invalid expression";
	}
	SetWatchValue(watch_data, value_string);

	//NOTE : We assert the t_info is set above. This should be set in all cases if we don't have an error.
	//TODO We could not set this if we have an error above.
	//TODO Maybe we should make this a function so we can reuse everywhere to display type info.
	//Could move it to thegame_code then
	type_string := TypeToString(watch_data.node.code_ir.t_info,,temp);
	SetWatchType(watch_data, type_string);
}
//TODO Put this in thegame_code since it is a general type string generator
TypeToString :: (input_t_info : *TypeInfo) -> string {
	t_info : *TypeInfo = input_t_info;
	sb : String_Builder;

	while t_info.type_enum == .POINTER {
		append(*sb, "*");
		t_info = (cast(*TypeInfoPointer) t_info).pointer_to;
	}

	if AllOrEquals(t_info.type_enum, STRUCT_TYPE_INTERNAL) {
		append(*sb, (cast(*TypeInfoStruct) t_info).name);
	}
	else if t_info.type_enum == .ENUM {
		append(*sb, (cast(*TypeInfoEnum) t_info).name);
	}
	else if t_info.type_enum == {
	case .MUSIC_UNIT; append(*sb, "mrow");
	case .STRING; append(*sb, "string");
	case .INTEGER; append(*sb, "int");
	case .FLOAT; append(*sb, "float");
	case .BOOL; append(*sb, "bool");
	case .VOID; append(*sb, "void");
	case .ARRAY; {
		a_type := cast(*TypeInfoArray) t_info;
		if a_type.array_type == {
		case .VIEW; append(*sb, "[] ");
		case .FIXED; print_to_builder(*sb, "[%] ", a_type.array_count);
		}
		//Recurse on TypeToString time in case the array value type is a pointer or array
		a_type_string : string = TypeToString(a_type.element_type);
		append(*sb, a_type_string);
	}
	case .PROCEDURE; {
		p_type := cast(*TypeInfoProcedure) t_info;
		append(*sb, "(");
		for p_type.argument_types {
			t_string := TypeToString(it);
			append(*sb, t_string);
			if it_index < p_type.argument_types.count-1 {
				append(*sb, ",");
			}
		}
		append(*sb, ")->(");
		for p_type.return_types {
			t_string := TypeToString(it);
			append(*sb, t_string);
			if it_index < p_type.return_types.count-1 {
				append(*sb, ",");
			}
		}
		append(*sb, ")");
	}
	} 
	return builder_to_string(*sb);
}
VisitWatchData :: struct {
	//TODO should we just pass in watch_index now like in EvaluateWatchData?
	watch_data : *WatchData;
	text_op : *TextOpSpaceData;
	all_data : *AllData;
}
/*TODO Should write unit tests for this once it is working with a few cases. OR once we start
adding structs and arrays then can add tests for that as well.
This function is based on ParseExpression so we should be testing them together. But ParseExpression
is based on lexing so we should just be testing EvaluateWatchData I think makes the most sense.
*/
//TODO Should we call this EvaluateWatchNodes?
//TODO Should we make this a pointer so we keep pointers going into DFSPost for simplicity and a reminder?
VisitWatchNodes :: (node : *BinaryNode, vwd : VisitWatchData) -> is_valid : bool {
	//TODO Why don't we input a struct with AllData AND other values like text_op
	//so we can put some errors in there instead so the errors are specific to Watch window instead of
	//reusing compilation errors. CompilerError
	cd : *CompilationData = vwd.all_data.comp_data;
	//TODO Should we just pass in DebugInfo if that's all we use?
	debug_info : *DebugInfo = *vwd.text_op.exec_info.debug_info;	
	c_frame : *DebugCallFrame = GetCallFrame(debug_info);

	watch_keywords :: string.["ram"];
	if node.value.token_type == {
	//TODO Need to add array access and operators as well.
	//Operators only base type like int, float and bool, maybe music memory?
	//So we need that ram memory for that and so we need to pass in all_data
	//Can check ram and music memory with "[" like
	//ram = ram[x] AND music_memory = mrow[a][b]
	//mrow is already done in compiler evaluation but ram would be specific to watch window.
	//I guess we could allow it in the language if it's convenient.
	case #char "("; {
		//NOTE : We don't process functions in the watch window so we will use the "(" binary op
		//to process special values like ram(sbp+ax)
		if node.left.value.token_string == {
		case "ram"; {
			if node.right.code_ir.t_info.type_enum != .INTEGER {
				SetWatchError(vwd.watch_data, "ram() requires integer input.");
				return false;
			}

			right_value, right_err := ComputeWatchValue(node.right.code_ir.op, debug_info.debug_all_registers, vwd.all_data.ram_memory,,temp);
			if right_err.is_error {
				SetWatchError(vwd.watch_data, right_err.msg);
				return false;
			}

			node.code_ir.op = RamMem(right_value.int_value);
			//We set t_info to int by default. We can cast or "," to a different type on top.
			//I think we can also allow a pointer to this which would just return the inner value
			//but we can use a generalized pointer in the watch pane to do that anyways.
			node.code_ir.t_info = *cd.int_type_info;
		}
		}
		return true;
	}
	case .INTEGER; {
		//TODO This could be done in ParseExpression when creating a leaf for all constants
		SetIntegerNode(node, node.value.int_value, cd);
		return true;
	}
	case .FLOAT; {
		//TODO This could be done in ParseExpression when creating a leaf for all constants
		node.code_ir.ir_type = .FLOAT;
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		node.code_ir.t_info = *cd.float_type_info;
		node.code_ir.op = FImm(node.value.float_value);
		return true;
	}
	case #char "."; {
		//TODO This is likely an InternalError so can possibly leave as an assertions or log.
		//TODO This can also be checked at the parser level
		assert(node.left != null && node.right != null);
		//We only pass the node up now since we compute member access at the member node
		//so that we can pass up the chain if we have an array or dereference.
		node.code_ir = node.right.code_ir; 
		node.code_ir.code_value_type = .L_VALUE;
		return true;
	}
	case #char "["; {
		//TODO CompilerError/ParserLevel (probably can check at the parser level for left and right)
		assert(node.left != null && node.right != null);
		if node.code_ir.ir_type != CodeIRType.BINARY_OP {
			SetWatchError(vwd.watch_data, "\"[\" is a binary op.");
			return false;
		} else if node.right.code_ir.t_info.type_enum != .INTEGER {
			SetWatchError(vwd.watch_data, "Need an integer offset.");
			return false;			
		}

		array_data_address : int;
		value_type : *TypeInfo;
		if node.left.code_ir.t_info.type_enum == {
		case .POINTER;
			pointer_info := cast(*TypeInfoPointer) node.left.code_ir.t_info;
			value_type = pointer_info.pointer_to;

			ram_address : int = ComputeRAMLocation(node.left.code_ir.op, debug_info.debug_all_registers, vwd.all_data.ram_memory);
			array_data_address = GetMemValue(ram_address, int, vwd.all_data.ram_memory);
		case .ARRAY;
			array_info := cast(*TypeInfoArray) node.left.code_ir.t_info;
			value_type = array_info.element_type;

			//NOTE : The ram location is the array data address for fixed arrays
			array_data_address = ComputeRAMLocation(node.left.code_ir.op, debug_info.debug_all_registers, vwd.all_data.ram_memory);
			if array_info.array_type == .VIEW {
				array_data_address += 8;
				array_data_address = GetMemValue(array_data_address, int, vwd.all_data.ram_memory);
			}
		}

		array_offset : int = ComputeOperandInt(node.right.code_ir.op, debug_info.debug_all_registers, vwd.all_data.ram_memory);
		array_data_address += array_offset * value_type.runtime_size;
		node.code_ir.op = RamMem(array_data_address);
		node.code_ir.t_info = value_type;
		node.code_ir.code_value_type = CodeValueType.L_VALUE;
		// node.code_ir.ir_type = .STACK_VARIABLE; //TODO Change this name to .MEMORY_VARIABLE for heap memory
		// node.code_ir.node_op_type = .ADDRESS_IN_MEMORY; 
		return true;
	}
	case .IDENT; {
		//We check if an identifier is in fact a struct member by looking up the tree.
		/*We need to do this because of the 2 following cases where the variable has been explicitly
		placed on the left so that this works in both cases. In both of these cases, we need to 
		go up the tree and check parent.left until we hit a "." with parent.right below. Then that shows
		us that this is a struct member so we compute the offset directly before doing the rest.
		This is now tested for the first struct pointer dereference case and works well.
		Still need to test the second case once we're implementing arrays.
		 	  .
   	    / \ 
   	   t   .*
   	       /
   	      p

   		  .
			 / \
			s   [
			   / \
			  x   0
		*/

		//TODO Could make this into a function to find first left parent node
		l_node : *BinaryNode = node;
		while l_node.parent != null && l_node == l_node.parent.left {
			l_node = l_node.parent;
		}
		found_struct_member : bool = false;
		if l_node.parent != null && l_node == l_node.parent.right && l_node.parent.value.token_type == #char "." {
			found_struct_member = true;
		}

		if found_struct_member {
			//TODO Implement this once we put structs and arrays in watch window
			//TODO Maybe change the name of this...
			struct_node : *BinaryNode = l_node.parent.left;
			struct_info : *TypeInfoStruct = cast(*TypeInfoStruct) struct_node.code_ir.t_info;

			//TODO CAn remove this entirely once we store struct_members in struct_info
			member_info : TypeInfoStructMember;
			found_member_info : bool = false;
			if l_node.value.token_type == .IDENT {
				member_info, found_member_info = GetStructMember(l_node.value.token_string, struct_info);
			} else {
				//This is for both array access "[" and dereference ".*" where the member node will be on the left
				member_info, found_member_info = GetStructMember(l_node.left.value.token_string, struct_info);
			}
			assert(found_member_info);

			node.code_ir.op = AddOperandOffset(member_info.offset_in_bytes, struct_node.code_ir.op);
			node.code_ir.t_info = member_info.t_info;

			#if 0 {
			node.code_ir.code_value_type = CodeValueType.L_VALUE;
			node.code_ir.ir_type = .STACK_VARIABLE;
			if struct_node.code_ir.t_info.type_enum == .ARRAY && member_info.name == "data" {
				//NOTE : We process this here so it can be the same as other structs except
				//we just the data member for arrays to the proper pointer type here.
				//TODO Could use something like this for other auto-casting behavior eventually.
				t_pointer_info := GetOrCreateTypeInfoPointer(array_info.element_type, cd);
				node.code_ir.t_info = cast(*TypeInfo) t_pointer_info;
			} else {
				node.code_ir.t_info = member_info.t_info;
			}

			/*TODO Can be do .POINTER auto-dereference in a similar way as arrays here as well?
			*/
			array_info : *TypeInfoArray;
			if struct_node.code_ir.t_info.type_enum == .ARRAY {
				array_info = cast(*TypeInfoArray) struct_node.code_ir.t_info;
				if array_info.array_type == {
				case .FIXED;
					if node.value.token_string == {
					case "count";
						/*TODO Technically we can remove some instruction in this case since we only need the integer
						for cases like f[1].count then we would have fetched the array in memory but then we only
						need the count which is at compile-time. I will leave the superfluous instructions for now,
						but we could maybe remove them later...
						*/
						//TODO Should this ir data be different since it's a compile-time integer?
						node.code_ir.ir_type = .INTEGER;
						//TODO Maybe this should be more systematic when we are setting operands up the tree.
						FreeOperandRegisters(struct_node.code_ir.op, *cd.all_registers);
						node.code_ir.op = Imm(array_info.array_count);
						node.code_ir.t_info = *cd.int_type_info;
					case "data";
						p_type : *TypeInfoPointer;
						found_p_type : bool = false;
						for cd.all_type_info_pointer if it.pointer_to == array_info.element_type {
							p_type = it;
							found_p_type = true;
						}
						assert(found_p_type);

						//TODO Could do this as GetArrayData function in case we change order later.
						reg, reg_reused := OLDGetOrReuseRegister(struct_node, cd);
						op_0, op_1 := GetMemoryAddressAsOperands(struct_node.code_ir.op);
						CreateMInstr(.add, RegMem(reg), op_0, op_1, d=cd);

						node.code_ir.ir_type = .REGISTER;
						node.code_ir.op = RegMem(reg);
						node.code_ir.t_info = p_type;
					case;
						//TODO CompilerError
						assert(false, "Invalid fixed array member : %.\n", node.*);
					}
					//Return here since we do not process fixed arrays as structs.
					return;
				case .VIEW;
					//We set the struct info and then process the array like a struct below.
					struct_info = *cd.array_view_struct_info;
				case .RESIZABLE;
					struct_info = *cd.resizable_array_struct_info;
				}
			}
			}
		} else {
			//We can check in here if we either have a stack var or heap memory or a function name.
			//TODO Need to check scope_index here as well once we keep track of that during debugging.
			//sanity check, this should be checked in the ui/input code
			// assert(debug_info.selected_call_frame_index < debug_info.debug_call_stack.count);
			// c_frame := debug_info.debug_call_stack[debug_info.selected_call_frame_index];
			//NOTE : We check backwards here since the last variables are the last ones we put on and we
			//want to get the last one we put on with the given watch name.
			found_var : bool = false;
			var : VariableData;
			for < c_frame.frame_vars if it.name == node.value.token_string {
				var = it;
				found_var = true;
			}
			// var, found_var := ArrayFindFirstByNameId(c_frame.frame_vars, node.value.token_string, "name");

			//TODO Maybe this is inefficient to check here and we should just check it on function calls?
			//TODO Maybe we don't need functions here, or maybe we do... not sure
			fun_decl, found_func := ArrayFindFirstByNameId(cd.all_function_declarations, node.value.token_string, "name");

			found_struct_type : bool = false;
			struct_type : *TypeInfoStruct;
			if !found_var {
				for cd.all_type_info_struct if it.name == node.value.token_string {
					struct_type = it;
					found_struct_type = true;
					break;
				}
			}

			found_reg : bool = false;
			reg_index : int = -1;
			if !found_struct_type && !found_var {
				for cd.all_registers if it.name == node.value.token_string {
					found_reg = true;
					reg_index = it.reg_index;
					break;
				}
			}

			is_watch_keyword : bool = false;
			for watch_keywords if it == node.value.token_string {
				is_watch_keyword = true;
				break;
			}

			//We check for local var here first, if we find it then we use that. This allows us to have local
			//variables with the same name as structs or enums. I think this is how it's done in jai.
			//If we have structs or functions with the same now, that should return a CompilerError.
			if found_var {
				//TODO FROM HERE Need to make sure we are in the right scope of instrs which should be set in CreateVarData
				//and then closed when we close the current scope. Global scope would just be the entire instruction set
				//if we are not in the valid instructions then we can return an error "var not in scope"
				//ALSO TODO WE SHOULD ADD variables everytime we enter a new scope when we execute some instructions
				//in the debugger. So we would check the function_id and start_instr_index (which is sorted now)
				//and then load variables currently availabe and then check here in reverse order to get first one by name.
				//ALSO i think but open_scope_stack as ids instead of separate data so we only have the data in 1 place
				//in all_scope_data now.
				node.code_ir.code_value_type = CodeValueType.L_VALUE;
				node.code_ir.ir_type = .STACK_VARIABLE;
				node.code_ir.ir_data_id = var.id;
				//TODO Do we have to cast type_info here, or should we just use id and type instead of pointer?
				node.code_ir.t_info = var.t_info;
				//TODO Maybe this variable is in a reg so we could set something like that as well.
				//TODO Also if it's in memory then the address would be somewhere and we'd have to create an
				//instruction and then load the register we store that in here.
				//THIS MIGHT WORK NOW WITH NEW VARIABLE STRUCTURE.
				//TODO If we have an array here, should we put the data and count in registers.
				//TODO If we have an array here then make a RamArray Op from the var op so that we can
				//pass that up and then free the registers later. We can't store it in var.op directly
				//because the register will get reused.
				node.code_ir.op = var.op;
			} else if found_struct_type {
				node.code_ir.ir_type = .DATA_TYPE_INFO;
				// node.code_ir.ir_data_id = struct_type.id;
				//TODO Should we use type and id here instead of pointer to avoid pointer memory issues?
				node.code_ir.t_info = cast(*TypeInfo) *struct_type.info;
				node.code_ir.code_value_type = CodeValueType.R_VALUE;
			} else if found_func {
				node.code_ir.t_info = cast(*TypeInfo) fun_decl.t_info_proc;
				node.code_ir.code_value_type = CodeValueType.R_VALUE;
			} else if found_reg {
				node.code_ir.op = RegMem(cast(RegDef) reg_index);
				//Default to int and then use external type with ","
				node.code_ir.t_info = *cd.int_type_info;
				//TODO If we add iax, ibx... and fax, fbx...
				//later then we can set type based on that too.
			} else if is_watch_keyword {
				//Do nothing since this will get processed at the "(" or wherever the keyword is used
				//We could set a value here in code_ir_type but there is no need since we checked in watch_keywords
			} else {
				//TODO This can be checked for errors up the tree on nodes where we should have a known identifier.
				// node.code_ir.ir_type = .UNKNOWN_IDENT;			
				// node.code_ir.code_value_type = CodeValueType.R_VALUE;				
				SetWatchError(vwd.watch_data,
				tprint("% is unknown identifier",node.value.token_string));
				return false;
			}
		}
		//If we get here then we are good by default.	
		return true;
	}
	// case #char "^"; #through;
	// case .LOGICAL_AND; #through;
	// case .LOGICAL_OR; #through;
	// case .ISEQUAL; #through;
	// case .ISNOTEQUAL; #through;
	// case #char ">"; #through;
	// case #char "<"; #through;
	case #char "*"; #through;
	case #char "-"; #through;
	case #char "+"; {
		//I think this is fine but only for base types int, float and bool and normal logical and arithmetic operations.
		//TODO Is this too much? I guess we can have conditional breakpoints
		//with something like this which could be useful.
		//We could add MUSIC_MEMORY here but then we would have to duplicate
		//the music memory asm which I think is a bad idea overall.
		//TODO This should be caught by ParseExpression actually.
		assert(node.right != null);
		// if node.left == null || node.right == null {
		// 	CreateCompErr(cd, .DEBUGGER, node,
		// 	sprint("Missing open bracket for close bracket : %.", 
		// 		lct.token_type,,context.allocator));
		// }

		valid_op_types :: MusicOperandType.[.INTEGER, .FLOAT, .REGISTER, .RAM_MEMORY];
		if !AllOrEquals(node.right.code_ir.op.operand_type, valid_op_types) {
			SetWatchError(vwd.watch_data,
			tprint("% invalid op type",node.right.value.token_string));
			return false;
		}
		right_value, right_err := ComputeWatchValue(node.right.code_ir.op, debug_info.debug_all_registers, vwd.all_data.ram_memory,,temp);
		if right_err.is_error {
			SetWatchError(vwd.watch_data, right_err.msg);
			return false;
		}

		right_type : *TypeInfo = node.right.code_ir.t_info;
		if node.code_ir.ir_type == .UNARY_OP {
			if node.value.token_type == {
			//TODO Logical operators
			case #char "-"; #through;
			case #char "+"; {
				if AllOrEquals(right_type.type_enum, .[.INTEGER, .FLOAT]) {
					if right_type.type_enum == .FLOAT {
						fv : float64;
						if node.value.token_type == {
						case #char "-"; fv = -right_value.float_value;
						case #char "+"; fv = right_value.float_value;
						}
						node.code_ir.op = FImm(fv);
						node.code_ir.t_info = *cd.float_type_info;
					} else {
						iv : int;
						if node.value.token_type == {
						case #char "-"; iv = -right_value.int_value;
						case #char "+"; iv = right_value.int_value;
						}
						node.code_ir.op = Imm(iv);
						node.code_ir.t_info = *cd.int_type_info;
					}
				} else {
					SetWatchError(vwd.watch_data, "Use float or int for arithmetic");
					return false;
			   }
			}
			case #char "*"; {
				if node.right.code_ir.op.operand_type != .RAM_MEMORY {
					SetWatchError(vwd.watch_data, "invalid pointer");
					return false;
				}

				node.code_ir.t_info = GetOrCreateTypeInfoPointer(node.right.code_ir.t_info, cd);
				node.code_ir.op = node.right.code_ir.op;
			}
			case;
				SetWatchError(vwd.watch_data, "Invalid unary op");
				return false;			
			}
		} else if node.code_ir.ir_type == .BINARY_OP {
			assert(node.left != null); //sanity check. should be checked in ParseExpression
			if !AllOrEquals(node.left.code_ir.op.operand_type, valid_op_types) {
				SetWatchError(vwd.watch_data, 
				tprint("% invalid op type",node.left.value.token_string));
				return false;
			}
			left_value, left_err := ComputeWatchValue(node.left.code_ir.op, debug_info.debug_all_registers, vwd.all_data.ram_memory,,temp);
			if left_err.is_error {
				SetWatchError(vwd.watch_data, left_err.msg);
				return false;
			}

			left_type : *TypeInfo = node.left.code_ir.t_info;
			//Need to do some auto type casting or something i guess
			if node.value.token_type == {
			//TODO Logical operators and other arithemtic ops
			case #char "-"; #through;
			case #char "+"; #through;
			case #char "*"; {
				if AllOrEquals(left_type.type_enum, .[.INTEGER, .FLOAT]) &&
					AllOrEquals(right_type.type_enum, .[.INTEGER, .FLOAT]) 
				{
					return_type : TypeInfoTag;
					if left_type.type_enum == .FLOAT || right_type.type_enum == .FLOAT {
						left_f : float64;
						if left_type.type_enum == {
						case .FLOAT; left_f = left_value.float_value;
						case .INTEGER; left_f = cast(float64) left_value.int_value;
						}
						right_f : float64;
						if right_type.type_enum == {
						case .FLOAT; right_f = right_value.float_value;
						case .INTEGER; right_f = cast(float64) right_value.int_value;
						}

						fv : float64;
						if node.value.token_type == {
						case #char "-"; fv = left_f - right_f;
						case #char "+"; fv = left_f + right_f;
						case #char "*"; fv = left_f * right_f;
						}
						node.code_ir.op = FImm(fv);
						node.code_ir.t_info = *cd.float_type_info;
					} else { //Both integer
						iv : int;
						if node.value.token_type == {
						case #char "-"; iv = left_value.int_value - right_value.int_value;
						case #char "+"; iv = left_value.int_value + right_value.int_value;
						case #char "*"; iv = left_value.int_value * right_value.int_value;
						}
						node.code_ir.op = Imm(iv);
						node.code_ir.t_info = *cd.int_type_info;
					}
				} else {
					SetWatchError(vwd.watch_data, "Use float or int for arithmetic");
					return false;
			   }
			}
			}
		}
		//If we get here then we are good by default.	
		return true;
	}
	}
	//TODO Maybe we should return an error here instead
	//and return true for all valid cases above
	//since most cases are invalid here.
	//TODO I think because ParseExpression can handle many things that we don't allow here,
	//then we can default to an invalid expression and return true on each valid expression node above.
	SetWatchError(vwd.watch_data, "Invalid expression");
	return false;
}
ComputeWatchValue :: inline (
	operand : MusicOperand,
	all_register_memory : [] MemoryValue,
	ram_memory : RAMMemory)
-> MemoryValue, CPUError
{
	mv : MemoryValue;
	err : CPUError;
	if operand.operand_type == {
	case MusicOperandType.REGISTER;
		mv = all_register_memory[operand.values[0].int_value];
	case MusicOperandType.FLOAT; #through;
	case MusicOperandType.INTEGER;
		mv = operand.values[0].value;
	case MusicOperandType.RAM_MEMORY;
		mem_address : int = ComputeRAMLocation(operand, all_register_memory, ram_memory);
		//This seems to a be about 5 instructions shorter than memcpy and also clearer ram_memory);
		mv, err = GetMemValue(mem_address, MemoryValue, ram_memory);
		// memcpy(*int_value, *ad.ram_memory.bytes[mem_address], size_of(int));
	}
	return mv, err;
}

GetWatch :: inline (name : string, watch_rows : [] WatchData) -> WatchData {
	for watch_rows if it.name == name {
		return it;
	}
	return .{};
}

TextPaneType :: enum u8 {
	NONE;
	TEXT;
	WATCH;
	DISASSEMBLY;
	//TODO Can Rename this to TEXT_OP_CONSOLE if we use it for other output later
	COMPILER_CONSOLE;	//TODO Add text input to this for doing anything like moving around space or updating other things

	//r_bottom_pane for now. Can make this more flexible later
	CALL_STACK;
	//TODO
	// BREAKPOINTS;
}

//TODO Likely make this left, right, l_bottom, r_bottom eventually.
//So we keep it separate for TextPaneType for now.
SelectedTextPane :: enum u8 {
	TEXT;
	WATCH;
	DISASSEMBLY;
	COMPILER_CONSOLE;
	CALL_STACK;

	TEXT_FIRST_BAR;
	TEXT_SECOND_BAR;
}
ChangeTextPane :: inline (
	pane_type : SelectedTextPane,
	text_op : *TextOpSpaceData,
	all_data : *AllData)
{
	if all_data.runtime_settings.save_file_on_focus_lost && text_op.selected_pane == SelectedTextPane.TEXT {
		//DOC : We don't update the cursor here because we do that in ChooseOpSpace and ChangeTextTab
		text_file := GetTabTextFile(text_op.ftab_i, text_op, all_data.all_text_files);
		success, msg := SaveTextFile(text_file);
		SetTextStatus(msg, text_op);
	}

	if text_op.is_watch_editing {
		SetHighlightedWatchToWatchEditAndEvaluate(text_op, all_data); 
	}
	text_op.selected_pane = pane_type;
	text_op.watch_cursor.cursor_is_selecting = false;
	text_op.is_watch_editing = false;
	text_op.edit_watch_name.text_string.count = 0;
	ResetTextCursor(*text_op.watch_cursor);

	//Unselect the bar if we change pane so we can move to text editor
	text_op.selected_text_bar = SelectedTextBarType.NONE;

}
ChangeTextTab :: inline (
	new_tab : int, 
	text_op : *TextOpSpaceData, 
	all_text_files : [] TextFile) 
-> *TextFile 
{
	//We don't pass back found_text_file right now because we assert in here since all tab text files should be found
	//internally to remain consistent with both the os file system and our own internal text file state.
 	new_text_file : *TextFile = GetTabTextFile(new_tab, text_op, all_text_files);
	ChangeTextTab(new_tab, new_text_file, text_op); 
	return new_text_file;
}
ChangeTextTab :: inline (
	new_tab : int,
	new_text_file : *TextFile,
	text_op : *TextOpSpaceData) 
{
	//TODO If we need to do something with the previous tab we can do it here.
	//CURRENTLY we auto_save on ChangeTextPane, which we call whenever we switch tabs so that should be 
	//good, but if we have issues, then we can also auto-save here instead.
	//We can also pass in that TextFile directly so we don't have to fetch it again.

	//TODO I guess we can add this here but why not just do that update in case anyways
	// if new_tab == text_op.ftab_i return;

	text_op.ftab_i = new_tab;

 	//TODO Maybe we can just do this every time just in case since it is not an expensive operation.
 	//I AM doing it everytime because if we edited and then saved, this would not run.
 	//Can remove the if if it all works out and tested.
	// if new_text_file.file_string.not_saved_text_edit {
	tab : *TextTab = *text_op.file_tabs[new_tab];
	MoveCursorToLineAndLineChar(tab.tab_cursor.cursor_line_number, tab.tab_cursor.cursor_line_char,
		*tab.tab_cursor, new_text_file.file_string, reset_cursor=false, update_bounds=false);
	// }	
}
TextTab :: struct {
	text_file_id : int;
	tab_cursor : TextCursor;
	// tab_cam_pos : Vector2F;
}
TextFirstBarType :: enum u8 {
	NONE;
	FIND_TEXT;
	GOTO_LINE;
	//TODO can implement this eventually and then take the 
	//text op space to the center of the given tano or op space
	// GOTO_TANO;
	// GOTO_OP_SPACE;
	//TODO Coudl also allow connecting op space
	//and then have "right-op_space_name" to say where we connect it
	// CONNECT_OP_SPACE;
}
TextSecondBarType :: enum u8 {
	NONE;
	REPLACE_TEXT;
	//TODO Can use this as a second bar for other functionality if needed
}
//NOTE : If we generalize this later then we could use an integer
//to choose which bar and a bool to say if we are selecting for example.
SelectedTextBarType :: enum u8 {
	NONE;
	SELECTED_FIRST_BAR;
	SELECTED_SECOND_BAR;
}
CloseTextBars :: inline (
	text_op : *TextOpSpaceData,
	op_space : OperationSpace,
	ted : TextEditorData) 
{
	if text_op.text_first_bar_type == TextFirstBarType.GOTO_LINE {
		//We always reset with goto line so itll reset from the find and also if we close and re-open.
		//This is the same behavior as sublime text
		text_op.first_bar_input_text.text_string.count = 0;
		ResetTextCursor(*text_op.first_bar_cursor);
	}
	text_op.text_first_bar_type = TextFirstBarType.NONE;
	text_op.text_second_bar_type = TextSecondBarType.NONE;
	text_op.selected_text_bar = SelectedTextBarType.NONE;					
	ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square, ted);
}
TEXT_STATUS_MESSAGE_SIZE :: #run Kilobytes(1);
SetTextStatus :: inline (
	msg : string,
	text_op : *TextOpSpaceData)
{
	text_op.text_status_timer = 5; //seconds
	copy_size : int = min(msg.count, TEXT_STATUS_MESSAGE_SIZE);
	memcpy(text_op.text_status_message.data, msg.data, copy_size);
	text_op.text_status_message.count = copy_size;
}
TextTopBarType :: enum u8 {
	NONE;
	TEXT_FILE_TABS;
}

/*TO SAVE TEXT OP SPACE DATA
	- we can have the updateable fields in a file which is stored on the system
	then they can update that in game and it saves to the system automatically
	this way no extra work is needed and if i change any names, I can easily run a 
	migration which will not affect anything anywhere other than that file if it exists.

TODO This should have it's own allocator to use for watch data names and debugging info
like breakpoints and call frames and also maybe execution and any other info that might persist.
TODO We could also store breakpoint line numbers and watch name string in a system file afterwards
and read them in so it persists after we close and re-open the program.
*/
TEXT_SPLIT_MIN : float : 0.05;
TEXT_SPLIT_MAX : float : 1.0 - TEXT_SPLIT_MIN;
TextOpSpaceData :: struct {
	//TODO This can just be op_space_id once we remove the op_space_id
	//and create op_space just with render_groups from a free list.
	// op_space_id : int;
	op_space_id : int;
	// text_file_id : int;

	//TODO Could eventually make this left_pane_cam and then
	//have the others be labelled that as well.
	//TODO FROM HERE Use these cams for text and watch names
	//and then also implement breakpoints either in scissor_group
	//or post_render_group. If in scissor we just move over the base_x
	//of the text and store that here.
	// text_cursor : TextCursor;
	ftab_i : int;
	file_tabs : [..] TextTab;

	//DOC : If this is false, then we grab the current text file in the file tabs instead
	set_fixed_main_compile : bool;
	main_compile_text_file_id : int;

	//TODO Should we just get that text_start from left_rect?
	// text_start_x : float;
	// text_start_y : float;
	//TODO This is for text stuff so we can group it together
	left_margin_char_width : int;
	//Number of chars that cursor is on before we move camera along x axis
	x_pre_move : int;
	//Can use this for tabs if we want that... Maybe we don't and we just
	//have the arrow on the left_margin and can ctrl+tab between them
	//and then another shortcut to go between op_spaces.
	top_margin_height : float;
	text_line_height_factor : float;	

	//TODO Can derive right_proportion from left_proportion.
	left_proportion : float = 1.0;
	set_left_proportion : float = 1.0;

	mouse_hovering_split_rect : bool;
	mouse_pressing_split_rect : bool;

	mouse_hovering_l_bottom_split_rect : bool;
	mouse_pressing_l_bottom_split_rect : bool;

	mouse_hovering_r_bottom_split_rect : bool;
	mouse_pressing_r_bottom_split_rect : bool;

	mouse_hovering_name_value_split_rect : bool;
	mouse_pressing_name_value_split_rect : bool;

	mouse_hovering_value_type_split_rect : bool;
	mouse_pressing_value_type_split_rect : bool;

	name_proportion : float;
	type_proportion : float;
	//value_proportion = 1 - name_proportion - type_proportion
	//which is computed and used in UpdateTextOpRects

	//TODO Default to false, just for testing right now
	//We could default this to true or allow default to be
	//set in the settings as well.
	//TODO SETTINGS SHOW this or not by default in the settings
	show_text_status_bar : bool;
	text_status_message : string;
	text_status_timer : float;


	selected_text_bar : SelectedTextBarType;
	//TODO We could generalize these I guess and make them
	//an array if needed... even with text bar above which does not have a cursor
	//Not sure we'll have more than 2 bars though
	text_first_bar_type : TextFirstBarType;
	first_bar_name_text : string;
	first_bar_cursor : TextCursor;
	first_bar_input_text : FileString;

	text_second_bar_type : TextSecondBarType;
	second_bar_name_text : string;
	second_bar_cursor : TextCursor;
	second_bar_input_text : FileString;

	mouse_hovering_top_bar : bool;
	mouse_holding_ftab : bool;
	//This needs to be -1 so we don't hover over tab 0 
	mouse_hovering_tab_i : int = -1;
	//TODO SETTINGS should set if we want this to show on startup
	//in settings or not and then can have separate test settings
	text_top_bar_type : TextTopBarType;

	ator : AllTextOpRects;
	//TODO Maybe rename these and then can change name later if we make
	//these interchangeable so we can put anything wherever we want.
	// left_rect : Rectangle2;
	// right_rect : Rectangle2;
	// left_cam : Camera2D; //Using tab cams in favor of this now.
	// right_cam : Camera2D;
	//TODO Can likely have a camera for bottom panes as well
	//so that we can move them on the x_axis if needed.

	//Watch window data
	is_watch_editing : bool;
	watch_cursor : TextCursor;
	edit_watch_name : FileString;
	highlighted_name_index : int;
	start_watch_index : int;
	end_watch_index : int;

	/*DOCU : We do the same thing as DebugCallFrame and store the pool directly in this array
	  so when we get a new value we just increment count and if we need a new one then we create it.
	  This way we don't have to put anything anywhere else and we don't need to reset any allocators for
	  storing the nodes.

	  TODO Should we make a StackPool and also use that for debug_call_stack and anything else with same structure?
	  We could but the MakeWatchData and ResetWatchData in here are still unique.
	  We could pass them in even at compile-time but let's see if/how we use this pattern before doing that.
	  ALSO to remove it is unique since we call array_ordered_remove_by_index but
	  maybe would call something different for a different StackPool
	*/
	// watch_data_pool_count : int;
	watch_data_pool : [..] WatchData;
	watch_data_rows : [..] WatchData;
	//DOCU : This is used to compile the name into expression nodes for each watch_data above.
	watch_cd : *CompilationData;


	//Left bottom pane info
	l_bottom_pane_type : TextPaneType;
	set_bottom_proportion : float = 0.4;
	bottom_proportion : float;
	//Use this to adjust between disassembly and compiler console
	//Currently we are not using this and allowing heights to be adjustable
	//between left and right instead so we can have a kind of asm view of needed
	//while still seeing the debugging pane. Maybe eventually we just allow
	//switching between text and asm in the top left rect anyways.
	//TODO I think we should remove this for now to remove confusion
	l_bottom_left_proportion : float = 1.0;
	//TODO I think
	// l_bottom_start_index : int;
	// l_bottom_end_index : int;

	//TODO Maybe use l_bottom_start_index instead since its
	//just an int we can use it for any window type.
	//Disassembly window data
	start_disasm_index : int;
	end_disasm_index : int;
	highlighted_disasm_index : int;

	//Compiler console data
	comp_cam : Camera2D;
	console_tsl : TextSplitLine;
	console_dynamic_string : DynamicString;
	//TODO We can put this in TextSplitLine maybe eventually.
	//The problem is for terminals we use the same lines for all terminals
	//It also depends on how we add the lines whether its actually more convenient or not...
	all_console_lines : [..] string;
	console_highlights : [..] TextHighlight;

	//Right bottom pane info
	//NOTE : r_bottom_height_proportion = 1 - l_bottom_left_proportion
	r_bottom_pane_type : TextPaneType;
	r_bottom_height_proportion : float;
	set_r_bottom_height_proportion : float = 0.4;
	//TODO Right now this is specific to the r_bottom_pane.
	//Would have to generalize it with other data if we allow it placed anywhere.
	/*DOC : This refers to the ui rendered index so we can just add and subtract directly
	it DOES NOT go into debug_call_stack directly and should not be used there anyways.
	*/
	highlighted_call_stack_index : int;
	/*DOC These are the max indices of the given pane size. The actual
	rendering index is computed while rendering if call_stack_count < end_call_stack_index
	*/
	start_call_stack_index : int;
	end_call_stack_index : int;


	//TODO Need to use this instead of comp_data from all_data now so that we can
	//have separate compilations for each text op.
	//TODO Likely need a specific allocator for this
	//Could have a pool of allocators but people will likely expect
	//the data to be there when they compile anyways. We could let them adjust the size
	//of the compilation pool in the settings then...
	text_comp_data : *CompilationData;
	text_comp_pool : Flat_Pool;
	text_comp_alloc : Allocator;

	//TODO We should have 3-4 different panes and then have what each one is
	//so that people can edit text in a general way and put whatever they want
	//wherever they want in the text_op_space similar to a text editor for convenience.
	//Maybe its not necessary since we can have multiple op_spaces open side by side anyways...
	selected_pane : SelectedTextPane;

	//TODO This info here is ok but executables need to be separate from code
	exec_info : ExecutionInfo;
}

/*TODO We can pass an object in here to set the initial state of the TextOpSpaceData
and have some defaults in there for convenience.
TODO Can also probably pass in ExternalDataToOpSpace for convenience with name and op_space_id and world_size
set and then we can collapse these later based on the OperationSpace since likely the OperationSpace will
be stored anyways per one open and then we can close or hide it and store all the persistent info in OperationSpace
and then we just reuse the render groups between op spaces if we hide or close it.

TODO TextOpSpace should have it's own allocator

TODO Should make a function or add to this by text_file_name and then
if we find the file we use it and otherwise we create it and read it in
from the system and then add it. Can also have multiple files and change
the file eventually so best to consider all that here when we do it.
*/
//TODO Could eventually write unit tests for this once it's stable
CreateTextOpSpace :: inline (
	//TODO I think this is not optional because even if we don't alreayd have a TextFile we want to be able
	//to save to a text file so we would create one. 
	//TODO We could make a function that creates the TextFile AND the op space for convenience and consistency.
	//TODO We will have multiple files here so it's best to wait till we implement #load
	//and then we need an array and need to 
	//Technically this could be empty too if we have no text file yet.
	//So remake this with an array but then also have an overload with just 1 value for backwards compatibility
	text_file_id : int,
	//TODO Should we pass this in or set it. I think we will change this eventually
	//anyways so maybe it does not matter too much and we can just set it for convenience
	// op_space_id : int,
	text_editor_data : TextEditorData,
	//TODO Should we pass this in directly or with the RenderGroup?
	pixels_per_square : float,
	all_data : *AllData,
	renderer_data : *RendererData)
-> *TextOpSpaceData 
//TODO We could return an id here instead like op_space_id if that is better than a pointer which could change.
//I guess this is ok just in case decide to update it right away. So don't use the pointer long term anyways.
{
	return CreateTextOpSpace(.[text_file_id], text_editor_data, pixels_per_square, all_data, renderer_data);
}
CreateTextOpSpace :: inline (
	//TODO I think this is not optional because even if we don't alreayd have a TextFile we want to be able
	//to save to a text file so we would create one. 
	//TODO We could make a function that creates the TextFile AND the op space for convenience and consistency.
	//TODO We will have multiple files here so it's best to wait till we implement #load
	//and then we need an array and need to 
	//Technically this could be empty too if we have no text file yet.
	//So remake this with an array but then also have an overload with just 1 value for backwards compatibility
	text_file_ids : [] int,
	//TODO Should we pass this in or set it. I think we will change this eventually
	//anyways so maybe it does not matter too much and we can just set it for convenience
	// op_space_id : int,
	text_editor_data : TextEditorData,
	//TODO Should we pass this in directly or with the RenderGroup?
	pixels_per_square : float,
	all_data : *AllData,
	//TODO We can remove renderer_data if we don't use it in here OR keep it and remove pixels_per_square
	renderer_data : *RendererData,
	//TODO I think this should always be passed in instead of having default be the text_file.file_name
	op_space_name : string = "")
-> *TextOpSpaceData 
//TODO We could return an id here instead like op_space_id if that is better than a pointer which could change.
//I guess this is ok just in case decide to update it right away. So don't use the pointer long term anyways.
{
	assert(text_file_ids.count > 0);

	//TODO should probably check that these text files actually exist
	//especially if we allow this functiont to be called
	text_file, found_text_file := ArrayFindFirstConstByNameId(all_data.all_text_files,
		text_file_ids[0], "id");

	cosd : CreateOpSpaceData;
	cosd.world_size = all_data.runtime_settings.text_op_size;
	cosd.op_space_external_type = OpSpaceExternalType.txt;
	if op_space_name.count == 0 {
		cosd.op_space_name = copy_string(text_file.file_name);
	} else {
		cosd.op_space_name = copy_string(op_space_name);
	}
	op_space : OperationSpace = CreateClosedOpSpace(cosd, 
		*all_data.all_closed_op_spaces, 
		*all_data.all_op_space_spec_data, 
		*all_data.all_op_spec_data_3D);

	//TODO Move text cursor in here and set bounds here instead.
	//Then we can make a function to generalize it one we finish the base debugger.
	//TODO Likely make a function when we do call stack pane in debugger so we have it consistent everywhere.
	text_op : *TextOpSpaceData = array_add(*all_data.all_text_op_space_data);
	text_op.op_space_id = op_space.id;
	// text_op.file_tabs[text_op.ftab_i].text_file_id = text_file_id;
	//TODO Could use OpenFileTab
	for text_file_ids {
		//TOOD Should check that these are valid text file ids
		text_tab : *TextTab = array_add(*text_op.file_tabs);
		text_tab.text_file_id = it;
	}

	text_op.watch_cd = MakeCompilationData();
	AddWatchData(text_op);

	//TODO We could have an InitExecInfo or InitDebugInfo function especially when we have separate 
	//execution from text op eventually.
	text_op.exec_info.debug_info.break_points.allocator = context.allocator;
	text_op.exec_info.debug_info.debug_call_stack.allocator = context.allocator;

	//NOTE : This is set manually as it can likely be adjustable.
	//In ComputeTextLineHeight we do text_line_height_factor * char_height
	text_op.text_line_height_factor = 1.35;
	text_op.x_pre_move = 2;
	text_op.left_margin_char_width = 0;
	//TODO Could set this later if we need for tabs or just a space for clarity
	text_op.top_margin_height = 0; 
	//TODO I think this can be removed now since we do ResizeTextOpSpace on the bottom
	text_op.file_tabs[text_op.ftab_i].tab_cursor.right_char_bound = 
		cast(int)(op_space.world_size.x / text_editor_data.code_font_1_char_width_world)
			- (text_op.left_margin_char_width+text_op.x_pre_move);
	text_op.file_tabs[text_op.ftab_i].tab_cursor.right_char_bound = 
		cast(int)(op_space.world_size.x / text_editor_data.code_font_1_char_width_world)
			- (text_op.left_margin_char_width+text_op.x_pre_move);

	//TODO We could double this in UpdateFileStringAtCursor.
	//This is enough for most cases unless someone accidentally searches for an entire file or something like that...
	//Likely could double these in UpdateFileStringAtCursor and then put a max allowed bytes to prevent issues.
	cfsd : CreateFileStringData;
	cfsd.total_allocated_bytes = Kilobytes(10);
	cfsd.undo_action_count = 20;
	cfsd.text_undo_split = " ";
	InitFileString(*text_op.first_bar_input_text, cfsd);
	InitFileString(*text_op.second_bar_input_text, cfsd);

	//TODO We could double this in UpdateFileStringAtCursor or also
	//give a few kilobytes and limit it anyways. This is 1000 chars right now though.
	cfsd.total_allocated_bytes = watch_name_string_max_size;
	InitFileString(*text_op.edit_watch_name, cfsd);

	//I think 10kb is around 250 lines so 15 kb is 375 lines, should be enough.
	//Could make this bigger but we could also just double the size of the dynamic string if we need more
	InitDynamicString(*text_op.console_dynamic_string, Kilobytes(15));

	//DOC : This message is only set internally so it should be fine at 1kb. Just keep the messages small.
	text_op.text_status_message = alloc_string(TEXT_STATUS_MESSAGE_SIZE);

	text_op.left_proportion = 1.0;
	// text_op.bottom_proportion = 0.0;
	text_op.bottom_proportion = 0.4;
	text_op.set_bottom_proportion = 0.4;
	text_op.l_bottom_left_proportion = text_op.left_proportion;
	text_op.l_bottom_pane_type = TextPaneType.NONE;

	text_op.r_bottom_pane_type = TextPaneType.NONE;
	text_op.r_bottom_height_proportion = text_op.bottom_proportion;
	text_op.set_r_bottom_height_proportion = text_op.r_bottom_height_proportion;

	text_op.name_proportion = 0.333333;
	// text_op.value_proportion = 0.4;
	text_op.type_proportion = 0.266666;

	//TODO Should likely run this one time on creation depending on size so it can be in the correct place.
	//TODO Should we run this in here or externally. Seems like in here is better on creation in case
	//we allow it to be adjust and then resize on any resize action.
	ResizeTextOpSpace(text_op, op_space.world_size, pixels_per_square, text_editor_data);

	//TODO We can set this to more if needed but I think 10 megabytes for a compiler is enough.
	//This also prevents large data grabs for no reason for example
	init(*text_op.text_comp_pool, Megabytes(15));
	text_op.text_comp_alloc.proc = flat_pool_allocator_proc;
	text_op.text_comp_alloc.data = *text_op.text_comp_pool;

	return text_op;
}

/*TODO We are recomputing these all the time so that we always
get the correct rect even if we change the size or move it BUT
eventually it may be better to store this in the TextOpSpace
and then only update them when we resize (maybe move) the op space.
I think it's just resize because all of these are op space relative
*/
OpSpaceRect :: inline (op_world_size : Vector2F) -> Rectangle2 {
	op_rect : Rectangle2 = RectCenterDim(Vector2F.{0,0}, op_world_size);
	return op_rect;
	// op_rect : Rectangle2 = RectCenterDim(op_2D_cam.world_pos, op_space.world_size);
}
//TODO we will put this in TextOpSpaceData and just update
//when resizing so we compute them all here now since we only need it
//when we render and when we check mouse input
/*DOC : All of these rects are op_relative so we can use the op_mouse
to check them and they are all calculated based on the op_rect
which is op_relative so is independent of the world and independent of the camera.
We convert the mouse from camera to op_space and then just check that for consistency
*/
AllTextOpRects :: struct {
	op_rect : Rectangle2;

	//Maybe we can remove left and right rect in favor of just
	//each quadrant rect (l_top,r_top,l_bottom,r_bottom)
	left_rect : Rectangle2;
	left_margin_rect : Rectangle2;
	l_top_rect : Rectangle2;
	l_bottom_rect : Rectangle2;

	//TODO Should add this now to compute height for text line bounds
	//DOC : I separated margin rect from text rect. I think it makes more sense this way, but let's see
	//how it feels as we go along. This way the behavior of the margin can be specifically coded in here
	//AND also then text rect is not confused as to whether it contains the margin or not.
	l_text_rect : Rectangle2;

	status_bar_rect : Rectangle2;
	status_bar_text_pos : Vector2F;

	first_bar_rect : Rectangle2;
	first_bar_text_rect : Rectangle2;
	first_bar_text_pos : Vector2F;
	first_bar_input_text_pos : Vector2F;

	second_bar_rect : Rectangle2;
	second_bar_text_rect : Rectangle2;
	second_bar_text_pos : Vector2F;
	second_bar_input_text_pos : Vector2F;

	top_bar_rect : Rectangle2;
	top_bar_text_offset : Vector2F;
	add_file_tab_rect : Rectangle2;

	//Split the left and right text op panes
	split_rect : Rectangle2;
	l_bottom_split_rect : Rectangle2;
	r_bottom_split_rect : Rectangle2;
	name_value_split_rect : Rectangle2;
	value_type_split_rect : Rectangle2;

	right_rect : Rectangle2;
	r_top_rect : Rectangle2;
	r_bottom_rect : Rectangle2;
	watch_name_rect : Rectangle2;
	watch_value_rect : Rectangle2;
	watch_type_rect : Rectangle2;


	//TODO Should we put top variables in ator?
	//Can do using temporarily
	// using top : TextOpPositions;
	//DOC : This is used also as the height for the rows in the watch pane
	//and also the asm text and call stack rows.
	TEXT_LINE_HEIGHT : float;
	//TODO I think these will always be the same but may change relative to font and stuff like that.
	//Would need to test with different fonts and different window sizes.
	// LOC_START_Y : float = 14.5 - text_op.top_margin_height;
	LOC_START_Y : float;
	// LOC_START_X : float = -19 + text_op.left_margin_char_width * perm.text_editor_data.code_font_1_char_width_world;
	MARGIN_END : float;
	//TODO This should be stored in TextOpSpaceData or something like that. Maybe not so we don't have readjust on size changes.
	// DEBUG_START_X : float = -19;
	DEBUG_START_X : float;

	//We adjust start_y for debugging so it is in line with the cursor and chars.
	cursor_height : float;
	// y_cursor_adjust : float;
	DEBUG_START_Y : float;

	CURSOR_WIDTH : float;
	X_GAP : float;
	LOC_START_X : float;

	//TODO Should we rename these and put X and 
	L_BOTTOM_LOC_ASM_Y : float;
	L_BOTTOM_LOC_ASM_X : float; 
	R_BOTTOM_LOC_CALL_STACK_Y : float;
	R_BOTTOM_LOC_CALL_STACK_X : float;
}
//TODO We can just rename this to UpdateTextOpRects and then use it
//more or less directly (just change the function call position)
//once we only compute this on resizing the text op space
UpdateTextOpRects :: inline (
	//This is a pointer so we can just update it later
	text_op : *TextOpSpaceData,
	op_world_size : Vector2F,
	//TODO Maybe we can remove this if the scaling is not great
	//or if it does not matter and we can just use a smaller r anyways
	pixels_per_square : float,
	ted : TextEditorData)
{
	ator : *AllTextOpRects = *text_op.ator;
	//pixles_per_square is 33 so 4/33 = 0.121212 so maybe
	//we can just set to 0.12 and use RectTopOutline and others
	//instead of using RectRender functions which takes in pixels as well
	rect_outline_r : float = 4.0;
	// rect_outline_r : float = 4.0/33;

	//NOTE : The base camera here should never change. Maybe we should store it in TextOpSpaceData instead.
	//We should be changing the other cameras instead.
	//So op_2D_cam.world_pos is always equal to Vector2F.{0,0} unless we move it eventually which we should not for text op space.
	// op_rect := RectCenterDim(Vector2F.{0,0}, op_world_size);
	op_rect : Rectangle2 = OpSpaceRect(op_world_size);
	// op_rect : Rectangle2 = RectCenterDim(op_2D_cam.world_pos, op_world_size);
	//TODO Can remove this if we don't need it outside since it is easily recomputible OR just store it and reuse it
	//in TextOpSpaceData like everything else
	ator.op_rect = op_rect;

	//DOC : We compute the data that may be required for rect here
	//so we can use it and we compute the data that may require the new rects at the bottom
	ator.TEXT_LINE_HEIGHT = ComputeTextLineHeight(text_op.text_line_height_factor,
		ted.char_height, pixels_per_square);
	// LOC_START_X : float = -19 + text_op.left_margin_char_width * ted.code_font_1_char_width_world;
	ator.MARGIN_END = ator.op_rect.min.x + text_op.left_margin_char_width * ted.code_font_1_char_width_world;
	//TODO This should be stored in TextOpSpaceData or something like that. Maybe not so we don't have readjust on size changes.
	// DEBUG_START_X : float = -19;
	ator.DEBUG_START_X = ator.op_rect.min.x + 0.5*(ator.MARGIN_END-ator.op_rect.min.x);

	//We adjust start_y for debugging so it is in line with the cursor and chars.
	ator.cursor_height = ComputeCursorHeight(ted.char_height, pixels_per_square);
	// ator.y_cursor_adjust = YAdjustCursorHeight(ator.cursor_height);

	//TODO we can set this from settings if needed as a thicker proportion maybe...
	ator.CURSOR_WIDTH = DefaultCursorWidth(ted.code_font_1_char_width_world);
	// ator.X_GAP = 2.3 * ator.CURSOR_WIDTH * ted.code_font_1_char_width_world;
	ator.X_GAP = DefaultXGap(ator.CURSOR_WIDTH, ted.code_font_1_char_width_world);
	/*DOC : Adding the gap here to loc start x also allows for the mouse to have some
	tiny give if we are scrolling to the left < loc start x to move past the bounds.
	Something to remember when changing it or testing it manually.
	*/
	ator.LOC_START_X = ator.MARGIN_END + ator.X_GAP;


	ator.left_rect = op_rect;
	ator.left_rect.max.x = op_rect.min.x + text_op.left_proportion*op_world_size.x;

	ator.left_margin_rect = op_rect;
	ator.left_margin_rect.max.x = op_rect.min.x + 
		(text_op.left_margin_char_width) * ted.code_font_1_char_width_world;

	//TODO We could make this start only from left_margin but it seems ok to move the cursor when we press breakpoint
	ator.l_top_rect = ator.left_rect;
	ator.l_top_rect.min.y = op_rect.min.y + text_op.bottom_proportion*op_world_size.y;

	//The first and second text bars require computation of
	//TEXT_LINE_HEIGHT and l_top_rect above
	//TODO I think we can compute l_text_rect after
	//so we add the total y from the text bars for the cursor bounds
	TB_HEIGHT_OFFSET :: 0.6;
	//DOC : We use this to adjust where we have to put the bars based on if we show the data bar or not
	//TODO We could generate these rects only if they are showing
	//but to be consistent all around we generate them regardless
	//and just check if their are showing for any input
	find_bar_y_factor : float = 0;
	find_bar_line_height_factor : float = text_op.text_line_height_factor-0.15;
	left_margin_width : float = text_op.left_margin_char_width * ted.code_font_1_char_width_world;
	text_bar_width : float = GetWidth(ator.l_top_rect);
	status_bar_min := ator.l_top_rect.min;
	status_bar_dim := Vector2F.{text_bar_width, find_bar_line_height_factor*ator.TEXT_LINE_HEIGHT};
	ator.status_bar_rect = RectMinDim(status_bar_min, status_bar_dim);
	if text_op.show_text_status_bar {
		find_bar_y_factor = 1.0;
	}
	ator.status_bar_text_pos = Vector2F.{status_bar_min.x + ator.X_GAP, 
		ator.l_top_rect.min.y + 
		TB_HEIGHT_OFFSET*find_bar_line_height_factor*ator.TEXT_LINE_HEIGHT};


	//Default to empty string for NONE case
	text_op.first_bar_name_text = "";
	if text_op.text_first_bar_type == TextFirstBarType.FIND_TEXT {
		text_op.first_bar_name_text = "Find:";				
		if text_op.text_second_bar_type == TextSecondBarType.REPLACE_TEXT {
			text_op.first_bar_name_text = "Find   :";
		}
	} else if text_op.text_first_bar_type == TextFirstBarType.GOTO_LINE {
		text_op.first_bar_name_text = "Goto Line:";
	}
	left_type_text_width_world : float = 
		text_op.first_bar_name_text.count*ted.code_font_1_char_width_world;
	TH_OFFSET :: 0.05;
	TH_DIM_OFFSET :: 0.09;
	first_bar_min : Vector2F;
	first_bar_min.x = ator.op_rect.min.x;
	first_bar_min.y = ator.l_top_rect.min.y + find_bar_y_factor*find_bar_line_height_factor*ator.TEXT_LINE_HEIGHT;
	first_bar_dim := Vector2F.{text_bar_width, find_bar_line_height_factor*ator.TEXT_LINE_HEIGHT};
	ator.first_bar_rect = RectMinDim(first_bar_min, first_bar_dim);
	first_text_min : Vector2F = ator.first_bar_rect.min;
	first_text_min.x += left_type_text_width_world;
	first_text_min.y += TH_OFFSET * ator.TEXT_LINE_HEIGHT;
	first_text_dim := Vector2F.{text_bar_width - left_type_text_width_world,
		(find_bar_line_height_factor-TH_DIM_OFFSET)*ator.TEXT_LINE_HEIGHT};
	ator.first_bar_text_rect = RectMinDim(first_text_min, first_text_dim);
	ator.first_bar_text_pos = Vector2F.{ator.first_bar_rect.min.x + ator.X_GAP,
		ator.l_top_rect.min.y + 
		(find_bar_y_factor+TB_HEIGHT_OFFSET)*find_bar_line_height_factor*ator.TEXT_LINE_HEIGHT};
	ator.first_bar_input_text_pos = ator.first_bar_text_pos;
	ator.first_bar_input_text_pos.x += left_type_text_width_world;


	//Default to empty string for NONE case
	text_op.second_bar_name_text = "";
	if text_op.text_second_bar_type == .REPLACE_TEXT {
		text_op.second_bar_name_text = "Replace:";
	}
	left_second_text_width_world : float = text_op.second_bar_name_text.count*ted.code_font_1_char_width_world;
	ator.second_bar_rect = ator.first_bar_rect;
	MoveRect(.{0,find_bar_line_height_factor*ator.TEXT_LINE_HEIGHT}, 
		*ator.second_bar_rect);
	second_text_min : Vector2F = ator.second_bar_rect.min;
	second_text_min.x += left_second_text_width_world;
	second_text_min.y += TH_OFFSET * ator.TEXT_LINE_HEIGHT;
	second_text_dim := Vector2F.{text_bar_width - left_second_text_width_world,
		(find_bar_line_height_factor-TH_DIM_OFFSET)*ator.TEXT_LINE_HEIGHT};
	ator.second_bar_text_rect = RectMinDim(second_text_min, second_text_dim);
	ator.second_bar_text_pos = Vector2F.{ator.first_bar_text_pos.x, 
		ator.l_top_rect.min.y + 
		(find_bar_y_factor+1+TB_HEIGHT_OFFSET)*find_bar_line_height_factor*ator.TEXT_LINE_HEIGHT};
	ator.second_bar_input_text_pos = ator.second_bar_text_pos;
	ator.second_bar_input_text_pos.x += left_type_text_width_world;


	//DOC : We use l_text_rect to compute things like lines or anything
	//else that just involves the text (maybe right and left char bounds if we put things on left and right later)
	//TODO Should we add the margin to the x here?
	ator.l_text_rect = ator.l_top_rect;
	ator.l_text_rect.min.x = ator.MARGIN_END;
	if text_op.show_text_status_bar {
		status_bar_height : float = GetHeight(text_op.ator.status_bar_rect);
		ator.l_text_rect.min.y += status_bar_height;
	}
	if text_op.text_first_bar_type != TextFirstBarType.NONE {
		first_bar_height : float = GetHeight(text_op.ator.first_bar_rect);
		ator.l_text_rect.min.y += first_bar_height;
		//We can only have second bar if we have first bar
		if text_op.text_second_bar_type != TextSecondBarType.NONE {
			second_bar_height : float = GetHeight(text_op.ator.second_bar_rect);
			ator.l_text_rect.min.y += second_bar_height;
		}
	}

	top_bar_min := Vector2F.{ator.l_top_rect.min.x,
		ator.l_top_rect.max.y - ator.TEXT_LINE_HEIGHT};
	top_bar_dim := Vector2F.{text_bar_width, ator.TEXT_LINE_HEIGHT};
	ator.top_bar_rect = RectMinDim(top_bar_min, top_bar_dim);
	ator.top_bar_text_offset.x = ator.X_GAP;
	ator.top_bar_text_offset.y = TB_HEIGHT_OFFSET * top_bar_dim.y;
	if text_op.text_top_bar_type != TextTopBarType.NONE {
		ator.l_text_rect.max.y -= top_bar_dim.y;
	}
	ator.add_file_tab_rect = ator.top_bar_rect;
	ator.add_file_tab_rect.min.x = ator.top_bar_rect.max.x - 1.5 * ted.code_font_1_char_width_world;


	/*DOC : We need to compute this after the text bar rects so we adjust based on the
	bottom find/replace bar and also the top file tab bar where the text
	and cursor are started drawing.
	*/
	//TODO I think these will always be the same but may change relative to font and stuff like that.
	//Would need to test with different fonts and different window sizes.
	// LOC_START_Y : float = 14.5 - text_op.top_margin_height;
	ator.LOC_START_Y = ator.l_text_rect.max.y - 0.5*ator.TEXT_LINE_HEIGHT - text_op.top_margin_height;
	ator.DEBUG_START_Y = ator.LOC_START_Y - YAdjustCursorHeight(ator.cursor_height);


	ator.l_bottom_rect  = ator.left_rect;
	ator.l_bottom_rect.max.y = op_rect.min.y + text_op.bottom_proportion*op_world_size.y;

	//DOC: We compute the position that require rects down here so we make sure to to compute the rects first
	ator.L_BOTTOM_LOC_ASM_Y = ator.l_bottom_rect.max.y - 0.5*ator.TEXT_LINE_HEIGHT - text_op.top_margin_height;
	ator.L_BOTTOM_LOC_ASM_X = ator.LOC_START_X;


	ator.l_bottom_split_rect = RectRenderTopOutline(ator.l_bottom_rect, rect_outline_r, pixels_per_square);

	right_proportion : float = 1.0 - text_op.left_proportion;
	right_min := Vector2F.{op_rect.min.x + text_op.left_proportion*op_world_size.x, op_rect.min.y};
	// ator.split_rect = RectCenterDim(right_min + Vector2F.{0,0.5*op_world_size.y}, 
	// 	Vector2F.{0.1,op_world_size.y});
	ator.right_rect = RectMinDim(right_min, 
		Vector2F.{right_proportion*op_world_size.x, op_world_size.y});
	ator.split_rect = RectRenderLeftOutline(ator.right_rect, rect_outline_r/2, pixels_per_square);

	/*DOC : If r_bottom_pane_type is closed, then
	r_top_rect = right_rect
	since we always have the right_rect open in debug mode
	This prevents overclicks when we are clicking on the bottom
	call stack pane to not touch the watch pane split rects or watch names.
	*/
	ator.r_top_rect = ator.right_rect;
	//TODO I don't think we need this anymore since we update proportions to keep
	//proportion values consistent with the rects that we are seeing then.
	// if text_op.r_bottom_pane_type != .NONE {
	ator.r_top_rect.min.y = op_rect.min.y + text_op.r_bottom_height_proportion*op_world_size.y;
	// }


	//TODO Would need to use l_bottom_left_proportion here if we wanted to 
	//allow adjusting on the horizontal instead of the vertical for the bottom
	// r_bottom_height_proportion : float = 1.0 - text_op.l_bottom_left_proportion;
	ator.r_bottom_rect = ator.right_rect;
	// ator.r_bottom_rect.max.y = op_rect.min.y + text_op.bottom_proportion*op_world_size.y;
	ator.r_bottom_rect.max.y = op_rect.min.y + text_op.r_bottom_height_proportion*op_world_size.y;
	ator.r_bottom_split_rect = RectRenderTopOutline(ator.r_bottom_rect, rect_outline_r, pixels_per_square);

	//Compute these her since it requires r_bottom_rect
	ator.R_BOTTOM_LOC_CALL_STACK_Y = ator.r_bottom_rect.max.y - 0.5*ator.TEXT_LINE_HEIGHT - text_op.top_margin_height;
	ator.R_BOTTOM_LOC_CALL_STACK_X = ator.r_bottom_rect.min.x + ator.X_GAP;


	//TODO These proportions should be stored in TextOpSpaceData so they can be udpate per text op
	// name_proportion : float = 0.333333;
	//We could store this or just grab the dim back after if we need it
	name_rect_dim : Vector2F = GetDim(ator.r_top_rect);
	name_rect_dim.x *= text_op.name_proportion;
	ator.watch_name_rect = RectMinDim(ator.r_top_rect.min, name_rect_dim);


	value_proportion : float = 1.0-text_op.name_proportion-text_op.type_proportion;
	value_rect_min : Vector2F = ator.watch_name_rect.min;
	value_rect_min.x += name_rect_dim.x;
	value_rect_dim : Vector2F = GetDim(ator.r_top_rect);
	value_rect_dim.x *= value_proportion;
	ator.watch_value_rect = RectMinDim(value_rect_min, value_rect_dim);

	ator.name_value_split_rect = RectRenderRightOutline(ator.watch_name_rect, rect_outline_r/2, pixels_per_square);
	ator.value_type_split_rect = RectRenderRightOutline(ator.watch_value_rect, rect_outline_r/2, pixels_per_square);

	// type_proportion : float = 1.0-text_op.name_proportion-text_op.value_proportion;
	type_rect_min : Vector2F = ator.watch_value_rect.min;
	type_rect_min.x += value_rect_dim.x;
	type_rect_dim : Vector2F = GetDim(ator.r_top_rect);
	type_rect_dim.x *= text_op.type_proportion;
	ator.watch_type_rect = RectMinDim(type_rect_min, type_rect_dim);
}
//TODO We could do this with just atore and not have in the cam if needed
//This way lets us compute the camera rectangle once with the whole top bar rect
//and then compute everything else relative to that.
CreateAllTabsRect :: inline (
	ator : AllTextOpRects)
-> Rectangle2 
{
	//TODO If we add other tab rect options, then we can subtract them here
	all_tabs_rect : Rectangle2 = ator.top_bar_rect;
	add_tab_width : float = GetWidth(ator.add_file_tab_rect);
	all_tabs_rect.max.x -= add_tab_width;
	return all_tabs_rect;	
}
//TODO Can replace this with a dynamic array in UpdateTextOpRects
CreateFileTabOpRects :: inline (
	text_op : TextOpSpaceData)
-> [] Rectangle2
{
	all_tabs_rect : Rectangle2 = CreateAllTabsRect(text_op.ator);

	file_tab_rects : [] Rectangle2 = 
		NewArray(text_op.file_tabs.count, Rectangle2,,temp);
	sub_rect_count := cast(float) max(5, text_op.file_tabs.count);
	for tab, tab_index : text_op.file_tabs {
		file_tab_rects[tab_index] = GetSubRect(all_tabs_rect, sub_rect_count, cast(float) tab_index);
	}
	return file_tab_rects;
}
GetFileTabXRect :: inline (
	tab_rect : Rectangle2,
	char_width_world : float) 
-> Rectangle2
{
	tab_height : float = GetHeight(tab_rect);
	close_full_rect : Rectangle2 = tab_rect;
	close_full_rect.min.x = tab_rect.max.x - tab_height;
	close_rect_center : Vector2F = GetCenter(close_full_rect);
	close_tab_dim : Vector2F = 0.4 * GetDim(close_full_rect);
	close_tab_rect : Rectangle2 = RectCenterDim(close_rect_center, close_tab_dim);
	return close_tab_rect;
}
/*DOC : For now this seems like a good limit. Later we could add
scrolling file tabs if needed but I am not sure more than 20 is a good idea.
I could up it to 30 if needed but would need to check the size in debug mode
Probably 30 is good out of debug mode. Also without file tab visually
it does not matter how many we have.
*/
MAX_TEXT_FILE_TABS : int : 20;
TEXT_TAB_MAX_MSG :: "Max 20 tabs already open";
OpenFileTabWithExplorer :: inline (
	text_op : *TextOpSpaceData,
	all_text_files : *[..] TextFile,
	op_space : OperationSpace,
	ted : TextEditorData)
//TODO Could return fe_result if thats needed here like error info or something else
-> *TextFile, found_text_file : bool
{
	//DOC : We put this here to prevent the explorer from opening unnecessarily if we hit the tab limit.
	if text_op.file_tabs.count == MAX_TEXT_FILE_TABS {
		SetTextStatus(TEXT_TAB_MAX_MSG, text_op);
	}

	fe_result := OpenFileWithExplorer();
	if !fe_result.file_success {
		SetTextStatus(fe_result.error_msg, text_op);
		return null, false;
	}
	text_file, found_text_file := OpenFileTab(fe_result.file_name, text_op, all_text_files, op_space, ted);
	return text_file, found_text_file;
}
/*DOC : This can be used to add file tabs by name maybe from terminal
OR also to add file tabs programatically in tests or dynamic libraries.
*/
//TODO Rename this to OpenFileTab since we open the tab if we already have the file in this text op space
OpenFileTab :: inline (
	absolute_file_name : string,
	text_op : *TextOpSpaceData,
	all_text_files : *[..] TextFile,
	op_space : OperationSpace,
	ted : TextEditorData)
-> *TextFile, found_text_file : bool
{
	if text_op.file_tabs.count == MAX_TEXT_FILE_TABS {
		SetTextStatus(TEXT_TAB_MAX_MSG, text_op);
	}
	//TODO Could pull this out to LoadFileTab by file name directly
	//Can use this for tests and also when opening a text op space from a file later
	text_file, found_text_file := GetOrLoadTextFileByAbsolutePath(absolute_file_name, all_text_files);
	if found_text_file {
		tab_index : int;
		text_file_already_open_in_this_text_op_space : bool = false;
		for text_op.file_tabs if it.text_file_id == text_file.id {
			tab_index = it_index;
			text_file_already_open_in_this_text_op_space = true;
			break;
		}

		if !text_file_already_open_in_this_text_op_space {
			new_tab : *TextTab = array_add(*text_op.file_tabs);
			new_tab.text_file_id = text_file.id;
			tab_index = text_op.file_tabs.count-1;
			//DOC : Resize to adjust tab cursors properly with new tab
			//Technically we can just update the cursor bounds for this tab but this seems more resilient overall
			//in case we change something later where adding the tab depends on or changes something else in the text op space.
			ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square, ted);
			//We will see the file if it opened so I don't think we need to set a text status here but we can if needed later
			// SetTextStatus(tprint("Opened file %", fe_result.file_name), text_op);
		}

		ChangeTextTab(tab_index, text_file, text_op);
	} 
	else {
		SetTextStatus(tprint("Cannot find file %", absolute_file_name), text_op);
	}	

	return text_file, found_text_file;
}
CloseFileTab :: inline (
	tab_index : int,
	text_op : *TextOpSpaceData,
	all_data : *AllData) 
{
	//TODO this is overkill since we just want to unselect the bottom bar but in case we pull it out
	//or something later this is likely more resilient overall.
	//This also auto-saves now so if we close a file tab, then this will save it before closing
	ChangeTextPane(SelectedTextPane.TEXT, text_op, all_data);
	//DOC : We don't allow the last file tab to be closed
	if text_op.file_tabs.count > 1 {
		//TODO We could do this more efficiently with a memcpy
		array_ordered_remove_by_index(*text_op.file_tabs, tab_index);
	}
	//TODO We only need to do this if we store the file tab rects in text_op and then likely recompute
	//this or can do something more efficient as well
	// ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
	// 	perm.text_editor_data);
}
/*TODO We can optimize this later if fetching text files
is always in order by text_file_id. I guess we can sort it
by text_file_id whenever we add a new file. We don't currently
remove files, but if we do, then we can use the removed file slot
whenever we add a new file.
*/
//We don't pass back found_text_file right now because we assert in here since all tab text files should be found
//internally to remain consistent with both the os file system and our own internal text file state.
GetTabTextFile :: inline (
	tab_index : int,
	text_op : *TextOpSpaceData,
	all_text_files : [] TextFile) 
-> *TextFile
{
 	text_file, found_text_file := 
 		GetTextFileById(text_op.file_tabs[tab_index].text_file_id, all_text_files);
	//Tab should always have a valid text file right now
	assert(found_text_file);
	return text_file;
}

//TODO Can remove this once we have everything else working
#if 0 {
TextOpPositions :: struct {
	//DOC : This is used also as the height for the rows in the watch pane
	//and also the asm text and call stack rows.
	TEXT_LINE_HEIGHT : float;
	//TODO I think these will always be the same but may change relative to font and stuff like that.
	//Would need to test with different fonts and different window sizes.
	// LOC_START_Y : float = 14.5 - text_op.top_margin_height;
	LOC_START_Y : float;
	// LOC_START_X : float = -19 + text_op.left_margin_char_width * perm.text_editor_data.code_font_1_char_width_world;
	MARGIN_END : float;
	//TODO This should be stored in TextOpSpaceData or something like that. Maybe not so we don't have readjust on size changes.
	// DEBUG_START_X : float = -19;
	DEBUG_START_X : float;

	//We adjust start_y for debugging so it is in line with the cursor and chars.
	cursor_height : float;
	y_cursor_adjust : float;
	DEBUG_START_Y : float;

	CURSOR_WIDTH : float;
	X_GAP : float;
	LOC_START_X : float;

	//TODO Should we rename these and put X and 
	L_BOTTOM_LOC_ASM_Y : float;
	L_BOTTOM_LOC_ASM_X : float; 
	R_BOTTOM_LOC_CALL_STACK_Y : float;
	R_BOTTOM_LOC_CALL_STACK_X : float;
}
ComputeTextOpPositions :: inline (
	ator : AllTextOpRects,
	op_space : OperationSpace,
	text_op : *TextOpSpaceData,
	//TODO Maybe put this in text op eventually and have 1 per TextOpSpaceData
	text_editor_data : TextEditorData) 
-> TextOpPositions
{
	top : TextOpPositions;

	top.TEXT_LINE_HEIGHT = ComputeTextLineHeight(text_op.text_line_height_factor,
		text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);
	//TODO I think these will always be the same but may change relative to font and stuff like that.
	//Would need to test with different fonts and different window sizes.
	// LOC_START_Y : float = 14.5 - text_op.top_margin_height;
	top.LOC_START_Y = ator.op_rect.max.y - 0.5*top.TEXT_LINE_HEIGHT - text_op.top_margin_height;
	// LOC_START_X : float = -19 + text_op.left_margin_char_width * text_editor_data.code_font_1_char_width_world;
	top.MARGIN_END = ator.op_rect.min.x + text_op.left_margin_char_width * text_editor_data.code_font_1_char_width_world;
	//TODO This should be stored in TextOpSpaceData or something like that. Maybe not so we don't have readjust on size changes.
	// DEBUG_START_X : float = -19;
	top.DEBUG_START_X = ator.op_rect.min.x + 0.5*(top.MARGIN_END-ator.op_rect.min.x);

	//We adjust start_y for debugging so it is in line with the cursor and chars.
	top.cursor_height = ComputeCursorHeight(text_editor_data.char_height, op_space.render_groups.scissor_group.pixels_per_square);
	top.y_cursor_adjust = YAdjustCursorHeight(top.cursor_height);
	top.DEBUG_START_Y = top.LOC_START_Y - top.y_cursor_adjust;

	top.CURSOR_WIDTH = 0.15*text_editor_data.code_font_1_char_width_world;
	top.X_GAP = 2.3 * top.CURSOR_WIDTH * text_editor_data.code_font_1_char_width_world;
	top.LOC_START_X = top.MARGIN_END + top.X_GAP;


	top.L_BOTTOM_LOC_ASM_Y = ator.l_bottom_rect.max.y - 0.5*top.TEXT_LINE_HEIGHT - text_op.top_margin_height;
	top.L_BOTTOM_LOC_ASM_X = top.LOC_START_X;


	top.R_BOTTOM_LOC_CALL_STACK_Y = ator.r_bottom_rect.max.y - 0.5*top.TEXT_LINE_HEIGHT - text_op.top_margin_height;
	top.R_BOTTOM_LOC_CALL_STACK_X = ator.r_bottom_rect.min.x + top.X_GAP;


	return top;
}
}

ComputeTextLineHeight :: inline (
	line_height_factor : float,
	char_height : int,
	pixels_per_square : float) 
-> float 
{
	result : float = line_height_factor * char_height / pixels_per_square;
	return result;
}

/*DOC : This gives use the line count from 0 which is why we subtract 1.
This way we stay within the indices when we add it to avoid issues.
*/
TextOpSpaceLineCountFromZero :: inline (world_height : float, line_height : float) -> int {
	// text_lines : int = round_to_int(external_data.world_size.y / TEXT_LINE_HEIGHT) - 1;
	// text_lines : int = floor_to_int(external_data.world_size.y / TEXT_LINE_HEIGHT) - 1;	
	lines : int = floor_to_int(world_height / line_height) - 1;
	return lines;
}

TextEditorCharWidth :: inline (
	text_proportion : float,
	world_length : float,
	char_world_width : float) 
-> int 
{
	//TODO Should we subtract the margin here? For mouse we will
	//be able to click in the margin or in the editor.
	//If we subtract the margin here, then we have to remove the subtraction
	//from UpdateTextCursorRightBound
	full_width := cast(int) 
		(text_proportion * world_length / char_world_width);
	return full_width;
}

ComputeTextRectWorldHeight :: inline (
	bottom_proportion : float,
	//TODO Could just pass in the height here
	op_space_world_size : Vector2F)
-> float 
{
	text_rect_world_height : float = 
		(1.0-bottom_proportion) * op_space_world_size.y;
	return text_rect_world_height;
}

//TODO Could put this in ResizeTextOpSpace if that is the only place we use it anyways.
UpdateTextCursorRightBound :: inline (
	cursor : *TextCursor,
	text_op : TextOpSpaceData,
	op_space_world_length : float,
	char_world_width : float) 
{
	text_full_width : int = TextEditorCharWidth(
		text_op.left_proportion, op_space_world_length, char_world_width);
	left_right_bound_diff : int = 
		text_full_width - (text_op.left_margin_char_width+text_op.x_pre_move);
	cursor.right_char_bound = cursor.left_char_bound + left_right_bound_diff;

	/*DOC TODO I wrote this here but actually it might be better to not have it since
	the cursor_line_char could at some point not be updated so if we adjust the size of the
	window then we have to manually bring the cursor back in focus.
	In other text editors, resizing a pane or window does not move 
	the cursor which I think feels more natural and is less prone to error
	since we just adjust the cursor based on user input after which I think is tested.
	*/
	// if cursor.cursor_line_char > cursor.right_char_bound {
	// 	cursor.right_char_bound = cursor.cursor_line_char;
	// 	cursor.left_char_bound = cursor.right_char_bound - left_right_bound_diff;
	// }
}

TextViewableLinesFromZero :: inline (
	//TODO I think we should pass in text_line_height_factor
	//instead if that's all we use since it is confusing what we
	//are using from the struct in here.
	text_line_height_factor : float,
	text_rect_world_height : float,
	char_height : int,
	pixels_per_square : float) 
-> int 
{
	line_height : float = ComputeTextLineHeight(text_line_height_factor,
		char_height, pixels_per_square);
	// op_space_lines : int = round_to_int(external_data.world_size.y / line_height) - 1;
	viewable_lines : int = TextOpSpaceLineCountFromZero(text_rect_world_height, line_height);
	// viewable_lines : int = floor_to_int(op_space_world_size.y / line_height) - 1;
	// return viewable_lines;
	//Just in case in TextOpSpaceLineCountFromZero we get -1 we get max with 0 here.
	return max(viewable_lines,0);
}

UpdateTextLineBounds :: inline (
	cursor : *TextCursor,
	text_line_height_factor : float,
	text_rect_world_height : float,
	char_height : int,
	pixels_per_square : float)
	//TODO We could pass in the FileStrin here if needed
	// file_string_loc : int)
{
	//TODO Remove this function and old TextOpSpaceLineCountFromZero
	//TODO We could just pull this out now and apply it to each tab in Resize
	//Or reuse this when we move/add to new tab
	viewable_lines : int = TextViewableLinesFromZero(text_line_height_factor, text_rect_world_height, 
		char_height, pixels_per_square);

	//If we adjust the text_space but then we have more viewable lines then
	//we need to adjust the start_file_line_index to account for that.
	//eg if we are at the bottom of a file and remove the bottom rects.
	#if 0 {
	old_viewable_lines : int = cursor.end_file_line_index - cursor.start_file_line_index;
	if viewable_lines > old_viewable_lines {
		viewable_diff : int = viewable_lines - old_viewable_lines;
		cursor.start_file_line_index -= viewable_diff; 
		if cursor.start_file_line_index < 0 {
			cursor.start_file_line_index = 0;
		}
	}
	}

	//TODO We can bring in file_string_loc if that makes more sense
	//but I find it feels better that it just stays in the same place right now
	cursor.end_file_line_index = cursor.start_file_line_index + viewable_lines;
	// if cursor.end_file_line_index >= file_string_loc {
	// 	cursor.end_file_line_index = file_string_loc-1;
	// }

	//Some old code for other ways to set end_file_line_index. Can remove if we don't use it
	// cursor.end_file_line_index = max(viewable_lines,0);
	// cursor.end_file_line_index = 
	// 	cursor.start_file_line_index + viewable_lines;
	// cursor.end_file_line_index = min(viewable_lines, 
	// 	max(0,perm.all_data.all_text_files[0].file_loc.count-1));
	// cursor.end_file_line_index = 
	// 	min(OP_SPACE_VIEWABLE_LINE_COUNT, 
	// 		max(0,perm.all_data.all_text_files[0].file_loc.count-1));


	//TODO Could update cursor_line_number here as well
	//Would have to update char_point with a MoveCursor function
	//Tried it but it messed with movement. Maybe will come back later. 
	// if cursor.cursor_line_number > cursor.end_file_line_index {
	// 	cursor.cursor_line_number = cursor.end_file_line_index;
	// } else if cursor.cursor_line_number < cursor.start_file_line_index {
	// 	cursor.cursor_line_number = cursor.start_file_line_index;
	// }
}

/*NOTE Reminder : this does not require text_op.file_tabs[text_op.ftab_i].text_file_id since we 
don't use the file in here.
*/
ResizeTextOpSpace :: inline (
	text_op : *TextOpSpaceData,
	op_space_world_size : Vector2F,
	pixels_per_square : float,
	ted : TextEditorData)
	//TODO I think we can remove these now because 
	//we limit them in the rendering instead of here.
	// file_string_loc : int,
	// disasm_loc : int)
{
	//TODO Maybe this is not the best place to make these adjustment
	//but it keeps things consistent in case we update panes in other places.
	//We could pull it out when we do r_bottom if that is simpler.
	#if 1 {
	if text_op.l_bottom_pane_type == .NONE text_op.bottom_proportion = 0;
	else text_op.bottom_proportion = text_op.set_bottom_proportion;

	if text_op.r_bottom_pane_type == .NONE text_op.r_bottom_height_proportion = 0;
	else text_op.r_bottom_height_proportion = text_op.set_r_bottom_height_proportion;

	if text_op.exec_info.exec_mode == .DEBUG text_op.left_proportion = text_op.set_left_proportion;
	else text_op.left_proportion = 1.0;
	}
	//TODO FROM HERE add set_left_proportion so we use the same
	//as above and then adjust that in here instead of on toggling
	//so we always set it and then the rects and proportion match up
	//otherwise they are not consistent and that seems worse.
	//Then we can likely remove that check for r_top_rect
	//Then we can recompute the text op space rects here and store it
	//in the text_op and then use that everywhere.
	//TODO Maybe we should the code from UpdateTextOpRects in here if we only use it here
	UpdateTextOpRects(text_op, op_space_world_size, pixels_per_square, ted);


	//TODO We could do this based on exec_mode instead of bottom_proportion if that is better.
	//TODO We could put the code for this back in here if we only ever
	//use the ResizeTextOpSpace function everywhere now.
	//TODO We could pull this out and only update tabs when we make adjustements or move between tabs
	//although resizing is not expensive and may lead to more resilient consistency.
	// text_rect_world_height : float = ComputeTextRectWorldHeight(text_op.bottom_proportion, op_space_world_size);
	text_rect_world_height : float = GetHeight(text_op.ator.l_text_rect);
	for * text_op.file_tabs {
		//TODO Technically this is the same for each tab so we could just compute it once and then set the same value for each tab
		//but just in case we recompute it. Maybe something will change later but if not we can do that instead.
		UpdateTextLineBounds(*it.tab_cursor, text_op.text_line_height_factor,
			text_rect_world_height, ted.char_height, pixels_per_square);
			// (1.0-text_op.bottom_proportion) * op_space_world_size.y,

		UpdateTextCursorRightBound(*it.tab_cursor, text_op, op_space_world_size.x, ted.code_font_1_char_width_world);
		// print("start=%,end=%", it.tab_cursor.start_file_line_index, it.tab_cursor.end_file_line_index);
	}

	//TODO Adjust this
	line_height : float = ComputeTextLineHeight(text_op.text_line_height_factor,
		ted.char_height, pixels_per_square);
	// op_space_lines : int = round_to_int(external_data.world_size.y / line_height) - 1;
	r_top_rect_height : float = GetHeight(text_op.ator.r_top_rect);
	viewable_lines : int = TextOpSpaceLineCountFromZero(r_top_rect_height, line_height);
	// viewable_lines : int = floor_to_int(op_space_world_size.y / line_height) - 1;
	//TODO Need to do the same thing for start_watch_index
	//as we are doing for text_viewable_lines once we cover it
	text_op.end_watch_index = text_op.start_watch_index + viewable_lines;
	watch_width : float = GetWidth(text_op.ator.r_top_rect);
	watch_char_size := cast(int) (watch_width / ted.code_font_1_char_width_world);
	//TODO FROM HERE if cursor >= right_char_bound, then we could
	//move left and right char bound so the its right = cursor and left = cursor - size
	text_op.watch_cursor.right_char_bound = text_op.watch_cursor.left_char_bound + watch_char_size;

	first_bar_width : float = GetWidth(text_op.ator.first_bar_text_rect);
	first_bar_char_size := cast(int) (first_bar_width / ted.code_font_1_char_width_world);
	text_op.first_bar_cursor.right_char_bound = text_op.first_bar_cursor.left_char_bound + first_bar_char_size - 1;
	second_bar_width : float = GetWidth(text_op.ator.second_bar_text_rect);
	second_bar_char_size := cast(int) (second_bar_width / ted.code_font_1_char_width_world);
	text_op.second_bar_cursor.right_char_bound = text_op.second_bar_cursor.left_char_bound + second_bar_char_size - 1;


	//NOTE : We can always set this since disasm_index is the viewable_index
	//and bounding it is done in rendering and with input. This allows us to avoid
	//having to resize thing when it is < the viewable size since its always the viewable size.
	bottom_viewable_lines : int = TextOpSpaceLineCountFromZero(text_op.bottom_proportion * op_space_world_size.y, line_height);
	text_op.end_disasm_index = text_op.start_disasm_index + bottom_viewable_lines;

	r_bottom_viewable_lines : int = TextOpSpaceLineCountFromZero(text_op.r_bottom_height_proportion * op_space_world_size.y, line_height);
	text_op.end_call_stack_index = text_op.start_call_stack_index + r_bottom_viewable_lines;
	//TODO We can remove this because we adjust the end_index for rendering
	//at the renderer so this can give us the total index anyways
	// if text_op.end_disasm_index >= disasm_loc {
	// 	text_op.end_disasm_index = disasm_loc-1;
	// }


	//Update the console sizes and split lines
	//TODO We could eventually even generalize TextSplitLine data based on the
	//rectangle we are putting the lines in but for now
	text_op.console_tsl.line_height = text_op.ator.TEXT_LINE_HEIGHT;
	text_op.console_tsl.cursor_height = text_op.ator.cursor_height;
	text_op.console_tsl.x_start_left = text_op.ator.op_rect.min.x + text_op.ator.X_GAP;
	text_op.console_tsl.y_start_top = text_op.ator.l_bottom_rect.max.y - 0.5*text_op.console_tsl.line_height - text_op.top_margin_height;
	text_op.console_tsl.line_char_count = cast(int) (GetWidth(text_op.ator.l_bottom_rect) / ted.code_font_1_char_width_world);
	text_op.console_tsl.line_char_count -= 1;
	// text_op.console_tsl.viewable_lines_from_zero = 1 + (cast(int) (console_height / text_op.ator.TEXT_LINE_HEIGHT));
	console_height : float = GetHeight(text_op.ator.l_bottom_rect);
	text_op.console_tsl.viewable_lines_from_zero = TextViewableLinesFromZero(text_op.text_line_height_factor, console_height, 
		ted.char_height, pixels_per_square);
	//Need to redo the split lines on resize so that they fit with the new line char count
	//TODO We can generalize this if we print out more lines to the text console
	//then we can just copy all the lines over somehwere and just use those
	text_op.console_tsl.split_lines.count = 0;
	ResizeTextOpSplitLines(text_op);
}
//TODO Unit test dynamic strings
//TODO Maybe unit test this now
//We will integration test it with input mappings
SetTextOpConsoleMessage :: inline (
	msg : string, 
	text_op : *TextOpSpaceData,
	$add_text : bool = false,
	$reset_console_highlights : bool = true) 
{
	#if add_text {
	//Add a new line if the last character is not a new line
	if text_op.console_dynamic_string.text_string.count > 0 &&
		#char "\n" != text_op.console_dynamic_string.text_string[text_op.console_dynamic_string.text_string.count-1]
	{
		AddDynamicString("\n", *text_op.console_dynamic_string);
	}
	AddDynamicString(msg, *text_op.console_dynamic_string);
	} else {
	#if reset_console_highlights array_reset_keeping_memory(*text_op.console_highlights);
	SetDynamicStringFromStart(msg, *text_op.console_dynamic_string);
	}
	ResetTextCursor(*text_op.console_tsl.cursor);
	array_reset_keeping_memory(*text_op.all_console_lines);
	//NOTE : The last value here is an empty line if there is no remainder
	split_lines : [] string = String.split(text_op.console_dynamic_string.text_string, "\n",,temp);
	if split_lines.count > 0 && peek(split_lines).count == 0 {
		split_lines.count -= 1;
	}
	array_copy(*text_op.all_console_lines, split_lines);
	ResizeTextOpSplitLines(text_op);
}
//TODO Can use a seimilar function for terminal split lines as well if we add text coloring or highlighting for terminal as well
ResizeTextOpSplitLines :: inline (text_op : *TextOpSpaceData) {
	array_reset_keeping_memory(*text_op.console_tsl.split_lines);
	for text_op.all_console_lines {
		AddSplitStringByLines(it, *text_op.console_tsl);
	}

	array_reset_keeping_memory(*text_op.console_tsl.split_selcs);
	for text_op.console_highlights {
		//TODO We could just skip over if this is the case but we should be clearing the console highlights
		//So we just double check here to make sure that is happening
		assert(it.char_point + it.char_count < text_op.console_dynamic_string.text_string.count);
		highlight_selc : StartEndLineChar = CharPointToSplitSelc(it.char_point, it.char_count, 
			text_op.console_dynamic_string.text_string, text_op.console_tsl);
		array_add(*text_op.console_tsl.split_selcs, highlight_selc);
		// print("highlight_selc=%\n", highlight_selc);
		//TODO we could store the rects in here instead since it would be half the size and not require recomputation
		//but we do it while rendering for now
		//We don't now because we could use the selc to highlight OR change text color OR anything else which 
		//allows more generalization later so we can change the text however we want
		//TODO maybe we highlight text later that is selectable
		// for line_number : highlight_selc.start_line..highlight_selc.end_line {
		// 	highlight_rect : *HighlightRect = array_add(*text_op.console_tsl.highlight_rects);
		// 	highlight_rect.rect = TSLHighlightedRect(line_number, highlight_selc, text_op.console_tsl, char_width_world);
		// 	highlight_rect.color = it.highlight_color;
		// }
	}	
}
/*DOC : We want to reset all the op space tabs and cursor that have this file in them that was saved in them
But not the current one since we can only have 1 tab of that file per op_space right now
And we are saving that one here so we don't need to adjust that op space or cursor
*/
UpdateAllTextOpTabsWithTextFile :: inline (
	text_file : TextFile,
	all_data : *AllData,
	ted : TextEditorData,
	do_not_update_text_op_ids : [] int = .[])
{
	for * check_text : all_data.all_text_op_space_data {
		if !AllOrEquals(check_text.op_space_id, do_not_update_text_op_ids) {
			already_found_tab : bool = false;
			for * tab : check_text.file_tabs if tab.text_file_id == text_file.id {
				//sanity check to make sure we don't have the same file tab opened twice
				assert(!already_found_tab);
				already_found_tab = true;

				op_space, found_op_space := FindOpSpaceOpenOrClosed(check_text.op_space_id, 
					all_data.all_open_op_spaces, all_data.all_closed_op_spaces);
				assert(op_space.op_space_external_type == OpSpaceExternalType.txt);
				assert(found_op_space);

				// ResizeTextOpSpace(check_text, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square, ted);
				#if 1 {
				MoveCursorToLineAndLineChar(tab.tab_cursor.cursor_line_number, tab.tab_cursor.cursor_line_char,
					*tab.tab_cursor, text_file.file_string);
				} else {
				previous_line_number : int = tab.tab_cursor.cursor_line_number;
				//We reset the cursor in here in case we were highlighting or something like that
				MoveToLine(previous_line_number, text_file.file_string, *tab.tab_cursor);
				}

				//TODO We could pass in this message if need different messages for different reloads.
				SetTextStatus(tprint("Updated file %", text_file.file_short_name), check_text);
			}
		}
	}
}
UpdateAllTextOpTabsWithTextFile :: inline (
	text_file : TextFile,
	all_data : *AllData,
	ted : TextEditorData,
	do_not_update_text_op_id : int)
{
	do_not_update_array : [1] int;
	do_not_update_array[0] = do_not_update_text_op_id;
	UpdateAllTextOpTabsWithTextFile(text_file, all_data, ted, do_not_update_array);
}
//TODO Can rename this with UpdateAllData later if we need to update
//more than just the text op tabs.
SaveTextFileAndUpdateAllTextOpTabs :: inline (
	text_file : *TextFile,
	all_data : *AllData,
	ted : TextEditorData,
	do_not_update_text_op_ids : [] int = .[])
-> success : bool, msg : string
{
	success, msg := SaveTextFile(text_file);
	if success {
		UpdateAllTextOpTabsWithTextFile(text_file, all_data, ted, do_not_update_text_op_ids);
	}
	return success, msg;
}
SaveTextFileAndUpdateAllTextOpTabs :: inline (
	text_file : *TextFile,
	all_data : *AllData,
	ted : TextEditorData,
	do_not_update_text_op_id : int)
-> success : bool, msg : string
{
	do_not_update_array : [1] int;
	do_not_update_array[0] = do_not_update_text_op_id;
	success, msg := SaveTextFileAndUpdateAllTextOpTabs(text_file, all_data, ted, do_not_update_array);
	return success, msg;
}

WatchValue :: (mv : MemoryValue, t_info : *TypeInfo) -> string {
	if t_info == null return .{};
	//TODO Can set trailing_width to a fixed length if needed. -1 is default
	tw : int = -1;
	vs : string = "No type found";
	//TODO Do we want an option with both values? Or just let player add the ,i/,f or change value types.
	// if watch_split.count == 1 {
	// 	vs = tprint("i:%,f:%", mv.int_value, formatFloat(mv.float_value,trailing_width=tw));
	//TODO Other types should be dealt with externall like struct and array and string and mrow
	if t_info.type_enum == {
	case .VOID; #through;
	case .POINTER; #through;
	case .PROCEDURE; #through;
	case .INTEGER; vs = tprint("%", mv.int_value);
	case .BOOL; vs = tprint("%", cast(bool) mv.int_value); //TODO Does this actually set to true and false string?
	case .FLOAT; vs = tprint("%", formatFloat(mv.float_value,trailing_width=tw));
	case .ENUM; {
		t_info_enum := cast(*TypeInfoEnum) t_info;
		value_index, found_value := EnumIndexByValue(t_info_enum, mv.int_value);
		if found_value vs = tprint("% (%)", t_info_enum.names[value_index], mv.int_value);
		else vs = tprint("% (enum out of range)", mv.int_value);
	}
	}
	return vs;
}

/*DOC : If highlighted_call_stack_index == 0 then we chose the first one and we did not choose anything
If > 0 then we chose a different call frame so we set that one.
This is where we subtract the highlighted index from the count so the selected index points to the right
index in the array. Then we need to subtract it back for the ui.
We could store both if that helps but I think this seems ok right now.
*/
SelectHighlightedCallFrame :: inline (
	text_op : *TextOpSpaceData,
	all_data : *AllData) 
{
	text_op.exec_info.debug_info.selected_call_frame_index = 
		text_op.exec_info.debug_info.debug_call_stack.count-1-text_op.highlighted_call_stack_index;
	if text_op.highlighted_call_stack_index == 0 {
		text_op.exec_info.debug_info.chose_other_call_frame = false;
		text_op.exec_info.debug_info.debug_all_registers = all_data.all_register_memory;
	} else {
		text_op.exec_info.debug_info.chose_other_call_frame = true;
		text_op.exec_info.debug_info.debug_all_registers = 
			text_op.exec_info.debug_info.debug_call_stack[text_op.exec_info.debug_info.selected_call_frame_index].stored_frame_registers;
	}
	//TODO We could make this a function EvaluateAllWatchData since we reuse it here and after instr execution
	if text_op.watch_data_rows.count > 1 {
		//We don't want to process the last row since it is always empty.
		//We could also check if that watch_data.name.count == 0 if there are issues with this.
		//NOTE : this is also asserted in EvaluateWatchData for an extra resilience check.
		for 0..text_op.watch_data_rows.count-2 {
			EvaluateWatchData(it, text_op, all_data, reset_data=false);
		}
	}
}

TerminalOpSpaceData :: struct {
	op_space_id : int;

	//DOC : These need to be separate for each op space data
	//since they can be different sizes. Is it worth allowing
	//multiple terminals... I think so for music spaces BUT maybe not
	//and we just have a fixed. If so then we can move all this
	//to TerminalData if we only allow 1 terminal
	//TODO Should we put split line array in TextSplitLine?
	//Then we can reuse it easily for compiler console as well.
	// terminal_split_lines : [..] StringSplitByLine;
	terminal_tsl : TextSplitLine;
	//TODO FROM HERE test the terminal
	//and gradually move things in TextSplitLine
	//and then put it to the compiler console and test that a bit too
	//TODO We can likely put this in terminal_tsl as well
	//might have to put them all in terminal_tsl for reuse
	// terminal_line_char_count : int;

	//NOTE : We separate this out becuse this is for the total
	//which includes the text and the cmd input. The highlight
	//cursor is just for the text and not for the cmd input.
	//Not sure how that translates for something 
	//TODO I Think we can remove this once everything is in 
	//terminal_split_lines so then we can reuse it for compiler console.
	// terminal_start_line_index : int;
	// terminal_viewable_lines : int;

	op_rect : Rectangle2;
	terminal_line_height_factor : float = 1.35;

	// terminal_cursor_height : float;

	//TOOD Maybe we should put some of these in TextSplitLine
	//so we can reuse the TextSplitLine
	// TERMINAL_LINE_HEIGHT : float;
	TERMINAL_CURSOR_WIDTH : float;
	TERMINAL_X_GAP : float;
	// TERMINAL_TEXT_START_X : float;
	// TERMINAL_TEXT_START_Y : float;
	//TODO I think we can maybe remove this and just use line_char_count
	// TERMINAL_LINE_WORLD_WIDTH : float;
}
ResizeTerminalOpSpace :: inline (
	term_op : *TerminalOpSpaceData, 
	op_space_world_size : Vector2F,
	pixels_per_square : float,
	ted : TextEditorData,
	td : TerminalData)
{
	term_op.op_rect = OpSpaceRect(op_space_world_size);

	// term_op.terminal_tsl.viewable_lines_from_zero = TextViewableLinesFromZero(term_op.terminal_line_height_factor, op_space_world_size.y, 
	// 	ted.char_height, pixels_per_square);
	term_op.terminal_tsl.viewable_lines_from_zero = TextViewableLinesFromZero(term_op.terminal_line_height_factor, op_space_world_size.y, 
		ted.char_height, pixels_per_square);
	// term_op.terminal_end_line_index = term_op.terminal_tsl.start_file_line_index + term_op.VIEWABLE_LINES;

	// term_op.terminal_cursor_height = ComputeCursorHeight(ted.char_height, pixels_per_square);
	term_op.terminal_tsl.cursor_height = ComputeCursorHeight(ted.char_height, pixels_per_square);

	// term_op.TERMINAL_LINE_HEIGHT = ComputeTextLineHeight(term_op.terminal_line_height_factor,
	// 	ted.char_height, pixels_per_square);
	term_op.terminal_tsl.line_height = ComputeTextLineHeight(term_op.terminal_line_height_factor,
		ted.char_height, pixels_per_square);

	//TODO I am reusing this from text space cursor but maybe we can reuse unless we want them to be different sizes.
	term_op.TERMINAL_CURSOR_WIDTH = DefaultCursorWidth(ted.code_font_1_char_width_world);
	term_op.TERMINAL_X_GAP = DefaultXGap(term_op.TERMINAL_CURSOR_WIDTH, ted.code_font_1_char_width_world);
	// term_op.TERMINAL_TEXT_START_X = term_op.op_rect.min.x + term_op.TERMINAL_X_GAP;
	term_op.terminal_tsl.x_start_left = term_op.op_rect.min.x + term_op.TERMINAL_X_GAP;
	//TODO Could add a top margin height here like with text start y if needed
	// term_op.TERMINAL_TEXT_START_Y = term_op.op_rect.max.y - 0.5 * term_op.TERMINAL_LINE_HEIGHT;
	term_op.terminal_tsl.y_start_top = term_op.op_rect.max.y - 0.5 * term_op.terminal_tsl.line_height;
	//We subtract 1 char here so we prevent going over the left side by a bit partially hiding the char at the end of the line
	// term_op.TERMINAL_LINE_WORLD_WIDTH = op_space_world_size.x - ted.code_font_1_char_width_world;
	term_op.terminal_tsl.line_char_count = cast(int) (op_space_world_size.x / ted.code_font_1_char_width_world);
	term_op.terminal_tsl.line_char_count -= 1;

	//Need to redo the split lines on resize so that they fit the terminal properly
	//with the new line char count
	term_op.terminal_tsl.split_lines.count = 0;
	for line : td.all_terminal_lines {
		AddSplitStringByLines(line, *term_op.terminal_tsl);
	}
	AddBackCmdSplitLine(term_op, td);
}
#if 0 {
TerminalLineStartToOpPos :: inline (
	line_number : int, 
	term_op : TerminalOpSpaceData) 
-> Vector2F 
{
	line_diff : int = line_number - term_op.terminal_tsl.start_file_line_index;
	op_pos : Vector2F = MakeV2F(term_op.TERMINAL_TEXT_START_X, 
		term_op.TERMINAL_TEXT_START_Y - (term_op.TERMINAL_LINE_HEIGHT*line_diff));
	return op_pos;
}
}
//TODO Not sure this function is worth it for 1 LOC.
//It does keep things consistent but also keeping the code there
//directly makes it a lot clearly as to what is happening
LineStartToOpPos :: inline (
	line_number : int,
	tsl : TextSplitLine)
-> Vector2F 
{
	line_diff : int = line_number - tsl.cursor.start_file_line_index;
	op_pos : Vector2F = MakeV2F(tsl.x_start_left, 
		tsl.y_start_top - (tsl.line_height*line_diff));
	return op_pos;
}

TSLHighlightedRect :: inline (
	line_number : int,
	selc : StartEndLineChar,
	tsl : TextSplitLine,
	char_width_world : float,
	//Need this for console highlighting but not for cursor highlighting apparently
	//This just depend on if the selc.end_line_char is the last char or the after last char
	$add_1_char_count : bool = false) 
-> Rectangle2
{
	line_string : string = tsl.split_lines[line_number].split_string;
	start_char, end_char := LineSpecificStartEndChar(line_string, line_number, selc);
	char_count : int = end_char - start_char;
	#if add_1_char_count char_count += 1;
	highlight_empty_line : bool = HighlightEmptyLine(tsl, line_number, line_string.count);
	if highlight_empty_line char_count = 1;
	#if 0 {
	//TODO Leaving the other way now for consistency with the text editor but I think just this line might be fine
	//TODO I think this works since if we only highlight 1 char then start_char == end_char so char_count == 0
	//Noticed this when doing the compiler error highlighting. If we have any weird issues then can likely check this
	//but if start_char == end_char, then we should be highlighting 1 char
	if char_count == 0 char_count = 1;
	}

	min_op_pos : Vector2F = LineStartToOpPos(line_number, tsl);
	min_op_pos.x += start_char * char_width_world;
	TextToMinCursorPos(*min_op_pos, tsl.cursor_height);

	highlighted_rect : Rectangle2 = HighlightedLineRect(char_count, 
		tsl.cursor_height, min_op_pos, char_width_world);
	return highlighted_rect;
}
#if 0 {
TerminalCmdCharPointToOpPos :: inline (
	char_point : int,
	char_width_world : float,
	term_op : TerminalOpSpaceData,
	td : TerminalData)
-> Vector2F 
{
	// line_count : int = TerminalCmdLineCount(cmd_with_start_string_count, term_op.terminal_tsl.line_char_count);
	cmd_start_line : int = TerminalCmdStartLine(td, term_op);
	line_diff : int = TerminalCmdLineDiff(char_point, term_op.terminal_tsl.line_char_count);
	total_line_number : int = cmd_start_line + line_diff;
	op_pos : Vector2F = TerminalLineStartToOpPos(total_line_number, term_op);
	line_char : int = char_point - line_diff * term_op.terminal_tsl.line_char_count;
	op_pos.x += line_char * char_width_world;
	return op_pos;
}
} else {
TerminalCmdFirstLineSize :: inline (
	term_op : TerminalOpSpaceData,
	td : TerminalData) 
-> int
{
	first_line_size : int = 
		term_op.terminal_tsl.line_char_count - td.terminal_start_cmd_string.count;
	return first_line_size;
}
TerminalCmdCharPointToOpPos :: inline (
	char_point : int,
	char_width_world : float,
	term_op : TerminalOpSpaceData,
	td : TerminalData)
-> Vector2F 
{
	// line_count : int = TerminalCmdLineCount(cmd_with_start_string_count, term_op.terminal_tsl.line_char_count);
	line_diff : int = 0;
	line_char : int = 0;
	first_line_size : int = 
		term_op.terminal_tsl.line_char_count - td.terminal_start_cmd_string.count;
	if char_point < first_line_size {
		line_diff = 0;
		line_char = char_point + td.terminal_start_cmd_string.count;
	} else {
		char_point_without_first_line : int = char_point - first_line_size;
		line_diff = 1 + 
			(char_point_without_first_line/term_op.terminal_tsl.line_char_count);

		line_char = char_point_without_first_line - 
			(line_diff-1) * term_op.terminal_tsl.line_char_count;
	}
	cmd_start_line : int = TerminalCmdStartLine(td, term_op);
	total_line_number : int = cmd_start_line + line_diff;
	op_pos : Vector2F = LineStartToOpPos(total_line_number, term_op.terminal_tsl);
	op_pos.x += line_char * char_width_world;
	return op_pos;
}
}
TerminalCmdStartLine :: inline (
	td : TerminalData,
	term_op : TerminalOpSpaceData)
-> int 
{
	cmd_line_diff : int = TerminalCmdLineDiff(td.cmd_string_with_start.count, term_op.terminal_tsl.line_char_count);
	cmd_start_line : int = term_op.terminal_tsl.split_lines.count-1 - cmd_line_diff;
	if cmd_start_line < 0 cmd_start_line = 0;
	return cmd_start_line;
}
#if 0 {
TerminalLineCharToOpPos :: inline (
	line_number : int,
	line_char : int,
	char_width_world : float,
	term_op : TerminalOpSpaceData)
-> Vector2F 
{
	op_pos : Vector2F = TerminalLineStartToOpPos(line_number, term_op);
	op_pos.x += line_char * char_width_world;
	return op_pos;
}
}
TerminalCmdLineDiff :: inline (char_point : int, line_char_count : int) -> int {
	line_diff := cast(int) (char_point / line_char_count);
	return line_diff;
}
TerminalCmdLineCount :: inline (char_point : int, line_char_count : int) -> int {
	cmd_line_diff : int = TerminalCmdLineDiff(char_point, line_char_count);
	cmd_line_count : int = 1+cmd_line_diff;
	return cmd_line_count;
}
SetTerminalCmdLineDiffInBounds :: inline (
	//We don't use this anymore but leaving here just in case we decide to allow this or something
	//otherwise can jsut remove if never used
	// cursor_char_point : int,
	term_op : *TerminalOpSpaceData) 
{
	//TODO We could set this to where the cursor is on the bottom. This shows the whole command though
	// cmd_line_count : int = TerminalCmdLineCount(cursor_char_point, term_op.terminal_tsl.line_char_count);
	cmd_line_index : int = term_op.terminal_tsl.split_lines.count-1;
	if cmd_line_index < term_op.terminal_tsl.start_file_line_index ||
		cmd_line_index > term_op.terminal_tsl.start_file_line_index + term_op.terminal_tsl.viewable_lines_from_zero
	{
		//TODO SETTINGS we could have a setting that either put this to the middle or top or bottom
		end_index : int = cmd_line_index - term_op.terminal_tsl.viewable_lines_from_zero;
		term_op.terminal_tsl.start_file_line_index = max(0, end_index);
		// center_index : int = cmd_line_index - (term_op.terminal_tsl.viewable_lines_from_zero/2);
		// term_op.terminal_tsl.start_file_line_index = max(0, center_index);
		// start_index : int = cmd_line_index;
		// term_op.terminal_tsl.start_file_line_index = max(0, start_index);
	}
}
/*DOC : Because terminal_command_string.text_string points to the same place as cmd_string_with_start
after the start, then we just have to update the count. We do a sanity check here as well to make sure
that we don't go over the total amount of bytes. We could update this eventually though ALTHOUGH
now if we update the size in UpdateFileStringAtCursor automaticaly then it will update here as well automatically.

IMPORTANT this needs to be called whenever we update the cmd string
which we only do in 2 cases right now. When we update text and when we press
enter in the terminal.
*/
UpdateCmdStringWithStart :: inline (td : *TerminalData) {
	assert(td.terminal_command_string.text_string.count < 
		td.terminal_command_string.total_allocated_bytes + td.terminal_start_cmd_string.count);
	td.cmd_string_with_start.count = 
		td.terminal_start_cmd_string.count+td.terminal_command_string.text_string.count;
}
RemoveSplitCmdLines :: inline (all_term_ops : [] TerminalOpSpaceData, td : TerminalData) {
	for * term_op : all_term_ops {
		term_op.terminal_tsl.split_lines.count = TerminalCmdStartLine(td, term_op.*);
	}
}
/*DOC : Here we use that fact that cmd_string_with_start has not been updated yet
so we can remove the previous split cmd line even if we update the command string.
THEN we update the cmd_string_with_start to align it.
Then we would call AddBackCmdSplitLine to add back the the newly updated
cmd_string_with_start.
We do this in 2 places
1) when we update text so the terminal_split_lines are in sync with the
command string and we can highlight it properly with the mouse
2) before and after each set of terminal events so we can programtically
add terminal events and we get the same behavior as through typing in the terminal
*/
RemoveSplitCmdStringWithStartAndUpdate :: inline (
	all_term_ops : [] TerminalOpSpaceData,
	td : *TerminalData) 
{
	RemoveSplitCmdLines(all_term_ops, td.*);
	//NEED TO UPDATE cmd string with start since we updated the command string
	UpdateCmdStringWithStart(td);
}
AddBackCmdSplitLine :: (
	all_term_ops : [] TerminalOpSpaceData,
	td : TerminalData) 
{
	for * term_op : all_term_ops {
		AddBackCmdSplitLine(term_op, td);
	}
}
AddBackCmdSplitLine :: (
	term_op : *TerminalOpSpaceData,
	td : TerminalData) 
{
	AddSplitStringByLines(td.cmd_string_with_start, *term_op.terminal_tsl);
	SetTerminalCmdLineDiffInBounds(term_op);
}

// RemoveLastSplitLine :: inline (all_terminal_op_space_data : [] TerminalOpSpaceData) {
// 	for * all_terminal_op_space_data if itterminal_tsl.split_lines.count > 0 {
// 		last_line : StringSplitByLine = peek(itterminal_tsl.split_lines);
// 		while itterminal_tsl.split_lines.count > 0 && 
// 			peek(itterminal_tsl.split_lines).line_number == last_line.line_number 
// 		{
// 			itterminal_tsl.split_lines.count -= 1;
// 		}
// 	}
// }
/*DOC : Clear all terminal data like a clear terminal command,
without resetting the terminal cmd history. To reset the cmd history
as well, we use ResetTerminalData for things like tests.

*/
ClearTerminal :: inline (
	td : *TerminalData,
	all_term_ops : [] TerminalOpSpaceData) 
{
	for * term_op : all_term_ops {
		array_reset_keeping_memory(*term_op.terminal_tsl.split_lines);
		term_op.terminal_tsl.start_file_line_index = 0;
		ResetTextCursor(*term_op.terminal_tsl.cursor);
	}

	td.all_terminal_lines.count = 0;

	ClearTerminalCommandString(td, all_term_ops);
	td.terminal_file_string.text_string.count = 0;
	//We do this on command execution but I will add it here for resilience
	//since we can use ClearTerminal from anywhere
	CopyToCurrentCmdHistory("", td);	
}
//NOTE : We don't have to resize in here for tests because all_terminal_op_space_data gets cleared
//on every test so we just want to reset all the terminal data to keep things consistent for other
//tests other than terminal specific tests.
ResetTerminalData :: inline (
	td : *TerminalData,
	all_term_ops : [] TerminalOpSpaceData) 
{
	ClearTerminal(td, all_term_ops);
	ResetTerminalCmdHistory(td);
	//DOC : This sets the terminal start characters back and then also brings the text back into view
	AddBackCmdSplitLine(all_term_ops, td.*);
}
/*DOC : The end_line_char here is used as the actual char for the text console highlighting BUT
is used as the char+1 for cursor highlighting based on the mouse selection.
Maybe we could change 1 of them so it is consistent BUT this makes sense in a way
because mouse highlighting can go to the last char since the cursor can go to the last char when
we want to add a char at the end of a line but highlighting cannot since we cannot highlight
the non-existant char at the end.
*/
StartEndLineChar :: struct {
	start_line : int;
	start_line_char : int;
	end_line : int;
	end_line_char : int;
}
TextSplitLineOrderedStartEndLineChar :: inline (cursor : TextSplitLine) 
-> StartEndLineChar
{
	selc : StartEndLineChar;
	if cursor.fixed_select_line_number < cursor.cursor_line_number {
		selc.start_line = cursor.fixed_select_line_number;
		selc.start_line_char = cursor.fixed_select_line_char;
		selc.end_line = cursor.cursor_line_number;
		selc.end_line_char = cursor.cursor_line_char;
	} else {
		//Sanity check
		same_fixed_line_char : bool = cursor.cursor_line_char == cursor.fixed_select_line_char &&
			cursor.cursor_line_number == cursor.fixed_select_line_number;
		assert(!same_fixed_line_char, "highlighted cursor same pos not possible %", cursor);

		selc.start_line = cursor.cursor_line_number;
		selc.start_line_char = cursor.cursor_line_char;
		selc.end_line = cursor.fixed_select_line_number;
		selc.end_line_char = cursor.fixed_select_line_char;
	} 
	return selc;
}
LineSpecificStartEndChar :: inline (
	line_string : string,
	line_number : int,
	selc : StartEndLineChar)
-> start_line_char : int, end_line_char : int
{
	start_line_char : int;
	end_line_char : int;
	if selc.start_line == selc.end_line {
		start_line_char = selc.start_line_char;
		end_line_char = selc.end_line_char;
	} else if line_number == selc.start_line {
		start_line_char = selc.start_line_char;
		end_line_char = line_string.count;
	} else if line_number == selc.end_line {
		start_line_char = 0;
		end_line_char = selc.end_line_char;
	} else {
		start_line_char = 0;
		end_line_char = line_string.count;
	}
	return start_line_char, end_line_char;
}

ResizeType :: enum u8 {
	BOTTOM_RIGHT;
	// RIGHT;
	// LEFT;
	// TOP_RIGHT;
}
ResizeOpSpace :: struct {
	op_space_id : int;
	resize_type : ResizeType;
}
MovingOpSpace :: struct {
	op_space_id : int;
}
ResizeAnyOpSpace :: inline (
	//TODO We are not using the pointer here but just in case we need to eventually
	//I think it makes more sense as a resizing input
	op_space : *OperationSpace,
	perm : *Persist) 
{
	if op_space.op_space_external_type == {
	case OpSpaceExternalType.terminal; {
		term_op : *TerminalOpSpaceData = ArrayFindFirstByNameId(perm.all_data.all_terminal_op_space_data,
			op_space.id, "op_space_id");

		ResizeTerminalOpSpace(term_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square, 
			perm.text_editor_data, perm.terminal_data);
	}
	case OpSpaceExternalType.txt; {
		text_op, found_text_op := ArrayFindFirstByNameId(perm.all_data.all_text_op_space_data, 
			op_space.id, "op_space_id");
		assert(found_text_op);

		ResizeTextOpSpace(text_op, op_space.world_size, op_space.render_groups.scissor_group.pixels_per_square,
			perm.text_editor_data);
	}
	case OpSpaceExternalType.space_3d; {
		op_3D, found_op_3D := ArrayFindFirstByNameId(perm.all_data.all_op_spec_data_3D,
			op_space.id, "op_space_id");
		assert(found_op_3D);

		ResizeOpSpace3D(op_space.world_size, *op_3D.op_space_3D);
	}
	}
}
//TODO We can reuse this for a reset to pixels_per_square base 
ResizeAllOpSpaces :: inline (perm : *Persist) {
	for * perm.all_data.all_open_op_spaces {
		ResizeAnyOpSpace(it, perm);
	}
	for * perm.all_data.all_closed_op_spaces {
		ResizeAnyOpSpace(it, perm);	
	}
}
//TODO RUNTIME SETTINGS can allow this to be adjustable if needed
global_zoom_speed : float : 0.5;
global_zoom_pixel_min : float : 16.0;
global_zoom_pixel_max : float : 70.0;
//TODO SETTINGS can allow this to be adjusted in settings for 2d op spaces
op_zoom_speed : float : 0.04;
op_zoom_min_factor : float : 0.4;
op_zoom_max_factor : float : 2.2;
UpdatePixelsPerSquareEverywhere :: inline (
	new_pixels_per_square : float,
	renderer_data : *RendererData,
	perm : *Persist) 
{
	renderer_data.base_render_group.pixels_per_square = new_pixels_per_square;
	//TODO Can call UpdateFontSize here if we want to change the font size on global zooming
	//OR should we change that only at the text op space level eventually?
	SetupTextEditorData(*perm.text_editor_data, renderer_data);
	for renderer_data.all_render_groups {
		it.pixels_per_square = new_pixels_per_square;
		UpdateHalfMonitorSquares(it);
	}
	ResizeAllOpSpaces(perm);
}

//TODO could just pass in world_size and world_offset if that is more efficient
//This way seems clearer and simpler code-wise
OpSpaceTitleBarRect :: inline (op_space : OperationSpace, ted : TextEditorData) -> Rectangle2 {
	op_space_rect : Rectangle2 = RectCenterDim(op_space.world_offset, op_space.world_size);
	title_bar_min : Vector2F = MakeV2F(op_space_rect.min.x, op_space_rect.max.y);
	// op_ui_size : Vector2F = MakeV2F(OP_SPACE_MIN_SIZE.x, 1.6);
	// op_ui_size : Vector2F = MakeV2F(OP_SPACE_MIN_SIZE.x, 1.4);
	//46.2 = 1.4 * 33 which should be the default pixels per square actually
	// height : float = 46.2 / op_space.render_groups.scissor_group.pixels_per_square;
	// title_bar_size : Vector2F = MakeV2F(op_space.world_size.x, 1.4);
	height : float = 2.1 * ted.code_font_1_char_width_world;
	title_bar_size : Vector2F = MakeV2F(op_space.world_size.x, height);
	title_bar_rect : Rectangle2 = RectMinDim(title_bar_min, title_bar_size);
	return title_bar_rect;
}
//TODO I think we can put this on TextOpRects now probably so we don't have to recompute it every frame
TitleBarData :: struct {
	title_bar_cam_rect : Rectangle2;
	fix_op_space_cam_rect : Rectangle2;
	fix_to_mspace_cam_rect : Rectangle2;
	close_op_space_cam_rect : Rectangle2;
	name_cam_pos : Vector2F;
}
//TODO Eventually we could store these rects in op_space and only
//recompute them when we move or resize the op_space if that seems worth it.
//This way we don't have to recompute it since we always calculate it from the op_rect.
ComputeTitleBar :: inline (
	op_space : OperationSpace,
	default_base_cam : Camera2D,
	ted : TextEditorData)
-> TitleBarData 
{
	tb_data : TitleBarData;

	num_of_sub_rects : float = 20;
 	title_bar_world_rect : Rectangle2 = OpSpaceTitleBarRect(op_space, ted);
	tb_data.title_bar_cam_rect = WorldRectToCamRect(title_bar_world_rect, default_base_cam);

	subrect_dim : Vector2F;
	subrect_dim.x = 2.2 * ted.code_font_1_char_width_world;
	subrect_dim.y = 0.55 * GetHeight(tb_data.title_bar_cam_rect); 

	// tb_data.close_op_space_cam_rect = GetSubRect(tb_data.title_bar_cam_rect, num_of_sub_rects, num_of_sub_rects-1, 0.35);
	// close_cam_pos : Vector2F = GetCenter(tb_data.close_op_space_cam_rect);
	close_op_pos : Vector2F = tb_data.title_bar_cam_rect.max;
	close_op_pos.y -= 0.5 * GetHeight(tb_data.title_bar_cam_rect);
	close_op_pos.x -= 1.5 * ted.code_font_1_char_width_world;
	tb_data.close_op_space_cam_rect = RectCenterDim(close_op_pos, subrect_dim);

 	// tb_data.fix_to_mspace_cam_rect = GetSubRect(tb_data.title_bar_cam_rect, num_of_sub_rects, num_of_sub_rects-2, 0.35);
	fix_mspace_pos : Vector2F = close_op_pos;
	fix_mspace_pos.x -= 1.1 * subrect_dim.x;
	tb_data.fix_to_mspace_cam_rect = RectCenterDim(fix_mspace_pos, subrect_dim);

 	tb_data.fix_op_space_cam_rect = GetSubRect(tb_data.title_bar_cam_rect, num_of_sub_rects, num_of_sub_rects-3, 0.35);

	tb_data.name_cam_pos = tb_data.title_bar_cam_rect.min;
	tb_data.name_cam_pos.y += 0.6 * GetHeight(tb_data.title_bar_cam_rect);

 	return tb_data;
}

//TODO We now just have it defaulted to fixed to camera and we can eventually set default fixed to mspace when open
//if needed but maybe having it be consistent is better in general
// SetDefaultOpSpaceFixedTypeState :: inline (
// 	op_space : *OperationSpace,
// 	//TODO Can use these runtime settings to change the default eventually
// 	runtime_settings : RuntimeSettingsData) 
// {
// 	op_space.is_fixed_to_camera = true;
// 	op_space.is_fixed_to_mspace = false;
// }
/*TODO Eventually we want to grab render groups from renderer data
as a group so that we can reuse them when we close the op space
and have clean and concise renderer data.
So we would group the render groups per op space in a struct
and then grab from a free list if we have, otherwise create new ones
with this code.

TODO Right now we create this 1 time here to avoid having to create this in the tests so that
we don't mess with the test allocator and the renderer data. RendererData needs its own allocator
to be used for all its data including arrays.
Eventually we should reuse render groups when closing an op space so then we can grab that here
every time. I think doing that with a struct would be find and then if we have some free render groups
we reuse those, otherwise we create some new ones, but the renderer data should have its own allocator
since the number of render groups should not be limited.

REMINDER DO NOT SET THESE IN TESTS because right now the allocator would
overlap between the test alloc and this one. I think when we add a separate
allocator for the renderer then it will not be a problem and we can test
out doing it then BUT since render groups are modular and reused for op spaces
that does not matter in any case and this should be safe anyways.
*/
SetOpSpaceRenderGroups :: inline (
	op_space : *OperationSpace,
	renderer_data : *RendererData) 
{
	//TODO Need to grab leftover render groups if we updated them
	//but then we have to reorder them using the code in reorder
	//but maybe it's best if we just store the render groups
	//as groups for op_spaces then anyways so its easier to order
	osrg : OpSpaceRenderGroups;
	if renderer_data.free_op_space_render_groups.count > 0 {
		osrg = pop(*renderer_data.free_op_space_render_groups);
	} else {
		op_space_viewport : Rectangle2 = MakeRectToPixelSpace(op_space.world_offset, op_space.world_size,
			renderer_data.base_render_group.screen_half_dim, renderer_data.base_render_group.pixels_per_square);

		//TODO Only need to create this if the OperationSpace is 3D but right now that is in separate data.
		//Eventually if we store OperationSpace and separate out RenderGroup and reuse those, then we can
		//only grab an extra RenderGroup if we need it when we have 3D op spaces.
		osrg.pre_scissor_group = CreateRenderGroup(Kilobytes(100), op_space_viewport, renderer_data, false);
		array_add(*renderer_data.all_render_groups, osrg.pre_scissor_group);
		osrg.scissor_group_3D = CreateRenderGroup(Megabyte(2), op_space_viewport, renderer_data, true);
		array_add(*renderer_data.all_render_groups, osrg.scissor_group_3D);

		osrg.scissor_group = CreateRenderGroup(Megabyte(1), op_space_viewport, renderer_data, false);
		array_add(*renderer_data.all_render_groups, osrg.scissor_group);

		osrg.post_render_group = CreateRenderGroup(Kilobytes(500), renderer_data.base_render_group.render_viewport, renderer_data, false);
		array_add(*renderer_data.all_render_groups, osrg.post_render_group);
	}
	osrg.op_space_id = op_space.id;
	array_add(*renderer_data.open_op_space_render_groups, osrg);
	op_space.render_groups = osrg;
	PushShaderEntries(op_space.render_groups.scissor_group, 0, 100000, 9999999);
	// PushSetShaderColor(op_space.render_groups.scissor_group, 100000);
}

//TODO implement close op space
//TODO could implement this by id as well for convenience if needed
//Just need to pull out the bottom code and search by id
OpenOpSpace :: inline (
	op_space_name : string,
	// op_space_id : int,
	renderer_data : *RendererData,
	all_data : *AllData) 
-> OperationSpace, open_op_space_success : bool, msg : string
{
	render_mspace, found_mspace := ArrayFindFirstByNameId(all_data.all_mspace_data,
		all_data.render_mspace_id, "mspace_id");
	assert(found_mspace);

	//If op_space already open then we move it to where we are and return it
	for * op_space : all_data.all_open_op_spaces if op_space.op_space_name == op_space_name {
		ChooseOpSpace(op_space.*, all_data, renderer_data);
		//TODO I think it's better to just choose the op_space on opening
		//this way if it's fixed to camera then it just gets selected
		//like in the case of the terminal or another op_space it wont move undesirably
		// SetDefaultOpSpaceFixedTypeState(op_space, all_data.runtime_settings);
		// op_space.world_offset = render_mspace.mspace_cam.world_pos;
		return op_space, true, tprint("% already open\n", op_space_name);
	}

	closed_op_space : OperationSpace;
	found_closed_op_space : bool = false;
	for all_data.all_closed_op_spaces if op_space_name == it.op_space_name {
		closed_op_space = it;
		found_closed_op_space = true;
		remove it;
		break;
	}
	if !found_closed_op_space {
		return .{}, false, tprint("% not found\n", op_space_name);
	}

	//TODO Check that the entire struct or array is null eventually
	//instead of just 1 group depending on what we use
	if closed_op_space.render_groups.pre_scissor_group == null {
		SetOpSpaceRenderGroups(*closed_op_space, renderer_data);
	}
	// SetDefaultOpSpaceFixedTypeState(*closed_op_space, all_data.runtime_settings);
	closed_op_space.world_offset = render_mspace.mspace_cam.world_pos;

	array_add(*all_data.all_open_op_spaces, closed_op_space);
	open_op_space : *OperationSpace = peek_pointer(all_data.all_open_op_spaces);
	ChooseOpSpace(open_op_space, all_data, renderer_data);
	//TODO We can remove this now that we don't use chord_s3 anymore like this
	#if 0 {
	if open_op_space.op_space_external_type == OpSpaceExternalType.chord_s3 {
		chord_s3, found_chord_s3 := ArrayFindFirstByNameId(all_data.all_chord_spaces_3, 
			open_op_space.id, "op_space_id");
		assert(found_chord_s3);

		chosen_chord_s3 : ChosenEntity;
		chosen_chord_s3.id = chord_s3.dspace_id;
		chosen_chord_s3.entity_type = EntityType.CHORD_S3;
		array_add(*all_data.all_chosen_entities, chosen_chord_s3);
	}
	}

	return open_op_space, true, tprint("% open\n", op_space_name);
}

//TODO Need to test this when we test autosave
AutoSaveChosenTextOpTab :: inline (all_data : *AllData) {
	if all_data.runtime_settings.save_file_on_focus_lost {
		for all_data.all_chosen_entities if it.entity_type == EntityType.OP_SPACE {
			previous_op_space, found_previous_op_space := FindOpSpaceOpenOrClosed(it.id, 
				all_data.all_open_op_spaces, all_data.all_closed_op_spaces);
			if found_previous_op_space && previous_op_space.op_space_external_type == OpSpaceExternalType.txt {
				text_op, found_text_op := ArrayFindFirstByNameId(all_data.all_text_op_space_data, 
					previous_op_space.id, "op_space_id");
				assert(found_text_op);

				text_file : *TextFile = GetTabTextFile(text_op.ftab_i, text_op, all_data.all_text_files);
				success, msg := SaveTextFile(text_file);
				SetTextStatus(msg, text_op);
				return;
			}
		}	
	}
}

//TODO This should bring the chosen op_space up to the front
//TODO SETTING auto-save if we WERE choosing a text_op space before this one, then we can save the unsaved text files here
/*DOC : When we choose an op space, we bring it to the top and 
if its a text op space we also set the cursor to current line and char, so that if we edited the text file
then the cursor will still be valid. We do the same thing when switching tabs.
*/
ChooseOpSpace :: inline (
	op_space : OperationSpace,
	all_data : *AllData,
	renderer_data : *RendererData,
	set_op_camera : bool = true)
{
	AutoSaveChosenTextOpTab(all_data);

	//TODO could remove only the given op_space if we can select multiple op_spaces at some point
	// ArrayRemoveAllByArrayNameId(*all_data.all_chosen_entities, 
	// 	EntityType.[.OP_SPACE, .TERMINAL], "entity_type", AllOrEquals);
	array_reset_keeping_memory(*all_data.all_chosen_entities);

	chosen_op_space : ChosenEntity;
	chosen_op_space.id = op_space.id;
	chosen_op_space.entity_type = EntityType.OP_SPACE;
	array_add(*all_data.all_chosen_entities, chosen_op_space);

	// if set_op_camera { 
	// 	all_data.active_cam_id = op_space.cam_2D_id;
	// }

	BringOpSpaceToTop(op_space, renderer_data);

	if op_space.op_space_external_type == OpSpaceExternalType.txt {
		//When we choose this op_space we want to make sure the cursor is as close to where it was before
		//so this way if only the line string changed, then we keep it there and if the line was removed
		//then we keep it at the same line which doesn't change the line bounds.
		//This seems like a good balance and if we don't edit then we don't change
		//and if we did edit but did not move the cursor, then it will stay in the same place
		//TODO FROM HERE test each above case for moving between files in text op space.
		//TODO Maybe I can move this doc to the move cursor line and char function...?
		/*DOC We don't update the bounds because if we removed a bunch of text and did not save then click with the mouse
		we will first move to the bounds of the cursor and then when we click with the mouse, we will be in the wrong position.
		This way if we click with the mouse then we go to where we are seeing but if we don't go with the mouse, then
		if the cursor is out of the bounds we can just move with an arrow key to adjust to it.
		For example if we remove text before where we are, the whole text string will shift up BUT
		since the line bounds stay the same, we will still get the proper mouse click even if
		we hit the bottom or top because we wil only render from where we are at SO therefore we might just have blank
		space on the bottom and then itll just adjust to the top when we click that text op space.
		ALSO I noticed this is how sublime text does it I am guessing for the same reason to avoid mouse input issues
		so we always need to keep the bounds the same when updating other tab cursor to avoid mouse issues when we press the space.
		*/
		text_op, found_text_op := ArrayFindFirstByNameId(all_data.all_text_op_space_data, 
			op_space.id, "op_space_id");
		assert(found_text_op);

	 	text_file := GetTabTextFile(text_op.ftab_i, text_op, all_data.all_text_files);
		//If we already saved the file, then we updated the cursor in UpdateAllTextOpTabsWithTextFile
		//TODO We could just do this even if it's not saved for good measure.
	 	//I AM doing it everytime because if we edited and then saved, this would not run.
 		//Can remove the if if it all works out and tested.
 		//We do the same when changing tab so that should be enough to keep the cursor updated whenever we go to this tab.
		/// if text_file.file_string.not_saved_text_edit {
		tab : *TextTab = *text_op.file_tabs[text_op.ftab_i];
		MoveCursorToLineAndLineChar(tab.tab_cursor.cursor_line_number, tab.tab_cursor.cursor_line_char,
			*tab.tab_cursor, text_file.file_string, reset_cursor=false, update_bounds=false);
		// }
	}

	/*TODO for now we set DSPACE_SELECTION_STATE as the default when
		choosing an op_space but we can change later if something else
		feels more natural

		TODO maybe we want this to be changeable depending on the level
		since some levels we will want the user to just input and some
		we will want the user ot choose

		***so maybe the initial InputStateType should be per op_space***
	*/
	// all_data.all_input_states[0].input_state_type = InputStateType.DSPACE_SELECTION_STATE;
}
//TODO Eventually do a DeleteOpSpace
//TODO SETTING if text op_space, then we can auto_save file on close BUT we will do that in ResetToUnselectedState
CloseOpSpace :: inline (
	op_space_name : string,
	all_data : *AllData,
	renderer_data : *RendererData)
-> success : bool
{
	op_space : OperationSpace;
	found_open_op_space : bool = false;
	for all_data.all_open_op_spaces if op_space_name == it.op_space_name {
		op_space = it;
		found_open_op_space = true;
		remove it;
		break;
	}
	if !found_open_op_space return false;

	//TODO We can actually just remove the render groups since we have
	//pointers to them here but maybe we will just to op space render groups
	//and then we don't need to do the extra step and we can just move the
	//op_space render groups around since people can just draw whatever they want
	//to the op spaces systematically and don't have to worry about the render groups.
	FreeOpSpaceRenderGroups(op_space, renderer_data);
	op_space.render_groups.pre_scissor_group = null;
	op_space.render_groups.scissor_group_3D = null;
	op_space.render_groups.scissor_group = null;
	op_space.render_groups.post_render_group = null;

	array_add(*all_data.all_closed_op_spaces, op_space);

	//TODO What should we do with cam? Only remove it on delete or maybe if we store it in the op_space
	//and grab it by pointer on selection and set the active cam to a camera pointer in all data instead.
	//The problem there is that then we might have some things applied to different cameras on the same frame...
	for all_data.all_chosen_entities if it.entity_type == EntityType.OP_SPACE && it.id == op_space.id {
		ResetToUnselectedState(all_data);
		break;
	}

	return true;
}
FreeOpSpaceRenderGroups :: inline (op_space : OperationSpace, renderer_data : *RendererData) {
	found_osrg, osrg_index := FindOpSpaceRenderGroupsByIndex(op_space, renderer_data.open_op_space_render_groups);
	assert(found_osrg);
	osrg : OpSpaceRenderGroups = renderer_data.open_op_space_render_groups[osrg_index];
	array_add(*renderer_data.free_op_space_render_groups, osrg);
	//TODO Can do this with a memcpy and just move all render groups to the left and reduce count by 1.
	array_ordered_remove_by_index(*renderer_data.open_op_space_render_groups, osrg_index);
}
BringOpSpaceToTop :: inline (op_space : OperationSpace, renderer_data : *RendererData) {
	found_osrg, osrg_index := FindOpSpaceRenderGroupsByIndex(op_space, renderer_data.open_op_space_render_groups);
	assert(found_osrg);
	osrg : OpSpaceRenderGroups = renderer_data.open_op_space_render_groups[osrg_index];
	//TODO Can do this with a memcpy and just move all render groups to the left and reduce count by 1.
	array_ordered_remove_by_index(*renderer_data.open_op_space_render_groups, osrg_index);
	array_add(*renderer_data.open_op_space_render_groups, osrg);
}
FindOpSpaceRenderGroupsByIndex :: inline (
	op_space : OperationSpace,
	active_osrg : [] OpSpaceRenderGroups) 
-> found : bool, index : int
{
	for active_osrg if it.op_space_id == op_space.id {
		return true, it_index;
	}
	return false, -1;
}
