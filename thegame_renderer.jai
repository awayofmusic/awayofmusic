// #import "my_renderer";
#import "Sort";
Simp    :: #import "Simp";
// GetRect :: #import "GetRect";

//TODO use this as connection if we ever make renderer a separate module
// #load "thegame_renderer_data.jai";

/*TODO I think the renderer should have it's own allocator instead of passed in allocated data.
This way we can use that allocator whenever allocating for the renderer and then this would work
for tests as well. Right now we can't allocate in renderer data in tests because the test allocator
will allocate the renderer data as well and then this gets overriden by all_data in some wierd
way when we updated op spaces. If there renderer data had, its own allocator, then we could allocate
everything for the renderer with that allocator.
*/
MakeRendererData :: inline (
	memory_start_byte : *u8,
	memory_size : s64,
	window_width : s32, window_height : s32,
	screen_width : s32, screen_height : s32) 
-> RendererData
{
	renderer_data : RendererData;
	renderer_data.memory.base = memory_start_byte;
	renderer_data.memory.size = memory_size;
	//TODO eventually we want to have a zooming factor but maybe that can be somewhere else
	//We have this ratio since we started with 1920x1080 straight but then with DPI aware
	//we do this linear operation to keep it the same size it was at 1920x1080 but with the
	//visual quality of other resolutions.
	// renderer_data.original_width = window_width;
	// renderer_data.resolution_scale_factor = window_width / 1920.0;
	//TODO Rename this to pixels_per_unit since square makes it seem like a square
	//TODO I think we can remove this once we do global zooming (OR could leave it as an overall inital scale factor)
	scale_factor : float = 1.0;
	// renderer_data.default_pixels_per_square = scale_factor*ComputePixelsPerUnit(window_width);
	//NOTE : We use this fixed screen width here so that everything is to scale regardless of the window size
	//but it still scales to the screen size appropriately.
	fixed_screen_width := cast(s32) (0.825 * screen_width);
	renderer_data.default_pixels_per_square = scale_factor*ComputePixelsPerUnit(fixed_screen_width);
	// renderer_data.default_pixels_per_square = 20.0 * (window_width / 1920.0);
	// renderer_data.default_pixels_per_square = 20.0 * 1.5 * (window_width / 3840.0);
	// renderer_data.default_pixels_per_square = 20.0 * (window_width / renderer_data.original_width);
	// renderer_data.default_pixels_per_square = 20.0;

	//TODO eventually we can allow change in font size. possibly even per render_group
	//TODO Should we remove first font since we won't use it? I guess we can leave in case we want to use
	//other fonts for menus or or written things.
	// font_height : int = window_height / 49;
	// font_height := cast(int) (scale_factor * (window_height / 49));

	//TODO FROM HERE store the base font height and then resize font when we zoom by multiplying by
	//the same factor as we do for pixels_per_square on base render group zoom 
	//TODO FROM HERE double check sizing and also why does the test fail sometimes?

	//(NOT op space zoom, op space zoom is only for 2d spaces and to increase font size on editor)
	//NOTE : We use this fixed screen height here so that everything is to scale regardless of the window size
	//but it still scales to the screen size appropriately.
	fixed_screen_height := cast(s32) (0.825 * screen_height);
	font_height := cast(int) (scale_factor * (fixed_screen_height / 49));
	// font_height := cast(int) (scale_factor * (window_height / 49));
	// font_height := cast(int) (scale_factor * (1782 / 49));
	font_0 : *Simp.Dynamic_Font = Simp.get_font_at_size(RESOURCES_DIR_NAME, "OpenSans-BoldItalic.ttf", font_height);
	//TODO Store these fonts in the renderer as we don't need them anywhere else.
	array_add(*renderer_data.all_my_fonts, font_0);
	//Note : Seems like character_height == window_height but we still grab from here just in case
	array_add(*renderer_data.all_my_fonts_data, MakeFontData(font_0.character_height));

	font_1 : *Simp.Dynamic_Font = Simp.get_font_at_size(RESOURCES_DIR_NAME, "JetBrainsMono-Light.ttf", font_height);
	array_add(*renderer_data.all_my_fonts, font_1);
	one_char_width : s64 = Simp.prepare_text(font_1, "1");
	array_add(*renderer_data.all_my_fonts_data, MakeFontData(font_1.character_height, one_char_width));

	renderer_data.base_render_group = MakeBaseRenderGroup(window_width, window_height, 5, *renderer_data);
	// renderer_data.row_group = MakeBaseRenderGroup(window_width, window_height, 2, *renderer_data);
	// renderer_data.post_row_group = MakeBaseRenderGroup(window_width, window_height, 2, *renderer_data);
	renderer_data.overlay_render_group = MakeBaseRenderGroup(window_width, window_height, 1, *renderer_data);

	//TODO Maybe we can just use the viewport width here now.
	terminal_width : s32 = round_to_s32(0.25*window_width);
	renderer_data.terminal_render_group = MakeBaseRenderGroup(terminal_width, window_height, 1, *renderer_data);

	renderer_data.initial_memory_used_size = renderer_data.memory.used;

	renderer_data.is_initialized = true;

	return renderer_data;
}
//DOC : We only have 1 font right now, if we add more then we can add an index here for that specific font
//but if we add more then we have to set that for PushText for example and in the text op space or at least
//for ui eventually i guess.
//REMINDER Call UpdateFontSize instead of this to actually update the font size in game
UpdateRendererFontSize :: inline (font_size : float, rd : *RendererData) {
	font_height := cast(int) (2*font_size);
	font_1 : *Simp.Dynamic_Font = Simp.get_font_at_size(RESOURCES_DIR_NAME, "JetBrainsMono-Light.ttf", font_height);
	rd.all_my_fonts[1] = font_1;
	one_char_width : s64 = Simp.prepare_text(font_1, "1");
	rd.all_my_fonts_data[1] = MakeFontData(font_1.character_height, one_char_width);
}
ComputePixelsPerUnit :: inline (pixel_width : s32) -> float {
	pixels_per_unit : float = 20.0 * (pixel_width / 1920.0);	
	// pixels_per_unit : float = 20.0 * (3168.0 / 1920.0);	
	return pixels_per_unit;
}
ResizeRenderWindow :: inline (window : Window_Type) {
   Simp.update_window(window);
}
ResizeRendererData :: inline (new_window_pixel_width : s32, new_window_pixel_height : s32, renderer_data : *RendererData) {
	#if 0 {
	renderer_data.default_pixels_per_square = ComputePixelsPerUnit(new_window_pixel_width);

	//TODO eventually we can allow change in font size. possibly even per render_group
	//TODO If we allow people to set their own fonts, then we can grab the name again here.
	//Is there a way to show all fonts available on the system?
	//Probably should only allow monospace fonts to avoid weird issues anyways.
	//TODO Should we remove first font since we won't use it? I guess we can leave in case we want to use
	//other fonts for menus or or written things.
	//TODO Use this to change the font when we zoom in and out. Although maybe we don't allow zooming
	//in the text op space... just changing the window size and can just allow font size changing instead.
	font_height : int = new_window_pixel_height / 49;
	font_0 : *Simp.Dynamic_Font = Simp.get_font_at_size(RESOURCES_DIR_NAME, "OpenSans-BoldItalic.ttf", font_height);
	renderer_data.all_my_fonts[0] = font_0;
	renderer_data.all_my_fonts_data[0] = MakeFontData(font_0.character_height);

	font_1 : *Simp.Dynamic_Font = Simp.get_font_at_size(RESOURCES_DIR_NAME, "JetBrainsMono-Light.ttf", font_height);
	renderer_data.all_my_fonts[1] = font_1;
	one_char_width : s64 = Simp.prepare_text(font_1, "1");
	renderer_data.all_my_fonts_data[1] = MakeFontData(font_1.character_height, one_char_width);
	}

	//TODO FROM HERE update base render groups and all other render groups as well (maybe make a function for that)
	//and then loop over them and do these ones separtely, then check how it works before doing this on windows.
	ResizeRenderGroup(new_window_pixel_width, new_window_pixel_height, renderer_data.base_render_group, renderer_data);
	ResizeRenderGroup(new_window_pixel_width, new_window_pixel_height, renderer_data.overlay_render_group, renderer_data);

	//TODO We should make this adjustable to something between 0.2 and 0.5. Then we can use that adjustment here instead
	//and store it in renderer data near the terminal render group.
	//Could have a command that sets that until we allow terminal to be an op space so it's just 1 way to adjust.
	//TODO If terminal is an op space, then we can also remove the terminal render group altogether
	terminal_width : s32 = round_to_s32(0.25*new_window_pixel_width);
	ResizeRenderGroup(terminal_width, new_window_pixel_height, renderer_data.terminal_render_group, renderer_data);
	//TODO Should we set an option here to reset this in ResizeRenderGroup?
	//This is because we change we scissor the text based on this, so for now I will just update
	//but it is unnecessary if we do wrap around text AND if we make it a fixed op space later then it is also unnecessary.
	// renderer_data.terminal_render_group.render_viewport = 
	// 	RectMinDim(Vector2F.{0,0}, MakeV2F(terminal_width, new_window_pixel_height));

	for renderer_data.all_render_groups {
		ResizeRenderGroup(new_window_pixel_width, new_window_pixel_height, it, renderer_data);
		//TODO If it's 3D, then we need to update the viewport and p_frustum of the chord space.
	}
}
//TODO Could pass in window render group to reuse the screen half dim
//so we make sure it's exactly the same for all render groups
ResizeRenderGroup :: inline (
	new_window_pixel_width : s32, new_window_pixel_height : s32, 
	render_group : *RenderGroup,
	renderer_data : *RendererData) 
{
	#if 0 {
	viewport_center := GetCenter(render_group.render_viewport);
	old_viewport_dim := GetDim(render_group.render_viewport);
	new_viewport_dim := old_viewport_dim;
	new_viewport_dim.x *= new_window_pixel_width / cast(float) render_group.window_width;
	new_viewport_dim.y *= new_window_pixel_height / cast(float) render_group.window_height;
	render_group.render_viewport = RectCenterDim(viewport_center, new_viewport_dim);
	}
	render_group.render_viewport = RectMinDim(Vector2F.{0,0}, MakeV2F(new_window_pixel_width, new_window_pixel_height));

	render_group.window_width = new_window_pixel_width;
	render_group.window_height = new_window_pixel_height;
	render_group.screen_half_dim = ComputeScreenHalfDim(
		render_group.window_width,
		render_group.window_height);

	/*TODO could update these in thegame if needed since we have a pointer to RenderGroup
	*/
	// render_group.zoom_factor = 1.0;
	// render_group.pixels_per_square = renderer_data.default_pixels_per_square;
	//TODO Do we need to update this if we have 3d?
	//YES I think we can update it but need to also update the chord space depth
	//I THINK We only use p_frustum now so need to change the depth and half dim and then
	//recompute the viewport and p_frustum I think and then can test that visually.
	// render_group.focal_squares = 24.0; //1 xy unit in 2D plane at this z square value from camera
	//TODO this should be adjusted in renderer to be resolution independent
	//TODO could adjust this relative to camera movement adjustment
	UpdateHalfMonitorSquares(render_group);	
}
MakeBaseRenderGroup :: inline (
	pixel_width : s32,
	pixel_height : s32,
	push_buffer_size_megabytes : s64,
	renderer_data : *RendererData)
