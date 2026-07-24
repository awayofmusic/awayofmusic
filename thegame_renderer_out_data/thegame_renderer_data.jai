/*
	TODO Need to move out fonts so only the Renderer is dependent on Simp. Then can
	only have access to RenderGroups directly by pointer or index which would be the
	relationship between the game and the renderer, essentially only the render_push_buffer
	and the Push functions onto it. This way we could to dynamic code reloading for both
	the renderer and for the game itself separately.
	Not doing it for now since the renderer is not finalized so may as well keep them together
	in case we want to try weird things later.

	TODO IF WE WANT THE FILE TO BE MORE MODULAR, would need to remove all dependencies from
	"thegame_math.jai" and instead only use things from Math/module.jai
	and also change MemoryData or generalize MemoryData and move in thegame_platform_data.jai
	but then i am unsure about how the polymorphism would work in that case. could also
	use a simple jai allocator and try that out for the renderer and then we would use that
	allocator everytime we push things

	why would we need to pull out thegame_math.jai? why not just include that
	as a module as part of the renderer with Math/module?

	TODO this needs to be somehow shared between thegame_renderer and thegame_render_group
	so that there is a common interface between both
	therefore this would require this class to be game agnostic, in other words,
	remove anything from thegame_math
*/
RenderBasis :: struct {
	p : Vector2F;
}
OpSpaceRenderGroups :: struct {
	op_space_id : int;
	//TODO Could call this pre_scissor_group but for now we are
	//only using it for 3D spaces so I will make it explicit.
	//If we need things behind it, then we can add a pre_scissor_group as well.
	/*We only need to generate this for 3D groups but are generating it
	all the time for now. This may be a good argument for keeping
	op_spaces in an array and then only cycling the render_groups
	instead of cycling the entire OperationSpace.
	WE ONLY NEED THESE FOR 3D op_spaces so that can be an optimization.
	TODO CAN MAKE THIS AN ARRAY_VIEW INTO ALL_RENDER_GROUPS so we can
	have variable size for 2D and 3D and then move them around as needed

	TODO We need to remove op_space_id and just have an array here separate
	for 2d and 3d render_groups and just load them up from a free list of render_groups
	whenever we open an op_space and then put them on a free list whenever we close an op_space.
	*/
	//TODO We don't need this in 2D since we have order in scissor_group anyways
	pre_scissor_group : *RenderGroup;
	scissor_group_3D : *RenderGroup;
	//TODO should we use ids as indices for now?
	//until we do proper memory allocation for rendering
	//TODO do we need a pre_render_group?
	scissor_group : *RenderGroup;
	//Note : post_render_group is for non-scissored entities
	post_render_group : *RenderGroup;
	// render_group_id : int;	
}
/*TODO 
	RenderGroup should have an order itself so we can order
	windows above and below each other
*/
//TODO add separate render_group for text so we don't call set_shader every triangle
//TODO should we have separate 2d and 3d render groups?
//TODO could put extra data pointer in here if group
//is 3D for example and have a type
RenderGroup :: struct {
	id : int;
	//TODO could store the center_world_pos here if needed
	//and remove render_bases
    default_basis : RenderBasis; //TODO should this just be half_monitor_squares / vice-versa?
    //TODO should this be in meters or grid squares?
    //TODO MAYBE WE SHOULD JUST HAVE 1 pixels_per_square since now we update all of them to be the same
    //and just keep it in tne renderer data as 1
    pixels_per_square : float;
    focal_squares : float; //z plane at which 1 grid unit looks like 1 grid unit in 2D on the viewing plane
    //TODO Not sure we should be using this instead of screen_half_idm * pixels_per_square...
    half_monitor_squares : Vector2F;
    //TODO This allows us to continue using half_monitor_square for convenience
    zoom_factor : float = 1.0;

    //TODO there is a Plane3 in Plane.jai
    // frustum_planes : [5] Plane3F; //in squares

    //TODO should we put these in RendererData?
    //what if we have multiple windows?
    screen_half_dim : Vector2F;
    window_width : s32;
    window_height : s32;
    //TODO should we have a version with only s32 for consistency
    render_viewport : Rectangle2;

    render_count : int;
    /* This is currently only sorting the pointers and so the MemoryData order is not actually touched.
    This is currently slow as we are fetching the Rendering data afterwards
    and these can be all over the place in memory. It would be better to have
    an array for each RenderType and then simply get them by pointer in order 
    where we check each one on each loop. 

    ***Or to have 1 larger rendering object with unions in it
    and then everything is just that object since most things will be triangles and text.
    Then we would have to convert rectangles to triangles, so need to check what is more efficient
    ***

    */
    //TODO should we replace these with dynamic arrays for now?
    //TODO should rename these and add to both push_buffer and the push_buffer_headers
    //TODO add SimpleAlloc or FlatPool to this array
    render_sort_buffer : [..] *RenderHeader;
    //TODO replace with SimpleAlloc or FlatPool array
    //WE MIGHT JUST USE 1 ARRAY with same size object for everything
    //and that could have its on FlatPool allocator
    render_push_buffer : MemoryData;

    /*TODO Ultimately, this should also have a different data type
    store in render_push_buffer because we use the depth buffer
    for sorting 3D triangles so we don't need to sort and therefore
    we can pass the vertex array directly to opengl. We would have
    to make the data vertex-color ordered but then we would not need
    the extra copy. With 2D we sort using order so we cannot do that.
    HOWEVER, if we use the depth test for 2D as well, then we just store
    the order as z and let opengl handle the order and then we don't have
    to copy that either. Not sure which is more efficient but definitely
    for 3D we just use the array directly. 2D may be a copy or not.
    Also to consider debugging which would be harder with a vertex array.
    So can likely wait until later and then also see for metal rendering
    */
    is_3D_render_group : bool;

    //TODO storing in here for now, can have have multiple and store in RenderEntry as well,
    //especially if we want to have multiple fonts
    //TODO This can be removed if we only allow one font
    //although maybe if we want other fonts for other things
    //then it would be useful again.
    font_index : int;
    // my_font : *Dynamic_Font;
}

