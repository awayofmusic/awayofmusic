#import "Sort";

GameState :: struct {
    memory : MemoryData;
    is_initialized : bool;
    persist : Persist;
}

//TODO move this out once we place rendere_data in the right place
//TODO make a transient storage allocator
TransientState :: struct {
	memory : MemoryData;
	is_initialized : bool;
}

ResetTransientMemory :: inline (trans : *TransientState) {
}

Kilobytes :: (bytes : s64) -> s64 #expand {
    return 1024 * bytes;
}

Megabytes :: (bytes : s64) -> s64 #expand {
    return 1024 * Kilobytes(bytes);
}

Gigabytes :: (bytes : s64) -> s64 #expand {
    return 1024 * Megabytes(bytes);
}

TransformToCameraSpace :: inline (v : Vector2F, transform : Matrix2F, 
							      cam : Camera2D, rotate_about : Vector2F = Vector2F.{}) 
								  -> Vector2F 
{
	trans_pos : Vector2F = TransformAboutPoint(v, transform, rotate_about);
	cam_pos : Vector2F = WorldSpaceToCameraSpace(trans_pos, cam);
	return cam_pos;
}

ViewportOffset :: inline (v : Vector2F, render_group : RenderGroup) -> Vector2F {
	//TODO Try changing this to pixels_per_square * screen_half_dim to see if that works for zoom
	viewport : Vector2F = v + render_group.half_monitor_squares;
	// viewport : Vector2F = v + render_group.screen_half_dim * render_group.pixels_per_square;
	return viewport;			
}

WorldSpaceToViewportSpace :: inline (world_pos : Vector2F, cam : Camera2D, render_group : RenderGroup) -> Vector2F {
	cam_pos := WorldSpaceToCameraSpace(world_pos, cam);
	viewport := ViewportOffset(cam_pos, render_group);
	return viewport;
}

PixelSpaceToWorldSpace :: inline (pixel_pos : s64, pixels_per_square : float) -> float {
	world_pos : float = pixel_pos / pixels_per_square;
	return world_pos;
}

DSpaceToCameraSpace :: inline (grid_pos : Vector2F, cam : $cam_type, space : DimensionalSpace) -> Vector2F {
	cam_pos := DSpaceToWorldSpace(grid_pos, space);
	cam_pos = WorldSpaceToCameraSpace(cam_pos, cam);
	return cam_pos;
}

//TODO generalize to 2D object space with rotations and maybe 3D homogeneous coordinates
DSpaceToWorldSpace :: inline (rel_pos : $vec_type, space : DimensionalSpace) -> vec_type {
	world_pos : vec_type = rel_pos + space.dspace_world_pos;
	return world_pos;
}

WorldSpaceToDimSpace :: inline (world_pos : $vec_type, dspace_world_pos : vec_type) -> vec_type {
	dspace_pos : vec_type = world_pos - dspace_world_pos;
	return dspace_pos;
}

//TODO could shorten this to one operation combining both conversion
DimSpaceToCameraSpace :: inline (dspace_pos : $vec_type, space : DimensionalSpace, cam : $cam_type) -> vec_type {
	world_pos : vec_type = GridSpaceToWorldSpace(dspace_pos, space);
	cam_pos : vec_type = WorldSpaceToCameraSpace(world_pos, cam);
	return cam_pos;
}


//TODO write inverse of this function
//and write unit_tests for both
//REMINDER : Used to be s32 from old windows system layer for reference
// MouseScreenToCam :: inline (mouse_x : s32, mouse_y : s32, render_group : RenderGroup) -> Vector2F {
//TODO Can just pass in screen_half_dim and pixels pre square so we make it game independt and compute this in platform later
MouseScreenToCam :: inline (mouse_x : int, mouse_y : int, render_group : RenderGroup) -> Vector2F {
	delta_x : float = (mouse_x / cast(float) (render_group.window_width-1.0));
	delta_y : float = (mouse_y / cast(float) (render_group.window_height-1.0));
	#if 0 {
	mouse_cam_x : float = 2.0 * render_group.half_monitor_squares.x * delta_x - render_group.half_monitor_squares.x;
	mouse_cam_y : float = 2.0 * render_group.half_monitor_squares.y * delta_y - render_group.half_monitor_squares.y;
	} else {
	//TODO Need to either update half_monitor_squares when we update pixels_per_square OR just use this way everywhere
	//Would this be clearer on 1 line?
	mouse_cam_x : float = 2.0 * (render_group.screen_half_dim.x / render_group.pixels_per_square) * delta_x - 
		render_group.screen_half_dim.x / render_group.pixels_per_square;
	mouse_cam_y : float = 2.0 * (render_group.screen_half_dim.y / render_group.pixels_per_square) * delta_y - 
		render_group.screen_half_dim.y / render_group.pixels_per_square;
	}

	mouse_cam : Vector2F = MakeV2F(mouse_cam_x, mouse_cam_y);
	return mouse_cam;
}

#if 0 {
GetDefaultBaseCam2D :: inline (all_2D_cams : [] Camera2D) 
-> Camera2D 
{
	assert(all_2D_cams.count > 0);
	default_base_cam : Camera2D = all_2D_cams[0];
	return default_base_cam;
}
}

/*TODO WE could have these inputs be passed in from 
input mappings and just take the key code without the modifiers
if people want movement to be something like arrow keys I think
that makes sense. This as default makes sense since its 2d plane movement
similar to 3d movement with wasd.

TODO Can also pass in a speed here to change that although that 
might make things choppy unless its a multiple i think with the
smooth diagonal movement I added below.
*/
DefaultInputMove2D :: inline (
	game_input : GameInput,
	pixels_per_square : float) 
-> Vector2F, moved_this_frame : bool
{
	//TODO Replace this with new input functions
	keyboard := game_input.Controllers[0];
	move_vec := Vector2F.{0,0};
	moved_this_frame : bool = false;
	// if keyboard.Right.EndedDown {
	if IsInputDown(xx #char "D", game_input) {
		move_vec += MakeV2F(1.0, 0);
		moved_this_frame = true;
	}
	// if keyboard.Left.EndedDown {
	if IsInputDown(xx #char "A", game_input) {
		move_vec += MakeV2F(-1.0, 0);
		moved_this_frame = true;
	}
	// if keyboard.Up.EndedDown {
	if IsInputDown(xx #char "W", game_input) {
		move_vec += MakeV2F(0, 1.0);
		moved_this_frame = true;
	}
	// if keyboard.Down.EndedDown {
	if IsInputDown(xx #char "S", game_input) {
		move_vec += MakeV2F(0, -1.0);
		moved_this_frame = true;
	}

 	if move_vec.x != 0 && move_vec.y != 0 {
    	move_vec *= 2.0*(1.0 / pixels_per_square);
    	// move_vec *= 1.0*(1.0 / pixels_per_square);
 	} else {
    	move_vec *= 2.0*(1.5 / pixels_per_square);
    	// move_vec *= 1.0*(1.5 / pixels_per_square);
	}	
	return move_vec, moved_this_frame;
}

Camera3D :: struct {
	world_pos : Vector3F;
	rotation : Matrix3F;
	//TODO how should we store our cubes dimensions?
	// cam_dim : Rectangle2;
}

MakeRectToPixelSpace :: inline (
	rect_pos : Vector2F,
	rect_size : Vector2F,
	window_center_pixel : Vector2F,
	pixels_per_square : float)
-> Rectangle2
{
	pixel_rect : Rectangle2 = RectCenterDim(rect_pos, rect_size);
	pixel_rect_min : Vector2F = GetMinCorner(pixel_rect);
	pixel_rect_max : Vector2F = GetMaxCorner(pixel_rect);

	pixel_rect.min = CamSpaceToPixelSpace(pixel_rect_min, window_center_pixel, pixels_per_square);
	pixel_rect.max = CamSpaceToPixelSpace(pixel_rect_max, window_center_pixel, pixels_per_square);

	return pixel_rect;
}

CamRectToPixelRect :: inline (
	cam_rect : Rectangle2,
	window_center_pixel : Vector2F,
	pixels_per_square : float)
-> Rectangle2 
{
	pixel_rect := cam_rect;
	pixel_rect.min = CamSpaceToPixelSpace(pixel_rect.min, window_center_pixel, pixels_per_square);
	pixel_rect.max = CamSpaceToPixelSpace(pixel_rect.max, window_center_pixel, pixels_per_square);
	return pixel_rect;
}

CamSpaceToPixelSpace :: inline (
	cam_pos : Vector2F,
	screen_half_dim : Vector2F,
	pixels_per_square : float) 
-> Vector2F
{
	pixel_pos : Vector2F = screen_half_dim + cam_pos * pixels_per_square;
	return pixel_pos;
}
CamRectToPixelRect :: inline (rect : Rectangle2, g : *RenderGroup) -> Rectangle2 {
	rp : Rectangle2 = ---;
	rp.min = g.screen_half_dim + rect.min * g.pixels_per_square;
	rp.max = g.screen_half_dim + rect.max * g.pixels_per_square;
	return rp;
}

WorldSpaceToPixelSpace :: inline (
	world_pos : Vector2F,
	cam : Camera2D,
	screen_half_dim : Vector2F,
	pixels_per_square : float) 
-> Vector2F 
{
	cam_pos : Vector2F = WorldSpaceToCameraSpace(world_pos, cam);
	pixel_pos : Vector2F = CamSpaceToPixelSpace(cam_pos, screen_half_dim, pixels_per_square);
	return pixel_pos;
}

GetPermanentStorage :: inline (game_memory : *GameMemory) -> *Persist {
    game_state := cast(*GameState) game_memory.PermanentStorage;
    perm := *game_state.persist;
    return perm;
}

TextCommandType :: enum {
	NONE;
	LEVEL_LOAD;
	LEVEL_UPDATE;
	RUN_TEST;
}

GameMode :: enum {
	PLAY;
	TEST;
	DEBUG;
}

//TODO These need to be separated out so we have data that can be used externally and data that
//cannot be used externally
TestLevelType :: #type (
	test_name : string,
	//TODO What if just pass TIPData in here instead
	game_memory : *GameMemory, 
	renderer_data : *RendererData, 
   audio_data : *AudioData,
   game_input : *GameInput);

file_type_enum_names : [] string : #run enum_names(FileTypeEnum);
file_type_enum_enums : [] FileTypeEnum : #run enum_values_as_enum(FileTypeEnum);
FileTypeEnum :: enum {
	txt;
	dll;
	dylib;
}

//TODO I think we should pass in runtime_settings into here for default values and setting anything else at startup
InitAllData :: () -> *AllData {
	//TODO I think we don't have to pass in context.allocator since that is done by default...
	all_data : *AllData = New(AllData,, context.allocator);
	#insert #run SetResizableArrays(AllData, "all_data.%.allocator = context.allocator;\n");

	//TODO Should remove ALL_NEXT_IDS and pass it in everywhere
	//We reset all_next_ids in the New call above and then set them since we reinit the data here.
	ALL_NEXT_IDS = all_data.all_next_ids;
	context.ALL_NEXT_IDS = *ALL_NEXT_IDS;

	//TODO Pass in runtime_settings here if we pass it into InitAllData eventually
	GetOrCreateMusicSpace(.{}, all_data.runtime_settings, *all_data.all_mspace_data, *all_data.free_mspace_data_pool);
	GetOrCreateSimpleSynth(.{}, *all_data.all_simple_synths, *all_data.free_simple_synth_pool);

   // all_data.global_rules.memory_unit_width = 2.0;
   all_data.global_rules.memory_unit_width = 1.75;

   //TODO Could increase this by default or just let people who use it increase it how they want.
	// init(*all_data.extern_pool, Megabytes(1));
	// all_data.extern_alloc.proc = flat_pool_allocator_proc;
	// all_data.extern_alloc.data = *all_data.extern_pool;


	//TODO Can adjust this later if we need more. Could just allow the 256 default
	//And we could reuse the pool/alloc for all compilations since we can make compilations sequential.
	//TODO FROM HERE This could be MySimplePool now, although in-game we always want default anyways...
	//This is a leak during tests but with SimpleAlloc it would not be
	init(*all_data.comp_pool, Megabytes(10));
	//TODO What if we just used the allocator and set the pool externally?
	//Then during tests we would set it to MySimplePool and during runtime we would use Flat_Pool
	//but we would still need to store the pool somewhere so maybe MySimplePool is best
	//since it defaults to default allocator when the context.allocator is not changed.
	//We could set the pool in TestData though and then have a slighlty different all_data for test
	//but then it is not exactly the same which is best to really test what is happening.
	all_data.comp_alloc.proc = flat_pool_allocator_proc;
	all_data.comp_alloc.data = *all_data.comp_pool;

   // set_allocators(*all_data.mspace_pool);
	// all_data.mspace_alloc = .{pool_allocator_proc, *all_data.mspace_pool};


	/*DOC : Default music setup can be done here after setting everything up.
	We create the default tuning systems on top, so maybe we can move that down here now.
	*/
	SetupMusic(all_data);

	for reg_def_enums array_add(*all_data.all_register_memory, MemoryValue.{});

	CreateDefaultTuningSystems(*all_data.all_tuning_systems, *all_data.all_tuning_pitches);
	//TODO Need to remove this and just use tuning system from the tano
	all_data.global_rules.tuning_system_id = all_data.all_tuning_systems[0].id;
	all_data.global_rules.tuning_system = all_data.all_tuning_systems[0];
	

	/*I think the Flat_Pool is more robust 
      - Flat_Pool allows contiguous memory on get() in virtual os memory without
	  changing the memory_base. A [..] resize would move the memory_base change.
	  - Flat_Pool makes a call to VirtualAlloc instead of using the default allocator. (This is not a positive point
	  since we want to control which allocator that allocates our memory.)
	  - [..] u8 is obviously an underlying byte array, Flat_Pool can yield a similar result with an extra byte array.

	  TODO Lets implement strings and then see if the underlying byte memory is somehow advantageous or not.
	*/
	#if 1 {
	//This options allows just using all_byte_memory here and then we have just 2 arrays instead of Flat_Pool.
	//It also allocates memory in the context.allocator which is preferable in general so we can use it
	//with test_alloc or other allocs. I am not sure of the benefit of pool other than resizing from the same address
	//but we can still resize here, it will just change address in memory which should not effect us since we
	//access ram using integer memory indices anyways.
	//TODO If we keep using this method then we can just store the [..] u8 in RAMMemory, unless we want that
	//to just have a *char and a count... iunno, lets see i guess. Keeping it in RAMMemory makes it more clear
	//that the memory is THERE. Then when we have multiple rams, we know exactly where it is and where each one
	//is being allocated.
	//TODO Should likely have an allocator for this so we can reset on compilation
	//Maybe we don't need though... depends how we allow resetting of ram and also using multiple rams.
	//This should likely be set by the compiler to knwo what to grab. IF we have values at the beginning
	//they should not be included in this. So if we let the user set this (stack and heap size-heap can maybe change
	//with another setting), then we would want to set this in compiler and then just grab ram at runtime
	//so then we could have multiple rams if needed. Could have 1 allocator for ram and just grab that so 
	//if there is nothing running then we can reset the whole thing or whatever is most convenient and efficient.
	//TODO FROM HERE I think stick with a resizable array for now and then we can change size later since
	//we will have a different model where we reuse memory anyways.
	// init(*all_data.ram_memory.ram_alloc_pool, ram_size);
	// all_data.ram_memory.bytes.count = ram_size;
	// all_data.ram_memory.bytes.data = cast(*u8) get(*all_data.ram_memory.ram_alloc_pool, ram_size);
	// all_data.ram_memory.bytes.allocated = ram_size;
	//TODO We don't really use this allocator now since we use the array fixed, but this would be the idea
	//eventually if we allow increasing the heap size at runtime if needed. Or we could make it fixed
	//and they have to increase it, or could set a start size and then increase if desired.
	// all_data.ram_memory.bytes.allocator.data = *all_data.ram_memory.ram_alloc_pool;
	//TODO Can use somethign like same_start_resize_flat_pool_allocator_proc here if we increase heap memory
	//at runtime and then it would reset and increase from the same point i think, but would have to test to make sure
	//SO we would call array_resize(all_data.ram_memory.bytes) which would use realloc and just grab the same memory
	//but increase it from the same position. NEED TO TEST THAT IT WORKS THOUGH BY CHECKING THE POINTERS
	// all_data.ram_memory.bytes.allocator.proc = flat_pool_allocator_proc;
	ram_size : int = Megabytes(4);
	array_resize(*all_data.ram_memory.bytes, ram_size);
	// array_resize(*all_data.all_ram_byte_memory, ram_size);
	// all_data.ram_memory.bytes.allocator.proc = same_start_resize_flat_pool_allocator_proc;
	// all_data.ram_memory.bytes.data = all_data.all_ram_byte_memory.data;
	// all_data.ram_memory.bytes.count = all_data.all_ram_byte_memory.count;
	// all_data.ram_memory.stack_size = cast(int) (0.5 * ram_size);
	all_data.ram_memory.stack_size = ram_size/2;
	// all_data.value_mem.data = cast(*MemoryValue) *all_data.old_byte_memory;
	// all_data.value_mem.count = Megabytes(1) / size_of(MemoryValue);
	// all_data.byte_mem.data = (cast(*u8) *all_data.old_byte_memory) + Megabytes(1);
	// all_data.byte_mem.count = Megabytes(1) / size_of(u8);
	} else {
	//TODO Using this flat_pool with overlay ram_memory now. Can remove other things here if we never use them.
	if *all_data.ram_flat_pool == null {
		init(*all_data.ram_flat_pool, Megabytes(5));
	} else {
		reset(*all_data.ram_flat_pool);
	}
	ram_size : int = Megabytes(2);
	all_data.ram_memory.bytes.data = cast(*u8) get(*all_data.ram_flat_pool, ram_size);
	all_data.ram_memory.bytes.count = ram_size;
	}

	//TODO Set this as default for now but we could set externally later
	//Or we could pass a value in here to set it to whatever we want.
	//Likely will have multiple rams and registers for each program currently executing later anyways.
	// all_data.all_register_memory[RegDef.hsp].int_value = ram_size/2;
	all_data.all_register_memory[RegDef.hsp].int_value = all_data.ram_memory.stack_size;
	all_data.all_register_memory[RegDef.hcp].int_value = all_data.all_register_memory[RegDef.hsp].int_value;

	// all_data.ram_memory.heap_p = ram_size - 1; //Could start from ram_size but then we would be off the actual memory.
	//This is off the ram but we could check this on a Get function for example.
	//Starting like this removes the need to check for initial conditions.
	all_data.ram_memory.heap_p = all_data.ram_memory.stack_size;
	all_data.ram_memory.debug_int.data = cast(*int) all_data.ram_memory.bytes.data;
	all_data.ram_memory.debug_int.count = ram_size / size_of(int);

	//TODO Remove this now that we use ram_memory
	// all_data.value_mem.data = cast(*MemoryValue) get(*all_data.ram_flat_pool, Megabytes(1));
	// all_data.value_mem.count = Megabytes(1) / size_of(MemoryValue);
	// all_data.byte_mem.data = cast(*u8) get(*all_data.ram_flat_pool, Megabytes(1));
	// all_data.byte_mem.count = Megabytes(1) / size_of(u8);
	// all_data.all_byte_mem.data = cast(*u8) all_data.ram_flat_pool.memory_base;
	// all_data.all_byte_mem.count = Megabytes(2) / size_of(u8);


	return all_data;
}
OP_TERMINAL_NAME :: "terminal88";
TERMINAL_LINE_HEIGHT_FACTOR : float : 1.35;

//TODO Each text file should have it's own allocator for string and lines
TEST_TEXT_NAME :: "test102";
CreateTestTextFile :: inline (all_next_ids : *AllNextIds, all_text_files : *[..] TextFile)
-> *TextFile
{
	//TODO FileString should be created externally as needed and then grabbed from a list as needed
	//Can do it once we finish with library and jai.
	//Also, they should be stored outside the current level so they can persist. Although the main
	//file should be in the current level and library files should be outside. For now we only have
	//1 library file but can have multiple later if we resolve dependency similarities with labels.
	//TODO Where should we put this default?
	//https://stackoverflow.com/questions/21038965/why-does-the-speed-of-memcpy-drop-dramatically-every-4kb
	// 1000 lines * 50 chars = 50000 bytes = 50kb
	//TODO This can be increased to anything if we do relative rendering of lines of code
	// since well always be rendering a fixed amount. Probably around 100 lines.
	//TODO Was tested with 5 Megabytes and 100k lines of code and it worked fine
	//so we could make 4-5 megabytes an upper limit and can do even more to see how far we can go...
	// main_text_file : TextFile = MakeTextFile(all_next_ids, TEST_TEXT_NAME, Kilobytes(50));
	new_text_file : *TextFile = array_add(all_text_files);
	new_text_file.* = MakeTextFile(all_next_ids, TEST_TEXT_NAME, Kilobytes(50));
	return new_text_file;
}

//TODO This should have a scissor so we only see text within the box and can move with text camera x
//systematically in UpdateFileStringAtCursor
DrawTextInputBox :: inline (
	command_type : TextCommandType, 
	text_string : string,
	cursor_diff_x : float,
	font_height : int,
	render_group : *RenderGroup)
{
	PushTextAndCursorShaderOrder(render_group);

	rect_height : float = 2;
	world_rect : Rectangle2 = RectCenterDim(Vector2F.{0,0}, MakeV2F(20,rect_height));
	PushRectangle(world_rect, DARK_BROWN, render_group, order = 10001);

	PushText(MakeV2F(world_rect.min.x, 2), enum_names(TextCommandType)[command_type], LIGHT_BROWN, render_group, order = 10003);

	text_cursor_start : Vector2F = world_rect.min;
	text_cursor_start.y += 0.5*rect_height;
	PushText(text_cursor_start, text_string, GREY_DARK_V, render_group, order = 10003);
	PushTypeCursor(text_cursor_start, cursor_diff_x, font_height, render_group);
}

ComputeFontHeightSquares :: inline (font_height : int, render_group : *RenderGroup) -> float {
	result : float = (OP_SPACE_LINE_HEIGHT*font_height) / render_group.pixels_per_square;
	return result;
}

//TODO Pulled these functions out so we can reuse them in other places while rendering.
ComputeCursorHeight :: inline (font_height : int, pixels_per_square : float) -> float {
	cursor_height : float = (1.5*font_height) / pixels_per_square;
	return cursor_height;
}
YAdjustCursorHeight :: inline (cursor_height : float) -> float {
	return 0.12 * cursor_height;
}
TextToMinCursorPos :: inline (text_pos : *Vector2F, cursor_height : float){
	text_pos.y -= 0.5*cursor_height;
	text_pos.y -= YAdjustCursorHeight(cursor_height);
}
/*TODO Conceptually we want the cursor to be a bit higher and lower than the char and for it to be even above and below.
*/
//TODO Pass in cursor color.
//TODO Could pass in TextCursor and put cursor_height in there
//TODO Maybe we should pass this in and compute it relative to char_width? Yes, then we don't have to do zoom factor.
PushTypeCursor :: inline (
	text_center_pos : Vector2F,
	cursor_diff_x : float,
	font_height : int,
	render_group : *RenderGroup,
	//TODO I think these should all be passed in. We just had the defaults before but now I think we should set
	//them manually in all cases like we are doing in the text editor.
	order : int = 10005,
	color : Vector4F = FGREEN_V,
	cursor_width : float = 0.1,
	//TODO Maybe we can remove this if we don't use it
	line_height_factor : float = 1.0)
-> Rectangle2
{
	cursor_rect : Rectangle2 = TypeCursorRect(text_center_pos, cursor_diff_x, font_height, 
		render_group.pixels_per_square, cursor_width, line_height_factor);
	PushRectangle(cursor_rect, color, render_group, order = order);
	return cursor_rect;
}
TypeCursorRect :: inline (
	text_center_pos : Vector2F,
	cursor_diff_x : float,
	font_height : int,
	pixels_per_square : float,
	//TODO I think these should all be passed in. We just had the defaults before but now I think we should set
	//them manually in all cases like we are doing in the text editor.
	cursor_width : float = 0.1,
	//TODO Maybe we can remove this if we don't use it
	line_height_factor : float = 1.0)
-> Rectangle2
{
	//TODO This should be set somewhere else like TextEditorData or RendererData so we don't have to recompute
	//and also so the font is consistent.
	// font_height_squares : float = (cast(float)(render_group.my_font.character_height + 0.5*render_group.my_font.typical_ascender)) / render_group.pixels_per_square;
	// font_height_squares : float = (1.5*font_height) / render_group.pixels_per_square;
	//TODO Maybe we should not multiple by OP_SPACE_LINE_HEIGHT by default and pass that in...
	// font_height_squares : float = ComputeFontHeightSquares(font_height, render_group);
	//TODO We don't seem to use the line_height_factor since we are using the height of the cursor for it anyways...
	// cursor_height : float = (line_height_factor*font_height) / render_group.pixels_per_square;
	// cursor_height : float = (1.5*font_height) / render_group.pixels_per_square;
	cursor_height : float = line_height_factor * ComputeCursorHeight(font_height, pixels_per_square);
	// font_height_squares_2 : float = OP_SPACE_LINE_HEIGHT;
	cursor_pos_x : float = text_center_pos.x + cursor_diff_x;
	//Move the cursor down a bit since it is higher than the line by line_height_factor.
	//TODO We could add the line_height_factor to cursor height as (1.0-line_height_factor)*font_height/pixels_per_square
	//and then add it here but this seems to work fine.
	// y_offset : float = (line_height_factor/11.5)*cursor_height;
	// cursor_rect : Rectangle2 = RectCenterDim(MakeV2F(cursor_pos_x, text_center_pos.y-y_offset), 
	// 	MakeV2F(cursor_width, cursor_height));
	//NOTE : This way we bring down the cursor a tiny bit since the center is around the same height as 
	//a lower case char and we want it a bit below that. 
	// y_adjust : float = 0.12 * cursor_height;
	y_adjust : float = YAdjustCursorHeight(cursor_height);
	//Not sure we need x_adjust... It seems to help a bit but maybe it could go either way depending on the case.
	//We can remove it if it causes any wierd issues here.
	x_adjust : float = 0.2 * cursor_width; 
	cursor_rect : Rectangle2 = RectCenterDim(MakeV2F(cursor_pos_x-x_adjust, text_center_pos.y-y_adjust), 
		MakeV2F(cursor_width, cursor_height));
	return cursor_rect;
}
DefaultCursorWidth :: inline (char_width_world : float) -> float {
	return 0.15 * char_width_world;
}
DefaultXGap :: inline (
	cursor_width : float,
	char_width_world : float,
	factor : float = 2.3) 
-> float
{
	x_gap : float = factor * cursor_width * char_width_world;
	return x_gap;
}
SingleCursorSettings :: struct {
	input_cursor_width : float;
	cursor_height_factor : float = 0.95;
	cursor_color : Vector4F = BLACK_V;
	draw_cursor : bool = true;
	highlight_color : Vector4F = LMBLUE_V;
}
DrawSingleLineCursor :: inline (
	cursor : TextCursor,
	start_text_cam_pos : Vector2F,
	//NOTE : This is here solely to highlight to the left withou a gap but
	//would be replaced with text scissoring if we do that instead
	start_rect_x : float,
	render_order : int,
	render_group : *RenderGroup,
	ted : TextEditorData,
	scs : SingleCursorSettings)
{
	my_cursor_width : float = DefaultCursorWidth(ted.code_font_1_char_width_world);
	if scs.input_cursor_width > 0 {
		my_cursor_width = scs.input_cursor_width;
	}

	cursor_x_diff : float = (cursor.cursor_line_char - cursor.left_char_bound) * ted.code_font_1_char_width_world;
	cursor_rect : Rectangle2 = TypeCursorRect(start_text_cam_pos, cursor_x_diff, ted.char_height, 
		render_group.pixels_per_square, my_cursor_width, line_height_factor=scs.cursor_height_factor);
	if scs.draw_cursor {
		PushRectangle(cursor_rect, scs.cursor_color, render_group, order = render_order + 1);
	}
	// cursor_rect : Rectangle2 = PushTypeCursor(start_text_cam_pos, cursor_x_diff, ted.char_height,
	// 	render_group, order=render_order+1, color=ORANGE_V, cursor_width=input_cursor_width,
	// 	line_height_factor=TEXT_BAR_CURSOR_FACTOR);
	if cursor.cursor_is_selecting {
		min_select_char : int;
		max_select_char : int;
		if cursor.fixed_select_line_char < cursor.cursor_line_char {
			min_select_char = max(cursor.fixed_select_line_char, cursor.left_char_bound);
			max_select_char = min(cursor.cursor_line_char, cursor.right_char_bound+2);
		} else { //cursor_line_char < fixed_select_line_char
			//Sanity check, this should never happen to avoid extra button presses to move it.
			//This case should set cursor_is_selecting=false in UpdateFileStringAtCursor
			assert(cursor.cursor_line_char != cursor.fixed_select_line_char);
			min_select_char = max(cursor.cursor_line_char, cursor.left_char_bound);
			max_select_char = min(cursor.fixed_select_line_char, cursor.right_char_bound+2);
		}
		min_select_char -= cursor.left_char_bound;
		max_select_char -= cursor.left_char_bound;

		cursor_height : float = GetHeight(cursor_rect);
		cursor_min_pos : Vector2F = start_text_cam_pos;
		if cursor.fixed_select_line_char < cursor.left_char_bound {
			//DOC : Doing this avoids having another scissor, but we can use a scissor instead if needed otherwise just for the text rect
			cursor_min_pos.x = start_rect_x;
		}
		// cursor_min_pos.y = cursor_rect.min.y + height_diff*cursor_height;
		cursor_min_pos.y = cursor_rect.min.y;
		cursor_min_pos.x += min_select_char * ted.code_font_1_char_width_world;

		char_count : int = max_select_char - min_select_char;
		highlighted_rect : Rectangle2 = HighlightedLineRect(char_count, cursor_height, cursor_min_pos,
			ted.code_font_1_char_width_world);
		//TODO Could pass this through cursor settings FROM the 
		PushRectangle(highlighted_rect, scs.highlight_color, render_group, order=render_order);
	}
}
DEFAULT_CURSOR_HEIGHT_DIFF : float : 0.05;
HighlightedLineRect :: inline (
	char_count : int,
	cursor_height : float,
	cursor_min_pos : Vector2F,
	char_width_world : float,
	height_diff : float = DEFAULT_CURSOR_HEIGHT_DIFF) 
-> Rectangle2
{
	text_pos : Vector2F = cursor_min_pos;
	text_pos.y += height_diff * cursor_height;
	highlighted_length : float = char_count * char_width_world;
	//1-2*height_diff means we raise by height_diff from the bottom and so then take height_diff off the top and bottom to even it out
	highlighted_height : float = (1.-2.*height_diff)*cursor_height;
	highlighted_rect : Rectangle2 = RectMinDim(text_pos, .{highlighted_length, highlighted_height});
	return highlighted_rect;
}
/*DOC :
The use case in thegame_base where we draw the text cursor fails
if we draw the cursor so that might be a reason to bind it.
BUT for now we don't draw the cursor so that gives us a failure point.

*/
CharCountUntilCursorWithTab :: inline (
	cursor_line_char : int,
	cursor_line_number : int,
	file_string : FileString)
-> int
{
	// assert(file_string.file_loc.count > 0);
	//TODO I will let this fail with invalid line number for now
	//since it should be valid once we select it.
	//This is tested in Test_TextOpCursor if needed to check
	//We could clamp it eventually if that seems better but I will leave it
	//for now to see if there are bugs.
	loc : string = file_string.file_loc[cursor_line_number];
	char_count : int = CharCountWithTabInString(loc, 0, cursor_line_char);
	return char_count;
}
//TODO We could generalize this by passing in a char and then also
//the char count or grabbing that in here from a function if needed.
//Right now only tabs are > 1 char but if we add more then we just have
//to update here with other char counts and check those that are > 1.
//BUT I don't think I'll do that since most text editors only have tab as > 1 char
CharCountWithTabInString :: inline (
	s : string,
	start_line_char : int,
	end_line_char : int)
-> int
{
	//This avoids weird issues or mistakes since this should not be possible
	assert(start_line_char <= end_line_char);
	//TODO Should this be a clamp below or asserted here?
	//Asserting allows us to see bugs as I don't think it should be negative
	//but maybe there are some cases where temporary invalid negative values are ok?
	//I guess this will make us find them out clearly if it happens.
	assert(start_line_char >= 0 && end_line_char >= 0);

	//Early out for empty string although I think it would work fine below
	if s.count <= 0 || s.data == null return 0;

	/*TODO We could have this fail instead but this prevents weird issues
	  like updating text file and having them in separate op spaces
	  then at least the rendering would not crash and then we would update
	  when choosing op space or changing tab. A crash might help us figure out
	  where the issue is but also may be annoying from a user perspective
	  where this would be fixed by selecting or refreshing the op space to update the cursor.
	*/
	start_char : int = min(start_line_char, s.count);
	end_char : int = min(end_line_char, s.count);

	char_count : int = end_char - start_char;
	bounded_string : string = String.slice(s, start_char, char_count);
	tab_count : int = StringCharCount("\t", bounded_string);	
	//NOTE : if tab_count == 0 then the following 2 lines do nothing, since we just 
	//subtract 0 and then add 0 but that is likely cheaper than having the if here anyways
	char_count -= tab_count;
	char_count += tab_count * TAB_CHAR_COUNT;
	return char_count;
}

//Note : This is fairly expensive function because of Simp.prepare_text, which is already called when rendering text.
//TODO Move this functio to the renderer since it is based on text data
#if 0 {
ComputePixelWidthOfString :: inline (
	input_string : string,
	my_font : *Dynamic_Font, 
	prepare_text_function : (*Dynamic_Font,string,Font_Effects) -> s64)
-> s64
{
    width_of_string : s64 = prepare_text_function(my_font, input_string, 0);
    //Note : This seems to align the string by keeping it consistent regardless of odd or even.
    if width_of_string % 2 == 1 width_of_string -= 1;
	return width_of_string;	
}
}
//Add this here to connect empty lines. I think this also makes everything that is highlighted clearer
//THIS ALSO removes the need for a second fixed select cursor
HighlightEmptyLine :: inline (
	cursor : $T,
	select_line : int,
	line_count : int) 
-> bool 
{
#assert(AllOrEquals(T, .[TextCursor, TextSplitLine]));
	highlighted_new_line : bool = 
		//If we come from the top, then we only highlighted the newline if that is not the current and therefore last line we are on
		//since we are only at the begnning of that line so we only highlighted the newline from the previous line and not the current line
		(cursor.cursor_line_number > cursor.fixed_select_line_number && 
	    cursor.cursor_line_number != select_line) 
		||
		//If we come from the bottom, then we always highlight the newline since we count that as a newline
		cursor.cursor_line_number < cursor.fixed_select_line_number;
		//This remove the newline on the way up but then we cant see the newline. Sublime text does it this way, not sure why...
		//then we cant tell the difference between highlighting just the line or a line and the new line.
		// cursor.cursor_line_number < cursor.fixed_select_line_number && line_count != 0;
	highlight_empty_line : bool = line_count == 0 && highlighted_new_line;
	return highlight_empty_line;
}
TextHighlight :: struct {
	char_point : int;
	char_count : int;
	highlight_color : Vector4F;
}
/*DOC : It feels more natural to split this out from TextCursor
as they are very different and serve different purposes. This is generally
used for split line text and also is more convenient and feels more natural
to use viewable lines here instead of end line index.

TODO I think even putting the split_lines array in here would
make it all be in 1 struct and be easily reusable anywhere
that we want split lines.

TODO Maybe we should call this TextWrapLine instead since split line can be confused
with that it's split by line 
*/
TextSplitLine :: struct {
	using cursor : TextCursor;
	//REMINDER : we are using start_file_line_index in cursor instead
	//this keeps it consistent with the cursor if we pass it into functions
	//AND it also does not add unecessary space here
	// start_line_index : int;

	//TODO Should have a copy of the whole lines here and then
	//use that for the terminal and the text console output
	//so we can resize as needed and the split lines are just
	//a string view into that anyways
	//Or for text op we can just add to an external array anyways
	//and just clear it when we recompile or reload settings
	split_lines : [..] StringSplitByLine;
	//DOC : Split selections which we can use to highlight
	//or even multi copy or things like that
	split_selcs : [..] StartEndLineChar;

	/*DOC : This is from zero so 
	end_index = start_file_line_index + viewable_lines_from_zero
	total_line_count = viewable_lines_from_zero+1
	this allows us to stay consistent with end index and not have to consider count
	and subtract (-1) everywhere.

	Generally I could have just used end_file_line_index like with text op space
	but this allows less updates since we just have to update start_file_line_index
	so I wanted to try that and see how it feels
	*/
	viewable_lines_from_zero : int;
	line_char_count : int;

	x_start_left : float;
	y_start_top : float;
	line_height : float;
	cursor_height : float;
}
ResetTSLAllLines :: inline (
	tsl : *TextSplitLine, 
	//TODO This is separate because of all_terminal_lines but we can
	//but it in TextSplitLine eventually if that makes more sense
	all_lines : *[..] string) 
{
	ResetTextCursor(*tsl.cursor);
	array_reset_keeping_memory(*tsl.split_lines);
	array_reset_keeping_memory(all_lines);
}
AddTSLLine :: inline (
	line : string,
	tsl : *TextSplitLine, 
	//TODO This is separate because of all_terminal_lines but we can
	//but it in TextSplitLine eventually if that makes more sense
	all_lines : *[..] string) 
{
	array_add(all_lines, line);
	AddSplitStringByLines(line, tsl);
}
//TODO Should we call this StringWrapByLine?
StringSplitByLine :: struct {
	split_string : string;
	//TODO Should we rename this to not_split_line_number?
	not_split_line_number : int;
}
//TODO Likely need to pass in line number and reference it so we know which lines
//OR just add line based on the previous one added
//TODO Where should we put this since we use it in the MAIN text editor as well for the compiler console
//Should we use it there as well or it just doing it straight away more efficient? I guess this is more consistent
// AddSplitStringByLines :: inline (
// 	s : string,
// 	line_world_width : float,
// 	char_width_world : float,
// 	split_lines : *[..] StringSplitByLine)
// {
// 	line_char_count := cast(int) (line_world_width / char_width_world);
// 	AddSplitStringByLines(s, line_char_count, split_lines);
// }
//DOC : We could pull out the split string by lines below but we are only adding them for now so no need.
//This currently splits the lines and adds them as a new line
AddSplitStringByLines :: inline (s : string, tsl : *TextSplitLine) {
	new_line_number : int = 0;
	if tsl.split_lines.count > 0 {
		last_line_number : int = peek(tsl.split_lines).not_split_line_number;
		new_line_number = last_line_number + 1;
	}
	
	//DOC : Line count is always > 0 since we always have 1 line even if its empty.
	//if s.count == line_char_count then we get 2 lines because technically the last char is on the next line
	//even though that line will be empty. this is a convention since we want the cursor on the next line instead 
	//of the previous line if we have no char at the end of line so we can see that we are now adding text to the next line
	//in the terminal for example
	//ALSO this code splits the lines, so we can pull this out if we want to just split lines but for now we only add split lines anyways as new lines
	line_count : int = 1 + (s.count / tsl.line_char_count);
	for 0..line_count-1 {
		next_line : string = String.slice(s, it * tsl.line_char_count, tsl.line_char_count);
		array_add(*tsl.split_lines, StringSplitByLine.{next_line, new_line_number});
	}
}
CopyTSLToClipboard :: inline (tsl : TextSplitLine) {
	selc : StartEndLineChar = TextSplitLineOrderedStartEndLineChar(tsl);
	sb : String_Builder;
	sb.allocator = temp;
	last_line_number : int = tsl.split_lines[selc.start_line].not_split_line_number;
	for split_line_index : selc.start_line..selc.end_line {
		split_line : StringSplitByLine = tsl.split_lines[split_line_index];
		line_string : string = split_line.split_string;
		start_char, end_char := LineSpecificStartEndChar(line_string, split_line_index, selc);
		char_count : int = end_char - start_char;
		if char_count == 0 {
			append(*sb, "\n");
		} else {
			if split_line.not_split_line_number != last_line_number {
				append(*sb, "\n");
			}
			copy_s : string = String.slice(line_string, start_char, char_count);
			append(*sb, copy_s);
		}
		last_line_number = split_line.not_split_line_number;
	}

	copy_text : string = builder_to_string(*sb,,temp);
	if copy_text.count > 0 {
		os_clipboard_set_text(copy_text);
	}
}
//TODO Can unit test this in the integration test with the terminal op
/*DOC : Char point is converted here to the position in a split line text.
This allows us to just take any char point from any text and find where it
would be in a split line text so we can highlight or select text in any way needed.
Eventually we can allow this to be used externally through something like dynamic libraries
or within our own code.
Remember to consider that the split line array is lacking the new line characters
in the char point so we need to either add those to the split line char (Which we are doing now)
or remove them from the char point which would require and extra loop or to use
an already made split line array to check how many lines we have till that char point.

start_char_point is incremented by 1 if we are at a newline and
end_char_point is decremented by 1 if we are at a newline

the return start_line_char and end_line_char are indices, so we need to do 
char_count = end_line_char - start_line_char + 1

if the end_char_point goes over the end but the start char point is before, then we bound it

since we are checking direct char points from the original text with new lines, it is the most clear
to pass in the text and then check the newline chars directly instead of checking from the split lines data
which could technically be done but is unnecessarily confusing

TODO Can make a similar functions for lines that are split by line and not by split line
*/
CharPointToSplitSelc :: inline (
	char_point : int, 
	char_count : int,
	text : string,
	tsl : TextSplitLine) 
-> StartEndLineChar 
{
	if text.count == 0 || char_point < 0 || char_count <= 0 || char_point >= text.count || tsl.split_lines.count == 0 {
		return .{};
	}

	start_char_point : int = char_point;
	if text[start_char_point] == #char "\n" {
		//skip over the new line if we start with it
		start_char_point += 1;
	}
	selc : StartEndLineChar;
	line_start_char : int = 0;
	// split_index : int = 0;
	//DOC : Go till we find the start highlight char which includes new line chars but the splitl ines don't
	//so we have to remember that if ever we have an issues here.
	previous_not_split_line_number : int = 0;
	for split_index : 0..tsl.split_lines.count-1 {
		split_line := tsl.split_lines[split_index];
		if split_line.not_split_line_number > previous_not_split_line_number {
			//add the newline char since the split lines dont have new lines but the char point from the input does have 
			//since its from the original text which contains new line chars
			line_start_char += 1;
			previous_not_split_line_number = split_line.not_split_line_number;
		}
		if InRange(line_start_char, start_char_point, line_start_char + split_line.split_string.count - 1) {
			selc.start_line = split_index;
			selc.start_line_char = start_char_point - line_start_char;
			break;
		} 
		line_start_char += split_line.split_string.count;
		// previous_not_split_line_number = split_line.not_split_line_number;
		if split_index == tsl.split_lines.count-1 {
			//we went past the end of the string and so start > end_of_string so return all 0s
			return selc;
		}
	}

	//end char point is an index and not a count so we need to do char_count = end_char_point - start_char_point
	//to get the count like we do when rendering this as text in the text console
	end_char_point : int = min(text.count-1, start_char_point + char_count - 1);
	if text[end_char_point] == #char "\n" {
		//remove the end line if we end with it
		end_char_point -= 1;
	}
	for split_index : selc.start_line..tsl.split_lines.count-1 {
		split_line := tsl.split_lines[split_index];
		if split_line.not_split_line_number > previous_not_split_line_number {
			//add the newline char since the split lines dont have new lines but the char point from the input does have 
			//since its from the original text which contains new line chars
			line_start_char += 1;
			previous_not_split_line_number = split_line.not_split_line_number;
		}
		if InRange(line_start_char, end_char_point, line_start_char + split_line.split_string.count - 1) {
			selc.end_line = split_index;
			selc.end_line_char = end_char_point - line_start_char;
			break;
		} 
		line_start_char += split_line.split_string.count;
		// previous_not_split_line_number = split_line.not_split_line_number;

		//IF the end char is over the string, then we highlight everything.
		//Otherwise this would remain at 0 and would then be <= start_line which would not make sense
		//we could also set this == to the start values but this seems more correct i think.
		if split_index == tsl.split_lines.count-1 && end_char_point >= line_start_char {
			selc.end_line = max(0,tsl.split_lines.count-1);
			selc.end_line_char = max(0,peek(tsl.split_lines).split_string.count-1);
			return selc;
		}
	}

	// print("selc=%\n", selc);
	return selc;
}

/*TODO 
	TODO Need to write some integration tests for this eventually now that we have the input mapping system with events.
	Implement text highlighting so we can remove the entire highlighted buffer.
	Implement copy and pasting both highlights and also lines.
	Implement undo system - put some notes below this comment

	Implement mouse input to move cursor. Only need to compute the delta of the current cursor position
	since it will have to be on the same screen and therefore < 50 lines away from the current position

	Note : single_line currently skips this function if we hit return_enter this frame. This prevents
	the '\n' char from being added when we want the text to remain on 1 line.

	Idea : Could pass in all_lines_of_code with the start_index of each line in the file. Then things like
	up and down arrow movement would be faster because we would not need search for the new_lines
	since we already know where we are from the all_lines_of_code.

	Line-by-line : Would only need to update this function and file_loc with a struct with dynamic string.	
	On macos, I am not sure if the asm will work with ARM NEON right away for .split and also memcpy 
	is 128-bit vectors like SSE instead of 256-bit vectors like AVX2. Does external string library work with ARM NEON?
	Single string model is more efficient for things like searching and generally keeping everything together in memory. 
	I tested it up to 100k loc, so even if mac only works for 10-50k loc that is ok. 

	IMPORTANT : If we need bigger file editing, we can just use an external editor and then make it easy 
	to reload text files and compile and run within this program.

*/
//TODO Undo system can be done by storing a point with cursor_pos and then accumulating text for a while or until
//input stops and then we just have undo/redo chunks like that which should be enough. Then also if we allow
//shortcuts we could have inverse events for the shortcuts like move line or replace all.
//TODO Should we rename to UpdateCodeStringAtCursor?
UpdateFileStringAtCursor :: inline (
	//TODO We could compile-time FileString and set if it's single line in there and then not
	//include the file_loc. I'll leave it separate for now but that would remove the array from there if needed
	//and then also provide the compile-time info here to not have all the code for single-line text editing.
	file_string : *FileString,
	cursor : *TextCursor,
	//TODO Pass in game_input here now so we can try to use new IsKeyboardPress
	// input : ControllerInput,
	/*DOC : I think having these here is clearer since we can update the file string
	however we want with any command BUT if we need to pass more in, 
	we can either pass in game_input or add some more variables 
	here for like IsInputDown or maybe mouse BUT it might be best to 
	just leave this as is since this updates the cursor and file 
	string specifically with these events
	*/
	frame_input_events : [] FrameInputEvent,
	// input_mappings : [] InputMapping,
	game_input : GameInput,
	//TODO Can pass in some mouse_data to move cursor with mouse eventually.
	// pixels_per_square : float,
	//TODO Can remove this now
	//We use it for the undo split string but maybe we can just pass that in instead OR set that in game input...?
	text_editor_data : TextEditorData,
	//REMOVE this since we can just pass in frame_input_events now
	//BUT we can add it back if we want specific actions later
	// all_tc_data : [] TextCursorAction = .[],
	$single_line : bool = false)
-> updated_text : bool, updated_input : bool //TODO Could make this a struct
{
//This is the keyboard, but let's remove other controllers now.
// input : ControllerInput = game_input.Controllers[0];
return_input_update : bool = false;
return_text_update : bool = false;

/*DOC : We are processing the events array here directly because this way we keep the events in the order
we receive them and therefore if we get a > 1 event in a frame, they are kept in the correct order. This prevents
having to think about if text inputs together with other keys or arrow inputs will happen in a certain order because
this way they will always happen in the same order as we receive them from the system.
*/
//TODO Could use a while loop here if we wanted to check other events or move around
// event_index : int = 0;
// for Input.events_this_frame print("event=%\n", it);
// while event_index < game_input.frame_input_events.count {
// 	defer event_index += 1;
// 	current_event : FrameInputEvent = game_input.frame_input_events[event_index];
// for current_event : game_input.frame_input_events {
for current_event : frame_input_events {
	//We only process events in order now so we can just check these as events since IsInputDown is whether we have
	//an event or not. This maintains order as well in case we pressed something valid before this event on the same frame.
	//TODO I think it might be best to also prevent this externally like in terminal and debug watch pane
	//and have this here just as a failsafe to prevent invalid presses for single line.
	#if single_line {
	// if IsInputDown(.ENTER, game_input) ||
	// 	IsInputDown(.TAB, game_input)
	if IsKeyboardEventAnyFlag(.ENTER, .IS_DOWN_WITH_PAUSE, current_event) ||
		//TODO We can set tab to show or not as an option since in the find bar we might want it and just show the unknown character
		IsKeyboardEventAnyFlag(.TAB, .IS_DOWN_WITH_PAUSE, current_event)
	{
		return return_text_update, return_input_update;
	}
	}

	event_text_update : bool;
	event_input_update : bool;
	// print("event=%\n", current_event);
	// if IsKeyboardEvent(#char "C", .{ctrl_pressed=true}, .DOWN_THIS_FRAME, current_event) ||
	if IsInputMapEvent(.TEXT_COPY, .DOWN_THIS_FRAME, current_event, game_input.game_input_mappings) ||
		IsKeyboardEvent(#char "X", .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) 
	{
		copy_text : string;
		if cursor.cursor_is_selecting {
			copy_text.count = abs(cursor.char_point - cursor.fixed_select_char_point);
			if cursor.char_point < cursor.fixed_select_char_point {
				copy_text.data = file_string.text_string.data + cursor.char_point;
			} else if cursor.fixed_select_char_point < cursor.char_point {
				copy_text.data = file_string.text_string.data + cursor.fixed_select_char_point;
			} else {
				//Sanity check
				assert(false, "cursor.char_point == cursor.fixed_select_char_point is not possible");
			}
		} else {
			//TODO MAYBE WE SHOULD REMOVE THIS CASE ALTOGETHER TO AVOID CONFUSION AND ISSUES?
			//It is convenient for holding ctrl+x to remove a bunch of code or copy-pasting the same line a few times
			//I removed it and if we don't use it then we remove this altogether. Will leave for now in case i decide to add it later
			#if 0 {
				//TODO Copy entire line find index from right and left of "\n" on both sides or start and end of file string
				line_start_char : int = LineStartCharPoint(cursor.char_point, file_string.*, single_line);
				//TODO Could use LineEndCharPoint and double check if we are at a "\n" or at the end and if so go over it.
				line_end_char : int = String.find_index_from_left(file_string.text_string, #char "\n", cursor.char_point);
				if line_end_char == -1 {
					line_end_char = file_string.text_string.count; // In case we are on the last line so no '\n' after
				} else {
					//We include the \n at the end
					line_end_char += 1;
				}

				copy_text.count = line_end_char - line_start_char;
				copy_text.data = file_string.text_string.data + line_start_char;

				//TODO We would have to add an extra remove text method code for general text remove without selection
				//in order for this to work properly with the undo system as well.
				//Can do that later if it seems necessary but now it just feels like unnecessary text editor functionality
				//since we can do everything with selection
				#if 0 {
				//NOTE : We don't need to remove text if we don't have any text OR if we are on a last empty line
				if copy_text.count > 0 &&
					IsKeyboardEvent(#char "X", .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) 
				{
					cursor.cursor_is_selecting = true;
					cursor.fixed_select_char_point = line_start_char;
					cursor.fixed_select_line_number = cursor.cursor_line_number;
					cursor.fixed_select_line_char = 0;

					cursor.char_point = line_end_char;
				}
				}
			}
		}

		//NOTE : We don't need to remove text if we don't have any text OR if we are on a last empty line
		//TODO We don't need this if now that we only copy selections but I will leave just in case for now.
		//Can remove if we decide to remove the copy/cut line functionality above later
		if copy_text.count > 0 {
			os_clipboard_set_text(copy_text);
		}
	}
	else if IsKeyboardEvent(#char "Z", .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) &&
		//If we don't have any undo history or action history, then we don't undo
		file_string.text_action_history.count > 0 && file_string.undo_buffer_length > 0
	{
		last_write_index : int = PosMod(file_string.action_write_index - 1, file_string.text_action_history.count);
		last_undo : TextAction = file_string.text_action_history[last_write_index];
		if last_undo.action_type == {
		case .REMOVE_TEXT_LEFT; #through;
		case .REMOVE_TEXT_RIGHT; {
			//Since we removed a char, we need to add it back
			set_char_data : *u8 = file_string.text_string.data + last_undo.after_action_cursor.char_point;
			last_char_data : *u8 = set_char_data + last_undo.undo_chars.count;
			copy_string_length : s64 = file_string.text_string.count - last_undo.after_action_cursor.char_point; 
			//Move over text to right
			memcpy(last_char_data, set_char_data, copy_string_length);
			//Add chars back where we had removed them
			memcpy(set_char_data, last_undo.undo_chars.data, last_undo.undo_chars.count);

			file_string.text_string.count += last_undo.undo_chars.count;
		}
		case .ADD_TEXT; {
			set_char_data : *u8 = file_string.text_string.data + last_undo.cursor_before_action.char_point;	
			last_char_data : *u8 = set_char_data + last_undo.undo_chars.count;
			end_char_point : int = last_undo.cursor_before_action.char_point + last_undo.undo_chars.count;
			copy_string_length : int = file_string.text_string.count - end_char_point;
			//remove added text back and set cursor back to where we were before
			memcpy(set_char_data, last_char_data, copy_string_length);

			file_string.text_string.count -= last_undo.undo_chars.count;
		}
		}

		file_string.undo_buffer_length -= 1;
		file_string.action_write_index = last_write_index;
		SetCursorWithCurrentBounds(cursor, last_undo.cursor_before_action);
		// cursor.* = last_undo.cursor_before_action;
	

		//We want to text update so that the lines of code are recomputed.
		event_text_update = true;
		//We don't have to input update since we set the cursor back to how it was before
		//BUT we do update because the cursor_line_char for action action cursor is wrong
		//and it is best to do it again for consistency and resilience.
		event_input_update = true;
	}
	//we can do redos if total_buffer_length > undo_buffer_length where
	//undo_count = redo_count = total_buffer_length - undo_buffer_length
	else if file_string.undo_buffer_length < file_string.total_buffer_length && 
			(IsKeyboardEvent(#char "Y", .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) ||
			 IsKeyboardEvent(#char "Z", .{ctrl_pressed=true,shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event))
	{
		redo : TextAction = file_string.text_action_history[file_string.action_write_index];
		if redo.action_type == {
		case .REMOVE_TEXT_LEFT; #through;
		case .REMOVE_TEXT_RIGHT; {
			//Redoing a remove text, so removing the text again
			set_char_data : *u8 = file_string.text_string.data + redo.after_action_cursor.char_point;
			last_char_data : *u8 = set_char_data + redo.undo_chars.count;
			end_char_point : int = redo.after_action_cursor.char_point + redo.undo_chars.count;
			copy_string_length : int = file_string.text_string.count - end_char_point;
			//remove added text back and set cursor back to where we were before
			memcpy(set_char_data, last_char_data, copy_string_length);

			file_string.text_string.count -= redo.undo_chars.count;
		}
		case .ADD_TEXT; {
			//Redoing an add text, so we are adding the text back
			set_char_data : *u8 = file_string.text_string.data + redo.cursor_before_action.char_point;
			last_char_data : *u8 = set_char_data + redo.undo_chars.count;
			copy_string_length : s64 = file_string.text_string.count - redo.cursor_before_action.char_point; 
			//Move over text to right
			memcpy(last_char_data, set_char_data, copy_string_length);
			//Add chars back where we had removed them
			memcpy(set_char_data, redo.undo_chars.data, redo.undo_chars.count);

			file_string.text_string.count += redo.undo_chars.count;
		}
		}

		next_write_cursor : int = PosMod(file_string.action_write_index + 1, file_string.text_action_history.count);
		file_string.action_write_index = next_write_cursor;
		file_string.undo_buffer_length += 1;
		SetCursorWithCurrentBounds(cursor, redo.after_action_cursor);
		// cursor.* = redo.after_action_cursor;

		//We have to redo event_input_update because the cursor_line_char could be wrong from the after_action_cursor
		//since we only so we update it accordingly and this is more consistent and resilient to any issues.
		event_input_update = true;
		event_text_update = true;
	}
	else if IsInputMapEvent(.TEXT_SELECT_ALL, .DOWN_THIS_FRAME, current_event, game_input.game_input_mappings) &&
		file_string.text_string.count > 0
	{
		SelectText(0, file_string.text_string.count, cursor, file_string, single_line);
		event_input_update = true;
	}

	/*DOC : If we update things on undo or redo, this avoids having also some extra text removal or addition
	which could create issues with the cursor_line_char updating or maybe something else unknown.
	I think having this here will be a bit more consistent and resilient but I guess testing and time will tell.

	TODO We could put this above and set add_text = true if we hit a shortcut like ctrl+V
	Having them all here is clearer though as to when we are actually adding and removing text.

	TODO IF we have an add and remove, then we can eventually create a replace action to do the replace with 1 undo/redo.
	This is simpler from a user perspective but requires some changes here which I can do later if needed.
	*/
	add_text : bool = current_event.event_type == .TEXT_BLOCK
		|| IsTextInputEvent(.IS_DOWN_WITH_PAUSE, current_event) 
	   || IsKeyboardEvent(.TAB, .IS_DOWN_WITH_PAUSE, current_event)
	   || IsKeyboardEvent(.ENTER, .IS_DOWN_WITH_PAUSE, current_event)
	   //TODO Can remove one of these (shift or ctrl) later if there is preference for only 1
	   || IsKeyboardEvent(.ENTER, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)
	   || IsKeyboardEvent(.ENTER, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)
	   || IsKeyboardEvent(#char "V", .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event);

	//TODO We could put this above and then set remove_text = true if we hit a shortcut like ctrl+X. Having here is clearer.
	remove_text : bool = IsKeyboardEvent(.BACKSPACE, .IS_DOWN_WITH_PAUSE, current_event) 
		|| IsKeyboardEvent(.DELETE, .IS_DOWN_WITH_PAUSE, current_event)
		|| IsKeyboardEvent(#char "X", .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) 
		|| (add_text && cursor.cursor_is_selecting);

	if remove_text && file_string.text_string.count > 0 {
		current_char_point_data : *u8 = file_string.text_string.data + cursor.char_point;
		if cursor.cursor_is_selecting {
			remove_width : int = abs(cursor.char_point - cursor.fixed_select_char_point);
			fixed_char_point_data : *u8 = file_string.text_string.data + cursor.fixed_select_char_point;
			if cursor.char_point > cursor.fixed_select_char_point {
				ta : TextAction;
				ta.action_type = TextActionType.REMOVE_TEXT_LEFT;
				ta.cursor_before_action = cursor;
				action_string : string = copy_temporary_string(string.{remove_width, fixed_char_point_data});

				copy_string_length : s64 = file_string.text_string.count - cursor.char_point; 
				memcpy(fixed_char_point_data, current_char_point_data, copy_string_length);
				//Adjust the cursor to the fixed select point
				cursor.char_point -= remove_width;
				cursor_line_diff : int = cursor.cursor_line_number - cursor.fixed_select_line_number;
				#if single_line assert(cursor_line_diff == 0); //sanity check for single line just in case to avoid issues with undo actions for find and replace bars
				if cursor_line_diff > 0 {
					cursor.cursor_line_number -= cursor_line_diff;
				}

				//Removal unselects to store in action. We do this on the bottom but doing it in both places is resilient.
				cursor.cursor_is_selecting = false;
				ta.after_action_cursor = cursor;
				CreateTextAction(action_string, ta, file_string, text_editor_data.undo_split_string);
			} 
			else if cursor.char_point < cursor.fixed_select_char_point {
				//Delete or backspace does not move the cursor in this case since the cursor is on the left
				//and we always remove text from the right.
				ta : TextAction;
				ta.action_type = TextActionType.REMOVE_TEXT_RIGHT;
				ta.cursor_before_action = cursor;
				//cursor.char_point on remove text right does not move so it is in the same place after the action.
				//Removal unselects. We do this on the bottom but doing it in both places is resilient.
				cursor.cursor_is_selecting = false;
				ta.after_action_cursor = cursor;
				CreateTextAction(string.{remove_width, current_char_point_data}, ta, file_string, text_editor_data.undo_split_string);


				copy_string_length : s64 = file_string.text_string.count - cursor.fixed_select_char_point; 
				memcpy(current_char_point_data, fixed_char_point_data, copy_string_length);
			} else {
				//Sanity check
				assert(false, "cursor.char_point == cursor.fixed_select_char_point is not possible");
			}

			file_string.text_string.count -= remove_width;

			/*DOC : If we are adding text we want to update the line char and bounds on remove so we can see the text.
			So if we remove here then we adjust the bounds and line char and then if we add some text back then we
			start from that removed position instead of the previous position which may result in not seeing any text.
			For example, pasting in some text on a single line when its highlighted and we are on the right char bound
			then this brings the left char bound back to 0 and then updates with the added text from there instead
			of adjusting it from the right char bound.
			*/
			if add_text {
				UpdateCursorLineCharAndBounds(cursor, file_string.*, single_line);
			}
		} 
		else if !cursor.cursor_is_selecting 
			&& IsKeyboardEvent(.BACKSPACE, .IS_DOWN_WITH_PAUSE, current_event)
			&& cursor.char_point > 0 
		{
			new_char_point_data : *u8 = current_char_point_data - 1;

			//TODO Can we generalize this if we pull out the memcpy and the position before changing the string
			//but also before changing the char points
			ta : TextAction;
			ta.action_type = TextActionType.REMOVE_TEXT_LEFT;
			ta.cursor_before_action = cursor;
			action_string : string = copy_temporary_string(string.{1, new_char_point_data});

			//IMPORTANT : Need to do this before the memcpy, otherwise we are checking the wrong char.
			//This led to an issue where if the next char was a \n then we would move the cursor incorrectly.
			if new_char_point_data.* == cast(u8) #char "\n" && !single_line {
				cursor.cursor_line_number -= 1;
			}
			
			copy_string_length : s64 = file_string.text_string.count - cursor.char_point; 
			memcpy(new_char_point_data, current_char_point_data, copy_string_length);

			cursor.char_point -= 1;
			file_string.text_string.count -= 1;

			ta.after_action_cursor = cursor;
			CreateTextAction(action_string, ta, file_string, text_editor_data.undo_split_string);
		} 
		else if !cursor.cursor_is_selecting
			&& IsKeyboardEvent(.DELETE, .IS_DOWN_WITH_PAUSE, current_event)
			&& cursor.char_point < file_string.text_string.count
		{
			old_char_point_data : *u8 = current_char_point_data + 1;

			ta : TextAction;
			ta.cursor_before_action = cursor;
			ta.action_type = TextActionType.REMOVE_TEXT_RIGHT;
			//NOTE : Delete has same char point and line number before and after action, so we can set them beforehand
			//and pass the string directly from the file instead of copying it.
			ta.after_action_cursor = cursor;
			CreateTextAction(string.{1, current_char_point_data}, ta, file_string, text_editor_data.undo_split_string);

			copy_string_length : s64 = file_string.text_string.count - cursor.char_point - 1; 
			memcpy(current_char_point_data, old_char_point_data, copy_string_length);
			file_string.text_string.count -= 1;
		}

		//NOTE : This removes selection if we are removing text AND also if we are adding text after a selection
		//which would remove the text here and therefore run this line and remove the selection.
		//In order to not hide bugs i put an assert here since we undo the selection when selecting above now,
		//so if we don't undo the selection then we should crash to avoid any text editing bugs/issues.
		assert(!cursor.cursor_is_selecting);
		// cursor.cursor_is_selecting = false;
		event_input_update = true;
		event_text_update = true;
	}
	/*NOTE : We do text_input first so that if the file_loc changes, then we can use that correct one after
	on the same frame. This way we have a consistent text updating and cursor updating every frame.
	*/
	// cursor_start_line_number : int = cursor.cursor_line_number;
	if add_text {
		//TODO Could use a function here instead but this seems cleaner for now.
		input_text : string;
		char_input : u8;
		if current_event.event_type == .TEXT_BLOCK {
			input_text = current_event.text_block;
		}
		else if IsTextInputEvent(.IS_DOWN_WITH_PAUSE, current_event) {
			input_text.data = cast(*u8) (*current_event.utf32);
			input_text.count = 1;
		}
		else if IsKeyboardEvent(.ENTER, .IS_DOWN_WITH_PAUSE, current_event) ||
	   		  //TODO Can remove one of these (shift or ctrl) later if there is preference for only 1
	   		  //SETTINGS this should also be set in settings
	   		  IsKeyboardEvent(.ENTER, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) ||
	   		  IsKeyboardEvent(.ENTER, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)
		{
		   if IsKeyboardEvent(.ENTER, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) ||
	   		IsKeyboardEvent(.ENTER, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)
		   {
				cursor.char_point = LineEndCharPoint(cursor.*, file_string.*, single_line);
			}
			char_input = #char "\n";
			input_text.data = *char_input;
			input_text.count = 1;
	   }
	   else if IsKeyboardEvent(.TAB, .IS_DOWN_WITH_PAUSE, current_event) {
			char_input = #char "\t";
			input_text.data = *char_input;
			input_text.count = 1;
	   }
		else if IsKeyboardEvent(#char "V", .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) {
			input_text = os_clipboard_get_text(,,temp);
		}

		new_text_length : int = file_string.text_string.count + input_text.count;
		if new_text_length >= file_string.total_allocated_bytes {
			//TODO We could double the size of the string here and then write the buffer to it.
			//Can try to do that with new same_start_resize_flat_pool_allocator_proc with Flat_Pool
			//ALSO Can have an option that limits it and does not resize it automatically here.
			//That can be used for watch and text box input.
			//YES And we can put the option in FileString and then return from here if it is limited size.
			//Could even add a return value although we won't update anything in that case
			//But then for text editor string we would want to resize and then
			//only limit it to the allocator max which we can check in here from Flat_Pool.
			print("End of file text editing.\n");
		}

		//TODO Once we double the string size above, we can remove this if statement
		if new_text_length < file_string.total_allocated_bytes
		{
			ta : TextAction;
			ta.action_type = TextActionType.ADD_TEXT;
			ta.cursor_before_action = cursor;

			//TODO Test this new fast method of copying thoroughly.
	    	//TODO make this a fast unsafe insert string method
	    	//TODO Could be safe if we pass in TextFile and verify the total_allocated_bytes
			old_char_point_data : *u8 = file_string.text_string.data + cursor.char_point;
			new_char_point_data : *u8 = old_char_point_data + input_text.count;
			copy_string_length : s64 = file_string.text_string.count - cursor.char_point; 
			//Note : Copy second part forward
			memcpy(new_char_point_data, old_char_point_data, copy_string_length);
			//Note : Copy input_buffer
			memcpy(old_char_point_data, input_text.data, input_text.count);

			file_string.text_string.count = new_text_length;

			// if text_add_update_cursor {
			cursor.char_point += input_text.count;

			// if input_text.count > 1 {
			// 	print("text_buffer_count = %\n", input_text.count);
			// }
			// Being here prevents us from adding '\n' if we are >= total_allocated_bytes
			#if !single_line {
			// Need to move the cursor for every "\n" found.
			// Not having this led to a bug where the cursor was not aligned with the text.
			// This also keeps it consistent with the text_input instead of the return_enter key
			// in case those mismatch for some reason.
			// But maybe not on testing. The else if with the back_space may have been enough.
			// Leaving though as this is resilient code for 
			//TODO Can we do this faster with SIMD? YES use find_index_from_left in the loop instead.
			//If we use external string module that uses AVX eventually then that would be double speed.
			for 0..input_text.count-1 if input_text[it] == #char "\n" {
				cursor.cursor_line_number += 1;
			}
			// if input.return_enter.is_down_with_pause {
			// 	cursor.cursor_line_number += 1;
			// }
			}
			// }	

			ta.after_action_cursor = cursor;
			CreateTextAction(input_text, ta, file_string, text_editor_data.undo_split_string);

			event_input_update = true;
			event_text_update = true;
		}
	}

	//TODO We only need to do this if we update the cursor_line_number
	#if !single_line {
	//TODO Instead of storing this as a bool, do the diff and check if diff != 0
	if event_text_update {
		//Note : Clear the errors since we updated the text
		// array_reset_keeping_memory(*perm.all_data.all_parse_errors);

		//TODO Can optimize this further by only splitting within the viewable region
		//and then only having those lines of code. One problem there is then we need some
		//relative placement data for the positions of the line OR we can always replace it
		//in the same place in the op_space and limit the op_space camera movement so we 
		//cannot go beyond those limits. We could also just have chunks of lines and the position
		//is always relative to the current chunk and we swap out chunks depending on where we are.
		//and so the position won't change when we swap out chunks. (or it will)
		//Note : This is stored in temporary storage. We can use custom StringSplit if we 
		//want a different allocator and we can pass back char_index if we want to know
		//the start char of each line from custom StringSplit.
		/*This site suggest either a spit buffer or a line-by-line implementation.
		https://stackoverflow.com/questions/4046246/how-are-text-editors-generally-implemented

		CURRENT METHOD WAS TESTED WITH AROUND 50-100k lines and it works fine sooo...
		I guess it would be worth testing with multiple files open but ultimately if we put things
		on separate threads then that might even be totally fine eventually.
		
		AN ALTERNATIVE is to do line-by-line editing but then we would have jagged arrays. So line-by-line would
		be faster for typical character input editing but would possibly create sparse memory and be
		more complex code-wise for line-by-line changes. But then we would not have to split on every update.
		Could try that eventually since we would only have to update UpdateFileStringAtCursor here and could
		then have 2 different text editors.

		NOTE : OPTIMIZING this split depending on the input case is more or less equivalent to line-by-line editing
		in terms of efficiency I think. So we could do that and if we just move some lines around for example
		or cut or paste a few full lines in then we can just update those lines in the file_loc instead
		of re-splitting the whole file. WE can do the whole thing in other cases.
		THIS IS ONLY NECESSARY IF WE HAVE SOME KIND OF SLOWDOWN BECAUSE OF THE SPLIT. Using avx find_index_from_left
		would be a first level optimization which would give a free 2x speedup for this in any case.

		ALSO Could have a FileViewer which does not allow editing but can view and traverse a file.
		This would be more efficient for syntax highlighting because then we would only have to do it
		whenever the file is externally updated and can index it as such. Otherwise we have to do
		syntax highlighting for each line on each pass (not so bad with only viewable lines now).
		FileViewer can be better for editing text externally and debugging or jumping around internally.
		*/

		//TODO Should split this directly into file_loc instead of like this.
		//That would be much more efficient and then we can optimize directly here and not have 
		//store this in temp and then do the memcpy since this could potentially be.
		//THAT WOULD BE FIRST OPTIMIZATION ALONG WITH avx find_index_from_left with external string library.
		//TODO Can just use an allocator directly anyways but then .split needs to use it
		//so then we don't have to memcpy back to file_loc. Can copy a .split that uses allocator
		//and then we just automatically reallocate the data with the same allocator as file_loc
		//and then we don't need the memcpy here and that would be easily more efficient.
		array_temp_split : [] string = 
			String.split(file_string.text_string, cast(u8) #char "\n",, temp);
		//ACTUALLY WE CAN JUST DO IT DIRECTLY HERE and load it in. We can adjust file_loc beforhane
		//since we already know the cursor_line_number difference from above.
		//TODO Would just need to keep track of it when we do cutting and highlighting add and removal later.
		//I think the only case is cutting we would have to loop through how many "\n" we cut or deleted out.
		//If we use external string module that uses AVX eventually then that would be double speed.

		//TODO Can use this to adjust below instead.
		//TODO Use this to adjust file_loc instead if we copy the split
		//directly to file_loc which we should do eventually anyways.
		//Also split with AVX2 since 95% of people have AVX2 on steam survey.
		// cursor_line_diff : int = cursor_start_line_number - cursor.cursor_line_number;

		//TODO Can do this beforehand now based on cursor_line_number and just compute a cursor_delta_lines
		//and then add or remove to the count based on the delta.
		//TODO instead of doing this we can have a max pre-allocated LOC and just copy over directly
		//and then double when we have to.
		//TODO Could check the allocated size for all_lines_of_code and just do a resize if we have to
		s : string = ---; //TODO could place this globally so we don't have to recreate every time
		while file_string.file_loc.count < array_temp_split.count {
			//TODO Can just do array_resize here instead with cursor_line_diff
			array_add(*file_string.file_loc, s);
		}

		//TODO Why not just reduce the count here with cursor_line_diff? Could test that out
		//I think because I was trying to make it more efficient but it did not work so I think
		//just reducing the count is ok now. Maybe can test when we implement multi-line copy/paste
		//and also highlighting.
		while file_string.file_loc.count > array_temp_split.count {
			array_unordered_remove_by_index(*file_string.file_loc,
				file_string.file_loc.count-1);
		}

		//TODO We can just split this directly in file_loc instead of doing this copy and adding above
		memcpy(file_string.file_loc.data, array_temp_split.data,
			array_temp_split.count * size_of(string));


		//TODO We could do this for single line as well, maybe for the terminal but maybe better to use a different system for that.
		//TODO We could put this on the bottom if that is clearer
		file_string.not_saved_text_edit = true;
	}
	}

	/*DOC : To prevent moving arrows and adding text input on the same frame, if we updated text beforehand
	then we don't do it again here. This way we avoid potential issues with resetting select_line_char
	or having out of order arrow keys on the same frame. We can remove it if there seems to be issues.
	*/
	
	//TODO Should we put else if here with the other arrow keys?
	//Probably yes since it does not seem to pickup anyways but
	//we can check manually later.
	// if IsOnlyInput(input.arrow_right.is_down_with_pause, input) &&
	if (IsKeyboardEvent(.ARROW_RIGHT, .IS_DOWN_WITH_PAUSE, current_event) || 
		 IsKeyboardEvent(.ARROW_RIGHT, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)) 
		// && cursor.char_point < file_string.text_string.count 
	{
		if cursor.cursor_is_selecting && IsKeyboardEvent(.ARROW_RIGHT, .IS_DOWN_WITH_PAUSE, current_event) {
			//If we are selecting then we leave the cursor where it is if it is > fixed point
			//if cursor < fixed point, then we move it to the fixed point
			cursor.cursor_is_selecting = false;
			if cursor.char_point < cursor.fixed_select_char_point {
				cursor.char_point = cursor.fixed_select_char_point;
				cursor.cursor_line_number = cursor.fixed_select_line_number;
				cursor.cursor_line_char = cursor.fixed_select_line_char;
			}
		} else if cursor.char_point < file_string.text_string.count {
			//We leave this outside to unselect in any case
			CheckAndSetSelection(cursor,
				IsKeyboardEvent(.ARROW_RIGHT, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)); 
	    	current_char : u8 = (file_string.text_string.data + cursor.char_point).*;
			if current_char == cast(u8) #char "\n" && !single_line {
				cursor.cursor_line_number += 1;
			}
			cursor.char_point += 1;
		}
		event_input_update = true;
	} 
	if (IsKeyboardEvent(.ARROW_LEFT, .IS_DOWN_WITH_PAUSE, current_event) || 
		 IsKeyboardEvent(.ARROW_LEFT, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)) 
		//NOTE : We don't want this for selection since then at char_point == 0 we don't trigger the unselect
		// && cursor.char_point > 0 
	{
		//TODO We could pull this case out if it's cleaner but having it here seems cleaner since all left arrow is in the same place.
		if cursor.cursor_is_selecting && IsKeyboardEvent(.ARROW_LEFT, .IS_DOWN_WITH_PAUSE, current_event) {
			//If we are selecting and press arrow left without shift, 
			//if cursor < fixed point, we leave the cursor where it is 
			//if cursor > fixed point, we move it to the fixed point
			cursor.cursor_is_selecting = false;
			if cursor.char_point > cursor.fixed_select_char_point {
				cursor.char_point = cursor.fixed_select_char_point;
				cursor.cursor_line_number = cursor.fixed_select_line_number;
				cursor.cursor_line_char = cursor.fixed_select_line_char;
			}
		} else if cursor.char_point > 0 {
			CheckAndSetSelection(cursor, 
				IsKeyboardEvent(.ARROW_LEFT, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event));
			cursor.char_point -= 1;
	    	current_char : u8 = (file_string.text_string.data + cursor.char_point).*;
			if current_char == cast(u8) #char "\n" && !single_line {
				cursor.cursor_line_number -= 1;
			}
		}
		event_input_update = true;
	} 
	CTRL_SKIP_CHARS : string : " \t";
	if (IsKeyboardEvent(.ARROW_RIGHT, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) || 
		 IsKeyboardEvent(.ARROW_RIGHT, .{ctrl_pressed=true,shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)) 
		//No longer need this since we want to unselect if we are at the end of the file
		// && cursor.char_point < file_string.text_string.count  
	{
		CheckAndSetSelection(cursor, 
			IsKeyboardEvent(.ARROW_RIGHT, .{ctrl_pressed=true,shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event));

		did_right_skip : bool = false;
 		while cursor.char_point < file_string.text_string.count &&
 				String.is_any((file_string.text_string.data + cursor.char_point).*, CTRL_SKIP_CHARS)
		{
			cursor.char_point += 1;
			did_right_skip = true;
		} 			

		if cursor.char_point < file_string.text_string.count {
	 		current_char : u8 = (file_string.text_string.data + cursor.char_point).*;
	 		if did_right_skip && current_char == "\n" {
	 			//Explicitly do nothing since we want to no skip over newline after a skip to show that there
	 			//are some empty spaces or tabs at the end of that line.
	 		} else if !did_right_skip && current_char == "\n" {
	 			//We only skip over single new lines since that feels best.
				cursor.char_point += 1;
				#if !single_line {
				cursor.cursor_line_number += 1;
				}
			} else if is_alnum(current_char) {
				//Skip over just the word
		    	while cursor.char_point < file_string.text_string.count &&
		    			is_alnum((file_string.text_string.data + cursor.char_point).*)
		    	{
		    		cursor.char_point += 1;
		    	}
		   } else if cursor.char_point + 1 < file_string.text_string.count &&
	   			is_alnum((file_string.text_string.data + cursor.char_point + 1).*)
	   			//NOTE : This is dealt with because the previous else if did not pass
	   			//&& !is_alnum(current_char)
		   {
		   	//If next char is alnum but current char is not (because of above else if)
		   	//Skip over 1 char and then the word 
		   	cursor.char_point += 1;
		   	while cursor.char_point < file_string.text_string.count &&
	    				is_alnum((file_string.text_string.data + cursor.char_point).*)
		    	{
		    		cursor.char_point += 1;
		    	}
			} else {//!is_alnum(current_char) && !is_alnum(next_char)
		    	while cursor.char_point < file_string.text_string.count && 
		    			!is_alnum((file_string.text_string.data + cursor.char_point).*) &&
		    			!is_space((file_string.text_string.data + cursor.char_point).*)
	 			{
		    		cursor.char_point += 1;
		    	}
		   }
		}
    	event_input_update = true;
	} 
	if (IsKeyboardEvent(.ARROW_LEFT, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) || 
		 IsKeyboardEvent(.ARROW_LEFT, .{ctrl_pressed=true,shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)) 
		//Need to be able to unselect if we are at start of file so we put this check below
		// && cursor.char_point > 0
	{
		CheckAndSetSelection(cursor, 
			IsKeyboardEvent(.ARROW_LEFT, .{ctrl_pressed=true,shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event));

		did_left_skip : bool = false;
		if cursor.char_point > 0 {
			if String.is_any((file_string.text_string.data + cursor.char_point - 1).*, CTRL_SKIP_CHARS) {
				cursor.char_point -= 1;
		 		while cursor.char_point > 0 &&
		 				String.is_any((file_string.text_string.data + cursor.char_point).*, CTRL_SKIP_CHARS) 
				{
					cursor.char_point -= 1;
				} 			
				//NOTE : This is more explicit than putting >= 0 in the while loop and I want to make the file bound checks clear.
				if cursor.char_point != 0 {
					cursor.char_point += 1;
				}
	 			did_left_skip = true;
		 	}
		}

	 	if cursor.char_point > 0 {
			cursor.char_point -= 1;
			if did_left_skip && (file_string.text_string.data + cursor.char_point).* == "\n" {
				//EXPLICITLY just set the cursor back since we want to stop if we skipped to the beginning of a line
				cursor.char_point += 1;
			} else if !did_left_skip && (file_string.text_string.data + cursor.char_point).* == "\n" && !single_line {
	 			//We only skip over single new lines since that feels best.
				cursor.cursor_line_number -= 1;
			} else if is_alnum((file_string.text_string.data + cursor.char_point).*) {
				//Skip over word if current char is alnum
		    	while cursor.char_point > 0 && is_alnum((file_string.text_string.data + cursor.char_point).*) {
		    		cursor.char_point -= 1;
		    	}
		    	//We could put >= 0 in the while loop but this is clearer. IF we hit the beginning of the file
		    	//then we don't add a char point since we stopped there.
		    	if cursor.char_point != 0 {    
			    	cursor.char_point += 1;
			   }
	   	} else if cursor.char_point - 1 > 0 && is_alnum((file_string.text_string.data + cursor.char_point - 1).*) 
	   		//This is not needed because previous else if did not pass
	   		//&& !is_alnum(current_char)
	   	{
	   		//We skip left over 1 char and then alnum. Good for cases liked "10," or "1.0]" or "x="
	   		cursor.char_point -= 1;
		    	while cursor.char_point > 0 && is_alnum((file_string.text_string.data + cursor.char_point).*) {
		    		cursor.char_point -= 1;
		    	}
		    	if cursor.char_point != 0 {
			    	cursor.char_point += 1;
			   }
			} else {//!is_alnum(current_char) && !is_alnum(current_char_point-1). both cases checked above
				//Here we don't have alnum in previous 2 chars AND we dont have skip chars since we already skipped above
				//SO then we skip over all non_alnum chars and also stop at is_space which includes newlines and tabs.
				cursor.char_point -= 1;
		    	while cursor.char_point > 0 && 
		    			!is_alnum((file_string.text_string.data + cursor.char_point).*) &&
		    			!is_space((file_string.text_string.data + cursor.char_point).*)
	 			{
		    		cursor.char_point -= 1;
		    	}
		    	if cursor.char_point != 0 {
			    	cursor.char_point += 1;
			   }
			}
		}
    	event_input_update = true;
	} 
	if (IsKeyboardEvent(.HOME, .IS_DOWN_WITH_PAUSE, current_event) || 
		 IsKeyboardEvent(.HOME, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)) 
		&& cursor.char_point > 0 
	{
		CheckAndSetSelection(cursor, 
			IsKeyboardEvent(.HOME, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event));
		line_start_char : int = LineStartCharPoint(cursor.char_point, file_string.*, single_line);
		text_start_char : int = line_start_char;
		next_char : *u8;
		if text_start_char < file_string.text_string.count {
			next_char = file_string.text_string.data + text_start_char;
		}
		//If we have some skip chars at the beginning of the line then we oscillate between the start of the line and end of those chars
		while text_start_char < file_string.text_string.count && 
			String.is_any(next_char.*, CTRL_SKIP_CHARS) 
		{
			text_start_char += 1;
			next_char += 1;
		}
		if text_start_char == cursor.char_point {
			cursor.char_point = line_start_char;
		} else {
			cursor.char_point = text_start_char;
		}
		event_input_update = true;
	} 
	if (IsKeyboardEvent(.END, .IS_DOWN_WITH_PAUSE, current_event) || 
		 IsKeyboardEvent(.END, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)) 
	{
		CheckAndSetSelection(cursor,
			IsKeyboardEvent(.END, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event));

		cursor.char_point = LineEndCharPoint(cursor.*, file_string.*, single_line);
		event_input_update = true;
	}
	if IsKeyboardEvent(#char "L", .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) 
		&& !single_line 
	{
		if !cursor.cursor_is_selecting {
			cursor.cursor_is_selecting = true;
			cursor.fixed_select_char_point = LineStartCharPoint(cursor.char_point, file_string.*, single_line);
			cursor.fixed_select_line_number = cursor.cursor_line_number;
			cursor.fixed_select_line_char = 0;
		} else if cursor.cursor_is_selecting && cursor.fixed_select_char_point > cursor.char_point {
			cursor_copy : TextCursor = cursor.*;

			cursor.fixed_select_char_point = LineStartCharPoint(cursor_copy.char_point, file_string.*, single_line);
			cursor.fixed_select_line_number = cursor_copy.cursor_line_number;
			cursor.fixed_select_line_char = 0;

			cursor.char_point = cursor_copy.fixed_select_char_point;
			cursor.cursor_line_number = cursor_copy.fixed_select_line_number;
		} else if cursor.cursor_is_selecting && cursor.fixed_select_char_point < cursor.char_point &&
			cursor.fixed_select_line_char > 0
		{
			cursor.fixed_select_char_point = LineStartCharPoint(cursor.fixed_select_char_point, file_string.*, single_line);
			cursor.fixed_select_line_char = 0;
		}

		cursor.char_point = LineEndCharPoint(cursor.*, file_string.*, single_line);
		if cursor.char_point < file_string.text_string.count &&
			file_string.text_string[cursor.char_point] == #char "\n" 
		{
			cursor.char_point += 1;
			cursor.cursor_line_number += 1;
		}
		event_input_update = true;
	}

	#if !single_line {
	//DOC : I think allowing ctrl+arrow and arrow on the same frame is ok since they are separate functions.
	//Also allowing up/down+left/right is ok but not up+down and left+right on the same frame
	// if input.only_ctrl_down && input.arrow_up.is_down_with_pause
	if IsKeyboardEvent(.ARROW_UP, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)
		&& cursor.start_file_line_index > 0 
	{
		move_bounds : bool = true;
		if cursor.cursor_line_number >= cursor.end_file_line_index &&
			!cursor.cursor_is_selecting
		{
			move_bounds = MoveCursorUp(file_string, cursor);
			//TODO technically this is only for the cursor right now but just in case we set it anyways.
			//Not sure if there can be issues with doing this and text editing at the same time
			event_input_update = true;
		} 
		if move_bounds {
			//TODO Can have a render_start_index which could be this-1 or this-2 and end this+2
			//so that we can render an extra line but this is where the cursor would stop at
			cursor.start_file_line_index -= 1;
			cursor.end_file_line_index -= 1;
		}
		//TODO We only do camera on x now but leaving here as reminder.
		//We can update camera outside of this call so we don't have to pass it in here.
		// op_2D_cam.world_pos.y += OP_SPACE_LINE_HEIGHT;
	} 

	/*NOTE: Here we check file_loc_count but if we updated text then it will be wrong. This could
	cause an inconsistency if, for example, we remove some lines AND move down on the same frame.
	We could prevent text_updating in this case to avoid that OR we could do text editing first 
	and then compute new file_loc and then check this afterwards so that it is always consistent...?
	*/
	// if input.only_ctrl_down && input.arrow_down.is_down_with_pause
	// if IsKeyboardEvent(.ARROW_DOWN, .{ctrl_pressed=true}, current_event)
	if IsKeyboardEvent(.ARROW_DOWN, .{ctrl_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)
		&& cursor.end_file_line_index < file_string.file_loc.count-1 
	{
		move_bounds : bool = true;
		if cursor.cursor_line_number <= cursor.start_file_line_index &&
			!cursor.cursor_is_selecting
		{
			move_bounds = MoveCursorDown(file_string, cursor);
			event_input_update = true;
		} 
		if move_bounds {
			cursor.start_file_line_index += 1;
			cursor.end_file_line_index += 1;
		}
		// op_2D_cam.world_pos.y -= OP_SPACE_LINE_HEIGHT;
	}

	//TODO These should be thoroughly tested in all cases, including bound checks.
	//Can possibly pull out up and down arrow as functions and test there
	//or just test this function directly in all cases.
	if (IsKeyboardEvent(.ARROW_UP, .IS_DOWN_WITH_PAUSE, current_event) || 
		 IsKeyboardEvent(.ARROW_UP, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event)) 
		//NOTE : We don't want to trigger this for selection so that we unselect
		// && cursor.cursor_line_number > 0 
	{
		if cursor.cursor_is_selecting && IsKeyboardEvent(.ARROW_UP, .IS_DOWN_WITH_PAUSE, current_event) {
			//If we are selecting and press arrow up without shift, 
			//if cursor < fixed point, we move up normally 
			//if cursor > fixed point, we move it to the fixed point and then move up normally
			if cursor.char_point > cursor.fixed_select_char_point {
				cursor.char_point = cursor.fixed_select_char_point;
				cursor.cursor_line_number = cursor.fixed_select_line_number;
				cursor.cursor_line_char = cursor.fixed_select_line_char;
			}
		} 

		CheckAndSetSelection(cursor, 
			IsKeyboardEvent(.ARROW_UP, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event));
		//We check this in MoveCursorUp anyways
		// if cursor.cursor_line_number > 0 {
		moved_cursor : bool = MoveCursorUp(file_string, cursor);
		//Better to update anyways for consistency and resilience
		event_input_update = true;
		// event_input_update = moved_cursor;
		// }
	}	
	if IsKeyboardEvent(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, current_event) || 
		IsKeyboardEvent(.ARROW_DOWN, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event) 
	{
		if cursor.cursor_is_selecting && IsKeyboardEvent(.ARROW_DOWN, .IS_DOWN_WITH_PAUSE, current_event) {
			//If we are selecting and press arrow down without shift, 
			//if cursor > fixed point, we move down normally 
			//if cursor < fixed point, we move it to the fixed point and then move down normally
			//We set is_selecting afterwards in the function below anyways
			// cursor.cursor_is_selecting = false;
			if cursor.char_point < cursor.fixed_select_char_point {
				cursor.char_point = cursor.fixed_select_char_point;
				cursor.cursor_line_number = cursor.fixed_select_line_number;
				cursor.cursor_line_char = cursor.fixed_select_line_char;
			}
		} 

		CheckAndSetSelection(cursor, 
			IsKeyboardEvent(.ARROW_DOWN, .{shift_pressed=true}, .IS_DOWN_WITH_PAUSE, current_event));
		moved_cursor : bool = MoveCursorDown(file_string, cursor);
		// event_input_update = moved_cursor;
		//Better to update anyways for consistency and resilience
		event_input_update = true;
	}

	//TODO Can do go-to line with this same functionality.
	//TODO We don't use this action_type currently, so I can remove it if we don't need it.
	//WE JUST CALL MoveToLine where we need it. Having it here allows us to regulate how it
	//happens with other input but we use it for debugging for example to move when the debugging line moves.
	// if input.only_ctrl_down && input.g_button.down_this_frame {
	// for all_tc_data if it.action_type == TextCursorActionType.MOVE_TO_LINE {
	// 	MoveToLine(it.line_number, file_string.*, cursor);
	// 	//We prevent further updating to make sure the cursor and line are in the right place.
	// 	event_input_update = false;
	// }
	}

	/*TODO We could do this twice in this function, once after text_updating and then again here.
	It shoud accumulate the cursor_line_number and char_point regardless but maybe if there is something wrong
	we can update it twice per frame anyways. and then put the cursor_line_char update code in a function a reuse it before.
	*/
	if event_input_update {
		//TODO Should we move this into UpdateCursorLineCharAndBounds as well?
		//WE NOT UPDATE THIS IN UpdateCursorLineCharAndBounds which seems more consisten
		//TODO Should we just use this to update cursor_line_char everywhere?
		// line_start_char : int = LineStartCharPoint(cursor.char_point, file_string.*, single_line);
		//NOTE : This should not be used before this point since it gets updated here.
		//In any case, it should only be used for x_bounds and rendering.
		// cursor.cursor_line_char = cursor.char_point - line_start_char;

		//We update x and y bounds here depending on how the input beforehand.
		//This keeps text window movement consistent with all text input everywhere.
		//Y is not needed for singl_line.
		#if 1 {
		UpdateCursorLineCharAndBounds(cursor, file_string.*, single_line);
		} else {
		#if !single_line {
		//TODO Should we make this a function?
		if cursor.cursor_line_number > cursor.end_file_line_index {
			line_difference : int = cursor.cursor_line_number - cursor.end_file_line_index;
			//TODO We could check line bounds here but I think we don't because we check beforehand based on input.
			cursor.start_file_line_index += line_difference;
			cursor.end_file_line_index += line_difference;
			// op_2D_cam.world_pos.y -= line_difference*OP_SPACE_LINE_HEIGHT;
		} else if cursor.cursor_line_number < cursor.start_file_line_index {
			line_difference : int = cursor.start_file_line_index - cursor.cursor_line_number;
			cursor.start_file_line_index -= line_difference;
			cursor.end_file_line_index -= line_difference;
			// op_2D_cam.world_pos.y += line_difference*OP_SPACE_LINE_HEIGHT;
		}
		}

		//TODO FROM HERE Need to account for tabs here now
		#if 1 {
		//TODO We can make this a function and then reuse for cursor mouse holding
		//Should we make sure that the left char bound is always in line with an actual char?
		char_count_with_tab : int = CharCountUntilCursorWithTab(cursor.cursor_line_char, 
			cursor.cursor_line_number, file_string.*);
		if char_count_with_tab > cursor.right_char_bound {
			char_diff : int = char_count_with_tab - cursor.right_char_bound;
			cursor.right_char_bound += char_diff;
			cursor.left_char_bound += char_diff;
		} else if char_count_with_tab < cursor.left_char_bound {
			char_diff : int = cursor.left_char_bound - char_count_with_tab;
			cursor.right_char_bound -= char_diff;
			cursor.left_char_bound -= char_diff;
		}
		} else {
		if cursor.cursor_line_char > cursor.right_char_bound {
			// print("char_point=% > right_bound=%\n", cursor.cursor_line_char, cursor.right_char_bound);
			char_diff : int = cursor.cursor_line_char - cursor.right_char_bound;
			cursor.right_char_bound += char_diff;
			cursor.left_char_bound += char_diff;
			//NOTE : We do this externally so this function does not depend on a camera.
			// op_2D_cam.world_pos.x = cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;
		} else if cursor.cursor_line_char < cursor.left_char_bound {
			// print("char_point=% < left_bound=%\n", cursor.cursor_line_char, cursor.left_char_bound);
			char_diff : int = cursor.left_char_bound - cursor.cursor_line_char;
			cursor.right_char_bound -= char_diff;
			cursor.left_char_bound -= char_diff;
			// op_2D_cam.world_pos.x = text_file.file_tabs[text_op.ftab_i].tab_cursor.left_char_bound * perm.text_editor_data.code_font_1_char_width_world;
		}
		}
		if cursor.cursor_is_selecting && cursor.char_point == cursor.fixed_select_char_point {
			//Remove the selection if the cursor was brought back to the fixed selection.
			//Checking this here avoids any issues like missing a backspace or text input because
			//we still have that cursor is selected but the selection is 0 char width so nothing happens for 1 keypress.
			cursor.cursor_is_selecting = false;
		}
		}

		#if 0 {
		//Note : Add these 2 lines to input if we want to use the dynamic char width font.
		// my_font : *Dynamic_Font,
		// prepare_text_function : (*Dynamic_Font,string,Font_Effects) -> s64,
		string_to_cursor : string = file_string.text_string;
		string_to_cursor.data += line_start_char;
		string_to_cursor.count = cursor.cursor_line_char;
		//TODO If we need this, it should be a function in the renderer which returns the dynamic
		//width of a string based on the font_index instead of the actual font pointer
		width_to_cursor : s64 = ComputePixelWidthOfString(string_to_cursor, my_font, prepare_text_function);
		} else {
		// This is an optimization that could be used for the code editing since we know
		// the font width is always the same and we precomputed 1 character. 
		// Otherwise we would use dynamic font char width above.
		// cursor.cursor_diff_x = text_editor_data.code_font_1_char_width_world * cursor.cursor_line_char;
		// width_to_cursor : s64 = text_editor_data.code_font_1_char_width_pixel * cursor_line_index;
		}
		//TODO Can put this back if or just recompute TextEditorData if we change the font size
		// cursor.cursor_diff_x = (cast(float) width_to_cursor) / pixels_per_square;
	}

	// print("char_point=%\n", cursor.char_point);
	if event_text_update return_text_update = true;
	if event_input_update return_input_update = true;
}

return return_text_update, return_input_update;
}
LineStartCharPoint :: inline (char_point : int, file_string : FileString, $single_line : bool = false) -> int {
	#if single_line {
	return 0;
	} else {
	return LineStartCharPoint(char_point, file_string.text_string);
	}
}
LineStartCharPoint :: inline (char_point : int, text : string) -> int {
	// Cursor char_point is before the character. So we can have an index == text_string.count
	// We want to start from the previous char so that if we are at the end we don't check 
	// text_string[text_string.count] which is no longer part of the string since count starts from 0.
	previous_char_point : int = char_point - 1;
	//TODO replace this with find_index_from_right if it's ever optimized in String/module
	line_start_char : int = FindIndexFromRight(text, cast(u8) #char "\n", previous_char_point);
	//We want the char after the \n which is the start of the lines.
	//ALSO If line_start_char == -1 then we get 0 so no need for an extra if statement for that boundary case.
	line_start_char += 1;
	return line_start_char;	
}
LineEndCharPoint :: inline (cursor : TextCursor, file_string : FileString, $single_line : bool) -> int {
	#if single_line {
	return file_string.text_string.count;
	} else {
	return LineEndCharPoint(cursor.char_point, file_string.text_string);
	}
}
LineEndCharPoint :: inline (char_point : int, text : string) -> int {
	line_end_char : int = String.find_index_from_left(text, #char "\n", char_point);
	if line_end_char == -1 {
		//Cursor can be at end of file but there is no character there so that needs to be checked externally
		//to make sure we are not accessing the end of file text_string.count
		line_end_char = text.count; // In case we are on the last line so no '\n' after
	}
	return line_end_char;
}
GetTextLine :: inline (char_point : int, text : string) -> string {
	line_start : int = LineStartCharPoint(char_point, text);
	line_end : int = LineEndCharPoint(char_point, text);
	line_count : int = line_end - line_start;
	line : string = String.slice(text, line_start, line_count);
	return line;
}
CheckAndSetSelection :: inline (cursor : *TextCursor, is_selecting : bool) {
	//TODO FROM HERE Could pass in if selected externally extend of checking here I THINK THAT IS BETTER
	if is_selecting {
		if !cursor.cursor_is_selecting {
			//We set the values if we have not selected yet and we have shift down
			cursor.fixed_select_char_point = cursor.char_point;
			cursor.fixed_select_line_number = cursor.cursor_line_number;
			cursor.fixed_select_line_char = cursor.cursor_line_char;
			cursor.cursor_is_selecting = true;
		}
	} else { //if shift not down and we pressed a valid selection key (arrow keys)
		cursor.cursor_is_selecting = false;
	}		
}


/*We use this so we can move the cursor and do/add things to a text file without ControllerInput for example.
TODO I am not currently since I pulled out MoveToLine but we can use it if needed later for convenience.
*/
TextCursorActionType :: enum u8 {
	MOVE_TO_LINE;
}
TextCursorAction :: struct {
	action_type : TextCursorActionType;
	line_number : int;
}

//NOTE : This moves the camera(start/end line index bounds) and calls MoveCursor to a specific line.
/*DOC : IF we move the cursor then we always want to reset it to make sure it's in a good position
and there is no selection to have to check for where select_char_point == char_point.
If we don't move the cursor, then we assume the cursor is in a good place so we just move the line bounds
where we want to see. This may be useful later for something like moving to a breakpoint but likely
moving the cursor there is better in any case so move_cursor is just here as an idea convenience but not used yet.
*/
MoveToLine :: inline (
	line_number : int, 
	file_string : FileString,
	cursor : *TextCursor,
	$move_cursor : bool = true,
	$center_line : bool = true)
{
	//TODO I think this should be mandatory to avoid cursor selecting issues
	#if move_cursor ResetTextCursor(cursor);

	//TODO Should we adjust so that the new cursor_line_number is in between?
	line_bound_diff : int = cursor.end_file_line_index - cursor.start_file_line_index;
	// top_count : int = line_bound_diff / 2;
	// top_count : int = line_bound_diff;
	// bottom_count : int = line_bound_diff - top_count;
	// line_diff : int = line_number - cursor.cursor_line_number;
	// cursor.start_file_line_index = line_number;
	clamp_line_number := Clamp(0, line_number, file_string.file_loc.count-1);
	cursor.start_file_line_index = clamp_line_number;
	#if center_line {
		cursor.start_file_line_index -= line_bound_diff/2;
	} else {
		cursor.start_file_line_index -= line_bound_diff;
	}
	if cursor.start_file_line_index < 0 {
		cursor.start_file_line_index = 0;
	}

	cursor.end_file_line_index = cursor.start_file_line_index + line_bound_diff;
	//TODO Technically we might not have to do this since we check the file_loc.count max when rendering as well
	//ACTUALLY This forces the text to be on the bottom of the editor which feels more natural than having it appear in the middle for example
	//Removing this also seems to prevent issues with resizing and moving cursors where the bounds don't change.
	//Let's leave it like this for now and see if that fixes all the issues
	#if 0 {
	if cursor.end_file_line_index >= file_string.file_loc.count {
		cursor.end_file_line_index = file_string.file_loc.count-1;
		cursor.start_file_line_index = max(0, cursor.end_file_line_index - line_bound_diff);
	}		
	}

	#if move_cursor {
		char_bound_diff : int = cursor.right_char_bound - cursor.left_char_bound;
		cursor.left_char_bound = 0;
		cursor.right_char_bound = char_bound_diff;
		cursor.cursor_line_number = clamp_line_number;
		cursor.cursor_line_char = 0;
		cursor.char_point = StartCharPointOfLineNumber(cursor.cursor_line_number, file_string);
	}
}

#if 0 {
//TODO I tried pulling this out but it does not seem to work. Can seem to move up or down afterwards.
//Maybe it's because of MoveCursorDown and MoveCursorUp. Can we update those to use loc bytes like we
//did with MoveToLine. That would be more efficient if we could... not sure though if it would work consistently.
//TODO LOOK INTO THIS when we update the text editor so we can MoveCursorToLine whenever we want and still move around.
MoveCursorToLine :: inline (
	line_number : int, 
	file_string : FileString,
	cursor : *TextCursor)
{
	//TODO Could just use UpdateCursorLineCharAndBounds here and then
	//set cursor bounds to be in the middle of line bound diff if needed
	char_bound_diff : int = cursor.right_char_bound - cursor.left_char_bound;
	cursor.left_char_bound = 0;
	cursor.right_char_bound = char_bound_diff;

	cursor.cursor_line_number = line_number;
	//TODO We could allow for a specific cursor_line_char here
	//and then would have to check if < file_string.file_loc[line_number].count
	//but i think GoToLine makes more sense in general as consistent behavior.
	cursor.cursor_line_char = 0;

	//TODO Use StartCharPointOfLineNumber here
	//and then set cursor.char_point to that
	#if 1 {
	cursor.char_point = StartCharPointOfLineNumber(cursor.cursor_line_number, file_string);
	} else {
	//We check char_point out of bounds separately, otherwise there
	//could be pointer issues on the bottom with this pointer offset method.
	if cursor.cursor_line_number <= 0 {
		//DOC : We do <= to 0 here otherwise we go into the case below if theres only 1 line and then the char_point 
		//and cursor_line_char don't match up. As long as this functions always moves to the beggining of the line it's ok 
		//but if we have to move to a specific cursor_line_char like when we add mouse input, then we would need a different function for that.
		cursor.char_point = 0;
	} else if cursor.cursor_line_number >= file_string.file_loc.count-1 {
	// } else if cursor.cursor_line_number >= file_string.file_loc.count {
		cursor.char_point = file_string.text_string.count;
	} else {
		//NOTE : This works because file_loc points to same string as text_string so the new char_point is just
		//the offset from the first_char_point. Taking file_string.file_loc[0].data == file_string.text_string.data.
		new_char_point : *u8 = file_string.file_loc[cursor.cursor_line_number].data;
		first_char_point : *u8 = file_string.text_string.data;
		//Sanity check to make sure the pointer is within bounds of the string to avoid memory issues as well.
		assert(new_char_point >= first_char_point && new_char_point < first_char_point + file_string.text_string.count);
		char_address_diff : int = new_char_point - first_char_point;
		// cursor.char_point += char_address_diff;
		cursor.char_point = char_address_diff;
	}
	}
}
}
//TODO Reuse this in file above if we know it's working
StartCharPointOfLineNumber :: inline (line_number : int, file_string : FileString) -> int {
	assert(file_string.file_loc.count > 0); //sanity check

	result_char_point : int;
	//We check char_point out of bounds separately, otherwise there
	//could be pointer issues on the bottom with this pointer offset method.
	is_eof : bool = line_number >= file_string.file_loc.count 
		||
		//DOC : This is equivalent to checking if the last char is "\n" since then the last line is not associated to any string data
		//We only update file_loc in 1 place in UpdateFileStringAtCursor so it's fine to just check this way.
		(file_string.file_loc.count > 0 && line_number == file_string.file_loc.count-1 && 
		 peek(file_string.file_loc).data == null);
	// } else if line_number >= file_string.file_loc.count-1 {
	if is_eof {
		result_char_point = file_string.text_string.count;
	} else if line_number <= 0 {
		//DOC : We do <= to 0 here otherwise we go into the case below if theres only 1 line and then the char_point 
		//and cursor_line_char don't match up. As long as this functions always moves to the beggining of the line it's ok 
		//but if we have to move to a specific cursor_line_char like when we add mouse input, then we would need a different function for that.
		result_char_point = 0;
	} else {
		//NOTE : This works because file_loc points to same string as text_string so the new char_point is just
		//the offset from the first_char_point. Taking file_string.file_loc[0].data == file_string.text_string.data.
		//Sanity check since if we only have 1 line then we return 0 from case above so we need some text in this case to get char pointer diff
		assert(file_string.file_loc[line_number].data != null);
		new_char_point : *u8 = file_string.file_loc[line_number].data;
		first_char_point : *u8 = file_string.text_string.data;
		//Sanity check to make sure the pointer is within bounds of the string to avoid memory issues as well.
		assert(new_char_point >= first_char_point && new_char_point < first_char_point + file_string.text_string.count);
		char_address_diff : int = new_char_point - first_char_point;
		// cursor.char_point += char_address_diff;
		result_char_point = char_address_diff;
	}
	return result_char_point;
}
//TODO maybe we should return a false error instead of -1 to avoid issues
LineNumberOfCharPoint :: inline (char_point : int, file_loc : [] string) -> int {
	total_char : int;
	for loc, line_number : file_loc {
		total_char += loc.count + 1; //add 1 for the \n
		if char_point < total_char {
			return line_number;
		}
	}							
	//BETTER to assert here since a file should always have at least 1 line so this acts as a sanity check
	assert(file_loc.count > 0);
	if char_point >= total_char {
		return file_loc.count-1;
	}
	return -1;
}
//DOC : This is used to move cursor to char point and clears the selection.
//If we want to select text then currently we explicitly use the SelectText function
MoveCursorToCharPoint :: inline (
	char_point : int,
	cursor : *TextCursor,
	file_string : FileString,
	$single_line : bool = false,
	$center_line : bool = true,
	$reset_cursor : bool = false)
{
	//TODO Could make this an option BUT this deals with clearing the selection and reseting char bounds in case
	ResetTextCursor(cursor);

	cursor.char_point = char_point;
	cursor.char_point = Clamp(0, cursor.char_point, file_string.text_string.count);
	#if single_line {
	cursor.cursor_line_char = cursor.char_point;
	cursor.cursor_line_number = 0;
	} else {
	line_number : int = LineNumberOfCharPoint(cursor.char_point, file_string.file_loc);
	//TODO This way we don't error out... but maybe we should error out instead...
	if line_number == -1 {
		log_error("Char point % not valid for cursor % and file %.", char_point, cursor.*, file_string);
	}
	//NOTE : We do this in UpdateCursorLineCharAndBounds now so we only ever have to update char_point and line_number in general
	// line_start_char : int = StartCharPointOfLineNumber(line_number, file_string);
	// cursor.cursor_line_char = cursor.char_point - line_start_char;
	cursor.cursor_line_number = line_number;
	}
	//TODO Could put cursor is selecting false here if we want that as general behavior.
	//Otherwise we can put it outside of this function call on a per-case basis.
	UpdateCursorLineCharAndBounds(cursor, file_string, single_line, center_line);
}
/*DOC : This is being used to update the cursor even if we udpate the text file
for example, if we have the same text file in multiple different text op spaces
SO we need to check bounds for both cursor and selection in case that changed

Using this function with the current cursor values does a keep cursor in bounds
functionality such that whether selecting or not, the cursor and selection is still valid
and as close as possible to the previous line and line char if we updated the text file either
in another op space or externally. 
TODO We could make a separate KeepCursorInBounds function to reuse once this is tested to make that
clearer or just use this function with the cursor values passed in to see clearly what we are doing.
In that case we keep all compile-time values as false so that we don't update the bounds for mouse input
afterwards. So if we move the cursor in choosing and then the mouse selects a position, we still see where
the cursor actually is, so the mouse input will be accurate.

When we choose an op space, we bring it to the top and 
if its a text op space we also set the cursor to current line and char, so that if we edited the text file
then the cursor will still be valid. We do the same thing when switching tabs.

*/
MoveCursorToLineAndLineChar :: inline (
	line_number : int,
	line_char : int,
	cursor : *TextCursor,
	file_string : FileString,
	$single_line : bool = false,
	$center_line : bool = false,
	$reset_cursor : bool = false,
	$update_bounds : bool = false)
{
	//We don't want to reset bounds here in case we moved over then we can just stay there
	//otherwise we will update them below anyways if needed
	#if reset_cursor ResetTextCursor(cursor, reset_bounds=false);

	#if single_line {
	cursor.char_point = Clamp(0, line_char, file_string.text_string.count);
	cursor.cursor_line_char = cursor.char_point;
	if cursor.cursor_is_selecting {
		cursor.fixed_select_char_point = Clamp(0, cursor.fixed_select_line_char, file_string.text_string.count);
		cursor.fixed_select_line_char = cursor.fixed_select_char_point;
	}
	} else {
	//TODO This seems to only be for the test text file which I don't really like in general
	//OK so leaving this here just in case for the test text file
	assert(file_string.file_loc.count > 0);
	clamp_line_number : int = Clamp(0, line_number, file_string.file_loc.count-1);
	//If we have an empty file then this will have count == 0 but the data will be null which is ok since we are not checking the data pointer
	loc : string = file_string.file_loc[clamp_line_number];
	//We can be on the last line character since that is the cursor on the end of the line
	clamp_line_char : int = Clamp(0, line_char, loc.count);

	cursor.cursor_line_number = clamp_line_number;
	cursor.cursor_line_char = clamp_line_char;
	start_line_char_point : int = StartCharPointOfLineNumber(cursor.cursor_line_number, file_string);
	cursor.char_point = start_line_char_point + clamp_line_char;

	if cursor.cursor_is_selecting {
		clamp_fixed_line_number : int = Clamp(0, cursor.fixed_select_line_number, file_string.file_loc.count-1);
		//If we have an empty file then this will have count == 0 but the data will be null which is ok since we are not checking the data pointer
		fixed_loc : string = file_string.file_loc[clamp_fixed_line_number];
		//We can be on the last line character since that is the cursor on the end of the line
		clamp_fixed_line_char : int = Clamp(0, cursor.fixed_select_line_char, fixed_loc.count);

		cursor.fixed_select_line_number = clamp_fixed_line_number;
		cursor.fixed_select_line_char = clamp_fixed_line_char;
		fixed_start_line_char_point : int = StartCharPointOfLineNumber(cursor.fixed_select_line_number, file_string);
		cursor.fixed_select_char_point = fixed_start_line_char_point + clamp_fixed_line_char;
	}
	}

	//Maybe we should just leave this out and then update it as needed externally
	#if update_bounds {
	UpdateCursorLineCharAndBounds(cursor, file_string, single_line, center_line);
	} else {
	//DOC : In case we don't do update_bounds, then we check this here to avoid issues with not being able to move cursor 
	if cursor.cursor_is_selecting && cursor.fixed_select_char_point == cursor.char_point {
		cursor.cursor_is_selecting = false;
	}
	}
}
/*DOC : start_char_point is the fixed select point
and the cursor goes to end_char_point
*/
//TODO FROM HERE test this and also MoveToLine and start line char point function
SelectText :: inline (
	start_char_point : int, //this is where fixed select point starts
	end_char_point : int, //this is where the cursor goes
	cursor : *TextCursor,
	file_string : FileString,
	$single_line : bool = false,
	$center_line : bool = true,
	$reset_cursor : bool = true) 
{
	if file_string.text_string.count == 0 return;

	clamp_start_char_point : int = Clamp(0, start_char_point, file_string.text_string.count);
	clamp_end_char_point : int = Clamp(0, end_char_point, file_string.text_string.count);
	//DOC : This way we don't select anything they are equal or start > end
	if clamp_start_char_point >= clamp_end_char_point return;

	//DOC : We already reset the cursor in here and update cursor line char bounds in here then do the select below
	//We check that clamp_start_char_point >= clamp_end_char_point above and return if so to avoid selection issues
	MoveCursorToCharPoint(clamp_end_char_point, cursor, file_string, single_line, center_line, reset_cursor=false);

	//DOC : We check above that clamp_start_char_point != clamp_end_char_point and then return so we don't have to unselect for that
	cursor.cursor_is_selecting = true;
	cursor.fixed_select_char_point = clamp_start_char_point;
	#if single_line {
	cursor.fixed_select_line_char = cursor.fixed_select_char_point;
	cursor.fixed_select_line_number = 0;
	} else {
	fixed_line_number : int = LineNumberOfCharPoint(clamp_start_char_point, file_string.file_loc);
	fixed_line_start_char : int = StartCharPointOfLineNumber(fixed_line_number, file_string);
	cursor.fixed_select_line_char = clamp_start_char_point - fixed_line_start_char;
	cursor.fixed_select_line_number = fixed_line_number;
	}

	//NOTE : We already do this in MoveCursorToCharPoint
	// #if reset_cursor UpdateCursorLineCharAndBounds(cursor, file_string, single_line, center_line);
	UnselectCursorWithSameFixedCharPoint(cursor);
}
CopySelectedTextToFindBar :: inline (
	text_op : *TextOpSpaceData,
	tab_cursor : TextCursor,
	file_string : FileString,
	ted : TextEditorData,
	game_input : GameInput)
{
	selected_text : string = GetSelectedText(tab_cursor, file_string);
	//If we did not find a newline, then we copy the selected text to the find bar
	//TODO SETTING multiline_selection_to_find_bar = false by default
	//Need to set it = true in the test for find and replace bar
	/*	
	if !multiline_selection_to_find_bar {
		found_newline : int = String.find_index_from_left(selected_text, "\n");
		if found_newline == -1 return;
	}
	*/
	fie : [1] FrameInputEvent;
	SetTextBlock(selected_text, *fie[0]);
	SelectText(0, text_op.first_bar_input_text.text_string.count, *text_op.first_bar_cursor, text_op.first_bar_input_text, 
		single_line=true);
	//We select text before updating to remove the old one and add the new one
 	updated_text := UpdateFileStringAtCursor(*text_op.first_bar_input_text, *text_op.first_bar_cursor,
		fie, game_input, ted, single_line=true);
	assert(updated_text);
	//We select text after since that allows easy removal of the text if needed
	SelectText(0, text_op.first_bar_input_text.text_string.count, *text_op.first_bar_cursor, text_op.first_bar_input_text,
		single_line=true);
}
SetCursorWithCurrentBounds :: inline (
	current_cursor : *TextCursor,
	new_cursor : TextCursor)
{
	current_line_diff : int = current_cursor.end_file_line_index - current_cursor.start_file_line_index;
	old_line_diff : int = new_cursor.end_file_line_index - new_cursor.start_file_line_index;
	current_char_diff : int = current_cursor.right_char_bound - current_cursor.left_char_bound;
	old_char_diff : int = new_cursor.right_char_bound - new_cursor.left_char_bound;

	current_cursor.* = new_cursor;

	if old_line_diff != current_line_diff {
		current_cursor.end_file_line_index = current_cursor.start_file_line_index + current_line_diff;
	}
	if old_char_diff != current_char_diff {
		current_cursor.right_char_bound = current_cursor.left_char_bound + current_char_diff;
	}
}
GetSelectedText :: inline (
	cursor : TextCursor,
	file_string : FileString) 
-> string 
{
	//sanity check - these should not be the same from updating the string in any case
	assert(cursor.char_point != cursor.fixed_select_char_point); 
	start_char_point : int = min(cursor.char_point, cursor.fixed_select_char_point);
	end_char_point : int = max(cursor.char_point, cursor.fixed_select_char_point);
	selected_text : string; 
	selected_text.data = file_string.text_string.data + start_char_point;
	selected_text.count = end_char_point - start_char_point;
	return selected_text;
}

//TODO Test this function thoroughly with and without UpdateFileStringAtCursor
//Should be easier now since we separated this out.
//TODO Can likely simplify these now with file_loc since we would have separated the lines sequentially
//in UpdateFileStringAtCursor and so the file_loc would be correct and we could remove the find index functions
//but its probably fine especially the simd find index from left.
MoveCursorUp :: inline (
	file_string : *FileString,
	cursor : *TextCursor)
-> moved_cursor : bool
{
	previous_char_point : s64 = cursor.char_point - 1;
	previous_new_line_index : int = 
		FindIndexFromRight(file_string.text_string, cast(u8) #char "\n", previous_char_point);
	found_previous_line : bool = previous_new_line_index != -1;
	if found_previous_line {
		// Line relative char index
		line_start : int = previous_new_line_index + 1;
		line_relative_index : int = cursor.char_point - line_start;

		// Previous line relative char index
		//Note : Start and end mean without the new line so \nTEST\n -> first T is start and last T is end
		previous_line_end : int = previous_new_line_index - 1;
		previous_line_start : int = FindIndexFromRight(file_string.text_string, cast(u8) #char "\n", previous_line_end);
		if previous_line_start == -1 {
			previous_line_start = 0; // In case we are on the first line so no '\n' before
		} else {
			previous_line_start += 1;
		}
		previous_line_length : int = previous_line_end - previous_line_start + 1;
		previous_line_char_point : int = previous_line_start + line_relative_index;

		if line_relative_index > previous_line_length {
			cursor.char_point = previous_new_line_index;
		} else {
			cursor.char_point = previous_line_char_point;
		}
		cursor.cursor_line_number -= 1;
		return true;
	}
	return false;
}

//TODO Test this function thoroughly with and without UpdateFileStringAtCursor
//Should be easier now since we separated this out.
MoveCursorDown :: inline (
	file_string : *FileString,
	cursor : *TextCursor)
-> moved_cursor : bool
{
	next_new_line_index : int = 
		String.find_index_from_left(file_string.text_string, cast(u8) #char "\n", cursor.char_point);
	found_next_line : bool = next_new_line_index != -1;
	if found_next_line {
		// Find line relative char index
		previous_char_point : s64 = cursor.char_point - 1;			
		previous_new_line_index : int = 
				FindIndexFromRight(file_string.text_string, cast(u8) #char "\n", previous_char_point);
		if previous_new_line_index == -1 previous_new_line_index = 0;

		line_start : int = previous_new_line_index + 1;
		if previous_new_line_index == 0 line_start = 0;
		line_relative_index : int = cursor.char_point - line_start;

		// Find next line relative char index
		//Note : Start and end mean without the new line so \nTEST\n -> first T is start and last T is end
		next_line_start : int = next_new_line_index + 1;
		next_line_end : int = String.find_index_from_left(file_string.text_string, cast(u8) #char "\n", next_line_start);
		if next_line_end == -1 {
			next_line_end = file_string.text_string.count; // In case we are on the last line so no '\n' after
		}
		next_line_end -= 1;
		next_line_length : int = next_line_end - next_line_start + 1;
		next_line_char_point : int = next_line_start + line_relative_index;

		if line_relative_index > next_line_length {
			cursor.char_point = next_line_end + 1;
		} else {
			cursor.char_point = next_line_char_point;
		}
		cursor.cursor_line_number += 1;
		return true;
	}
	return false;
}
/*DOC : This allows us to scroll text bounds and remain within the limits.
TODO Rename to MouseScrollTextBounds
*/
MouseScrollTextBounds :: inline (
	start_line_ptr : *int,
	end_line_ptr : *int,
	upper_limit : int,
	mouse_wheel : int) 
{
	line_bound_diff : int = end_line_ptr.* - start_line_ptr.*;
	if mouse_wheel > 0 && start_line_ptr.* > 0 {
		start_line_ptr.* -= mouse_wheel;
		if start_line_ptr.* < 0 {
			start_line_ptr.* = 0;
		}
		end_line_ptr.* = start_line_ptr.* + line_bound_diff;
	}
	//NOTE : if end_line_ptr > upper_limit, then we don't want to move since it means
	//what our bounds are larger than the number of lines available in total.
	else if mouse_wheel < 0 && end_line_ptr.* < upper_limit {
		end_line_ptr.* -= mouse_wheel;
		if end_line_ptr.* >= upper_limit {
			end_line_ptr.* = upper_limit-1;
		}
		start_line_ptr.* = end_line_ptr.* - line_bound_diff;
	}
}
MouseSingleLineCharPoint :: inline (
	op_mouse : Vector2F,
	min_x : float,
	text_string : string,
	cursor : TextCursor,
	char_width_world : float)
-> int
{
	//TODO We could return this x_diff if needed i guess...
	mouse_x_diff : float = op_mouse.x - min_x;
	mouse_char_float_x_diff : float = mouse_x_diff / char_width_world;
	mouse_char_point : int = round_to_int(mouse_char_float_x_diff) + cursor.left_char_bound;
	if mouse_char_point < 0 {
		mouse_char_point = 0;
	} else if mouse_char_point > text_string.count {
		mouse_char_point = text_string.count;
	}
	return mouse_char_point;
}
/*DOC : Here we update the given bounds if the highlighted index
is outside of the given start and end bounds.
This assumes that the given highlighted index is within
the total bounds since we just adjust the bound indices.
BUT rendering deals with limits in case we are beyond limits.
*/
AdjustTextBoundsToIndex :: inline (
	highlighted_index : int,
	start_bound_ptr : *int,
	end_bound_ptr : *int) 
{
	if highlighted_index < start_bound_ptr.* {
		index_diff : int = start_bound_ptr.* - highlighted_index;
		start_bound_ptr.* -= index_diff;
		end_bound_ptr.* -= index_diff;
	} else if highlighted_index > end_bound_ptr.* {
		index_diff : int = highlighted_index - end_bound_ptr.*;
		start_bound_ptr.* += index_diff;
		end_bound_ptr.* += index_diff;
	}
}
/*DOC : We update cursor.cursor_line_char in here now which feels better overall since it keeps the line char calculation
consistent whenever we move the chars instead of relying on it externally.
ALSO this means we only ever need to update the char_point and line_number (for multi-line) anywhere and then we just
call this function to update everything else which makes the most sense from a programmer standpoint.

REMINDER : we can remove mouse_line_char from CheckCursorMouseHolding if this is working since we just compute it here anyways
for both the single and multi line cases.
*/
//TODO Should we rename this to UpdateTextCursor since we seem to be doing other things than updating the boudns anyways?
//Like preventing selection if char_point == fixed_select_char_point and also maybe updaing cursor_line_char eventually?
UpdateCursorLineCharAndBounds :: inline (
	cursor : *TextCursor, 
	file_string : FileString,
	$single_line : bool = false,
	$center_line : bool = false) 
{
	line_start_char : int = LineStartCharPoint(cursor.char_point, file_string, single_line);
	//NOTE : This should not be used before this point since it gets updated here.
	//In any case, it should only be used for x_bounds and rendering.
	cursor.cursor_line_char = cursor.char_point - line_start_char;

	//I think this way is clearer than the the old version in dead code since we clearly maintain the line bound diff in both cases.
	//I think it is arithmetically equivalent to the above anyways.
	#if !single_line {
	line_bound_diff : int = cursor.end_file_line_index - cursor.start_file_line_index;
	if cursor.cursor_line_number < cursor.start_file_line_index {
		cursor.start_file_line_index = cursor.cursor_line_number;
		cursor.end_file_line_index = cursor.start_file_line_index + line_bound_diff;
	} else if cursor.cursor_line_number > cursor.end_file_line_index {
		cursor.end_file_line_index = cursor.cursor_line_number;
		cursor.start_file_line_index = cursor.end_file_line_index - line_bound_diff;
	}
	#if center_line {
	if cursor.cursor_line_number == cursor.start_file_line_index {
		cursor.start_file_line_index -= line_bound_diff/2;
	} else if cursor.cursor_line_number == cursor.end_file_line_index {
		cursor.start_file_line_index += line_bound_diff/2; 
	}
	if cursor.start_file_line_index < 0 {
		cursor.start_file_line_index = 0;
	}
	cursor.end_file_line_index = cursor.start_file_line_index + line_bound_diff; 
	} else {
	//I dont think this happens since the cursor_line_number is clamped but just a sanity check in case.
	if cursor.start_file_line_index < 0 {
		cursor.start_file_line_index = 0;
		cursor.end_file_line_index = cursor.start_file_line_index + line_bound_diff; 
	}
	}
	//TODO Should we make sure that the left char bound is always in line with an actual char?
	//TODO We assume cursor_line_number is valid here but we could clamp it in this function.
	//I will leave it as is for now to see if there are bugs in the line checking code in general.
	total_char_count : int = CharCountUntilCursorWithTab(cursor.cursor_line_char, 
		cursor.cursor_line_number, file_string);
	} else {
	//If we have single line then all characters are single width only
	total_char_count : int = cursor.cursor_line_char;
	}

	if total_char_count > cursor.right_char_bound {
		char_diff : int = total_char_count - cursor.right_char_bound;
		cursor.right_char_bound += char_diff;
		cursor.left_char_bound += char_diff;
	} else if total_char_count < cursor.left_char_bound {
		char_diff : int = cursor.left_char_bound - total_char_count;
		cursor.right_char_bound -= char_diff;
		cursor.left_char_bound -= char_diff;
	}

	UnselectCursorWithSameFixedCharPoint(cursor);
}
UnselectCursorWithSameFixedCharPoint :: inline (cursor : *TextCursor) {
	if cursor.cursor_is_selecting && cursor.char_point == cursor.fixed_select_char_point {
		//Remove the selection if the cursor was brought back to the fixed selection.
		//Checking this here avoids any issues like missing a backspace or text input because
		//we still have that cursor is selected but the selection is 0 char width so nothing happens for 1 keypress.
		cursor.cursor_is_selecting = false;
	}	
}

EqualsChosenEntity :: inline (
	c1 : ChosenEntity, c2 : ChosenEntity) 
-> bool
{
	result : bool = c1.id == c2.id &&
					c1.entity_type == c2.entity_type;
	return result;
}

//TODO SETTINGS auto_save should be done here
ResetToUnselectedState :: inline (ad : *AllData) {
	AutoSaveChosenTextOpTab(ad);
	// base_cam : Camera2D = GetDefaultBaseCam2D(ad.all_2D_cams);
	// ad.active_cam_id = base_cam.id;
	array_reset_keeping_memory(*ad.all_chosen_entities);
	// ad.input_check.is_writing_code = false;
	ad.reset_to_unselected_state = false;
}

Persist :: struct {
	//TODO where should we put this?
	//TODO can we just remove this now?
	draw_buffer : RenderBuffer;

	//TODO should this work with text input instead of type
	//eg "test level1" vs "load level1" vs "update level1"
	text_command_type : TextCommandType;
	text_command_string : FileString;
	text_command_cursor : TextCursor;

	//TODO Should we put this in AllData now or still leave here to persist the commands we run through all modes
	using terminal_data : TerminalData;

	//Will need to have multiple of these for multiple text editors
	//TODO Should likely have this in the text op space data eventually say it can be set for each op space
	//can set things like color and font size and undo split for each text op space separately
	//AND THEN we can replace the default settings with the runtime settings file
	text_editor_data : TextEditorData;
	
	game_mode : GameMode;

	test_data : TestData;

	// locked_sound_data : LockedSoundData;

	all_data : *AllData;
	//TODO separate different datas here
	//saveable data, ui data, transient level data, etc...
}

/*TODO
	need to separate transient level data from saveable level data
	possible also separate data that changes between levels
*/
//TODO i believe this can be done with metaprogramming for all space types
//TODO could test out metaprogramming with this but then not use because it would be hard to read and debug for now
//TODO lets create some better metaprogramming analysis tools!
//TODO one selected array for each dspace type?
//TODO Cleanup AllData since the compiler complained
//so for now we put #type_info_no_size_complaint since we need the type_info in InitAllData
//but most of the data in here is no longer being used
AllData :: struct #type_info_no_size_complaint {
	/*TODO We are storing this here for convenience. Right now AllData is being used
	in general, but eventually we want to separate the data model better to account
	for being able to change between music spaces.
	If we can remove some later or pass them into the functions that need them, I think that might be better but let's see.
	*/
	// renderer_data : *RendererData;
	// audio_data : *AudioData;
	// game_input : *GameInput;
	shared_lib_data : SharedLibraryData;

	global_rules : GlobalRules;
	//TODO Should this be in AllCodeData since we reset
	//it every time we run some code.
	audio_timing : AudioTiming;
	last_play_pos_x : float;

	//This is only used for tests right now
	input_mappings_file_path : string = INPUT_MAPPINGS_REL_PATH;
	runtime_settings_file_path : string = RUNTIME_SETTINGS_REL_PATH;
	runtime_settings : RuntimeSettingsData;

	//TODO Seems like we don't need these but I can leave them here
	//in case we need them later.
	// extern_pool : Flat_Pool;
	// extern_alloc : Allocator;
	//DOC : This is used to share data across all dls being used externally
	my_shared_data : *void;

	/*TODO This should be associated to internal synths
	so we can adjust the parameters. For now, we just 
	have them here to generate for ease. Also in general
	will likely use midi data HOWEVER this is necessary
	for alternative tuning systems because midi does not
	easily support that and neither do any DAWs.
	*/
	all_osc_waves : [..] OscWave;

	all_next_ids : AllNextIds;

	all_terminal_events : [..] TerminalEvent;
	//These will be loaded into all_terminal_events
	//next frame so we can process a loaded level
	//before opening op_spaces for example.
	//TODO Not sure this is being used anymore, even for tests...
	next_frame_terminal_events : [..] TerminalEvent;

	//TODO Should we pull text files out of all_data?
	//Maybe only decide once we store files on disk drive.
	/* Right now all_text_files are used to store
	all code files currently available. We can default
	that all_text_files[0] is the starting main file.
	*/
	/*TODO All text file strings should be stored
	somewhere and then that should be cleared on level
	load. Maybe all string should be stored somewhere
	and then cleared on level load (probably custom allocator).
	Right now they are lost in oblivion.

	Could use a pool in that case since we will reset it
	on any level reset.
	*/
	all_text_files : [..] TextFile;

	reset_to_unselected_state : bool;

	/*TODO We need an even higher layer so we can duplicate most of AllData
	so we can multiple row spaces that all have different op_spaces. Although we then could allow
	veiwing op spaces between these higher level spaces for convenience or not... Not sure.
	But this would be necessary later so that we can have infinitely long pieces.
	*/
	//Note : All data that can be reset when we
	//need to reset the data generated from the code.
	//This should be a parameter in AllLevelData
	//once we separate level_data from all_data.
	// using all_code_data : *AllCodeData;
	//TODO We can use an allocator for each mspace if that helps but maybe we want 
	//We would need to use a pool since we want it to be of arbitrary size.
	// mspace_alloc : Allocator; 
	// mspace_pool : Pool;

	/*3D Data
		TODO can move this closer to chord_s2 once more fleshed out
	*/
	all_render_music_pt_3D : [..] RenderMusicPt3D;
	//TODO update to vl_line_segments in 3D eventualy
	all_grid_edges_3D : [..] GridEdge3D;

	//TODO Change name to all_chord_space_points since we
	//will use another array for regular axes space
	all_space_points_3D : [..] SpacePoint3D;
	all_chord_space_points : [..] ChordSpacePoints3D;
	// cam_test : Camera2D;
	/*
	*/

	/*TODO only one for now what if we want more than one?
		will we ever want more than one chosen dspace?
		TODO if we want more then we would have a sorted array here 
		to choose from instead

		also these seem like more of a transient data thing
		but transient over the course of a level
		could separate level transient data from start level data
		for easier level storing and serialization
	*/
	//MusicPt : this is an FSM where we have chosen and hover states
	//except hover is per frame and chosen persists into next frames
	// chosen_entity : ChosenEntity;
	all_chosen_entities : [..] ChosenEntity;


	//New Collision Data
	//TODO Can likely remove everything above this and just use this
	//and then optimize later based on shapes if needed.
	all_op_collision_entities : [..] CollisionEntity;
	//TODO Could have a different struct for this without the
	//op_space_id and maybe just rect if that's the only shape in the base.
	// all_base_collision_entities : [..] CollisionEntity;


	//TODO could make these structs if needed
	all_audio_events : [..] AudioEvent;
	game_audio_play : GameAudioPlay;
	set_audio_position_data : SetAudioPositionData;
	//TODO This is not a very efficient model for 
	//the wave synthesis but it is consistent and solid
	//for now until we understand it better.
	//Ie reusing osc_wave volume_envolope per lane
	all_playing_music_pt_and_waves : [..] MusicPointAndOscWave;

	/*Note : This are placed here in case we recompile
	and we still want the notes to keep playing or stop.

	all_playing_midi and all_playing_music_pt_and_waves
	need to be able to end even if we recompile code. So we set
	them here and they get reset.
	TODO So if we update the level, these all need to get cleared
	since internal synth will just stop but all_playing_midi
	will never send the note_off message.
	If we are playing on a separate thread, then it doesn't
	matter since the notes will end when they end or we can
	trigger a stop on level change.
	*/
	//TODO should rename this to all_playing_midi_music_pts or all_playing_external_music_pts or something like that.
	all_playing_midi : [..] PlayingMidi;
	// all_playing_music_pts : [..] MusicPoint;

	//TODO REMOVE THIS AND ITS USAGE EVERYWHERE ONCE WE KNOW ITS OK
	// input_check : InputCheck;

	all_compile_code_events : [..] CompileCodeEvent;
	/*TODO Could allow multiple sets of these so each text file
	can have its own music/data instructions to execute
	*/
	/*TODO we only allow 1 event in here and then use the count to check
	if we are currently executing something this frame. Should we leave it this
	way or just set 1 struct here with a bool to check?
	Leaving an array allows us to catch issues with multiple processes running
	which is the main reason to keep it for now.
	*/
	all_process_instruction_events : [..] ProcessInstructionEvent;
	//TODO Will likely need to have 1 of these for each file
	//especially if we can run things concurrently, then well
	//have multiple cpu_states, although having 1 for each
	//is likely fine anyways so we can compile > 1 thing at once.
	//TODO We don't need this anymore since we have comp_data
	//I will reference that array for now but really we don't need it anymore.
	all_music_instructions : [..] MusicInstruction;
	exec_info : ExecutionInfo;

	//TODO Will need multiple of these eventually for each compiled file.
	//Can have an allocator for each OR just reuse the same allocator
	//if we don't allow multiple compilations at once for example.
	comp_pool : Flat_Pool;
	//TODO We can make this before compiling instead of storing it here unless the comp_pool can be changed
	comp_alloc : Allocator;
	//TODO We should create an array of these and treat them like 
	//debugging EXEs. Then we can store a name and by default it would be
	//the file_name for text_op. Otherwise it can be called specifically by another name.
	//When we update this then we can specify text_file_id in EvaluateWatchData and 
	//anything else for watch window or other text_file specific debugging
	//Can likely have 1 alloc per comp_data then, maybe even store it in CompilationData
	//so then if we recompile something with the same name, we can just reset and redo it.
	//OR we can also use a free list and if we recompile then we free/reuse it with the same allocator.
	comp_data : *CompilationData;
	//TODO should remove this cpu_state entirely
	cpu_state : CPUState;

	//OpSpace
	all_open_op_spaces : [..] OperationSpace;
	all_closed_op_spaces : [..] OperationSpace;
	all_resizing_op_space : [..] ResizeOpSpace;
	//DOC : We use this so we can move multiple op spaces at once later
	//if we allow attaching op spaces to each other and also this makes it
	//easy to check if we are currently moving any op space to prevent
	//any unwanted mouse hovering behavior.
	all_moving_op_spaces : [..] MovingOpSpace;

	//TODO Eventually we could have 2d and 3d free render groups and remove the 3d scissor group for 2d
	//and then use them in tandem with the 2d and 3d updated renderer data.
	//TODO We can likely remove this if we put it in the RendererData as
	//something like this instead of just flat render groups which
	//would greatly simplify sorting as well.
	// free_op_space_render_groups : [..] OpSpaceRenderGroups;

	all_op_space_spec_data : [..] OpSpaceSpecData;
	all_op_spec_data_3D : [..] OpSpecData3D;

	all_text_op_space_data : [..] TextOpSpaceData;

	all_terminal_op_space_data : [..] TerminalOpSpaceData;

	/*TODO do we need this?
		how else would we know that the dspace ops are grouped for rendering.
		otherwise we would have to check that the primary music_pt_set is attached
		to a dspace in the base space and that dspace is attached to a dspace_set
	*/
	//TODO should these be viewable or is clustering them together
	//enough of a symbol to show that it is a DSpaceSet
	all_dspace_to_op_space : [..] DSpaceToOpSpace;

	//TODO Could collapse this with MemoryUnitToDSpace. Keeping separate for now since chord spaces
	//are processed very differently from the other dspaces. With space_points and vl_points.
	//TODO RENAME THIS TO all_vl_mem_to_chord_space or something
	//like that since this for voice leadings.
	all_memory_unit_to_chord_space : [..] MemoryUnitToChordSpace;


	/* OLD All Code Data
	Some of these arrays can be pre-allocated since we know things
	like # of rows and lanes during compilation. Then those arrays
	don't need to be dynamic, they can just be pre-allocated arrays
	although then this would conflict with code levels which would be
	more robust. But we could still pre-allocate the dynamic array
	so no new allocations are needed and then use a Pool allocator
	more efficiently.

	I think we can separate this data between OpSpaceData which is specific to op_space
	and then MusicSpaceData which is specific to each MusicSpace.
	Then MusicSpaces can communicate through code and by copying over rows.
	Through code because text files are stored in the OS so they can move between
	one MusicSpace easily by opening by name.

	This should be associated to 1 executable so that we can have each
	one running as desired whenever we want and still keep data after.
	this would also help with music spaces. Can think about it then
	since music rows are shared.
	*/

	//TODO Use this to select which mspace we are currently on.
	//Can likely make a function to ensure that index exists before accessing the all mspace array.
	//TODO We can put this all in 1 object that helps eventually
	/*DOC : The mspaces play in sequence based on this array. So if we want to change the order of the audio,
	then we want to update the the order of this mspace array. It acts as a circular array when playing in general
	and moves to the next mspace in the array. We can mute mspace by making the audio row size = 0;
	The idea here is that we can loop on any mspace by muting all the other mspaces and then it will
	skip over all of them. This allows 1 method with lots of flexibility for what we loop over and then
	we can rearrange mspace or rows or music points individually to go over or loop over different areas.
	FOR EXAMPLE if we want to check a specific section, then we can just copy that over to a new mspace and
	then mute every other mspace and just have that 1 mspace loop naturally.
	*/
	audio_mspace_id : int;
	render_mspace_id : int;
	all_mspace_data : [..] MusicSpaceData;
	free_mspace_data_pool : [..] MusicSpaceData;
	//TODO Can store all unused mspaces (maybe including tano stack mspace data) for reuse later
	//since we will likely be making and recreating.
	// free_mspace_data : [..] *MusicSpaceData;

	//Music Points
	all_start_playing_music_pts : [..] MusicPoint;
	//NOTE TODO : We are just using a separate array here for now BUT
	//this is simulating a musical space and when we implement music spaces
	//then we should just use another music space for the tano stack music points.
	//TODO I Think we can just use negative mspace_index for tano since we can't
	//access those in the array anyways and then have a separate tano_stack_mspace_data
	//array where we take the absolute value of the given mspace_index - 1 and grab by index like that.
	//so tano_stack_mspace_data[abs(mspace_index) - 1] and use the separate array so it does not 
	//interfere with user mspaces and then we can also have a way of seeing them in real time if needed
	//later where we can have a command that moves to a particular tano stack mspace (or negative mspace)
	// tano_stack_mspace_data : [..] *MusicSpaceData;
	tano_stack_music_pts : [..] MusicPoint;


	//TODO Gradually move this out for mspaces and op_spaces
	// Tuning System data
	all_tuning_systems : [..] TuningSystem;
	all_tuning_pitches : [..] TuningPitch;
	all_linear_to_tuning_system : [..] LinearToTuningSystem;

	//Register Data
	//TODO We could store an array of the names here to see them
	//since they are computed as compile-time constants right now
	all_register_memory : [..] MemoryValue;

	//TODO Should this be a FlatPool or a [..] u8?
	//Flat_Pool allows contiguous memory on get in virtual os memory without
	//changing the memory_base. A [..] resize would move the memory_base.
	//Flat_Pool is also a fresh chunk of memory and does not use the default memory allocator.
	ram_memory : RAMMemory;

	//Linear Space Data
	//TODO should this just be a tile grid on the whole world map?
	//TODO should points be directly associated to DSpaces due to the inherent geometrical advantages of each space?
	all_space_points : [..] SpacePoint;
	//TODO maybe change to smaller type for log ratio points since we only need the different mesh?
	all_log_ratio_points : [..] SpacePoint;
	/*TODO should we have all_linear_base_spaces
	as a separate array from all_linear_op_spaces
	*/
	//TODO Convert these to use generic data table model indexed by id
	all_linear_pitch_spaces : [..] LinearPitchSpace;
	//TODO should we have a base_linear_pitch_spaces?

	//TODO I am not sure I want this anymore. I think having everything in memory is simpler and more consistent.
	//If we want arrays off, we can have rows that are muted or allow negative rows that are automatically not visible.
	all_extra_circle_points : [..] CirclePoint;

	//TODO Rename this to all_circle_spaces
	all_new_circle_spaces : [..] CircleSpace;

	//TODO I think putting these all in 1 struct would make it easier to pass them around in general.
	//In case we decide to add more shapes or change shapes in a given function, or if we add more SpaceObjects
	using all_space_shapes : AllSpaceShapes;
	//TODO Having an array here would allow us to naturally index by op_space_id
	//which seems to be the natural way to index and organize these shapes anyways.
	//all_space_shapes : [..] AllSpaceShapes;

	//TODO I think we can just have this one to associate memory to dspace for visual convenience
	//Or also if the player wants to use them
	all_memory_range_to_dspace : [..] MemoryRangeToDSpace;

	all_memory_unit_to_dspace : [..] MemoryUnitToDSpace;
	all_dspace_to_op_space_id : [..] DSpaceToOpSpaceIndex;

	all_op_linear_data : [..] OpLinearData;

	//TODO Eventually I think we can have a different struct if needed
	//since the op rows will likely be different from the base rows.
	all_op_linear_rows : [..] MusicLaneRow;
	//TODO We can change this as well. Possibly even remove it if we only
	//allow single section for op rows. Let's see how we use the op linear rows.
	all_op_section_to_row : [..] SectionToRow;

	/*Note : viewable and editable are subsets of all
		editable <= viewable <= all
		can maybe use this pattern in general for many
		different types of data
	*/
	//Note : viewable_linear_pitch_spaces applies to base_render_group
	//TODO change name to viewable_base_linear_spaces? viewable_lane_linear_spaces?
	//TODO could use viewable_linear_pitch_space if all_editable
	//TODO should these just be ids so we avoid having to update everywhere?
	// all_editable : bool;
	viewable_linear_pitch_spaces : [..] LinearPitchSpace;

	all_spiral_spaces : [..] SpiralSpace;
	all_spiral_vls : [..] SpiralVoiceLeading;

	all_space_point_to_value : [..] SpacePointToValue;

	//TODO Rename this to PitchSpace2
	//TODO Shoudl we merge this with ChordSpace2
	all_pitch_space_2D : [..] PitchSpace2D;

	all_cs2_points_2D : [..] ChordS2Points2D;

	//TODO rename to visible_space_points_3D
	//or viewable_space_points_3D so it accounts for 4D
	//sub sections
	visible_space_points_3D : [..] SpacePoint3D;
	all_chord_spaces_3 : [..] ChordSpace3;


	//Synthesis and audio data
	//TODO We could have an osc_wave pool and reuse osc_waves here as well.
	all_simple_synths : [..] SimpleSynth;
	free_simple_synth_pool : [..] SimpleSynth;
	// all_subtractive_synths : [..] SubtractiveSynth;
	// all_hover_simple_synths : [..] SimpleSynth;
}

//TODO If we set all this in AllData as 1 struct then we can just have 1 move
AllDataToSharedLibraryData :: inline (
	sl : *SharedLibraryData,
	dl : *DynamicLibrary,
	renderer_data : *RendererData,
	audio_data : *AudioData, 
	game_input : *GameInput, 
	//TODO Could make a SharedFrameData here if we have more data that is reset every frame.
	frame_hover_entities : *[..] HoverEntity,
	all_data : *AllData) 
{
	//TODO Could set one of these per dynamic library for convenience
	sl.my_shared_data = all_data.my_shared_data;
	sl.my_per_dl_data = dl.my_per_dl_data;
	// sl.extern_alloc = all_data.extern_alloc;

	sl.global_rules = all_data.global_rules;
	sl.renderer_data = renderer_data;
	sl.audio_data = audio_data;
	sl.game_input = game_input;

	sl.audio_timing = *all_data.audio_timing;
	sl.game_audio_play = *all_data.game_audio_play;

	sl.all_tuning_systems = *all_data.all_tuning_systems;
	sl.all_tuning_pitches = *all_data.all_tuning_pitches;

	sl.render_mspace_id = all_data.render_mspace_id;
	sl.all_mspace_data = *all_data.all_mspace_data;
	sl.free_mspace_data_pool = *all_data.free_mspace_data_pool;
	//TODO Need to move dl processing to after audio processing but before audio buffering before we can add this
	//Also add GameAudioPlay when we do that so we can access
	// sl.audio_mspace_id = all_data.audio_mspace_id;

	sl.all_linear_to_tuning_system = *all_data.all_linear_to_tuning_system;
	sl.all_linear_pitch_spaces = *all_data.all_linear_pitch_spaces;
	sl.all_space_points = *all_data.all_space_points;

	sl.all_simple_synths = *all_data.all_simple_synths;
	sl.free_simple_synth_pool = *all_data.free_simple_synth_pool;

	sl.all_open_op_spaces = all_data.all_open_op_spaces;
	sl.all_closed_op_spaces = *all_data.all_closed_op_spaces;
	sl.all_op_space_spec_data = *all_data.all_op_space_spec_data;
	sl.all_op_spec_data_3D = *all_data.all_op_spec_data_3D;

	sl.all_cs2_points_2D = *all_data.all_cs2_points_2D;
	sl.all_chord_space_points = *all_data.all_chord_space_points;

	sl.all_terminal_events = *all_data.all_terminal_events;

	sl.all_chosen_entities = all_data.all_chosen_entities;
	sl.frame_hover_entities = frame_hover_entities.*;
}
PostUpdateExternal :: inline (
	dl : *DynamicLibrary,
	renderer_data : *RendererData,
	perm : *Persist) 
{
	perm.all_data.my_shared_data = perm.all_data.shared_lib_data.my_shared_data;
	dl.my_per_dl_data = perm.all_data.shared_lib_data.my_per_dl_data;
	if perm.all_data.shared_lib_data.update_runtime_settings_from_dl {
		//TODO We can only use this here once startup_dl is the only place we can update settings from
		UpdateRuntimeSettings(perm.all_data.shared_lib_data.to_update_runtime_settings, perm, renderer_data);
		perm.all_data.shared_lib_data.update_runtime_settings_from_dl = false;
	}
}

//DOC : This return the string directly from memory so we need to copy it with or without an allocator
//to allocate it properly depending on where the string needs to be allocated.
AsmStringToString :: inline (
	asm_s : AsmString,
	ram : RAMMemory)
-> string, CPUError
{
	s_data, err := GetMemory(asm_s.data_address, asm_s.count, ram);
	if err.is_error return "", err;

	s := string.{asm_s.count, s_data};
	return s, NO_CPU_ERROR;
}

ChangeRenderMusicSpace :: inline (
	new_mspace_id : int,
	ad : *AllData) 
{
	last_mspace, found_last_mspace := ArrayFindFirstByNameId(ad.all_mspace_data,
		ad.render_mspace_id, "mspace_id");
	assert(found_last_mspace);

	new_mspace, found_new_mspace := ArrayFindFirstByNameId(ad.all_mspace_data,
		new_mspace_id, "mspace_id");
	assert(found_new_mspace);

	ad.render_mspace_id = new_mspace_id;

	MoveFixedCameraOpSpaces(last_mspace.mspace_cam.world_pos,
		new_mspace.mspace_cam.world_pos, ad);
}
GetRenderMSpace :: inline (all_data : *AllData) -> *MusicSpaceData {
	render_mspace, found_render_mspace := ArrayFindFirstByNameId(all_data.all_mspace_data,
		all_data.render_mspace_id, "mspace_id");
	assert(found_render_mspace);
	return render_mspace;
}
GetAudioMSpace :: inline (all_data : *AllData) -> *MusicSpaceData {
	audio_mspace, found_audio_mspace := ArrayFindFirstByNameId(all_data.all_mspace_data,
		all_data.audio_mspace_id, "mspace_id");
	assert(found_audio_mspace);
	return audio_mspace;
}
GetNextNonMutedMSpace :: inline (
	start_index : int, 
	all_mspace_data : [] MusicSpaceData) 
-> next_mspace_index : int, all_muted : bool 
{
	//TODO Should we return invalid here for these 2 assertions instead?
	assert(start_index >= 0);
	assert(start_index < all_mspace_data.count);
	if start_index + 1 < all_mspace_data.count {
		for start_index+1..all_mspace_data.count-1 {
			check_mspace := all_mspace_data[it];
			if check_mspace.mspace_audio_row_size == 0 continue;
			else return it, false;
		}
	}
	for 0..start_index {
		check_mspace := all_mspace_data[it];
		if check_mspace.mspace_audio_row_size == 0 continue;
		else return it, false;
	}
	return start_index, true;
}

MoveFixedCameraOpSpaces :: inline (
	new_cam_pos : Vector2F,
	last_cam_pos : Vector2F,
	//TODO Maybe we should just pass in all_open_op_spaces here
	ad : *AllData) 
{
	for * ad.all_open_op_spaces if it.fixed_op_type == .FIXED_TO_CAMERA {
		distance_from_last_cam : Vector2F = (it.world_offset - last_cam_pos);
		it.world_offset = new_cam_pos + distance_from_last_cam;
	}	
}

#if 0 {
for_expansion :: (all_dspaces : *AllDSpaces, body : Code, flags : For_Flags) #expand {
	//MusicPt : Need POINTER so we can cast the return value to the proper space type
	#assert(flags == For_Flags.POINTER);

	should_break : bool = false;
	//MusicPt : need to assign index out here to avoid name overlap within loop
    `it : *DimSpaceHeader = null;
    `it_index : int = 0;
    for *circle, circle_index : all_dspaces.circle_pitch_spaces {
    	if should_break break;
    	it = *circle.header;
    	it_index += 1;
    	#insert(break={should_break = true;}) body;
    	// #insert body;
    }    
    for *dspace_2D, dspace_2D_index : all_dspaces.chord_spaces_2 {
    	if should_break break;
    	it = *dspace_2D.header;
    	it_index += 1;
    	#insert(break={should_break = true;}) body;
    	// #insert body;
    }

    for *piano, piano_index : all_grids.piano_grids {
    	if should_break break;
    	it = *piano.header;
    	it_index += 1;
    	#insert(break={should_break = true;}) body;
    	// #insert body;
    }
    //TODO this required making DimSpaceHeader only 2D
    //TODO but we could split out if we needed DimSpaceHeader(Vector3F)
    //TODO then we would have 2D loop and 3D loop
    // print("it_index is %\n", it_index);
    for *grid_3D, grid_3D_index : all_grids.grids_3D {
    	if should_break break;
    	it = *grid_3D.header;
    	it_index += 1;
    	#insert(break={should_break = true;}) body;
    	// #insert body;
    }
}
}

/*NOTE : This is interesting because we needed 3 states in integration test.
The state to start so we can reset data and test results.
The state to continue so we can have a test run through multiple frames.
The state to end so we don't run anymore and print out CURRENT_TEST_RESULTS.
*/
TestState :: enum u8 {
	NO_TEST_RUNNING;
	TEST_STARTED;
	TEST_CONTINUE;
	TEST_FINISHED;
	//TODO Can use this to set an error later. 
	//For now we just print them but maybe we want to do something with the error.
	//If we don't then we can just replace this with TEST_FINISHED anyways
	TEST_ERROR;
}
//TODO Should we put this in thegame_test?
/*TODO If we need per-test data later on, then we can
add that array at compile-time with the itest arrays
and set it to default for each array and then set them
as needed on first test_data.is_initialized in case we have to change them at runtime.
*/
TestData :: struct {
	is_initialized : bool;
	test_name : string;
	test_state : TestState;
	test_function_name : string;
	//TODO Could use this to early out of tests if needed.
	// test_failsafe : bool;

	//TODO Can use this to store specific data for at the current
	//running test with test_alloc
	spec_data : *void;

	all_unit_tests_finished : bool;
	// all_i_test_finished : bool;
	all_itest_index : int;

	//TODO Can use this to keep track of time within
	//a test itself.
	//TODO could make this float64 if that's easier to use
	test_timer : Apollo_Time;

	//TODO Can use this from inside a test to check how long
	//all the frames are taking to run.
	// max_all_frame_time : Apollo_Time;
	//TODO could make this float64 if that's easier to use
	all_frames_time : Apollo_Time;
	//TODO Can use this from inside a test to check how long
	//the last frame took to run.
	// max_dt_time : Apollo_Time;
	//TODO could make this float64 if that's easier to use
	last_frame_dt : Apollo_Time;

	//We use this to run more inputs/actions within a test. This can be used
	//to do benny tests (maybe another name) just by setting
	//test_running = true and then using the sub_test_index to know what to run.
	//So we only need 1 function and this to run multiple inputs or other actions
	//for the same test since the test will keep running as long as we keep
	//resetting test_running = true;
	//This can also be used as a frame_count. We could add 
	//frame_count separately if we do that often
	sub_test_index : int;
	//We set this externally since it seems that it will be consistent,
	//but if it's not we can just use sub_test_index or something else.
	//This is is just there so the test can now where it is at and act accordingly.
	//We could also have a timer set in here if needed.
	//TODO Should have a timer which throttles the frames.
	frame_count : int;

	/*NOTE : This is one way to run tests consistently.
	HOWEVER we could just use frame_count and sub_test_index
	in any other way to write tests. This will just run inputs
	until done and seems like a pretty regular and consisten way
	to write integration tests with various inputs.
	*/
	initialized_test : bool;
	all_sub_tests : [..] SubTestData;

	//TODO REMINDER if we want to SubTest to just run a few frames, we would just put how many
	//frames we want to run as the repeat_count and have the test be an empty function.
	//So if we want the test to run more slowly we could just check a timer and keep running frames
	default_frame_wait : int;

	use_as_test_input : *GameInput;

	pre_test_runtime_settings : RuntimeSettingsData;

	//Some extra testing data
	//NOT SURE if I like this so maybe we can remove it if theres issues
	//ALSO If ever we pull out the mouse line char code then this would not be necessary
	test_mouse_line_char : int;
}
//TODO Maybe we can use this everywhere for tests now instead.
TIPData :: struct {
	perm : *Persist;
	game_memory : *GameMemory;
	renderer_data : *RendererData; 
	audio_data : *AudioData; 
	game_input : *GameInput;
}
SubTestData :: struct {
	// test_inputs : [] TestInput;
	// has_test_proc : bool;
	//TODO Can remove this if we don't need it anymore later
	//leaving for now just as a reminder of doing tests with procs instead
	//which ended up being more complicated and cumbersome in terms of both
	//implementation and legibility and the if statements are much clearer and
	//cleaner in general and I prefer working with them.
	//Let's see how it is over time writing more tests now.
	test_proc : TestInputProc;

	run_count : int;
	//TODO If we want the test to wait, we can just set this to 0
	//OR we could have an override flag that says to wait here instead
	//until something happens in the test
	run_index : int;
	//TODO Not sure we need this also best to have a failsafe otherwise
	//Or just reset the run_index or do run_index -= 1 so at least it won't get stuck;
	// wait_to_run : bool;

	//TODO We can use this to wait a certain number of frames
	//before running the test or each run of it, this way
	//the game keeps running and we just check each frame instead
	//TODO Could set this * fraction so if we slow it down
	//we would just multiple this by 2 or 3 or whatever and it would
	//wait until it hits that frame
	current_frame_wait : int;
	override_wait : bool;
	frame_wait_override : int;
	//TODO Could set this to current frame_count + frame_wait
	//once we hit this test.
	// end_frame : int;

	spec_data : *void;
}
SubT :: inline (
	run_count : int = 1,
	frame_wait_override : int = 1,
	proc : TestInputProc = null)
-> SubTestData 
{
	sub_test : SubTestData;
	//TODO Remove this if we never use it
	sub_test.test_proc = proc;
	sub_test.run_count = run_count;
	//We have run_index < run_count to loop run_count times. We could check run_index < run_count-1
	//But this also lets us check run_index == 0 as a default value and then set the run_count to how
	//many times we want it to actually run.
	sub_test.run_index = 1; 
	if frame_wait_override > 1 {
		sub_test.override_wait = true;
	}
	sub_test.frame_wait_override = frame_wait_override;
	return sub_test;
}
//TODO We simplify the if statement out here for convenience so we can run a test n times with 1 line.
//DOC : This actually runs it n-1 times so 0 would run it once maybe we can change that eventually for clarity...
RunSubTestNTimes :: (n : int, test_data : *TestData) {
	if test_data.all_sub_tests[test_data.sub_test_index].run_index == 0 {
		test_data.all_sub_tests[test_data.sub_test_index] = SubT(n);
	}
}
TestInputProc :: #type (
	perm : *Persist,	
	game_memory : *GameMemory,
	renderer_data : *RendererData, 
	audio_data : *AudioData, 
	game_input : *GameInput);

//Leaving this here in case we want to remember what we reset for this but can remove once
//we separate out all the mspace and op_space data from all data properly.
#if 0 {
//TODO Generalize the ResetAllDynamicArrays metacode
//and also do a reset for AllData
ResetAllCodeData :: (all_code_data : *AllCodeData) {
//TODO Could make a function for any type for this
//So we could reuse for AllDataInstructionData
//and AllOldMusicInstructionData
//TODO Could we use SetResizable array now? maybe in this case this is better since we also have integers
#insert #run () -> string {
	sb : String_Builder;
	all_code_data_type_info := cast(*Type_Info_Struct) type_info(AllCodeData);
	for ti_member : all_code_data_type_info.members {
		if ti_member.type.type == Type_Info_Tag.ARRAY {
			ti_array := cast(*Type_Info_Array) ti_member.type;
			if ti_array.array_type == .RESIZABLE {
				print_to_builder(*sb, 
				"array_reset_keeping_memory(*all_code_data.%);\n", ti_member.name);
			}
		} else if ti_member.type.type == Type_Info_Tag.INTEGER {
			print_to_builder(*sb, 
			"all_code_data.% = 0;\n", ti_member.name);
		}
	}
	return builder_to_string(*sb);
}();

	// for reg_def_enums array_add(*all_code_data.all_register_memory, MemoryValue.{});

	//TODO There could be a setting where we don't reset this if we want to maintain the memory_values.
	// reset(*all_code_data.ram_flat_pool);

	//TODO Could pull this out into separate function
	//Or also call DefaultCodeLevelData
	//Default values can be added here if needed.
	//Although in the case of the tuning_system, we have to check
	//later to make sure we already created it if it is added.
	//TODO Could allow an instruction that sets the default_tuning_system
	#if 1 {
	CreateDefaultTuningSystems(*all_code_data.all_tuning_systems, *all_code_data.all_tuning_pitches);
	} else {
	CreateEqualTemperedTuningSystemWithTuningPitches(12,
		*all_code_data.all_tuning_systems,
		*all_code_data.all_tuning_pitches,
		*all_code_data.all_mps_systems);
	CreateTuningSystem(TuningSystemType.pyth, 13, *all_code_data.all_tuning_systems, *all_code_data.all_tuning_pitches, *all_code_data.all_mps_systems);
	CreateCreateTuningDataSystems(*all_code_data.all_tuning_systems, *all_code_data.all_tuning_pitches);
	}
}
}


/*DOCU : MySimplePool is the simplest allocator I could think of. It just allocates and does not free.
It is currently made to grab memory from another allocator assuming that that will deal with it.
So this allows us to allocate memory within another allocator.

This is currently being tested in WatchData (although we will likely remove it), so that we can get the
expression nodes to have the same memory as the given allocator for TextOpSpaceData which will likely be
the default allocator.

We could add .RESIZE and then allocate more but then we would have to get more data from the original allocator
so we would then ahve to store it, so I am keeping this as simple as possible for now.

TODO IDEA : We could make a pool from Flat_Pool and then have MySimplePool make small pools from the Flat_Pool
so that then when we reset, we reset everything and if we want to increase memory from a specific place
we just reset and grab more. Not sure if this is useful but it could be worth trying.
*/
MySimplePool :: struct {
	base : *u8;
	//DOCU : used and size are in bytes. We could set "used" to be *u8 but this seems natural.
	used : int;
	size : int;	
	//TODO Could have a flag here or a separate pool that is resizable MyResizePool to avoid extra memory
	// is_resizable : bool;
}
InitMySimplePool :: (msp : *MySimplePool, size_in_bytes : int) {
	msp.used = 0;
	msp.size = size_in_bytes;
	msp.base = alloc(size_in_bytes);
}
ResetMySimplePool :: (msp : *MySimplePool) {
	msp.used = 0;
}
MySimpleAllocProc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
	if mode == {
	case .RESIZE; #through;
	case .ALLOCATE;
		msp := cast(*MySimplePool) allocator_data;
		assert(msp != null && msp.base != null);
		return_data : *u8 = msp.base + msp.used;
		if msp.used + requested_size >= msp.size {
			//TODO We could realloc here and memcpy over to the new one (Could make that a flag or a different alloc type)
			//Note that then we would lose the pointers
			// realloc(requested_size);
         log_error("Attempt to allocate size %, but MySimplePool is full : %\n", requested_size, msp);
         //TODO Which is better here. Returning null will likely crash something so the error will be obvious
         //but maybe we don't want to crash?
			// return return_data;
			return null;
		}
		msp.used += requested_size;
		return cast(*void) return_data;
	//NOTE : This was resizing the allocator but we don't want that
	// case .RESIZE;
	// 	msp := cast(*MySimplePool) allocator_data;
	// 	assert(msp != null && msp.base != null);
	// 	// return_data : *u8 = msp.base + msp.used;
	// 	if requested_size > msp.size {
	// 		//TODO We could realloc here and memcpy over to the new one (Could make that a flag or a different alloc type)
	// 		// realloc(requested_size);
   //       log_error("Attempt to resize : % bytes, but MySimplePool is fixed to : % bytes\n", requested_size, msp.size);
   //       //TODO Which is better here. Returning null will likely crash something so the error will be obvious
   //       //but maybe we don't want to crash?
	// 		// return return_data;
	// 		return null;
	// 	}
	// 	// msp.used += requested_size;
	// 	return cast(*void) msp.base;
	case .FREE; #through;
		//TODO Leaving these here separate in case we want to implement them later.
	case;
		//TODO Not sure this is works with our RESIZE changes, but we do it for now just in case.
      log_error("MySimpleAllocProc invalid Allocator_Mode : %\n", mode);
		return null;
	}
}
//TODO Should likely put this in TextOpSpaceData since we will allow
//changing the font size and color per op space I think.
TextEditorData :: struct {
	//TODO If we want these to be per op_space then we need one for each RenderGroup.
	//We have font_id so we could just associate one of these per font
	//if we want different fonts for different spaces for example.
	code_font_1_char_width_pixel : s64;
	//I prefer pre-computing this so it's the same everywhere without 
	//the possibility of a floating point difference error
	code_font_1_char_width_world : float;
	char_height : int;
	font_color : Vector4F;
	//TODO Eventually we will pass this in through the settings either directly or
	//we can set it from the settings to here so people can update text editor data and have
	//different text editor data for each text op space
	undo_split_string : string;
	undo_split_chars : [16] u8;
}
//DOC : We only have 1 font right now, if we add more then we can add an index here for that specific font
//but if we add more then we have to set that for PushText for example and in the text op space or at least
//for ui eventually i guess.
UpdateFontSize :: inline (font_size : float, ted : *TextEditorData, rd : *RendererData) {
	UpdateRendererFontSize(font_size, rd);
	SetupTextEditorData(ted, rd.*);
}
SetupTextEditorData :: inline (ted : *TextEditorData, renderer_data : RendererData) {
	//TODO Will need to pass in this function if we bring back hot code reloading.
	//TODO Should we search for the font by name instead in case we add new fonts later?
	//TODO Can call this from renderer and do it in there.
	one_char_width : s64 = renderer_data.all_my_fonts_data[1].char_width;
    // if one_char_width % 2 == 1 one_char_width -= 1;
	ted.code_font_1_char_width_pixel = one_char_width;
	//TODO Need to update this on zoom for text editor and text in general OR just remove it
	//and recompute it wherever we use it which may be preferable although we will have to adjust the
	//font size on zoom as well eventually. Leaving it like this for now for consistency and since I think
	//when we change the font size, we will have to update this anyways.
	ted.code_font_1_char_width_world = one_char_width / renderer_data.base_render_group.pixels_per_square;
	ted.char_height = renderer_data.all_my_fonts_data[1].char_height;
	// print("char_height=%, char_width_pixel=%, chard_width_world=%, pixels_per_square=%\n", 
	// 	ted.char_height, one_char_width, ted.code_font_1_char_width_world, renderer_data.base_render_group.pixels_per_square);

	//TODO This should be udpated from settings
	//TODO MAybe we should store these in FileString instead
	//so we can have it be different for single line input
	ted.undo_split_chars[0] = "\n";
	ted.undo_split_string = string.{1, ted.undo_split_chars.data};
}

//TODO Do this for other OpSpace/Window connections
//and we store persistent data in the non-window data
TextFileToOpSpace :: struct {
	text_file_id : int;
	op_space_id : int;
}

//TODO I think text_files or at least FileString should have it's own allocator.
//Then we can reuse the allocators if we close and open other files.
//I think we would only reuse a text file if we deleted a file in which case
//we could just reuse it later in a pool and reuse the pooled text file directly
//and just reset the count files and the file string values directly.
TextFile :: struct {
	id : int;
	//TODO Should we have a path variable and full name?
	absolute_path_name : string;
	/*DOC : This is technically either the relative path if we use load_op by name otherwise it's the absolute path.
	That is somewhat confusing but is convenient for loading by relative path when typing in the name.
	That is the only case we use it though. In all other cases the absolute path above should be used.
	*/
	file_name : string;
	file_write_time : Apollo_Time;
	//TODO Could have a file_extension or do this by enum. 
	//Extension is more robust since then we can add any 
	//extension we want. Could still have enum for specific
	//types that we support by default.
	file_extension : string;
	//TODO file_short_name should be file_name by default
	//TODO I think we can remove this now since we have absolute_path_name and 
	//file_name (which is relative or absolute depending on how the user inputs it)
	file_short_name : string;
	//TODO use resize_flat_pool_allocator_proc to resize text_string once we implement that
	//and see if that works at all with some copy_pasting.
	using file_string : FileString;

	was_internal_saved : bool;

	//TODO This should also be separated out since it is op_space specific
	//since we can have the same file in multiple op_spaces.
	//TODO Put this in TextOpSpaceData
	// text_cursor : TextCursor;

	//TODO We could separate this out since its only needed for the text editor and not for compiling for example
	//TODO How should we store lines of code in a separate data table and then manage the lines ourselves?
	//OR Each file_loc has it's own allocator and then we can
	//just split to the same allocator memory every time.
	//TODO Should probably put this in TextOpSpaceData anyways since we can
	//have a file in multiple op_spaces regardless. OR keep it here for now
	//so that the lines remain consistent for now.
	// file_loc : [..] string;
	//TODO Remove this completely once it is working in TextCursor
	// start_file_line_index : int;
	// end_file_line_index : int;
	// left_char_bound : int;
	// right_char_bound : int;

	/*TODO Could split this enum out into multiple arrays
		if that is more efficient or also split up
		all_text_files to have DEFAULT at the beginning
		and LIBRARY at the end depending on how we use it 
		or if we add more text file types. 
		Let's see what we do after we have the 
		jai files working.
	*/
	file_type : TextFileType;
	is_external_file : bool;
}

TextFileType :: enum {
	DEFAULT;
	LIBRARY;
}

//TODO Would could also make an IncreasingAllocator which always increases like this and instead of doing reset
//the get just gets from the same place every time. It would be slightly more efficient but then I would alos
//have to maintain it myself between Windows and Mac so this seems more convenient at least for now.
//TODO Use this for FileString for TextFile so that we can resize the string without wasting any memory at all.
same_start_resize_flat_pool_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if mode == {
      case .FREE;   
      	return null;
      case .RESIZE;
			pool := cast(*Flat_Pool) allocator_data;
			assert(pool != null);
			//We reset the pool here and then get so that 
			reset(pool);
			result := get(pool, requested_size);
			return result;
      case .ALLOCATE;
      	//TODO I think not allowing allocated here at all so we can only resize might be best... or maybe not...
      	//OR MAYBE alloc should be the same as resize anyways since this is a specific use case.
			pool := cast(*Flat_Pool) allocator_data;
			assert(pool != null);
			result := get(pool, requested_size);
			return result;
			// return null;
      case;
      	//TODO Not sure this is works with our RESIZE changes, but we do it for now just in case.
			return flat_pool_allocator_proc(mode, requested_size, old_size, old_memory, allocator_data);
    }
}
//TODO Should we rename this to TextString or TextEditString
//since it can be used for a file but also we are using everywhere
//for single line.
CreateFileStringData :: struct {
	//I will leave defaults out here if it really depends on the use case
	total_allocated_bytes : int;
	undo_action_count : int;
	//TODO We could default to " \n" if that makes more sense or put those as constants
	//TODO SETTINGS
	text_undo_split : string = "\n";
}
InitFileString :: inline (fs : *FileString, cfsd : CreateFileStringData) {
	fs.total_allocated_bytes = cfsd.total_allocated_bytes;
	fs.text_string = alloc_string(cfsd.total_allocated_bytes);
	fs.text_string.count = 0;

	InitTextActionHistory(fs, cfsd);
}
InitTextActionHistory :: inline (fs : *FileString, cfsd : CreateFileStringData) {
	fs.action_write_index = 0;
	fs.undo_buffer_length = 0;
	fs.total_buffer_length = 0;
	fs.text_undo_split = cfsd.text_undo_split;
	fs.text_action_history = NewArray(cfsd.undo_action_count, TextAction);
}
//TODO Should we generalize this to thegame_string as an AllocatedString or PreAllocString
//or leave here for now until we have to change it?
//Or call it CodeString to separate it from system Files
//but also this somewhat imitates a system file and the
//way we read and write to it.
//TODO Could we replace this with a *[..] u8 which
//already has allocated variable in it?
//TODO Can rename this to DynamicString so we can 
//build up for our own purposes.
//TODO Maybe rename this editable string since we use it with
//UpdateFileStringAtCursor and it is not necessarily a file.
//TODO WE COULD PUT single_line in here instead of compile-timing it everywhere
FileString :: struct {
	//TODO If we have a [..] u8 in here with it's own allocator
	//then I think we would not need to manage the member
	//and this string would just point to that array OR
	//I think we could just cast that array to string when needed.
	//TODO Use this instead with a Pool or Flat_Pool
	//Maybe Flat_Pool is fine so we can limit file size.
	//So each text file would have its own pool and string here
	//and then it would increase automatically when needed
	//and we can set allocated to the pool max allocated size.
	//With Flat_Pool we can reset and then get so that we stick to the same
	//initial .data. This way we could make our own allocator
	//that uses the Flat_Pool but keeps the same .data memory_base.
	//TODO Make our own flat_pool_allocator_proc that has its own resize.
	//text_string : [..] u8;
	text_string : string;
	total_allocated_bytes : int;

	/*NOTE : storing this in here now because techinally file_loc should be consistent
	across all text editors. If we want to keep a specific text editor window
	consistent, we can just update the bounds of that editor whenever we add lines.
	So just adjust all text_cursor_bounds for all TextOpSpaceData with this text_file.
	*/
	//TODO We can compile-time this out for single_line files
	file_loc : [..] string;
	//TODO FROM HERE should we generalize this?
	//text_string would point to first *u8
	//of dynamic string and its count would
	//be = dynamic_string.count
	//This has the advantage of being able to use
	//the built in jai memory allocation directly
	//and so we would only need to update the default
	//allocator
	// text_string : string;
	// dynamic_string : *[..] u8;

	not_saved_text_edit : bool;

	//TODO Can also have an allocator for the text undo system strings
	//so that if we reuse it eventually, then we can just clear it in 1 go.
	// text_undo_system : TextActionSystem;
	/*DOC : If undo_buffer_length < total_buffer_length, then we are undoing
	and therefore we could redo. If we perform an action, then we set
	total_buffer_length = undo_buffer_length so we can no longer redo
	but we can still undo if we have any undos left.
	So undo_buffer_length gets decremented as we undo and set back to
	total_buffer_length when we perform an action to reset the action history
	to the current write cursor.
	
	FOR RESET OR REUSE FILE if we delete a file for example and reuse the memory.
	//TODO We could put this into a struct like below if that helps transferring data or something like that later.
	I am not putting in a separate struct for now because it is likely best to
	just reuse the file_string altogether if we delete a file or something like that.
	Then if we use a separate allocator for the entire file, we could maybe use that here.
	Right now if we reuse, we would just reset these to 0 
	and the text_action_history would not change since the total_buffer_length
	and the undo_buffer_length would both be 0 we can just keep the old history the same.
	TODO WE COULD cycle through text_action_history and set them all to .NONE for good measure though
	*/
	action_write_index : int;
	undo_buffer_length : int;
	total_buffer_length : int;
	text_undo_split : string;
	//size_of(TextAction) == 224 bytes and size_of(TextCursor) == 88 bytes
	//so if we used u32/s32 in TextCursor then 224-88 = 136 bytes
	//100 * 224 bytes = 22400bytes = 22.4kb -> * 2 = 44.8kb
	//Seems ok to default to < 50kb but could increase default if we compress TextCursor
	text_action_history : [] TextAction;
}
// TextActionSystem :: struct {
// 	action_write_index : int;
// 	undo_buffer_length : int;
// 	total_buffer_length : int;
// 	text_action_history : [] TextAction;
// }
TextActionType :: enum u8 {
	NONE;
	ADD_TEXT;
	REMOVE_TEXT_LEFT;
	REMOVE_TEXT_RIGHT;
	//TODO We could add this later to do replace undos in 1 action for convenience
	//REPLACE_TEXT;
}
TextAction :: struct {
	action_type : TextActionType;
	//TODO We can make all the vars in here s32 which would reduce
	//the size of these actions by about 50% which may be worth doing.
	//TECHNICALLY we only have store char_point, line_number and fixed_select data
	//since everything else is computed based on char_point. 
	//Maybe we can do that eventually as that would be even more compression if needed.
	cursor_before_action : TextCursor;
	after_action_cursor : TextCursor;

	//TODO This could have a Flat_Pool as an allocator so we can
	//reuse it later if needed if we delete a text file for example 
	//but maybe we don't want that in general in which case it's not necessary.
	//FOR TESTS this gets allocated with test_alloc so then we continue using that if we play with the test.
	//But it will get reset on the next test if we run another one. Generally tests should be used as test
	//and only played around with for testing purposes after running the integration test.
	undo_chars : [..] u8;
}
CreateTextAction :: inline (
	action_string : string,
	ta : TextAction,
	file_string : *FileString,
	//TODO We can let people set this to whatever they want in a settings file. 
	//Default could be new line or something else.
	//Currently this only applies to adding text since deleting seems like wed want to undo in chunks
	//If we end up not using this, then we can hardcode checking single char or specific chars instead of using is_any
	// undo_split := " \r\t\n"
	undo_split := "\n")
{
	//TODO In case we have not added a text action history to this
	//file string then we just return. This currently applies to single
	//line input like terminal commands, test strings and watch window variable names.
	if file_string.text_action_history.count == 0 return;
	//NOTE : We use the action_string in here for new array no the undo_chars.
	//Maybe we should just pass in the variables directly instead of through TextAction
	//if that is less confusing but the TextAction feels better for setting data.
	assert(ta.undo_chars.count == 0);

	compressed_action_with_previous : bool = false;
	last_write_index : int = PosMod(file_string.action_write_index - 1, file_string.text_action_history.count);
	last_ta : *TextAction = *file_string.text_action_history[last_write_index];

	is_sequential_action : bool = last_ta.after_action_cursor.char_point == ta.cursor_before_action.char_point;
	is_single_char_action : bool = action_string.count == 1;
	same_action_as_last : bool = ta.action_type == last_ta.action_type;
	same_sequential_single_char_action : bool = is_sequential_action && is_single_char_action && same_action_as_last;
	if ta.action_type == .ADD_TEXT && same_sequential_single_char_action {
		//If we have the same undo split char, then we compress it instead of splitting it
		//eg if undo_split = " \n" then multiple single "\n" in a row or 
		//multiple single spaces " " in a row if user holds enter or spacebar for example
		if String.is_any(action_string[0], file_string.text_undo_split) {
			same_undo_split_char : bool = last_ta.undo_chars.count > 0 &&
				peek(last_ta.undo_chars) == action_string[0];
			compressed_action_with_previous = 
				same_sequential_single_char_action && same_undo_split_char;
		} else {
			compressed_action_with_previous = same_sequential_single_char_action;
		}
		if compressed_action_with_previous {
			next_char : u8 = action_string[0];
			array_add(*last_ta.undo_chars, next_char);
			last_ta.after_action_cursor = ta.after_action_cursor;
		}
	} 
	else if ta.action_type == .REMOVE_TEXT_LEFT && same_sequential_single_char_action {
		//We insert at index 0 here because we are removing the previous char and therefore need to reverse the order
		//eg "test" will be removed from right to left as t-s-e-t so in reverse we get t-e-s-t
		// sequential_text_remove_left : bool = last_ta.cursor_before_action.char_point - last_ta.undo_chars.count == ta.cursor_before_action.char_point;
		next_char : u8 = action_string[0];
		array_insert_at(*last_ta.undo_chars, next_char, 0);
		last_ta.after_action_cursor = ta.after_action_cursor;
		compressed_action_with_previous = true;
	} 
	else if ta.action_type == .REMOVE_TEXT_RIGHT && same_sequential_single_char_action {
		//Remove text right does not move cursor so last_ta.cursor_before_action == ta.after_action_cursor AND last_ta.after_action_cursor == ta.cursor_before_action
		//because last_ta.cursor_before_action == last_ta.after_action_cursor AND ta.cursor_before_action == ta.after_action_cursor
		// sequential_text_remove_right : bool = last_ta.cursor_before_action.char_point == ta.cursor_before_action.char_point;
		next_char : u8 = action_string[0];
		array_add(*last_ta.undo_chars, next_char);
		last_ta.after_action_cursor = ta.after_action_cursor;
		compressed_action_with_previous = true;
	} 

	if !compressed_action_with_previous {
		assert(file_string.action_write_index < file_string.text_action_history.count);
		next_action : *TextAction = *file_string.text_action_history[file_string.action_write_index];
		next_action.cursor_before_action = ta.cursor_before_action;
		next_action.after_action_cursor = ta.after_action_cursor;
		next_action.action_type = ta.action_type;
		array_reset_keeping_memory(*next_action.undo_chars);
		array_reserve(*next_action.undo_chars, action_string.count);
		memcpy(next_action.undo_chars.data, action_string.data, action_string.count);
		next_action.undo_chars.count = action_string.count;

		file_string.action_write_index = PosMod(file_string.action_write_index + 1, file_string.text_action_history.count);
		//TODO We can reuse this if we are adding multiple actions at once later.
		// WriteToCircleBuffer(TextAction.[action], 
		// 	file_string.text_action_history, 
		// 	*file_string.action_write_index);

		//This keeps track of the total undo_buffer_length
		file_string.undo_buffer_length += 1;
		if file_string.undo_buffer_length > file_string.text_action_history.count {
			file_string.undo_buffer_length = file_string.text_action_history.count;
		}
	}

	//We always reset this since we use this since we check if total_buffer_length == undo_buffer_length for redo
	//because if they are equal then we have nothing to redo since we have not undone anything.
	//This also restarts the action history since we did an action, so if we were undoing then we restart the action
	//from the current position since the total length is the same.
	file_string.total_buffer_length = file_string.undo_buffer_length;
}

//TODO We could also do this with a [..] u8 and remove total_allocated_bytes
//since we have allocated in the resizable array itself and
//which would also allow us to use a specific allocator for this specific dynamic string
//in the resizable array. Could make a separate one called ResizableString
DynamicString :: struct {
	text_string : string;
	total_allocated_bytes : int;
}
InitDynamicString :: inline (ds : *DynamicString, total_bytes : int) {
	ds.total_allocated_bytes = total_bytes;
	ds.text_string = alloc_string(ds.total_allocated_bytes);
	ds.text_string.count = 0;
}
MaybeResizeDynamicString :: inline (new_size : int, ds : *DynamicString) {
	if new_size >= ds.total_allocated_bytes {
		old_string : string = ds.text_string;
		ds.total_allocated_bytes = 2*new_size;
		ds.text_string = alloc_string(ds.total_allocated_bytes);
		memcpy(ds.text_string.data, old_string.data, old_string.count);
		ds.text_string.count = old_string.count;
		//TODO Use an underlying [..] u8 if we have problesm with free
		free(old_string);
	}	
}
SetDynamicStringFromStart :: inline (s : string, ds : *DynamicString) -> string {
	MaybeResizeDynamicString(s.count, ds);
	memcpy(ds.text_string.data, s.data, s.count);
	ds.text_string.count = s.count;
	return string.{s.count, ds.text_string.data};
}
//DOC : We return the string in case we want to set it somewhere else like an array of string
AddDynamicString :: inline (s : string, ds : *DynamicString) -> string {
	previous_size : int = ds.text_string.count;
	new_size : int = s.count + ds.text_string.count;
	MaybeResizeDynamicString(new_size, ds);
	add_string_data : *u8 = ds.text_string.data + previous_size;
	memcpy(add_string_data, s.data, s.count);
	ds.text_string.count = new_size;
	return string.{s.count, add_string_data};
}

//TODO I think text files should have their own allocator
/*DOC : This is only really used for tests so could rename to MakeTestTextFile
and just use it there since we create TextFile separate in the base game.
*/
MakeTextFile :: inline (
	all_next_ids : *AllNextIds,
	file_name : string,
	total_allocated_bytes : int,
	file_short_name : string = "",
	file_type : TextFileType = TextFileType.DEFAULT,
	write_file_string : string = "")
-> TextFile 
{
	text_file : TextFile;
	text_file.id = all_next_ids.NEXT_TEXT_FILE_ID;
	all_next_ids.NEXT_TEXT_FILE_ID += 1;
	//TODO Should we store these file names together somewhere
	//or is this fine?
	text_file.file_type = file_type;
	text_file.file_name = copy_string(file_name);
	//We set this for convenience since we are ony using this function for tests right now.
	// text_file.absolute_path_name = text_file.file_name;
	text_file.total_allocated_bytes = total_allocated_bytes;
	text_file.text_string = alloc_string(total_allocated_bytes);
	text_file.text_string.count = 0;
	WriteFileString(*text_file, write_file_string);
	//TODO Should this be an input parameter or maybe we should pull out 
	//text editor variables from the TextFile struct.
	// text_file.end_file_line_index = OP_SPACE_VIEWABLE_LINE_COUNT;
	//TODO REMOVE THIS AND COMPUTE IT EXTERNALLY BASED ON specific
	//OP SPACE data not AS A CONSTANT
	// text_file.file_tabs[text_op.ftab_i].tab_cursor.end_file_line_index = OP_SPACE_VIEWABLE_LINE_COUNT;

	if file_short_name.count == 0 {
		text_file.file_short_name = text_file.file_name;
	} else {
		text_file.file_short_name = copy_string(file_short_name);
	}

	return text_file;
}
//DOC : This will overwrite the entire file string
//TODO We could just move this into MakeTextFile if that is the only place we use it
//and also rename that to MakeTestTextFile Or just move it all into CreateTestTextFile
//OR leave it to be able to make a text file in gave if needed without saving it so they can save it
WriteFileString :: inline (
	text_file : *TextFile,
	write_string : string)
{
	//TODO We can remove this assertion once we automatically increase the main_file_string.
	assert(text_file.total_allocated_bytes > write_string.count);

	memcpy(text_file.text_string.data, write_string.data, write_string.count);
	text_file.text_string.count = write_string.count;

	//TODO Can set this directly if we use a specific allocator for a text file
	//and then make our own SplitToArray function that splits directly to an array
	lines := String.split(text_file.text_string, cast(u8) #char "\n",, temp);
	array_reset_keeping_memory(*text_file.file_loc);
   for lines array_add(*text_file.file_loc, it);
}

//TODO Can put TAB_CHAR_COUNT in an editable settings file
//OR Could set it in text editor data for now
TAB_CHAR_COUNT : int : 2;
//TODO We could pull this out as a function so we can test if mouse_line_char is correct in unit tests
//for something like < op_mouse x diff although we are checking that based on how much it moves over
//TODO We could store this in text_editor_data as well and then make a function to GetCharCountWorld
GetCharCount :: inline (c : u8) -> int {
	if c == "\t" return TAB_CHAR_COUNT;
	return 1;
}
StringCharCount :: inline (c : u8, s : string) -> int {
	char_count : int = 0;
	i : int = String.find_index_from_left(s, c, 0);
	while i != -1 {
		char_count += 1;
		i += 1;
		i = String.find_index_from_left(s, c, i);
	}
	return char_count;
}
//TODO Should this be connected to TextFile
//and be fetched implicitly or do we just pass in
//freely for now in case we want multiple cursor
//editing eventually.
//TODO We can likely reduce these values to s32/u32 and then
//reduce this struct by half for the undo system
/*REMINDER IMPORTANT : If we make these all s32/u32 then we could
reduce the size of the undo system. We could leave char_point as int
and everything else as u32. That would limit the size of files to
2^32bytes ~ 4Gb
*/
TextCursor :: struct {
	/*Note : This char_point implies before the character
	so that that the cursor starts before the first char
	and ends after the last char. Therefore, char_point
	can be == text_string.count+1 which would be placed
	after the last character.
	*/
	//TODO Should rename this to cursor_file_char_index
	//TODO Would this be more convenient as a *u8? Maybe not
	char_point : int;
	cursor_line_number : int;
	//Note : This is the cached cursor_point but in floating point
	//Can be computed with 1 multiplication now that text is constant
	//TODO We should only have 1 of these so we don't have to recompute
	//or have function but I think only having 1 is better.
	// cursor_diff_x : float;
	//NOTE : Now we multiple this by perm.text_editor_data.code_font_1_char_width_world
	//whenever we need it in the world which keeps it consistent everywhere with only 1 update.
	//TODO Could renmae to cursor_line_char_index
	cursor_line_char : int;
	//TODO Should we store the height in here?
	//Right now we recompute every frame in PushTypeCursor since it is based on line_height and font_height.

	//Used to fix a cursor for selection.
	//Should we call it something else?
	cursor_is_selecting : bool;
	fixed_select_char_point : int;
	fixed_select_line_number : int;
	fixed_select_line_char : int;

	cursor_left_mouse_holding : bool;

	//TODO Could rename these now that the
	//TODO Should this be in FileString instead?
	//What if we want multiple cursors eventually?
	/*NOTE : This is used for the bounds of the cursor. We adjust
	for rendering while actually rendering. This is worth remembering,
	because this is adjusted for here for viewable bounds and then
	also adjusted while rendering and in the input to prevent going over
	the bounds even if we have less loc than the full view.
	SO THIS IS A COMBO OF THIS + RENDERING + INPUT to keep
	the cursor and the lines in balance.
	This is important to remember when updating everything.
	So in the case of loc < end_file_line_index we prevent the cursor
	from being > loc and so the start->end is always = viewable lines
	and the cursor is either between start->loc or start->end.
	*/
	start_file_line_index : int;
	end_file_line_index : int;
	/*DOC : These are char_bounds because they represent the number of single chars.
	So if a tab is 2 chars then the tab would coung for 2 chars in these bounds.
	*/	
	left_char_bound : int;
	right_char_bound : int;
}

ResetTextCursor :: inline (tc : *TextCursor, $reset_bounds : bool = true) {
	tc.char_point = 0;
	tc.cursor_line_char = 0;
	tc.cursor_line_number = 0;
	tc.cursor_is_selecting = false;
	tc.cursor_left_mouse_holding = false;

	#if reset_bounds {
	char_bound_diff : int = tc.right_char_bound - tc.left_char_bound;
	tc.left_char_bound = 0;
	tc.right_char_bound = char_bound_diff;
	}
}
/*DOC : This does not create a new string but just takes a view on the input text string
We can take from the count instead of right char bound because then we
always get the string even if right_char_bound > text.count
*/
SingleLineTextInBounds :: (text : string, cursor : TextCursor) -> string {
	//TODO can do right_char_bound - left_char_bound instead if that seems better
	text_in_bounds : string = String.slice(text, cursor.left_char_bound,
		text.count - cursor.left_char_bound);
	return text_in_bounds;
}

//TODO Can pass in cursor height = 0 here if we don't need to adjust for cursor height
MouseYDiff :: inline (start_y : float, mouse_y : float, cursor_height : float) -> float {
	mouse_y_diff : float = start_y - mouse_y - YAdjustCursorHeight(cursor_height);
	return mouse_y_diff;
}
MouseLineNumber :: inline (
	//Get this from the function above to adjust for cursor height
	mouse_y_diff : float,
	line_height : float,
	start_line_index : int,
	max_line_count : int) 
-> int 
{
	mouse_line_diff_float : float = mouse_y_diff / line_height;
	mouse_line_diff_int : int = round_to_int(mouse_line_diff_float);
	mouse_line_number : int = mouse_line_diff_int + start_line_index;
	if mouse_line_number < 0 {
		mouse_line_number = 0;
	} else if mouse_line_number >= max_line_count {
		mouse_line_number = max_line_count-1;
	}
	return mouse_line_number;
}
MouseLineChar :: inline (
	mouse_x : float,
	start_x : float,
	char_width_world : float,
	max_line_char_count : int)
-> int 
{
	op_mouse_x_diff : float = mouse_x - start_x;
	before_mouse_x_diff : float = op_mouse_x_diff / char_width_world;
	mouse_line_char : int = round_to_int(before_mouse_x_diff);
	// mouse_line_char : int = round_to_int(before_mouse_x_diff / perm.text_editor_data.code_font_1_char_width_world);
	if mouse_line_char < 0 {
		mouse_line_char = 0;
	} else if mouse_line_char > max_line_char_count {
		mouse_line_char = max_line_char_count;
	}
	return mouse_line_char;
}
//TODO FROM HERE start testing and think about this
//and don't forget to remove extra rendering compiled out code on bottom
//TODO FROM HERE we could have a general mouse holding flag
//in AllData so we can check that anywhere in case to avoid
//holding patterns but reset it every frame if needed
//Do that first or just start testing text file tabs
//and then do that after. Iunno maybe think about it a bit
//first before doing that with holding
//try it out with op spaces to see how that is
//TODO MAYBE rename this to IsMouseSpecificHolding
//and then can have a general one. Let's test that when we
//do the terminal and then other op spaces
IsMouseSpecificHolding :: inline (
	specific_hold : bool,
	game_input : GameInput) 
-> bool
{
	mouse_holding : bool = specific_hold &&
		IsInputDown(.MOUSE_BUTTON_LEFT, game_input) &&
		!IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input);
	return mouse_holding;
}
/*TODO We could check if !IsInputDown && !down_this_frame for extra
safety but I think this is enough. We could imagine a case where
the mouse kind of gets stuck but then pressing the mouse will undo that.
The other way we could have issues with the IsInputDown maybe... probably not
so we could add that check if needed.
*/
MouseOffSpecificHold :: inline (
	specific_hold : *bool,
	game_input : GameInput)
-> bool
{
	off_hold : bool = specific_hold.* &&
		IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input);
	if off_hold {
		specific_hold.* = false;
	}
	return off_hold;
}
TextSplitLineMouseHolding :: inline (
	mouse_line_char : int,
	mouse_line_number : int,
	tsl : *TextSplitLine,
	game_input : GameInput) 
{
	same_mouse_line_char : bool = tsl.cursor_line_char == mouse_line_char &&
		tsl.cursor_line_number == mouse_line_number;
	if IsMouseSpecificHolding(tsl.cursor_left_mouse_holding, game_input) &&
		!same_mouse_line_char
	{
		if !tsl.cursor_is_selecting {
			tsl.cursor_is_selecting = true;
			// tsl.fixed_select_char_point = tsl.char_point;
			tsl.fixed_select_line_number = tsl.cursor_line_number;
			tsl.fixed_select_line_char = tsl.cursor_line_char;
		}

		// tsl.char_point = mouse_char_point;
		tsl.cursor_line_char = mouse_line_char;
		tsl.cursor_line_number = mouse_line_number;

		//TODO Should we just store this in terminal_tsl instead to show bounds of the highlight?
		//That would also be translatable afterwards but then also maybe confusing
		// end_line_index : int = min(tsl.split_lines.count-1,
		// 	tsl.start_file_line_index + tsl.viewable_lines_from_zero);
		end_line_index : int = tsl.start_file_line_index + tsl.viewable_lines_from_zero;
		if tsl.cursor_line_number < tsl.start_file_line_index {
			tsl.start_file_line_index = tsl.cursor_line_number;
		} else if tsl.cursor_line_number > end_line_index {
			tsl.start_file_line_index += tsl.cursor_line_number - end_line_index;
		}

		same_fixed_line_char : bool = tsl.cursor_line_char == tsl.fixed_select_line_char &&
			tsl.cursor_line_number == tsl.fixed_select_line_number;
		if tsl.cursor_is_selecting && same_fixed_line_char {
			//Remove the selection if the cursor was brought back to the fixed selection.
			//Checking this here avoids any issues like missing a backspace or text input because
			//we still have that cursor is selected but the selection is 0 char width so nothing happens for 1 keypress.
			tsl.cursor_is_selecting = false;
		}	
		// print("cursor=%\n", tsl.cursor);
	} 
	MouseOffSpecificHold(*tsl.cursor_left_mouse_holding, game_input);
}
/*DOC : This needs to be called outside of the rectangle checking because we can be holding the mouse
anywhere when highlighting and also this registers the up_this_frame to unhold the mouse
so we need to make sure this gets called no matter what

TODO SHOULD WE RESET cursor_left_mouse_holding if we click off the text op_space on the same frame?
ACTUALLY I dont think so since it wont move if we are off it 
and then itll get reset anyways when we click back on the op space
since itll get an up_this_frame and then reset it here anyways in any case
since this is always called if we have selected the text op space
*/
CheckCursorMouseHolding :: inline (
	mouse_char_point : int,
	//line_number == 0 for single line input
	mouse_line_number : int,
	cursor : *TextCursor,
	file_string : FileString,
	game_input : GameInput,
	$single_line : bool = false) 
-> bool
{
	is_mouse_input : bool = false;
	/*DOC : We press outside this function and then if we are holding
	and pressed and the char point is not the same, then we highlight.
	We undo the left mouse holding below on an up this frame in any case
	if we had the flag on which should undo it even if we press away
	to a different pane or a different window/empty space and come back after
	one of the up this frame will trigger it.
	Putting the up on the bottom is necessary to reset it if we get a
	down and up on the same frame to make sure we register the up and remove
	the mouse hold.
	Since we only cursor select when mouse char point != cursor char point
	then we are ok because we cannot have 2 different mouse positions on the same frame.
	*/
	// if cursor.cursor_left_mouse_holding &&
	// 	IsInputDown(.MOUSE_BUTTON_LEFT, game_input) &&
	// 	!IsKeyboardPress(.MOUSE_BUTTON_LEFT, .DOWN_THIS_FRAME, game_input) &&
	if IsMouseSpecificHolding(cursor.cursor_left_mouse_holding, game_input) &&
		mouse_char_point != cursor.char_point
	{
		if !cursor.cursor_is_selecting {
			cursor.cursor_is_selecting = true;
			cursor.fixed_select_char_point = cursor.char_point;
			cursor.fixed_select_line_number = cursor.cursor_line_number;
			cursor.fixed_select_line_char = cursor.cursor_line_char;
		}

		cursor.char_point = mouse_char_point;
		//We update this below now, just leaving here as a reminder in case there is an issue
		// cursor.cursor_line_char = mouse_line_char;
		cursor.cursor_line_number = mouse_line_number;
		UpdateCursorLineCharAndBounds(cursor, file_string, single_line);
		is_mouse_input = true;
	} 
	/*DOC : I THINK we don't want an else if here because if we get a down
	and up on the same frame then we want them to cancel out otherwise 
	we can get down and up on same frame and then it would still be holding
	so we do down on the next frame, it would highlight since it never
	reset the mouse holding flag.
	This way we always reset on a mouse up even no matter what.
	*/
	MouseOffSpecificHold(*cursor.cursor_left_mouse_holding, game_input);
	// if cursor.cursor_left_mouse_holding &&
	// 	IsKeyboardPress(.MOUSE_BUTTON_LEFT, .UP_THIS_FRAME, game_input) 
	// if CheckMouseOffSpecificHold(cursor.cursor_left_mouse_holding, game_input) {
	// 	cursor.cursor_left_mouse_holding = false;
	// 	//TODO Should we set is mouse input or since it's off now then we don't actually have input this frame?
	// 	//Probably not since we are not holding anything down and just resetting
	// }
	/*DOC : Always setting this to true here says there is mouse input whenever we were holding on some text
	which prevents keyboard input with text input. Even though this likely works fine in general, it avoids any
	invalid cursor and text states that I very likely did not think of.
	If we have a specific mouse and keyboard together, then I can code that precise input explicitly.
	*/
	// if cursor.cursor_left_mouse_holding {
	// 	is_mouse_input = true;
	// }
	//TODO I Think we can remove returning this now and just check this instead
	return cursor.cursor_left_mouse_holding;
}

//This is in here because the external files dont access the platform code. If we separate out the
//dynamic library code from platform file, then we can put this there instead.
// Type_ExternalRunOnce :: #type (
// 	all_data : *AllData,
// 	renderer_data : *RendererData,
// 	input : GameInput) -> ();
//TODO Need to rename this since we use it for both functions now.
Type_ExternalRunOnce :: #type (
	shared_lib : *SharedLibraryData) -> ();
/*TODO Not sure we need this stub anymore since we have
  a table for the external files so we just don't put
  an entry in the table then.

  TODO MAYBE we can use thise stub instead of setting a null pointer OR just check for null.
  Will leave this here as a reminder just in case that is a better idea.
*/
Stub_ExternalRunOnce :: (
	all_data : *AllData,
	renderer_data : *RendererData,
	input : GameInput)
{ 
    log("We are running Stub_ExternalRunOnce\n");
}

#if 0 {
InputCheck :: struct {
	is_writing_code : bool;
}
ValidateInputPress :: inline (
	input_state : bool,
	input_check : InputCheck)
-> bool
{
	result : bool = input_state &&
		!input_check.is_writing_code;
	return result;
}
}

CircleOrientation :: struct {
	clockwise : bool;
	rotate_rad : float;
}


AsmChordS2Data :: struct {
	//return values
	ret_dspace_id : int;

	op_space_id : int;
	world_pos : Vector2F64;
	scale_world_unit : float64;
   point_dim : Vector2F64;
	//TODO Should we allo both or is tuning_system_id enough since this is a chord_space.
	//I guess I am thinking what if we want the geometry without the sound... but then someone can make it.
	//We need lp_count in case we have different tuning syste
   lp_count : int;
	tuning_system_id : int;
	is_sound_float : AsmBool;

	vl_order_text : AsmBool = #run ToAsmBool(true);
	vl_order_color : AsmBool = #run ToAsmBool(true);

	asm_cs_filters : AsmArray(AsmCSFilter);
	cs_filter_aggregate : ChordSpaceFilterAggregate;

	osc_wave_type : OscWaveType;

   //TODO Maybe we only allow this in dynamic libraries
   //OR MAYBE we can add it later if we add matrices to the language
   //MAYBE 2d is ok but maybe its going overboard and will be too slow
	// transform : Matrix2F64;
} @LibraryAsmGen
AsmFiltersToTempFilters :: inline (
	asm_cs_filters : [] AsmCSFilter,
	ram_memory : RAMMemory)
-> [] CSFilter, CPUError
{
	//TODO We could pass in temp as the allocator but we always copy this over
	//after anyways for chord_s2 and chord_s3 so putting this here now to keep it consistent.
	cs_filters := NewArray(asm_cs_filters.count, CSFilter,,temp);
	for asm_cs_filters {
		cs_filters[it_index].filter_index = it.filter_index;
		cs_filters[it_index].filter_value = it.filter_value;
		cs_filters[it_index].filter_type = it.filter_type;
		err : CPUError;
		cs_filters[it_index].value_set, err = GetAsmArray(it.value_set, ram_memory);
		if err.is_error return .[], err;
	}
	return cs_filters, NO_CPU_ERROR;
}
FilterLocalVLDistanceFromChords :: inline (
	max_vl_distance : int,
	space_point_fun_region_pos : [$fr_dim] int,
	tsc : int,
	chords_to_check : [][chord_dim] int,
	$chord_dim : int)
-> bool
{
	pitch_set : [] int = FunRegionPosToPitchSet(space_point_fun_region_pos, tsc, chord_dim);
	is_within_vl_distance : bool = false;
	for chord : chords_to_check {
		//TODO Also filter for 2-note chord space in 3d, and 2 and 3 in 4d
		//TODO FROM HERE CHANGE THIS NAME PULL THIS OUT AND MOVE TO 4D AND ALLOW MULTIPLE FILTERS
		//EG THIS ONE AND CHROMATIC TO SEE CLOSEST CHROMATIC OR THIS AND DIATONIC TO SEE CLOSEST DIATONIC
		total_vl_distance : int = 0;
		for note, note_index : chord {
			total_vl_distance += abs(note - pitch_set[note_index]);
		}

		fun_region_distance : int = 0;
		chord_fun_region_pos := OrderedPitchSetToFundamentalRegion(chord, tsc);
		for note, note_index : chord {
			fun_region_distance += abs(chord_fun_region_pos[note_index] - space_point_fun_region_pos[note_index]);
		}

		if fun_region_distance <= max_vl_distance || total_vl_distance <= max_vl_distance {
			return true;
		}
	}
	return false;
}

MapChordS2Data :: struct {
	dspace_id : int;
	op_space_id : int;
	vl_start_chord : AsmArray(float64);
	vl_deltas : AsmArray(float64);
	//TODO Should we add a color here to identify specific voice leadings?
} @LibraryAsmGen

/*TODO Should add values somewhere to relate space_points
to fun_region_pos / other pitch sizes. So circles could
have > 1 note value like in 3.5.3 abstract model of diatonic counterpoint
*/
DEFAULT_CIRCLE_ORIENT :: CircleOrientation.{true, PI/2.0};
MakeCircleSpace :: (
	base_circle_pos : Vector2F, radius : float, 
	num_of_points : int, point_dim : Vector2F,
	all_space_points : *[..] SpacePoint,
	orient : CircleOrientation = DEFAULT_CIRCLE_ORIENT)
-> Space2D 
{
	//TODO For unequal spaces, we would have to compute each polar coordinate separately.
	//TODO Could generalize and compute points separately based on tuning_system
	//and then keep this method if we are making a circle_space from an array for memory_indices.
	roots_of_unity := RootsOfUnity(num_of_points, orient.clockwise, orient.rotate_rad, Vector2F,, temp);

	space : Space2D;
	space.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	defer context.ALL_NEXT_IDS.DSPACE_ID += 1;
	space.dspace_point_dim = point_dim;
	space.dspace_dim = MakeV2F(0, radius); //put radius in dspace_dim.y for now since #place y = radius
	space.dspace_dim_int = MakeV2I(num_of_points, 0);
	space.dspace_world_pos = base_circle_pos;
	space.dspace_world_center = base_circle_pos;
	for circle_pos, circle_index : roots_of_unity {
		point : SpacePoint;
		point.id = context.ALL_NEXT_IDS.POINT_ID;
		defer context.ALL_NEXT_IDS.POINT_ID += 1;
		point.dspace_id = space.dspace_id;
		point.rel_pos = space.dspace_dim.radius * circle_pos;
		point.world_pos = space.dspace_world_pos + point.rel_pos;
		point.rect_mesh = RectCenterDim(point.world_pos, point_dim);
		point.dspace_pos = point.rel_pos;
		point.int_pos.x = circle_index;

		point.color = GREY_DARK_V;
		if circle_index == 1 || circle_index == 3 || circle_index == 6 || circle_index == 8 || circle_index == 10 {
			point.color = LIGHT_BROWN;
		}

		array_add(all_space_points, point);
	}
	return space;
}

ComputeCircleRadius :: inline (input_radius : int) -> float {
	radius : float = 0.5 * (1 + input_radius);
	return radius;
}

MakeCircularPitchClassSpaceAndPoints :: (
	base_circle_pos : Vector2F, radius : float, 
	num_of_points : int, point_dim : Vector2F,
	all_space_points : *[..] SpacePoint,
	orient : CircleOrientation = DEFAULT_CIRCLE_ORIENT) 
-> Space2D 
{
	roots_of_unity := RootsOfUnity(num_of_points, orient.clockwise, orient.rotate_rad, Vector2F,, temp);

	space : Space2D;
	space.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	defer context.ALL_NEXT_IDS.DSPACE_ID += 1;
	space.dspace_point_dim = point_dim;
	space.dspace_dim = MakeV2F(0, radius); //put radius in dspace_dim.y for now since #place y = radius
	space.dspace_dim_int = MakeV2I(num_of_points, 0);
	space.dspace_world_pos = base_circle_pos;
	space.dspace_world_center = base_circle_pos;
	for circle_pos, circle_index : roots_of_unity {
		point : SpacePoint;
		point.id = context.ALL_NEXT_IDS.POINT_ID;
		defer context.ALL_NEXT_IDS.POINT_ID += 1;
		point.dspace_id = space.dspace_id;
		point.rel_pos = space.dspace_dim.radius * circle_pos;
		point.world_pos = space.dspace_world_pos + point.rel_pos;
		point.rect_mesh = RectCenterDim(point.world_pos, point_dim);
		point.dspace_pos = point.rel_pos;
		point.int_pos.x = circle_index;

		point.color = GREY_DARK_V;
		if circle_index == 1 || circle_index == 3 || circle_index == 6 || circle_index == 8 || circle_index == 10 {
			point.color = LIGHT_BROWN;
		}

		array_add(all_space_points, point);
	}
	return space;
}

MakeRowLinearPitchSpace :: inline (
	world_base_pos : Vector2F,
	octave_height : float,
	dspace_height : float,
	dspace_width : float)
-> LinearPitchSpace
{
	linear : LinearPitchSpace;
	linear.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	defer context.ALL_NEXT_IDS.DSPACE_ID += 1;

	linear.base_world_pos = world_base_pos;

	//Note : We use base_world_pos as it is more consistent
	//and keeps both eq and non-eq scrolling clean.
	// linear.dspace_world_pos = world_base_pos;
	//TODO How do we pass in this point or do we even have to?
	//TODO This is updated later since we need the first point
	// linear.dspace_world_pos.y += 0.5;

	linear.dspace_world_center = world_base_pos;
	linear.dspace_world_center.y += 0.5*dspace_height;

	linear.octave_dim = MakeV2F(dspace_width, octave_height);
	linear.dspace_dim = MakeV2F(dspace_width, dspace_height);

	return linear;
}

/*New Space and points Code
*/
MakeLinearPitchSpace :: inline (
	world_pos : Vector2F, 
	system_point_count : int,
	all_space_points : *[..] SpacePoint,
	orientation : LinearPitchSpaceOrientation = LinearPitchSpaceOrientation.VERTICAL)
-> LinearPitchSpace
{
	linear_point_dim : Vector2F = DEFAULT_LINEAR_POINT_SIZE;
	linear_point_dim.y = DEFAULT_LINEAR_SPACE_SIZE.y / system_point_count;

	//TODO rotate based on Matrix2F transform instead of y_up
	linear : LinearPitchSpace;
	linear.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	defer context.ALL_NEXT_IDS.DSPACE_ID += 1;
	linear.dspace_world_center = world_pos;

	linear.dspace_world_pos = world_pos;
	linear.dspace_world_pos.y -= 0.5 * DEFAULT_LINEAR_SPACE_SIZE.y;
	linear.dspace_world_pos.y += 0.5 * linear_point_dim.y;

	linear.base_world_pos = world_pos;
	linear.base_world_pos.y -= 0.5 * DEFAULT_LINEAR_SPACE_SIZE.y;

	linear.dspace_point_dim = linear_point_dim;
	linear.octave_text = "0";
	linear.orientation = orientation;
	linear.transform = Matrix2F_IDENTITY;
	linear.dspace_dim_int.y = system_point_count;
	linear.dspace_dim = DEFAULT_LINEAR_SPACE_SIZE;

	return linear;
	//TODO Keeping vertical and horizontal for now in case we use horizontal later
	//But would likely make a separate function for that anyways since it would be a different mode
	// if linear.orientation == LinearPitchSpaceOrientation.VERTICAL {
	// } else if linear.orientation == LinearPitchSpaceOrientation.HORIZONTAL {
	// 	linear.transform = ROTATE_NEG90;
		//TODO can we remove one of these if we always start from the base of the rectangle?
	// 	linear.dspace_world_pos.x -= 0.5 * (system_point_count * linear_point_dim.x);
	// 	linear.dspace_world_pos.x += 0.5 * linear_point_dim.x;
	// 	linear.base_world_pos = linear.dspace_world_pos;
	// 	linear.base_world_pos.x -= 0.5 * linear_point_dim.x;
	// 	linear.dspace_dim_int.x = system_point_count;
	// 	linear.dspace_dim.y = linear_point_dim.y;
	// 	linear.dspace_dim.x = linear_point_dim.x * (system_point_count);
	// }
}

GetRowNumOfPoints :: inline (
	tuning_system_count : int,
	create_row_data : CreateRowData)
-> int
{
	num_of_points : int = tuning_system_count;
	if create_row_data.use_num_of_points {
		num_of_points = create_row_data.num_of_points;
	}
	return num_of_points;
}

ComputeRowHeight :: inline (
	tuning_system : TuningSystem,
	array_tuning_pitches : [] TuningPitch,
	create_row_data : CreateRowData)
-> float
{
	num_of_points : int = GetRowNumOfPoints(tuning_system.music_pt_count, create_row_data);

	row_height : float;
	//TODO This should not be based on EQUAL_TEMPERAMENT but just on EQUAL in CreateRowData
	//since we want to allow unequal temperaments but with same sized rectangle points for convenience
	if tuning_system.type == TuningSystemType.EQUAL_TEMPERAMENT {
		row_height = create_row_data.octave_height * num_of_points / tuning_system.music_pt_count;
	}
	else {
		row_height = ComputeRowHeightFromRatios(num_of_points, tuning_system,
			array_tuning_pitches, create_row_data.octave_height);
	}

	return row_height;
}

//TODO Pass in compass interval to compute ratios properly with non octave-based tuning systems
ComputeRowHeightFromRatios :: inline (
	num_of_points : int,
	tuning_system : TuningSystem,
	ordered_tuning_pitches_in_system : [] TuningPitch,
	octave_height : float)
-> float
{
	total_height : float = 0;
	pitch_index : int = 0;
	while pitch_index < num_of_points
	{
		mod_pitch_index : int = pitch_index % ordered_tuning_pitches_in_system.count;
		tuning_pitch : TuningPitch = ordered_tuning_pitches_in_system[mod_pitch_index];

		//TODO update to consider the base of the tuning_system
		length_ratio : float = LogRatioToLinear(tuning_pitch.ratio_to_next_music_pt, tuning_system.compass_interval);
		point_height : float = length_ratio * octave_height;
		total_height += point_height;

		pitch_index += 1;
	}

	return total_height;
}

//TODO Is there somewhat to restric thte type of $S to 2 types?
AdjustSpacePointsBaseNote :: inline (
	//TODO This should be based on linear_pitch_space view and not TuningSystemType
	tuning_system_type : TuningSystemType,
	points_in_space : [] $S,
	base_note : int,
	base_world_pos : Vector2F,
	row_height : float)
{
	#assert(S == SpacePoint || S == *SpacePoint);

	//TODO This should be based on something else in case we have non_equal temperaments but that look equal
	if tuning_system_type == TuningSystemType.EQUAL_TEMPERAMENT {
		AdjustSpacePointsEqualTemperament(points_in_space, base_world_pos, base_note);
	} else {
		AdjustSpacePointsNonEqualTemperament(points_in_space, base_world_pos, base_note, row_height);
	}
}

AdjustSpacePointsEqualTemperament :: inline (
	points_in_space : [] $S,
	base_world_pos : Vector2F,
	base_note : int)
{
	#assert(S == SpacePoint || S == *SpacePoint);

	for * pointer, point_index : points_in_space
	{
		point : *SpacePoint;
		#if S == *SpacePoint point = <<pointer;
		else #if S == SpacePoint point = pointer;

		//TODO Could just update world_pos and create the rect in the renderer
		//But obviously this is more efficient in the renderer
		rect_center_y : float = point.rect_dim.y * PosMod(point_index - base_note, points_in_space.count);
		point.world_pos = base_world_pos;
		point.world_pos.y += rect_center_y;
		point.rect_mesh = RectMinCenterDim(point.world_pos, point.rect_dim);
	}
}

AdjustSpacePointsNonEqualTemperament :: inline (
	points_in_space : [] $S,
	base_world_pos : Vector2F,
	base_note : int,
	row_height : float)
{
	#assert(S == SpacePoint || S == *SpacePoint);
	// Cannot fmod_cycling with denominator 0
	assert(row_height > 0); 

	mod_base_note : int = base_note % points_in_space.count;
	pos_shift : float = points_in_space[mod_base_note].rel_pos.y;
	for * pointer : points_in_space
	{
		point : *SpacePoint;
		#if S == *SpacePoint point = <<pointer;
		else #if S == SpacePoint point = pointer;

		//TODO Could just update world_pos and create the rect in the renderer
		//Obviously this is more efficient for the renderer
		rect_center_y : float = fmod_cycling(point.rel_pos.y - pos_shift, row_height);
		point.world_pos = base_world_pos;
		point.world_pos.y += rect_center_y;
		point.rect_mesh = RectMinCenterDim(point.world_pos, point.rect_dim);
	}
}

//TODO We can remove this one if we never use it since the new one accounts for all cases
//and works for more notes and all tuning_systems
#if 1 {
MakeRatioProportionalPoints :: inline (
	linear : LinearPitchSpace,
	tuning_system : TuningSystem,
	all_tuning_pitches : [] TuningPitch,
	white_color : Vector4F = GREY_DARKER_V,
	black_color : Vector4F = GREY_BLACK_V)
-> [] SpacePoint
{
	array_tuning_pitches : [] TuningPitch =
		ArrayFindAllVarName(all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
	assert(tuning_system.music_pt_count == array_tuning_pitches.count);

	points_in_space : [] SpacePoint = NewArray(array_tuning_pitches.count, SpacePoint, false,, temp);
	for tuning_pitch, point_index : array_tuning_pitches 
	{
		point : SpacePoint;
		point.id = context.ALL_NEXT_IDS.POINT_ID;
		context.ALL_NEXT_IDS.POINT_ID += 1;
		point.dspace_id = linear.dspace_id;
		point.color = white_color;
		//TODO what to do for other tuning systems and music_pt counts?
		if tuning_system.music_pt_count == 12 {
			if point_index == 1 || point_index == 3 || point_index == 6 || point_index == 8 || point_index == 10 {
				point.color = black_color;
			}
		} else if point_index % 2 == 1 {
			point.color = black_color;
		}

		start_ratio : float = RatioToOctaveLinear(tuning_pitch.ratio_from_start);
		length_ratio : float = RatioToOctaveLinear(tuning_pitch.ratio_to_next_music_pt);

		point.int_pos.x = tuning_pitch.music_pt_pos;
		point.world_pos = linear.base_world_pos;
		point.world_pos.y += start_ratio * DEFAULT_LINEAR_SPACE_SIZE.y;
		point_dim : Vector2F = MakeV2F(DEFAULT_LINEAR_SPACE_SIZE.x, DEFAULT_LINEAR_SPACE_SIZE.y * length_ratio);
		point.rect_mesh = RectMinCenterDim(point.world_pos, point_dim);

		// We get the rel_pos from the center of the bottom point
		point.rel_pos = point.world_pos - linear.dspace_world_pos;
		point.dspace_pos = point.rel_pos;

		points_in_space[point_index] = point;
	}
	return points_in_space;
}
}

MakeEqualLinearPoints :: inline (
	linear : LinearPitchSpace,
	tuning_system : TuningSystem,
	orientation : LinearPitchSpaceOrientation = LinearPitchSpaceOrientation.VERTICAL,
	white_color : Vector4F = WHITE_V,
	black_color : Vector4F = GREY_DARKER_V)
-> [] SpacePoint
{
	points_in_space : [..] SpacePoint;
	for point_index : 0..tuning_system.music_pt_count-1 {
		point : SpacePoint;
		point.id = context.ALL_NEXT_IDS.POINT_ID;
		context.ALL_NEXT_IDS.POINT_ID += 1;
		point.dspace_id = linear.dspace_id;
		point.color = white_color;
		//TODO what to do for other tuning systems and music_pt counts?
		if tuning_system.music_pt_count == 12 {
			if point_index == 1 || point_index == 3 || point_index == 6 || point_index == 8 || point_index == 10 {
				point.color = black_color;
			}
		} else if point_index % 2 == 1 {
			point.color = black_color;
		}

		//TODO could set int_pos in here since it is likely consistent
		if linear.orientation == LinearPitchSpaceOrientation.VERTICAL {
			point.world_pos = linear.dspace_world_pos;
			point.world_pos.y += point_index * linear.dspace_point_dim.y;
			//TODO could increase the boundary around the rectangles
			point.rect_mesh = RectCenterDim(point.world_pos, linear.dspace_point_dim - Vector2F.{0,0});
		} 
		else if linear.orientation == LinearPitchSpaceOrientation.HORIZONTAL {
			point.world_pos = linear.dspace_world_pos;
			point.world_pos.x += point_index * linear.dspace_point_dim.x;
			point.rect_mesh = RectCenterDim(point.world_pos, linear.dspace_point_dim - Vector2F.{0,0});
		}

		point.rel_pos = point.world_pos - linear.dspace_world_pos;
		point.dspace_pos = point.rel_pos;
		array_add(*points_in_space, point);
	}
	return points_in_space;
}

/*End of New Space and points Code
*/

/*TODO Old Space and points code can move out at some point with all other old code 
*/
UpdateLinearPitchSpaceData :: struct {
	update_world_pos : bool;
	world_pos : Vector2F;

	update_points : bool;
}

/*TODO 
	passing tuning_system_music_pt_count in here for now but this should depend on linear space
	current size or current tuning system depending on the current linear user settings

	should we split this function in 2 where one function is update points and space and 
	the other is just update linear pitch space

	right now we update the rect_mesh, but once we have a separate rendering mesh,
	we should just update the linear_pitch_space position since the rendering mesh should
	just be drawn relative to the linear_pitch_space

	THIS SHOULD BE DONE AS A DATABASE AND NOT AS A POINTER
*/
UpdateLinearPitchSpace :: inline (
	linear : *LinearPitchSpace,
	tuning_system_music_pt_count : int,
	update : UpdateLinearPitchSpaceData,
	all_space_points : [] SpacePoint)
{
	if update.update_world_pos {
		linear.dspace_world_center = update.world_pos;
		linear.dspace_world_pos = update.world_pos;
		if linear.orientation == LinearPitchSpaceOrientation.VERTICAL {
			linear.transform = Matrix2F_IDENTITY;
			linear.dspace_world_pos.y -= 0.5 * (tuning_system_music_pt_count * linear.dspace_point_dim.y);
			linear.dspace_world_pos.y += 0.5 * linear.dspace_point_dim.y;
			linear.base_world_pos = linear.dspace_world_pos;
			linear.base_world_pos.y -= 0.5 * linear.dspace_point_dim.y;
		} else if linear.orientation == LinearPitchSpaceOrientation.HORIZONTAL {
			linear.transform = ROTATE_NEG90;
			//TODO can we remove one of these if we always start from the base of the rectangle?
			linear.dspace_world_pos.x -= 0.5 * (tuning_system_music_pt_count * linear.dspace_point_dim.x);
			linear.dspace_world_pos.x += 0.5 * linear.dspace_point_dim.x;
			linear.base_world_pos = linear.dspace_world_pos;
			linear.base_world_pos.x -= 0.5 * linear.dspace_point_dim.x;
		}
	}

	if update.update_points {
		points_in_space : [] *SpacePoint = ArrayFindAllPointersByNameId(all_space_points, linear.dspace_id, "dspace_id");
		for point, point_index : points_in_space {
			if linear.orientation == LinearPitchSpaceOrientation.VERTICAL 
			{
				point.world_pos = linear.dspace_world_pos;
				point.world_pos.y += point_index * linear.dspace_point_dim.y;
				point.rect_mesh = RectCenterDim(point.world_pos, linear.dspace_point_dim);
			} 
			else if linear.orientation == LinearPitchSpaceOrientation.HORIZONTAL 
			{
				point.world_pos = linear.dspace_world_pos;
				point.world_pos.x += point_index * linear.dspace_point_dim.x;
				point.rect_mesh = RectCenterDim(point.world_pos, linear.dspace_point_dim);
			}
			point.rel_pos = point.world_pos - linear.dspace_world_pos;
			point.dspace_pos = point.rel_pos;
		}
	}
}

MakeContinuousLinearSpace :: (
	world_pos : Vector2F,
	dspace_dim : Vector2F,
	tuning_system : TuningSystem,
	orientation : LinearPitchSpaceOrientation = LinearPitchSpaceOrientation.VERTICAL)
-> LinearPitchSpace
{
	//TODO rotate based on Matrix2F transform instead of y_up
	linear : LinearPitchSpace;
	linear.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	defer context.ALL_NEXT_IDS.DSPACE_ID += 1;
	linear.dspace_world_center = world_pos;
	linear.dspace_world_pos = world_pos;
	linear.dspace_dim = dspace_dim;
	linear.dspace_point_dim = Vector2F.{0.4,0.4};
	linear.octave_text = "0";
	linear.orientation = orientation;
	if linear.orientation == LinearPitchSpaceOrientation.VERTICAL {
		linear.transform = Matrix2F_IDENTITY;
	} else if linear.orientation == LinearPitchSpaceOrientation.HORIZONTAL {
		linear.transform = ROTATE_NEG90;
	}
	return linear;
}

/*TODO could potentially remove the VERTICAL/HORIZONTAL
	for grouped piano spaces for examples since we know that theyll
	always be vertical spaces
*/
WorldPosToLinearPitchSpacePointIndex :: inline (
	world_pos : Vector2F,
	linear : LinearPitchSpace)
-> int
{
	point_index_float : float = ---;
	if linear.orientation == LinearPitchSpaceOrientation.VERTICAL {
		delta_y : float = world_pos.y - linear.base_world_pos.y;
		point_index_float = delta_y / linear.dspace_point_dim.y;
	}
	else if linear.orientation == LinearPitchSpaceOrientation.HORIZONTAL {
		delta_x : float = world_pos.x - linear.base_world_pos.x;
		point_index_float = delta_x / linear.dspace_point_dim.x;
	}
	point_index_int : int = cast(int) point_index_float;		
	return point_index_int;
}

LinearPitchPointIndexToWorldRect :: inline (
	point_index : int,
	linear : LinearPitchSpace)
-> Rectangle2
{
	world_pos : Vector2F = ---;
	if linear.orientation == LinearPitchSpaceOrientation.VERTICAL {
		world_y : float = linear.dspace_world_pos.y + (point_index * linear.dspace_point_dim.y);
		world_pos = MakeV2F(linear.dspace_world_pos.x, world_y);
	}
	else if linear.orientation == LinearPitchSpaceOrientation.HORIZONTAL {
		world_x : float = linear.dspace_world_pos.x + (point_index * linear.dspace_point_dim.y);
		world_pos = MakeV2F(world_x, linear.dspace_world_pos.y);
	}
	world_rect : Rectangle2 = RectCenterDim(world_pos, linear.dspace_point_dim);
	return world_rect;
}

AsmCreateSpiral :: struct {
	//return values
	ret_dspace_id : int;

	op_space_id : int;
	spiral_type : SpiralType;
	world_pos : Vector2F64;
	tuning_system_id : int;
	pitch_zero_freq : float64;
	//TODO Should we rename these?
	tuning_count : int;
	chord_count : int;
	rotate : float64 = PI64/2;
	is_clockwise : AsmBool = #run ToAsmBool(true);
	radius_size : float64; // Use to adjust spiral_delta size going out
	sr_factor : float64; // Use to adjust inner radius size (although it does effect overall spiral size as well)
	is_in_out : AsmBool = #run ToAsmBool(true);
	sound_float : AsmBool;
	is_loop : AsmBool = #run ToAsmBool(true);
	show_values : AsmBool = #run ToAsmBool(true);
	point_dim : Vector2F64;
	//TODO Do this with a Vector4F64
	// point_color : Vector4F = LIGHT_BROWN;
	osc_wave_type : OscWaveType;

	base_chord : AsmArray(float64);
	base_index : int;
} @LibraryAsmGen
AsmMapSpiral :: struct {
	op_space_id : int;
	dspace_id : int;
	dspace_shape_group : int;
	//This will get grouped by the SpiralSpace.chord_count
	//TODO Reorder this in case we use an array in the game code data
	map_chords : AsmArray(float64);
	//TODO It might be better to just have the player draw these lines
	//themselves with a general draw line function and associate it to
	//dspace and op_space themselves instead of automatically like this.
	//That would avoid the looping problem.
	draw_vl_lines : AsmBool; //bool to draw_vl_lines between each chord.
} @LibraryAsmGen
MapSpiralData :: struct {
	op_space_id : int;
	dspace_id : int;
	dspace_shape_group : int;

	//This will get grouped by the SpiralSpace.chord_count
	//TODO Reorder this in case we use an array in the game code data
	chord_data : int;
	chord_count : int;

	//TODO It might be better to just have the player draw these lines
	//themselves with a general draw line function and associate it to
	//dspace and op_space themselves instead of automatically like this.
	//That would avoid the looping problem.
	draw_vl_lines : int; //bool to draw_vl_lines between each chord.
	//TODO Can add this to finish a loop or leave it up to the user to add.
	// loop_vls_lines : int;
}

/*NOTE : Could generalize this for all 2d voice_leadings in general
maybe except for chord_s2. But still from 1 dspace to another is very interesting.
Like a 2D spiral space voice leading to a chord_s2 voice leading.
Or a circle space to a linear space kind of thing.
*/
SpiralVoiceLeading :: struct {
	dspace_id : int;
	// start_spiral_index : float64;
	// end_spiral_index : float64;
	start_pos : Vector2F;
	end_pos : Vector2F;
}

/*NOTE : This is a convenience function both for consistent reuse AND
also for code abstraction in case we change the way spirals are made by default.
BUT we can still create them with InitSpiralSpace for example.

We return SpiralSpace because then we can just pass in values directly
to the function and not have to worry about it as a pointer.
*/
CreateSpiralInSpace :: inline (
	sp : SpiralSpace,
	op_spec_data : *OpSpaceSpecData) 
-> *SpiralSpace
{
	spiral : *SpiralSpace = array_add(*op_spec_data.all_op_spirals);
	spiral.* = sp;
	spiral.op_space_id = op_spec_data.op_space_id;
	InitSpiralSpace(spiral);

	coll : *CollisionEntity = array_add(*op_spec_data.all_op_collision_entities);
	coll.entity_id = spiral.dspace_id;
	coll.entity_type = EntityType.SPIRAL;
	coll.op_space_id = op_spec_data.op_space_id;
	coll.shape = CollisionShape.CIRCLE;
	coll.circle.pos = spiral.world_center_pos;
	coll.circle.radius = spiral.total_radius;

	return spiral;
}

InitSpiralSpace :: inline (sp : *SpiralSpace) {
	sp.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	context.ALL_NEXT_IDS.DSPACE_ID += 1;
	if sp.spiral_type == SpiralType.PROPER sp.radius_size *= 1.75 / 2;
	if sp.is_in_out {
		sp.in_out_factor = 1.0;
		sp.start_radius = sp.sr_factor*sp.radius_size;
		//TODO Maybe we should just use in_out_factor in the code
		//instead of having the negative mapped in 2 places?
		sp.spiral_delta = sp.radius_size / sp.tuning_count;
	} else {
		sp.in_out_factor = -1.0;
		//sr_factor is for center (like in in_out below) and then chord_count for spiral
		sp.start_radius = (sp.sr_factor+sp.chord_count)*sp.radius_size;
		/*NOTE : Computing this here makes it convenient particular for computing
		spiral pos but also we have to remember to multiple all radius values
		if we need to make some kind of collision adjustment.
		*/
		sp.spiral_delta = -sp.radius_size / sp.tuning_count;
	}
	sp.total_radius = (sp.sr_factor+sp.chord_count)*sp.radius_size + sp.point_dim.y;
}

ValidateSpiral :: inline (
	base_chord : [] float64,
	sp : SpiralSpace)
-> success : bool, error_msg : string
{
	if base_chord.count != sp.chord_count {
		return false, "Error : base_chord.count != sp.chord_count";
	}
	//Otherwise there is no spiral. Can return this as an error eventually.
	if sp.chord_count * sp.tuning_count <= 0 {
		return false, "Error : sp.chord_count * sp.tuning_count <= 0";
	}	
	return true, "";
}
SetSpiralBase :: inline (
	base_chord : [] float64,
	base_index : int,
	sp : *SpiralSpace,
	op_spec_data : *OpSpaceSpecData)
-> success : bool, error_msg : string
{
	success, error_msg := ValidateSpiral(base_chord, sp.*);
	if !success return success, error_msg;

	//TODO To set multiple base points we just create more and then just need to update the
	//base_space_point_id and base_index to whatever we want.
	//NOTE : We then just need to grab the space_point that has this dspace_id and int_pos.x == base_index
	// sp.has_base_points = true;
	// sp.base_space_point_id = context.ALL_NEXT_IDS.POINT_ID;
	sp.base_index = base_index;

	sorted_base_chord := array_copy(base_chord,,temp);
	quick_sort(sorted_base_chord, (f1,f2) => f1 - f2);
	//DOC : To ensure that we have positive values in range for now as the base chord
	//especially in case valid negative values are passed in
	for * sorted_base_chord {
		if it.* < 0 {
			it.* = fmod_cycling(it.*, cast(float64)sp.tuning_count);
		}
	}

	sp.base_chord = array_copy(sorted_base_chord,, op_spec_data.spec_2D_alloc);

	//TODO Should this be temp or context.allocator?
	point_chord := array_copy(sorted_base_chord,, temp);
	roots_of_unity := RootsOfUnity(sp.tuning_count, sp.is_clockwise, sp.rotate, Vector2F,, temp);
	//TODO We could add a value here to increase size of spiral so we
	//could use it more as an instrument. Could add a value but then
	//we would laso have to adjust the radius and number of points everywhere.
	//Also would have to consider how we map music pts to this geometry then.
	for 0..(sp.chord_count*sp.tuning_count)-1 {
		it_mod : int = it % sp.chord_count;
		if it_mod == base_index {
			// point : *SpacePoint = array_add(all_space_points);
			// point.id = context.ALL_NEXT_IDS.POINT_ID;
			// context.ALL_NEXT_IDS.POINT_ID += 1;
			// point.dspace_id = sp.dspace_id;
			// point.world_pos = IndexToSpiralPos(it, sp, roots_of_unity);
			// point.rect_mesh = RectCenterDim(point.world_pos, sp.point_dim);
			// point.color = sp.point_color;
			// // point.int_pos.x = it;
			// point.int_pos.x = 7; //This is 7 for the rendering order
			// //Storing these here for covenience on printing 1-2 values even though spiral point can be n-dimensional
			// point.fun_region_float[0] = point_chord[0];
			// if point_chord.count > 1 {
			// 	point.fun_region_float[1] = point_chord[1];
			// }
			world_pos : Vector2F = IndexToSpiralPos(it, sp, roots_of_unity);

			//ADDING SPACE RECTS DIRECTLY and then we can remove SpacePoint above once this is working.
			rect : *SpaceRect = array_add(*op_spec_data.ass.all_space_rects);
			rect.shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
			context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;
			rect.op_space_id = op_spec_data.op_space_id;
			rect.dspace_id = sp.dspace_id;
			rect.dspace_shape_group = sp.base_shape_group;
			rect.render_order = sp.base_render_order;
			rect.color = sp.point_color;
			rect.rect = RectCenterDim(world_pos, sp.point_dim);
			rect.pitch_set = array_copy(point_chord,, op_spec_data.spec_2D_alloc);
			rect.shape_text = sprint("%", point_chord,, op_spec_data.spec_2D_alloc);

			space_text : *SpaceText = array_add(*op_spec_data.ass.all_space_text);
			space_text.op_space_id = op_spec_data.op_space_id;
			space_text.dspace_id = sp.dspace_id;
			//TODO I think we could store this render_order OR I guess this i the default text op render order
			//Maybe we could store that somewhere as default instead.
			space_text.render_order = 10003;
			//TODO Maybe this should be a different group in case we want to erase it later.
			space_text.dspace_shape_group = sp.base_shape_group;
			space_text.color = WHITE_V;
			// space_text.color = LOW_WHITE_V;
			//TODO Calculate this here if we remove SpacePoint
			space_text.op_pos = world_pos - Vector2F.{0,sp.point_dim.y};

			//TODO Make a function SetSpaceText and reuse for chord_s2, then we can also just memcpy what fits
			//TODO Could also print a list of values here if needed. I think tprint might do it directly
			space_string : string = tprint("%", point_chord[0]);
			SetSpaceText(space_string, space_text);
			//Sanity check but we could just put an if here but max s64 is < 32 chars anyways
			// assert(space_string.count <= space_text.text_chars.count);
			// space_text.text.data = space_text.text_chars.data;
			// space_text.text.count = space_string.count;
			// memcpy(space_text.text.data, space_string.data, space_string.count);

			for * point_chord {
				// rect_value : *SpaceShapeValue = array_add(*ass.all_space_shape_values);
				// rect_value.shape_id = rect.shape_id;
				// rect_value.float_value = it.*;

				// sp_to_value : *SpacePointToValue = array_add(all_space_point_to_value);
				// sp_to_value.space_point_id = point.id;
				// sp_to_value.value = it.*;
				//TODO Remove this if we remove BOOK spiral eventually
				if sp.spiral_type == {
				case .BOOK; it.* = PosMod(it.* - 1, cast(float64) sp.tuning_count);
				case; it.* += 1;
				}			
			}
		}
	}
	return true, "";
}

CreateSpiralPointAndValues :: inline (
	chord : [] float64,
	sp : SpiralSpace,
	all_space_points : *[..] SpacePoint,
	all_space_point_to_value : *[..] SpacePointToValue,
	color : Vector4F = LIGHT_BROWN)
{
	assert(chord.count == sp.chord_count);
	space_point := CreateSpiralPoint(chord[0] * sp.chord_count,
		chord[0], sp, all_space_points, color);
	CreateSpiralPointValues(chord, space_point.id,
		all_space_point_to_value);
}

/*NOTE : We make this with index so we can decide how we want to make the point.
We can externally use all_spiral_base_values or just do it directly. This way keeps
it flexible and consistent in case we decide to change things later.

I AM NOT SURE EXACTLY HOW WE WILL USE THIS, so I am keeping it flexible and general for
now so we can do all cases that are suggested in the book and then we can see how we use it later.

This allows us to put a point anywhere and then associate any values we want to it so the spiral remains flexible.
*/
CreateSpiralPoint :: inline (
	index : float64,
	display_value : float64,
	sp : SpiralSpace,
	all_space_points : *[..] SpacePoint,
	color : Vector4F = LIGHT_BROWN,
	order : int = 8)
-> *SpacePoint
{
	point : *SpacePoint = array_add(all_space_points);
	point.id = context.ALL_NEXT_IDS.POINT_ID;
	context.ALL_NEXT_IDS.POINT_ID += 1;
	point.dspace_id = sp.dspace_id;
	//TODO Could use IndexToSpiralPos but with float and euler's formula instead if we allow that... hmmmm
	//TODO Can grab base_chord from all_spiral_base_values if we need to compute offset values.
	// point.world_pos = ChordToSpiralPoint(float_chord, float_base, 0, sp);
	point.world_pos = FloatIndexToSpiralPos(index, sp);
	point.rect_mesh = RectCenterDim(point.world_pos, sp.point_dim);
	point.color = color;
	//Storing these here for covenience on printing 1-2 values even though spiral point can be n-dimensional
	point.fun_region_float[0] = display_value;
	point.int_pos.x = order;
	return point;
}

CreateSpiralPointValues :: inline (
	chord : [] float64,
	space_point_id : int,
	all_space_point_to_value : *[..] SpacePointToValue)
{
	for chord {
		sp_to_value : *SpacePointToValue = array_add(all_space_point_to_value);
		sp_to_value.space_point_id = space_point_id;
		sp_to_value.value = it;
	}
}

//TODO Can have a separate table that indexes these values eventually
//and then we can remove the space_point_id. Or just have an SoA.
//SoA or separate table index should make this good.
SpacePointToValue :: struct {
	// dspace_id : int;
	space_point_id : int;
	value : float64;

	//TODO Could add an order if needed but we can just sort
	//by value for now since we are using this for fun_region_pos
	//for spirals for now. This generalizes for chord space dimensions
	//as well though.
	// order : int;
}

/*TODO This is not efficient. For example, we could have a separate loop for each type and then
no need for if and can likely remove some calculations as well. Let's see how everything else progresses.
IT IS convenient for different types for now since we have to compute the previous point beforehand to
close the spiral loops.

I THINK ULTIMATELY I MAY JUST WANT PROPER spiral and then we 
can remove a lot of this and maybe put some in the regular code

TODO What if we make the index a float which is what we do in ChordToSpiralPoint
Then we could use euler's formula instead of roots_of_unity and then
we don't have to pass that in.
*/
IndexToSpiralPos :: inline (index : int, sp : SpiralSpace, roots_of_unity : [] Vector2F) -> Vector2F {
	radius_index, point_index := ComputeQuotientAndRemainder2(index, sp.tuning_count);

	//TODO Can allow each method depending on some input params if we want positive or negative to be clockwise
	//and can also can possibly allow rotation by PI/sp.tuning_count or just PI/2
	radius : float;
	if sp.spiral_type == {
	case SpiralType.PROPER;
		//TODO Maybe we should remove spiral_delta altogether and just
		//(sp.in_out_factor * sp.radius_size / sp.tuning_count)
		// spiral_delta : float = sp.radius_size / sp.tuning_count;
		//This draws a proper spiral with radius changing at each step but I don't find it very clear overall
		radius = sp.start_radius + index * sp.spiral_delta;
	case SpiralType.CONCENTRIC_CIRCLE;
		//TODO This does not really work with out_in, since
		//we have to change the radius_size and sr_factor
		//but at least it works for now in all cases with that change
		//This draws positive clockwise
		radius = sp.start_radius + 
			sp.in_out_factor * sp.radius_size * radius_index;
	case SpiralType.BOOK;
		start_radius_index : int = 0;
		max_radius_index : int = sp.chord_count;	
		//Radius from top of circle with positive counter-clockwise like the book
		current_radius_index : int = PosMod(start_radius_index - radius_index, max_radius_index);
		// current_radius_index : int = PosMod(start_radius_index - radius_index - 1, max_radius_index);
		radius = sp.start_radius + sp.radius_size * current_radius_index;
	}

	//TODO We could use eulers formula here to ge the vector without roots of unity instead
	rel_pos   : Vector2F = radius * roots_of_unity[point_index];
	world_pos : Vector2F = sp.world_center_pos + rel_pos;
	return world_pos;
}

//TODO Maybe name this FloatIndexToSpiralPos
//TODO Also likely do both float and float64 for convenience
FloatIndexToSpiralPos :: inline (index : $T, sp : SpiralSpace) -> Vector2F {
//TODO Could just make this float. It is for convenience but relative
//pos is likely always to be 32-bit anyways
#assert(T == float || T == float64);
	// spiral_delta : float = sp.radius_size / sp.tuning_count;
	c : float = 1.0;
	if sp.is_clockwise c = -1.0;
	theta := sp.rotate + c * TAU * (index / sp.tuning_count);
	// theta : float = (PI/2.0) - TAU * (index / sp.tuning_count);
	circle_pos : Vector2F = EulersFormula(cast(float) theta).vector;
	radius : float;
	if sp.spiral_type == SpiralType.PROPER {
	//TODO Each of these points is slightly more out or in. Does it matter?
	#if 1 {
	//TODO Should we mod this one like we do the int one below?
	radius = sp.start_radius + cast(float) index * sp.spiral_delta;
	} else {
	diff_int : int = cast(int) index;
	diff_int = PosMod(diff_int, sp.tuning_count * sp.chord_count);
	radius = sp.start_radius + diff_int * sp.spiral_delta;
	}
	} else {
	tuning_int : int = cast(int) (index / sp.tuning_count);
	tuning_int = PosMod(tuning_int, sp.chord_count);
	radius = sp.start_radius + 
		sp.in_out_factor * sp.radius_size * tuning_int;
	}
	spiral_point : Vector2F = sp.world_center_pos + radius * circle_pos;
	return spiral_point;
}

/*I prefer this over chords. I think I am starting to see that chords
are separate from spiral. Just focus on the index and only use the chords
for audio. Can convert a chord to spiral index but that would just be based
on the base note anyways whic would reduce to this case.
Especially if the base chord is always 0 based then this linear equation
would always be the base case.
*/
BaseValueToSpiralIndex :: inline (
	base_value : float64,
	chord_count : int, 
	base_index : int = 0) 
-> float64 
{
	spiral_index : float64 = base_value * chord_count + base_index;
	return spiral_index;
}

ChordToSpiralIndex :: inline (
	chord : [] $T,
	base_chord : [] T,
	//TODO We could just pass in base_chords and then check the deltas between the notes.
	//I guess we would have to do that anyways outside to find the actual index.
	//TODO Could calculate the base_index from inter_onsets later if needed OR even just pass in the inter-onsets
	//instead so we can just compare those directly. Let's see what is more convenient during usage.
	base_index : int)
-> T
{
#assert(T == int || T == float || T == float64);
	//TODO This is not necessary but sanity check for now.
	assert(chord.count == base_chord.count);
	assert(base_index < chord.count);

	//TODO This allows us to adjust based on base_chord and base_index but will the base_chord always be 0
	//and the base_index always be given externally? Eg If base_chord is always 0, then we don't need it.
	vl_diff : T = chord.count * (chord[0] - base_chord[0]) + base_index;
	return vl_diff;
}


ChordToSpiralPoint :: inline (
	chord : [] $T,
	base_chord : [] T,
	base_index : int, //TODO This is stored in spiral so no need to add both...
	sp : SpiralSpace)
-> Vector2F
{
#assert(T == float || T == float64);
	vl_diff := ChordToSpiralIndex(chord, base_chord, base_index);
	spiral_point := FloatIndexToSpiralPos(vl_diff, sp);
	return spiral_point;
}


PitchSpace2D :: struct {
	dspace_id : int;
	//TODO Should this be float64 eventually for all world_pos?
	bottom_left_point_pos : Vector2F;
	base_point_count : int;
	octave_count : int;
	inter_point_gap : Vector2F;
	point_dim : Vector2F;
	osc_waves : [2] OscWave;
}

//RenameTo ChordSpacePoints3D2D and the 3D one to ChordSpacePoints3D
FunRegionData2D :: struct {
	linear_point_count : int;
	start_index : int;
	fun_region_pos_count : int;
}

//TODO should this be in separate tables?
ChordSpace2State :: enum {
	NONE;
	VOICE_LEADING;
}

#if 0 {
WorldBasisCoordinates :: struct {
	axis_0, axis_1 : Vector2F;
}
ChangeBasis :: inline (
	v : Vector2F,
	basis : WorldBasisCoordinates)
-> Vector2F 
{
	change_basis : Vector2F = v.x * basis.axis_0 + v.y * basis.axis_1;
	return change_basis;
}

WorldPosDiffToVoiceSizeUnit :: inline (
	world_pos_0 : Vector2F,
	world_pos_1 : Vector2F,
	world_to_voice : WorldBasisCoordinates)
-> [2] float 
{
	world_diff : Vector2F = world_pos_1 - world_pos_0;
	diff_voice : Vector2F = ChangeBasis(world_diff, world_to_voice);
	return diff_voice.component;
}
}

WorldPosDiffToVoiceSize :: inline (
	world_pos_0 : Vector2F,
	world_pos_1 : Vector2F,
	world_to_voice : Matrix2F)
-> Vector2F 
{
	world_diff : Vector2F = world_pos_1 - world_pos_0;
	diff_voice : Vector2F = world_to_voice * world_diff;
	return diff_voice;
}

GetCurrentWorldToVoiceMatrix :: inline (chord_s2 : ChordSpace2) -> Matrix2F {
	if chord_s2.swapped_matrix_flag {
		return chord_s2.swapped_world_to_voice;
	}
	return chord_s2.world_to_invariant_matrix;
}

GetWorldToVoiceMatrixSwapFlag :: inline (chord_s2 : ChordSpace2, should_swap : bool) -> Matrix2F {
	if should_swap {
		return chord_s2.swapped_world_to_voice;
	}
	return chord_s2.world_to_invariant_matrix;
}

//TODO Should we use this everywhere now? When we change x_index
//to float64 then it will be easier to update for sure.
MemoryUnit :: struct {
	x_index : int;
	//TODO We want this eventually so we can set things to be
	//in between memory units to simplify rhythmic structures.
	// x_index : float64;
	row_index : int;
}

//TODO Should this be specific to ChordS2?
//TODO Should this be merge with MemoryUnitToDSpace?
//TODO OR replace MemoryUnitToDSpace with this since this 
//considers voice_leadings. We may not use vls for linear and circle
//but probably will want something for spirals so we could
//just have 1 array with all MemoryUnitToDSpace
//and then maybe add a dspace_type here later if needed.
//TODO Rename MemoryOrderedToSpace and can likely use for spirals
MemoryUnitToChordSpace :: struct {
	dspace_id : int;

	//TODO Should this be memory_index instead?
	//Curently we use x and row index because this allows
	//for easier checks in Voice leading algorithms.
	//However, it is less efficient since we have an
	//extra int in here.
	// memory_index : int;
	x_index : int;
	row_index : int;

	//Note : order is used in case we have we want multiple
	//memory_units for the same vl point in the chord_space
	//This is dealt with by MemoryUnitsToVoiceLeadings
	order : int;
	//vl_index is used for multiple voice_leadings per chord_space
	vl_index : int;
}

//TODO Should likely replace this with MemoryUnitToDSpace
MakeMemoryUnitToChordSpace :: inline (
	dspace_id : int,
	row_index : int,
	x_index : int,
	order : int,
	vl_index : int = 0) 
-> MemoryUnitToChordSpace
{
	mem_to_chord : MemoryUnitToChordSpace = ---;
	mem_to_chord.dspace_id = dspace_id;
	mem_to_chord.x_index = x_index;
	mem_to_chord.row_index = row_index;
	mem_to_chord.order = order;
	mem_to_chord.vl_index = vl_index;
	return mem_to_chord;
}

MakeMemoryUnitToChordSpaceMemIndex :: inline (
	dspace_id : int,
	memory_index : int,
	row_size : int,
	order : int) 
-> MemoryUnitToChordSpace
{
	memory_unit_to_chord_s2 : MemoryUnitToChordSpace = ---;
	memory_unit_to_chord_s2.dspace_id = dspace_id;

	x_index, row_index := ComputeXAndRowIndex(memory_index, row_size);
	memory_unit_to_chord_s2.x_index = x_index;
	memory_unit_to_chord_s2.row_index = row_index;

	memory_unit_to_chord_s2.order = order;
	return memory_unit_to_chord_s2;
}

//TODO Feels like we can genericize this kind of search based on the values we're sorting by.
SortMapMem :: inline (m1 : MemoryUnitToChordSpace, m2 : MemoryUnitToChordSpace) -> int {
	sv : int = m1.dspace_id - m2.dspace_id;
	if sv == 0 sv = m1.vl_index - m2.vl_index;
	if sv == 0 sv = m1.order - m2.order;
	return sv;
}

MusicPtsByOrder :: struct {
	order : int;
	music_pts : [] MusicPoint;
}


/*Note : this is the code directly transfered for chord_s3
	can be split up and moved around later once it runs in game
*/
#if 1 {
/*TODO these should be moved into math or render_group
	or eventually a separate 3D_rendering file
*/
//TODO should this just me stored as a temp_transform in each Cube struct?
ComputeTempRotatedGrid3DTransform :: inline (
	cube_data : SpacePoint3D, 
	grid_3D : ChordSpace3) 
-> Matrix4x3F 
{
	// rotate_pos : Vector3F = (grid_3D.mouse_rotate * grid_3D.temp_mouse_rotate * 
	// 	(GetTranslation(cube_data.data.transform) - center)) + center;
	// rotate_transform : Matrix4x3F = MultiplyTransform(grid_3D.mouse_rotate * grid_3D.temp_mouse_rotate, cube_data.data.transform);
	/**
		Multiply objects and grids with Quaternions up till this point and then set the rotation matrix
		only once here before taking the inverse of the camera transform

		Would also multiply the set rotation matrix by the camera transform. Therefore,
		we would not store the camera rotation in the transform but only in the quaternion
		and pass it at the end here
	**/
	rotate_pos : Vector3F = RotatedGrid3DPosition(cube_data.rel_pos, grid_3D);
	rotate_transform := Matrix4x3F_Identity; 
	UpdateTranslation(*rotate_transform, rotate_pos);
	//This allows for specific cube rotation. We can make a separate one for that since it requires the storage of the rotation matrix
	//Or set a fetch transform matrix bool and then go and get that if it is set
	// rotate_transform : Matrix4x3F = cube_data.data.transform;
	// UpdateTranslation(*rotate_transform, rotate_pos);
	return rotate_transform;
}

RotatedRelPosInChordS3 :: inline (
	rel_pos : Vector3F,
	chord_s3 : ChordSpace3)
-> Vector3F 
{
	rotate_pos : Vector3F = (chord_s3.mouse_rotate * chord_s3.temp_mouse_rotate *
		(rel_pos - chord_s3.center_of_rotation)) + chord_s3.center_of_rotation;
	return rotate_pos;	
}

//TODO We could just pass in char width and height so this is reusable without the text editor data
Text3DBackgroundRect :: inline (
	text : string, 
	text_pos : Vector2F,
	pixels_per_square : float, 
	ted : TextEditorData) 
-> Rectangle2 
{
	rect_dim := Vector2F.{text.count*ted.code_font_1_char_width_world,
		ted.char_height / pixels_per_square};
	text_adjusted_pos : Vector2F = text_pos + Vector2F.{0.5*rect_dim.x,-0.15*rect_dim.y};
	//0.45 seemed more centered for 1 char but I think its good enough like this
	// text_adjusted_pos : Vector2F = text_formatted_pos + Vector2F.{0.45*rect_dim.x,-0.15*rect_dim.y};
	rect_formatted : Rectangle2 = RectCenterDim(text_adjusted_pos, rect_dim);
	// rect_formatted = RectCenterDim(text_formatted_pos + Vector2F.{0.3,-0.15}, Vector2F.{1,1});
	return rect_formatted;
}

#if 0 {
SortVisibleSpacePoints :: inline (s1 : SpacePoint3D, s2 : SpacePoint3D) -> int {
	sort_value : int = s1.dspace_id - s2.dspace_id;
	if sort_value == 0 sort_value = cast(int) s2.render_solid_cube - cast(int) s1.render_solid_cube;
	return sort_value;
}
}

/*DOC : We pass in an allocator here to allocate all the values needed for the 3d space points fr poses and pitch sets.

TODO Ultimately, we can just put this for the dynamic library and then people can reuse the loop and update it as they
like and likely that would provide a more efficient way to filter through dimension >= 7 in 12 equal temperament for example
*/
ChordSpacePoints3DWithFilter :: inline (
	chord_dim : int,
	tuning_system_count : int,
	cs_filters : [] CSFilter,
	cs_filter_aggregate : ChordSpaceFilterAggregate,
	csp : *[..] SpacePoint3D)
{
	p_loops : PermutationLoops;
	p_loops.loop_count = chord_dim;
	p_loops.start_value = -tuning_system_count;
	p_loops.end_value = tuning_system_count;
	new_fun_pos := NewArray(chord_dim, float64,,temp);
	for fr_pos : p_loops {
		is_non_descending_order : bool = true;
		for 0..p_loops.loop_count-2 {
			is_non_descending_order &&= fr_pos[it] <= fr_pos[it+1];
		}
		is_non_descending_order &&= fr_pos[p_loops.loop_count-1] <= fr_pos[0] + tuning_system_count;

		x_sum : int = ArraySum(fr_pos);
		sum_in_bounds : bool = x_sum >= 0 && x_sum < tuning_system_count;

		//TODO Can use this to filter out specific cross section although we 
		//do these with the generalized filters now.
		// cross_section_sum : bool = x_sum == 0;

		// for x1 : -tsc..tsc for x2 : -tsc..tsc for x3 : -tsc..tsc 
		// if x[0] <= x[1] && x[1] <= x[2] && x[2] <= x[0] + tsc &&
		// 	// x[0] + x[1] + x[2] == 0
		// 	x[0] + x[1] + x[2] >= 0 && x[0] + x[1] + x[2] < tsc
		// {
		if is_non_descending_order && sum_in_bounds {
			for fr_pos new_fun_pos[it_index] = cast(float64) it;
			if FilterChordSpacePoints(new_fun_pos, tuning_system_count, cs_filters, cs_filter_aggregate) {
				sp3 : *SpacePoint3D = array_add(csp);
				//TODO Do we need to set an id here anymore? Remove this if we don't use it.
				//We could set a separate id for each
				sp3.id = context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID;
				defer context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID += 1;
				UpdateSpacePoint3D(sp3, tuning_system_count, new_fun_pos);
			}
		}
	}
}

/*TODO keeping this here since we
	could return another Grid3D type for other grid_3ds such as scales, etc...
*/
//TODO could overload with a function that passes in transforms directly if needed
//TODO could pass in viewport directly if we separate 2D and 3D grid structs
MakeGrid3D :: (
	chord_s3_world_pos : Vector2F, 
	chord_s3_dim : Vector2F, 
    depth : float, n : float, f : float, 
    visible_space_points_3D : *[..] SpacePoint3D,
    cube_poses : [] Vector3F, colors : [] Vector4F = .[],
    cam_start : Vector3F = Vector3F.{}, 
    center_of_rotation : Vector3F = Vector3F.{}) 
-> ChordSpace3 
{
	grid_3D : ChordSpace3;
	grid_3D.dspace_id = context.ALL_NEXT_IDS.NEXT_CHORD_S3_ID;
	defer context.ALL_NEXT_IDS.NEXT_CHORD_S3_ID += 1;
	grid_3D.viewport = MakeViewportFullDim(chord_s3_dim, depth);
	//Note : without depth precision
	// grid_3D.p_frustum = MakeFrustumProjectionWithG(grid_3D.viewport.g, grid_3D.viewport.s, n, f);
	//Note : Depth precision adds floating point precision farther away and pre inverts z for the depth buffer
	/*Note : VIEWPORT G AND S are used in p_frustum here in order
	to do appropriate clipping in
	*/
	grid_3D.p_frustum = MakeFrustumProjectionDepthPrecisionWithG(grid_3D.viewport.g, grid_3D.viewport.s, n, f);
	// grid_3D.cam_transform = Matrix3F_Identity;
	grid_3D.cam_trans = MakeMatrix4x3F(Matrix3F_Identity, cam_start);
	grid_3D.mouse_rotate = Matrix3F_Identity;
	grid_3D.temp_mouse_rotate = Matrix3F_Identity;
	grid_3D.temp_cam_rotate = Matrix3F_Identity;
	grid_3D.center_of_rotation = center_of_rotation;
	grid_3D.chord_s3_world_pos = chord_s3_world_pos;
	grid_3D.chord_s3_dim = chord_s3_dim;

	for pos, pos_index : cube_poses {
		space_point_3D : SpacePoint3D;
		space_point_3D.id = context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID;
		defer context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID += 1;
		// space_point_3D.dspace_id = grid_3D.dspace_id;
		space_point_3D.rel_pos = pos;
		// space_point_3D.data.mesh = CUBE_TRI_FACE;
		// space_point_3D.data.transform = MakeMatrix4x3F(Matrix3F_Identity, pos);
		// if colors.count > 0 for * face : space_point_3D.data.mesh.faces {
		// 	face.color = colors[pos_index % colors.count];
		// }
		array_add(visible_space_points_3D, space_point_3D);
	}		
	return grid_3D;
}

/*Note : This is a copy MakeGrid3D specific for pitch_s3.

TODO I think we can generalize this to all dimensions and just pass in chord_dim.
This is so incomprehensible in 3D unlikely to use it anyways for anything other than showing it is incomprehensible.
*/
MakePitchSpace3 :: inline (
	chord_s3_world_pos : Vector2F, 
	chord_s3_dim : Vector2F, 
	depth : float, n : float, f : float, 
	visible_space_points_3D : *[..] SpacePoint3D,
	cam_start : Vector3F = Vector3F.{}, 
	center_of_rotation : Vector3F = Vector3F.{}) 
-> ChordSpace3 
{
	pitch_s3 : ChordSpace3;
	pitch_s3.dspace_id = context.ALL_NEXT_IDS.NEXT_CHORD_S3_ID;
	defer context.ALL_NEXT_IDS.NEXT_CHORD_S3_ID += 1;
	pitch_s3.viewport = MakeViewportFullDim(chord_s3_dim, depth);
	//Note : without depth precision
	// pitch_s3.p_frustum = MakeFrustumProjectionWithG(pitch_s3.viewport.g, pitch_s3.viewport.s, n, f);
	//Note : Depth precision adds floating point precision farther away and pre inverts z for the depth buffer
	/*Note : VIEWPORT G AND S are used in p_frustum here in order
	to do appropriate clipping in
	*/
	pitch_s3.p_frustum = MakeFrustumProjectionDepthPrecisionWithG(pitch_s3.viewport.g, pitch_s3.viewport.s, n, f);
	// pitch_s3.cam_transform = Matrix3F_Identity;
	pitch_s3.cam_trans = MakeMatrix4x3F(Matrix3F_Identity, cam_start);
	pitch_s3.mouse_rotate = Matrix3F_Identity;
	pitch_s3.temp_mouse_rotate = Matrix3F_Identity;
	pitch_s3.temp_cam_rotate = Matrix3F_Identity;
	pitch_s3.center_of_rotation = center_of_rotation;
	pitch_s3.chord_s3_world_pos = chord_s3_world_pos;
	pitch_s3.chord_s3_dim = chord_s3_dim;
	pitch_s3.higher_dim = 3;
	pitch_s3.osc_waves = NewArray(3, OscWave,, context.allocator);

	//TODO Need to pass this in and store in ChordSpace3
	bp_count : int = 12;
	//TODO We could add a filter here too like with ChordSpace3
	for x : 0..bp_count-1 for y : 0..bp_count-1 for z : 0..bp_count-1 {
		point_3D : *SpacePoint3D = array_add(visible_space_points_3D);
		point_3D.id = context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID;
		defer context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID += 1;
		// point_3D.dspace_id = pitch_s3.dspace_id;
		// point_3D.fun_region_size = 3;
		point_3D.fun_region = NewArray(3, float64);
		point_3D.fun_region[0] = cast(float64) x;
		point_3D.fun_region[1] = cast(float64) y;
		point_3D.fun_region[2] = cast(float64) z;
		point_3D.rel_pos = FunRegionFloatPosToRelPos(point_3D.fun_region, bp_count);
		// point_3D.data.transform = MakeMatrix4x3F(Matrix3F_Identity, point_3D.rel_pos);
		//TODO fun_region_pos should be permutation index and then
		//can calculate based on dimension and index
		//TODO fun_region_float then we cant, so we need to store
		//it in a separte array since it can be anything
		// for point_3D.fun_region point_3D.fun_region_float[it_index] = it;

		//TODO Can set this but this was completely incomprehensible imo.
		//Could be good as a demonstration i guess...
		#if 0 {
		if IsOnAxis(float64.[1.0,3.0,6.0,8.0,10.0], point_3D.fun_region, cast(float64) bp_count) {
			point_3D.color = GREY_BLACK_V;
		} else {
			point_3D.color = GREY_DARKER_V;
		}
		}

		//TODO Need to remove the Cube from SpacePoint3D
		// point_3D.data.mesh = CUBE_TRI_FACE;
		// point_3D.data.transform = MakeMatrix4x3F(Matrix3F_Identity, pos);
		// for * face : point_3D.data.mesh.faces {
		// 	face.color = color;
		// }
	}		
	return pitch_s3;
}


valid_chord_space_filters :: ChordSpaceFilterType.[.SUM];
UpdateOpSpacePointsByFilter :: inline (
	csp : ChordSpacePoints3D,
	op_space_points_3D : *[..] SpacePoint3D,
	cs_filters : [] CSFilter,
	cs_filter_aggregate : ChordSpaceFilterAggregate)
{
	//TODO We do this to avoid large updates with filters that cannot be updated BUT
	//we could just leave it and let it update anyways if that is simpler since it will
	//still work just have to re-filter all of the values which seems unnecessary.
	//ALSO this avoid filtering when we don't need to for example when we update filter with input mappings
	//then this won't do anything if we don't have a valid filter but instead just have custom points for example
	is_update_filter : bool = false;
	for filter : cs_filters {
		for valid_type : valid_chord_space_filters if valid_type == filter.filter_type {
			is_update_filter = true;
			break filter;
		}
	}
	if !is_update_filter {
		// print("Filter types % not updateable.\n", cs_filters);
    	return;
	}

	Remove3DPointsWithFilter(op_space_points_3D);
	FilterCS3D(csp, op_space_points_3D, cs_filters, cs_filter_aggregate);
}

FunRegionPosToRelPos :: inline (
	fun_region_pos : Vector3I)
-> Vector3F
{
	rel_pos : Vector3F = 5.0 *
		MakeV3F(cast(float) fun_region_pos.x, 
				cast(float) fun_region_pos.y, 
				cast(float) fun_region_pos.z);

	return rel_pos;
}

//TODO Could have an inverse RelPosToFunRegionPos,
//but we would need x4 in the 4D case due to the mixing of multiplication.
//TODO Can we put this in the fun_region_pos array?
// $chord_dim : int) 
/*TODO This subtraction is 1 way to adjust but maybe it can be done better.
I tested with up to 53-ET with the subtraction. CAN ALSO MOVE THE CAMERA. Can try both
Consider that we want to keep things close to 0 remove 32-bit float error.
We only want this because the space increases so the filter seems further away.
I think it is better to adjust the camera z based on the lp_count on creations. 
Let's try both for a bit and see how it is.
*/	
FunRegionFloatPosToRelPos :: inline (
	fun_region_pos : [$chord_dim] float,
	//TODO I pased this in here but not sure if it does anything. Might be best to just move the camera to wherever
	//the points end up appearing in the op_space. Could also pass in chord_s3 if needed.
	lp_count : int)
-> Vector3F
{
	// lp_offset : float = lp_count - 12.0;
	// lp_factor : float = (lp_count - 12.0);
	rel_pos : Vector3F = 5.0 *
		MakeV3F(fun_region_pos[0],
				fun_region_pos[1],
				fun_region_pos[2]);
			// - 2.0*Vector3F.{0,0,lp_factor};

	#if chord_dim == 4 {
	rel_pos += fun_region_pos[3] * Vector3F.{1,1,0};
	}
	return rel_pos;
}

//TODO Should only have 1 of these i think or also return
//a 64-bit float vector to maintain world_pos as float64
FunRegionFloatPosToRelPos :: inline (
	fun_region_pos : [$chord_dim] float64,
	lp_count : int)
-> Vector3F
{
	// lp_offset : float = lp_count - 12.0;
	// lp_factor : float = (lp_count - 12.0);
	rel_pos : Vector3F = 5.0 *
		MakeV3F(
			cast(float) fun_region_pos[0],
			cast(float) fun_region_pos[1],
			cast(float) fun_region_pos[2]);
		// - 2.0*Vector3F.{0,0,lp_factor};

	#if chord_dim == 4 {
	rel_pos += (cast(float) fun_region_pos[3]) * Vector3F.{1,1,0};
	}
	return rel_pos;
}

FunRegionPosToRelPos :: inline (
	fun_region_pos : Vector3F) 
-> Vector3F
{
	rel_pos : Vector3F = 5.0 * fun_region_pos;
	return rel_pos;
}

//TODO use this for chord_s3 vl_line_segment generation
FunRegionPosToWorldPos :: inline (
	fun_region_pos : Vector3I,
	chord_s3 : ChordSpace3) 
-> Vector3F
{	
	rel_pos : Vector3F = FunRegionPosToRelPos(fun_region_pos);
	rotate_pos : Vector3F = RotatedRelPosInChordS3(rel_pos, chord_s3);
	return rotate_pos;
}

FunRegionPosToWorldPos :: inline (
	fun_region_pos : Vector3F,
	chord_s3 : ChordSpace3) 
-> Vector3F
{	
	rel_pos : Vector3F = FunRegionPosToRelPos(fun_region_pos);
	rotate_pos : Vector3F = RotatedRelPosInChordS3(rel_pos, chord_s3);
	return rotate_pos;
}

//TODO should this be split up and put into thegame_render_group?
Cube :: struct {
	//TODO should we move this all into grid_pos translation and other transforms?
	//TODO This can be removed if we never rotate the cubes themselves
	transform : Matrix4x3F;
	//TODO can this just be a pointer and then we store color separately?
	// mesh : CubeTriMesh; //for different colors if needed
	//TODO would storing all outgoing edges here work?
	//TODO move chord3 out once we use regular music_pts
	//and audio_music_pts for 
	//We can remove this if we just include 1 in ChordSpace3 instead
	//Then I think we can remove Cube from SpacePoint3D which is a lot of memory
	chord3 : Chord3; //TODO array for multiple octaves?
}

//TODO replace this with something like VoiceLeadingLineSegment3D
GridEdge3D :: struct {
	dspace_id : int;

	//TODO update these to be space_point_ids like in VoiceLeadingLineSegment2D
	vert_0 : *SpacePoint3D;
	vert_1 : *SpacePoint3D;

	//TODO this should be an id for rendering and collision
	//TODO change name to shape or something else
	//or replace directly with mesh_id, collision_id
	//or just separate table entirely
	shape : Cube;
}

Chord3 :: Chord(4, Vector3F);
Chord2 :: Chord(2, Vector2F);
Chord1 :: Chord(1, Vector2F);
Chord :: struct($size : int, $note_pos_type : Type) {
	// chord_on : bool;
	chord_size : int;
	waves : [size] OscWave;
	// chord_pos : note_pos_type;
	// timer : float;
	// text : string;
}
}

#if 0 {
RotatedGrid3DPosition :: inline (cube_data : SpacePoint3D, grid_3D : ChordSpace3) -> Vector3F {
	rotate_pos : Vector3F = (grid_3D.mouse_rotate * grid_3D.temp_mouse_rotate *
		(cube_data.rel_pos - grid_3D.center_of_rotation)) + grid_3D.center_of_rotation;
	return rotate_pos;	
}
}

OpGridPosToStartPulseCoord :: inline (op_grid_pos_x : int, dspace_set_count : int) -> int
{
	pulse_coord : int = round_to_int(0.5 * op_grid_pos_x * dspace_set_count);
	return pulse_coord;
}

CirclePoint :: struct {
	dspace_id : int;
	music_pt_int : int;
}

BEAT_PITCH_OFFSET_SIZE_FACTOR :: 0.4;

/*TODO technically we can reuse RenderMusicPt here but
since we have no need for the 2D rectangle or possibly the id
then we will keep them separate since, overall, it seems like it 
makes sense to separate 2D and 3D
*/
RenderMusicPt3D :: struct {
	//TODO do we really need a separate id
	id : int;
	//TODO caching in here for now but can be removed
	//and get dspace_id from SpacePoint
	//TODO should we rename dspace_id to chord_s3_id?
	//and do this everywhere overall since these dspace_ids
	//don't really have to be the same anymore...
	dspace_id : int;
	space_point_3D_id : int;
	// music_pt_set_id : int;

	//Note : we don't need a mesh in here since we can just fetch
	//from the visible_space_points_3D
	// cube_mesh : Cube;
	//TODO could store a separate rect in SoA to check mouse intersection
	
	//MusicPt : x - beat, y - pitch (or vice-versa)
	//TODO should this be in MusicPoint
	// beat_pitch_offset : Vector2F;

	//TODO can have a flags in here or voice data to know if music_pt is previously held
	//TODO for audio would need to know which synth osc wave to hold back and forward from
	// music_pt_held_back : bool;
	// music_pt_held_forward : bool;
	//TODO store start and end beat in here?
	//TODO for rhythm to we have previous beat music_pt check for held music_pts here?
}

MakeRenderMusicPt3D :: inline (
	dspace_id : int,
	space_point_3D_id : int)
-> RenderMusicPt3D
{
	render_music_pt_3D : RenderMusicPt3D = ---;
	render_music_pt_3D.id = context.ALL_NEXT_IDS.NEXT_RENDER_MUSIC_PT_3D;
	defer context.ALL_NEXT_IDS.NEXT_RENDER_MUSIC_PT_3D += 1;
	render_music_pt_3D.dspace_id = dspace_id;
	render_music_pt_3D.space_point_3D_id = space_point_3D_id;
	return render_music_pt_3D;
}

InternalRowMessage :: struct {
	message_id : int;
	using value : union {
		int_value : int;
		float_value : float64;
	}
}
MessageSimpleSynth :: inline (synth : *SimpleSynth, row_msg : InternalRowMessage) {
	if row_msg.message_id == {
	case 0; synth.volume = cast(float) row_msg.float_value;
	case 1; synth.envelope.attack_seconds = cast(float) row_msg.float_value;
	}
}

/*TODO this concept should be fleshed out more so that
	all the base_linear_spaces and scales and other rules
	are positioned relative to the music_lane their in

	do we even need this as a separate concept or is
*/
MusicLane :: struct {
	id : int;
	//TODO Can likely remove this now that we have only 1 type of music_lane
	music_lane_type : MusicLaneType;
	//TODO Right now pitch always comes first.
	//Should we allow this to be changeable?
	// first_row_world_pos : Vector2F;

	//TODO This should likely be pulled out into
	//a separate array like SoA. Then the string 
	//memory management would be easier as well.
	//String literals could potentially even have
	//their own allocator.
	lane_name : string;
	// music_lane_pos : int;
	//TODO order needed when we have multiple music_lanes
	//to know where to render them spatially
	//can therefore keep the array sorted by order
	// order : int;
	// next_pitch_world_start_pos : Vector2F;
	// next_rhythm_world_start_pos : Vector2F;
	//TODO this could be adjustable based on how many
	//note we want to see at once
	// world_height : float;
}


MakeMusicLane :: inline (
	music_lane_type : MusicLaneType = MusicLaneType.DEFAULT,
	lane_name : string = "") 
-> MusicLane 
{
	music_lane : MusicLane;
	music_lane.id = context.ALL_NEXT_IDS.NEXT_MUSIC_LANE_ID;
	defer context.ALL_NEXT_IDS.NEXT_MUSIC_LANE_ID += 1;
	music_lane.music_lane_type = music_lane_type;
	// music_lane.first_row_world_pos = start_world_pos;
	music_lane.lane_name = copy_string(lane_name);
	return music_lane;	
}


GetRowXStart :: inline (row : MusicLaneRow, memory_unit_width : float) -> float {
	x_start : float = row.row_world_base_start.x - 0.5*memory_unit_width;
	return x_start;
}
GetPlayPosWorldX :: inline (
	row : MusicLaneRow,
	x_float : float64,
	memory_unit_width : float) 
-> float 
{
	play_pos_x : float = GetRowXStart(row, memory_unit_width);
	play_pos_x += cast(float) (x_float * memory_unit_width);
	return play_pos_x;
}



RowViewType :: enum {
	ROW_VIEW_LINEAR;
	//TODO This should only allow octave view
	//since otherwise points would not be aligned
	ROW_VIEW_MODULO;
}

//TODO Should we still create lane or just have rows 
//TODO Should we rename to CreateNextMusicRow/CreateNextBaseMusicRow and only allow that and then inserting will be equivalent to
//creating and moving it up to that position or we could have a convenience function for that specifically if needed
//since we would just have to update all the music_pt indices from there.
//TODO FROM HERE ADd mspace_id to this and then also get_or_create_mspace by name so it's unique to the string
//and we can recreate when recompiling and then either do clear or not
CreateMusicRow :: inline (create_row_data : CreateRowData, all_data : *AllData) -> MusicLaneRow {
	return CreateMusicRow(
		create_row_data,
		all_data.all_mspace_data,
		all_data.global_rules,
		all_data.all_tuning_systems,
		all_data.all_tuning_pitches,
		*all_data.all_linear_to_tuning_system,
		*all_data.all_linear_pitch_spaces,
		*all_data.all_space_points); 
}

CreateOpLinearRow :: inline (create_row_data : CreateRowData, all_data : *AllData) -> MusicLaneRow {
	//TODO Remove this once the new way is working.
	// row : MusicLaneRow = MakeMusicLaneRow(DEFAULT_MUSIC_LANE_ID, RowSystemType.internal_pitch, MusicLaneType.MEMORY, 
	// 	next_row_world_base_pos, next_row_index, create_row_data.row_height, use_create_row_data = true, create_row_data);
	row : *MusicLaneRow = array_add(*all_data.all_op_linear_rows);
	row.id = context.ALL_NEXT_IDS.NEXT_OP_LINEAR_ROW_ID;
	context.ALL_NEXT_IDS.NEXT_OP_LINEAR_ROW_ID += 1;
	//TODO We could make this one struct so we only have to copy once
	//and we can then reuse it everywhere.
	row.row_world_base_start = create_row_data.op_world_pos;
	row.row_height = create_row_data.row_height;
	row.octave_height = create_row_data.octave_height;
	row.x_point_width = create_row_data.x_point_width;
	row.op_row_type = create_row_data.op_row_type;
	row.copy_music_row_id = create_row_data.copy_music_row_id;
	// row.music_lane_id = music_lane_id;
	//TODO If we want to be able to play a linear row directly (maybe with mouse-hover or mouse-hover and click)
	//then we can use something like this to set how we want the row to sound. This could be a good idea for hearing
	//different notes with specific sounds for example either with midi or internal pitch.
	row.row_system_type = create_row_data.row_system_type;
	// row.row_midi_data = create_row_data.row_midi_data;
	// row.sound_on = create_row_data.sound_on;
	row.is_muted_row = create_row_data.muted_row;

	last_section_x : int = 0;
	if row.op_row_type == OpRowType.COPY_MUSIC_ROW {
		music_row : MusicLaneRow = ArrayFindFirstByNameId(all_data.all_mspace_data[0].all_music_lane_rows, 
			row.copy_music_row_id, "id");
		row.total_row_index = music_row.total_row_index;

		//Need to find last section for the collision rect width
		for all_data.all_mspace_data[0].all_section_to_row if it.row_id == row.copy_music_row_id {
			if it.end_x > last_section_x {
				last_section_x = it.end_x;
			}
		}
	} else {
		for row_section : create_row_data.row_section_data {
			// linear_tuning : LinearToTuningSystem = 
			// 	GetOrCreateLinearTuning(row_section.tuning_system_id, row_section.linear_view, all_data);
			linear_tuning : LinearToTuningSystem = GetOrCreateLinearTuning(
				row_section.tuning_system_id, 
				row_section.linear_view, 
				all_data.all_tuning_systems, 
				all_data.all_tuning_pitches,
				*all_data.all_linear_to_tuning_system,
				*all_data.all_linear_pitch_spaces,
				*all_data.all_space_points);

			section : *SectionToRow = array_add(*all_data.all_op_section_to_row);
			//TODO Should this be index or id? Id would allow row movement without having to update this section.
			section.row_id = row.id;
			section.dspace_id = linear_tuning.dspace_id;
			section.start_x = last_section_x;
			section.end_x = last_section_x + row_section.x_length;
			section.tuning_system_id = linear_tuning.tuning_system_id;

			//TODO Should check that last_section_x == global row_size after this loop i think.
			//So we would have to set the row_size beforehand OR take the first row or something like that.
			last_section_x = section.end_x;
		}
	}

	row.row_size = last_section_x;

	linear_grid_dim : Vector2F = ---;
	linear_grid_dim.x = row.x_point_width * last_section_x;
	linear_grid_dim.y = row.row_height;
	//TODO We could store this rectangle in a separate linear space for op space struct with grid_size etc...
	// world_min_pos : Vector2F = points_in_space[0].rect_mesh.min + row.row_world_base_start;
	//row.row_world_base_start is the min_center so we subtract half the width the get the bottom left
	//without having to use the space_points so we can compute this anywhere instead.
	world_min_pos : Vector2F = row.row_world_base_start - Vector2F.{0.5*row.x_point_width,0};
	linear_grid_rect : Rectangle2 = RectMinDim(world_min_pos, linear_grid_dim);
	linear_world_center : Vector2F = GetCenter(linear_grid_rect);

	coll : *CollisionEntity = array_add(*all_data.all_op_collision_entities);
	coll.entity_id = row.id;
	coll.entity_type = EntityType.OP_LINEAR_ROW;
	coll.shape = CollisionShape.RECTANGLE;
	coll.rect = RectCenterDim(linear_world_center, linear_grid_dim);

	return row.*;
}


MakeMusicLaneRow :: inline (
	music_lane_id : int,
	row_system_type : RowSystemType,
	music_lane_type : MusicLaneType,
	row_world_base_start : Vector2F,
	total_row_index : int,
	row_height : float,
	use_create_row_data : bool = false,
	create_row_data : CreateRowData = CreateRowData.{},
	row_name : string = "")
-> MusicLaneRow
{
	music_lane_row : MusicLaneRow;
	//We are using negative row_ids/row_indices now for hidden rows
	assert(context.ALL_NEXT_IDS.NEXT_MUSIC_LANE_ROW_ID >= 0);
	music_lane_row.id = context.ALL_NEXT_IDS.NEXT_MUSIC_LANE_ROW_ID;
	context.ALL_NEXT_IDS.NEXT_MUSIC_LANE_ROW_ID += 1;
	music_lane_row.music_lane_id = music_lane_id;
	music_lane_row.row_system_type = row_system_type;
	music_lane_row.music_lane_type = music_lane_type;
	music_lane_row.row_world_base_start = row_world_base_start;
	music_lane_row.total_row_index = total_row_index;
	music_lane_row.row_height = row_height;

	//TODO This should always be used and is just here for legacy code convenience.
	//To be removed once we always use CreateRowData
	if use_create_row_data 
	{
		music_lane_row.row_midi_data = create_row_data.row_midi_data;
		music_lane_row.row_system_type = create_row_data.row_system_type;
		// music_lane_row.sound_on = create_row_data.sound_on;
		music_lane_row.is_muted_row = create_row_data.muted_row;
		music_lane_row.base_note = create_row_data.base_note;
		music_lane_row.num_of_points = GetRowNumOfPoints(create_row_data.tuning_system_count, create_row_data);
		music_lane_row.octave_height = create_row_data.octave_height;
		music_lane_row.music_lane_row_point_type = create_row_data.music_lane_row_point_type;
	}

	music_lane_row.row_name = copy_string(row_name);
	return music_lane_row;
}

ComputeNextPitchRowWorldStart :: inline (
	all_music_lane_rows : [] MusicLaneRow)
-> Vector2F
{
	min_row_world_y : float = 
		ArrayFindMinByNameId(all_music_lane_rows, "row_world_base_start.y", 0.0);
	pitch_start_pos : Vector2F = MakeV2F(0, min_row_world_y - 20);
	return pitch_start_pos;
}

//TODO This could possibly change if we allow height to increase if we want to show more octaves at once.
//This could be store in the MusicLaneRow then.
row_world_height : float = 12.5;
MUSIC_LANE_GAP : float = 5;
DEFAULT_START_POS :: Vector2F.{0,0};
ComputeNextMusicLaneWorldPos :: inline (
	all_music_lane_rows : [] MusicLaneRow)
-> Vector2F
{
	bottom_row, found_bottom_row := ArrayFindMinValueByNameId(all_music_lane_rows,
		"row_world_base_start.y", FLOAT32_MAX);

	next_world_pos := DEFAULT_START_POS;
	if found_bottom_row {
		next_world_pos = bottom_row.row_world_base_start;
		// next_world_pos.y -= MUSIC_LANE_GAP;
	}

	return next_world_pos;
}

ComputePitchGridWorldPos :: inline (
	start_world_pos : Vector2F,
	memory_unit_width : float,
	memory_x_index : int)
-> Vector2F
{
	pitch_grid_world_pos : Vector2F = start_world_pos;
	pitch_grid_world_pos.x += memory_x_index * memory_unit_width;
	return pitch_grid_world_pos;
}

MemoryRangeToDSpace :: struct {
	x_start : float64;
	x_end : float64;
	row_index : int;

	dspace_id : int;
	op_dspace_type : OpDSpaceType;
	x_dspace_start : float64;
}

MemoryUnitToDSpace :: struct {
	//TODO Should this be float64 now as well?
	x_index : int;
	//TODO Should this be row_id so we don't have to update it on a change?
	//Then we have to fetch the row all the time for the index for each one to get music_pts though...
	row_index : int;

	//TODO Should we have type here so that dspace_id remains different per type?
	dspace_id : int;
	//TODO We could have separate arrays per type especially if we need more data
	//for each separate type but this seems ok and consistent for now.
	op_dspace_type : OpDSpaceType;

	//Adding this specifically for linear grids optimization 
	//(this might only be linear but maybe for other dspaces as well...)
	//Should we separate it out somehow if it is only for linear?
	//TODO If we don't really use it in practice then we can remove it although it does seem very practical
	/*TODO Can replace this with the word order once we merge it with
	MemoryUnitToChordSpace
	*/
	//TODO Maybe this should be float64
	x_grid_pos : int;
	//TODO Could add this if we wanted to allow a range mapping.
	// x_end_pos : float64;
}

DSpaceToOpSpaceIndex :: struct {
	/*Note : We are doing it this way instead of multiple
	arrays for each dspace_type so that we can easily change
	between each and just have to generate the different
	dspace. Ultimately this may be unnecessary since we may
	only ever have LINEAR and CIRCLE and other op_space
	representations may be much more complex.
	*/
	//TODO If dspace_id is unique to each type then we can have different ids for each type instead of just dspace_id
	//Then we could make the total id = dspace_id + op_dspace_type
	dspace_id : int;
	op_dspace_type : OpDSpaceType;
	op_space_id : int;
	op_grid_pos : Vector2I;
}

//TODO Should probably rename this to OpGeometryType or something like that.
op_dspace_type_enums : [] OpDSpaceType : #run enum_values_as_enum(OpDSpaceType);
OpDSpaceType :: enum {
	//TODO Can remove these once we generalize everything.
	//Just keeping it here for the tests in case for asm tests.
	//But we will update everything so we can change those tests anyways.
	OLD_LINEAR;
	OLD_CIRCLE; 

	LINEAR;
	CIRCLE;
	SPIRAL;

	//TODO Should this really be a type or generalized so we can 
	//have it run for any dimension eventually.
	CHORD_S2;
	PITCH_S2;
}

OpLinearData :: struct {
	dspace_id : int;
	base_note : int;
	grid_size_x : int;
	grid_size_y : int;
	//TODO Could have an unequal rendering here instead of doing it with UNEQUAL_TEMPERAMENT
}

SetupTerminalData :: inline (td : *TerminalData) {
	//TODO SETTINGS Could pass this in through settings
	//other default option - λ
	// td.terminal_start_cmd_string = "λ";
	td.terminal_start_cmd_string = ">";

	/*DOC : Having cmd_string_with_start and terminal_command_string
	allows us to just add the cmd_string_with_start to the terminal_split_lines
	directly whenever we update and so then we can highlight it directly
	and with terminal_command_string we can still update the text like a normal
	single line text string. Setting it like this allows us to use 1 contiguous block
	that always stays in sync.
	IMPORTANT remember to call UpdateCmdStringWithStart whenever we change
	the terminal_command_string which we are doing now on udpated_text and 
	when pressing enter in the terminal.
	*/
	terminal_command_string_size : int = Kilobytes(1);
	cmd_string_with_start_size : int = 
		terminal_command_string_size+td.terminal_start_cmd_string.count;
	td.cmd_string_with_start = alloc_string(cmd_string_with_start_size);
	memcpy(td.cmd_string_with_start.data, 
		td.terminal_start_cmd_string.data, 
		td.terminal_start_cmd_string.count);
	td.cmd_string_with_start.count = td.terminal_start_cmd_string.count;

	//TODO SETTING This can also be a setting if needed
	//OR we can eventually have this double automatically
	//in update file to string and set whether or not we allow 
	//file string increase as a bool flag in FileString
	//WOULD Also have to increase the size of cmd_string_start if we do that

	td.terminal_command_string.total_allocated_bytes = terminal_command_string_size;
	td.terminal_command_string.text_string.data =
		td.cmd_string_with_start.data + td.terminal_start_cmd_string.count;
	td.terminal_command_string.text_string.count = 0;
	//TODO I Am not adding this because it messes with the terminal history
	//We could make the terminal history part of undo but that feels weird
	// cfsd : CreateFileStringData;
	// cfsd.undo_action_count = 50;
	// cfsd.text_undo_split = " ";
	// InitTextActionHistory(*td.terminal_command_string, cfsd);


	td.next_cmd_history_index = 0;
	td.cmd_history_count = 1;
	td.history_select_offset = 0;
	//TODO SETTINGS can pass this in through settings and set the default in there instead
	td.cmd_history_max_count = 40;
	array_resize(*td.terminal_cmd_history, td.cmd_history_max_count);
	for * td.terminal_cmd_history {
		it.* = alloc_string(terminal_command_string_size);
		it.count = 0;
	}


	//TODO Should this be bigger in case we want to pass in many commands
	//TODO I think we can remove this altogether
	//TODO What exactly is this? Maybe a list for all possible terminal commands, BUT I can make that
	//a command and just output that to the terminal or generate a file for documentation.
	// executable_commands_string_size : int = Kilobytes(1);
	// td.runnable_terminal_commands.total_allocated_bytes = executable_commands_string_size;
	// td.runnable_terminal_commands.text_string = alloc_string(executable_commands_string_size);
	// td.runnable_terminal_commands.text_string.count = 0;

	//TODO Maybe can an allocator and clear it with a clear command.
	//TODO SETTING I think this can be a startup setting where we set the size
	//of this depending on what people want and default to 100kb which is around 2000 lines
	//and also write in documentation to clear sometimes
	terminal_string_size : int = Kilobytes(50);
	td.terminal_file_string.total_allocated_bytes = terminal_string_size;
	td.terminal_file_string.text_string = alloc_string(terminal_string_size);
	td.terminal_file_string.text_string.count = 0;
}
ResetTerminalCmdHistory :: inline (td : *TerminalData) {
	td.next_cmd_history_index = 0;
	td.cmd_history_count = 1;
	td.history_select_offset = 0;
	//We reset here just in case for example we adjust this for tests or there might be other cases later
	td.terminal_cmd_history.count = td.cmd_history_max_count;
	for * td.terminal_cmd_history {
		it.count = 0;
	}
}
/*TODO If we create a dynamic string, then we should likely use that
currently the size
*/
CopyToCurrentCmdHistory :: inline (
	to_copy : string,
	td : *TerminalData) 
{
	memcpy(td.terminal_cmd_history[td.next_cmd_history_index].data,
		to_copy.data, to_copy.count);
	td.terminal_cmd_history[td.next_cmd_history_index].count = to_copy.count;
}
ClearTerminalCommandString :: inline (td : *TerminalData, all_term_ops : [] TerminalOpSpaceData) {
	ResetTextCursor(*td.terminal_cursor);
	td.terminal_command_string.text_string.count = 0;
	UpdateCmdStringWithStart(td);
}

//TODO SETTING this should be settable in the settings and then set in
//terminal_data below
// cmd_history_max_count : int : 40;
TerminalData :: struct {
	//NOTE : This is the start of the cmd string by default ">" right now
	terminal_start_cmd_string : string;
	//Should rename this to DynamicString
	/*DOC : terminal_command_string refers to the same string
	as cmd_string with start but the data pointer is increased by 
	the size of the terminal_start_cmd_string.count
	*/
	terminal_command_string : FileString;
	cmd_string_with_start : string;

	terminal_file_string : FileString;
	//TODO Rename to terminal command cursor and have some separate data for highlighting other text
	terminal_cursor : TextCursor;

	//TODO Can put this into a separate struct if we reuse it or something eventually.
	history_select_offset : int;
	//TODO This is the current cmd index, so we could name it current_cmd_index
	//but I think this is clearer and just leave it a note her that
	//THIS IS the current cmd message that is typed in the terminal
	next_cmd_history_index : int;
	//DOC : This count includes the current command so we can systematically
	//go back to what we were writing when we are scrolling through the cmd history.
	cmd_history_count : int;
	cmd_history_max_count : int;
	terminal_cmd_history : [..] string;

	//Need this for when we resize
	//TODO Can put it in term op if we ever have separate terminals eventually
	all_terminal_lines : [..] string;


	//TODO This should be capped and then we loop to write
	//So we would need a pointer of which line we 
	//are currently writing on to not have to move 
	//the whole terminal over or something like that.
	//this should also have a max char cap per line
	//TODO Could make this an object which could
	//then differentiate between lines of commands
	//and info and error commands or also just add
	//and array with info for each lane instead
	//of one big object
	//TODO CAN REMOVE BOTH OF THESE NOW SINCE WE PUT THE terminal
	//in an op_space
	// terminal_open : bool;
	// terminal_cam : Camera2D;
	//TODO this index is for when we have a limited number
	//of lines and history so we know where we need to add to
	//and start drawing from which would be right after the this index
	//TODO CAN REMOVE THIS now since we use it from text_split_line
	// terminal_start_line_index : int;
	// runnable_terminal_commands : FileString;
}

#if 0 {
terminal_command_details : [terminal_command_type_count] string : .[
#string DONE
'load' TODO details\n
DONE,

#string DONE
'code' TODO details\n
DONE,

#string DONE
ms : Prints out all music sections by name.\n
DONE
];
}

IsTerminalCmdHelp :: inline (cmd_switches : [] string) -> bool {
	is_cmd_help : bool = cmd_switches.count > 0 && cmd_switches[0] == "-help";
	return is_cmd_help;
}
goto_type_names : [] string : #run enum_names(GoToTermType);
goto_type_values : [] GoToTermType : #run enum_values_as_enum(GoToTermType);
GoToTermType :: enum {
	mspace;
	op_space;
}

CompileCodeType :: enum {
	DEFAULT; //just a string
	TEXT_FILE;
}
CompileCodeEvent :: struct {
	compile_settings : CompileSettings;
	code_string : string;
	text_file_id : int;

	compile_code_type : CompileCodeType;
	//TODO We could have this be op_space and/or text_file_id because
	//technically we could compile from file_id without op_space
	//and we can have 2 op_spaces with the same text_file i guess...
	//or maybe we don't allow the second case...
	op_space_id : int;
}

ProcessInstructionEvent :: struct {
	//PROBABLY BETTER TO JUST DO THIS FROM COMMAND LINE and set the parameters consistently.
	//If we are in RUN, then we can use text_file_id and just run instructions.
	//If we are in DEBUG, then we have to use op_space_id.
	// exec_mode : ExecutionMode;

	op_space_id : int;
	// text_file_id : int;
}
OneOpIsExecuting :: inline (
	all_process_instruction_events : [] ProcessInstructionEvent) 
-> bool
{
	return all_process_instruction_events.count == 1;
}
TextOpIsExecuting :: inline (
	op_space_id : int,
	all_process_instruction_events : [] ProcessInstructionEvent) 
-> bool
{
	text_op_is_executing : bool = all_process_instruction_events.count > 0 &&
		all_process_instruction_events[0].op_space_id == op_space_id;
	return text_op_is_executing;
}

MapLinearType :: enum {
	POINT;
	RANGE;
}
MapLinearData :: struct {
	dspace_id : int;
	row_index : int;
	x_index : float64;

	op_x_row_pos : float64;

	map_linear_type : MapLinearType;
	x_end_index : float64;
}

//TODO Should this be collapsed with AsmCreateRowData?
AsmOpRowData :: struct {
	//Return values
	row_id : int;

	octave_height : float64;
	row_height : float64;

	row_section_memory_index : int;
	row_section_count : int;

	//TODO We might want to make this different for op_rows since we will play them differently
	sound_on : int; //bool in asm
	row_system_type : RowSystemType;
	//TODO We can add midi specific data here
	// row_midi_data : RowMidiData;

	op_space_id : int;

	x_point_width : float64;
	x_op_pos : float64;
	y_op_pos : float64;
	is_music_row_copy : int; //bool in asm
	copy_music_row_id : int;
}

//TODO Could do a version with input params for non-default
MakeDefaultCreateRowData :: inline (all_data : AllData) -> CreateRowData
{
	//TODO Should we take this from all_tuning_systems instead?
	create_row_data : CreateRowData;
	create_row_data.tuning_system_type = all_data.global_rules.tuning_system.type;
	create_row_data.tuning_system_count = all_data.global_rules.tuning_system.music_pt_count;
	return create_row_data;
}

/*Setting up music data with a struct so we can easily add
members if we need to add more music data setup.

TODO SET A DEFAULT BASE/ZERO FREQUENCY IN HERE so that we have the same
frequency everywhere for all 0 pitches and then we can allow adjusting that
on a per case basis explicitly if needed.
*/
SetupMusicData :: struct {
	//TODO I think this should just be memory_units_per_second
	row_size : int = 12;
	memory_units_per_second : float64 = 1.0;
	// default_pitch_zero_freq : float64 = C4;
	//TODO Maybe we can set which music space is default here and put that in a register
	//or somewhere in global rules or something like that and then use that
	//whenever we don't specify music space or to start implementing it and not add it everywhere.
	//default_music_space : int;
	//TODO Do we want to have the concept of a beat here? It could be maintained by the user.
	//I'll store it in here for now but I am not sure I want to keep it as I would rather remove
	//the concept of a beat altogether and people can introduce it if they want to.
	/*I WILL REMOVE IT. Will keep it for now just in case BUT then we can also allow drawing
	rectangles for linear so that we can change the rhythm for row section without having to change
	the underlying memory_units_per_second so that the asm works. Then the user can write functions
	that allows the rhythm to generalize the length of music_pts per row and then can multiply values from there.
	*/
	//TODO REMOVE THESE 2 once they are no longer used
	bpm : float64 = 60.0;
}

//Leaving like this so I can put things on for defaults if needed.
TWO_ROWS :: CreateRowData.[
.{row_section_data=.[.{x_length=12}], row_system_type=.internal_pitch},
.{row_section_data=.[.{x_length=12}], row_system_type=.internal_pitch},
];
SetupMusic :: inline (all_data : *AllData, smd : SetupMusicData = .{}) {
	//TODO Should this be in a register instead of in global rules?
	all_data.global_rules.row_size = smd.row_size;
	//TODO I think maybe i want to remove bpm and bps altogether and only keep memory_units as a concept.
	all_data.audio_timing.bpm = smd.bpm;
	all_data.audio_timing.bps = all_data.audio_timing.bpm / 60.0;
	//TODO Why am I multiplying this? It was 1 so it was doing nothing. No need to multiply.
	//TODO Should this be memory_units_per_beat by default though?
	//TODO I think we can leave this as per_second and then have a function that does memory_units_per_second
	//to memory_units_per_beat
	// all_data.game_audio_play.memory_units_per_second = smd.memory_units_per_second * all_data.audio_timing.bps;
	all_data.game_audio_play.memory_units_per_second = smd.memory_units_per_second;

	//TODO We could set base_frequency in here which would map to the pitch 0 in any case.
	//We could also allow that to be set per tuning system if needed
}

SetupMusicAndRows :: inline (all_data : *AllData, rows : [] CreateRowData = .[], smd : SetupMusicData = .{}) {
	//TODO We can rmove this from here now since we set it by default
	//We can just call this function if we need to update it OR update it directly in the code since that works now.
	// SetupMusic(all_data, smd);
	//Technically we can just call this now directly and remove this function
	for rows CreateMusicRow(it, all_data);
}


/*TODO Should we put this in a separate instructions file?
*/
MusicInstruction :: struct {
	//TODO Do we need this id. Maybe it can be associated externally by file_id or something like that.
	//Leaving here for now just in case we use it but can remove if we don't with external id
	//so it clears up the instruction data from unnecessary size increase.
	//We could reference a file by beginning and start index and then remove the id... not sure.
	//They are currently not used and only need if we need things to happen out of order.
	//I think we can remove id to try and keep size <= 128 bytes.
	//Mac cache lines are 128 bytes, pc cache lines are 64 bytes.
	//Can collapse some enums to bits to remove a few more bytes too.
	id : int;
	op_code : OpCode;
	instr_type : InstructionType;
	//TODO Could have a #place here with each separate operand.
	operands : [3] MusicOperand;
}

/*REMINDER 
  I am making this a type for now but it could be 1 bit if
  we only have these 2 types. This is in case we need it for
  u8 string later or allow other types as well.
*/
InstructionType :: enum u8 {
	INTEGER;
	FLOAT;
	//TODO Could allow byte here so we can have instructions
	//for u8 and bool like arithmetic and logical. This would then
	//be used directly for string manipulation if needed for example.
	/*IF/WHEN We allow this type, I think we just need this type and not operand types.
	Then we just check the InstructionType and only take the the first byte. We can do
	bounds checks I guess but maybe just do checks in the compiler and not during execution.
	Just assume to take the first byte would be clearer and faster.
	Would need to check this in arithmetic and also comparison instructions. (Maybe logical but maybe note)
	Comparison is most important and also could have a special case for mov.b if needed but maybe mov_size == 1 is enough.
	REMIND THAT THIS IS REALLY ONLY NEEDED FOR STRINGS and should not really be used as an int replacement for now.
	*/
	// BYTE;
}

//TODO Can this be done with #procedure_of_call or something like that?
// MakeFloatInstr :: #bake_arguments MakeMusicInstruction(t=.FLOAT);
FloatInstr :: MakeFloatInstr;
MakeFloatInstr :: inline (
	op_code : OpCode,
	operands : .. MusicOperand) 
-> MusicInstruction 
{
	return MakeMusicInstruction(op_code, operands, .FLOAT);
}

MakeMI :: MakeMusicInstruction;
MakeMusicInstruction :: inline (
	op_code : OpCode,
	operands : .. MusicOperand,
	t : InstructionType = .INTEGER) 
-> MusicInstruction 
{
	assert(operands.count <= MusicInstruction.operands.count, "MusicInstruction operands need to be <= 3.");
	mi : MusicInstruction = MakeMusicInstruction(op_code, operands, t);
	return mi;
}

MakeMusicInstruction :: inline (
	op_code : OpCode,
	operands : [] MusicOperand,
	t : InstructionType = .INTEGER) 
-> MusicInstruction 
{
	assert(operands.count <= MusicInstruction.operands.count);

	mi : MusicInstruction;
	mi.id = context.ALL_NEXT_IDS.NEXT_MUSIC_INSTRUCTION_ID;
	context.ALL_NEXT_IDS.NEXT_MUSIC_INSTRUCTION_ID += 1;
	mi.instr_type = t;
	mi.op_code = op_code;
	for operands {
		mi.operands[it_index] = it;
	}
	return mi;
}

EqualsMInstr :: inline (m1 : MusicInstruction, m2 : MusicInstruction) -> bool {
	is_equal : bool = m1.op_code == m2.op_code &&
		m1.instr_type == m2.instr_type &&
		EqualsMOperand(m1.operands[0], m2.operands[0]) &&
		EqualsMOperand(m1.operands[1], m2.operands[1]) &&
		EqualsMOperand(m1.operands[2], m2.operands[2]);
	return is_equal;
}

MusicOperand :: struct {
	operand_type : MusicOperandType;
	//TODO Could have a #place here with each separate value.
	/*TODO We could also just make this a struct with
	  both values and then can also copy easily. This way
	  we can also put using on the first value and then access
	  that type by default directly. Maybe thats confusing
	  for debugging though.
	  Part of me likes the struct way more than the array way,
	  since then we can copy with one line of code as well.
	  SO FAR I am just using the arrays.
	  ALSO IMPORTANT it may be possible to optimize this down
	  to 1 64 bit value and then 2 32 bit values for anything
	  that needs 2 values. The only exception is music memory
	  since it reduces how much we can access... not sure
	  will leave it now but maybe can consider later...
	  Can possible remove v0 and v1 since im using the array everywhere.
	  CAN MAKE 1 32-bit and 1 64-bit and that would optimize a bit eventually.

	  Can also reduce a few bytes by collapsing the enums into bits
	  Seems like pc cache lines are 64 bytes and mac cache lines are 128 bytes
	  so would be worth keeping this <= 128 bytes.
	*/
	// using mv : MultiValues;
	using v0 : MusicOperandValue;
	v1 : MusicOperandValue;
	#place v0; values : [2] MusicOperandValue;
}

//TODO Remove this if we don't use since it seems like
//I am using the fixed array of operand values everywhere
#if 0 {
MultiValues :: struct {
	using v0 : MusicOperandValue;
	v1 : MusicOperandValue;
}
}

MusicOperandType :: enum u8 {
	//TODO We can remove this NONE type if we set the defaults
	//to be zero and also have a zero register at register 0
	//and then calculations just come out to be 0 for RAM_MEMORY and MUSIC_MEMORY.
	NONE;
	INTEGER;
	FLOAT;
	REGISTER;
	//TODO Should we rename this to RAM_VALUE now?
	RAM_MEMORY;
	MUSIC_MEMORY;
	//We are using RAM_ARRAY for array access so we cannot set right now.
	//Should we allow setting an array? That seems like something
	//we can stick to keeping in the compiler.
	/*This should be thought of as a base value like INTEGER or FLOAT.
	I am not sure if we should use it as an array storage type, but
	maybe we could since it could simplify array code in general.
	*/
	RAM_ARRAY;
}

EqualsMOperand :: inline (o1 : MusicOperand, o2 : MusicOperand) -> bool {
	is_equal : bool = o1.operand_type == o2.operand_type &&
		EqualsMValue(o1.values[0], o2.values[0]) &&
		EqualsMValue(o1.values[1], o2.values[1]);
	return is_equal;
}

MusicOperandValue :: struct {
	type : OperandValueType;
	using value : MemoryValue;
}

OperandValueType :: enum u8 {
	NONE;
	REGISTER;
	INTEGER;
	FLOAT;
}

EqualsMValue :: inline (v1 : MusicOperandValue, v2 : MusicOperandValue) -> bool {
	is_equal : bool = v1.type == v2.type && v1.int_value == v2.int_value;
	return is_equal;
}

//TODO We could validate in here, although if we use the functions
//internally then it should be fine and we don't need to validate.
MakeMusicOperand :: inline (
	type : MusicOperandType,
	v1 : MusicOperandValue)
-> MusicOperand
{
	op : MusicOperand;
	op.operand_type = type;
	op.values[0] = v1;
	return op;
}

MakeMusicOperand :: inline (
	type : MusicOperandType,
	v1 : MusicOperandValue,
	v2 : MusicOperandValue)
-> MusicOperand
{
	op : MusicOperand = MakeMusicOperand(type, v1);
	op.values[1] = v2;
	return op;
}

//TODO Should this go in thegame_code?
non_stack_start_reg :: RegDef.ax;
non_stack_start_reg_index :: cast(int) non_stack_start_reg;
reusable_start_reg :: RegDef.r0;
reusable_start_reg_index :: cast(int) reusable_start_reg;
reusable_end_reg :: RegDef.r3;
reusable_end_reg_index :: cast(int) reusable_end_reg;

//We use this for push_all_stack_reg and pop_all_stack_reg for everything we have to store and reset on a function call
push_pop_start_reg :: RegDef.sbp;
push_pop_start_reg_index :: cast(int) push_pop_start_reg;
STACK_REG_SIZE :: ((#run enum_names(RegDef)).count - push_pop_start_reg_index) * size_of(MemoryValue);
ALL_REG_SIZE :: (#run enum_names(RegDef)).count * size_of(MemoryValue);
reg_def_names : [] string : #run enum_names(RegDef);
reg_def_enums : [] RegDef : #run enum_values_as_enum(RegDef);
reg_def_s64 : [] int : #run enum_values_as_s64(RegDef);
RegDef :: enum {
	//We could use this if needed as a default zero value reg
	//that is always set to zero like they do in RISC architecture.
	//TODO Can rename to ZERO_REGISTER
	ZERO_VALUE_REGISTER;

	//Constant value registers
	dfms; //default music space

	ir; //Current instruction register
	pc; //Next instruction program count
	cr; //TODO Can remove this if we don't use a comparison register.

	//TODO Should we rename this .hbp instead of .hsp?
	hsp; //heap start pointer
	hcp; //heap current pointer
	hrp; //heap return pointer

	//tano row stack pointers
	//NOTE : This will not get reset on function return so then the tsp can maintain the return tano stack op neumes.
	tsp; //tano row stack pointer

	srp; //stack return pointer

	sbp; //stack base pointer
	scp; //stack current pointer
	//TODO We may not need this if we can just use byte_offset_from_sbp
	sep; //stack expression pointer (can remove this if not used)
	//We want to reset this on function return so we place it here
	tbp; //tano row base pointer

	//TODO Likely need a bdr (base data register) to show
	//where data starts after constant. Can use now also
	//so that the 0 value in memory always = 0 for null pointers
	//TODO Should we rename to rax...?
	//NOTE : These registers are now assumed to only be used locally and do not move around in an expression.
	//To use a register that moves around (eg for binary ops or dereference) then use reusable registers below.
	ax;
	bx;
	cx;
	dx;
	//Maybe we have a few y registers instead of ex. So ax, bx, cx and ay, by, cy
	// ex;

	//NOTE : We use arm register names for reusable registers.
	//These are use based on availability and specifically for
	//pointer dereferences for example. Could also optimize simple
	//instructions and use them for y = x + 1 for example if needed
	//to avoid a stack push for the x + 1 there eventually.
	r0;
	r1;
	r2;
	r3;
	//TODO could add more of these if we need them

	/*NOTE : If we do add float registers, we can add an execution time check
	so that we always grab reg.float_value from float registers. This would maybe
	be helpful but I don't know if it matters. We would still have to specify that
	it is a float instruction. Ultimately all register can hold anything, even on x86
	and so the values are interpreted by the instructions. This allows an extra check
	but it may not be worth it. The general case is good because it allows me or the user
	to do anything and also does not feel restrictive or not restrictive enough
	because memory and registers will be interpreted anyways in any case.
	Ie if there is a float in an int value, there is no way to check it in all cases all the time.
	*/
	//TODO Could have 5 float registers by name here and then we know which ones are floats and then
	//optimization for op_codes would be fine later.
	//fadd also makes it fine. Only having a separate type does not make it fine but also how would
	//we know the other types anyways... so may need it anyways. (could possibly just be a few bits though.)
	// fax;
	// fbx;
	// fcx;...

	//Then we could also have forced integer registers
	// iax;
	// ibx;
	// icx;

	//Function pointer
	foop;

	//TODO Can likely remove all these in favor of just storing muscalls on the stack
	//TODO REMOVE THIS ONCE WE REMOVE THE OLD MUSCALL CODE.
	amu;
	bmu;
	cmu;
	dmu;
	emu;
}

/*New Music instruction and operand creation. Can remove
old one if this works nicely. We use the OldMusicOperand
and OldMusicOperandValue directly here and then copy it over.
We could also add it directly to the array since we know
it is correct. Is there a clean way to do this?
*/

/*TODO SHOULD WE move this into thegame_code?

REPLACE New and call the old ones Old once this is working and tested.
*/

/*
NEW MUSIC OPERAND STUFF

TODO MOVE ALL THIS INTO thegame_code
*/
//TODO We could just pass in music_instructions directly instead of using the /interface now
InstrCreator :: struct {
	all_music_instructions : [..] MusicInstruction;
}

//TODO Can replace with #bake_arguments if that allows function overloads at some point.
CreateFloatInstr :: FCreateMInstr;
FInstr :: FCreateMInstr;
FCreateMInstr :: inline (op_code : OpCode, operands : .. MusicOperand, d : $D/interface InstrCreator) -> MusicInstruction {
	return CreateMInstr(op_code, operands, ami=*d.all_music_instructions, t=.FLOAT);	
}
FCreateMInstr :: inline (op_code : OpCode, operands : .. MusicOperand, ami : *[..] MusicInstruction) -> MusicInstruction {
	return CreateMInstr(op_code, operands, ami, t=.FLOAT);
}
FCreateMInstr :: inline (op_code : OpCode, operands : [] MusicOperand, ami : *[..] MusicInstruction) -> MusicInstruction {
	return CreateMInstr(op_code, operands, ami, t=.FLOAT);
}

Instr :: CreateMInstr;
CreateMInstr :: inline (op_code : OpCode, operands : .. MusicOperand, d : $D/interface InstrCreator, $t : InstructionType = .INTEGER) -> MusicInstruction {
	return CreateMInstr(op_code, operands, ami=*d.all_music_instructions, t=t);	
}
CreateMInstr :: inline (op_code : OpCode, operands : .. MusicOperand, ami : *[..] MusicInstruction, $t : InstructionType = .INTEGER) -> MusicInstruction {
	return CreateMInstr(op_code, operands, ami, t);
}
//TODO Could Make a separate function like MakeInstr which then sets that a compile_time dont_add and we just return it without adding.
CreateMInstr :: inline (op_code : OpCode, operands : [] MusicOperand, ami : *[..] MusicInstruction, $t : InstructionType = .INTEGER) -> MusicInstruction {
	assert(operands.count <= MusicInstruction.operands.count);
	mi : MusicInstruction = MakeMusicInstruction(op_code, operands, t);
	//TODO Validate that the operands work with the instruction before adding
	//Can validate operands and values altogether now.
	// ValidateOldMusicInstruction();
	array_add(ami, mi);
	return mi;
}
CreateMInstr :: inline (mi : MusicInstruction, d : $D/interface InstrCreator) -> MusicInstruction {
	new_mi : MusicInstruction = PROC_JMP_RETURN;
	new_mi.id = context.ALL_NEXT_IDS.NEXT_MUSIC_INSTRUCTION_ID;
	context.ALL_NEXT_IDS.NEXT_MUSIC_INSTRUCTION_ID += 1;
	array_add(*d.all_music_instructions, new_mi);
	return new_mi;
}

//TODO Should have a version with integer to allow creation of new registers.
RegMem :: inline (reg_def : RegDef) -> MusicOperand {
	mop : MusicOperand = MakeMusicOperand(.REGISTER, .{.REGISTER,.{cast(int) reg_def}});
	return mop;	
}

//TODO Can reaplce this with Imm or Imme for shortness
Imm :: Immediate;
Immediate :: inline (i : int) -> MusicOperand {
	mop : MusicOperand = MakeMusicOperand(.INTEGER, .{.INTEGER, .{i}});
	return mop;
}

FImm :: inline (f : float64) -> MusicOperand {
	mop : MusicOperand = MakeMusicOperand(.FLOAT, .{.FLOAT, .{float_value=f}});
	return mop;
}

ImmEnum :: inline (i : $T) -> MusicOperand {
   #assert(type_info(T).type == .ENUM);
	mop : MusicOperand = MakeMusicOperand(.INTEGER, .{.INTEGER, .{cast(int) i}});
	return mop;
}

//TODO Do we need a version with only 1 x input?
MusicMem :: inline (row : $T, x : $R) -> MusicOperand {
	#if R == float64 || R == float {
	mop := MakeMusicOperand(.MUSIC_MEMORY, .{IntOrReg(T),.{cast(int) row}}, .{.FLOAT,.{float_value=cast(float64)x}});
	} else {
	mop := MakeMusicOperand(.MUSIC_MEMORY, .{IntOrReg(T),.{cast(int) row}}, .{IntOrReg(R),.{cast(int) x}});
	}
	return mop;
}
//TODO Not sure if 1 input should be absolute x or row?
// MusicMem :: inline (x : $T) -> MusicOperand {
// 	mop : MusicOperand = MakeMusicOperand(.MUSIC_MEMORY, .{IntOrReg(T),.{cast(int) x}});
// 	return mop;
// }

//TODO Could collapse RamMem function now. This just lets us do RamMem(.sbp,0) without RamMem(RegDef.sbp,0).
RamMem :: inline (b : RegDef, i : int) -> MusicOperand {
	return MakeMusicOperand(.RAM_MEMORY, .{.REGISTER,.{cast(int)b}}, .{.INTEGER,.{i}});
}
RamMem :: inline (b : RegDef, i : RegDef) -> MusicOperand {
	return MakeMusicOperand(.RAM_MEMORY, .{.REGISTER,.{cast(int)b}}, .{.REGISTER,.{cast(int)i}});
}
RamMem :: inline (b : RegDef) -> MusicOperand {
	return MakeMusicOperand(.RAM_MEMORY, .{.REGISTER,.{cast(int)b}});
}
RamMem :: inline (b : int) -> MusicOperand {
	return MakeMusicOperand(.RAM_MEMORY, .{.INTEGER,.{b}});
}

//TODO I kind of want to flip the order of data and count here...
RamArray :: inline (count : $T, data : $R) -> MusicOperand {
	mop : MusicOperand = 
		MakeMusicOperand(.RAM_ARRAY, .{IntOrReg(T),.{cast(int) count}}, .{IntOrReg(R),.{cast(int) data}});
	return mop;
}

//I think with the macro and the #if this is all done at compile-time now.
//Maybe if we want these to be dll callable later we might have to change them a bit... not sure.
IntOrReg :: inline ($T : Type) -> OperandValueType #expand {
	return ToOpValueType(T, .[int,RegDef]);
}
ToOpValueType :: inline ($T : Type, $valid_types : [] Type = .[int,RegDef,float64]) -> OperandValueType #expand {
#assert(AllOrEquals(T,valid_types));
	#if T == {
	case int; return .INTEGER;
	case RegDef; return .REGISTER;
	case float64; return .FLOAT;
	}
	//Note : This cannot be reached because of the #assert above.
	//Putting here to squelch the compiler warnings.
	return .NONE;
}

ValueToOp :: inline (v : MusicOperandValue) -> MusicOperand {
	operand_type : MusicOperandType;
	if #complete v.type == {
	case .NONE;     operand_type = .NONE;
	case .REGISTER; operand_type = .REGISTER;
	case .INTEGER;  operand_type = .INTEGER;
	case .FLOAT;    operand_type = .FLOAT;
	}
	return MakeMusicOperand(operand_type, v);
}

NO_CPU_ERROR :: CPUError.{is_error=false};
//TODO Can rename this to RuntimeError if that's clearer but CPUError seems more general.
CPUError :: struct {
	is_error : bool;
	//TODO Can reuse this if we need both
	// instr_index : int;
	error_index : int;
	msg : string;
}

CPUErr :: MakeCPUErr;
MakeCPUErr :: inline (msg : string, instr_index : int=0) -> CPUError {
	err : CPUError;
	err.is_error = true;
	err.error_index = instr_index;
	err.msg = msg;
	return err;
}

/*END OF NEW OPERAND STUFF
*/

/*TODO Should we do this union or just have 3 different register types?
*/
MemoryValue :: union {
	//TODO Or should this be *u8 for bytes instead?
	int_value : int;
	float_value : float64;
	bytes : [8] u8;
}

//TODO Likely move this to thegame_code
//TODO could turn this into a u8 if we have less than
//256 although if users can add their own then
//we can have a custom option which fetches those.
//Unless they create their own in which case we don't 
//need anything.
//TODO Should this be in AllData because we will
//likely want to allow the player to add their own
//although maybe only has higher level functions?
//Still might be worth creating HashTable to put them
//all in for easy access and easy adding later on
//although if people create their own models, they
//may want to change everything.
op_code_names : [] string : #run enum_names(OpCode);
op_code_enums : [] OpCode : #run enum_values_as_enum(OpCode);
OpCode :: enum u8 {
	//Data Directive OpCodes
	//Note : These could be fixed for levels
	/*Every File can start with
		LANESIZE X
		NUMADDRESS 10
		MUSICLANE 0 reg
	*/
	//TODO These could be generated visually upon request
	//so we can see things or just when we run everything
	// numsreg;
	// numfreg;
	// lanesize;  //LANESIZE 10
	//TODO Could allow to generate music lanes instead
	//like MUSICLANE 10 without a name would make 10 music_lanes
	// lane; // musiclane piano 1

	//Music Instructions
	// CREATE_MUSIC_POINT; //Second operand is note we want to create in first operand
	//TODO Should have only 1 COPY op_code but then
	//various op_codes depending on the input
	// MOVE_MPS; //Move entire MPS with replacement
	mov; //MOVE_IMMEDIATE; //Move constant MPS value directly with replacement
	mset; //This performs a memset so we can initialize things easily and efficiently in ram memory
	clear;


	//TODO If we need more operands (eg for chunk moves) then we could make this array compile-time constant.
	//ACTUALLY for chunks we could have operand[2] be the 2 chunk values and operand[0] and operand[1] be
	//the music memory values we are trying to move.
	// movc;

	add;
	sub;
	mod;
	div;
	mul;

	split;
	dim;


	//tano instructions
	tmov;
	tclear;

	tadd;
	tsub;
	tmod;
	tdiv;
	tmul;

	trol;
	tshr;
	tshl;
	tror;


	// ADD_SYSTEM;
	// SUB_SYSTEM;
	// SUBSET; //TODO can we just replace subset with LOGICAL AND?
	// //TODO Can have player implement SYSTEM_SUBSET ops.
	// //Should we provide player with modulo(%) op? 
	// //Or even have them implement modulo?
	// //Yes, modulo seems like it could be another level.
	// ADD_SYSTEM_SUBSET;
	// SUB_SYSTEM_SUBSET;
	// //Note that inversion is just 2*n - value = (n+n) - value
	// SPLIT; //Can have the second operand be which notes in vertical positions you want to be moved
	// EXTEND; //Extend Rhythm
	// SNAP_UP;
	// SNAP_DOWN;
	// SNAP_ROUND;

	//Get tuning system of specific memory
	//This would allow tuning to be changed depending
	//on whats happening in the piece
	//TODO MEMORY_CHUNK type or something 
	//instead of MEMORY_MPS
	//TODO entire lane is this tuning
	//tuning <[piano] 12
	//TODO entire row is this tuning
	//tuning <[piano,#0] 12
	//TODO subsection is this tuning
	//tuning <[piano,#0,#0] 12
	//tunerow piano.pitch 12
	//tunelane piano 12
	//tunemps [piano.pitch, 10] 19
	//tune [0, piano.pitch] 19
	//tune [0, piano.0] 19
	//TODO to create tuning systems
	//Could also allow changing tuning systems
	//with registers
	//eq19 : tuning = {a,b,c,d,e,f}
	//eq19 : tuning = {0,120,240,600,1200}
	//TODO This can be replaced with muscall altogether now
	tune;

	//TODO Can be replaced with muscall
	mlen;

	// This could be a generalized op which lets us do
	// multiple simply math operations at once for clarity.
	// So we'd have to implement operator precedence using a binary tree
	// MATHOP piano[.1] := 2 * .0 - .1
	// MATH_OP;

	// This does not need to be an op_code and can instead
	// get replaced by the other op_codes like inlining.
	// Could also allow macros to be placed directly in
	// an op space in a visual kind of way.
	// MACRO;

	//TODO regular split can be a level using INTERSECTION and JUMP_EQUAL
	//Can also have < and > be INTERSECTION since we can
	//go and check each value with a loop and then the player
	//can create their own measure for > or < of chord for example
	// INTERSECTION; //Logical AND - can be used as specific music_pt_pos split
	or; //Logical OR - can be used as a MOVE without replacement
	and;
	not;
	xor;
	// diff;
	abs;

	shr;
	shl;
	ror;
	rol;

	//TOOD FROM HERE start implementing cmpr and branching
	//Code Instructions
	//Note : Do a comparison with <, >, <=, etc...
	//and then place that comparison in a register
	//cmpr #0 #1 > #2
	//can be implemented using bits in int value
	//for ==, >, <
	// cmp; //Convenience with the operators
	ceq;
	cgt;
	clt;
	cgte;
	clte;
	cneq;

	tjmp;
	fjmp;
	jmp;
	call;
	//TODO We could have jmpa for absolute addressing if needed.
	// jmpa;
	//TODO Can remove this, leaving here for now for backwards
	//compatibilty with old execution for old example checking.
	// jr; //TODO is the word 'call' better here

	/*TODO For storing and loading ireg like a stack
	  if needed for convenience in a macro. The other
	  way to do this would be to store ireg values in
	  memory_units but then we would be limited to 
	  row_size although not really since we can
	  make a lane as many rows as we want.

	  What names do we want? What does x86 and arm use?
	*/
	ret;
	//TODO I think we can remove these now
	// pushi;
	// popi;
	// pushf;
	// popf;

	push;
	pop;

	//TODO Right now we are doing comparison and then
	//jump based on the comparison but we could
	//change later if needed. Could do 1 compare and
	//then jump if we keep it with a separate register
	//because then we could have negative numbers.
	// jeq;
	// jgt;
	// jlt;
	// jgte;
	// jlte;
	// jneq;

	push_all_stack_reg;
	pop_all_stack_reg;


	//We use these to systematically manage heap memory.
	alloc;
	free;

	ftoi; //float to int
	itof; //int to float

	s_print; //asm for sprint

	//Move memory from constant section to main memory
	//TODO Could rename const_mem or constm maybe
	const_mov;

	/*TODO Instead of having separate create and map instructions
	we could just have create and map with an operand that
	specifies what we are creating.
	Should we even have create and map or just load things into
	a buffer. This would be more work to parse but also more extensible. 
	Do we want to allow creation of op_spaces in code or just in external jai.
	To some extent, external jai makes more sense because then you have access
	to everything like render buffer and audio whereas then I would have to create
	a mapping to that which seems like overkill. 
	Maybe the internal language should just be musical manipulation and some
	op_space creation but for more complicated things like creating own geometries
	and making synths then we have to use normal code, otherwise the overlap seems
	to start to be too much. HOWEVER, we can do it if it seems good
	since we have a full programming language out our disposal. 

	TECHNICALLY we can create a system that allows creating op_spaces and then
	adding dspaces arbitrarily at a position and then mapping points either from
	music_memory or from direct points in other memory. This way we could even allow
	mapping objects like squares or triangles directly to a vector point in the op_space
	and so we could draw our own shapes. However, more complex tasks would still need
	externall dll, like movement and then also think about vr. (Could possibly allow movement
	if we allow certain things to update every frame)
	This would allow us to create something like a collision object
	so then we can even interact with it with the mouse and generate possibly.
	OR allow keyboard strokes to have an effect.
	*/

	//TODO I think we should should move all the base muscalls in here.
	//Then we don't have update assembler or the values in tests.
	mspace_clear;
	//TODO Could also allow moving spaces to a specific index so people can cycle in any order they want.
	//Could call it move_mspace or swap_mspace might be clearer.
	// swap_mspace;

	//New instructions for muscall (like syscall) so we can generalize
	//thinks like creating. The first operand can have a corresponding
	//enum for code legibility.
	muscall;

	//Music and op space asm instructions
	setup_music;

	get_or_create_simple_synth;
	update_simple_synth;
	delete_simple_synth;
	delete_all_synths;

	get_tuning_system;
	create_tuning_system;
	reset_default_tuning_systems;

	create_row;

	get_or_create_mspace;
	update_mspace;
	delete_mspace;
	clear_mspace;

	get_or_create_op_space;
	clear_op_space;

	create_circle;
	map_circle;

	create_spiral;
	map_spiral;

	create_cs2;
	map_cs2;

	create_cs3;
	map_cs3;

	create_custom_3D;
	create_shape_3D;
	create_text_3D;

	create_custom_geometry;
	create_shape;
	delete_shape;
	create_text;

	//TODO Should use this to allow converting to frequencies with a pitch and tuning system in a consistent way
	// to_frequency;

	//Note : Comparisons are always just a SUB and then a branch.
	//Can look at some more places to see how they do it as well.
	// JUMP_EQUAL;
	// JUMP_NOT_EQUAL;
	// JUMP_GREATER_THAN; //can tell us if we have notes in an mps or not if we compare to empty mps

	// //TODO do we need these?
	// JUMP_GREATER_THAN_EQUAL;
	// JUMP_LESS_THAN;
	// JUMP_LESS_THAN_EQUAL;

	exit;
	HALT;

	//TODO Would go check in a String table for name.
	//This way the user can easily create new OpCodes.
	// CUSTOM; 
}

/*We write the numbers out explicitly since those will be used directly in the instructions.
WE NEED TO ALLOW THESE TO BE NAMED BY STRING IN THE ASM directly as that is much clearer

TODO Should these even be muscalls or just normal calls? I feel like they should be muscalls for consistency
with future calls but we could make the base calls normal calls. Eventually when we let people add their own
calls, then they would use muscalls with other numbers basically, but maybe that would even be a separate
instruction altogether like cuscall for custom calls and then we call the external code with that particular instruction.

TODO MAYBE we should not make these number dependent and have them be called by name everywhere.

TODO I THINK WE SHOULD REMOVE base instructions from MUSCALL and have that be future calls
if we allow people to add their own or something.
The issue is the tests fail when we change the order in here (could use enum_flags)
but also then we can't tell what the call is with the number, so we could
update the assembler for that but why when we can just have the call anyways...
*/
muscall_type_names : [] string : #run enum_names(MusCallType);
muscall_type_enums : [] MusCallType : #run enum_values_as_enum(MusCallType);
MusCallType :: enum {
	/*I am not sure how these should be done if we should
	allow combining 2d or 3d space. What about vr? Probably
	best to do that once we actually integrate with vr.
	TODO Should we rename this to create_window?
	I may want to use the name Space later to have more total row spaces.
	*/
	create_space;

	//This is the new create_row. I think maybe this should be 0 instead
	//and then create space should be 1 and then create_geometry 2 and so on
	setup_music;
	create_row;

	map_memory;

	//TODO Rename to create_linear or create_op_linear or create_op_linear_row
	create_op_row;
	map_linear;

	create_circle;
	map_circle;

	create_spiral;
	map_spiral;

	//TODO I think we can have separate chord_s2 and chord_s3+ since one is 2d and one is 3d
	//but 3d can be 3d+ since it is all 3d and just dimension change. It depends what we need to generate for each.
	create_cs2;
	map_cs2;

	create_cs3;
	map_cs3;

	/*DOC : Generalized create shape call.
	*/
	create_custom_geometry;
	create_shape;
	delete_shape;
	create_shape_value;
	delete_shape_value;
}

map_geometry_type_enums : [] MapGeometryType : #run enum_values_as_enum(MapGeometryType);
MapGeometryType :: enum {
	memory_unit;
	point;
	//TODO Could have this as a range to place in 1 dspace like a sequence of linear on linear
	//or a sequence of linear on circle like a melody on a circle
	// memory_range;
}

AsmGeom3D :: struct {
	group_id : int;
	op_space_id : int;
	tuning_system_id : int;
	//TODO We could add MIDI to here instead of for the chord space directly
	custom_audio_type : CustomAudioType;
	osc_wave_type : OscWaveType;
} @LibraryAsmGen

AsmShape3D :: struct {
	op_space_id : int;
	group_id : int;
	rel_pos : Vector3F64;
	//TODO Do we need both of these?
	fun_region : AsmArray(float64);
	pitch_set : AsmArray(float64);
	shape_text : AsmString;
	//We only need to add this option if these are filterable eventually
	// do_not_remove_with_filter : AsmBool;
	draw_wire_mesh : AsmBool;
	not_selectable : AsmBool;
	color := #run MakeV4F64(DEFAULT_CUBE_MULTI_COLOR);
	scale_value : float64 = 1.0;
} @LibraryAsmGen
AsmText3D :: struct {
	op_space_id : int;
	group_id : int;
	text : AsmString;
	op_pos : Vector3F64;
} @LibraryAsmGen

AsmGeom2D :: struct {
	dspace_id : int; //returned
	op_space_id : int;
	custom_audio_type : CustomAudioType;
	tuning_system_id : int;
	osc_wave_type : OscWaveType;
	collision_pos : Vector2F64;
	collision_dim : Vector2F64;
	show_collision : AsmBool;

	//TODO If we put this in here then we could just draw the rects
	//and if it's a sound float, then we do the special audio
	//OR JUST AHVE THIS IN CUSTOM GEOMETRY and have that as
	//a type which we only set internally.
	// is_sound_float : AsmBool;
} @LibraryAsmGen


CreateGeometryData :: struct {
	//Return variables
	//TODO Should these be here or somewhere else?
	dspace_id : int;

	//Input variables
	op_dspace_type : OpDSpaceType;
	op_space_id : int;
	//Should this be general or specific to each space? I guess position is general in any case.
	pos_x : float64;
	pos_y : float64;
	data_address : int;
}

//TODO Will each geometry be the same create data or do we need separate ones for each OpDSpaceType?
CreateCircleData :: struct {
	radius : float64;
	point_count : int;	
}


CreateLinearData :: struct {
	base_note : int;
	grid_size_x : int;
	grid_size_y : int;
}

MapGeometryData :: struct {
	dspace_id : int;
	op_dspace_type : OpDSpaceType;
	map_geometry_type : MapGeometryType;

	//TODO Should we access the map data array directly or have an intermediate data for each type?
	//Can also just put intermediate data here.
	map_data_count : int;
	map_data_address : int;
	//TODO Do we need this later?
	// op_space_id : int;
}

/*These are the default mapping unit datas. We have a different one below for linear
since we can have a sequence with linear and then maybe we can update these later if needed for example
*/
MapUnitData :: struct {
	row_index : int;
	x_index : int;
}

MapPointData :: struct {
	dspace_id_address : int;
	point_count : int;
}

//TODO Not sure if we need this or if we should just put it in MapUnitData anyways
MapLinearUnitData :: struct {
	using unit_data : MapUnitData;
	//TODO If we use this for other spaces then I can move it back to MapUnitData
	//I just can't think of another case where I'd do that know but maybe later... iunno
	x_grid_pos : int;
}

//TODO Could setup some kind of array data struct since we will likely
//reuse the concept.
SetMapPointData :: inline (ram_memory : *[] MemoryValue, ram_address : int,
	dspace_id_address : int, points : [] int)
{
	point_data := cast(*MapPointData) *((ram_memory.*)[ram_address]);
	point_data.dspace_id_address = dspace_id_address;
	point_data.point_count = points.count;
	pd_size : int = size_of(MapPointData) / 8;
	for points {
		(ram_memory.*)[ram_address + it_index + pd_size].int_value = it;
	}
}

/*TODO Should we move all this and MusicInstruction to thegame_code?
*/

//TODO Could make a CodeMemory object eventually so we can reset easily
//for now we use all_data just for consistency
//TODO Could also likely just pass in AllCodeData here but we have not really
//done the memory allocation everywhere yet so will just leave this for now.
/*TODO EVENTUALLY instead fo resetting we will just grab new data whenever
we execute from a pool and then that will always be reset so it won't affect anything else.
*/
ResetCodeMemory :: inline (all_data : *AllData) {
	//TODO Could do memset here for efficiency eventually.
	//Doing this for safet for now just in case.
	assert(all_data.all_register_memory.count == reg_def_enums.count);
	for * all_data.all_register_memory {
		it.* = .{};
	}
	// memset(all_data.all_register_memory.data, 0, 
	// 	size_of(MemoryValue) * all_data.all_register_memory.count);

	all_data.all_register_memory[RegDef.hsp].int_value = all_data.ram_memory.stack_size;
	all_data.all_register_memory[RegDef.hcp].int_value = all_data.all_register_memory[RegDef.hsp].int_value;


	//TODO For now we don't reset anything because eventually we will
	//just grab new data only when we are running.

	//TODO Right now we get the same amount we store in bytes array
	//so we have it only in 1 place and don't get it confused.
	// reset(*all_data.ram_memory.ram_alloc_pool);
	// all_data.ram_memory.bytes.data = cast(*u8) 
	// 	get(*all_data.ram_memory.ram_alloc_pool, 
	// 		all_data.ram_memory.bytes.count);
}

/*This memory model allows for array bounds check in jai.
Consider using a stack pointer and heap pointer in here instead of a used variable.
*/
RAMMemory :: struct {
	//TODO If we use a char *u8 here then we can do using
	//and access the RAMMemory directly. Could also just
	//make an array operator overload.
	bytes : [..] u8;
	// ram_alloc_pool : Flat_Pool;

	//TODO Could have stack_start_address after null and constants
	//Then also stack_end_address instead of the size here.
	//I think heap can just be the end of the bytes array.
	//NOTE : stack size = heap_start_address
	//Should we rename this to heap_start_address?
	stack_size : int;

	//TODO This is here so we don't have a bunch of valid tests breaking. I can remove it later
	//but maybe we don't want null_address always (eg if we only have #asm block and no code)
	has_null_address : bool = false;
	null_address : int = 0;
	//TODO Should we just move these out since we will only use them in tests?
	//These are just for convenience. If we only use them in tests eventually
	//can make an external struct to move these out just for tests.
	stack_p : int;
	heap_p : int;

	//For debugging convenience
	debug_int : [] int;
}

//TODO Technically this should return a u8 so maybe use *u8 in RAMMemory instead.
operator [] :: (mem : RAMMemory, index: int) -> *u8 {
	return *mem.bytes[index];
}

//TODO I think these Push functions are unneecessary now and just
//have a separate stack_p in the tests if we need it instead of storing
//it in RAMMemory. Or could pass a value in and update it there.
//OR Could do like we had before and have a RAMPointer struct
//which updates any values we want in it separate from RAMMemory
PushRAMValues :: inline (arr : .. $T, r : *RAMMemory) -> int {
	return PushRAMValues(arr,r=r);
}
PushRAMValues :: inline (arr : [] $T, r : *RAMMemory) -> int {
	index : int = r.stack_p;
	PushRAMArray(arr, r);
	return index;
}

//TODO This should be Push and Set should be at a specific location
//so we don't have any mixups
PushRAMValue :: inline (v : $T, r : *RAMMemory) -> int {
	index : int = r.stack_p;
	v_ret : *T = PushStruct(T, r);
	v_ret.* = v;
	return index;
}

//TODO Stack and heap should be swapped in terms of direction
PushStack :: inline (size : s64, ram : *RAMMemory) -> *void {
	assert(ram.stack_p + size < ram.heap_p);
   result : *void = ram.bytes.data + ram.stack_p;
   ram.stack_p += size;
   return result;
}

//TODO FROM HERE maybe do stack and heap like in computer memory
//and then update RAMMemory bytes and the mov
//OR can start on mov and see how that feels for stack and heap
//TODO With Flat_Pool, this could just be a separate array 
//that the stack can't cross. We want 1 array for memory, so
//that the move instruction accesses the 1 array as memory
//and not 2 arrays.
//Also usually stack is from the top and heap from the bottom
//so we could also just put an array at the stack_p to see
//what's in it.
/*If we start heat from ram.bytes.count then we just subtract size.
But then the first value is off memory which could lead to errors.
This way also heap_p is always at the last placed piece of data.

We are starting from there now otherwise size-1 has a bug
Better to have out of bounds than a weird error like that.
*/
PushHeap :: inline (size : s64, ram : *RAMMemory) -> *void {
	assert(ram.heap_p - size > ram.stack_p);
    // ram.heap_p -= size - 1; //This way we have a bug if size == 1 repeatedly
    ram.heap_p -= size; //If we started from bytes.count
    result : *void = ram.bytes.data + ram.heap_p;
    return result;
}

//TODO Change names to heap and stack
PushStruct :: inline ($type : Type, data : *RAMMemory) -> *type {
	result := cast(*type) PushStack(size_of(type), data);
	return result;
}

PushMulti :: inline ($type : Type, count : s64, data : *RAMMemory) -> *type {
    result := cast(*type) PushStack(size_of(type) * count, data);
    return result;
}

PushString :: inline (s : string, ram_mem : *RAMMemory) -> count : int, data : int {
	push_address : int = ram_mem.stack_p;
	push_data : *u8 = PushMulti(u8, s.count, ram_mem);
	memcpy(push_data, s.data, s.count);
	return s.count, push_address;
}

HeapMulti :: inline ($type : Type, count : s64, data : *RAMMemory) -> *type {
    result := cast(*type) PushHeap(size_of(type) * count, data);
    return result;
}

PushRAMArray :: inline (array : [] $T, ram : *RAMMemory) -> count : int, data : int {
	data : int = ram.stack_p;
	result : [] T;
   result.data = PushMulti(T, array.count, ram);
   result.count = array.count;
   for array result[it_index] = it;
   //TODO memcpy is not copying all the time. Maybe a stack data pointer issue.
   // memcpy(result.data, array.data, array.count);
   return array.count, data;
}

//TODO Can remove this function now with RAM_ARRAY
/*This imitates how arrays would be loaded in code so that we can
use them consistently for music memory.
TODO Need to update this to use RAM_ARRAY now.
*/
PushRAMArrayAndCount :: inline (array : [] $T, data : *RAMMemory) -> int {
	//Push array view
	index : int = data.stack_p;
	PushRAMValue(array.count, data);
	//Push fixed array values
	// data_address : int = data.stack_p;
	PushRAMArray(array, data);
	// PushRAMValue(data_address, data);
   return index;
}

PushRAMString :: inline (s : string, ram : *RAMMemory) -> count : int, data : int {
	data : int = ram.stack_p;
   result_data := cast(*u8) PushStack(s.count, ram);
   // for array result[it_index] = it;
   //TODO memcpy is not copying all the time. Maybe a stack data pointer issue.
   memcpy(result_data, s.data, s.count);
   return s.count, data;
}

PushRAMCountData :: inline (count : int, data : int, ram : *RAMMemory) -> int {
	stack_start_address : int = PushRAMValue(count, ram);
	PushRAMValue(data, ram);
   return stack_start_address;
}

//TODO I am not sure this function is in fact useful anywhere other
//than mov instruction? So I am not using it for now unless it is reused properly.
SetRAMMem :: inline (location : int, v : *u8, size : int, r : *RAMMemory) {
	assert(v != null && r != null);
	m_ptr : *u8 = GetMemory(location, size, r);
	assert(m_ptr != null);
	memcpy(m_ptr, v, size);
}

SetRAMValue :: inline (location : int, v : $T, r : *RAMMemory) -> CPUError {
	p, err := GetMemPtr(location, T, r);
	assert(p != null);
	p.* = v;
	return err;
}

//TODO Should this return a CPUError for consistency or do we want different errors in different places?
//Right now we could have out of bounds access or out of heap memory, so it seems like different messages are needed.
MemoryInBounds :: inline (ram : RAMMemory, location : int, size : int = 0) -> CPUError {
	if location + size < ram.bytes.count && location >= 0 && size >= 0 {
		return NO_CPU_ERROR;
	}
	err := CPUErr(sprint("Memory out of bounds : %. RAM location is % and size is % bytes.\n", 
		ram.bytes.count, location, size,,context.allocator));
	return err;
}

//TODO Rename to GetRAMMem and ones below as well
GetMemory :: inline (location : int, size : int, ram : RAMMemory) -> *u8, CPUError {
	#if 1 {
	bounds_err := MemoryInBounds(ram, location, size);
	if bounds_err.is_error return null, bounds_err;

	rm : *u8 = *ram.bytes[location];
	return rm, NO_CPU_ERROR;
	} else {
	//TODO Leaving here for now but can remove since above case has separate out memory bounds check.
	if location + size < ram.bytes.count && location >= 0 && size >= 0 {
		rm : *u8 = *ram.bytes[location];
		return rm, CPUError.{};
	} else {
		err := CPUErr(sprint("Memory out of bounds : %. RAM location is % and size is % bytes.\n", 
			ram.bytes.count, location, size,,context.allocator));
		return null, err;
	}
	}
}

//TODO Could make one that increments by size type instead of bytes
//although I'm not sure if that's convenient right now.
GetMemValue :: inline (location : int, $type : Type, ram : RAMMemory) -> type, CPUError {
	rm, err := GetMemPtr(location, type, ram);
	//TODO This is a sanity check, we should never be returning null as this should be
	//checked beforehand that it is in bounds for GetMemory.
	assert(rm != null);
	return rm.*, err;
}

GetMemPtr :: inline (location : int, $type : Type, ram : RAMMemory) -> *type, CPUError {
	rm, err := GetMemory(location, size_of(type), ram);
	return (cast(*type) rm), err;
}

GetMemArray :: inline (location : int, count : int, $type : Type, ram : RAMMemory) -> [] type, CPUError {
	array_data, err := GetMemory(location, count * size_of(type), ram);
	arr : [] type;
	arr.data = cast(*type) array_data;
	arr.count = count;
	return arr, err;
}
GetAsmArray :: inline (asm_array : AsmArray($array_type), ram : RAMMemory) -> [] array_type, CPUError {
	asm_array, array_err := GetMemArray(asm_array.data_address, asm_array.count, asm_array.array_type, ram);
	return asm_array, array_err;
}

UpdateLogicMusicOp :: inline (
	op_code : OpCode, 
	mp : *MusicPoint,
	shft_dist : int,
	rotate_bound : int) 
{
	if op_code == {
	case OpCode.shr;
		//TODO What if we go over the row_size? Do we even want row_size or do we want it to just match
		//the max note count anyways and then we adjust that by checking before rendering or playing audio?
		mp.x_start += shft_dist;
		mp.x_end += shft_dist;
	case OpCode.shl;
		mp.x_start -= shft_dist;
		mp.x_end -= shft_dist;
	case OpCode.ror;
		mp.x_start = PosMod(mp.x_start + shft_dist, rotate_bound);
		mp.x_end = PosMod(mp.x_end + shft_dist, rotate_bound);
	case OpCode.rol;
		mp.x_start = PosMod(mp.x_start - shft_dist, rotate_bound);
		mp.x_end = PosMod(mp.x_end - shft_dist, rotate_bound);
	}
}

ArithmeticMusicOp :: inline (
	op_code : OpCode,
	op_int : int,
	op_float : float64, 
	mp : *MusicPoint) 
{
	if op_code == {
	//TODO Need to do PosMod here based on the TuningSystem
	//OR could have a DataConstantType which says if we do PosMod by default
	//or not and if not then we would have a runtime error
	case OpCode.add;
		mp.music_pt_pos += op_int;
		mp.music_pt_float += op_float;
	case OpCode.sub;
		mp.music_pt_pos = ClampMin(0, mp.music_pt_pos - op_int);
		mp.music_pt_float = ClampMin(cast(float64) 0, mp.music_pt_float - op_float);
	case OpCode.mod;
		mp.music_pt_pos = PosMod(mp.music_pt_pos, op_int);
		mp.music_pt_float = PosMod(mp.music_pt_float, op_float);
	case OpCode.div;
		mp.music_pt_pos /= op_int;
		mp.music_pt_float /= op_float;
	case OpCode.mul;
		mp.music_pt_pos *= op_int;
		mp.music_pt_float *= op_float;
	}
}

/*TODO We should use this one instead of ArithmeticMusicOp even for MusicMemory so it works with
subtraction (inversion) and division as well.
*/
//TODO This can just return a float value and be set once we remove music_pt_pos if that makes more sense
DirectionArithmeticOp :: inline (
	op_code : OpCode,
	left_float : float64,
	right_float : float64,
	mp : *MusicPoint) 
{
	if op_code == {
	case OpCode.tadd;
		mp.music_pt_float = left_float + right_float;
	case OpCode.tsub;
		//TODO Should we allow negative music_pt_pos here and then just not play or render them?
		//This way they can be modded for example if needed.
		//Need to check if that works with rendering music_pts on linear row
		// mp.music_pt_float = ClampMin(cast(float64) 0, left_float - right_float);
		mp.music_pt_float = left_float - right_float;
	case OpCode.tmod;
		//TODO We could use fmod_cycling OR have a separate operation for modulo that stays negative/positive
		//depending on the mod value.
		mp.music_pt_float = PosMod(left_float, right_float);
	case OpCode.tdiv;
		mp.music_pt_float = left_float / right_float;
	case OpCode.tmul;
		mp.music_pt_float = left_float * right_float;
	}
	//TODO Remove this once we remove music_pt_pos and can just round whenever we need and int for midi for example
	mp.music_pt_pos = round_to_int(mp.music_pt_float);
}

//TODO Could we just use a generic linear function in the math module?
ComputeMemoryIndex :: inline (
	x_index : int,
	row_index : int,
	row_size : int)
-> int
{
	memory_index : int = (row_index * row_size) + x_index;
	return memory_index;
}

ComputeXAndRowIndex :: inline (
	memory_index : int,
	row_size : int)
-> x_index : int, row_index : int
{
	row_index, x_index := ComputeQuotientAndRemainder2(memory_index, row_size);
	return x_index, row_index;
}

//TODO This is only used for old tests, can remove if we remove that test.
GetAllMemoryIndexMusicPtPointers :: inline (
	memory_index : int,
	row_size : int,
	all_music_pts : [] MusicPoint,
	allocator : Allocator = temp)
-> [] *MusicPoint
{
	x_index, row_index := ComputeXAndRowIndex(memory_index, row_size);
	return GetAllMusicPtPosByPosition(row_index, x_index, all_music_pts, *MusicPoint);
}


/*TODO
	this can return all dspaces of all types eventually
*/
GetAllDSpacesInOpSpace :: inline (
	op_space_id : int,
	all_dspace_to_op_space : [] DSpaceToOpSpace,
	all_linear_pitch_spaces : [] LinearPitchSpace,
	allocator : Allocator = temp)
-> [] LinearPitchSpace
{
	array_dspace_to_op_space : [] DSpaceToOpSpace = 
		ArrayFindAllVarName(all_dspace_to_op_space, op_space_id, "op_space_id", temp);

	array_linear_spaces_in_op_space : [] LinearPitchSpace =
		ArrayFindAllByBothNames(
			all_linear_pitch_spaces, "dspace_id",
			array_dspace_to_op_space, AllOrEqualsVarName, "dspace_id",
			temp);

	return array_linear_spaces_in_op_space;
}

OffsetSpaceToWorldSpace :: inline (
	offset_pos : Vector2F,
	world_offset : Vector2F,
	offset_cam_pos : Vector2F)
-> Vector2F
{
	world_pos : Vector2F = 
		offset_pos - offset_cam_pos + world_offset;
	return world_pos;	
}

/*TODO
We no longer use this in favor of just moving the op_space
based on the camera movement that frame.
*/
// GetOpSpaceWorldCam :: inline (
// 	op_space : OperationSpace,
// 	default_base_cam : Camera2D) 
// -> Camera2D
// {
// 	op_world_cam : Camera2D = default_base_cam;
// 	if op_space.is_fixed_to_camera {
// 		op_world_cam.world_pos = Vector2F.{0,0};
// 	}
// 	return op_world_cam;
// }

//TODO should we store music_pt_set_id in here for convenience?
//this would also make it easier to use as a SetOfMPS
DSpaceToOpSpace :: struct {
	dspace_id : int;
	op_space_id : int;
	//TODO this is stored in DSpaceSetToOpSpace
	//do we need in both places for convenience?
	op_grid_pos : Vector2I;
	//TODO should we store dspace type in here

	//TODO Should we have a separate DSpaceToOpSpace order here
	//instead of using rhythm. Yes, that seems more flexible in general
	//and we may also want options where there is no rhythm to the 
	//dspace_set in general.
}

GetAllLinearSpacesInOpSpace :: inline (
	op_space_id : int,
	all_base_dspace_to_op_space : [] DSpaceToOpSpace,
	all_linear_pitch_spaces : [] LinearPitchSpace,
	allocator : Allocator = temp) 
-> [] LinearPitchSpace
{
	current_dspace_to_op_space : [] DSpaceToOpSpace = 
		ArrayFindAllVarName(all_base_dspace_to_op_space, op_space_id, "op_space_id", allocator);

	array_dspace_in_op_space : [] LinearPitchSpace = 
		ArrayFindAllByBothNames(all_linear_pitch_spaces, "dspace_id", 
			current_dspace_to_op_space, AllOrEqualsVarName, "dspace_id", allocator);

	return array_dspace_in_op_space;
}

/*TODO
	instead of storing this in data structs could have a separate
	table which stores all dspace_ids and their associated types
*/
DSpaceType :: enum {
	LINEAR_PITCH_SPACE;
	CIRCULAR_PITCH_CLASS_SPACE;
	CHORD_S2;
	CHORD_S3;
	PIANO_ROLL;

	DSPACE_SET_GROUP; //TODO

	CIRCULAR_RHYTHM_SPACE;
}


/*TODO These could be pointers so that if data changes
we don't have to change it here.

OscWave is stored here so its not a pointer but it may be
more efficient eventually to have an OscWave pool so we don't
have to recreate them and also if different music_points share
different synth value because theyre on the same lane.
*/
MusicPointAndOscWave :: struct {
	music_pt : MusicPoint;
	osc_wave : OscWave;
	//TODO ultimately we can just store the frequency
	//and pass that to the synthesizer but it depends
	//on the synthesizer so maybe we just pass everything
	//to the synthesizer anyways
	tuning_system_id : int;
}

/*DOC : Likely will need to update this to a synth once we implement that.
So then we could have an array for each synth type and each synth
would have an array of osc waves.
MySimpleSynth - no filter just, wave and adsr (this should be very fast so we can have a lot of them)
MyFilterSynth - add filtering and lfo after processing (can maybe just do filtering if lfo is too much)
TODO Currently use GenerateSamples and pass in audio thread buffer and then
we will update it to use synths and then we will associate synths to rows
and then also have a default synth for hovering or maybe specific for op spaces.

REMINDER : Anything with locked prefix requires the audio mutex.

TODO I think i can remove this since I was using this when generating
the audio in the audio thread but now we use the circular buffer so we don't need this anymore.
*/
LockedSoundData :: struct {
	audio_thread_play_cursor : int;
	audio_thread_play_sample : int;
	//TODO Maybe this should be in global scope like in Sound_Player
	//so we don't accidentally have alternate ones.
	audio_mutex : Mutex;
	//TODO Maybe this could just be the simple synth
	locked_audio_queue : [..] OscWave;
	simple_waves : [..] OscWave;
	//TODO Could have a separate more complex synth queue here
	//with filters and/or lfos

	stop_neume_audio : bool;
	locked_audio_events : [..] AudioEvent;

	//For hovering, likely will not allow this to be changed other than
	//with the mouse hovering changing frequency and other things if needed.
	hover_waves : [] OscWave;
}

PlayingMidi :: struct {
	//TODO Remove x_end once we only have float
	x_end : int;
	x_end_float : float64;
	//TODO Should this be float64 and just cast or round for midi?
	music_pt_pos : int;
	midi_channel : u8;
}

MusicLine :: struct {
/*TODO If we wanted to change the frequency while the note is playing, we could interpolate between them
and store the MusicLine between them which just stores the 2 music points. Currently this would work
in AddSignalToAudioBuffer because we simply adjust the frequency and add the radians from wherever
the wav was playing. This would however not necessarily work in midi since the changes would not be fine_grained.
Likely that most synths would have a fine tuning knob which can then be mapped to a MusicLine and then we can overlap
those rows to see the point and the line in the same row.
*/
}

/*NOTE TODO : For now we only have 2 music_pt arrays but eventually we will want
to be able to get the music_pts array from any music space with this.
I am not sure if I want to set the stack music space to be -1 or something else (88?).
This leaves it ambiguous for now.
*/
GetMSpaceNeumes :: inline (mspace_index : int, ad : *AllData) -> *[..] MusicPoint {
	//TODO I Think we can just use negative mspace_index for tano since we can't
	//access those in the array anyways and then have a separate tano_stack_mspace_data
	//array where we take the absolute value of the mspace_index and grab by index like that.
	if mspace_index != 0 {
		return *ad.tano_stack_music_pts;
	}
	return *ad.all_mspace_data[0].all_music_pts;
}

//TODO Not sure we need this anymore.
//Can remove if we don't use anywhere.
IncrementMemX :: inline (
	old_x : int, old_row : int,
	row_size : int, row_count : int) 
-> new_x : int, new_row : int
{
	new_row : int = old_row;
	new_x : int = old_x + 1;
	if new_x > row_size {
		new_x %= row_size;
		new_row += 1;
		if new_row >= row_count {
			//TODO Return user error went over max row.
			//We could also not create this and return a user error.
		}
	}
	return new_x, new_row;
}

UNINITIALIZED_TUNING_PITCH : int : -666;
MakeOldMusicPoint :: inline (
	music_pt_pos : int,
	invariant_id : int)
-> MusicPoint 
{
	music_pt : MusicPoint;
	music_pt.id = context.ALL_NEXT_IDS.NEXT_MUSIC_POINT_ID;
	defer context.ALL_NEXT_IDS.NEXT_MUSIC_POINT_ID += 1;
	music_pt.invariant_id = invariant_id;
	music_pt.music_pt_pos = music_pt_pos;
	return music_pt;
}

ReplaceMusicPtsInMemory :: inline (
	input_music_pt_poses : [] $T,
	x_pos : int,
	row_index : int,
	all_music_pts : *[..] MusicPoint)
-> [] MusicPoint
{
	RemoveAllMusicPtsInMemory(row_index, x_pos, all_music_pts);

	result_music_pts : [] MusicPoint = NewArray(input_music_pt_poses.count, MusicPoint, false,, temp);
	for music_pt_pos, input_index : input_music_pt_poses {
		result_music_pts[input_index] = MakeMemoryMusicPoint(music_pt_pos, x_pos, x_pos+1, row_index);
	}

	CreateManyMusicPtsInMemory(result_music_pts, all_music_pts);
	return result_music_pts;
}

CreateMusicPtByIType :: inline (
	instr_type : InstructionType,
	mv : MemoryValue,
	//TODO These could also allow float for rhythm eventually.
	x_start : $T, x_end : T,
	row_index : int,
	all_music_pts : *[..] MusicPoint)
-> *MusicPoint
{
	mp : *MusicPoint;
	if #complete instr_type == {
	case .INTEGER; mp = CreateMusicPtInMemory(mv.int_value, row_index, x_start, x_end, all_music_pts);
	case .FLOAT; mp = CreateMusicPtInMemory(mv.float_value, row_index, x_start, x_end, all_music_pts);
	}
	return mp;
}

CreateMusicPtInMemory :: inline (
	music_pt : MusicPoint,
	all_music_pts : *[..] MusicPoint)
-> *MusicPoint
{
	mp : *MusicPoint = array_add(all_music_pts);
	mp.* = music_pt;
	return mp;
}

//Leaving old method just in case but can remove if we never use.
//New way is more efficient since we access memory directly and more flexible 
//since we can return a pointer if needed.
//MOVED TO shared library so we can remove if we don't need it here anymore
#if 0 {
CreateManyMusicPtsInMemory :: inline (
	input_music_pt_poses : [] $T,
	row_index : int,
	//R is checked in SetMemoryMusicPoint. (float, float64 and int for convenience)
	x_start : $R, x_end : R,
	all_music_pts : *[..] MusicPoint)
-> [] MusicPoint
{
	//TODO Could just return an array view although it would be incorrect if we change values in the all_music_pts later.
	result_music_pts : [] MusicPoint = NewArray(input_music_pt_poses.count, MusicPoint, false,, temp);
	for input_music_pt_poses {
		mp : *MusicPoint = CreateMusicPtInMemory(it, row_index, x_start, x_end, all_music_pts);
		result_music_pts[it_index] = mp.*;
	}
	return result_music_pts;
}
} else #if 0 {
CreateManyMusicPtsInMemory :: inline (
	input_music_pt_poses : [] int,
	x_start : int, x_end : int,
	row_index : int,
	all_music_pts : *[..] MusicPoint)
-> [] MusicPoint
{
	result_music_pts : [] MusicPoint = NewArray(input_music_pt_poses.count, MusicPoint, false,, temp);
	for music_pt_pos, input_index : input_music_pt_poses {
		result_music_pts[input_index] = MakeMemoryMusicPoint(music_pt_pos, x_start, x_end, row_index);
	}

	CreateManyMusicPtsInMemory(result_music_pts, all_music_pts);
	return result_music_pts;
}
}

//TODO Not sure why we would use this... but it's here. Leaving for now.
#if 0 {
CreateManyMusicPtsInMemory :: inline (
	input_music_pts : [] MusicPoint,
	x_start : int, row_index : int,
	row_size : int,
	all_music_pts : *[..] MusicPoint)
-> [] MusicPoint
{
	new_music_pts : [] MusicPoint = NewArray(input_music_pts.count, MusicPoint, false,, temp);
	for input_pt, i : input_music_pts {
		new_music_pts[i] = input_pt;
		x_length : int = input_pt.x_end - input_pt.x_start;
		new_music_pts[i].x_start = x_start;
		//TODO Check if x + 1 goes to beginning of next in rendering and audio.
		new_music_pts[i].x_end = ClampMax(x_start+x_length, row_size);
		new_music_pts[i].row_index = row_index;
	}

	CreateManyMusicPtsInMemory(new_music_pts, all_music_pts);
	return new_music_pts;
}
}

//Leaving old method just in case but can remove if we never use
#if 1 {
CreateManyMusicPtsInMemory :: inline (
	input_music_pts : [] MusicPoint,
	all_music_pts : *[..] MusicPoint,
	$with_return : bool = false)
-> [] *MusicPoint
{
	#if with_return {
	result : [..] *MusicPoint;
	result.allocator = temp;
	}
	for music_pt : input_music_pts {
		//TODO could replace this with a memcpy
		mp : *MusicPoint = CreateMusicPtInMemory(music_pt, all_music_pts);
		#if with_return array_add(*result, mp);
	}
	#if with_return return result;
	return .[];
}
} else {
CreateManyMusicPtsInMemory :: inline (
	input_music_pts : [] MusicPoint,
	all_music_pts : *[..] MusicPoint,
	$with_return : bool = false)
-> [] *MusicPoint
{
	#if with_return {
	result : [..] *MusicPoint;
	result.allocator = temp;
	}
	for music_pt : input_music_pts {
		//TODO could replace this with a memcpy
		array_add(all_music_pts, music_pt);
		#if with_return {
		array_add(*result, *((all_music_pts.*)[all_music_pts.count-1]));
		}
	}
	#if with_return return result;
	else return .[];
}
}

//New Music Point functions
//Making a section here as maybe it's worth pulling this out somehow
//TODO could set this context in thegame_base instead of external_dll if needed.
#add_context c_all_data : *AllData;
NewCreateMusicPtInMemory :: inline (
	music_pt_pos : int,
	x_start : int, x_end : int,
	row_index : int)
-> MusicPoint
{
	music_pt : MusicPoint = MakeMemoryMusicPoint(music_pt_pos, x_start, x_end, row_index);
	array_add(*context.c_all_data.all_mspace_data[0].all_music_pts, music_pt);
	return music_pt;
}

NewReplaceMusicPtsInMemory :: inline (
	input_music_pt_poses : [] $T,
	x_pos : int,
	row_index : int)
{
	ReplaceMusicPtsInMemory(input_music_pt_poses, x_pos, row_index, *context.c_all_data.all_mspace_data[0].all_music_pts);
}

/*TODO 
Could pull out all the new musical operators
*/

//TODO Could return [] MusicPoint
//Note : We need both [] and []= operator overloads to have []= working for the compiler.
#if 0 {
operator [] :: (row : MusicLaneRow, index: int) -> [] *MusicPoint {
	return GetAllMusicPtPosByPosition(row.total_row_index, index, context.c_all_data.all_mspace_data[0].all_music_pts, *MusicPoint);
}

operator []= :: (row : *MusicLaneRow, index: int, value: [] *MusicPoint) {
	RemoveAllMusicPtsInMemory(row.total_row_index, index, *context.c_all_data.all_mspace_data[0].all_music_pts);
	for pointer : value {
		mp : MusicPoint = MakeMemoryMusicPoint(pointer.music_pt_pos, index, index+1, row.total_row_index);
		array_add(*context.c_all_data.all_mspace_data[0].all_music_pts, mp);
	}
}
} else #if 1 {
//TODO FROM HERE could write some simple tests for all these operators so we know it works if
//we change data model things later.
operator [] :: (row : MusicLaneRow, index: int) -> AggregateMusicPts {
	amp : AggregateMusicPts;
	amp.row_index = row.total_row_index;
	amp.x_start = index;
	amp.pts = GetAllMusicPtPosByPosition(row.total_row_index, index, context.c_all_data.all_mspace_data[0].all_music_pts, MusicPoint);
	return amp;
}

#if 0 {
operator [] :: (row : MusicLaneRow, index: float) -> AggregateMusicPts {
	amp : AggregateMusicPts;
	amp.row_index = row.total_row_index;
	amp.x_start = index;
	amp.pts = GetAllMusicPtPosByPosition(row.total_row_index, cast(int)index, context.c_all_data.all_mspace_data[0].all_music_pts, MusicPoint);
	return amp;
}
}

operator []= :: (row : *MusicLaneRow, index: int, value: AggregateMusicPts) {
	RemoveAllMusicPtsInMemory(row.total_row_index, index, *context.c_all_data.all_mspace_data[0].all_music_pts);
	for pointer : value.pts {
		mp : MusicPoint = MakeMemoryMusicPoint(pointer.music_pt_float, index, index+1, row.total_row_index);
		array_add(*context.c_all_data.all_mspace_data[0].all_music_pts, mp);
	}
}

operator []= :: (row : *MusicLaneRow, index: float, value: AggregateMusicPts) {
	RemoveAllMusicPtsInMemory(row.total_row_index, cast(int)index, *context.c_all_data.all_mspace_data[0].all_music_pts);
	for pointer : value.pts {
		mp : MusicPoint = MakeMemoryMusicPoint(pointer.music_pt_float, cast(int)index, cast(int)index+1, row.total_row_index);
		array_add(*context.c_all_data.all_mspace_data[0].all_music_pts, mp);
	}
}

operator [] :: (row : AggregateMusicPts, index: int) -> MusicPoint {
	return row.pts[index];
}	

#if 0 {
operator []= :: (amp_out : *AggregateMusicPts, index: float, value: MusicPoint) {
	amp_in.pts[index];
}
}
}

//TODO Should we just have [] float64 arrays now instead of [] MusicPoint
//We already have the x_start and row_index...
AggregateMusicPts :: struct {
	//TODO Should we also include a ptr array here?
	//This could let the user update things however they want easily.
	#as pts : [] MusicPoint;
	x_start : int;
	row_index : int;
}

operator []= :: (row : *MusicLaneRow, index: int, value: int) {
	array : [1] int;
	array[0] = value;
	NewReplaceMusicPtsInMemory(array, index, row.total_row_index);
}

operator []= :: (row : *MusicLaneRow, index: int, value: float64) {
	array : [1] float64;
	array[0] = value;
	NewReplaceMusicPtsInMemory(array, index, row.total_row_index);
}

operator []= :: (row : *MusicLaneRow, index: int, value: [] $T) {
	NewReplaceMusicPtsInMemory(value, index, row.total_row_index);
}

#if 0 {
//TODO We could access memory_index directly with an array operator
//this way as well or anything really.
MemoryIndex :: struct {
}

operator [] :: (row : *MemoryIndex, index: int, value: [] $T) -> AggregateMusicPts {
	amp : AggregateMusicPts;
	amp.row_index = row.total_row_index;
	amp.x_start = index;
	//TODO Compute row from index
	amp.pts = GetAllMusicPtPosByPosition(row.total_row_index, index, context.c_all_data.all_mspace_data[0].all_music_pts, MusicPoint);
	return amp;
}	
}

InterOnsetIntervals :: struct {
	intervals : [] int;
	start_index : int;
}

operator []= :: (row : *MusicLaneRow, index: int, value: InterOnsetIntervals) {
	music_pt_ints : [] int = NewArray(value.intervals.count,int,true,,temp);
	music_pt_ints[0] = value.start_index;
	for 0..value.intervals.count-2 {
		music_pt_ints[it+1] = value.intervals[it] + music_pt_ints[it];
	}
	NewReplaceMusicPtsInMemory(music_pt_ints,index,row.total_row_index);
}

Inter :: inline (row : MusicLaneRow) -> InterOnsetIntervals {
	return Inter(row,0,context.c_all_data.global_rules.row_size-1);
}

Inter :: inline (row : MusicLaneRow, start : int, end : int) 
-> InterOnsetIntervals 
{
	ioi_intervals : [..] int;
	ioi_intervals.allocator = temp;

	/*We split up into 2 arrays to simplify the processing
	since we are treating the inter-onset intervals row section
	as if it is a circular buffer.
	*/
	i : int = start;
	while row[i].pts.count == 0 i += 1;

	s0 : int = i;
	e0 : int = end;
	s1 : int = 0;
	e1 : int = i;

	ioi : InterOnsetIntervals;
	ioi.start_index = i;

	interval : int = 1;
	i = s0+1;
	while i <= e0 {
		while i <= e0 && row[i].pts.count == 0 {
			interval += 1;
			i += 1;
		}
		if i > e0 break;
		array_add(*ioi_intervals, interval);
		interval = 1;
		i += 1;
	}

	//Cycle back and finish the last interval
	i = s1;
	while i <= e1 && row[i].pts.count == 0 {
		interval += 1;
		i += 1;
	}	
	array_add(*ioi_intervals, interval);

	ioi.intervals = ioi_intervals;
	return ioi;
}

CopyRow :: inline (
	r0 : MusicLaneRow, 
	r1 : MusicLaneRow) 
{
	CopyRow(r0,0,context.c_all_data.global_rules.row_size-1,
			r1,0,context.c_all_data.global_rules.row_size-1);
}

CopyRow :: inline (
	r0 : MusicLaneRow, 
	r1 : MusicLaneRow, start : int, end : int) 
{
	CopyRow(r0,start,end,r1,start,end);
}

CopyRow :: inline (
	row_0 : MusicLaneRow, start_0 : int, end_0 : int,
	row_1 : MusicLaneRow, start_1 : int, end_1 : int) 
{
	//TODO For now we assert but this should just produce
	//and error message
	assert(end_0 - start_0 == end_1 - start_1);

	i1 : int = start_1;
	for i0 : start_0..end_0 {
		row_1[i1] = row_0[i0];
		i1 += 1;
	}
}

ShiftRow :: inline (shift : int, row_0 : MusicLaneRow, row_1 : MusicLaneRow) {
	ShiftRow(shift, 
		row_0, 0, context.c_all_data.global_rules.row_size-1,
		row_1, 0, context.c_all_data.global_rules.row_size-1);
}

ShiftRow :: inline (shift : int,
	row_0 : MusicLaneRow, start_0 : int, end_0 : int,
	row_1 : MusicLaneRow, start_1 : int, end_1 : int)
{
	//Make sure theres no overlap so we don't mess up the shift. 
	//TODO Alternatively we could store a temp row.
	assert(end_0 - start_0 == end_1 - start_1);
	if row_0.total_row_index == row_1.total_row_index {
		assert((start_0 > start_1 && end_0 > end_1) ||
			   (start_0 < start_1 && end_0 < end_1));
	}
	n : int = end_0 - start_0 + 1;
	for i0 : start_0..end_0 {
		i1 : int = ((i0 + shift) % n) + (start_1-start_0);
		row_1[i1] = row_0[i0];
	}
}

ShiftRow :: inline (shift : int, row : MusicLaneRow) {
	ShiftRow(shift, row, 0, context.c_all_data.global_rules.row_size-1);
}

ShiftRow :: inline (shift : int, row : MusicLaneRow, start : int, end : int) {
	assert(end > start);
	n : int = end - start + 1;
	temp_row : [] AggregateMusicPts = NewArray(n,AggregateMusicPts,true,,temp);
	for i0 : start..end {
		i1 : int = ((i0 + shift) % n) + start;
		temp_row[i1] = row[i0];
	}

	i : int = start;
	for amp : temp_row {
		row[i] = amp;
		i += 1;
	}
}

RowToVertical :: inline (row : MusicLaneRow) -> AggregateMusicPts
{
	return RowToVertical(row, 0, context.c_all_data.global_rules.row_size-1);
}

RowToVertical :: inline (
	row : MusicLaneRow, 
	row_start : int, row_end : int,
	vert_start : int = 0)
-> AggregateMusicPts
{
	vert_pts : [..] MusicPoint;
	vert_pts.allocator = temp;
	//TODO Could check that end < max_row_index
	i : int = 0;
	for row_start..row_end {
		if row[it].pts.count > 0 {
			array_add(*vert_pts, MakeMemoryMusicPoint(vert_start+i,0,0,0));
		}
		i += 1;
	}

	return_amp : AggregateMusicPts;
	return_amp.pts = vert_pts;
	return return_amp;
}

AggregateOpType :: enum u8 {
	AGGREGATE_ADD;
	AGGREGATE_SUB;
	AGGREGATE_SUB_REV;
	AGGREGATE_MULT;
	AGGREGATE_DIV;
	AGGREGATE_MOD;
}

AggregateOp :: inline ($agg_type : AggregateOpType, music_pts : AggregateMusicPts, value : $T) -> AggregateMusicPts {
	#assert(T == int || T == float);
	amp : AggregateMusicPts;
	amp.pts = NewArray(music_pts.pts.count, MusicPoint,, temp);
	for music_pts.pts {
		//TODO Can make this a switch statement since I think the new compiler version has compile time switch statements.
		#if agg_type == .AGGREGATE_ADD {
			amp.pts[it_index].music_pt_float = it.music_pt_float + value;
			amp.pts[it_index].music_pt_pos = round_to_int(it.music_pt_pos + value);
		} else #if agg_type == .AGGREGATE_SUB {
			amp.pts[it_index].music_pt_float = ClampMin(0.0,it.music_pt_float - value);
			amp.pts[it_index].music_pt_pos = ClampMin(0,round_to_int(it.music_pt_pos - value));
		} else #if agg_type == .AGGREGATE_SUB_REV {
			amp.pts[it_index].music_pt_float = ClampMin(0.0,value - it.music_pt_float);
			amp.pts[it_index].music_pt_pos = ClampMin(0,round_to_int(value - it.music_pt_pos));
		} else #if agg_type == .AGGREGATE_MULT {
			amp.pts[it_index].music_pt_float = it.music_pt_float * value;
			amp.pts[it_index].music_pt_pos = round_to_int(it.music_pt_pos * value);
		} else #if agg_type == .AGGREGATE_DIV {
			amp.pts[it_index].music_pt_float = it.music_pt_float / value;
			amp.pts[it_index].music_pt_pos = round_to_int(it.music_pt_pos / value);
		} else #if agg_type == .AGGREGATE_MOD {
			amp.pts[it_index].music_pt_float = fmod_cycling(it.music_pt_float, cast(float) value);
			amp.pts[it_index].music_pt_pos = it.music_pt_pos % round_to_int(value);
		}
	}
	return amp;
}

operator + :: (music_pts : AggregateMusicPts, value : $T) -> AggregateMusicPts #symmetric {
	return AggregateOp(.AGGREGATE_ADD, music_pts, value);
}
operator - :: (music_pts : AggregateMusicPts, value : $T) -> AggregateMusicPts {
	return AggregateOp(.AGGREGATE_SUB, music_pts, value);
}
operator - :: (value : $T, music_pts : AggregateMusicPts) -> AggregateMusicPts {
	return AggregateOp(.AGGREGATE_SUB_REV, music_pts, value);
}
operator * :: (music_pts : AggregateMusicPts, value : $T) -> AggregateMusicPts #symmetric {
	return AggregateOp(.AGGREGATE_MULT, music_pts, value);
}
operator / :: (music_pts : AggregateMusicPts, value : $T) -> AggregateMusicPts {
	return AggregateOp(.AGGREGATE_DIV, music_pts, value);
}
operator % :: (music_pts : AggregateMusicPts, value : $T) -> AggregateMusicPts {
	return AggregateOp(.AGGREGATE_MOD, music_pts, value);
}

TypeToFloatPts :: inline (a2 : $T) -> [] float64 {
	#assert(T == AggregateMusicPts || (T == [] int) || (T == [] float64) || T == int || T == float64);

	float_pts : [..] float64;
	float_pts.allocator = temp;
	#if T == AggregateMusicPts {
		for a2.pts array_add(*float_pts, it.music_pt_float);
	} else #if T == [] int {
		for a2 array_add(*float_pts, cast(float) it);
	} else #if T == [] float {
		float_pts = a2;
	} else #if T == int {
		array_add(*float_pts, cast(float) a2);
	} else #if T == float {
		array_add(*float_pts, a2);
	}

	return float_pts;
}

//TODO Should reuse what we do in Execute MusicInstruction here instead of separate functions
//Should we just have [] float64 arrays now instead of [] MusicPoint
operator && :: (a1 : AggregateMusicPts, a2 : $T) -> AggregateMusicPts #symmetric {
	float_pts : [] float64 = TypeToFloatPts(a2);
	and_pts : [..] MusicPoint;
	and_pts.allocator = temp;
	//Check if we have in both a1 and a2
	for m1: a1.pts {
		for m2: float_pts if FloatEqual(m1.music_pt_float, m2) {
			//Check if we have already added the point.
			for and_pts if FloatEqual(it.music_pt_float, m2) {
				break;
			}
			array_add(*and_pts, m1);
			break;
		}
	}

	amp : AggregateMusicPts;
	amp.pts = and_pts;
	return amp;
}

operator || :: (a1 : AggregateMusicPts, a2 : $T) -> AggregateMusicPts #symmetric {
	float_pts : [] float64 = TypeToFloatPts(a2);
	or_pts : [..] MusicPoint;
	or_pts.allocator = temp;
	for m1: a1.pts {
		for or_pts if Float64Equal(it.music_pt_float, m1.music_pt_float) {
			continue;
		}
		array_add(*or_pts, m1);
	}

	for m2: float_pts {
		for or_pts if Float64Equal(it.music_pt_float, m2) {
			continue;
		}
		mp : MusicPoint;
		mp.music_pt_float = m2;
		mp.music_pt_pos = round_to_int(m2);
		array_add(*or_pts, mp);
	}

	amp : AggregateMusicPts;
	amp.pts = or_pts;
	return amp;
}
//End of new music point functions

/*
	This mapping functions will map our MusicPoints to a specified linear_space by the dspace_id.
	Untested but this will likely work for circular_spaces as well.

	Note that this will return the SpacePoints in the same order
	as the MusicPoints were passed in.

	TODO similar mapping functions for higher dspaces
*/
//TODO Should have a version that uses all_space_points directly
//since we can pass it in beforehand without filtering
MapMusicPtsToSpace2D :: inline (
	input_music_pts : [] MusicPoint,
	dspace_id : int,
	all_space_points : [] SpacePoint)
-> [] SpacePoint
{
	return_music_to_space_pts : [] SpacePoint = NewArray(input_music_pts.count, SpacePoint, false,, temp);

	points_in_space : [] SpacePoint = ArrayFindAllVarName(all_space_points, dspace_id, "dspace_id", temp);
	//TODO since space_points are left ordered and only get removed altogether, we only need to sort
	//if the space_points get moved around eventually
	// quick_sort(points_in_space, (p1,p2) => p1.int_pos.x - p2.int_pos.x);

	for music_pt, music_pt_index : input_music_pts
	{
		modded_music_pt_pos : int = music_pt.music_pt_pos % points_in_space.count;
		return_music_to_space_pts[music_pt_index] = points_in_space[modded_music_pt_pos];
	}

	return return_music_to_space_pts;
}

/*TODO Could eventually replace this with AllAudioAction
only so that we only have a set of actions and not
an array of events. It does not seem like we will need
more than 1 of each event and having a set will avoid
overlapping events for reset and duplicates for stop and play
*/
//TODO Could rename to SetAudioEvent and use it
//for playing or reset since they are similar logic
AudioEvent :: struct {
	// CHANGE THIS NAME AS WELL
	initial_x_memory : int;
	x_float : float64;
	audio_event_type : AudioEventType;
}

AudioEventType :: enum u8 {
	RESET_AUDIO_TO_MEMORY_UNIT;
	SET_AUDIO_TO_X_FLOAT;
	PLAY_NOTES_AT_CURRENT_MEMORY;
	STOP_ALL_MUSIC_PTS;
}

MakeAudioEvent :: inline (
	audio_event_type : AudioEventType,
	initial_x_memory : int = 0,
	x_float : float64 = 0)
-> AudioEvent
{
	audio_event : AudioEvent = ---;
	audio_event.audio_event_type = audio_event_type;
	audio_event.initial_x_memory = initial_x_memory;
	audio_event.x_float = x_float;
	return audio_event;
}

/*Testing another way to do audio in order to avoid duplicates
and not reprocess data.
With this method, order must be fixed so we are also
leaving the AudioEvent method just in case the order does
eventually matter.
*/
SetAudioPositionData :: struct {
	is_set : bool;

	set_audio_mspace_id : int;

	set_audio_type : SetAudioType;
	memory_unit : int;
	memory_x_float : float64;
}
SetAudioType :: enum {
	SET_MEMORY_UNIT;
	SET_MEMORY_X_FLOAT;
}

/*TODO 
  these could be replaced with rhythm units which would be the
  smallest possible beat fraction in the level (eg 1/256)
  and the base rhythm unit would be associated to some base
  fraction of a beat (eg 1/256th of a beat)

  --- Some bounds for rhythm unit denominations ---
  240bpm=4bps=0.25spb each rhythm unit = 0.25 seconds
  with a u32 that means we would have 
  2^32 * 0.25s = 1,073,741,824s = 34 years

  if rhythm unit = 0.25s / 256 = 0.0009765625s then 2^32 * 0.0009765625s = 4,194,304s = 48 days
  if rhythm unit = 0.25s / 128 = 0.001953125s then 2^32 * 0.001953125s = 8,388,608s = 96 days
  if rhythm unit = 0.25s / 64 = 0.00390625s then 2^32 * 0.00390625s = 16,777,216s = 192 days

  this would allow for optimization in terms of using discrete
  integer values for beats and potentially less than 64 bits

  this rhythm unit idea would work well with a separate beat offset 
  for smaller beat variations 

  ***sorting is a good reason to use rhythm_units, since sorting
  by float64 (which is a common operation) requires casting to int
  and so it is better that we just have int in the first place***
*/

//TODO Some old functions that are no longer used with compile-time array or other
//types. Leaving here in case someone needs them but otherwise we can remove eventually.
//TODO Is it better to pass in fun_region_pos : [chord_dim] int directly?
//seems less prone to weird errors
#if 0 {
FunRegionPosToPitchSet :: inline (
	fun_region_pos : [$chord_dim] $T,
	tuning_system_count : int)
-> [chord_dim] T
{
#assert(T == int || T == float || T == float64);
	pitch_set : [chord_dim] T;
	for 0..chord_dim-1 {
		pitch_set[it] = PosMod(fun_region_pos[it], cast(T) tuning_system_count);
	}
	quick_sort(pitch_set, (p1,p2) => p1-p2);
	
	return pitch_set;
}

//TODO can $size be in [$size] int
//TODO write tests for this function
//(6,8,11) -> (-1,6,8) -> (-4,-1,6)
OrderedPitchSetToFundamentalRegion :: (
	input : [size] int, 
	tuning_system_music_pt_count : int, 
	$size : int) 
-> [size] int 
{
	return OrderedPitchSetToFundamentalRegion(input, tuning_system_music_pt_count); 
}

//Leaving this here for now since it works with ints but we don't use it so compiled out for now.
//Someone can generalize it in shared library if needed for ints later since i dont want duplicate logic if we don't need it.
//TODO This is sorted in here so can likely remove
//the word ordered...
OrderedPitchSetToFundamentalRegion :: inline (
	input : [$size] int, 
	tuning_system_music_pt_count : int)
-> [size] int 
{
	poses : [size] int;
	for input_pos, input_index : input {
		poses[input_index] = PosMod(input_pos, tuning_system_music_pt_count);
	}
	quick_sort(poses, (i1, i2) => i1 - i2);
	sum_poses : int = ArraySum(poses);
	while sum_poses >= tuning_system_music_pt_count {
		last_value : int = poses[size-1] - tuning_system_music_pt_count;
		// for < size-1..1 poses[it] = poses[it-1];
		for < 1..size-1 poses[it] = poses[it-1];
		poses[0] = last_value;
		sum_poses = ArraySum(poses);
	}
	//TODO is this unnecessary now that we fixed the ordering bug?
	// quick_sort(poses, (i1, i2) => i1 - i2);
	return poses;
}

OrderedPitchSetToFundamentalRegion :: inline (
	input : [size] $T, 
	tuning_system_music_pt_count : T, 
	$size : int) 
-> [size] T 
{
	return OrderedPitchSetToFundamentalRegion(input, tuning_system_music_pt_count);
}

OrderedPitchSetToFundamentalRegion :: inline (
	input : [$size] $T, 
	tuning_system_music_pt_count : T)
-> [size] T 
{
#assert(T == float || T == float64);
	poses : [size] T;
	for input_pos, input_index : input {
		poses[input_index] = PosMod(input_pos, tuning_system_music_pt_count);
	}
	quick_sort(poses, (i1, i2) => i1 - i2);
	sum_poses : T = ArraySum(poses);
	while sum_poses > tuning_system_music_pt_count ||
		   FloatBothEqual(sum_poses, tuning_system_music_pt_count)
	{
		last_value : T = poses[poses.count-1] - tuning_system_music_pt_count;
		// for < size-1..1 poses[it] = poses[it-1];
		for < 1..size-1 poses[it] = poses[it-1];
   	poses[0] = last_value;
		sum_poses = ArraySum(poses);
	}
	//TODO is this unnecessary now that we fixed the ordering bug?
	// quick_sort(poses, (i1, i2) => i1 - i2);
	return poses;
}

//TODO can we have a reflected conversion instead if we store the
//reflected matrix instead
FunRegionPosToWorldPos :: inline (
	fun_region_pos : [2] float,
    invariant_to_world : Matrix2F, 
    chord_s2 : ChordSpace2)
-> Vector2F 
{
	world_pos : Vector2F = chord_s2.zero_pos;
	world_pos += invariant_to_world * MakeV2F(fun_region_pos);
	return world_pos;
}

FunRegionPosToWorldPos :: inline (
	fun_region_pos : [2] float, 
	chord_s2 : ChordSpace2) 
  	-> Vector2F 
{
	world_pos : Vector2F = chord_s2.zero_pos;
	world_pos += fun_region_pos[0] * chord_s2.invariant_0_unit_length +
		         fun_region_pos[1] * chord_s2.invariant_1_unit_length;
	return world_pos;
}
}

PointRectInLinearSpace :: inline (point : SpacePoint, linear : Space2D) -> Rectangle2 {
	world_pos : Vector2F = linear.dspace_world_pos + point.dspace_pos;
	rect : Rectangle2 = RectCenterDim(world_pos, linear.dspace_point_dim - Vector2F.{0.1,0.1});
	return rect;
}

AsmCreateTuningData :: struct {
	ret_tuning_system_id : int;
	create_tuning_type : CreateTuningType;
	name : AsmString;
	short_name : AsmString;
	compass_interval : float64;
	//Use point_count for eq temp and values for other create types.
	point_count : int;
	//Values depend on the create tuning type above
	values : AsmArray(float64);
} @LibraryAsmGen
CreateTuningType :: enum {
	EQUAL_TEMPERAMENT;
	RATIOS_FROM_START;
	RATIOS_TO_NEXT;
	LINEAR_FROM_START;
	LINEAR_TO_NEXT;
} @LibraryAsmGen
AsmGetTuningSystemData :: struct {
	ret_tuning_system_id : int;
	short_name : AsmString;
} @LibraryAsmGen

NoneEquals :: inline (value : $T, or_checks : [] T) -> bool {
	for or_checks if value == it return false;
	return true;
}

ToByteArray :: (a: *$T, count : int) -> [] u8 {
	bytes : [] u8;
	bytes.data = cast(*u8) a;
	bytes.count = count * size_of(T);
	return bytes;
}
ToByteArray :: (a: [] $T) -> [] u8 {
	return ToByteArray(a.data, a.count);
}
/*Circle Buffer operations
*/
//TODO We could keep write and read bytes in here or just externally anyways.
//Could have this for convenience and keep the generalized functions and then just
//have some extra functions
CircleBuffer :: struct($T : Type) {
	buffer : [] T;
	write_cursor : int;
	read_cursor : int;
}
WriteToCircleBuffer :: (write_buffer : [] $T, circle : [] T, write_cursor : *int) {
	write_b : [] u8;
	write_b.data = cast(*u8) write_buffer.data;
	write_b.count = write_buffer.count * size_of(T);
	circle_b : [] u8;
	circle_b.data = cast(*u8) circle.data;
	circle_b.count = circle.count * size_of(T);
	write_cursor_in_bytes : int = write_cursor.* * size_of(T);
	WriteBytesToCircleBuffer(write_b, circle_b, *write_cursor_in_bytes);
	write_cursor.* = write_cursor_in_bytes / size_of(T);
	print("write_cursor=%\n", write_cursor.*);
}
//TODO FROM HERE unit test these functions and then update the os layer here and cleanup code and split up windows and mac.
//Can likely cleanup the audio to float32 later once we know that i works on windows and mac.
//TODO Likely put these in thegame_data
WriteBytesToCircleBuffer :: (write_buffer : [] u8, circle : [] u8, write_cursor_in_bytes : *int) {
	//TODO Technically we could error this out so this would overwrite the circular buffer.
	if write_cursor_in_bytes.* > circle.count log("Writing over 1 entire cycle in circle buffer.\n");

	current_write_byte : int = write_cursor_in_bytes.*;
	bytes_to_write : int = write_buffer.count;
	write_data : *u8 = write_buffer.data;
	while bytes_to_write > 0 {
		circle_data : *u8 = circle.data + current_write_byte;
		if current_write_byte + bytes_to_write >= circle.count {
			bytes_to_copy := circle.count - current_write_byte;
			memcpy(circle_data, write_data, bytes_to_copy);
			write_data += bytes_to_copy;
			bytes_to_write -= bytes_to_copy;
			current_write_byte = 0;
		} else {
			memcpy(circle_data, write_data, bytes_to_write);
			write_data += bytes_to_write;
			current_write_byte += bytes_to_write;
			bytes_to_write = 0;
		}
	}
	write_cursor_in_bytes.* = current_write_byte;

	assert(bytes_to_write == 0);
	assert(current_write_byte < circle.count);
	assert((write_data - write_buffer.data) == write_buffer.count);
}
ReadFromCircleBuffer :: (output_buffer : [] $T, circle : [] T, read_cursor : *int) {
	output_b : [] u8;
	output_b.data = cast(*u8) write_buffer.data;
	output_b.count = write_buffer.count * size_of(T);
	circle_b : [] u8;
	circle_b.data = cast(*u8) circle.data;
	circle_b.count = circle.count * size_of(T);
	read_cursor_in_bytes : int = read_cursor.* * size_of(T);
	ReadBytesFromCircleBuffer(output_b, circle_b, *read_cursor_in_bytes);
	read_cursor.* = read_cursor_in_bytes / size_of(T);
}
ReadBytesFromCircleBuffer :: (output_buffer : [] u8, circle : [] u8, read_cursor_in_bytes : *int) {
	if read_cursor_in_bytes.* > circle.count log("Reading over 1 entire cycle in circle buffer.\n");

	current_read_byte : int = read_cursor_in_bytes.*;
	bytes_to_read := output_buffer.count;
	output_data := output_buffer.data;
	while bytes_to_read > 0 {
		ring_bytes : *u8 = circle.data + current_read_byte;
		if current_read_byte + bytes_to_read >= circle.count {
			bytes_to_copy := circle.count - current_read_byte;
			memcpy(output_data, ring_bytes, bytes_to_copy);
			output_data += bytes_to_copy;
			bytes_to_read -= bytes_to_copy;
			current_read_byte = 0;
		} else {
			memcpy(output_data, ring_bytes, bytes_to_read);
			output_data += bytes_to_read;
			current_read_byte += bytes_to_read;
			bytes_to_read = 0;
		}
	}
	read_cursor_in_bytes.* = current_read_byte;

	assert(bytes_to_read == 0);
	assert(current_read_byte < circle.count);
	assert((output_data - output_buffer.data) == output_buffer.count);
}	

//TODO do dspace_dim and rel_pos have to be integer
SpacePointHeader2DToIndex :: (pos : Vector2F, space : DimensionalSpace) -> int {
	index : int = round_to_int(pos.x + pos.y * space.dspace_dim.x);
	return index;
}

SpacePointHeader2DToIndex :: (pos : Vector2I, space : DimensionalSpace) -> int {
	index : int = round_to_int(pos.x + pos.y * space.dspace_dim.x);
	return index;
}

TuningTransposition :: inline (
	music_pt_pos : int,
	transpose_size : int,
	$is_inverse : bool)
-> int 
{
	transpose_result : int = ---;
	#if is_inverse transpose_result = music_pt_pos - transpose_size;
	else transpose_result = music_pt_pos + transpose_size;
	return transpose_result;
}

/* Interscalar Interval Matrix
	TODO could have this in float as well if needed
*/
ScaleIntervalMatrix :: struct {
	matrix : [][] int;
	a_chord : [] int;
	b_chord : [] int;
}

MakeInterscalarIntervalMatrix :: (
	a_chord : [] int, 
	b_chord : [] int, 
	tuning_system_music_pt_count : int) 
-> ScaleIntervalMatrix 
{
	assert(a_chord.count == b_chord.count);

	si_matrix : ScaleIntervalMatrix;
	si_matrix.matrix = NewArray(a_chord.count, [] int);
	for 0..a_chord.count-1 {
		si_matrix.matrix[it] = NewArray(b_chord.count, int);
	}
	si_matrix.a_chord = a_chord;
	si_matrix.b_chord = b_chord;

	b_temp : [] int = array_copy(b_chord);
	defer free(b_temp.data);
	for 0..a_chord.count-1 {
		si_matrix.matrix[it] = ArraySubtract(b_temp,a_chord);
		// for * si_matrix.matrix[it] {
		// 	<<it = PosMod(<<it, 12.0);
		// }

		first_temp : int = b_temp[0];
		for 0..b_temp.count-2 {
			b_temp[it] = b_temp[it + 1];
		}
		b_temp[b_temp.count-1] = first_temp + tuning_system_music_pt_count;
	}
	return si_matrix;
}

ShiftScale :: (original_scale : [] int, start_degree : int, tuning_shift : int, tuning_system_music_pt_count : int) -> [] int {
	shifted_scale : [] int = NewArray(original_scale.count, int);
	shifted_index : int = 0;
	for original_index : start_degree..original_scale.count-1 {
		shifted_scale[shifted_index] = original_scale[original_index];
		shifted_index += 1;
	}

	for original_index : 0..start_degree-1 {
		shifted_scale[shifted_index] = original_scale[original_index] + tuning_system_music_pt_count;
		shifted_index += 1;		
	}

	shifted_start_degree : int = shifted_scale[0];
	for * shifted_scale {
		<< it -= shifted_start_degree;
		<< it += tuning_shift;
	}

	return shifted_scale;
}
TestInterscalarIntervalMatrix :: () {
    ts_count : int = 12;
    diatonic_scale_int_array :: int.[0,2,4,5,7,9,11];
    acoustic_scale_int_array :: int.[0,2,4,6,7,9,10];
    // scale_interval_matrix := MakeInterscalarIntervalMatrix(int.[0,3,6,10], int.[0,4,7,10]);
    // scale_interval_matrix := MakeInterscalarIntervalMatrix(int.[0,2,4,5,7,9,11], int.[0,2,4,6,7,9,10], 12);
    // scale_interval_matrix := MakeInterscalarIntervalMatrix(int.[0,2,4,5,7,9,11], int.[-10,-8,-6,-5,-3,-2,0], 12);
    // scale_interval_matrix := MakeInterscalarIntervalMatrix(int.[0,2,4,5,7,9,11], 
    // 	ShiftScale(acoustic_scale_int_array, 1, -10, ts_count), ts_count);
    // scale_interval_matrix := MakeInterscalarIntervalMatrix(int.[0,2,4,5,7,9,11], int.[2,4,6,7,9,10,12], 12);
    scale_interval_matrix := MakeInterscalarIntervalMatrix(int.[0,2,4,5,7,9,11], 
    	ShiftScale(acoustic_scale_int_array, 1, 0, ts_count), ts_count);
	print("si_matrix is %\n", scale_interval_matrix);
}

/*End of Interscalar Interval Matrix
*/

/**
	Data Models
**/

/*
Generic data model for a table that is indexed (and sorted) by id
where each new id is an incremental value
GetById -> O(1)
GetPointerById -> O(1)
UpdateValueById -> O(1)
InsertNextValue -> O(1)
DeleteById -> O(1)

Limitations : looping requires if statement to check for DEFAULT_UNINITIALIZED_ID
MusicPts : if looping is not needed, can also replace this with a hash table
*/

//TODO can do a version with a fixed compile-time size and counter
TableIndexById :: struct(type : $T) {
	table_id : int;
	table : [..] T;
	next_value_id : int;
	free_list : [..] int;
	//TODO other tables that hook into this one and react to operations done to this table
	// hooked_table_ids : [..] int;
}

//TODO this needs a free list to work properly
DEFAULT_UNINITIALIZED_ID : int : -666666;
DeleteById :: inline (table : *[..] $T, id : int) -> bool {
	if id >= table.count return false;
	table[id].id = DEFAULT_UNINITIALIZED_ID;
	return true;
}

InsertNextValue :: inline (table : *[..] $T, value : *T, next_id : *int) {
	value.id = <<next_id;
	<<next_id += 1; //TODO make update more hash-like / specific?
	array_add(table, value);
}

UpdateValueById :: inline (table : [..] $T, id : int, value : T) -> bool {
	if id >= table.count return false;
	table[id] = value;
	return true;
}

GetPointerById :: inline (table : [..] $T, id : int) -> *T, bool {
	if id >= table.count return null, false;
	value : *T = *table[id];
	return value, true;	
}

GetById :: inline (table : [] $T, id : int) -> T, bool {
	if id >= table.count return T.{}, false;
	value : T = table[id];
	return value, true;	
}

/*
Generic data model for a table that is sorted by id
where each new id is an incremental value
GetById -> O(log n)
GetPointerById -> O(log n)
UpdateValueById -> O(log n)
InsertNextValue -> O(1)
DeleteById -> O(n)

Advantage : array is in tact with no uninitialized values during looping
*/

TableSortedById :: struct(type : $T) {
	table : [..] T;
	next_id : int;
}

DeleteById :: inline (table : *TableSortedById, id : int) -> bool {
	if id >= table.count return false;
	removed : bool = false;
	for * table if <<it.id == id {
		remove it;
		removed = true;
		break;
	}
	return removed;
}

InsertNextValue :: inline (table : TableSortedById, value : *table.type, next_id : *int) {
	value.id = <<next_id;
	<<next_id += 1; //TODO make update more hash-like / specific?
	array_add(table, value);
}

UpdateValueById :: inline (table : TableSortedById, id : int, value : table.type) -> bool {
	if id >= table.count return false;
	table[id] = value;
	return true;
}

//TODO this needs to use binary search
GetPointerById :: inline (table : TableSortedById, id : int) -> *table.type, bool {
	if id >= table.count return null, false;
	value : *T = *table[id];
	return value, true;	
}

//TODO this needs to use binary search
GetById :: inline (table : TableSortedById, id : int) -> table.type, bool {
	if id >= table.count return T.{}, false;
	value : T = table[id];
	return value, true;	
}

//TODO implement hash table with size (and free list and linked list or linear probing)
//TODO implement BTree

/**
	End of Data Models
**/

/**
	DynamicMemory
**/
DynamicMemory :: struct($data_type : Type) {
	using memory : MemoryData;
	//TODO need to attach this to our permanent allocator
	size_stack : [..] int;
}

PushStruct :: inline (data : *DynamicMemory, $type : Type) -> *type {
	//TODO could initialize this externally
	if data.size_stack.count == 0 {
		array_add(*data.size_stack, 0);
	}
	previous_size : int = data.size_stack[data.size_stack.count - 1];
	array_add(*data.size_stack, previous_size + size_of(type));
	return PushStruct(*data.memory, type);	
}

for_expansion :: (memory : *DynamicMemory($dyn_type), body : Code, flags : For_Flags) #expand {
	#assert(flags != For_Flags.REVERSE);
    index : int = 0;
    while index < memory.size_stack.count {
    	defer index += 1;
    	byte_offset : int = memory.size_stack[index];
    	grid_header := cast(*dyn_type) ((cast(*u8)memory.base) + byte_offset);
		`it_index := index;
    	`it := grid_header;
    	if flags != For_Flags.POINTER {
    		copy_header := <<grid_header;
    		it = *copy_header;
    	}
		#insert body;
    }
}

operator [] :: (memory : DynamicMemory($dyn_type), index : int) -> *dyn_type {
	assert(index <= memory.size_stack.count);
	byte_offset : int = memory.size_stack[index];
	grid_header := cast(*dyn_type) ((cast(*u8)memory.base) + byte_offset);
	return grid_header;
}


/*
	Input processing code
	should this have its own file?
*/

MoveCamWASD :: inline (
	keyboard : ControllerInput,
	pixels_per_square : float) 
-> Vector2F
{
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
    	move_this_frame *= 2.0*(1.0 / pixels_per_square);
    	// move_this_frame *= 1.0*(1.0 / pixels_per_square);
 	} else {
    	move_this_frame *= 2.0*(1.5 / pixels_per_square);
    	// move_this_frame *= 1.0*(1.5 / pixels_per_square);
    }
    return move_this_frame;
}

/*
	End of Input processing
*/

/*
	Mouse Collision System

	TODO other collision shapes (eg circles)

	***TODO we can do all collisions by checking if we collided
	with a rect and then go grab the collided entity based
	on the corresponding id and some entity type***

	We are technically using these to group collision data but that can be done with the collision_id
	straight I think... so maybe we don't need this data at all.
	We can remove it if collision work and we never use since the collision_id is enough to group things.
*/
//TODO where should we put the collision detection? separate file?
//TODO is separate CollisionData struct necessary?
//or is duck typing with collision_id enough
//maybe if we have multiple collision types
CollisionData :: struct {
	id : int;
	// collision_type : CollisionType;
}

CollisionType :: enum {
	//TODO Not sure we need this type since we store collision_id in active_op_space for covenience
	OP_SPACE;
	//TODO Need to differentiate between linear and background linear spaces.
	//Could put an is_background flag for now to make it robust.
	LINEAR_SPACE;
	CIRCLE_SPACE;
	CHORD_S2;
}

MakeCollisionData :: inline () -> CollisionData {
	collision_data : CollisionData;
	collision_data.id = context.ALL_NEXT_IDS.NEXT_COLLISION_ID;
	defer context.ALL_NEXT_IDS.NEXT_COLLISION_ID += 1;
	return collision_data;
}

CollisionRect :: struct {
	collision_id : int;
	world_rect : Rectangle2;
}

Collidable :: struct {
	collision_id : int;
}

//TODO should this take a Collidable or just a collision_id?
IsCollidingCamSpace :: inline (
	cam_pos : Vector2F,
	collidable : $T/interface Collidable,
	cam : Camera2D,
	all_collision_rects : [] CollisionRect)
-> bool
{
	collision_rects : [] CollisionRect = 
		ArrayFindAllVarName(all_collision_rects, collidable.collision_id, "collision_id", temp);
	for collision_rect : collision_rects {
		cam_rect : Rectangle2 = WorldRectToCamRect(collision_rect.world_rect, cam);
		if IsInRectangle(cam_pos, cam_rect) {
			return true;	
		}
	}
	return false;
}

IsCollidingWorldSpace :: inline (
	world_pos : Vector2F,
	collidable : $T/interface Collidable,
	all_collision_rects : [] CollisionRect)
-> bool
{
	collision_rects : [] CollisionRect = 
		ArrayFindAllVarName(all_collision_rects, collidable.collision_id, "collision_id", temp);
	for collision_rect : collision_rects {
		if IsInRectangle(world_pos, collision_rect.world_rect) {
			return true;	
		}
	}
	return false;
}

CreateColliderAndRect :: inline (
	world_pos : Vector2F, world_size : Vector2F,
	collision_type : CollisionType,
	all_collision_data : *[..] CollisionData,
	all_collision_rects : *[..] CollisionRect)
-> CollisionData
{
	collision_data : CollisionData = MakeCollisionData();
	array_add(all_collision_data, collision_data);

	collision_rect : CollisionRect;
	collision_rect.collision_id = collision_data.id;
	collision_rect.world_rect = RectCenterDim(world_pos, world_size);
	array_add(all_collision_rects, collision_rect);

	return collision_data;
}

CreateColliderAndManyRects :: inline (
	create_world_poses : [] Vector2F,
	create_world_sizes : [] Vector2F,
	all_collision_data : *[..] CollisionData,
	all_collision_rects : *[..] CollisionRect)
-> CollisionData
{
	assert(create_world_poses.count == create_world_sizes.count);

	collision_data : CollisionData = MakeCollisionData();
	array_add(all_collision_data, collision_data);

	for 0..create_world_poses.count-1 
	{
		world_pos  : Vector2F = create_world_poses[it];
		world_size : Vector2F = create_world_sizes[it];

		collision_rect : CollisionRect;
		collision_rect.collision_id = collision_data.id;
		collision_rect.world_rect = RectCenterDim(world_pos, world_size);
		array_add(all_collision_rects, collision_rect);
	}

	return collision_data;
}

RemoveColliderAndRects :: inline (
	collision_id : int,
	all_collision_data : *[..] CollisionData,
	all_collision_rects : *[..] CollisionRect)
{
	ArrayRemoveAllByNameId(all_collision_rects, collision_id, "collision_id");
	ArrayRemoveFirstByNameId(all_collision_data, collision_id, "id");
}
/*
	End of Mouse Collision System
*/