-> *RenderGroup
{
	render_group : *RenderGroup = PushStruct(*renderer_data.memory, RenderGroup);

	render_group.render_push_buffer.size = Megabyte(push_buffer_size_megabytes);
	render_group.render_push_buffer.base = PushSize(*renderer_data.memory, render_group.render_push_buffer.size);

	//TODO this can likely be pulled out and done in the renderer
	render_group.default_basis.p = Vector2F.{};

	render_group.render_viewport = RectMinDim(Vector2F.{0,0}, MakeV2F(pixel_width, pixel_height));

	render_group.window_width = pixel_width;
	render_group.window_height = pixel_height;

	render_group.screen_half_dim = ComputeScreenHalfDim(
		render_group.window_width,
		render_group.window_height);

	/*TODO could update these in thegame if needed since we have a pointer to RenderGroup
	*/
	render_group.zoom_factor = 1.0;
	render_group.pixels_per_square = renderer_data.default_pixels_per_square;
	render_group.focal_squares = 24.0; //1 xy unit in 2D plane at this z square value from camera
	//TODO this should be adjusted in renderer to be resolution independent
	//TODO could adjust this relative to camera movement adjustment
	#if 1 {
	UpdateHalfMonitorSquares(render_group);
	} else {
	width_squares : float = (pixel_width-1) / render_group.pixels_per_square;
	height_squares : float = (pixel_height-1) / render_group.pixels_per_square;
	render_group.half_monitor_squares = MakeV2F(width_squares * 0.5, height_squares * 0.5);
	}

	//TODO should this be put in each render text entry for different fonts?
	//TODO could pass get_font_at_size into game if needed
	//when we completely separate out the renderer
	//TODO could search for font by name instead
	render_group.font_index = 1;

	return render_group;
}

//TODO could pass in a flag to note use GetRect if needed
SetupRenderer :: inline (window : Window_Type) {
    //Setup simp renderer
	Simp.set_render_target(window);
    // GetRect.ui_init();
}

SwapRenderBuffer :: inline (window : Window_Type, type : RendererType) {
	//Note : This is the only renderer for now so we call it directly
	//but can use branching if we have multiple renderers later.
	Simp.swap_buffers(window);
	#if 0 {
	if RendererType.SIMP_OPENGL == type
	{
	}
	else assert(false, "Renderer not implemented with type %\n", type);
	}
}

PerFrameUpdateRenderer :: inline (window : Window_Type, width : s32, height : s32) {
	// GetRect.ui_per_frame_update(window, WINDOW_WIDTH, WINDOW_HEIGHT, get_time());	
}


RenderSort :: (e1 : *RenderHeader, e2 : *RenderHeader) -> int {
	result : int = e1.order - e2.order;	
	return result;
}

//TODO : all elements of the render group should be triangles
//so we have to convert rectangles to quads and quads to triangles
#if 0 {
RenderGroup2DToOutput :: (group : *RenderGroup, output : *RenderBuffer) {
    screen_half_dim := MakeV2F(0.5 * (output.width-1), 0.5 * (output.height-1));
	sort_view : [] *RenderHeader = group.render_sort_buffer;
	sort_view.count = group.render_count;
	if group.sort_by_order then quick_sort(sort_view, RenderSort);
	for entry : sort_view {
	}
}
}

//TODO should we just store this in RendererData?
RendererType :: enum {
	SIMP_OPENGL;
	CPU_RENDERING;
}
USE_OLD_ALL_RENDER_GROUPS :: false;
//TODO allow this switch to let us optimize between different renderers if needed
RenderDataToOutput :: inline (renderer_data : *RendererData, type : RendererType)
{
	if RendererType.SIMP_OPENGL == type 
	{
		RenderGroupSimpOpenGL(renderer_data.base_render_group, renderer_data);
		// RenderGroupSimpOpenGL(renderer_data.row_group, renderer_data);
		// RenderGroupSimpOpenGL(renderer_data.post_row_group, renderer_data);
		#if USE_OLD_ALL_RENDER_GROUPS {
		for renderer_data.all_render_groups {
			RenderGroupSimpOpenGL(it, renderer_data);
		}
		} else {
		for renderer_data.open_op_space_render_groups {
			RenderGroupSimpOpenGL(it.pre_scissor_group, renderer_data);
			RenderGroupSimpOpenGL(it.scissor_group_3D, renderer_data);
			RenderGroupSimpOpenGL(it.scissor_group, renderer_data);
			RenderGroupSimpOpenGL(it.post_render_group, renderer_data);
		}
		}
		//TODO We render it after all_render_groups but we could add it to all_render_groups
		//and then it would be in order so we could have things on top of the terminal then.
		//Right now that does not seem necessary and separating the terminal out
		//simplifies having to deal with passing over the OpSpace and RenderGroups on level loads.
		RenderGroupSimpOpenGL(renderer_data.terminal_render_group, renderer_data);
		RenderGroupSimpOpenGL(renderer_data.overlay_render_group, renderer_data);
	}
	else if RendererType.CPU_RENDERING == type
	{
		//Note : CPU rendering does not work. I see no need in re-implementing it.
		//It was a productive excercise on learning rendering fundamentals.
		#if 0 {
			RenderGroupCPU(*renderer_data.render_group, *renderer_data.draw_buffer);
		}
	}
	else assert(false, "Renderer % not found.\n", type);
}