//TODO should we move this to thegame_renderer_data?
NEXT_RENDER_GROUP_ID : int = 0;
CreateRenderGroup :: inline (
	push_buffer_size_in_bytes : s64,
	render_viewport : Rectangle2,
	renderer_data : *RendererData,
	//TODO This might eventually be separate type of RenderGroup since the push_buffer should be different
	is_3D_render_group : bool)
-> *RenderGroup
{
	// assert(renderer_data.all_render_groups.count > 0);

	render_group : *RenderGroup = PushStruct(*renderer_data.memory, RenderGroup);
	render_group.id = NEXT_RENDER_GROUP_ID;
	NEXT_RENDER_GROUP_ID += 1;

	//TODO render_sort_buffer should be set to the same allocator HOWEVER 
	//we will likely use 1 array so then we don't need the render_sort_buffer since it will sorted directly in the 1 array
	render_group.render_push_buffer.size = push_buffer_size_in_bytes;
	render_group.render_push_buffer.base = PushSize(*renderer_data.memory, render_group.render_push_buffer.size);

	//TODO this can likely be pulled out and done in the renderer
	render_group.default_basis.p = Vector2F.{};

	render_group.render_viewport = render_viewport;

	render_group.window_width = renderer_data.base_render_group.window_width;
	render_group.window_height = renderer_data.base_render_group.window_height;

	render_group.screen_half_dim = ComputeScreenHalfDim(
		render_group.window_width,
		render_group.window_height);

	/*TODO could update these in thegame if needed since we have a pointer to RenderGroup
	*/
	render_group.zoom_factor = 1.0;
	render_group.pixels_per_square = renderer_data.base_render_group.pixels_per_square;
	render_group.focal_squares = 24.0; //1 xy unit in 2D plane at this z square value from camera
	//TODO this should be adjusted in renderer to be resolution independent
	//TODO could adjust this relative to camera movement adjustment
	#if 0 {
	//TODO do we want half_monitor_squares for the screen or the viewport?
	width_squares : float = (render_viewport.max.x-render_viewport.min.x-1) / render_group.pixels_per_square;
	height_squares : float = (render_viewport.max.y-render_viewport.min.y-1) / render_group.pixels_per_square;
	render_group.half_monitor_squares = MakeV2F(width_squares * 0.5, height_squares * 0.5);
	}
	else #if 0 {
	//TODO Should store the (width-1, height-1) in here as well to avoid issues
	width_squares : float = (render_group.window_width-1) / render_group.pixels_per_square;
	height_squares : float = (render_group.window_height-1) / render_group.pixels_per_square;
	//TODO WE SHOULD REMOVE THIS SO WE CAN SIZE BASED ON PIXELS_PER_SQUARE
	render_group.half_monitor_squares = MakeV2F(width_squares * 0.5, height_squares * 0.5);
	}
	else {
	UpdateHalfMonitorSquares(render_group);
	}
	//TODO should this be put in each render text entry for different fonts?
	//TODO could pass get_font_at_size into game if needed
	//when we completely separate out the renderer
	//TODO could search for font by name instead
	render_group.font_index = 1;

	render_group.is_3D_render_group = is_3D_render_group;

	return render_group;
}