//TODO Can likely remove this since the enum version works well
/**Note : currently assumes that render entries are in camera space
	and that the camera is always at screen center (ie using screen_half_dim)
**/
/**TODO multiplying by pixels in here so we can check camera rectangle
	somewhere else, but maybe we could do that with pixels as well
**/
//TODO should this just take RenderGroup instead of *RenderGroup
//TODO should make a purely 2D version now with data oriented design
#if 0 {
RenderGroupSimpOpenGL :: inline (group : *RenderGroup) {
	// ProfileProcedure();
	//TODO use group.memory directly when we don't sort for speed (will we always sort?)
	//TODO i think we don't have to subtract 1 here because we cast down to float
	//so 0.5*10 == 5 and 0.5*11 = 5.5 -> 5.0
    // group_center : Vector2F = MakeV2F(
    // 	0.5 * (group.window_width-group.render_viewport.min_x), 
    // 	0.5 * (group.render_viewport.max_y-group.render_viewport.min_y)); 
    // screen_half_dim := MakeV2F(0.5 * (group.window_width-1), 0.5 * (group.window_height-1));
    //TODO use this directly
    // screen_half_dim : Vector2F = group.screen_half_dim;
    //TODO group.render_sort_buffer should be MemoryData and not and Array
    //TODO try out RadixSort here once we impelement that
	quick_sort(group.render_sort_buffer, RenderSort);
	// ProfilerStart("Render Entry Loop");

	//TODO leaving this here for now since that what is done in GetRect popups.jai
	// GetRect.pointer_end_frame();  // We don't have a better place to put this right now!

	Simp.set_scissor(
		cast(s32) group.render_viewport.min.x, 
		cast(s32) group.render_viewport.min.y,
		cast(s32) group.render_viewport.max.x, 
		cast(s32) group.render_viewport.max.y);

	/*TODO
		could store a function pointer for each type and
		just run that function with itself as input instead of this
		OR just use Type in RenderHeader without the polymoprhism
	*/
	for entry : group.render_sort_buffer {
		//TODO draw quad function
		//TODO should we transform every shape to viewport space before rendering
		if entry.type == RTriangle {
			//TODO could separate 2D and 3D since order may not matter between them
			//TODO should make a pure 2D version which accounts for viewport offset if we don't have 2D on different z planes
			tri := cast(*RenderEntry(RTriangle)) entry;
			//TODO no need to make a triangle here
			pixel_triangle := MakeTriangle3F(
				MakeV3F(tri.data.triangle.a.xy * group.pixels_per_square, tri.data.triangle.a.z),
				MakeV3F(tri.data.triangle.b.xy * group.pixels_per_square, tri.data.triangle.b.z),
				MakeV3F(tri.data.triangle.c.xy * group.pixels_per_square, tri.data.triangle.c.z));
			Simp.immediate_triangle(pixel_triangle.a.jai_v, pixel_triangle.b.jai_v, pixel_triangle.c.jai_v,
				tri.data.shade.x * tri.color.jai_v, tri.data.shade.y * tri.color.jai_v, tri.data.shade.z * tri.color.jai_v);
			// pixel_triangle := MakeTriangle3F(
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.a.xy * group.pixels_per_square)), tri.data.triangle.a.z),
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.b.xy * group.pixels_per_square)), tri.data.triangle.b.z),
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.c.xy * group.pixels_per_square)), tri.data.triangle.c.z));
			// if PRINT_LENGTH && it_index == 10 print("pixel_tri is %\n", pixel_triangle);
			// DrawFilledTriangle(pixel_triangle, tri.color, output, tri.data.shade);
		}
		else if entry.type == RRectangle {
			//TODO We could set this shader every time if we ever have issues because 
			//it does not reset it if we already are using the same on
			//WOULD THAT FIX THINGS FOR THE PRE_SCISSOR_GROUP ISSUES?
			// Simp.set_shader_for_color(enable_blend = true);
			rect := cast(*RenderEntry(RRectangle)) entry;
			minXY : Vector2F = group.screen_half_dim + rect.data.rect.min * group.pixels_per_square;
			maxXY : Vector2F = group.screen_half_dim + rect.data.rect.max * group.pixels_per_square;
			Simp.immediate_quad(minXY.x, minXY.y, maxXY.x, maxXY.y, rect.color.jai_v);
		} 
		else if entry.type == RLine {
			line := cast(*RenderEntry(RLine)) entry;
			DrawLineSimpQuad(group.screen_half_dim + group.pixels_per_square * line.offset,
					 group.screen_half_dim + group.pixels_per_square * line.data.end,
					 line.color);
		}
		else if entry.type == RText {
			// Simp.set_shader_for_text();
			r_text := cast(*RenderEntry(RText)) entry;
	    	// game_code.SIMPSetShaderForText();
	    	//Note : This assumes that we are defining the point on the left_middle of the text.
	    	//TODO Could remove text_y if we define it as bottom_left corner.
			x := cast(int) (group.screen_half_dim.x + group.pixels_per_square * r_text.offset.x);
		 	y := cast(int) (group.screen_half_dim.y + group.pixels_per_square * r_text.offset.y);
		 	text_width := Simp.prepare_text(group.my_font, r_text.data.text, .LEFT_JUSTIFIED);
		    // text_x := round_to_int(x - text_width / 2.0);
	 	    text_y := round_to_int(y - group.my_font.character_height * 0.5);
		    Simp.draw_prepared_text(group.my_font, x, text_y, Vector4.{1.0, 1.0, 1.0, 1.0});
		}
		else if entry.type == RClear {
			clear := cast(*RenderEntry(RClear)) entry;
			Simp.clear_render_target(clear.color.r, clear.color.g, clear.color.b, clear.color.a);
			// Simp.immediate_flush();
			Simp.set_shader_for_color(enable_blend = true);
			// Simp.immediate_begin();
		}
		else if entry.type == RImmediateFlush {
			Simp.immediate_flush();
		}
		//TODO should we just set these before every text and shader color?
		//maybe this is faster... i don't know opengl. 
		//It might not be since set_shader_for_color sets this for us anyways.
		else if entry.type == RSetShaderColor {
			Simp.set_shader_for_color(enable_blend = true);
		}
		else if entry.type == RSetShaderText {
			Simp.set_shader_for_text();
		}
		else if entry.type == RSetScissor {
			r_scissor := cast(*RenderEntry(RSetScissor)) entry;
			min_x := cast(s32) (group.screen_half_dim.x + r_scissor.data.x0 * group.pixels_per_square);
			min_y := cast(s32) (group.screen_half_dim.y + r_scissor.data.y0 * group.pixels_per_square);
			max_x := cast(s32) (group.screen_half_dim.x + r_scissor.data.x1 * group.pixels_per_square); 
			max_y := cast(s32) (group.screen_half_dim.y + r_scissor.data.y1 * group.pixels_per_square);
			Simp.set_scissor(min_x, min_y, max_x, max_y);
		}
		else if entry.type == RClearScissor {
			Simp.clear_scissor();
		}
	}
	// ProfilerEnd("Render Entry Loop");
	// ProfilerPrint("Render Entry Loop");
}
}
else {
RenderGroupSimpOpenGL :: inline (group : *RenderGroup, renderer_data : RendererData) {
	// ProfileProcedure();
	//TODO use group.memory directly when we don't sort for speed (will we always sort?)
	//TODO i think we don't have to subtract 1 here because we cast down to float
	//so 0.5*10 == 5 and 0.5*11 = 5.5 -> 5.0
    // group_center : Vector2F = MakeV2F(
    // 	0.5 * (group.window_width-group.render_viewport.min_x), 
    // 	0.5 * (group.render_viewport.max_y-group.render_viewport.min_y)); 
    // screen_half_dim := MakeV2F(0.5 * (group.window_width-1), 0.5 * (group.window_height-1));
    //TODO use this directly
    // screen_half_dim : Vector2F = group.screen_half_dim;
    //TODO group.render_sort_buffer should be MemoryData and not and Array
    //TODO try out RadixSort here once we impelement that
 	if !group.is_3D_render_group {
		quick_sort(group.render_sort_buffer, RenderSort);
	}
	// ProfilerStart("Render Entry Loop");

	//TODO leaving this here for now since that what is done in GetRect popups.jai
	// GetRect.pointer_end_frame();  // We don't have a better place to put this right now!

	Simp.set_scissor(
		cast(s32) group.render_viewport.min.x,
		cast(s32) group.render_viewport.min.y,
		cast(s32) group.render_viewport.max.x, 
		cast(s32) group.render_viewport.max.y);

	/*REOMVE THIS ONCE WE DO IT
	TODO FROM HERE It's worth trying 2 different .exes side-by-side to really see if theres a difference.
	Also increasing the number of vertices does seem to make a difference so then the separate 3D case with
	vertex-color buffer will likely solve any of those issues so we only clear the depth buffer and draw 1 time.
	All those could make a difference, hard to tell until we try it out. 

	PitchSpace3D and then also update SpacePoint3D stuff with VlPoint and VLLinePoint so that the points are in a
	separate array and then we can just collapse the rendering in chord_s3 that supports between dimensions for
	VLLinePoint and VLPoint
	*/

	//TODO Can pull this out once we separate 3D from 3D rendering. Then we only need this for 3D.
	/*TODO NOTE : Am I noticing some minor stuttering with the depth buffer? I am not sure.
	Worth testing around later. Can even remove this for now if needed until we do a full rendering pass later.
	Will only be able to tell once we have separate 3D rendering vertex buffer and we don't sort on 3D and
	GL_STREAM_DRAW->GL_STATIC_DRAW seems to make a difference
	
	Actually, this would not make a difference since they would just get rendered over each other, BUT it would still
	be more efficient to pass in the entire vertex array as 1 draw call.
	TO FIX THE CLEAR DEPTH BUFFER ONLY AFTER ALL VERTICES, we would have to setup the vertex array buffer in here
	on pushing the triangles. So instead of pushing Triangle3F, we would push vertex-color, vertex-color...
	And we would have to setup separate shader and shader data specific for this 3D case. This would be much more efficient
	as we would avoid copying from triangle to vertex AND we could optimize data and opengl things if needed only for 3D.
	Then we could test that version and compare that with or without the depth_buffer which would be a bit involved
	since we would have to have 1 version with order and 1 without since the difference between the depth buffer and
	non-depth buffer version is just that non-depth buffer has an order so we can sort. Can also keep this version
	and compile both and then run.exe next to each other and see if there a difference.

	Stuttering may also be caused due to improper setup (can check the size of opengl depth buffer and also make it 32-bit? Or maybe not all graphics cards have that).
	Also sometimes it does seem smooth, so maybe could even be a movement thing like in 2D where sometimes it's jittery and sometimes not.
	Maybe I'm just crazy... and it only happens once in a while. Would be worth making separate 3D entirely and then comparing. 
	*/
	if group.is_3D_render_group {
		Simp.enable_depth_test();
		//TODO Can set this outside but if we don't sort eventually and we just have 3D renderer do color
		//we can just set this beforehand every time.
		Simp.set_shader_for_color(true);
		//TODO Is there stutter if we only do depth buffer later?
		// Simp.clear_depth_buffer();
	}

	/*TODO
		could store a function pointer for each type and
		just run that function with itself as input instead of this
		OR just use Type in RenderHeader without the polymoprhism

		ULTIMATELY it may be more efficient to have 1 render object of the
		biggest size and then just union the other values and go through them
		1) Sequential in memory where each object is max size VS
		2) random access where each object is different sizes
		LIKELY THAT 1) is more efficient in general but that may be worth testing
		Another idea is to separate 3D and 2D but we still need to order 3D and 2D on top of each other soo...
		YES, indeed now we can have a separate 3D render group loop and even likely have a separate data
		array altogether which would store vertex-color and then this can be passed directly to opengl.
		Likely best to wait to see if this all works on mac first and then do it in case we have issues.
		Also if we want to optimize to metal later then we don't want our data to be opengl specific.

		IF everything is 3D (ie 2d would have z as depth, op_linear_row check) then we can leverage depth buffer to sort and 
		then we don't need to sort here and don't need an extra array copy but I am not sure if that would work in all cases.
		Probably best to do above way first and then maybe try this later for efficiency optimization.
	*/
	for entry : group.render_sort_buffer {
		//TODO draw quad function
		//TODO should we transform every shape to viewport space before rendering
		if entry.render_type == {
		case RenderType.TRIANGLE; {
		//TODO Could have a 2D Triangle version where we only start 3 Vector2Fs and then
		//convert it to 3D only here for simp.
		// if entry.type == RTriangle {
			//TODO could separate 2D and 3D since order may not matter between them
			//This would allow the screen_half_dim in here like for other shapes...
			//TODO should make a pure 2D version which accounts for viewport offset if we don't have 2D on different z planes
			//YES THEN WE WOULD HAVE CONSISTENT VIEWPORT OFFSET for 2D HERE INSTEAD OF HAVING TO calculate the offset in each function
			//Then we can also do consistent zoom using pixels_per_square or even a factor on it which makes the most sense
			tri := cast(*RTriangle) entry;
			//Note : Only multiplying xy for now in case we want to use the original z later for the depth buffer in 3D.
			//Instead of just multiplying the entire triangle into pixels.
			// pixel_triangle : Triangle3F = tri.triangle * group.pixels_per_square;
			pixel_triangle : Triangle3F = tri.triangle;
			pixel_triangle.a.xy *= group.pixels_per_square;
			pixel_triangle.b.xy *= group.pixels_per_square;
			pixel_triangle.c.xy *= group.pixels_per_square;
			// Simp.enable_depth_test();
			Simp.immediate_triangle(pixel_triangle.a.jai_v, pixel_triangle.b.jai_v, pixel_triangle.c.jai_v,
				tri.shade.x * tri.color.jai_v, tri.shade.y * tri.color.jai_v, tri.shade.z * tri.color.jai_v);
			// Simp.immediate_flush();
			// Simp.disable_depth_test();
			// pixel_triangle := MakeTriangle3F(
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.a.xy * group.pixels_per_square)), tri.data.triangle.a.z),
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.b.xy * group.pixels_per_square)), tri.data.triangle.b.z),
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.c.xy * group.pixels_per_square)), tri.data.triangle.c.z));
			// if PRINT_LENGTH && it_index == 10 print("pixel_tri is %\n", pixel_triangle);
			// DrawFilledTriangle(pixel_triangle, tri.color, output, tri.data.shade);
		}
		//TODO Should add a 2D triangle even if it's just for the 3 less floats since most things will be 2D
		case RenderType.RECTANGLE; {
		// else if entry.type == RRectangle {
			//TODO This only resets the shader if we or not on the same one.
			//WOULD THAT FIX THINGS FOR THE PRE_SCISSOR_GROUP ISSUES? Seems like no
			// Simp.set_shader_for_color(enable_blend = true);
			rect := cast(*RRectangle) entry;
			minXY : Vector2F = group.screen_half_dim + rect.rect.min * group.pixels_per_square;// * group.zoom_factor;
			maxXY : Vector2F = group.screen_half_dim + rect.rect.max * group.pixels_per_square;// * group.zoom_factor;
			Simp.immediate_quad(minXY.x, minXY.y, maxXY.x, maxXY.y, rect.color.jai_v);
		} 
		case RenderType.LINE; {
		// else if entry.type == RLine {
			line := cast(*RLine) entry;
			DrawLineSimpQuad(group.screen_half_dim + group.pixels_per_square * line.offset,
					 group.screen_half_dim + group.pixels_per_square * line.end,
					 line.color);
		}
		case RenderType.TEXT; {
		// else if entry.type == RText {
			//TODO Could be worth profiling this and for rects and triangle
			//to see if its slower if we set this here. Probably not since its mostly color anyways
			// Simp.set_shader_for_text();
			r_text := cast(*RText) entry;
	    	// game_code.SIMPSetShaderForText();
	    	//Note : This assumes that we are defining the point on the left_middle of the text.
	    	//TODO Could remove text_y if we define it as bottom_left corner.
			x := cast(int) (group.screen_half_dim.x + group.pixels_per_square * r_text.offset.x);
		 	y := cast(int) (group.screen_half_dim.y + group.pixels_per_square * r_text.offset.y);

		 	text_width := Simp.prepare_text(renderer_data.all_my_fonts[1], r_text.text, .LEFT_JUSTIFIED);
			// text_x := round_to_int(x - text_width / 2.0);
			//TODO We could remove this and define text from bottom left instead. Would just need to change
			//everywhere that we do that then.
			text_y := round_to_int(y - renderer_data.all_my_fonts[1].character_height * 0.5);
			//TODO Font can be taken from RendererData so we can separate out DynamicFont from RenderGroup
			Simp.draw_prepared_text(renderer_data.all_my_fonts[1], x, text_y, r_text.color.jai_v);
		}
		case RenderType.CLEAR; {
		// else if entry.type == RClear {
			clear := cast(*RClear) entry;
			Simp.clear_render_target(clear.color.r, clear.color.g, clear.color.b, clear.color.a);
			// Simp.immediate_flush();
			Simp.set_shader_for_color(enable_blend = true);
			// Simp.immediate_begin();
		}
		case RenderType.IMMEDIATE_FLUSH; {
		// else if entry.type == RImmediateFlush {
			Simp.immediate_flush();
		}
		//TODO should we just set these before every text and shader color?
		//maybe this is faster... i don't know opengl
		case RenderType.SET_SHADER_COLOR; {
		// else if entry.type == RSetShaderColor {
			Simp.set_shader_for_color(enable_blend = true);
		}
		case RenderType.SET_SHADER_TEXT; {
		// else if entry.type == RSetShaderText {
			Simp.set_shader_for_text();
		}
		case RenderType.SET_SCISSOR; {
		// else if entry.type == RSetScissor {
			r_scissor := cast(*RSetScissor) entry;
			#if 0 {
			//TODO Can use this for camera position if needed. But better to control at runtime since viewports are generally in pixel.
			min_x := cast(s32) (group.screen_half_dim.x + r_scissor.x0 * group.pixels_per_square);
			min_y := cast(s32) (group.screen_half_dim.y + r_scissor.y0 * group.pixels_per_square);
			max_x := cast(s32) (group.screen_half_dim.x + r_scissor.x1 * group.pixels_per_square); 
			max_y := cast(s32) (group.screen_half_dim.y + r_scissor.y1 * group.pixels_per_square);
			Simp.set_scissor(min_x, min_y, max_x, max_y);
			} else {
			Simp.set_scissor(cast(s32) r_scissor.x0, cast(s32) r_scissor.y0, cast(s32) r_scissor.x1, cast(s32) r_scissor.y1);
			}
		}
		case RenderType.CLEAR_SCISSOR; {
		// else if entry.type == RClearScissor {
			Simp.clear_scissor();
		}
		}
	}

	if group.is_3D_render_group {
		Simp.immediate_flush();
		Simp.clear_depth_buffer();
		Simp.disable_depth_test();
	}

	// ProfilerEnd("Render Entry Loop");
	// ProfilerPrint("Render Entry Loop");
}
}