//TODO I am not sure we even want this, might be better to just do the division everywhere...
UpdateHalfMonitorSquares :: inline (render_group : *RenderGroup) {
   //TODO Should store the (width-1, height-1) in here as well to avoid issues
   width_squares : float = (render_group.window_width-1) / render_group.pixels_per_square;
   height_squares : float = (render_group.window_height-1) / render_group.pixels_per_square;
   //TODO WE SHOULD REMOVE THIS SO WE CAN SIZE BASED ON PIXELS_PER_SQUARE
   render_group.half_monitor_squares = MakeV2F(width_squares * 0.5, height_squares * 0.5);
}

//TODO should this just be in the RenderGroup? or RendererData?
ComputeScreenHalfDim :: inline (
	window_width : s32,
	window_height : s32) 
-> Vector2F
{
	screen_half_dim := MakeV2F(0.5 * (window_width-1), 0.5 * (window_height-1));
	return screen_half_dim;
}


/*TODO could change memory to be a simple jai allocator
	and then would not need MemoryData as that would be
	genericized in the simple jai allocator or Flat_Pool
	maybe Simple_Alloc is better since it can grow in case we 
	have an overflow of rendergroups or something
*/
/*Eventually we can pull out the RenderGroups
part of this struct since the game only needs the
RenderGroup and then the rest of this data can be
only for the renderer since the renderer_data is
initialized by the OS.
*/
RendererData :: struct {
	//TODO can replace MemoryData with SimpleAlloc or FlatPool
	//and then use directly on all_render_groups
	memory : MemoryData;
	is_initialized : bool;

	default_pixels_per_square : float;

	//Note : This keeps track of memory used for base_render_group, overlay_render_group and terminal_render_group
	initial_memory_used_size : int;

	// original_width : int;
	// resolution_scale_factor : float;

	//TODO need to update render headers array as well
	//TODO could replace allocator with SimpleAlloc or FlatPool
	//TODO can remove MemoryData if we use an allocator
	//directly for the array
	base_render_group : *RenderGroup;
	/*TODO For now I am putting the rows in base_render_group at order index values < 0.
	  IF we only use base for rows and some row overlay rendering, then this makes the most sense.
	  The only limitation is that we can only have 2^62 rows then (actually 2^62 because we have 10 render order indices per row)
	  Also it might be harder to code with but should be fine since the base_render_group works as normal now with everything > 0. 
	  IF we need more later then I can add these groups. Right now everything in base_render_group is more convenient and efficient.
	  OR If it is clearer and more consistent overall to have row_group, we can do that too.
	  WARNING : If there are weird issues with PushClear ordering not rendering things in base_render_group we can also switch to row_group if that helps.
	*/
	// row_group : *RenderGroup;
	// post_row_group : *RenderGroup;
	//Note : terminal needs its own RenderGroup so that it is not affected by level loads
	terminal_render_group : *RenderGroup;
	overlay_render_group : *RenderGroup;
	//TODO should also have a top_render_group
	//TODO FROM HERE grab render groups as needed
	//so have an inactive and active render group for op_space
	//(same lazy creation for op_space)
	/*DOC : all_render_groups stores all created render groups which we do not delete
	and keep in there for future use. We reuse the unused render_groups which are
	easily reference from free_op_space_render_groups.
	So whenever we create an op_space, we check if we have any free render groups
	in free_op_space_render_groups and if we don't, then we create it new ones in all_render_groups.
	All currently used render groups are found in open_op_space_render_groups.
	all_render_groups can be refereneced by pointer since all render groups are pointers.
	This design allows for easy updating of all render groups when needed in all_render_groups
	eg for resizing the window or for doing a global zoom AND
	we can also easily reference and reorder the current open op spaces
	without having to adjust sets of render groups together.

	FUTURE CONSIDERATIONS : If we split up 2d and 3d render groups eventually
	this should simplify things since only 1 of the op space render groups is 3d
	and also then we can create 2 sets arrays, 1 explicitly for 3d and 1 for 2d.
	So the 2d render_groups would only have 3 render groups and each render group could
	have a different size. Consider this if/when we try to optimize the renderer for 2d and 3d.
	*/
	all_render_groups : [..] *RenderGroup;
	open_op_space_render_groups : [..] OpSpaceRenderGroups;
	free_op_space_render_groups : [..] OpSpaceRenderGroups;

	// render_group_count : int;
	// max_render_group_count : int;
	all_my_fonts_data : [..] FontData;
	//TODO This can be moved into thegame_renderer
	//and then nothing needs to depend on Simp except
	//for the renderer.
	//We are only leaving in here for now for convenience
	//but if we remove then we can remove the dependency
	//on Simp from everywhere except the renderer
	//and so then we can fully pull out the renderer
	//if needed for things like dynamic recompilation.
	//TODO I THINK WE CAN MOVE THIS OUT OF HERE and then it would not depend on Simp so we can pass the renderer data
	//to the shared library
	all_my_fonts : [..] *Dynamic_Font;
}