//TODO remove this once we implement GetRect
#if 0 {
init_subwindow : bool = false;
subwindow: GetRect.Subwindow_Info;
//TODO turn this on to test draw subwindow
TESTGetRectSubwindow :: inline (renderer_data : *RendererData) {
	//TODO should this be done here or in UpdateAndRender?
	/*GET RECT TEST
	*/
	current_theme := xx GetRect.Default_Themes.Default;
    proc := GetRect.default_theme_procs[current_theme];
    my_theme := proc();

	k := WINDOW_HEIGHT * .1;
    if !init_subwindow 
    {
    	init_subwindow = true;
	    r := GetRect.get_rect(7.5*k, 3*k, 4*k, 5*k);
	    subwindow.rect = r;
	    subwindow.user_data = renderer_data;
	    subwindow.draw = draw_subwindow_text;
	    subwindow.title_text = "Text";
	}
	subwindow_state := GetRect.add_subwindow(*subwindow, *my_theme.subwindow_theme);
	/*END GET RECT TEST
	*/

	draw_subwindow_text :: (r: GetRect.Rect, data: *void) {
		renderer_data := cast(*RendererData) data;
	    font := renderer_data.render_group.my_font;
	    // lines := split(TEXT_FIELD_1, "\n");

	    K :: .5;
	    color := Vector4.{K, K, K, 1};

	    xpad := floor(font.default_line_spacing * .5 + .5);

	    // print("r = %\n", r);
	    x := r.x + xpad;
	    y := r.y + r.h;// - cast(float) font.default_line_spacing;
		Simp.immediate_quad(r.x, r.y, r.x+10, r.y+10, Vector4.{1,1,1,1});
        y -= cast(float) font.default_line_spacing;
	}
	GetRect.pointer_end_frame();  // We don't have a better place to put this right now!

    to_raise: *GetRect.Subwindow_State;
    //TODO turn this on to test draw subwindow
    // GetRect.draw_subwindow(subwindow_state);
    subwindow_state.wants_draw = false;

    if subwindow_state.wants_a_raise {
        to_raise = subwindow_state;
        subwindow_state.wants_a_raise = false;
    }

    if to_raise GetRect.raise(to_raise);

    // drawing_popups = true;
    // for * popups {
    //     it.proc(it.data);
    // }
    // drawing_popups = false;

    // There is no explicit GetRect end-of-frame call; this is the closest thing.
    // Once we get here, we are done drawing widgets, at least in theory!

    // If the left mouse button was pressed, and no widget ever intercepted it,
    // and we aren't active, deselect active widgets.

    if (GetRect.mouse_button_left_state & .START) && !GetRect.some_widget_received_left_mouse_button {
        if !(GetRect.active_widget && GetRect.active_widget_is_grabbing) {
            GetRect.active_widget_deactivate_all();
        }
    }
}
}

//TODO this is unused but leaving here in for potential template/experimenting later
RenderGroupCPU :: inline (group : *RenderGroup, output : *RenderBuffer) {
	#if 0 {
	// ProfileProcedure();
	//TODO use group.memory directly when we don't sort for speed (will we always sort?)
    screen_half_dim := MakeV2F(0.5 * (output.width-1), 0.5 * (output.height-1));
	quick_sort(group.render_sort_buffer, RenderSort);
	// ProfilerStart("Render Entry Loop");
	for entry : group.render_sort_buffer {
		//TODO draw quad function
		//TODO should we transform every shape to viewport space before rendering
		if entry.type == RTriangle {
			//TODO could separate 2D and 3D since order may not matter between them
			//TODO should make a pure 2D version which accounts for viewport offset if we don't have 2D on different z planes
			tri := cast(*RenderEntry(RTriangle)) entry;
			pixel_triangle := MakeTriangle3F(
				MakeV3F(tri.data.triangle.a.xy * group.pixels_per_square, tri.data.triangle.a.z),
				MakeV3F(tri.data.triangle.b.xy * group.pixels_per_square, tri.data.triangle.b.z),
				MakeV3F(tri.data.triangle.c.xy * group.pixels_per_square, tri.data.triangle.c.z));
			// pixel_triangle := MakeTriangle3F(
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.a.xy * group.pixels_per_square)), tri.data.triangle.a.z),
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.b.xy * group.pixels_per_square)), tri.data.triangle.b.z),
			// 	MakeV3F(MakeV2F(MakeV2ICeil(tri.data.triangle.c.xy * group.pixels_per_square)), tri.data.triangle.c.z));
			// if PRINT_LENGTH && it_index == 10 print("pixel_tri is %\n", pixel_triangle);
			// DrawFilledTriangle(pixel_triangle, tri.color, output, tri.data.shade);
		}
		else if entry.type == RRectangle {
			rect := cast(*RenderEntry(RRectangle)) entry;
			DrawRectangle(screen_half_dim + rect.data.rect.min * group.pixels_per_square,
						  screen_half_dim + rect.data.rect.max * group.pixels_per_square,
						  rect.color, output);
		} 
		else if entry.type == RLine {
			line := cast(*RenderEntry(RLine)) entry;
			DrawLine(screen_half_dim + group.pixels_per_square * line.offset,
					 screen_half_dim + group.pixels_per_square * line.data.end,
					 line.color, output);
		}
		else if entry.type == RClear {
			clear := cast(*RenderEntry(RClear)) entry;
			ClearRenderBuffer(clear.color, output);
		}
	}
	// ProfilerEnd("Render Entry Loop");
	// ProfilerPrint("Render Entry Loop");
	}
}