FontData :: struct {
	char_width : int;
	char_height : int;
}

MakeFontData :: inline (
	char_height : int,
	char_width : int = -1) //-1 in case we don't have a constant width
-> FontData
{
	font_data : FontData = ---;
	font_data.char_height = char_height;
	font_data.char_width = char_width;
	return font_data;
}

ResetAllRendererData :: inline (rd : *RendererData) {
	//It seems we don't need to reset any of the all_render_groups because they all 
	//grab from rd.memory which is reset below to initial_memory_used_size.
	//This will therefore write over that data
	array_reset_keeping_memory(*rd.all_render_groups);
	array_reset_keeping_memory(*rd.open_op_space_render_groups);
	array_reset_keeping_memory(*rd.free_op_space_render_groups);

	rd.memory.used = rd.initial_memory_used_size;
	ResetRenderGroup(rd.base_render_group);
	// ResetRenderGroup(rd.row_group);
	// ResetRenderGroup(rd.post_row_group);
	ResetRenderGroup(rd.overlay_render_group);
}

ResetAllRenderGroups :: inline (renderer_data : *RendererData) {
	ResetRenderGroup(renderer_data.base_render_group);
	// ResetRenderGroup(renderer_data.row_group);
	// ResetRenderGroup(renderer_data.post_row_group);
	for renderer_data.all_render_groups ResetRenderGroup(it);
	ResetRenderGroup(renderer_data.terminal_render_group);
	ResetRenderGroup(renderer_data.overlay_render_group);
}

ResetRenderGroup :: inline (render_group : *RenderGroup) {
	render_group.render_push_buffer.used = 0;
	render_group.render_count = 0;
	array_reset_keeping_memory(*render_group.render_sort_buffer);
}

UpdateAllRendererData :: inline () {
	
}

//TODO remove this from thegame_render_group
//and then remove altogether
#if 1 {
RenderBuffer :: struct {
    //TODO could also store the entire Bitmap header in here if needed
    height : s32;
    width : s32;
    pitch : s32;
    memory : *void;
    bitmap : *u32;
    bytes_per_pixel : s32 = 4;

    depth_buffer : [] float;
};
}


#if 0 {
/*TODO should we collapse all data in here, array of vectors and string = null?

	***TODO
		split out order and type so we can sort much faster
		and only store the necessary data and then 
		fetch extra data as need. maybe even SoA
	***
	
	collapsing all data would make coding / processing easier but would make 
	every object hold everything (or store arrays far away) and be heavier
	would have >= 3 Vector3F + string == 64 * 3 bits = 192 bits
	however this would be better if we only/mainly used bitmaps
	and removed other things or somethig like that

	so this is lighter since all data is variable and consecutive
	and we only had 64 bit address per render entry
*/
//TODO make Vectors in here be from Math/module
//TODO and also only have type and int in here for faster sorting
RenderHeader :: struct {
	basis : *RenderBasis;
	offset : Vector2F; //TODO could set this to be viewport half_dim
	color : Vector4F;
	type : Type;
	order : int;
	//TODO should we also store type as separate enum?
}
/*TODO could do date : *void and then case(*RType)
	by type in an if/switch statement if we want
	to separate it out and are worried about
	polymorphic types between a program and a dll

	OR just have a RenderEntryType enum
	and then cast directly in the renderer
*/
RenderEntry :: struct($data_type : Type) {
	using header : RenderHeader;
	data : data_type;
}

RImmediateFlush :: struct {
}

RSetShaderText :: struct {
}

RSetShaderColor :: struct {
}

RClear :: struct {
}

RText :: struct {
	text : string;
}

RLine :: struct {
	end : Vector2F;
}

RSetScissor :: struct {
	x0, y0, x1, y1 : float;
}

RClearScissor :: struct {
}

//TODO do a version where rectangle gets stored as 2 triangles for rendering
RRectangle :: struct {
	rect : Rectangle2;
}