ClearDepthBuffer :: inline (render_buffer : *RenderBuffer) {
	for * render_buffer.depth_buffer {
		<<it = 0;
	}
}

ClearRenderBuffer :: (color : Vector4F, render_buffer : *RenderBuffer) {
	hex_color := ColorToHex(color);
    pixel := cast(*u32) render_buffer.memory;
    for 0..(render_buffer.width * render_buffer.height - 1) {
        <<pixel = hex_color;
        pixel += 1;
    }
    ClearDepthBuffer(render_buffer);
}

//TODO retry to do bit offset
DrawBitmap :: (v_input_start : Vector2F,
                loaded_bitmap : RenderBuffer, 
                draw_buffer : *RenderBuffer,
                c_alpha : float) {
    v_start := v_input_start;
    // assert(v_start.x >= 0);
    // assert(v_start.y >= 0);
    // assert(v_start.x < cast(float) draw_buffer.BitmapWidth);
    // assert(v_start.y < cast(float) draw_buffer.BitmapHeight);

    //TODO THIS MIGHT BE FIXED LETS SEE IF IT EVER CRASHES on background_start pixels again
    //probably the same bug here with the rounding on 0.5
    //so wed have to add offset ourselves but can also test sometimes by
    //plugging in the values directly
    x_start_u32 := round_to_s32(v_start.x);
    y_start_u32 := round_to_s32(v_start.y);
    x_end_u32 := x_start_u32 + loaded_bitmap.width;
    y_end_u32 := y_start_u32 + loaded_bitmap.height;
    if x_end_u32 >= draw_buffer.width {
        x_end_u32 = draw_buffer.width - 1;
    }
    if y_end_u32 >= draw_buffer.height {
        y_end_u32 = draw_buffer.height - 1;
    }

    // print("bitmap start x = %\n", x_start_u32);
    // print("bitmap end x = %\n", x_end_u32);

    offset_x : s32;
    if x_start_u32 < 0 {
        offset_x = -x_start_u32; 
        // x_start_u32 += offset_x;
        x_end_u32 -= offset_x;
    }
    offset_y : s32;
    if y_start_u32 < 0 {
        offset_y = -y_start_u32;
        // y_start_u32 += offset_y;
        y_end_u32 -= offset_y;
    }

    // if x_end_u32 >= draw_buffer.width {
        // x_end_u32 = draw_buffer.width - 1;
    // }
    // if y_end_u32 >= draw_buffer.height {
        // y_end_u32 = draw_buffer.height - 1;
    // }

    background_start := cast(*u32) draw_buffer.memory;
    for y : y_start_u32..y_end_u32 {
        y_pixel_offset := y + offset_y;
        y_bitmap := y_pixel_offset - y_start_u32;
        for x : x_start_u32..x_end_u32 {
            x_pixel_offset := x + offset_x;
            x_bitmap := x_pixel_offset - x_start_u32;
            //TODO this is awfully inefficient alpha blending
            bitmap_pixel := loaded_bitmap.bitmap[y_bitmap * loaded_bitmap.width + x_bitmap];
            t : float = ((bitmap_pixel >> 24) & 0xff) / 255.0;
            t *= c_alpha;
            bR : float = cast(float) ((bitmap_pixel >> 16) & 0xff);
            bG : float = cast(float) ((bitmap_pixel >> 8) & 0xff);
            bB : float = cast(float) (bitmap_pixel & 0xff);

            background_value := y_pixel_offset * draw_buffer.width + x_pixel_offset;
            background_pixel := background_start[background_value];
            dR : float = cast(float) ((background_pixel >> 16) & 0xff);
            dG : float = cast(float) ((background_pixel >> 8) & 0xff);
            dB : float = cast(float) (background_pixel & 0xff);

            pR : float = t * bR + (1.0 - t) * dR;
            pG : float = t * bG + (1.0 - t) * dG;
            pB : float = t * bB + (1.0 - t) * dB;

            newR : u32 = (cast(u32) (pR + 0.5)) << 16;
            newG : u32 = (cast(u32) (pG + 0.5)) << 8;
            newB : u32 = (cast(u32) (pB + 0.5));
            // //Apparently alpha here is unnecessary since it's only informational for the blt
            blended_pixel := newR | newG | newB;
            // if offset_x > 0 {
            //     blended_pixel = BLACK;
            // }
            SetPixelFromBottom(x_pixel_offset, y_pixel_offset, blended_pixel, draw_buffer);
        }
    }

    //For debugging to check pixel equality
    // for y : 0..Y_ADJ_LENGTH-1 {
    //     for x : 0..X_ADJ_LENGTH-1 {
    //         bbuffer := cast(*u32) back_buffer.BitmapMemory;
    //         assert(bbuffer[y * back_buffer.BitmapWidth + x] == bitmap[y * loaded_bitmap.Width + x]);
    //     }
    // }
}

//TODO where is InterpTriangleYSort? maybe a full git search would find it
#if 0 {
DrawFilledTriangle :: (triangle : Triangle3F, color : Vector4F, render_buffer : *RenderBuffer, shade : Vector3F = Vector3F.{1,1,1}) {

   tri_xy := MakeTriangle2F(triangle.a.xy, triangle.b.xy, triangle.c.xy);
	x012, x02 := InterpTriangleYSort(*tri_xy);

	tri_zy : Triangle2F = MakeTriangle2F(
		MakeV2F(triangle.a.z, triangle.a.y),
		MakeV2F(triangle.b.z, triangle.b.y),
		MakeV2F(triangle.c.z, triangle.c.y));
    z012, z02 := InterpTriangleYSort(*tri_zy);

	tri_sy : Triangle2F = MakeTriangle2F(
		MakeV2F(shade.x, triangle.a.y),
		MakeV2F(shade.y, triangle.b.y),
		MakeV2F(shade.z, triangle.c.y));
    s012, s02 := InterpTriangleYSort(*tri_sy);

    m : int = cast(int) (x012.count / 2.0);
    x_left, z_left, s_left : [] float;
    x_right, z_right, s_right : [] float;
    if x012[m] < x02[m] {
    	x_left = x012; z_left = z012; s_left = s012;
    	x_right = x02; z_right = z02; s_right = s02;
    } else {
    	x_left = x02; z_left = z02; s_left = s02;
    	x_right = x012; z_right = z012; s_right = s012;
    }

    //Note : ys are low->high sorted from a->b->c
    y0 : int = max(0, round_to_int(tri_xy.a.y));
    y2 : int = min(cast(int) render_buffer.height-1, round_to_int(tri_xy.c.y));
    for y : y0..y2 {
    	y_norm : int = y - y0;
    	xl_int : int = max(0, round_to_int(x_left[y_norm]));
    	xr_int : int = min(cast(int) render_buffer.width-1, round_to_int(x_right[y_norm]));
		z_seg : [] float = Interpolate(xl_int, z_left[y_norm], xr_int, z_right[y_norm]);
		s_seg : [] float = Interpolate(xl_int, s_left[y_norm], xr_int, s_right[y_norm]);
    	for x : xl_int..xr_int {
    		// z_inv : float = 1 / z_seg[x - xl_int];
    		z_inv : float = z_seg[x - xl_int];
            current_depth := GetDepthValue(x, y, <<render_buffer);
    		// if z_inv >= current_depth {
    		if z_inv >= current_depth { //For 2D depth checking
				// color_hex : u32 = ColorToHex(color);
				color_shade : u32 = ColorToHex(s_seg[x - xl_int] * color);
				//TODO do we still need clip here?
    			SetPixelFromBottomClip(x, y, color_shade, render_buffer);
    			// SetPixelFromBottom(x, y, color_shade, render_buffer);
    			SetDepthValue(x, y, z_inv, render_buffer);
    		}
    	}
	}
}
}