RTriangle :: struct {
	triangle : Triangle3F;
	shade : Vector3F;
}
}
else {
RenderHeader :: struct {
	//TODO Should put color only in the entries that need it
	// color : Vector4F;
	order : int;
	render_type : RenderType;
	//TODO should we also store type as separate enum?
}

RenderType :: enum u8 {
	IMMEDIATE_FLUSH;
	SET_SHADER_TEXT;
	SET_SHADER_COLOR;
	CLEAR;
	TEXT;
	LINE;
	SET_SCISSOR;
	CLEAR_SCISSOR;
	RECTANGLE;
	TRIANGLE;
}

#if 1 {
SizeOfRenderType :: ($t : RenderType) -> s64 #expand {
	//TODO Try these with compile time constants
	#if 	 t == .IMMEDIATE_FLUSH  return size_of(RImmediateFlush);
	else #if t == .SET_SHADER_TEXT  return size_of(RSetShaderText);
	else #if t == .SET_SHADER_COLOR return size_of(RSetShaderColor);
	else #if t == .CLEAR            return size_of(RClear);
	else #if t == .TEXT             return size_of(RText);
	else #if t == .LINE             return size_of(RLine);
	else #if t == .SET_SCISSOR      return size_of(RSetScissor);
	else #if t == .CLEAR_SCISSOR    return size_of(RClearScissor);
	else #if t == .RECTANGLE        return size_of(RRectangle);
	else #if t == .TRIANGLE         return size_of(RTriangle);
	else return -1;
	//TODO Could make this a case statemnt if #must
}
}
else {
SizeOfRenderType :: inline (t : Type) -> s64 {
	//TODO Try these with compile time constants
	if 	 	t == RImmediateFlush  return size_of(RImmediateFlush);
	else if t == RSetShaderText  return size_of(RSetShaderText);
	else if t == RSetShaderColor return size_of(RSetShaderColor);
	else if t == RClear            return size_of(RClear);
	else if t == RText             return size_of(RText);
	else if t == RLine             return size_of(RLine);
	else if t == RSetScissor      return size_of(RSetScissor);
	else if t == RClearScissor    return size_of(RClearScissor);
	else if t == RRectangle        return size_of(RRectangle);
	else if t == RTriangle         return size_of(RTriangle);
	else return -1;
	//TODO Could make this a case statemnt if #must
}
}

RImmediateFlush :: struct {
	using header : RenderHeader;
}

RSetShaderText :: struct {
	using header : RenderHeader;
}

RSetShaderColor :: struct {
	using header : RenderHeader;
}

RClear :: struct {
	using header : RenderHeader;
	color : Vector4F;
}

RText :: struct {
	using header : RenderHeader;
	text : string;
	offset : Vector2F;
	color : Vector4F = Vector4F.{1,1,1,1};
	//TODO We could set a font_index in here if we wanted to have multiple sizes or different fonts for example.
}

RLine :: struct {
	using header : RenderHeader;
	end : Vector2F;
	offset : Vector2F;
	color : Vector4F;
}

RSetScissor :: struct {
	using header : RenderHeader;
	x0, y0, x1, y1 : float;
}

RClearScissor :: struct {
	using header : RenderHeader;
}

//TODO do a version where rectangle gets stored as 2 triangles for rendering
//the advantage there would be that we would only ever render triangles so we 
//would store everything as a triangle except for text.
//although this version is more efficient as we only need 2 Vector2Fs to store 1 rectangle
RRectangle :: struct {
	using header : RenderHeader;
	rect : Rectangle2;
	color : Vector4F;
	//TODO Can add a shade here for shading rectangles in general I think is worth it.
	//Can also have a version with 4 colors and 4 shades which would be much bigger but possibly worth it
	//This would make 12 floats which is still less than the 13 in a 2d triangle. So we could collapse
	//2d into 1 object and no need for these different structs anymore.
}

//TODO Should have a RTriangle2D version so 2D triangles can remain 2D until being passed
//to simp which would then get converted to 3D.
RTriangle :: struct {
	using header : RenderHeader;
	triangle : Triangle3F;
	color : Vector4F;
	shade : Vector3F;
}
}
//Note : this ordering may only work for windows
ColorToHex :: (color : Vector4F) -> u32 {
    result : u32 = (round_to_u32(color.a * 255.0) << 24) |
	               (round_to_u32(color.r * 255.0) << 16) |
	               (round_to_u32(color.g * 255.0) << 8) |
	               (round_to_u32(color.b * 255.0));
    return result;
} 

ColorMultNoAlpha :: inline (mult : float, c : Vector4F) -> Vector4F {
	new_c : Vector4F;
	new_c.a = c.a;
	new_c.xyz = mult * c.xyz;
	return new_c;
}