DrawCross :: (center : Vector2F, width : float, height : float, color : Vector4F,
                        render_buffer : *RenderBuffer, R : float = 2.0) 
{
    horizontal : Rectangle2 = RectCenterDim(center, MakeV2F(width, R));
    DrawRectangle(horizontal.min, horizontal.max, color, render_buffer);   

    vertical : Rectangle2 = RectCenterDim(center, MakeV2F(R, height));
    DrawRectangle(vertical.min, vertical.max, color, render_buffer);   
}

//Note current rendering is for grid to avoid thickness overlap on adjacent rectangle outlines
DrawRectangleOutline :: (center : Vector2F, width : float, height : float, color : Vector4F,
                        render_buffer : *RenderBuffer, R : float = 2.0) {
    rect : Rectangle2 = RectCenterDim(center, MakeV2F(width, height));
    DrawRectangle(MakeV2F(rect.min.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.min.x + R/2.0, rect.max.y + R/2.0), color, render_buffer);
    DrawRectangle(MakeV2F(rect.min.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.min.y + R/2.0), color, render_buffer);
    DrawRectangle(MakeV2F(rect.max.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.max.y + R/2.0), color, render_buffer);
    DrawRectangle(MakeV2F(rect.min.x - R/2.0, rect.max.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.max.y + R/2.0), color, render_buffer);
}

DrawRectangle :: inline (rect : Rectangle2, color : Vector4F, render_buffer : *RenderBuffer = null) {
	DrawRectangle(rect.min, rect.max, color, render_buffer);
}

DrawRectangle :: inline (center : Vector2F, width : float, height : float, color : Vector4F, back_buffer : *RenderBuffer = null) {
	rect : Rectangle2 = RectCenterDim(center, MakeV2F(width, height));	
    DrawRectangle(rect.min, rect.max, color, back_buffer);
}

DrawRectangle :: inline (minXY : Vector2F, maxXY : Vector2F, color : Vector4F, render_buffer : *RenderBuffer) {
	color_hex : u32 = ColorToHex(color);
	DrawRectangle(minXY, maxXY, color_hex, render_buffer);
}

DrawRectangle :: (minXY : Vector2F, maxXY : Vector2F, color : u32, render_buffer : *RenderBuffer) {
    minX_int := round_to_int(minXY.x);
    minY_int := round_to_int(minXY.y);
    maxX_int := round_to_int(maxXY.x);
    maxY_int := round_to_int(maxXY.y);

    if minX_int < 0 then minX_int = 0;
    if minY_int < 0 then minY_int = 0;
    if maxX_int >= render_buffer.width then maxX_int = render_buffer.width-1;
    if maxY_int >= render_buffer.height then maxY_int = render_buffer.height-1;
    row : *u32 = (cast(*u32) render_buffer.memory) + minY_int * render_buffer.width + minX_int;
    for y : minY_int..maxY_int {
    	pixel : *u32 = row;
        for x : minX_int..maxX_int 
        {
        	<<pixel = color;
            pixel += 1;
            // SetPixelFromBottom(x, y, color, render_buffer);
        }
        row += render_buffer.width;
    }
}

#if 0 {
DrawRandomPixelRectangle :: inline (center : Vector2F, height : float, width : float,
                                    random_series : RandomSeries, render_buffer : *RenderBuffer)
{
    //Note : This assumes that bitmap width and height are even numbers
    center_from_middle := MakeV2F(render_buffer.width / 2 + center.x,
                            render_buffer.height / 2 + center.y);
    rect := RectCenterDim(center_from_middle, MakeV2F(height, width));
    DrawRandomPixelRectangle(rect.min, rect.max, random_series, render_buffer);
}

DrawRandomPixelRectangle :: (minXY : Vector2F, maxXY : Vector2F, 
                            random_series : RandomSeries, render_buffer : *RenderBuffer) 
{
    loop_random : RandomSeries;
    loop_random.random_number_index = random_series.random_number_index;

    minX_int := round_to_int(minXY.x);
    minY_int := round_to_int(minXY.y);
    maxX_int := round_to_int(maxXY.x);
    maxY_int := round_to_int(maxXY.y);

    if minX_int < 0 then minX_int = 0;
    if minY_int < 0 then minY_int = 0;
    if maxX_int >= render_buffer.width then maxX_int = render_buffer.width-1;
    if maxY_int >= render_buffer.height then maxY_int = render_buffer.height-1;
    for y : minY_int..maxY_int {
        for x : minX_int..maxX_int 
        {
            r := RandomUnilateral(*loop_random);
            g := RandomUnilateral(*loop_random);
            b := RandomUnilateral(*loop_random);
            color : u32 = (round_to_u32(r * 255.0) << 16) |
                          (round_to_u32(g * 255.0) << 8) |
                          (round_to_u32(b * 255.0));
            SetPixelFromBottom(x, y, color, render_buffer);
        }
    }
}
}

//TODO how should we generically pass in float vectors?
DrawTriangle :: (v0 : Vector2I, v1 : Vector2I, v2 : Vector2I, color : u32, render_buffer : *RenderBuffer) {
    //Sanity check for now but this is probably inefficient here
    if v0.y > render_buffer.height ||
        v1.y > render_buffer.height ||
        v2.y > render_buffer.height ||
        v0.y < 0 || v1.y < 0 || v2.y < 0
    {
    	//TODO clipping should be assumed before input
        return; 
    }

    //To ensure counter-clockwise oriented triangle 
    if moment(v1 - v0, v2 - v0) < 0 then swap(*v0, *v1);

    vsort_x0 : int = v0.x;
    vsort_x1 : int = v1.x;
    vsort_x2 : int = v2.x;
    if vsort_x0 > vsort_x1 then swap(*vsort_x0, *vsort_x1);
    if vsort_x1 > vsort_x2 then swap(*vsort_x1, *vsort_x2);
    if vsort_x0 > vsort_x1 then swap(*vsort_x0, *vsort_x1);

    vsort_y0 : int = v0.y;
    vsort_y1 : int = v1.y;
    vsort_y2 : int = v2.y;
    if vsort_y0 > vsort_y1 then swap(*vsort_y0, *vsort_y1); 
    if vsort_y1 > vsort_y2 then swap(*vsort_y1, *vsort_y2); 
    if vsort_y0 > vsort_y1 then swap(*vsort_y0, *vsort_y1);

    a01 : int = v0.y - v1.y;
    b01 : int = v1.x - v0.x;
    w01 : int = a01 * vsort_x0 + b01 * vsort_y0 + moment(v0, v1);
    w01_y : int = w01;

    a12 : int = v1.y - v2.y;
    b12 : int = v2.x - v1.x;
    w12 : int = a12 * vsort_x0 + b12 * vsort_y0 + moment(v1, v2);
    w12_y : int = w12;

    a20 : int = v2.y - v0.y;
    b20 : int = v0.x - v2.x;
    w20 : int = a20 * vsort_x0 + b20 * vsort_y0 + moment(v2, v0);
    w20_y : int = w20;

    //TODO can do simd on 8-16 pixels at once here
    row : *u32 = (cast(*u32) render_buffer.memory) + vsort_y0 * render_buffer.width + vsort_x0;
    for y : vsort_y0..vsort_y2 {
        w01 = w01_y;
        w12 = w12_y;
        w20 = w20_y;
        pixel : *u32 = row;
        for x : vsort_x0..vsort_x2 {
            w01 += a01;
            w12 += a12;
            w20 += a20;
            //TODO we should set pixel directly here and only increment pixel in x and pixel row in y
            // if w01 | w12 | w20 >= 0 then SetPixelFromBottom(x, y, color, render_buffer);
            if w01 | w12 | w20 >= 0 then <<pixel = color;
            pixel += 1;
        }
        w01_y += b01;
        w12_y += b12;
        w20_y += b20;
        row += render_buffer.width;
    } 
}


//TODO update color to Vector4F
//TODO DrawLine using rotated cube similar to 3D edge
DrawLineSimpQuad :: inline (v0 : Vector2F, v1 : Vector2F, color : Vector4F) {
	// Simp.set_shader_for_color();
	c :: 0.75;
	color_v := color.jai_v;
	sort_v0, sort_v1 := Vector2.{v0.x, v0.y}, Vector2.{v1.x, v1.y};
	if sort_v0.x > sort_v1.x {
		temp := sort_v0;
		sort_v0 = sort_v1;
		sort_v1 = temp;
	}
	if sort_v1.y > sort_v0.y {
		Simp.immediate_quad(
			Vector2.{sort_v0.x - c, sort_v0.y + c}, 
			Vector2.{sort_v0.x + c, sort_v0.y - c}, 
			Vector2.{sort_v1.x - c, sort_v1.y + c}, 
			Vector2.{sort_v1.x + c, sort_v1.y - c},
			color_v);
	} else if sort_v0.y > sort_v1.y {
		Simp.immediate_quad(
			Vector2.{sort_v0.x + c, sort_v0.y + c}, 
			Vector2.{sort_v0.x - c, sort_v0.y - c}, 
			Vector2.{sort_v1.x + c, sort_v1.y + c}, 
			Vector2.{sort_v1.x - c, sort_v1.y - c},
			color_v);
	} else if round_to_int(sort_v0.x) == round_to_int(sort_v1.x) {
		Simp.immediate_quad(
			Vector2.{sort_v0.x - c, sort_v0.y}, 
			Vector2.{sort_v0.x + c, sort_v0.y}, 
			Vector2.{sort_v1.x - c, sort_v1.y}, 
			Vector2.{sort_v1.x + c, sort_v1.y},
			color_v);
	} else if round_to_int(sort_v0.y) == round_to_int(sort_v1.y) {
		Simp.immediate_quad(
			Vector2.{sort_v0.x, sort_v0.y - c}, 
			Vector2.{sort_v0.x, sort_v0.y + c}, 
			Vector2.{sort_v1.x, sort_v1.y - c}, 
			Vector2.{sort_v1.x, sort_v1.y + c},
			color_v);
	}
}

DrawLine :: inline (v0 : Vector2F, v1 : Vector2F, color : Vector4F, render_buffer : *RenderBuffer = null) {
	/*TODO for efficient clipping would have to check line segment intersction 
  		https://stackoverflow.com/questions/16203760/how-to-check-if-line-segment-intersects-a-rectangle
	*/
 	x0 := round_to_int(v0.x);
 	y0 := round_to_int(v0.y);
 	x1 := round_to_int(v1.x);
 	y1 := round_to_int(v1.y);

    hex_color := ColorToHex(color);
    DrawLine(x0, y0, x1, y1, hex_color, render_buffer);
}

//Bresenham's Line Algorithm!
DrawLine :: (x0 : int, y0 : int, x1 : int, y1 : int, color : u32, render_buffer : *RenderBuffer) {
    y_large := false;
    if abs(y1 - y0) > abs(x1 - x0) {
        swap(*x0, *y0);
        swap(*x1, *y1);
        y_large = true;
    }

    if x0 > x1 {
        swap(*x0, *x1);
        swap(*y0, *y1);
    }

    x_diff : int = x1 - x0;
    y_diff : int = y1 - y0;
    y_delta : int = 1;
    if y_diff < 0 {
       y_delta = -1;
       y_diff *= -1;
    }

    c2 : int = 2 * y_diff;
    c1 : int = c2 - 2 * x_diff;
    p : int = c2 - x_diff;
    y : int = y0;
    for x : x0..x1 {
    	//TODO can make this more efficient by setting pixels directly to buffer
    	//TODO clipping should be done pre pixel setting for speed
        if y_large then SetPixelFromBottomClip(y, x, color, render_buffer);
        else SetPixelFromBottomClip(x, y, color, render_buffer);
        if p > 0 {
            p += c1;
            y += y_delta;
        }
        else {
            p += c2;
        }
    }
}

//TODO can probably swap all these pixel ints with s32
SetPixelFromTop :: inline (x : int, y : int, color : u32, render_buffer : *RenderBuffer) {
    //because int == s64 then the addition is correct since we are adding bytes to a byte
    pixel := cast(*u32) (render_buffer.memory + GetPixelCoordFromTop(x, y, <<render_buffer));
    <<pixel = color;
}

SetPixelFromBottom :: inline (x : int, y : int, color : u32, render_buffer : *RenderBuffer) {
    //because int == s64 then the addition is correct since we are adding bytes to a byte
    pixel_coord := GetPixelCoordFromBottom(x, y, <<render_buffer);
    pixel := cast(*u32) (render_buffer.memory + pixel_coord);
    <<pixel = color;
}

SetPixelFromBottomClip :: inline (x : int, y : int, color : u32, render_buffer : *RenderBuffer) {
    //because int == s64 then the addition is correct since we are adding bytes to a byte
    if x < 0 || x >= render_buffer.width || y < 0 || y >= render_buffer.height return;
    pixel_coord := GetPixelCoordFromBottom(x, y, <<render_buffer);
    pixel := cast(*u32) (render_buffer.memory + pixel_coord);
    <<pixel = color;
}

//This assumes that we are starting from the bottom left corner and drawing to the right and up
GetPixelCoordFromBottom :: inline (x : int, y : int, render_buffer : RenderBuffer) -> int {
    return (x + y * render_buffer.width) * render_buffer.bytes_per_pixel;
}

//int here to generalize function
//But this returns a byte accurate coordinate
GetPixelCoordFromTop :: inline (x : int, y : int, render_buffer : RenderBuffer) -> int {
    return ((render_buffer.height - 1 - y) * render_buffer.width + x) * render_buffer.bytes_per_pixel;
}

//END OF RENDERING

/*
https://www.geeksforgeeks.org/bresenhams-circle-drawing-algorithm/
// C-program for circle drawing
// using Bresenham’s Algorithm
// in computer-graphics
#include <stdio.h>
#include <dos.h>
#include <graphics.h>
 
// Function to put pixels
// at subsequence points
void drawCircle(int xc, int yc, int x, int y)
{
    putpixel(xc+x, yc+y, RED);
    putpixel(xc-x, yc+y, RED);
    putpixel(xc+x, yc-y, RED);
    putpixel(xc-x, yc-y, RED);
    putpixel(xc+y, yc+x, RED);
    putpixel(xc-y, yc+x, RED);
    putpixel(xc+y, yc-x, RED);
    putpixel(xc-y, yc-x, RED);
}
 
// Function for circle-generation
// using Bresenham's algorithm
void circleBres(int xc, int yc, int r)
{
    int x = 0, y = r;
    int d = 3 - 2 * r;
    drawCircle(xc, yc, x, y);
    while (y >= x)
    {
        // for each pixel we will
        // draw all eight pixels
         
        x++;
 
        // check for decision parameter
        // and correspondingly
        // update d, x, y
        if (d > 0)
        {
            y--;
            d = d + 4 * (x - y) + 10;
        }
        else
            d = d + 4 * x + 6;
        drawCircle(xc, yc, x, y);
        delay(50);
    }
}
*/

